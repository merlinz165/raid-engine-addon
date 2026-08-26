local addonName, addon = ...
addon.Contract = addon.Contract or {}
local Contract = addon.Contract
local Json = addon.Json

local function fail(message) error("Raid Engine contract rejected: " .. message, 0) end
local function requireType(value, expected, label)
  if type(value) ~= expected then fail(label .. " must be " .. expected) end
end
local function requireString(value, label)
  requireType(value, "string", label)
  if value == "" then fail(label .. " must not be empty") end
end
local function requireHash(value, label)
  requireString(value, label)
  if not value:match("^sha256:[0-9a-fA-F]+$") then fail(label .. " must be a sha256 reference") end
end
local function allowedKeys(value, keys, label)
  for key in pairs(value) do if not keys[key] then fail(label .. " contains unsupported field " .. tostring(key)) end end
end
local function evidenceValue(value, label)
  requireType(value, "table", label)
  allowedKeys(value, { state = true, value = true, evidence_status = true, provenance_refs = true, limitations = true }, label)
  requireString(value.state, label .. ".state")
  if value.state ~= "KNOWN" and value.state ~= "UNKNOWN" and value.state ~= "NOT_APPLICABLE" then fail(label .. ".state is invalid") end
  requireString(value.evidence_status, label .. ".evidence_status")
  requireType(value.provenance_refs, "table", label .. ".provenance_refs")
  if value.state == "KNOWN" and value.value == nil then fail(label .. ".value is required when known") end
end
local function root(value, kind)
  requireType(value, "table", kind)
  requireString(value.schema_version, kind .. ".schema_version")
  if value.schema_version ~= "0.1.0" and value.schema_version ~= "0.2.0" then fail(kind .. ".schema_version is unsupported") end
  if value.contract_kind ~= kind then fail(kind .. ".contract_kind mismatch") end
  requireString(value.document_id, kind .. ".document_id"); requireString(value.producer, kind .. ".producer"); requireString(value.producer_version, kind .. ".producer_version"); requireString(value.created_at, kind .. ".created_at")
  requireType(value.scope, "table", kind .. ".scope"); requireString(value.scope.game_version, kind .. ".scope.game_version")
  requireType(value.limitations, "table", kind .. ".limitations"); requireType(value.provenance_refs, "table", kind .. ".provenance_refs")
end
local function identity(value, label, namespaces)
  requireType(value, "table", label); allowedKeys(value, { namespace = true, id = true, display_kind = true }, label)
  requireString(value.namespace, label .. ".namespace"); requireType(value.id, "number", label .. ".id"); requireString(value.display_kind, label .. ".display_kind")
  if namespaces and not namespaces[value.namespace] then fail(label .. ".namespace is not allowed") end
end

function Contract.assertLoadout(value)
  root(value, "PlayerLoadoutSnapshot")
  allowedKeys(value, { schema_version = true, contract_kind = true, document_id = true, producer = true, producer_version = true, created_at = true, scope = true, evidence_status = true, coverage = true, limitations = true, provenance_refs = true, loadout_snapshot_id = true, roster_snapshot_ref = true, participation_id = true, captured_at = true, source = true, class_ref = true, specialization_ref = true, selected_trait_refs = true, selected_ability_refs = true, equipment_refs = true, selection_coverage = true }, "PlayerLoadoutSnapshot")
  requireString(value.loadout_snapshot_id, "loadout_snapshot_id"); requireString(value.participation_id, "participation_id"); requireString(value.captured_at, "captured_at")
  requireType(value.roster_snapshot_ref, "table", "roster_snapshot_ref"); requireString(value.roster_snapshot_ref.document_id, "roster_snapshot_ref.document_id"); requireHash(value.roster_snapshot_ref.content_hash, "roster_snapshot_ref.content_hash")
  requireString(value.source, "source"); if value.source ~= "ADDON" then fail("source must be ADDON") end
  evidenceValue(value.specialization_ref, "specialization_ref"); if value.class_ref then evidenceValue(value.class_ref, "class_ref") end
  requireType(value.selected_trait_refs, "table", "selected_trait_refs"); local seen = {}
  for index, ref in ipairs(value.selected_trait_refs) do identity(ref, "selected_trait_refs[" .. index .. "]", { ["blizzard.trait_node_entry"] = true }); local key = ref.namespace .. ":" .. ref.id; if seen[key] then fail("duplicate selected Trait ref") end; seen[key] = true end
  if value.selected_ability_refs then
    requireType(value.selected_ability_refs, "table", "selected_ability_refs"); seen = {}
    for index, ref in ipairs(value.selected_ability_refs) do identity(ref, "selected_ability_refs[" .. index .. "]", { ["blizzard.spell"] = true, ["blizzard.skill_line_ability"] = true }); local key = ref.namespace .. ":" .. ref.id; if seen[key] then fail("duplicate selected ability ref") end; seen[key] = true end
  end
  if value.equipment_refs then
    requireType(value.equipment_refs, "table", "equipment_refs"); seen = {}
    for index, ref in ipairs(value.equipment_refs) do
      requireType(ref, "table", "equipment_refs[" .. index .. "]"); allowedKeys(ref, { slot = true, item_id = true, item_level = true }, "equipment_refs[" .. index .. "]"); requireType(ref.slot, "number", "equipment slot"); requireType(ref.item_id, "number", "equipment item_id"); evidenceValue(ref.item_level, "equipment item_level"); if seen[ref.slot] then fail("duplicate equipment slot") end; seen[ref.slot] = true
    end
  end
  requireString(value.selection_coverage, "selection_coverage")
  if value.selection_coverage ~= "COMPLETE" and value.selection_coverage ~= "PARTIAL" and value.selection_coverage ~= "UNKNOWN" then fail("selection_coverage is invalid") end
  return true
