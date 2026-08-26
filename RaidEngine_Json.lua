local addonName, addon = ...
addon.Json = addon.Json or {}
local Json = addon.Json

local function isArray(value)
  if type(value) ~= "table" then return false, 0 end
  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false, 0 end
    count = count + 1
  end
  for index = 1, count do
    if value[index] == nil then return false, 0 end
  end
  return true, count
end

local function escape(value)
  return value:gsub('[%z\1-\31\\"]', function(character)
    local escapes = { ["\\"] = "\\\\", ["\""] = "\\\"", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f" }
    return escapes[character] or string.format("\\u%04x", string.byte(character))
  end)
end

local function encode(value, depth)
  depth = depth or 0
  if depth > 24 then error("JSON nesting limit exceeded") end
  local valueType = type(value)
  if value == nil then return "null" end
  if valueType == "boolean" then return value and "true" or "false" end
  if valueType == "number" then
    if value ~= value or value == math.huge or value == -math.huge then error("JSON cannot encode non-finite numbers") end
    return string.format("%.17g", value)
  end
  if valueType == "string" then return '"' .. escape(value) .. '"' end
  if valueType ~= "table" then error("JSON cannot encode " .. valueType) end
  local array, count = isArray(value)
  local parts = {}
  if array then
    for index = 1, count do parts[#parts + 1] = encode(value[index], depth + 1) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do
    if type(key) ~= "string" then error("JSON object keys must be strings") end
    keys[#keys + 1] = key
  end
  table.sort(keys)
  for _, key in ipairs(keys) do parts[#parts + 1] = encode(key, depth + 1) .. ":" .. encode(value[key], depth + 1) end
  return "{" .. table.concat(parts, ",") .. "}"
end

function Json.encode(value)
  return encode(value, 0)
end

local function decode(source)
  if type(source) ~= "string" or #source > 256 * 1024 then error("JSON input is empty or too large") end
  local position = 1
  local function skipWhitespace()
    while position <= #source and source:sub(position, position):match("%s") do position = position + 1 end
  end
  local parseValue
  local function parseString()
    position = position + 1
    local out = {}
    while position <= #source do
      local character = source:sub(position, position)
      if character == '"' then position = position + 1; return table.concat(out) end
      if character == "\\" then
        position = position + 1
        local escaped = source:sub(position, position)
        local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
        if map[escaped] then out[#out + 1] = map[escaped]; position = position + 1
        elseif escaped == "u" then
          local hex = source:sub(position + 1, position + 4)
          if not hex:match("^%x%x%x%x$") then error("Invalid JSON unicode escape") end
          local code = tonumber(hex, 16)
          if code < 128 then out[#out + 1] = string.char(code) else out[#out + 1] = "?" end
          position = position + 5
        else error("Invalid JSON escape") end
      else
        if string.byte(character) < 32 then error("Control character in JSON string") end
        out[#out + 1] = character; position = position + 1
      end
    end
    error("Unterminated JSON string")
  end
  local function parseNumber()
    local start = position
    local token = source:sub(position):match("^-?%d+%.?%d*[eE]?[+-]?%d*")
    if not token or token == "" or not token:match("^-?%d+%.?%d*[eE]?[+-]?%d*$") then error("Invalid JSON number") end
    position = position + #token
    local number = tonumber(token)
    if not number or number ~= number or number == math.huge or number == -math.huge then error("Invalid JSON number") end
    if position == start then error("Invalid JSON number") end
    return number
  end
  local function parseArray()
    position = position + 1; local result = {}; skipWhitespace()
    if source:sub(position, position) == "]" then position = position + 1; return result end
    while true do
      result[#result + 1] = parseValue(); skipWhitespace()
      local character = source:sub(position, position)
      if character == "]" then position = position + 1; return result end
      if character ~= "," then error("Expected comma in JSON array") end
      position = position + 1; skipWhitespace()
    end
  end
  local function parseObject()
    position = position + 1; local result = {}; skipWhitespace()
    if source:sub(position, position) == "}" then position = position + 1; return result end
    while true do
      if source:sub(position, position) ~= '"' then error("JSON object key must be a string") end
      local key = parseString(); skipWhitespace()
      if source:sub(position, position) ~= ":" then error("Expected colon in JSON object") end
      position = position + 1; skipWhitespace()
      if result[key] ~= nil then error("Duplicate JSON object key") end
      result[key] = parseValue(); skipWhitespace()
      local character = source:sub(position, position)
      if character == "}" then position = position + 1; return result end
      if character ~= "," then error("Expected comma in JSON object") end
      position = position + 1; skipWhitespace()
    end
  end
  function parseValue()
    skipWhitespace(); local character = source:sub(position, position)
    if character == '"' then return parseString() end
    if character == "{" then return parseObject() end
    if character == "[" then return parseArray() end
    if source:sub(position, position + 3) == "true" then position = position + 4; return true end
    if source:sub(position, position + 4) == "false" then position = position + 5; return false end
    if source:sub(position, position + 3) == "null" then position = position + 4; return nil end
    if character == "-" or character:match("%d") then return parseNumber() end
    error("Unexpected JSON token")
  end
  local value = parseValue(); skipWhitespace()
  if position <= #source then error("Trailing JSON input") end
  return value
end

function Json.decode(source)
  return decode(source)
end
