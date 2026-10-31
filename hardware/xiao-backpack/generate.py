#!/usr/bin/env python3
"""Generate the XIAO ESP32-C6 smart vent backpack (KiCad 7 project).

One table (PARTS) is the source of truth. From it this script writes:
  smart_vent_backpack.kicad_sch   schematic (net labels on every pin)
  smart_vent_backpack.kicad_pcb   placed, autorouted (Freerouting) PCB with
                                  ground pours on both layers
  smart_vent_backpack.kicad_pro   project + net classes
  lib/                            XIAO symbol and footprint
and then checks itself:
  - the schematic netlist (exported by kicad-cli) equals the PCB's nets
  - KiCad DRC on the routed board (report in fab/drc.rpt)

Needs KiCad 7+ (python3 pcbnew + kicad-cli). Routing is done by an external
autorouter through the Specctra DSN/SES files in fab/:
  /usr/bin/python3 generate.py                      place only; writes fab/*.dsn
  (route fab/smart_vent_backpack.dsn with Freerouting or similar -> .ses)
  /usr/bin/python3 generate.py --ses fab/smart_vent_backpack.ses
  /usr/bin/python3 generate.py --freerouting freerouting.jar   (runs it headless)
"""

import argparse
import math
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
NAME = "smart_vent_backpack"
KICAD_SYM = Path("/usr/share/kicad/symbols")
KICAD_FP = Path("/usr/share/kicad/footprints")
LIB = HERE / "lib"

BOARD_W, BOARD_H = 48.0, 19.0          # mm; XIAO is 21 x 17.8, at the right end
XIAO_C = (BOARD_W - 10.55, BOARD_H / 2)  # XIAO footprint origin (Seeed's)
# Window under the XIAO's BAT+/BAT- pads (near D5 / D8) for the battery wires.
WINDOW = (XIAO_C[0] - 7.4, BOARD_H / 2 - 3.5, XIAO_C[0] - 2.4, BOARD_H / 2 + 3.5)

R0805 = "Resistor_SMD:R_0805_2012Metric_Pad1.20x1.40mm_HandSolder"
C0805 = "Capacitor_SMD:C_0805_2012Metric_Pad1.18x1.45mm_HandSolder"
C1206 = "Capacitor_SMD:C_1206_3216Metric_Pad1.33x1.80mm_HandSolder"

