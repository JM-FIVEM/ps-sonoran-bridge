local PS_TO_SONORAN = {}

local function logDebug(msg)
  if Config.Debug then
    print(("[ps-sonoran-bridge][DEBUG] %s"):format(msg))
  end
end

local function logInfo(msg)
  print(("[ps-sonoran-bridge] %s"):format(msg))
end

local function getSonoranSteamId(src)
  for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
    if identifier:sub(1, 6) == "steam:" then
      local hex = identifier:sub(7)
      return "STEAM:" .. string.upper(hex)
    end
  end
  return nil
end

local function parseSonoranCallId(body)
  if not body then return nil end
  return tonumber(tostring(body):match("ID:%s*(%d+)"))
end

local function httpPostJson(url, payload, cb)
  local body = json.encode(payload)

  logDebug(("POST %s"):format(url))
  logDebug(("payload=%s"):format(body))

  PerformHttpRequest(url, function(status, resp, headers)
    logDebug(("status=%s resp=%s"):format(tostring(status), tostring(resp)))
    if cb then cb(status, resp, headers) end
  end, "POST", body, {
    ["Content-Type"] = "application/json",
    ["Accept"] = "application/json",
  })
end

local function buildDescription(data)
  local parts = {}

  if data.code then parts[#parts + 1] = ("Code: %s"):format(data.code) end
  if data.message then parts[#parts + 1] = ("Title: %s"):format(data.message) end
  if data.information then parts[#parts + 1] = ("Info: %s"):format(data.information) end
  if data.vehicle then parts[#parts + 1] = ("Vehicle: %s"):format(data.vehicle) end
  if data.plate then parts[#parts + 1] = ("Plate: %s"):format(data.plate) end
  if data.color then parts[#parts + 1] = ("Color: %s"):format(data.color) end

  return table.concat(parts, " | ")
end

local function sonoranCreateFromDispatch(data)
  local son = Config.Sonoran

  local priority = tonumber(data.priority) or 2
  if priority < 1 then priority = 1 end
  if priority > 3 then priority = 3 end

  local postal = tostring(data.postal or "000")
  if postal == "" then postal = "000" end

  local dispatchObj = {
    serverId = son.serverId,
    origin = son.origin,
    status = son.status,
    priority = priority,

    block = postal,
    postal = postal,

    address = tostring(data.street or "Unknown"),
    title = tostring(data.message or "Dispatch Call"),
    code = tostring(data.code or data.codeName or "CALL"),
    description = buildDescription(data),

    trackPrimary = false,
    notes = {},
    units = {}
  }

  local payload = {
    id = son.communityId,
    key = son.apiKey,
    type = "NEW_DISPATCH",
    data = { dispatchObj }
  }

  local url = son.baseUrl .. "/emergency/new_dispatch"

  httpPostJson(url, payload, function(status, resp)
    if status ~= 200 then
      logInfo(("NEW_DISPATCH FAILED (PS:%s) HTTP:%s"):format(tostring(data.id), tostring(status)))
      logDebug(("resp=%s"):format(tostring(resp)))
      return
    end

    local callId = parseSonoranCallId(resp)
    if not callId then
      logInfo(("NEW_DISPATCH PARSE FAILED (PS:%s)"):format(tostring(data.id)))
      logDebug(("resp=%s"):format(tostring(resp)))
      return
    end

    PS_TO_SONORAN[data.id] = callId
    logInfo(("CALL CREATED [Sonoran:%s] (PS:%s)"):format(tostring(callId), tostring(data.id)))
  end)
end

AddEventHandler('ps-dispatch:server:callCreated', function(data)
  if not data or not data.id then return end
  sonoranCreateFromDispatch(data)
end)

AddEventHandler('ps-dispatch:server:unitAttached', function(psId, src, player)
  local son = Config.Sonoran
  local callId = PS_TO_SONORAN[psId]

  if not callId then
    logInfo(("NO MAPPING (PS:%s) - call not created or resource restarted"):format(tostring(psId)))
    return
  end

  local steamId = getSonoranSteamId(src)
  if not steamId then
    logInfo(("ATTACH SKIPPED - no steam identifier (src:%s) [Sonoran:%s] (PS:%s)"):format(
      tostring(src), tostring(callId), tostring(psId)
    ))
    return
  end

  local payload = {
    id = son.communityId,
    key = son.apiKey,
    type = "ATTACH_UNIT",
    data = {{
      serverId = son.serverId,
      callId = callId,
      units = { steamId }
    }}
  }

  local url = son.baseUrl .. "/emergency/attach_unit"

  httpPostJson(url, payload, function(status, resp)
    if status ~= 200 then
      logInfo(("ATTACH_UNIT FAILED [Sonoran:%s] (PS:%s) HTTP:%s"):format(
        tostring(callId), tostring(psId), tostring(status)
      ))
      logDebug(("resp=%s"):format(tostring(resp)))
      return
    end

    logInfo(("UNIT ATTACHED [Sonoran:%s] (PS:%s)"):format(tostring(callId), tostring(psId)))
    logDebug(("unit=%s src=%s"):format(tostring(steamId), tostring(src)))
  end)
end)
