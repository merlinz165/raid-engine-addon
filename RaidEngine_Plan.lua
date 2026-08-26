local addonName, addon = ...
addon.Plan = addon.Plan or {}
local Plan = addon.Plan
local Json = addon.Json
local Contract = addon.Contract

local function timestampKey(value)
  if type(value) ~= "string" then return nil end
  local year, month, day, hour, minute, second = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
  if not year then return nil end
  return (((((tonumber(year) * 12 + tonumber(month)) * 31 + tonumber(day)) * 24 + tonumber(hour)) * 60 + tonumber(minute)) * 60 + tonumber(second))
end
local function assertTemporalValidity(value, now)
  local effectiveFrom = value.effective_from
  local effectiveUntil = value.scope and value.scope.effective_until
  local fromTime = timestampKey(effectiveFrom)
  if not fromTime then error("确认计划缺少可读的生效时间", 0) end
  if effectiveUntil then
    local untilTime = timestampKey(effectiveUntil)
    if not untilTime then error("确认计划有效期格式无效", 0) end
    if untilTime <= fromTime then error("确认计划有效期早于生效时间", 0) end
    if now >= untilTime then error("确认计划已过期", 0) end
  end
end

function Plan.import(serialized)
  local value = Json.decode(serialized)
  Contract.assertExecutionSnapshot(value)
  assertTemporalValidity(value, tonumber(date("!%Y%m%d%H%M%S")))
  local checksum = Contract.localIdentity(value)
  return { package = value, checksum = checksum, imported_at = date("!%Y-%m-%dT%H:%M:%SZ") }
end

function Plan.verify(stored)
  if type(stored) ~= "table" or type(stored.package) ~= "table" or type(stored.checksum) ~= "string" then return false, "计划包存储结构无效" end
  local ok, message = pcall(Contract.assertExecutionSnapshot, stored.package)
  if not ok then return false, tostring(message) end
  local temporalOk, temporalMessage = pcall(assertTemporalValidity, stored.package, tonumber(date("!%Y%m%d%H%M%S")))
  if not temporalOk then return false, tostring(temporalMessage) end
  if Contract.localIdentity(stored.package) ~= stored.checksum then return false, "计划包校验和不匹配，可能已被篡改" end
  return true
end

function Plan.render(stored)
  local ok, message = Plan.verify(stored)
  if not ok then error(message, 0) end
  local task = stored.package.task
  local window = task.target_window_ms
  local abilities = {}
  if task.raid_cooldown_ability_id then abilities[#abilities + 1] = tostring(task.raid_cooldown_ability_id) end
  if task.coverage_ability_ids then for _, id in ipairs(task.coverage_ability_ids) do abilities[#abilities + 1] = tostring(id) end end
  return table.concat({ "Raid Engine 已确认任务", "任务：" .. task.task_id, "机制：" .. task.kind, "窗口：" .. tostring(window.start) .. "–" .. tostring(window["end"]) .. " ms", "技能：" .. (#abilities > 0 and table.concat(abilities, ", ") or "未提供技能 ID"), "负责人：" .. task.leader_roster_id, "备份：" .. task.backup_roster_id, "仅显示已确认计划；AddOn 不会自动施法或移动。" }, "\n")
end