# ref, symbol, value, footprint, {pin: net}, schematic (x, y), pcb (x, y, rot), extra fields
PARTS = [
    # --- XIAO (piggyback headers) ---
    ("U3", f"{NAME}:XIAO_ESP32C6", "XIAO ESP32-C6", f"{NAME}:XIAO_ESP32C6_Backpack",
     {"1": "VBAT_ADC", "2": "SRV_FB_ADC", "3": "SRV_PWM", "4": "SRV_EN", "5": "LIMIT",
      "6": None, "7": None, "8": None, "9": None, "10": None, "11": None,
      "12": None, "13": "GND", "14": None},
     (190.5, 63.5), (XIAO_C[0], XIAO_C[1], 0), {}),
    # --- battery in, load switch ---
    ("J1", "Connector_Generic:Conn_01x02", "Battery (JST-PH)",
     "Connector_JST:JST_PH_B2B-PH-K_1x02_P2.00mm_Vertical",
     {"1": "VBAT", "2": "GND"}, (25.4, 63.5), (6.6, 15.6, 180), {}),
    ("TP1", "Connector:TestPoint", "BAT+ to XIAO", "TestPoint:TestPoint_THTPad_1.5x1.5mm_Drill0.7mm",
     {"1": "VBAT"}, (25.4, 45.72), (WINDOW[0] - 1.9, 7.8, 0), {}),
    ("TP2", "Connector:TestPoint", "BAT- to XIAO", "TestPoint:TestPoint_THTPad_1.5x1.5mm_Drill0.7mm",
     {"1": "GND"}, (35.56, 45.72), (WINDOW[0] - 1.9, 11.2, 0), {}),
    ("U1", "Power_Management:TPS22917DBV", "TPS22917DBV", "Package_TO_SOT_SMD:SOT-23-6_Handsoldering",
     {"1": "VBAT", "2": "GND", "3": "SRV_EN", "4": "CT", "5": "VSW", "6": "VSW"},
     (66.04, 63.5), (5.2, 9.2, 0), {}),
    ("C1", "Device:C", "1u", C0805, {"1": "VBAT", "2": "GND"}, (45.72, 76.2), (1.6, 9.2, 90), {}),
    ("C2", "Device:C", "1n", C0805, {"1": "CT", "2": "GND"}, (50.8, 76.2), (8.6, 9.2, 90), {}),
    ("R1", "Device:R", "1M", R0805, {"1": "SRV_EN", "2": "GND"}, (55.88, 76.2), (38.6, 12.9, 90), {}),
    # --- 5 V boost ---
    ("U2", "Regulator_Switching:MT3608", "MT3608", "Package_TO_SOT_SMD:SOT-23-6_Handsoldering",
     {"1": "SW", "2": "GND", "3": "FB", "4": "VSW", "5": "VSW", "6": None},
     (106.68, 63.5), (12.4, 9.2, 0), {}),
    ("C3", "Device:C", "22u 10V", C1206, {"1": "VSW", "2": "GND"}, (88.9, 76.2), (12.4, 13.2, 0), {}),
    ("L1", "Device:L", "10u", "Inductor_SMD:L_Taiyo-Yuden_NR-60xx_HandSoldering",
     {"1": "VSW", "2": "SW"}, (101.6, 50.8), (19.0, 9.4, 0), {}),
    ("D1", "Device:D_Schottky", "SS34", "Diode_SMD:D_SMA_Handsoldering",
     {"1": "V5", "2": "SW"}, (124.46, 55.88), (19.0, 15.8, 180), {}),
    ("R2", "Device:R", "75k", R0805, {"1": "V5", "2": "FB"}, (124.46, 68.58), (15.4, 5.1, 0), {}),
    ("R3", "Device:R", "10k", R0805, {"1": "FB", "2": "GND"}, (124.46, 78.74), (10.8, 5.1, 0), {}),
    ("C4", "Device:C", "22u 10V", C1206, {"1": "V5", "2": "GND"}, (137.16, 68.58), (24.6, 7.1, 90), {}),
    ("C5", "Device:C", "22u 10V", C1206, {"1": "V5", "2": "GND"}, (144.78, 68.58), (24.6, 12.5, 90), {}),
    # --- servo connector, feedback divider, PWM ---
    ("J2", "Connector_Generic:Conn_01x04", "Servo (GND +5V SIG FB)",
     "Connector_PinHeader_2.54mm:PinHeader_1x04_P2.54mm_Vertical",
     {"1": "GND", "2": "V5", "3": "SRV_SIG", "4": "SRV_FB"}, (160.02, 30.48), (2.0, 1.9, 90), {}),
    ("R8", "Device:R", "330", R0805, {"1": "SRV_PWM", "2": "SRV_SIG"}, (170.18, 45.72), (41.2, 5.8, 90), {}),
    ("R6", "Device:R", "10k", R0805, {"1": "SRV_FB", "2": "SRV_FB_ADC"}, (149.86, 88.9), (43.6, 5.8, 90), {}),
    ("R7", "Device:R", "20k", R0805, {"1": "SRV_FB_ADC", "2": "GND"}, (157.48, 88.9), (43.6, 9.5, 90), {}),
    ("C7", "Device:C", "100n", C0805, {"1": "SRV_FB_ADC", "2": "GND"}, (165.1, 88.9), (43.6, 13.2, 90), {}),
    # --- battery voltage divider ---
    ("R4", "Device:R", "1M", R0805, {"1": "VBAT", "2": "VBAT_ADC"}, (35.56, 88.9), (46.2, 5.8, 90), {}),
    ("R5", "Device:R", "1M", R0805, {"1": "VBAT_ADC", "2": "GND"}, (43.18, 88.9), (46.2, 9.5, 90), {}),
    ("C6", "Device:C", "100n", C0805, {"1": "VBAT_ADC", "2": "GND"}, (50.8, 88.9), (46.2, 13.2, 90), {}),
    # --- limit switch ---
    ("J3", "Connector_Generic:Conn_01x02", "Limit switch", "Connector_PinHeader_2.54mm:PinHeader_1x02_P2.54mm_Vertical",
     {"1": "LIM_PWR", "2": "LIMIT"}, (203.2, 30.48), (13.6, 1.9, 90), {}),
    ("R9", "Device:R", "1k", R0805, {"1": "SRV_EN", "2": "LIM_PWR"}, (190.5, 99.06), (38.6, 5.8, 90), {}),
    ("R10", "Device:R", "100k", R0805, {"1": "LIMIT", "2": "GND"}, (198.12, 99.06), (41.2, 9.5, 90), {}),
    # --- ERC helpers (schematic only) ---
    ("#FLG1", "power:PWR_FLAG", "PWR_FLAG", "", {"1": "VBAT"}, (25.4, 30.48), None, {}),
    ("#FLG2", "power:PWR_FLAG", "PWR_FLAG", "", {"1": "GND"}, (35.56, 30.48), None, {}),
]

# PCB placement (x, y, rotation) in mm, origin top-left, y down. The XIAO
# sits on top at the right-hand end with USB-C at the board edge; only
# low parts (0805s) go underneath it. Connectors run along the top edge
# of the extension (the end that points up inside the vent's tower).
PLACE = {
    "U3": (XIAO_C[0], XIAO_C[1], 0),
    # extension: connectors, load switch, boost
    "J2": (2.0, 1.9, 90), "J3": (13.6, 1.9, 90), "J1": (6.6, 16.0, 180),
    "C1": (1.4, 9.5, 90), "U1": (5.0, 9.5, 0), "C2": (8.6, 9.5, 90),
    "R3": (10.4, 5.3, 0), "R2": (15.2, 5.3, 0),
    "U2": (12.2, 9.5, 0), "C3": (12.2, 13.6, 0),
    "L1": (20.0, 9.5, 0), "D1": (19.5, 16.3, 180),
    "C4": (25.6, 6.6, 90), "C5": (25.6, 12.4, 90),
    "TP1": (WINDOW[0] - 1.6, 7.0, 0), "TP2": (WINDOW[0] - 1.6, 12.0, 0),
    # under the XIAO, next to the pins they serve (D0..D4 run along the top)
    "R4": (46.4, 5.4, 90), "R5": (46.4, 9.5, 90), "C6": (46.4, 13.6, 90),
    "R6": (43.8, 5.4, 90), "R7": (43.8, 9.5, 90), "C7": (43.8, 13.6, 90),
    "R8": (41.2, 5.4, 90), "R10": (41.2, 9.5, 90),
    "R9": (38.6, 5.4, 90), "R1": (38.6, 9.5, 90),
}

