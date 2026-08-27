local addonName, addon = ...
_G.RaidEngine = addon
addon.version = "0.1.0"

local function message(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff58a6ffRaid Engine|r " .. tostring(text)) end
end
local function binding()
  RaidEngineSavedVariables = RaidEngineSavedVariables or {}
  RaidEngineSavedVariables.binding = RaidEngineSavedVariables.binding or {}
  return RaidEngineSavedVariables.binding
end
local function usage()
  message("命令：bind <participation_id> <roster_snapshot_id> <sha256:...>；capture；export；import <JSON>；timeline；status；clear confirm")
end
local function splitFirst(text)
  local command, rest = text:match("^(%S+)%s*(.-)%s*$")
  return (command or ""), (rest or "")
end

local function handle(commandText)
  local command, rest = splitFirst(commandText)
  if command == "bind" then
    local participation, rosterID, rosterHash = rest:match("^(%S+)%s+(%S+)%s+(%S+)%s*$")
    if not participation or not rosterID or not rosterHash or not (rosterHash:match("^sha256:[0-9a-f]+$") and #rosterHash == 71) then message("bind 参数无效；需要 participation_id、roster_snapshot_id、64 位小写 sha256 引用"); return end
    local state = binding(); state.participation_id = participation; state.roster_snapshot_ref = { document_id = rosterID, content_hash = rosterHash }; message("已绑定本地采集上下文；不会保存云端凭据。")
  elseif command == "capture" then
    local ok, result = pcall(addon.Loadout.capture, binding())
    if not ok then message(result); return end
    RaidEngineSavedVariables.last_loadout = result; message("已采集 Loadout（" .. result.loadout_snapshot_id .. "）；输入 export 导出交换包。")
  elseif command == "export" then
    local value = RaidEngineSavedVariables and RaidEngineSavedVariables.last_loadout
    if not value then message("尚无快照；先执行 capture"); return end
    local serialized = addon.Json.encode(value); RaidEngineSavedVariables.last_loadout_export = serialized; message("已写入 SavedVariables 导出缓存（" .. #serialized .. " bytes）；复制该 JSON 交给 Core 导入，不要在聊天频道粘贴。")
  elseif command == "import" then
    if rest == "" then message("import 需要确认计划 JSON"); return end
    local ok, result = pcall(addon.Plan.import, rest)
    if not ok then message(result); return end
    RaidEngineSavedVariables.confirmed_plan = result; message("已导入并校验确认计划：\n" .. addon.Plan.render(result))
  elseif command == "timeline" then
    local state = addon.Timeline and addon.Timeline.status and addon.Timeline.status() or { state = "UNAVAILABLE" }
    message("官方时间轴采集：" .. tostring(state.state) .. "；记录=" .. tostring(state.record_count or 0) .. "；战斗中事件=" .. tostring(state.event_count or 0) .. "。仅保存去标识化事件聚合，交给 Core 提取。")
  elseif command == "status" then
    local state = RaidEngineSavedVariables or {}; local loadout = state.last_loadout; local plan = state.confirmed_plan
    message("版本 " .. addon.version .. "；Loadout=" .. (loadout and loadout.loadout_snapshot_id or "未采集") .. "；确认计划=" .. (plan and plan.package.execution_snapshot_id or "未导入"))
  elseif command == "clear" and rest == "confirm" then
    RaidEngineSavedVariables.last_loadout = nil; RaidEngineSavedVariables.last_loadout_export = nil; RaidEngineSavedVariables.confirmed_plan = nil; RaidEngineSavedVariables.timelineLog = nil; message("已清除本地快照、导出缓存、时间轴和确认计划；绑定信息保留。")
  else usage() end
end

SLASH_RAIDENGINE1 = "/raidengine"
SlashCmdList.RAIDENGINE = handle

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  RaidEngineSavedVariables = RaidEngineSavedVariables or { schema_version = "0.1.0" }
  message("已加载；不执行任何受保护游戏动作。输入 /raidengine 查看命令。")
end)