end

function Contract.assertExecutionSnapshot(value)
  root(value, "ExecutionSnapshot")
  allowedKeys(value, { schema_version = true, contract_kind = true, document_id = true, producer = true, producer_version = true, created_at = true, scope = true, evidence_status = true, coverage = true, limitations = true, provenance_refs = true, execution_snapshot_id = true, plan_version_ref = true, leader_decision_ref = true, raid_night_ref = true, roster_snapshot_ref = true, effective_from = true, task = true, confirmed = true }, "ExecutionSnapshot")
  requireString(value.execution_snapshot_id, "execution_snapshot_id"); requireString(value.effective_from, "effective_from"); if value.confirmed ~= true then fail("only confirmed plans may be imported") end
  for _, key in ipairs({ "plan_version_ref", "leader_decision_ref" }) do local ref = value[key]; requireType(ref, "table", key); allowedKeys(ref, { document_id = true, content_hash = true }, key); requireString(ref.document_id, key .. ".document_id"); requireHash(ref.content_hash, key .. ".content_hash") end
  if value.raid_night_ref then requireType(value.raid_night_ref, "table", "raid_night_ref"); requireString(value.raid_night_ref.document_id, "raid_night_ref.document_id"); requireHash(value.raid_night_ref.content_hash, "raid_night_ref.content_hash") end
  if value.roster_snapshot_ref then requireType(value.roster_snapshot_ref, "table", "roster_snapshot_ref"); requireString(value.roster_snapshot_ref.document_id, "roster_snapshot_ref.document_id"); requireHash(value.roster_snapshot_ref.content_hash, "roster_snapshot_ref.content_hash") end
  local task = value.task; requireType(task, "table", "task"); allowedKeys(task, { task_id = true, kind = true, raid_cooldown_ability_id = true, coverage_ability_ids = true, target_window_ms = true, leader_roster_id = true, backup_roster_id = true }, "task"); requireString(task.task_id, "task.task_id"); requireString(task.kind, "task.kind"); requireType(task.target_window_ms, "table", "task.target_window_ms"); requireType(task.target_window_ms.start, "number", "task.target_window_ms.start"); requireType(task.target_window_ms["end"], "number", "task.target_window_ms.end"); if task.target_window_ms.start > task.target_window_ms["end"] then fail("task window is reversed") end; requireString(task.leader_roster_id, "task.leader_roster_id"); requireString(task.backup_roster_id, "task.backup_roster_id")
  return true
end

function Contract.localIdentity(value)
  local encoded = Json.encode(value)
  local hash = 2166136261
  for index = 1, #encoded do hash = (hash + string.byte(encoded, index)) % 4294967296; hash = (hash * 16777619) % 4294967296 end
  return string.format("addon-local:%08x", hash)
end