NET_CLASSES = {
    "Power": {"nets": ["VBAT", "GND", "VSW", "SW", "V5"], "track": 0.6, "clearance": 0.2},
}
DEFAULT_TRACK, DEFAULT_CLEARANCE = 0.25, 0.2
VIA_D, VIA_DRILL = 0.6, 0.3


def uid():
    return str(uuid.uuid4())


# =================================================================== s-expr

def find_block(text, start):
    """Return the balanced (...) block starting at text[start]."""
    depth, i, in_str = 0, start, False
    while i < len(text):
        ch = text[i]
        if in_str:
            if ch == "\\":
                i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    raise ValueError("unbalanced")


def lib_symbol(lib_id):
    lib, name = lib_id.split(":")
    path = LIB / f"{NAME}.kicad_sym" if lib == NAME else KICAD_SYM / f"{lib}.kicad_sym"
    text = path.read_text()
    m = re.search(r'\n\s*\(symbol "' + re.escape(name) + r'"', text)
    block = find_block(text, text.index("(", m.start()))
    return block.replace(f'(symbol "{name}"', f'(symbol "{lib_id}"', 1)


def symbol_pins(block):
    """pin number -> (x, y, angle) for unit 1 / body style 1 (and shared unit 0)."""
    pins = {}
    for sub in re.finditer(r'\(symbol "[^"]*_(\d+)_(\d+)"', block):
        unit, style = int(sub.group(1)), int(sub.group(2))
        if unit not in (0, 1) or style not in (0, 1):
            continue
        sb = find_block(block, sub.start())
        for p in re.finditer(r'\(pin \w+ \w+\s*\(at ([-\d.]+) ([-\d.]+) (\d+)\)', sb):
            pb = find_block(sb, p.start())
            num = re.search(r'\(number "([^"]*)"', pb).group(1)
            pins[num] = (float(p.group(1)), float(p.group(2)), int(p.group(3)))
    return pins


# =================================================================== library

