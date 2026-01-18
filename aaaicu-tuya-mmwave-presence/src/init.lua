-- aaaicu-tuya-mmwave-presence (stable v2)
-- Tuya EF00 (cluster 0xEF00) / command 0x02 payload:
-- 00 <seq> <dp> <type> <len_hi> <len_lo> <data...>

local log = require "log"
local zigbee_driver = require "st.zigbee"
local capabilities = require "st.capabilities"

local TUYA_EF00_CLUSTER = 0xEF00
local TUYA_CMD_REPORT   = 0x02

-- Custom capability for distance measurement (no standard capability available)
-- Using standard pattern: namespace.capability-name format
local CAP_DISTANCE = capabilities["vehicleconnect17671.distancecm"]

local function to_bytes(payload)
  if payload == nil then return {} end
  if type(payload) == "string" then
    local t = {}
    for i=1,#payload do t[#t+1] = payload:byte(i) end
    return t
  end
  if type(payload) == "table" then
    if type(payload.value) == "string" then
      local t = {}
      for i=1,#payload.value do t[#t+1] = payload.value:byte(i) end
      return t
    end
    if #payload > 0 and type(payload[1]) == "number" then
      return payload
    end
  end
  return {}
end

local function u16_be(hi, lo) return (hi or 0) * 256 + (lo or 0) end
local function u32_be(b1,b2,b3,b4)
  return ((b1 or 0) * 16777216) + ((b2 or 0) * 65536) + ((b3 or 0) * 256) + (b4 or 0)
end

local function tuya_handler(driver, device, zb_rx)
  -- Extract body bytes from Zigbee message
  local body_bytes = nil
  if zb_rx and zb_rx.body and zb_rx.body.zcl_body then
    body_bytes = zb_rx.body.zcl_body.body_bytes
  end

  local b = to_bytes(body_bytes)
  if #b < 6 then
    log.warn("[aaaicu] Tuya message too short, ignoring")
    return
  end

  local dp    = b[3]
  local dtype = b[4]
  local len = u16_be(b[5], b[6])

  -- Validate payload length
  if #b < (6 + len) then
    log.warn(string.format("[aaaicu] Invalid payload length: expected %d bytes, got %d", 6 + len, #b))
    return
  end

  -- DP01: motion (type 0x04, len 1)
  if dp == 0x01 and dtype == 0x04 and len == 1 then
    local v = b[7]
    device:emit_event(capabilities.motionSensor.motion(v == 1 and "active" or "inactive"))
    log.info(string.format("[aaaicu] DP01 motion=%d", v))
    return
  end

  -- DP09: distance cm (type 0x02, len 4)
  if dp == 0x09 and dtype == 0x02 and len == 4 then
    if CAP_DISTANCE == nil then
      log.error("[aaaicu] CAP_DISTANCE is nil - capability id mismatch? Check profile configuration.")
      return
    end

    local distance_cm = u32_be(b[7], b[8], b[9], b[10])
    
    -- Emit distance event using standard pattern
    device:emit_event(CAP_DISTANCE.distance({ value = distance_cm, unit = "cm" }))
    log.info(string.format("[aaaicu] DP09 distance=%d cm", distance_cm))
    return
  end

  -- DP68: illuminance (type 0x02, len 4)
  if dp == 0x68 and dtype == 0x02 and len == 4 then
    local lux = u32_be(b[7], b[8], b[9], b[10])
    device:emit_event(capabilities.illuminanceMeasurement.illuminance(lux))
    log.info(string.format("[aaaicu] DP68 illuminance=%d", lux))
    return
  end
end

local zigbee_handlers = {
  cluster = {
    [TUYA_EF00_CLUSTER] = {
      [TUYA_CMD_REPORT] = tuya_handler
    }
  }
}

local driver = zigbee_driver("aaaicu-tuya-mmwave-presence", { zigbee_handlers = zigbee_handlers })
driver:run()
