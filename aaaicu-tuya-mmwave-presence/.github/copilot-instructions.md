# Copilot / AI agent instructions for aaaicu-tuya-mmwave-presence

Purpose
- Help AI coding agents be productive when changing or extending this SmartThings Edge Zigbee driver.

Quick overview
- Main entry: `src/init.lua` — a compact Zigbee Edge driver that registers a handler for Tuya cluster `0xEF00` command `0x02`.
- Config: `config.yaml` lists the profile in `profiles/` used by the driver.
- Profiles: `profiles/aaaicu-tuya-mmwave-presence.yaml` defines components and capabilities (includes a custom capability `vehicleconnect17671.distancecm`).
- Device matching: `fingerprints.yml` maps Zigbee manufacturer/model to the driver profile.
- UI: `distancecm.presentation.json` is a presentation file used to display the `distance` state.

Big-picture architecture & data flow
- Zigbee messages arrive at the Tuya EF00 cluster (0xEF00). `src/init.lua` converts the raw ZCL body into a byte array and dispatches by DP (data point) id.
- Important DPs parsed in `src/init.lua`:
  - DP01 (0x01): motion (type 0x04, len 1) → emits `motionSensor.motion` (active/inactive).
  - DP09 (0x09): distance (type 0x02, len 4) → 32-bit BE integer → emits `vehicleconnect17671.distancecm.distance` with `cm` unit.
  - DP68 (0x68): illuminance (type 0x02, len 4) → emits `illuminanceMeasurement.illuminance`.

What to preserve when editing
- Keep `to_bytes`, `u16_be`, `u32_be` helpers or replace with equivalent byte parsing — other logic depends on BE (big-endian) multi-byte reads.
- Preserve DP id / type / length checks before reading payload bytes to avoid out-of-range errors.

Project-specific conventions
- Capability naming: a custom capability `vehicleconnect17671.distancecm` is referenced from Lua; when adding capabilities, update `profiles/*.yaml` and any presentation JSON.
- Fingerprints are kept in `fingerprints.yml` rather than scattered; update it when adding support for new Tuya manufacturer strings.
- Driver name used in `zigbee_driver("aaaicu-tuya-mmwave-presence", ...)` should match `config.yaml.packageKey`.

Testing and local verification (discoverable patterns only)
- There is no included CI or packaging script in the repo. Typical edits are small: update `src/init.lua`, bump `profiles/` or `fingerprints.yml`, and test by deploying the driver using your normal SmartThings Edge toolchain.

Examples (copy/paste friendly)
- Emitting distance (from `src/init.lua`):
```
local distance_cm = u32_be(b[7], b[8], b[9], b[10])
device:emit_event(CAP_DISTANCE.distance({ value = distance_cm, unit = "cm" }))
```
- Motion parsing pattern:
```
if dp == 0x01 and dtype == 0x04 and len == 1 then
  local v = b[7]
  device:emit_event(capabilities.motionSensor.motion(v == 1 and "active" or "inactive"))
end
```

Where to look when something breaks
- `src/init.lua` for parsing logic and event emission.
- `profiles/` for capability wiring and `fingerprints.yml` for device-to-profile mapping.
- `distancecm.presentation.json` for UI/automation expectations of the `distance` value and unit.

Notes and restrictions for AI edits
- Don’t assume runtime deployment tooling — this repo lacks build scripts. Make small, reversible changes and reference the specific files above.
- Avoid changing capability IDs or driver package keys without updating `profiles/*.yaml` and `config.yaml` to keep them in sync.

If something is unclear
- Ask for device logs (Zigbee RX body payload bytes) and the SmartThings Edge deployment method the maintainer uses — both speed accurate fixes.

EOF