def write_library():
    LIB.mkdir(exist_ok=True)
    left = [("1", "D0/A0"), ("2", "D1/A1"), ("3", "D2/A2"), ("4", "D3"), ("5", "D4/SDA"),
            ("6", "D5/SCL"), ("7", "D6/TX")]
    right = [("14", "5V"), ("13", "GND"), ("12", "3V3"), ("11", "D10/MOSI"), ("10", "D9/MISO"),
             ("9", "D8/SCK"), ("8", "D7/RX")]
    types = {"13": "power_in", "14": "power_in", "12": "power_out"}
    pins = []
    for i, (n, nm) in enumerate(left):
        pins.append(f'(pin {types.get(n, "bidirectional")} line (at -15.24 {7.62 - 2.54 * i:.2f} 0) (length 2.54) '
                    f'(name "{nm}" (effects (font (size 1.27 1.27)))) (number "{n}" (effects (font (size 1.27 1.27)))))')
    for i, (n, nm) in enumerate(right):
        pins.append(f'(pin {types.get(n, "bidirectional")} line (at 15.24 {7.62 - 2.54 * i:.2f} 180) (length 2.54) '
                    f'(name "{nm}" (effects (font (size 1.27 1.27)))) (number "{n}" (effects (font (size 1.27 1.27)))))')
    sym = f'''(kicad_symbol_lib (version 20220914) (generator {NAME}_generate)
  (symbol "XIAO_ESP32C6" (in_bom no) (on_board yes)
    (property "Reference" "U" (at 0 11.43 0) (effects (font (size 1.27 1.27))))
    (property "Value" "XIAO ESP32-C6" (at 0 -11.43 0) (effects (font (size 1.27 1.27))))
    (property "Footprint" "{NAME}:XIAO_ESP32C6_Backpack" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))
    (property "Datasheet" "https://wiki.seeedstudio.com/xiao_esp32c6_getting_started/" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))
    (property "ki_description" "Seeed Studio XIAO ESP32-C6, mounted on 2x 1x7 headers (not part of this board's BOM)" (at 0 0 0) (effects (font (size 1.27 1.27)) hide))
    (symbol "XIAO_ESP32C6_0_1"
      (rectangle (start -12.7 10.16) (end 12.7 -10.16) (stroke (width 0.254) (type default)) (fill (type background))))
    (symbol "XIAO_ESP32C6_1_1"
      {chr(10).join("      " + p for p in pins)}))
)
'''
    (LIB / f"{NAME}.kicad_sym").write_text(sym)

    # Footprint: XIAO through-hole pins, same geometry as Seeed's
    # XIAO-ESP32-C6 footprint (pin 1 = D0 at the USB end, USB-C toward +X).
    pads = []
    for i in range(7):
        pads.append((str(i + 1), 7.62 - 2.54 * i, -7.62))
        pads.append((str(i + 8), -7.62 + 2.54 * i, 7.62))
    pad_txt = "\n".join(
        f'  (pad "{n}" thru_hole {"rect" if n == "1" else "circle"} (at {x:.2f} {y:.2f}) (size 1.7 1.7) '
        f'(drill 1.0) (layers "*.Cu" "*.Mask") (tstamp {uid()}))' for n, x, y in pads)
    fp = f'''(footprint "XIAO_ESP32C6_Backpack" (version 20221018) (generator {NAME}_generate)
  (layer "F.Cu")
  (descr "Seeed XIAO ESP32-C6 on 2x 1x7 2.54 mm headers, mounted on top. USB-C toward +X.")
  (attr through_hole exclude_from_bom)
  (fp_text reference "U3" (at -6 0 90) (layer "F.Fab") (effects (font (size 0.8 0.8) (thickness 0.12))) (tstamp {uid()}))
  (fp_text value "XIAO ESP32-C6" (at 0 0) (layer "F.Fab") (effects (font (size 0.8 0.8) (thickness 0.12))) (tstamp {uid()}))
  (fp_rect (start -10.425 -8.9) (end 10.55 8.9) (stroke (width 0.1) (type default)) (fill none) (layer "F.Fab") (tstamp {uid()}))
  (fp_rect (start 10.55 -4.5) (end 12.05 4.5) (stroke (width 0.1) (type default)) (fill none) (layer "F.Fab") (tstamp {uid()}))
  (fp_text user "USB-C" (at 9 0 90) (layer "F.Fab") (effects (font (size 0.8 0.8) (thickness 0.12))) (tstamp {uid()}))
  (fp_text user "XIAO" (at 3 0) (layer "F.Fab") (effects (font (size 1 1) (thickness 0.15))) (tstamp {uid()}))
  (fp_rect (start -8.95 -8.95) (end 8.95 -6.29) (stroke (width 0.05) (type default)) (fill none) (layer "F.CrtYd") (tstamp {uid()}))
  (fp_rect (start -8.95 6.29) (end 8.95 8.95) (stroke (width 0.05) (type default)) (fill none) (layer "F.CrtYd") (tstamp {uid()}))
  (fp_line (start 9.2 -8.4) (end 9.2 -6.8) (stroke (width 0.15) (type default)) (layer "F.SilkS") (tstamp {uid()}))
{pad_txt}
)
'''
    pretty = LIB / f"{NAME}.pretty"
    pretty.mkdir(exist_ok=True)
    (pretty / "XIAO_ESP32C6_Backpack.kicad_mod").write_text(fp)

    (HERE / "sym-lib-table").write_text(
        f'(sym_lib_table\n  (lib (name "{NAME}")(type "KiCad")(uri "${{KIPRJMOD}}/lib/{NAME}.kicad_sym")(options "")(descr ""))\n)\n')
    (HERE / "fp-lib-table").write_text(
        f'(fp_lib_table\n  (lib (name "{NAME}")(type "KiCad")(uri "${{KIPRJMOD}}/lib/{NAME}.pretty")(options "")(descr ""))\n)\n')


# =================================================================== schematic

def esc(s):
    return s.replace('"', '\\"')


