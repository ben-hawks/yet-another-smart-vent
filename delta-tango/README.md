# Delta Tango (Thread edition)

A rewrite of [BrobstonCreations/delta-tango](https://github.com/BrobstonCreations/delta-tango)
for current ESPHome. It measures the HVAC **supply and return air
temperature** so Home Assistant can open the smart vents before restricted
airflow trips the furnace's high-limit switch or freezes the A/C coil.

## Why it matters with closed vents

Closing vents raises the duct pressure, which lowers blower airflow, which
raises the temperature rise across the heat exchanger. Example: an
Ameristar/Trane **M801P080BU36** (80k input, 63k output, **rated rise
30–60 °F**). From its product data:

| Fan speed tap | CFM @ 0.5 in. w.c. | Rise | CFM @ 0.7 in. w.c. | Rise |
|---|---|---|---|---|
| High | 1247 | ~47 °F | 1189 | ~49 °F |
| Medium-high | 1107 | ~53 °F | 1058 | ~55 °F |
| Medium-low | 973 | ~60 °F | 928 | **~63 °F** |
| Low | 842 | **~69 °F** | 808 | **~72 °F** |

(Rise ≈ output BTU/h ÷ (1.08 × CFM).) On the medium-low tap, this furnace
is already at the top of its range, and closing a few vents pushes it over.
Check which tap your furnace uses for heating (the wire on the control
board's HEAT terminal) and measure the real rise with all vents open first.

## What changed from the original

| Original | This version |
|---|---|
| D1 Mini (ESP8266), Wi-Fi | XIAO ESP32-C6, Thread **router** (strengthens the mesh for the battery vents) |
| Both DS18B20 probes on one bus, told apart by discovery order (can silently swap) | One probe per pin, so they can't swap |
| `dallas:` hub, bare `ota:` | `one_wire` + `dallas_temp`, `ota: platform: esphome` |
| Rise as return − supply | Rise as **supply − return** (positive when heating), in Δ°C and Δ°F, with no temperature device class so HA doesn't unit-convert a difference |
| No automation | Safety blueprint (below) |

## Hardware

**Parts list, wiring diagram, probe installation and commissioning steps: [BUILD.md](BUILD.md).**

- Seeed XIAO ESP32-C6 and a USB power adapter (furnaces usually have an
  outlet nearby)
- 2 × waterproof DS18B20 probes, each with a **4.7 kΩ** pull-up from DATA to 3V3
- Probe wiring: red → 3V3, black → GND, yellow (data) → D0 for supply, D1 for return

Probe placement:
- **Supply:** in the supply plenum, at least 12 in. downstream of the heat
  exchanger / A-coil and out of the burners' line of sight.
- **Return:** in the return duct, upstream of the filter.

Drill a small hole for each probe and seal it with foil tape.

## Firmware

`delta-tango-xiao-esp32c6.yaml`. Like the vents, it needs `thread_tlv` in
`secrets.yaml`.

## Home Assistant safety blueprint

[`home-assistant/blueprints/automation/smart_vent/hvac_vent_safety.yaml`](../home-assistant/blueprints/automation/smart_vent/hvac_vent_safety.yaml)
opens every listed vent when any of these hold for 2 minutes:

- **heating** and rise is above `max_rise_f` (default 57 °F, i.e. 3 °F under a 60 °F rated maximum)
- **cooling** and supply air is below `min_supply_temp` (default 4 °C), which risks coil icing
- the Delta Tango sensor has been **unavailable** for 5 minutes during a cycle

Import it in Home Assistant under **Settings → Automations & scenes →
Blueprints → Import blueprint**, using the file's GitHub URL.
