# Bill of materials: battery/Thread 2x12 vent, 10 builds

Prices were looked up on 2026-11-01 and come from distributor search pages,
so check them in the cart before ordering. "Check" means the price, stock or
fit was not confirmed. **Qty** is for 10 vents, including spares where parts
are cheap. A spreadsheet version is in [`bom-10-vents.csv`](bom-10-vents.csv).

## Main parts

| Part | Per vent | Qty (10) | Source | Part number | Unit price | Notes |
|---|---|---|---|---|---|---|
| Seeed XIAO ESP32-C6 | 1 | 10 | DigiKey | 1597-113991254-ND (113991254) | $5.38 (qty 1) | No headers; solder your own |
| Feetech FT90M-FB servo (metal gear, analog feedback) | 1 | 10 | Alibaba | Feetech FT90M-FB | ~$6 | Rated −15 to 70 °C (the DFRobot SER0046 is only 50 °C). **Make sure it is the 4-wire -FB version**; RobotShop EU has it at €10.50 |
| Protected 18650 cell, 3400 mAh, button top | 1 | 10 | liionwholesale.com | SW34PCB (Sinowatt SW18650-34MP) | $6.37 (qty 10, your quote) | 69.1 × 18.6 mm. The page showed **out of stock** on 2026-11-01 |
| 18650 holder with wire leads | 1 | 10 | DigiKey | MPD BH-18650-W | $3.64 (check qty) | **Check that a 69.1 mm protected cell fits.** Order one first |
| Limit switch | 1 | 10 | DigiKey | P10865S-ND (Panasonic ESE-11HS2) | $0.376 | Same as upstream |

## Backpack PCB (`hardware/xiao-backpack`)

**Or skip this table and have JLCPCB assemble it.** Every SMD part has a
checked LCSC number in
[`hardware/xiao-backpack/fab/jlcpcb/`](../hardware/xiao-backpack/fab/jlcpcb)
(BOM + CPL): 11 Basic parts and 3 Extended. You then only hand-solder the
connectors and headers. See the board's README.

| Ref | Part | Per vent | Qty (10) | Source | Part number | Unit price @10 |
|---|---|---|---|---|---|---|
| — | PCB, 48 × 19 mm, 2-layer, 1.6 mm | 1 | 10 | JLCPCB / PCBWay / OSH Park | Gerbers in `hardware/xiao-backpack/fab/gerbers` | check (typically a few dollars for 5–10) |
| U1 | TPS22917DBVR load switch | 1 | 10 | DigiKey | 296-50498-1-ND | $0.407 |
| U2 | MT3608 boost converter | 1 | 12 | **LCSC** | C84817 | check (DigiKey doesn't stock it) |
| L1 | 10 µH 4.6 A Isat 52 mΩ shielded, 6 × 6 mm | 1 | 10 | DigiKey | SRN6045TA-100MCT-ND (Bourns SRN6045TA-100M) | $0.408 |
| D1 | 40 V 3 A Schottky, SMA | 1 | 10 | DigiKey | Diodes Inc B340A-13-F | $0.54 (check stock) |
| C3, C4, C5 | 22 µF 10 V X5R 1206 | 3 | 30 | DigiKey | 1276-1287-1-ND (Samsung CL31A226KPHNNNE) | $0.283 (10), $0.188 (100) |
| C1 | 1 µF 25 V X7R 0805 | 1 | 20 | DigiKey | 1276-1066-1-ND (CL21B105KAFNNNE) | $0.059 |
| C6, C7 | 100 nF 50 V X7R 0805 | 2 | 30 | DigiKey | 1276-1003-1-ND (CL21B104KBCNNNC) | $0.045 |
| R1, R4, R5 | 1 MΩ 1% 0805 | 3 | 50 | DigiKey | 311-1.00MCRCT-ND (Yageo RC0805FR-071ML) | $0.034 (10), $0.017 (100) |
| R2 | 51 kΩ 1% 0805 | 1 | 20 | DigiKey | Yageo RC0805FR-0751KL | ~same as above (check) |
| R3 | 6.8 kΩ 1% 0805 | 1 | 20 | DigiKey | Yageo RC0805FR-076K8L | ~same (check) |
| R6, R9 | 1 kΩ 1% 0805 | 2 | 30 | DigiKey | Yageo RC0805FR-071KL | ~same (check) |
| R7, R10 | 100 kΩ 1% 0805 | 2 | 30 | DigiKey | Yageo RC0805FR-07100KL | ~same (check) |
| R8 | 330 Ω 1% 0805 | 1 | 20 | DigiKey | Yageo RC0805FR-07330RL | ~same (check) |
| J1 | JST PH 2-pin vertical header | 1 | 12 | DigiKey | JST B2B-PH-K-S(LF)(SN) | $0.12 (check) |
| — | JST PH 2-pin housing + crimps (battery holder lead) | 1 + 2 | 12 + 30 | DigiKey | PHR-2 + SPH-002T-P0.5S | $0.10, ~$0.04 | Needs a crimper; or solder the holder leads straight into J1's holes |
| XIAO pins | 1×40 male breakaway header, 2.54 mm, straight | 0.5 | 5 | DigiKey | Pololu 965 or similar | ~$0.95–1.49 (qty 1) | XIAO is soldered directly to the backpack (no sockets) to fit the tower |
| J2, J3 | 1×40 male breakaway header, 2.54 mm, **right-angle** | 0.2 | 2 | DigiKey | any | check | 6 pins per board; plugs exit along the board edge |

The FT90M-FB has a 4th feedback wire alongside the usual three. Feetech
doesn't list its colours, so identify the wires on arrival. Check its plug against J2's pin order (GND, +5V, SIG, FB) and
re-pin it, or use a 4-pin housing, if they don't match.

## Hardware and printing

| Part | Per vent | Qty (10) | Source | Notes |
|---|---|---|---|---|
| M3 heat-set inserts, 4.6 OD × 5.7 mm | 9 | 90 | already on hand | |
| M3 × 8 flat-head (countersunk) screw | 6 | 60 | McMaster / Amazon assortment | DigiKey only listed marketplace seal screws |
| M3 × 10 flat-head screw | 2 | 20 | same | |
| M3 × 16 flat-head screw | 1 | 10 | same | Follower louver axle |
| ASA or PETG filament | about 150 g (estimate) | about 1.5 kg | any | **Not PLA**: gas-furnace supply air reaches 37–53 °C |
| 3 mm closed-cell foam, zip ties, 26 AWG wire | some | — | any | Tower liner, holder retention, BAT wires |

## Rough cost per vent

Known prices add up to about **$26 per vent**: XIAO $5.38, servo $6.30,
cell $6.37, holder $3.64, switch $0.38, and about $4.3 of board parts and
connectors. On top of that come the MT3608, the PCB, screws, filament (about
$3) and shipping, so expect roughly **$30–35 per vent** before shipping.

## Not on this list

- A Thread border router (you already have one).
- Delta Tango (one per furnace, about $21): see
  [`delta-tango/BUILD.md`](../delta-tango/BUILD.md).