def write_schematic():
    root = uid()
    lib_ids = sorted({p[1] for p in PARTS})
    blocks = {lid: lib_symbol(lid) for lid in lib_ids}
    items = []
    for ref, lid, value, fp, pinmap, (sx, sy), _pcb, _ in PARTS:
        pins = symbol_pins(blocks[lid])
        in_bom = "no" if ref.startswith("#") or ref == "U3" else "yes"
        props = [
            f'(property "Reference" "{ref}" (at {sx} {sy - 6.35} 0) (effects (font (size 1.27 1.27)){" hide" if ref.startswith("#") else ""}))',
            f'(property "Value" "{esc(value)}" (at {sx} {sy + 6.35} 0) (effects (font (size 1.27 1.27))))',
            f'(property "Footprint" "{fp}" (at {sx} {sy} 0) (effects (font (size 1.27 1.27)) hide))',
            f'(property "Datasheet" "" (at {sx} {sy} 0) (effects (font (size 1.27 1.27)) hide))',
        ]
        pin_txt = " ".join(f'(pin "{n}" (uuid {uid()}))' for n in pins)
        items.append(
            f'  (symbol (lib_id "{lid}") (at {sx} {sy} 0) (unit 1) (in_bom {in_bom}) (on_board {"no" if ref.startswith("#") else "yes"}) (dnp no) (uuid {uid()})\n    '
            + "\n    ".join(props) + f"\n    {pin_txt}\n"
            f'    (instances (project "{NAME}" (path "/{root}" (reference "{ref}") (unit 1)))))')
        for num, (px, py, ang) in pins.items():
            x, y = round(sx + px, 2), round(sy - py, 2)
            net = pinmap.get(num)
            if net is None:
                items.append(f'  (no_connect (at {x} {y}) (uuid {uid()}))')
                continue
            if ref.startswith("#FLG") or lid == "power:GND":
                pass
            la = {0: 180, 180: 0, 90: 270, 270: 90}[ang]
            just = {180: "right", 0: "left", 90: "left", 270: "right"}[la]
            items.append(f'  (label "{net}" (at {x} {y} {la}) (fields_autoplaced) '
                         f'(effects (font (size 1.27 1.27)) (justify {just})) (uuid {uid()}))')
    notes = [
        ("Smart vent backpack for Seeed XIAO ESP32-C6 (generated by generate.py)", 25.4, 15.24),
        ("Servo power: TPS22917 cuts the cell off completely (nA leakage), MT3608 boosts to 5.1 V.", 25.4, 20.32),
        ("Vout = 0.6 V x (1 + 75k/10k) = 5.1 V.  D3 (SRV_EN) also feeds the limit switch through R9.", 25.4, 22.86),
        ("Wire TP1/TP2 to the XIAO's BAT+/BAT- pads through the board's window.", 25.4, 25.4),
    ]
    for t, x, y in notes:
        items.append(f'  (text "{esc(t)}" (at {x} {y} 0) (effects (font (size 1.27 1.27)) (justify left)) (uuid {uid()}))')
    sch = (f'(kicad_sch (version 20230121) (generator eeschema)\n  (uuid {root})\n  (paper "A4")\n'
           f'  (title_block (title "Smart Vent XIAO Backpack") (rev "0.1") (company "ben-hawks/yet-another-smart-vent"))\n'
           "  (lib_symbols\n" + "\n".join("    " + b for b in blocks.values()) + "\n  )\n"
           + "\n".join(items)
           + f'\n  (sheet_instances (path "/" (page "1")))\n)\n')
    (HERE / f"{NAME}.kicad_sch").write_text(sch)


# =================================================================== project

def write_project():
    import json
    pro = {
        "board": {"design_settings": {"defaults": {}, "rules": {
            "min_clearance": 0.15, "min_track_width": 0.2, "min_via_diameter": 0.5,
            "min_through_hole_diameter": 0.3, "min_copper_edge_clearance": 0.3}}},
        "meta": {"filename": f"{NAME}.kicad_pro", "version": 1},
        "net_settings": {
            "classes": [
                {"name": "Default", "clearance": DEFAULT_CLEARANCE, "track_width": DEFAULT_TRACK,
                 "via_diameter": VIA_D, "via_drill": VIA_DRILL, "wire_width": 6, "bus_width": 12,
                 "diff_pair_gap": 0.25, "diff_pair_via_gap": 0.25, "diff_pair_width": 0.2,
                 "microvia_diameter": 0.3, "microvia_drill": 0.1, "line_style": 0, "pcb_color": "rgba(0, 0, 0, 0.000)",
                 "schematic_color": "rgba(0, 0, 0, 0.000)"},
            ] + [
                {"name": n, "clearance": c["clearance"], "track_width": c["track"],
                 "via_diameter": 0.8, "via_drill": 0.4, "wire_width": 6, "bus_width": 12,
                 "diff_pair_gap": 0.25, "diff_pair_via_gap": 0.25, "diff_pair_width": 0.2,
                 "microvia_diameter": 0.3, "microvia_drill": 0.1, "line_style": 0, "pcb_color": "rgba(0, 0, 0, 0.000)",
                 "schematic_color": "rgba(0, 0, 0, 0.000)"} for n, c in NET_CLASSES.items()],
            "meta": {"version": 3},
            "net_colors": None,
            "netclass_assignments": None,
            "netclass_patterns": [{"netclass": n, "pattern": net}
                                  for n, c in NET_CLASSES.items() for net in c["nets"]],
        },
        "schematic": {"legacy_lib_dir": "", "legacy_lib_list": []},
        "sheets": [], "text_variables": {},
    }
    (HERE / f"{NAME}.kicad_pro").write_text(json.dumps(pro, indent=2))


# =================================================================== PCB

