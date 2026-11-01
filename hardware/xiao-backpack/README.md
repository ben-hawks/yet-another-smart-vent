# Smart Vent XIAO backpack (KiCad)

A 48 × 19 mm two-layer board that holds all of the vent's auxiliary
circuitry. The XIAO ESP32-C6 plugs onto it with its two 1×7 headers.

![Routed board, top and bottom](fab/routed.png)

**Status: routed, ready for a first prototype order.** It was autorouted with
Freerouting 2.5.0 from `fab/smart_vent_backpack.dsn`, and the result is in
`fab/smart_vent_backpack.ses`. After importing:
- every net is connected (0 unconnected pads)
- KiCad 7 DRC reports 0 violations, against fab rules of 0.3 mm to the edge,
  0.15 mm clearance and 0.12 mm minimum track
- the PCB's netlist matches the schematic's

Power nets (GND, VBAT, VSW, SW, V5) are 0.6 mm, narrowing to 0.36–0.45 mm
only at pads. Ground is poured on both layers. Order with
[`fab/gerbers.zip`](fab/gerbers.zip) (2 layers, 1.6 mm, 1 oz, any colour).
This is an untested first revision, so order a small batch.

## Circuit

| Block | Parts | Notes |
|---|---|---|
| Battery in | J1 (JST-PH 2 mm), TP1/TP2 | TP1/TP2 are wire pads. Run short wires through the window to the XIAO's BAT+/BAT− pads, which charge the cell over USB-C |
| Servo power switch | U1 TPS22917 load switch, C1, C2 (soft start), R1 (keeps it off) | Cuts the cell off completely between moves (nanoamp leakage). Its ON pin is XIAO **D3** |
| 5 V boost | U2 MT3608, L1 10 µH, D1 SS34, C3–C5 22 µF, R2/R3 | Vout = 0.6 V × (1 + 75k/10k) = 5.1 V. Only powered while U1 is on |
| Servo | J2: GND, +5V, SIG, FB | SIG from **D2** through R8 (330 Ω). FB (0–3.3 V on the SER0046) through R6 1 kΩ to **D1**, with R7 100 kΩ pull-down and C7 filter |
| Battery sense | R4/R5 1M/1M, C6 | To **D0**. Draws about 2 µA |
| Limit switch | J3 | Fed from **D3** through R9 (1 kΩ), returns to **D4** with R10 (100 kΩ) pull-down. Only live while the servo is powered |

These pins match `common/smart-vent-thread-battery-base.yaml`, so the
firmware needs no changes.

## Building it

- All passives are 0805 (1206 for the 22 µF capacitors) with hand-solder
  pads. Both ICs are SOT-23-6. Parts list: [`fab/bom.csv`](fab/bom.csv).
- **Inductor:** any shielded 10 µH in 6 × 6 mm with a saturation current of
  2.5 A or more. A stalled servo pulls about 1.3 A from the cell through the
  boost converter.
- **Battery connector polarity:** JST-PH leads aren't standardized. Pin 1
  (square pad) is **+**. Check your cell's leads before plugging in.
- Mount the XIAO on the **top** with standard headers. Only the 0805 parts
  sit underneath it. Solder the battery wires to the XIAO's BAT pads before
  stacking the boards.

## Routing

`generate.py` builds everything from one parts table: the schematic (net
labels on every pin), the placed PCB, net classes (0.6 mm for power nets),
ground pours, Gerbers, the parts list, and the checks (schematic vs PCB
nets, DRC).

```bash
/usr/bin/python3 generate.py                              # place, write fab/smart_vent_backpack.dsn
# route fab/smart_vent_backpack.dsn with Freerouting (or similar) -> .ses
/usr/bin/python3 generate.py --ses fab/smart_vent_backpack.ses   # import routes, pour, DRC, Gerbers
# GND tracks that hug the battery window are dropped on import (the pours carry GND)
```

The router's output can also be imported straight into KiCad (**File →
Import → Specctra Session**) on the generated `.kicad_pcb`.

Requires KiCad 7 or later. Set `KICAD7_FOOTPRINT_DIR` if KiCad's global
libraries aren't configured.
