local PS_TO_SONORAN = {} -- [psDispatchId] = sonoranCallId

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
  print(("[ps-sonoran-bridge] POST %s"):format(url))
  print(("[ps-sonoran-bridge] payload=%s"):format(body))

  PerformHttpRequest(url, function(status, resp, headers)
    print(("[ps-sonoran-bridge] status=%s resp=%s"):format(tostring(status), tostring(resp)))
    if cb then cb(status, resp, headers) end
  end, "POST", body, {
    ["Content-Type"] = "application/json",
    ["Accept"] = "application/json",
  })
end

local function sonoranCreateFromDispatch(data)
  local son = Config.Sonoran

  local priority = tonumber(data.priority) or 2
  if priority < 1 then priority = 1 end
  if priority > 3 then priority = 3 end

  local descParts = {}
  if data.code then descParts[#descParts+1] = ("Code: %s"):format(data.code) end
  if data.message then descParts[#descParts+1] = ("Title: %s"):format(data.message) end
  if data.information then descParts[#descParts+1] = ("Info: %s"):format(data.information) end
  if data.vehicle then descParts[#descParts+1] = ("Vehicle: %s"):format(data.vehicle) end
  if data.plate then descParts[#descParts+1] = ("Plate: %s"):format(data.plate) end
  if data.color then descParts[#descParts+1] = ("Color: %s"):format(data.color) end
  local description = table.concat(descParts, " | ")

local postal = tostring(data.postal or "000")
if postal == "" then postal = "000" end

  local dispatchObj = {
  serverId = son.serverId,
  origin = son.origin,
  status = son.status,
  priority = priority,

  block = postal,                -- IMPORTANT
  address = tostring(data.street or "Unknown"),
  postal = postal,               -- IMPORTANT

  title = tostring(data.message or "Dispatch Call"),
  code = tostring(data.code or data.codeName or "CALL"),
  description = description,

  trackPrimary = false,
  notes = {},
  units = {}
}


  if data.postal and tostring(data.postal) ~= "" then
    dispatchObj.postal = tostring(data.postal)
    dispatchObj.block = tostring(data.postal)
  end

local payload = {
  id = son.communityId,
  key = son.apiKey,
  type = "NEW_DISPATCH",
  data = { dispatchObj }
}


  local url = son.baseUrl .. "/emergency/new_dispatch"

  httpPostJson(url, payload, function(status, resp)
    if status ~= 200 then
      print(("[ps-sonoran-bridge] NEW_DISPATCH failed ps id %s: http=%s resp=%s"):format(
        tostring(data.id), tostring(status), tostring(resp)
      ))
      return
    end

    local callId = parseSonoranCallId(resp)
    if not callId then
      print(("[ps-sonoran-bridge] NEW_DISPATCH success but couldn't parse callId. ps id %s resp=%s"):format(
        tostring(data.id), tostring(resp)
      ))
      return
    end

    PS_TO_SONORAN[data.id] = callId
    print(("[ps-sonoran-bridge] Linked ps id %s -> sonoran callId %s"):format(tostring(data.id), tostring(callId)))
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
    print(("[ps-sonoran-bridge] No sonoran mapping for ps id %s"):format(tostring(psId)))
    return
  end

  local steamId = getSonoranSteamId(src)
  if not steamId then
    print(("[ps-sonoran-bridge] No steam: identifier for src %s, cannot attach to Sonoran call %s"):format(
      tostring(src), tostring(callId)
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
      print(("[ps-sonoran-bridge] ATTACH_UNIT failed ps id %s sonoran %s http=%s resp=%s"):format(
        tostring(psId), tostring(callId), tostring(status), tostring(resp)
      ))
      return
    end
    print(("[ps-sonoran-bridge] Attached %s to Sonoran call %s (ps id %s)"):format(
      steamId, tostring(callId), tostring(psId)
    ))
  end)
end)
