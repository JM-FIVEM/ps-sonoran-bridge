# ps-sonoran-bridge

A simple bridge between **ps-dispatch** and **Sonoran CAD**.

When a PS-Dispatch call is created, a dispatch call is created in Sonoran CAD.
When an officer accepts a call, the unit is attached to the Sonoran call.

---

## ⚠️ Sonoran Subscription Requirement

This resource **requires Sonoran CAD Plus or higher**.

The following Sonoran API endpoints are used and are **NOT available** on Free or Standard plans:

- `emergency/new_dispatch`
- `emergency/attach_unit`

If your community is not on **Plus or higher**, this resource will not work.

---

## Requirements

- FiveM server
- **ps-dispatch**
- **Sonoran CAD Plus or higher**

---

## Installation

1. Place the resource in your server:

2. Ensure it in `server.cfg`:
   ```cfg
   ensure ps-sonoran-bridge
   ```

3. Make sure **ps-dispatch** starts before this resource.

---

## Configuration

Edit `config.lua` and set your Sonoran details:

```lua
Config = {}

Config.Sonoran = {
  baseUrl = "https://api.sonorancad.com",
  communityId = "YOUR_COMMUNITY_ID",
  apiKey = "YOUR_API_KEY",
  serverId = 1,
  origin = 1, -- 1 for RADIO DISPATCH // 2 for CALLER
  status = 0,
}
```

Edit `ps-dispatch/server/main.lua`

# ⚠ OR DOWNLOAD MY FORK OF IT [HERE](https://github.com/JM-FIVEM/ps-dispatch)

Replace `ps-dispatch:server:notify` and `ps-dispatch:client:notify` with this

```
-- Events
RegisterServerEvent('ps-dispatch:server:notify', function(data)
    callCount = callCount + 1
    data.id = callCount
    data.time = os.time() * 1000
    data.units = {}
    data.responses = {}

    if #calls > 0 then
        if calls[#calls] == data then
            return
        end
    end
        
    if #calls >= Config.MaxCallList then
        table.remove(calls, 1)
    end

    calls[#calls + 1] = data

    TriggerClientEvent('ps-dispatch:client:notify', -1, data)
    TriggerEvent('ps-dispatch:server:callCreated', data)

end)

RegisterServerEvent('ps-dispatch:server:attach', function(id, player)
    for i=1, #calls do
        if calls[i]['id'] == id then
            for j = 1, #calls[i]['units'] do
                if calls[i]['units'][j]['citizenid'] == player.citizenid then
                    return
                end
            end
            calls[i]['units'][#calls[i]['units'] + 1] = player
            TriggerEvent('ps-dispatch:server:unitAttached', id, source, player)
            return
        end
    end
end)
```
---

## How It Works

- PS-Dispatch creates a call → Sonoran **NEW_DISPATCH**
- Officer accepts the call → Sonoran **ATTACH_UNIT**

---

## Notes
- Call mappings are stored in memory and reset on resource restart.