def build_pcb(freerouting_jar=None, ses_in=None):
    import pcbnew

    board = pcbnew.BOARD()
    ds = board.GetDesignSettings()
    ds.SetCopperLayerCount(2)
    ns = ds.m_NetSettings
    dflt = ns.m_DefaultNetClass
    dflt.SetTrackWidth(pcbnew.FromMM(DEFAULT_TRACK))
    dflt.SetClearance(pcbnew.FromMM(DEFAULT_CLEARANCE))
    dflt.SetViaDiameter(pcbnew.FromMM(VIA_D))
    dflt.SetViaDrill(pcbnew.FromMM(VIA_DRILL))
    for cname, c in NET_CLASSES.items():
        nc = pcbnew.NETCLASS(cname)
        nc.SetTrackWidth(pcbnew.FromMM(c["track"]))
        nc.SetClearance(pcbnew.FromMM(c["clearance"]))
        nc.SetViaDiameter(pcbnew.FromMM(0.8))
        nc.SetViaDrill(pcbnew.FromMM(0.4))
        ns.m_NetClasses[cname] = nc

    nets = {}

    def net(name):
        if name not in nets:
            ni = pcbnew.NETINFO_ITEM(board, name)
            board.Add(ni)
            nets[name] = ni
        return nets[name]

    power_of = {n: c for c, v in NET_CLASSES.items() for n in v["nets"]}
    for _, _, _, _, pinmap, _, pcb, _ in PARTS:
        if pcb:
            for n in pinmap.values():
                if n:
                    net(n)
    for name, ni in nets.items():
        if name in power_of:
            ni.SetNetClass(ns.m_NetClasses[power_of[name]])

    for ref, lid, value, fpid, pinmap, _, pcb, _ in PARTS:
        if not pcb:
            continue
        pcb = PLACE[ref]
        lib, fpname = fpid.split(":")
        libdir = str(LIB / f"{NAME}.pretty") if lib == NAME else str(KICAD_FP / f"{lib}.pretty")
        fp = pcbnew.FootprintLoad(libdir, fpname)
        fp.SetReference(ref)
        fp.SetValue(value)
        fp.SetFPIDAsString(fpid)
        x, y, rot = pcb
        fp.SetPosition(pcbnew.VECTOR2I(pcbnew.FromMM(x), pcbnew.FromMM(y)))
        fp.SetOrientationDegrees(rot)
        for pad in fp.Pads():
            n = pinmap.get(pad.GetNumber())
            if n:
                pad.SetNet(nets[n])
        # Reference designators go on the assembly (Fab) layer: the board is
        # too dense for silkscreen ones. fab/assembly.svg shows them.
        fp.Reference().SetLayer(pcbnew.F_Fab)
        fp.Reference().SetTextSize(pcbnew.VECTOR2I(pcbnew.FromMM(0.8), pcbnew.FromMM(0.8)))
        fp.Reference().SetTextThickness(pcbnew.FromMM(0.12))
        fp.Value().SetVisible(False)
        board.Add(fp)

    # outline with rounded corners + battery-wire window
    def edge_line(a, b):
        s = pcbnew.PCB_SHAPE(board)
        s.SetShape(pcbnew.SHAPE_T_SEGMENT)
        s.SetStart(pcbnew.VECTOR2I(pcbnew.FromMM(a[0]), pcbnew.FromMM(a[1])))
        s.SetEnd(pcbnew.VECTOR2I(pcbnew.FromMM(b[0]), pcbnew.FromMM(b[1])))
        s.SetLayer(pcbnew.Edge_Cuts)
        s.SetWidth(pcbnew.FromMM(0.1))
        board.Add(s)

    def edge_arc(c, start, angle):
        s = pcbnew.PCB_SHAPE(board)
        s.SetShape(pcbnew.SHAPE_T_ARC)
        s.SetCenter(pcbnew.VECTOR2I(pcbnew.FromMM(c[0]), pcbnew.FromMM(c[1])))
        s.SetStart(pcbnew.VECTOR2I(pcbnew.FromMM(start[0]), pcbnew.FromMM(start[1])))
        s.SetArcAngleAndEnd(pcbnew.EDA_ANGLE(angle, pcbnew.DEGREES_T), True)
        s.SetLayer(pcbnew.Edge_Cuts)
        s.SetWidth(pcbnew.FromMM(0.1))
        board.Add(s)

    r = 1.0
    W, H = BOARD_W, BOARD_H
    edge_line((r, 0), (W - r, 0)); edge_line((W, r), (W, H - r))
    edge_line((W - r, H), (r, H)); edge_line((0, H - r), (0, r))
    edge_arc((W - r, r), (W - r, 0), 90); edge_arc((W - r, H - r), (W, H - r), 90)
    edge_arc((r, H - r), (r, H), 90); edge_arc((r, r), (0, r), 90)
    x0, y0, x1, y1 = WINDOW
    edge_line((x0, y0), (x1, y0)); edge_line((x1, y0), (x1, y1))
    edge_line((x1, y1), (x0, y1)); edge_line((x0, y1), (x0, y0))

    # silkscreen labels
    def silk(text, x, y, size=0.8, layer=pcbnew.F_SilkS, angle=0):
        t = pcbnew.PCB_TEXT(board)
        t.SetText(text)
        t.SetPosition(pcbnew.VECTOR2I(pcbnew.FromMM(x), pcbnew.FromMM(y)))
        t.SetTextSize(pcbnew.VECTOR2I(pcbnew.FromMM(size), pcbnew.FromMM(size)))
        t.SetTextThickness(pcbnew.FromMM(0.12))
        t.SetLayer(layer)
        t.SetTextAngle(pcbnew.EDA_ANGLE(angle, pcbnew.DEGREES_T))
        if layer == pcbnew.B_SilkS:
            t.SetMirrored(True)
        board.Add(t)

    silk("SMART VENT  v0.1", 12.5, BOARD_H - 1.3, 0.8, pcbnew.B_SilkS)
    silk("BAT", (x0 + x1) / 2, y1 + 1.1, 0.8, pcbnew.B_SilkS)

    pcb_path = HERE / f"{NAME}.kicad_pcb"
    board.Save(str(pcb_path))

    # ---- autoroute
    dsn = HERE / "fab" / f"{NAME}.dsn"
    ses = HERE / "fab" / f"{NAME}.ses"
    dsn.parent.mkdir(exist_ok=True)
    if not pcbnew.ExportSpecctraDSN(board, str(dsn)):
        sys.exit("DSN export failed")
    if freerouting_jar:
        if ses.exists():
            ses.unlink()
        subprocess.run(["java", "-jar", freerouting_jar, "-de", str(dsn), "-do", str(ses),
                        "-mp", "40"], check=False, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=900)
        if not ses.exists():
            sys.exit("Freerouting produced no .ses")
        ses_in = ses
    if ses_in:
        n_tracks, n_vias = import_ses(board, Path(ses_in), nets)
        print(f"routed: {n_tracks} track segments, {n_vias} vias")
    else:
        print(f"not routed: route {dsn.relative_to(HERE)} and re-run with --ses <file>")

    # ---- ground pours on both layers. The zone filler is only reliable on a
    # board loaded from disk, so save and reload first.
    board.Save(str(pcb_path))
    board = pcbnew.LoadBoard(str(pcb_path))
    board.BuildConnectivity()
    nets = {n: board.FindNet(n) for n in nets}
    for layer in (pcbnew.F_Cu, pcbnew.B_Cu):
        z = pcbnew.ZONE(board)
        z.SetLayer(layer)
        z.SetNet(nets["GND"])
        z.SetLocalClearance(pcbnew.FromMM(0.3))
        z.SetMinThickness(pcbnew.FromMM(0.25))
        z.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
        z.SetThermalReliefGap(pcbnew.FromMM(0.3))
        z.SetThermalReliefSpokeWidth(pcbnew.FromMM(0.4))
        outline = z.Outline()
        outline.NewOutline()
        for px, py in ((0, 0), (W, 0), (W, H), (0, H)):
            outline.Append(pcbnew.FromMM(px), pcbnew.FromMM(py))
        board.Add(z)
    pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    board.Save(str(pcb_path))
    return pcb_path


