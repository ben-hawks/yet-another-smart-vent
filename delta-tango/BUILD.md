# Delta Tango: parts and build

One per furnace. It reads the supply and return air temperature, works
out the temperature rise, and feeds the vent safety blueprint. It's mains
powered, so it also acts as a Thread router near the furnace for the vents.

## Parts

Prices were looked up on DigiKey on 2026-11-01. "Check" means not confirmed.

| Part | Qty | Source | Part number | Price | Notes |
|---|---|---|---|---|---|
| Seeed XIAO ESP32-C6 | 1 | DigiKey | 1597-113991254-ND (113991254) | $5.38 | Same board as the vents |
| Waterproof DS18B20 probe | 2 | DigiKey / DFRobot | DFRobot DFR0198 | ~$6.90 each (check) | Stainless tip, 3-wire cable. Check the cable length reaches from the furnace to where the XIAO will sit |
| 4.7 kΩ resistor, 1/4 W through-hole | 2 | DigiKey | Stackpole CF14JT4K70 | $0.10 | One pull-up per probe |
| 3-position 3.5 mm screw terminal | 2 | DigiKey | ED2636-ND (On Shore OSTTE030161) | $0.97 | Lets you swap a probe without soldering. Optional |
| Small perfboard, ~30 × 50 mm | 1 | any | — | — | Or solder everything straight to the XIAO's pins |
| USB-C power supply, 5 V 1 A + cable | 1 | any | — | — | Plug into the outlet by the furnace |
| Enclosure | 1 | 3D print or a small project box | — | — | Anything that keeps dust off; mount it on the wall or a joist, **not** on the furnace cabinet |
| Foil HVAC tape (UL 181) or 1/4" grommets | — | hardware store | — | — | To seal the probe holes |

**About $21 total**, plus the power supply and enclosure.

## Wiring

Each probe gets its own XIAO pin, so supply and return can never be mixed
up. That was a weakness of the original Delta Tango.

| Probe wire | Supply probe | Return probe |
|---|---|---|
| Red (VDD) | 3V3 | 3V3 |
| Black (GND) | GND | GND |
| Yellow (DATA) | **D0** | **D1** |
| 4.7 kΩ pull-up | D0 → 3V3 | D1 → 3V3 |

```
            3V3 ──┬──────────┬───────────── red (both probes)
                  4.7k       4.7k
   D0 ────────────┘          │      ←── yellow, SUPPLY probe
   D1 ───────────────────────┘      ←── yellow, RETURN probe
            GND ─────────────────────── black (both probes)
```

Some probes use other colours (e.g. red/black/white, or red/green/yellow).
Check the probe's data sheet: one wire is power, one ground, one data.

## Installing the probes

**Safety first.**
- Only drill sheet-metal **ductwork**. Never drill the furnace cabinet,
  the A-coil (AC evaporator) housing or the flue/vent pipe.
- Turn the furnace off at its switch while you drill.
- Keep probe cables away from the burner compartment and flue.

1. **Supply probe:** in the supply plenum or the main supply trunk, at least
   12" (30 cm) downstream of the furnace and A-coil. It should be out of
   line of sight of the heat exchanger so it reads air, not radiant heat.
   Drill a 1/4" (6–7 mm) hole and push the tip about 2–3" into the airflow.
2. **Return probe:** in the return duct **before the filter**, away from any
   bypass damper or humidifier tap.
3. Seal both holes with foil tape or a grommet. Strain-relieve the cables
   with a zip tie or a tape tab, so a tug can't pull the tips out.
4. Mount the enclosure nearby and power it from the outlet.

## Firmware and Home Assistant

1. In your ESPHome dashboard, create a device from
   [`delta-tango-xiao-esp32c6.yaml`](delta-tango-xiao-esp32c6.yaml). Like the
   vents, it needs `thread_tlv` in `secrets.yaml`. Flash it over USB the
   first time. It joins Thread as a full Thread device, so it can route for
   the vents.
2. Adopt it in Home Assistant. You get *HVAC Supply Air Temperature*,
   *HVAC Return Air Temperature*, *HVAC Temperature Rise (C)* and
   *HVAC Temperature Rise (F)*.
3. Import the safety blueprint
   ([`../home-assistant/blueprints/automation/smart_vent/hvac_vent_safety.yaml`](../home-assistant/blueprints/automation/smart_vent/hvac_vent_safety.yaml))
   and create an automation from it with:
   - **Rise sensor:** *HVAC Temperature Rise (F)*
   - **Supply sensor:** *HVAC Supply Air Temperature*
   - **Max rise:** **57 °F**. The Ameristar M801P080BU36 is rated for a
     30–60 °F rise.
   - **Vents:** all the smart vents
4. In `tools/hvac_zones.py` (the `ha-dashboard` repo), set
   `RISE_SENSOR = "sensor.<your_device>_hvac_temperature_rise_f"` and re-run
   it, so the zoning controller also holds vents open on a high rise.

## Checking it

1. **Fan only (or system off):** both probes should agree within about
   0.5 °C after a few minutes. If not, check the wiring and that the supply
   probe isn't seeing radiant heat.
2. **Heating, all vents open:** after about 10 minutes the rise should
   settle inside the furnace's rated range (30–60 °F here). Note that
   number: it's your baseline.
   - If it's **above 55 °F with everything open**, the furnace is already
     airflow-starved, for example by a dirty filter or the blower's
     medium-low fan speed. Fix that before letting zoning close any vents.
3. **Swap test:** the supply reading should be the one that rises when the
   burner fires. If it's the return reading, the yellow wires are swapped
   between D0 and D1.
4. **Cooling (in season):** the rise goes negative, typically −15 to −22 °F.
   The blueprint opens vents if supply air drops below 4 °C (coil icing
   risk).
