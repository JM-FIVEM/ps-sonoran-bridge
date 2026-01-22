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

---

## How It Works

- PS-Dispatch creates a call → Sonoran **NEW_DISPATCH**
- Officer accepts the call → Sonoran **ATTACH_UNIT**

---

## Notes
- Call mappings are stored in memory and reset on resource restart.
