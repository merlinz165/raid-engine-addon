local addonName, addon = ...
addon.Loadout = addon.Loadout or {}
local Loadout = addon.Loadout
local Contract = addon.Contract

local function now()
  return date("!%Y-%m-%dT%H:%M:%SZ")
end
local function known(value, provenance)
  return { state = "KNOWN", value = value, evidence_status = "PARTIAL", provenance_refs = { provenance }, limitations = { "Captured by the WoW client; Core must re-address and reconcile this observation." } }
end
local function unknown(provenance, limitation)
  return { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = { provenance }, limitations = { limitation } }
end
local function scope()
  local version, _, _, build = GetBuildInfo()
  return { game_version = version or "unknown", build = known(tonumber(build) or 0, "addon:build"), region = unknown("addon:region", "Client region is not asserted by the AddOn."), locale = known(GetLocale() or "unknown", "addon:locale"), difficulty = unknown("addon:difficulty", "Encounter difficulty is not available outside an active encounter context.") }
end
local function selectedTraits(configID, provenance)
  local refs = {}
  if not configID or not C_Traits or not C_Traits.GetConfigInfo or not C_Traits.GetTreeNodes or not C_Traits.GetNodeInfo then return refs, false end
  local config = C_Traits.GetConfigInfo(configID)
  if not config or not config.treeIDs then return refs, false end
  for _, treeID in ipairs(config.treeIDs) do
    local nodes = C_Traits.GetTreeNodes(treeID) or {}
    for _, nodeID in ipairs(nodes) do
      local node = C_Traits.GetNodeInfo(configID, nodeID)
      local entry = node and node.activeEntry
      if entry and entry.entryID then refs[#refs + 1] = { namespace = "blizzard.trait_node_entry", id = entry.entryID, display_kind = "trait_node_entry" } end
    end
  end
  return refs, true
end
local function equipment()
  local refs = {}
  for slot = 1, 19 do
    local itemID = GetInventoryItemID("player", slot)
    if itemID then
      local level = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo("player", slot) or nil
      refs[#refs + 1] = { slot = slot, item_id = itemID, item_level = level and known(level, "addon:equipment") or unknown("addon:equipment", "Item level API did not return a value.") }
    end
  end
  return refs
end

function Loadout.capture(binding)
  binding = binding or {}
  if not binding.participation_id or not binding.roster_snapshot_ref then error("先用 /raidengine bind 设置 participation_id、roster snapshot ID 和 sha256") end
  local timestamp = now(); local provenance = "addon:capture:" .. timestamp
  local className, classFile, classID = UnitClass("player")
  local specializationID = GetSpecialization and GetSpecialization() or nil
  local specID = specializationID and GetSpecializationInfo and select(1, GetSpecializationInfo(specializationID)) or nil
  local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID() or nil
  local traits, traitComplete = selectedTraits(configID, provenance)
  local classRef = classID and known({ namespace = "blizzard.class", id = classID, display_kind = "class" }, provenance) or unknown(provenance, "Class identity is unavailable.")
  local specRef = specID and known({ namespace = "blizzard.specialization", id = specID, display_kind = "specialization" }, provenance) or unknown(provenance, "Active specialization is unavailable.")
  local snapshot = { schema_version = "0.1.0", contract_kind = "PlayerLoadoutSnapshot", producer = "raid-engine-addon", producer_version = "0.1.0", created_at = timestamp, scope = scope(), evidence_status = "PARTIAL", coverage = { state = "PARTIAL", notes = { "Selected ability enumeration is intentionally not guessed by the AddOn." } }, limitations = { "Core must re-address this local snapshot before persistence.", "Selected ability IDs are not inferred from action bars.", className and ("Class observed: " .. className) or "Class name unavailable.", classFile and ("Class file observed: " .. classFile) or "Class file unavailable." }, provenance_refs = {}, loadout_snapshot_id = "pending", roster_snapshot_ref = binding.roster_snapshot_ref, participation_id = binding.participation_id, captured_at = timestamp, source = "ADDON", class_ref = classRef, specialization_ref = specRef, selected_trait_refs = traits, selected_ability_refs = {}, equipment_refs = equipment(), selection_coverage = traitComplete and "PARTIAL" or "UNKNOWN" }
  snapshot.provenance_refs[1] = { ref = provenance, kind = "observation", method = "wow-addon-loadout-capture", method_version = "0.1.0", captured_at = timestamp, status = "PARTIAL" }
  snapshot.loadout_snapshot_id = Contract.localIdentity({ roster_snapshot_ref = snapshot.roster_snapshot_ref, participation_id = snapshot.participation_id, captured_at = snapshot.captured_at, class_ref = snapshot.class_ref, specialization_ref = snapshot.specialization_ref, selected_trait_refs = snapshot.selected_trait_refs, selected_ability_refs = snapshot.selected_ability_refs, equipment_refs = snapshot.equipment_refs })
  Contract.assertLoadout(snapshot)
  return snapshot
end
