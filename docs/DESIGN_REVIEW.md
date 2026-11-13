# Pre-production design review (2026-11-13)

Scope: the battery/Thread floor vent (2x12), the round ceiling vent, the
XIAO backpack board, the firmware, the Delta Tango and the Home Assistant
zoning logic, reviewed before ordering parts for about 20 vents.

**Nothing has been built or measured yet.** This review is from the design
files, datasheets and simulation-style checks (collision checks, DRC,
compiles). The [first-article checks](#first-article-checks) below are the
part a desk review can't replace.

## Summary

| # | Area | Finding | Severity | Status |
|---|---|---|---|---|
| 1 | Floor vent | Fully open sat on the linkage's dead point: the follower louver was uncontrolled there and could flip the wrong way | High | Fixed |
| 2 | Floor vent | Limit switch was pressed where 20° of louver travel moves the link under 0.5 mm, so "closed" could be 20° off | High | Fixed |
| 3 | Firmware | A flat cell could leave a vent shut for good | High | Fixed |
| 4 | Board | Load switch slew capacitor wired to GND and left off: turn-on inrush close to the part's 2.5 A pulse limit | High | Fixed in v0.2 |
| 5 | Board | No protection against a cell fitted backwards | High | Fixed in v0.2 |
| 6 | System | Free area of the floor grille was about 8.2 sq in, roughly half a stock register; the furnace is already at the top of its rise range | High | Improved to 10.3 sq in; see below |
| 7 | Zoning | An unreachable vent was counted as open for the airflow floor | Medium | Fixed |
| 8 | Firmware | No reaction to an overheating bay; no report of blocked louvers | Medium | Fixed |
| 9 | Firmware | Calibration trusted a limit switch that was already pressed (or shorted) | Medium | Fixed |
| 10 | Firmware | Maintenance Mode could show "on" with sleep re-enabled | Low | Fixed |
| 11 | System | Recharging over the XIAO's USB-C takes 35–40 hours per cell and has no temperature cut-off | Medium | Procedure: swap cells |
| 12 | System | Battery life rests on a sleep current nobody has measured on this firmware | High | Open: first-article check |
| 13 | System | Radio range from inside a sheet-metal boot is unknown | Medium | Open: first-article check; antenna option added |
| 14 | System | About 20 vents plus room sensors is 30+ sleepy Thread devices | Medium | Open: add mains-powered routers |
| 15 | Servo | Dimensions, feedback voltage, plug order and temperature rating come from conflicting or partial sources | Medium | Open: measure one before printing |
| 16 | Limit switch | The ESE-11HS2's lever geometry wasn't available; the pads allow for it with one parameter | Low | Open: check on the first print |
| 17 | Materials | PETG and ASA are not flame-retardant | Note | Your call; see Safety |

## System level

**Airflow is the main risk, not the electronics.** The Ameristar
M801P080BU36 is rated for a 30–60 °F rise and already runs near 60 °F on
its medium-low fan speed with every register open. Every vent this project
adds restricts airflow a little even when fully open, because a printed
grille has less free area than a stamped steel one.

- The floor grille now has about 10.3 sq in of free area (5 mm slots, 2 mm
  bars, full-width, with a centre spine). A stock 2x12 register is
  typically 12–15 sq in. The louver section behind it is about 13.6 sq in
  when open, so the grille is the limit.
- **Before installing any vents:** fit the Delta Tango, measure the rise
  with all registers open, and if it is above about 50 °F, move the
  furnace's heating fan speed up one tap (or have an HVAC tech do it). Then
  re-measure after the vents are in, all open. Zoning should only be turned
  on once the all-open rise has headroom.
- Layers that keep the furnace safe, outermost first: the furnace's own
  high-limit switch; the Delta Tango blueprint (opens everything at 57 °F
  rise, on a cold coil, or if the sensor is lost); the zoning controller
  (60% of registers stay open, unreachable vents count as closed, 30-minute
  hold-open after a high rise); and each vent on its own (opens on lost
  controller, low battery or an overheated bay).

**Battery life.** The budget is 0.25–0.45 mA average, or 9–14 months on a
3400 mAh cell. That assumes ESP-IDF's automatic light sleep engages
between Thread polls. An independent bench test of the XIAO ESP32-C6
measured about 0.22 mA for the whole board in light sleep (Seeed's own
table says 2.5–3.1 mA), so the budget is plausible, but it is the first
thing to measure. If light sleep doesn't engage, the board idles at
15–25 mA and a cell lasts about a week. `power_down_cpu: true` on
`smart_vent_power` is an untested option that may save a little more.

**Thread capacity.** Each router only accepts a limited number of sleepy
children (10 on a default OpenThread build; border routers vary), and it
has to buffer their messages. Twenty vents plus a TIMMERFLOTTE per room
needs several mains-powered Thread routers spread through the house. The
Delta Tango is one. A XIAO ESP32-C6 on a USB charger running the Delta
Tango firmware without probes makes another for about $6.

**Radio.** The floor vent's antenna sits below the floor inside a
sheet-metal boot, with the printed grille as its only window. It may be
fine; it may not. The firmware now has `external_antenna: 'true'` for a
U.FL antenna routed up under the flange. The ceiling vent's pod is outside
the duct and isn't affected.

**Recharging 20 vents.** The XIAO charges at about 100 mA, so a 3400 mAh
cell takes 35–40 hours. Plan on swapping cells and using an 18650 charger.
Buy a few spare cells.

**Firmware source.** The device file pulls its package from the fork's
default branch (`repo_ref: master`; it said `main`, which doesn't exist),
but this work is on `claude/wonderful-gauss-hco8hj`. Merge it, or set
`repo_ref` to that branch, before flashing the fleet.

## Board (v0.2)

- **Q1 (AO3401A)** in the battery line blocks a reversed cell or a
  mis-crimped plug. It conducts both ways when the cell is the right way
  round, so USB charging still works. It costs about 0.1 V at stall
  current. It can't protect against a reversed cell *and* USB plugged in at
  the same time.
- **C2** now goes from CT to VIN and is fitted (1 nF, about 1.6 ms rise).
  With CT open, the load switch rose in about 65 µs and charged C3–C5
  (66 µF) through the inductor and diode at roughly 2 A, against a 2.5 A
  pulse rating. Now it is about 0.15 A.
- Checked against datasheets: TPS22917 pinout, CT, QOD and ratings; MT3608
  pinout (pin 6 is unconnected, as it should be) and feedback divider;
  XIAO pin map and RF switch pins; none of the pins used is a strapping
  pin.
- At stall with a nearly flat cell the boost draws about 1.8 A from the
  cell, under the load switch's 2 A and well under the inductor's 4.6 A
  saturation current.
- The feedback divider (10k/20k) keeps the ADC pin at or under 3.4 V even
  if the servo's feedback wire reaches the full 5.1 V.
- Routing and an independent KiCad 10 review: see the board's
  [README](../hardware/xiao-backpack/README.md).

## Printed parts and mechanics

**Floor vent**

- The cranks now hang below the louvers and swing 45° either side of
  straight down. Checked for collisions between every pair of parts at 0°
  to 90° in 15° steps.
- The limit switch sits under a pad on the side wall and is pressed by the
  driven louver's outer edge, which moves about 0.2 mm per degree. A
  0.3 mm error in gluing it is about 1.5° of louver angle.
- The grille bars are 2 mm wide and 8 mm deep with a 22 mm span. That is
  fine for a foot, not for a stiletto heel or a chair leg; nor was the
  first draft.
- The flange stands 6 mm above the floor, a little more than a stamped
  register. Its edge is chamfered.
- The louvers' far-end and follower axles are M3 screws turning in plain
  holes. Left tight they bind the louver; left loose they can work out
  over thousands of cycles. The build guide now says to back off a quarter
  turn and lock the head.
- The tower leaves 14 mm under it in a 4" boot. If the duct joins the boot
  under the tower end, mirror the model so the tower sits at the other end.

**Round ceiling vent**

- Already used the 45° crank geometry and edge-sensed limit switch. The
  switch pad height is now a parameter (`sw_gap`).
- The louvers print on their straight edge; all STLs are watertight.
- Still to measure on the real vent: the screw circle, the duct's inside
  diameter and at least 34 mm of straight duct above the ceiling.

**Both**

- Mount the servo horn with the servo at its centre and the louvers half
  open. Calibration finds "closed" within about 120° of centre.
- The servo's mounting-hole spacing (27.8 mm), shaft offset (5.9 mm) and
  the height of its output boss are from generic micro-servo drawings, not
  Feetech's. Measure one servo and print `fit_test` before printing twenty
  bodies.

## Safety

- **Li-ion cell in the supply air (floor vent).** Normal supply air is
  37–54 °C; the cell is rated to 60 °C on discharge. The tower is closed
  and foam-lined, the cell is a protected type, and the vent opens itself
  if the bay passes about 60 °C. Heat shortens the cell's life (expect
  faster capacity loss than a room-temperature cell) but stays far below
  the 130 °C region where cells become dangerous. Never charge in place
  while the heat is running.
- **Plastics.** PETG softens near 80 °C and ASA near 100 °C, so both hold
  their shape. Neither is flame-retardant, and building codes generally
  expect materials in air ducts to be. Commercial plastic registers exist,
  so this is common practice rather than exotic, but if you want margin,
  print the floor vent's tower half (`body_left`) and lid in a V-0 rated
  filament (flame-retardant PETG or PC).
- **Wiring.** The cell's protection circuit is the only fuse. Keep the
  holder leads short, and zip-tie the holder so the cell can't shake loose.
- **Drilling for the Delta Tango:** ductwork only, never the furnace
  cabinet, coil housing or flue.

## First-article checks

Order the parts, but build and test **one** vent before assembling or
printing the rest. Details are in
[BATTERY_THREAD.md](BATTERY_THREAD.md#first-article-checks).

1. Measure a servo (body, tab holes, shaft offset, boss height, feedback
   voltage at both ends, plug order) and a limit switch. Adjust the `.scad`
   parameters, print `fit_test`, then one full vent.
2. Board: 5 V rail off at idle and about 5.1 V during a move; a reversed
   cell does nothing.
3. Sleep current under 0.5 mA averaged over a minute.
4. Calibration, 50 open/close cycles, and the `Blocked` sensor.
5. In the floor: stays connected and answers within a few seconds.
6. Furnace rise with the Delta Tango: all registers open, before and after
   fitting vents.