def import_ses(board, ses_path, nets):
    import pcbnew
    text = ses_path.read_text()
    res = re.search(r"\(resolution (\w+) (\d+)\)", text)
    unit, div = res.group(1), int(res.group(2))
    scale_mm = {"um": 0.001, "mm": 1.0, "mil": 0.0254, "inch": 25.4}[unit] / div

    def pt(x, y):
        return pcbnew.VECTOR2I(pcbnew.FromMM(float(x) * scale_mm), pcbnew.FromMM(-float(y) * scale_mm))

    layers = {"F.Cu": pcbnew.F_Cu, "B.Cu": pcbnew.B_Cu}
    n_t = n_v = 0
    net_out = text[text.index("(network_out"):]
    for m in re.finditer(r'\(net "?([^"\s)]+)"?', net_out):
        blk = find_block(net_out, m.start())
        ni = nets.get(m.group(1))
        if ni is None:
            continue
        for w in re.finditer(r"\(path (\S+) ([\d.]+)((?:\s+-?[\d.]+)+)\)", blk):
            layer, width = w.group(1), float(w.group(2)) * scale_mm
            coords = w.group(3).split()
            ps = [pt(coords[i], coords[i + 1]) for i in range(0, len(coords), 2)]
            for a, b in zip(ps, ps[1:]):
                t = pcbnew.PCB_TRACK(board)
                t.SetStart(a)
                t.SetEnd(b)
                t.SetWidth(pcbnew.FromMM(width))
                t.SetLayer(layers[layer])
                t.SetNet(ni)
                board.Add(t)
                n_t += 1
        for v in re.finditer(r'\(via "?([^"\s]+)"? (-?[\d.]+) (-?[\d.]+)', blk):
            name = v.group(1)
            dims = re.findall(r"(\d+)", name.split("_")[-2] if "_" in name else "")
            via = pcbnew.PCB_VIA(board)
            via.SetPosition(pt(v.group(2), v.group(3)))
            mm = re.search(r"(\d+):(\d+)_um", name)
            d, drill = (int(mm.group(1)) / 1000, int(mm.group(2)) / 1000) if mm else (VIA_D, VIA_DRILL)
            via.SetWidth(pcbnew.FromMM(d))
            via.SetDrill(pcbnew.FromMM(drill))
            via.SetNet(ni)
            board.Add(via)
            n_v += 1
    return n_t, n_v


# =================================================================== checks / outputs

def pcb_nets(pcb_path):
    import pcbnew
    board = pcbnew.LoadBoard(str(pcb_path))
    out = {}
    for fp in board.GetFootprints():
        for pad in fp.Pads():
            n = pad.GetNetname()
            if n:
                out.setdefault(n, set()).add(f"{fp.GetReference()}.{pad.GetNumber()}")
    return out


