local addonName, addon = ...
addon.Timeline = addon.Timeline or {}
local Timeline = addon.Timeline

-- Official EncounterTimeline observations are deliberately bounded and
-- de-identified.  Core's SavedVariables extractor only needs the aggregate
-- lifecycle/duration fields; names, GUIDs, chat text and file paths never enter
-- this record.
local MAX_EVENTS_PER_RECORD = 512
local MAX_RECORDS_PER_KEY = 64
local active

local function captureEncounterLoadout()
  if not RaidEngineSavedVariables or type(RaidEngineSavedVariables.binding) ~= "table" then return false end
  if not addon.Loadout or type(addon.Loadout.capture) ~= "function" then return false end
  local ok, snapshot = pcall(addon.Loadout.capture, RaidEngineSavedVariables.binding)
  if not ok or type(snapshot) ~= "table" then return false end
  RaidEngineSavedVariables.last_loadout = snapshot
  RaidEngineSavedVariables.last_loadout_capture_reason = "ENCOUNTER_START"
  return true
end

local function currentTime()
  return GetTime and tonumber(GetTime()) or 0
end

local function numeric(value)
  return type(value) == "number" and value == value and value or nil
end

local function instanceID()
  if not GetInstanceInfo then return nil end
  local value = select(8, GetInstanceInfo())
  value = numeric(value)
  return value and value > 0 and math.floor(value) or nil
end

local function timelineLog()
  RaidEngineSavedVariables = RaidEngineSavedVariables or { schema_version = "0.1.0" }
  RaidEngineSavedVariables.timelineLog = RaidEngineSavedVariables.timelineLog or {}
  return RaidEngineSavedVariables.timelineLog
end

local function eventInfo(eventID)
  if not C_EncounterTimeline or not C_EncounterTimeline.GetEventInfo then return nil end
  local ok, info = pcall(C_EncounterTimeline.GetEventInfo, eventID)
  return ok and type(info) == "table" and info or nil
end

local function eventState(eventID, fallback)
  if numeric(fallback) then return fallback end
  if not C_EncounterTimeline or not C_EncounterTimeline.GetEventState then return nil end
  local ok, state = pcall(C_EncounterTimeline.GetEventState, eventID)
  return ok and numeric(state) or nil
end

local function eventElapsed(eventID)
  if not C_EncounterTimeline or not C_EncounterTimeline.GetEventTimeElapsed then return nil end
  local ok, elapsed = pcall(C_EncounterTimeline.GetEventTimeElapsed, eventID)
  return ok and numeric(elapsed) or nil
end

local function newRecord(encounterID, instance, difficulty)
  return { encounterID = encounterID, instanceID = instance, difficultyID = difficulty, events = {}, startedAt = currentTime() }
end

-- Kept as a small pure-ish helper so the bounded behavior can be tested without
-- a WoW client.  It intentionally copies only scalar timeline fields.
function Timeline._appendEvent(record, eventName, info, timestamp, elapsed, stateID)
  if type(record) ~= "table" or type(record.events) ~= "table" or #record.events >= MAX_EVENTS_PER_RECORD then return false end
  info = type(info) == "table" and info or {}
  local source = numeric(info.source)
  if source and source ~= 0 then return false end -- encounter source only
  local duration = numeric(info.duration)
  local at = numeric(timestamp)
  local since = numeric(elapsed)
  if at == nil then at = currentTime() end
  if since ~= nil then at = math.max(0, at - since) end
  local event = { event = eventName, time = at }
  if duration and duration > 0 then event.duration = duration end
  local state = numeric(stateID)
  if state then event.stateID = state end
  record.events[#record.events + 1] = event
  return true
end

local function appendRuntimeEvent(eventName, eventID, fallbackState)
  if not active then return end
  local info = eventInfo(eventID)
  local elapsed = eventElapsed(eventID)
  local state = eventState(eventID, fallbackState)
  Timeline._appendEvent(active, eventName, info, currentTime(), elapsed, state)
end

local function begin(encounterID, difficulty)
  encounterID = numeric(encounterID)
  local instance = instanceID()
  if not encounterID or encounterID <= 0 or not instance then
    active = nil
    return false
  end
  active = newRecord(math.floor(encounterID), instance, numeric(difficulty) or 0)
  captureEncounterLoadout()
  return true
end

local function finish()
  if not active or #active.events == 0 then active = nil; return false end
  local log = timelineLog()
  local byInstance = log[active.instanceID] or {}
  log[active.instanceID] = byInstance
  local byEncounter = byInstance[active.encounterID] or {}
  byInstance[active.encounterID] = byEncounter
  local key = tostring(active.difficultyID or 0)
  local records = byEncounter[key] or {}
  byEncounter[key] = records
  if #records < MAX_RECORDS_PER_KEY then
    records[#records + 1] = { encounterID = active.encounterID, instanceID = active.instanceID, difficultyID = active.difficultyID, events = active.events }
  end
  active = nil
  return true
end

function Timeline.status()
  if active then return { state = "RECORDING", encounter_id = active.encounterID, instance_id = active.instanceID, event_count = #active.events } end
  local log = RaidEngineSavedVariables and RaidEngineSavedVariables.timelineLog
  local records = 0
  if type(log) == "table" then
    for _, encounters in pairs(log) do
      if type(encounters) == "table" then for _, difficulties in pairs(encounters) do if type(difficulties) == "table" then records = records + #difficulties end end end
    end
  end
  return { state = records > 0 and "READY" or "EMPTY", record_count = records }
end

local frame = CreateFrame and CreateFrame("Frame")
if frame then
  frame:RegisterEvent("ENCOUNTER_START")
  frame:RegisterEvent("ENCOUNTER_END")
  frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
  frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
  frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
      begin(...)
    elseif event == "ENCOUNTER_END" then
      finish()
    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
      appendRuntimeEvent(event, ...)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
      appendRuntimeEvent(event, ...)
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
      appendRuntimeEvent(event, ...)
    end
  end)
end
