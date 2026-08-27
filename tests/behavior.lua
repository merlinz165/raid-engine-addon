local addon = {}
function date(format)
  if format and format:find("%Y%m%d") then return "20260826000000" end
  return "2026-08-26T00:00:00Z"
end
local function load(name)
  local chunk = assert(loadfile(name))
  chunk("RaidEngine", addon)
end

load("RaidEngine_Json.lua")
load("RaidEngine_Contract.lua")
load("RaidEngine_Plan.lua")
load("RaidEngine_Timeline.lua")
load("RaidEngine_Loadout.lua")

local encoded = addon.Json.encode({ z = 2, a = { true, "ok" } })
assert(encoded == '{"a":[true,"ok"],"z":2}', encoded)
local decoded = addon.Json.decode(encoded)
assert(decoded.a[2] == "ok" and decoded.z == 2)
assert(addon.Contract.localIdentity({ a = 1 }) == addon.Contract.localIdentity({ a = 1 }))

local loadout = {
  schema_version = "0.1.0", contract_kind = "PlayerLoadoutSnapshot", document_id = "addon-local:test", producer = "raid-engine-addon", producer_version = "0.1.0", created_at = "2026-08-26T00:00:00Z",
  scope = { game_version = "12.0.1", build = { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = {} }, region = { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = {} }, locale = { state = "KNOWN", value = "zhCN", evidence_status = "PARTIAL", provenance_refs = {} }, difficulty = { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = {} } }, evidence_status = "PARTIAL", coverage = { state = "PARTIAL" }, limitations = {}, provenance_refs = {}, loadout_snapshot_id = "addon-local:test", roster_snapshot_ref = { document_id = "roster:test", content_hash = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }, participation_id = "participation:test", captured_at = "2026-08-26T00:00:00Z", source = "ADDON", specialization_ref = { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = {} }, selected_trait_refs = {}, selected_ability_refs = {}, equipment_refs = {}, selection_coverage = "UNKNOWN"
}
assert(addon.Contract.assertLoadout(loadout))
local ok = pcall(function() addon.Contract.assertLoadout({}) end)
assert(not ok)

local plan = {
  schema_version = "0.1.0", contract_kind = "ExecutionSnapshot", document_id = "execution:test", producer = "raid-engine", producer_version = "0.1.0", created_at = "2026-08-26T00:00:00Z", scope = { game_version = "12.0.1", build = { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = {} }, region = { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = {} }, locale = { state = "KNOWN", value = "zhCN", evidence_status = "PARTIAL", provenance_refs = {} }, difficulty = { state = "UNKNOWN", evidence_status = "UNKNOWN", provenance_refs = {} } }, evidence_status = "VERIFIED", coverage = { state = "COMPLETE" }, limitations = {}, provenance_refs = {}, execution_snapshot_id = "execution:test", plan_version_ref = { document_id = "plan:test", content_hash = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }, leader_decision_ref = { document_id = "decision:test", content_hash = "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" }, effective_from = "2026-08-26T00:00:00Z", task = { task_id = "task:test", kind = "USE_RAID_COOLDOWN_IN_WINDOW", raid_cooldown_ability_id = 123, target_window_ms = { start = 1000, ["end"] = 2000 }, leader_roster_id = "leader:test", backup_roster_id = "backup:test" }, confirmed = true
}
assert(addon.Contract.assertExecutionSnapshot(plan))
local imported, importedValue = pcall(addon.Plan.import, addon.Json.encode(plan))
assert(imported and importedValue.package.confirmed == true)
plan.scope.effective_until = "2020-01-01T00:00:00Z"
imported = pcall(addon.Plan.import, addon.Json.encode(plan))
assert(not imported)
plan.confirmed = false
ok = pcall(function() addon.Contract.assertExecutionSnapshot(plan) end)
assert(not ok)
print("addon behavior checks passed")

local record = { encounterID = 3421, instanceID = 3004, events = {} }
assert(addon.Timeline._appendEvent(record, "ENCOUNTER_TIMELINE_EVENT_ADDED", { source = 0, duration = 41.25 }, 0.5, 0.25, 0))
assert(record.events[1].time == 0.25 and record.events[1].duration == 41.25)
assert(not addon.Timeline._appendEvent(record, "ENCOUNTER_TIMELINE_EVENT_ADDED", { source = 1, duration = 99 }, 1, 0, 0))
for _ = 1, 600 do addon.Timeline._appendEvent(record, "ENCOUNTER_TIMELINE_EVENT_REMOVED", { source = 0 }, 1, nil, 3) end
assert(#record.events == 512)

-- The client snapshot records bounded action-bar spell observations while
-- keeping the overall selection explicitly PARTIAL.
function GetBuildInfo() return "12.1.0", "", "", "69382" end
function GetLocale() return "zhCN" end
function UnitClass() return "圣骑士", "PALADIN", 2 end
function GetSpecialization() return nil end
function GetActionInfo(slot)
  if slot == 1 then return "spell", 1289855 end
  if slot == 2 then return "spell", 31821 end
  if slot == 3 then return "spell", 1289855 end
  return nil, nil
end
function GetInventoryItemID() return nil end
RaidEngineSavedVariables = {}
local captured = addon.Loadout.capture({ participation_id = "participation:test", roster_snapshot_ref = { document_id = "roster:test", content_hash = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } })
assert(captured.selection_coverage == "PARTIAL")
assert(#captured.selected_ability_refs == 2)
assert(captured.selected_ability_refs[1].id == 31821 and captured.selected_ability_refs[2].id == 1289855)