def sch_nets():
    xml = HERE / "fab" / f"{NAME}.net.xml"
    subprocess.run(["kicad-cli", "sch", "export", "netlist", "--format", "kicadxml", "-o", str(xml),
                    str(HERE / f"{NAME}.kicad_sch")], check=True, capture_output=True)
    import xml.etree.ElementTree as ET
    root = ET.parse(xml).getroot()
    out = {}
    for n in root.iter("net"):
        name = n.get("name").lstrip("/")
        nodes = {f"{x.get('ref')}.{x.get('pin')}" for x in n.iter("node") if not x.get("ref").startswith("#")}
        if name.startswith("unconnected-") or name.startswith("Net-(") and len(nodes) <= 1:
            continue
        if nodes:
            out[name] = nodes
    return out


def check_and_export(pcb_path):
    import pcbnew
    s, p = sch_nets(), pcb_nets(pcb_path)
    s = {k: v for k, v in s.items() if not k.startswith("unconnected")}
    ok = s == p
    print("schematic vs PCB nets:", "MATCH" if ok else "MISMATCH")
    if not ok:
        for k in sorted(set(s) | set(p)):
            if s.get(k) != p.get(k):
                print("  ", k, "sch:", sorted(s.get(k, [])), "pcb:", sorted(p.get(k, [])))
    for name, nodes in s.items():
        if len(nodes) < 2:
            print("  WARNING single-pin net", name, nodes)

    board = pcbnew.LoadBoard(str(pcb_path))
    rpt = HERE / "fab" / "drc.rpt"
    pcbnew.WriteDRCReport(board, str(rpt), pcbnew.EDA_UNITS_MILLIMETRES, True)
    text = rpt.read_text()
    counts = re.findall(r"\*\* Found (\d+) ([^*\n]+)", text)
    print("DRC:", "; ".join(f"{c} {w.strip()}" for c, w in counts))

    fab = HERE / "fab"
    (fab / "gerbers").mkdir(parents=True, exist_ok=True)
    subprocess.run(["kicad-cli", "pcb", "export", "gerbers", "-o", str(fab / "gerbers") + "/",
                    "--layers", "F.Cu,B.Cu,F.Paste,B.Paste,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts",
                    "--subtract-soldermask", str(pcb_path)], check=True, capture_output=True)
    subprocess.run(["kicad-cli", "pcb", "export", "drill", "-o", str(fab / "gerbers") + "/",
                    str(pcb_path)], check=True, capture_output=True)
    for side, layers in (("top", "F.Cu,F.SilkS,F.Mask,Edge.Cuts,F.Fab"), ("bottom", "B.Cu,B.SilkS,B.Mask,Edge.Cuts")):
        args = ["kicad-cli", "pcb", "export", "svg", "-o", str(fab / f"{side}.svg"), "--layers", layers,
                "--page-size-mode", "2", "--exclude-drawing-sheet"]
        if side == "bottom":
            args.append("--mirror")
        subprocess.run(args + [str(pcb_path)], check=True, capture_output=True)
    subprocess.run(["kicad-cli", "sch", "export", "pdf", "-o", str(fab / f"{NAME}_schematic.pdf"),
                    str(HERE / f"{NAME}.kicad_sch")], check=True, capture_output=True)
    write_bom()
    return ok, counts


BOM_NOTES = {
    "U1": "TI TPS22917DBVR load switch",
    "U2": "MT3608 boost (SOT-23-6)",
    "L1": "10 uH shielded, 6x6 mm, Isat >= 2.5 A, DCR < 0.1 ohm (e.g. Taiyo Yuden NR6045 family; check Isat)",
    "D1": "SS34 (40 V 3 A Schottky, SMA) or SS24",
    "J1": "JST B2B-PH-K-S (2 mm). CHECK the battery lead polarity: pin 1 = +",
    "J2": "1x4 2.54 mm header",
    "J3": "1x2 2.54 mm header",
    "TP1": "wire pad", "TP2": "wire pad",
    "C3": "22 uF 10 V X5R/X7R 1206", "C4": "22 uF 10 V X5R/X7R 1206", "C5": "22 uF 10 V X5R/X7R 1206",
}


def write_bom():
    import csv
    rows = {}
    for ref, lid, value, fp, *_ in PARTS:
        if ref.startswith("#") or ref == "U3":
            continue
        key = (value, fp.split(":")[1])
        rows.setdefault(key, []).append(ref)
    with open(HERE / "fab" / "bom.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["References", "Qty", "Value", "Footprint", "Notes"])
        for (value, fp), refs in sorted(rows.items(), key=lambda kv: kv[1][0]):
            notes = BOM_NOTES.get(refs[0], "0805" if "0805" in fp else "")
            w.writerow([" ".join(refs), len(refs), value, fp, notes])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--freerouting", help="Freerouting .jar to run headless")
    ap.add_argument("--ses", help="routed Specctra session to import")
    args = ap.parse_args()
    write_library()
    write_schematic()
    write_project()
    pcb = build_pcb(args.freerouting, args.ses)
    ok, _ = check_and_export(pcb)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
