// Yet Another Smart Vent - battery/Thread 2x12 variant
// Original parametric design (does not reuse upstream STL geometry).
//
// Coordinate system (assembled):
//   X = along the 12" length, Y = across the 2" width,
//   Z = 0 at the finished floor surface; the grille flange is above Z=0 and
//   the body hangs down into the register boot.
//
// Export one part at a time, e.g.:
//   openscad -D 'part="body_left"' -o body_left.stl smart_vent_2x12_battery.scad
// Parts: assembly, body_left, body_right, louver_driven, louver_follower,
//        link, lid, fit_test
// The lid is a slide-out cartridge: it carries the backpack PCB and the cell
// holder, so two screws bring board and cell out of the tower together.
//
// All structural fasteners are M3 screws into M3 heat-set inserts.

part = "assembly";
explode = 0;          // assembly view only: spread the parts apart (mm)
show_open = false;    // assembly view only: louvers open instead of closed
angle = 0;            // assembly view only: louver angle in degrees (0 closed .. 90 open)

/* [Boot / floor fit - MEASURE YOUR VENT] */
body_len   = 296;     // outer length of the part that drops into the boot
body_w     = 52;      // outer width of the part that drops into the boot
body_depth = 40;      // louver section depth below the floor surface
bay_depth  = 85;      // electronics/battery tower depth below the floor
boot_depth = 101.6;   // measured: floor surface to the bottom of the boot (4")

/* [Grille flange] */
flange_len = 330;
flange_w   = 84;
flange_t   = 6;
flange_r   = 6;       // corner radius
// Grille: free area matters. Twenty of these in a house add up, and a gas
// furnace needs its airflow. 5 mm slots on a 7 mm pitch give about 10.3 sq in
// (the first draft had 8.2). The centre spine halves each bar's span, so the
// 2 mm bars survive being stepped on.
slot_w     = 5;
slot_pitch = 7;
bar_drop   = 2;       // the bars continue this far below the floor line (stiffer underfoot)
spine_w    = 2.4;     // lengthwise rib under the middle of the grille
spine_drop = 6;       // how far the spine hangs below the floor line

/* [Structure] */
wall       = 2;
partition_t = 3;      // wall between the louvers and the electronics bay
bay_len    = 46;      // outer length of the electronics tower
liner_t    = 2;       // foam liner on the tower's end wall (heat from a gas furnace)
split_clear = 0.15;   // gap per side at the centre split

/* [Louvers] */
louver_axis_z  = -19;
louver_axis_y  = 11.8;   // +/- from centre
louver_half_chord = 11;
louver_plate_t = 4;      // plate sits below the axis (flat side down to print)
end_block_len  = 9;      // must exceed insert_depth
crank_r        = 9;      // crank pin radius from the louver axis
// The cranks hang DOWN and swing 45 deg either side of straight down.
// A parallelogram linkage loses control of the follower when the cranks
// line up with the link (its dead point); the first draft was fully open
// exactly there. 135 = down and toward -Y when closed, 225 when open.
crank_phase    = 135;
link_w         = 5;      // link bar width
pin_d          = 3;
louver_end_gap = 0.5;    // clearance at each end of a louver

/* [M3 hardware] */
// M3 x 4.6 OD x 5.7 mm inserts: 4.0 mm hole, 7 mm deep (room for displaced plastic)
insert_d     = 4.0;
insert_depth = 7.0;
m3_clear     = 3.4;
m3_head_d    = 6.4;   // countersink diameter for M3 flat head
lid_thumb_screws = false;  // true: plain M3 clearance holes in the lid (flat seat) for M3 thumb screws
thumb_head_h = 9;     // tallest thumb screw head that still leaves 5 mm under the tower

/* [Servo - Feetech FT90M-FB (23.2 x 12 x 25.5 mm per Feetech): VERIFY WITH CALIPERS] */
servo_body_len  = 23.2;   // along Y
servo_body_w    = 12.2;   // along Z
servo_shaft_off = 5.9;    // shaft centre from the near end of the body
servo_tab_hole_spacing = 27.8;
servo_above_tab = 6.6;    // case height above the mounting tabs
servo_spline_above_tab = 8.7; // top of the output spline above the tabs (FT90M sheet: 25.5 - 16.8)
servo_below_tab = 16.8;   // case depth below the tabs (FT90M sheet)

/* [Limit switch - Panasonic ESE-11HS2 (8.6 x 4.5 x 3.6 mm): CHECK THE LEVER ON YOURS] */
// The switch is glued under a pad on the side wall, above the driven
// louver's outer edge at the servo end. That edge rises about 0.2 mm per
// degree as the vent closes, so the switch position sets "closed" to
// within a degree or two. The pad's underside is sw_gap above the edge
// when closed: switch body height + the lever's travel to its ON point.
sw_gap   = 5.0;
sw_pad_w = 4.2;      // how far the pad stands out from the side wall

/* [Electronics] */
// X = depth (open face to back), Y = width, Z = length. CHECK YOURS WITH CALIPERS.
cell_holder = [21, 21, 78];   // single 18650 holder, standing upright
xiao = [17.8, 21, 1.2];       // XIAO ESP32-C6: width, length, PCB thickness

$fn = 48;

assert(bay_depth + 2.5 + 5 <= boot_depth,
       str("Tower (", bay_depth + 2.5, " mm incl. lid) needs 5 mm clearance in a ", boot_depth, " mm boot"));
assert(!lid_thumb_screws || bay_depth + 2.5 + thumb_head_h + 5 <= boot_depth,
       "Thumb screw heads leave less than 5 mm under the tower");
assert(end_block_len >= insert_depth + 1, "Louver end blocks are too short for the inserts");
assert(louver_axis_y + crank_r * sin(45) + 3 < body_w / 2 - wall - 1, "crank tips would hit the side walls");
assert(crank_r - link_w / 2 >= 6.4, "link bar would rub the servo's output boss (about 12 mm across)");
eps = 0.01;

// ---------------------------------------------------------------- derived
x0      = -body_len / 2;              // body start (tower end)
x1      =  body_len / 2;              // body end (far end)
part_x  = x0 + bay_len;               // louver-side face of the partition
tab_x   = part_x - partition_t;       // bay-side face (servo tabs sit here)
inner_w = body_w / 2 - wall;          // inner half width
case_top_x = tab_x + servo_above_tab;
link_t  = 2.4;
link_x1 = case_top_x + 0.4;           // link slab (louver side of servo case)
link_x2 = link_x1 + link_t;
louver_x0 = link_x2 + 0.2;            // louver end face (servo end)
louver_x1 = x1 - wall - louver_end_gap;
louver_len = louver_x1 - louver_x0;
grille_x0 = part_x + 3;
grille_x1 = x1 - wall - 3;
end_block_h = 8;
sw_pad_z = louver_axis_z + end_block_h / 2 + sw_gap;   // underside of the limit switch pad
function crank_y(a) = -crank_r * sin(crank_phase + a);
function crank_z(a) =  crank_r * cos(crank_phase + a);

// ---------------------------------------------------------------- helpers
module rrect(size, r) {
  // rounded rectangle centred on the origin
  offset(r) square([size[0] - 2 * r, size[1] - 2 * r], center = true);
}

module insert_hole(depth = insert_depth) {
  // opening at z=0, pointing down -Z
  translate([0, 0, -depth]) cylinder(d = insert_d, h = depth + eps);
  translate([0, 0, -0.6]) cylinder(d1 = insert_d, d2 = insert_d + 1, h = 0.6 + eps);
}

module m3_countersunk(len = 20) {
  // head at z=0 pointing down -Z
  translate([0, 0, -len]) cylinder(d = m3_clear, h = len + eps);
  translate([0, 0, -(m3_head_d - m3_clear) / 2]) cylinder(d1 = m3_clear, d2 = m3_head_d, h = (m3_head_d - m3_clear) / 2 + eps);
}

// ---------------------------------------------------------------- flange
module flange() {
  difference() {
    union() {
      hull() {
        linear_extrude(flange_t - 1.5) rrect([flange_len, flange_w], flange_r);
        translate([0, 0, flange_t - 1.5]) linear_extrude(1.5) rrect([flange_len - 3, flange_w - 3], flange_r - 1.5);
      }
      // the grille bars continue below the floor line, inside the body
      translate([part_x, -inner_w - eps, -bar_drop]) cube([x1 - wall - part_x, 2 * inner_w + 2 * eps, bar_drop + eps]);
    }
    // grille slots over the louvers (solid band at the centre split)
    for (x = [grille_x0 + slot_w / 2 : slot_pitch : grille_x1 - slot_w / 2])
      if (abs(x) > 12)
        translate([x, 0, -bar_drop - 1]) linear_extrude(flange_t + bar_drop + 2)
          hull() for (s = [-1, 1]) translate([0, s * (inner_w - 1 - slot_w / 2)]) circle(d = slot_w);
  }
  // centre spine: ties every bar together and halves its span
  translate([grille_x0 - 3, -spine_w / 2, -spine_drop]) cube([grille_x1 - grille_x0 + 6, spine_w, spine_drop + flange_t - 0.6]);
}

// ---------------------------------------------------------------- body
module body_shell() {
  difference() {
    union() {
      translate([x0, -body_w / 2, -body_depth]) cube([body_len, body_w, body_depth + eps]);
      translate([x0, -body_w / 2, -bay_depth]) cube([bay_len, body_w, bay_depth + eps]);
    }
    // louver section: open top (under the grille) and open bottom
    translate([part_x, -inner_w, -body_depth - 1]) cube([x1 - wall - part_x, 2 * inner_w, body_depth + 2]);
    // electronics tower: open at the bottom for the lid
    translate([x0 + wall, -inner_w, -bay_depth - 1]) cube([bay_len - wall - partition_t, 2 * inner_w, bay_depth + 1 - eps]);
  }
  // lid screw bosses
  for (p = lid_screws()) translate([p[0] - 4, p[1] - 4, -bay_depth]) cube([8, 8, 10]);
  // limit switch pad on the side wall, above the driven louver's outer edge
  translate([part_x - eps, -inner_w - eps, sw_pad_z]) cube([louver_x0 + end_block_len - part_x, sw_pad_w, -sw_pad_z]);
}

function lid_screws() = [[x0 + wall + 4.5, inner_w - 4], [tab_x - 4.5, -(inner_w - 4)]];

module body_cuts() {
  // servo: opening for the case above the tabs + pilot holes for tab screws
  sy0 = -louver_axis_y - servo_shaft_off;           // case end near the shaft
  sy_c = sy0 + servo_body_len / 2;
  translate([tab_x - 1, sy0 - 0.4, louver_axis_z - servo_body_w / 2 - 0.4])
    cube([partition_t + 2, servo_body_len + 0.8, servo_body_w + 0.8]);
  for (s = [-1, 1]) translate([tab_x - 1, sy_c + s * servo_tab_hole_spacing / 2, louver_axis_z])
    rotate([0, 90, 0]) cylinder(d = 1.8, h = partition_t + 2);
  // follower louver axle: flat-head M3 from the bay side, head flush
  translate([tab_x, louver_axis_y, louver_axis_z]) rotate([0, -90, 0]) m3_countersunk(partition_t + 2);
  // far-end axles: flat-head M3 from outside the end wall
  for (s = [-1, 1]) translate([x1, s * louver_axis_y, louver_axis_z]) rotate([0, 90, 0]) m3_countersunk(wall + 2);
  // wire hole for the limit switch (beside its pad, above the servo tab)
  translate([tab_x - 1, -inner_w + sw_pad_w + 2.6, -5]) rotate([0, 90, 0]) cylinder(d = 3.5, h = partition_t + 2);
  // lid inserts
  for (p = lid_screws()) translate([p[0], p[1], -bay_depth]) rotate([180, 0, 0]) insert_hole();
}

module body_full() {
  difference() {
    union() { flange(); body_shell(); }
    body_cuts();
  }
}

// --- centre split joint (left half owns the bosses, right half the tab) ---
joint_y = inner_w - 2;   // screw line, 2 mm in from the inner wall face
module left_bosses() {
  for (s = [-1, 1]) {
    y0 = s > 0 ? joint_y - 2 : -inner_w - 0.5;
    translate([-8, y0, -8]) cube([16, 4.5, 8]);                                 // top
    translate([-8, y0, -body_depth + 3]) cube([16, 4.5, body_depth - 3 - 28.5]); // bottom
  }
}
module right_tabs() {
  for (s = [-1, 1]) translate([0, s > 0 ? joint_y - 2 : -body_w / 2, -body_depth])
    cube([8, 4 + wall, 3]);
}
module joint_holes() {
  for (s = [-1, 1]) {
    translate([4, s * joint_y, flange_t]) m3_countersunk(flange_t + 1);       // top screw
    translate([4, s * joint_y, 0]) insert_hole();                            // top insert
    translate([4, s * joint_y, -body_depth]) rotate([180, 0, 0]) m3_countersunk(4); // bottom screw
    translate([4, s * joint_y, -body_depth + 3]) rotate([180, 0, 0]) insert_hole(); // bottom insert
  }
}

module body_left() {
  difference() {
    union() {
      intersection() {
        body_full();
        translate([-500, -500, -500]) cube([500 - split_clear, 1000, 1000]);
      }
      // keep the bosses clear of the right half's walls
      intersection() {
        left_bosses();
        translate([-500, -inner_w + 0.3, -500]) cube([1000, 2 * inner_w - 0.6, 1000]);
      }
      intersection() {
        left_bosses();
        translate([-500, -500, -500]) cube([500, 1000, 1000]);
      }
    }
    joint_holes();
  }
}

module body_right() {
  difference() {
    union() {
      intersection() {
        body_full();
        translate([split_clear, -500, -500]) cube([500, 1000, 1000]);
      }
      right_tabs();
    }
    joint_holes();
  }
}

// ---------------------------------------------------------------- louvers
// Built in "louver space": X along the louver from its servo-end face (x=0),
// axis on the X axis, closed orientation (plate horizontal, below the axis).
module louver_section_2d() {
  translate([0, -louver_plate_t / 2]) square([2 * louver_half_chord, louver_plate_t], center = true);
}
module louver_end_block_2d() {
  square([2 * louver_half_chord, end_block_h], center = true);
}
module crank_2d() {
  hull() { circle(d = 8); translate([crank_y(0), crank_z(0)]) circle(d = 6); }
}

module louver(driven = false) {
  difference() {
    union() {
      // plate
      rotate([90, 0, 90]) linear_extrude(louver_len) louver_section_2d();
      // end blocks (carry the inserts / horn)
      for (x = [0, louver_len - end_block_len])
        translate([x, 0, 0]) rotate([90, 0, 90]) linear_extrude(end_block_len) louver_end_block_2d();
      // crank fin + pin at the servo end
      rotate([90, 0, 90]) linear_extrude(end_block_len) crank_2d();
      translate([eps, crank_y(0), crank_z(0)]) rotate([0, -90, 0]) cylinder(d = pin_d, h = link_t + 0.5 + eps);
      // stiffening ribs on top of the plate
      for (y = [-6, 6]) translate([0, y - 0.8, 0]) cube([louver_len, 1.6, 2]);
    }
    // far-end axle insert
    translate([louver_len, 0, 0]) rotate([0, 90, 0]) insert_hole();
    if (driven) {
      // servo horn pocket (trim a single-arm horn to ~10 mm)
      translate([-eps, 0, 0]) rotate([0, 90, 0]) cylinder(d = 7.6, h = 6);
      translate([-eps, 0, 0]) rotate([90, 0, 90]) linear_extrude(2.6)
        hull() { circle(d = 6); translate([10, 0]) circle(d = 4.6); }
      for (r = [5.5, 8.5]) translate([-eps, r, 0]) rotate([0, 90, 0]) cylinder(d = 1.5, h = 9);
    } else {
      translate([0, 0, 0]) rotate([0, -90, 0]) insert_hole();
    }
  }
}

// ---------------------------------------------------------------- link
link_len = 2 * louver_axis_y;
module link() {
  difference() {
    linear_extrude(link_t) hull() for (x = [0, link_len]) translate([x, 0]) circle(d = link_w);
    for (x = [0, link_len]) translate([x, 0, -1]) cylinder(d = pin_d + 0.3, h = link_t + 2);
  }
}

// ---------------------------------------------------------------- lid
// The lid is a cartridge. Undo its two screws and it slides straight down
// out of the tower with the backpack PCB and the cell holder on it; the
// servo and limit switch leads stay plugged in and need about 90 mm of slack.
// The electronics are the XIAO backpack PCB (hardware/xiao-backpack, 48 x 19
// x 1.6 mm) standing upright under the servo, XIAO end (USB-C) down through
// the lid. The XIAO is soldered straight onto the backpack (2.5 mm header
// spacer), with the components facing the partition (+X).
lid_t = 2.5;
backpack = [19, 48, 1.6];          // width (Y), length (Z), thickness (X)
bp_stack_top = 12;                // tallest top-side part: JST-PH + plug at the far end (XIAO stack ~7.5)
bp_x = tab_x - 14.5;               // back (bottom-side) face of the backpack PCB
bp_y = 0;                          // centre of the board width
usb_x = bp_x + backpack[2] + 2.5 + 1.2 + 1.6;   // USB-C centre: PCB + spacer + XIAO PCB + half receptacle

// Cell holder cradle. The holder stands on the lid against the foam liner,
// open face toward -X (the end wall): in the tower the liner backs the cell,
// and with the cartridge out that face has nothing in front of it.
hold_liner_gap = 0.2;              // holder to foam liner (the foam gives)
hold_fit   = 0.3;                  // socket clearance around the holder
hold_x0    = x0 + wall + liner_t + hold_liner_gap;   // open face of the holder
hold_x1    = hold_x0 + cell_holder[0];               // back of the holder
hold_y     = cell_holder[1] / 2;
rail_t     = 2;                    // side rails
rail_h     = 55;                   // rail height above the lid
sock_h     = 6;                    // height of the low wall across the open face
sock_wall  = 1.6;
rail_x0    = hold_x0 + 0.2;        // 0.4 mm short of the liner
rail_x1    = hold_x1 + hold_fit + sock_wall;
rail_y     = hold_y + hold_fit;    // inner face of a rail
keep_w     = 1.8;                  // how far the back lips reach in behind the holder
band_z     = [20, 45];             // rubber band / zip tie notches, height above the lid
band_h     = 4;
wire_notch = [3, 6];               // lead comb in the top of each rail: width, depth
servo_x0   = tab_x - servo_below_tab;                // servo case face in the bay
servo_z0   = louver_axis_z - servo_body_w / 2;       // underside of the servo case

module cell_cradle() {
  zb = -bay_depth - eps;
  difference() {
    union() {
      for (s = [-1, 1]) {
        // side rail
        translate([rail_x0, s > 0 ? rail_y : -rail_y - rail_t, zb]) cube([rail_x1 - rail_x0, rail_t, rail_h + eps]);
        // lip behind the holder's back corner
        translate([hold_x1 + hold_fit, s > 0 ? rail_y - hold_fit - keep_w : rail_y - eps, zb])
          cube([sock_wall, hold_fit + keep_w + eps, rail_h + eps]);
      }
      // low wall across the open face (the liner must stop above it)
      translate([hold_x0 - 0.2 - sock_wall, -rail_y - rail_t, zb]) cube([sock_wall, 2 * (rail_y + rail_t), sock_h + eps]);
    }
    // band notches in both vertical edges of the rails; 45 deg roofs print clean
    for (h = band_z) translate([0, 0, -bay_depth + h]) rotate([90, 0, 0]) linear_extrude(2 * (rail_y + rail_t) + 2, center = true) {
      polygon([[rail_x0 - 1, 0], [rail_x0 + 1.2, 0], [rail_x0 + 1.2, band_h], [rail_x0 - 1, band_h + 2.2]]);
      polygon([[rail_x1 + 1, 0], [hold_x1 + hold_fit - eps, 0], [hold_x1 + hold_fit - eps, band_h], [rail_x1 + 1, band_h + sock_wall + 1 + eps]]);
    }
    // lead comb: the servo and switch leads fold over here
    translate([(rail_x0 + hold_x1) / 2 - wire_notch[0] / 2, -rail_y - rail_t - 1, -bay_depth + rail_h - wire_notch[1]])
      cube([wire_notch[0], 2 * (rail_y + rail_t) + 2, wire_notch[1] + 1]);
  }
}

module holder_ghost() {
  translate([hold_x0, -hold_y, -bay_depth]) cube(cell_holder);
}

module lid() {
  difference() {
    union() {
      translate([x0, -body_w / 2, -bay_depth - lid_t]) cube([bay_len, body_w, lid_t]);
      // locating lip inside the tower
      difference() {
        translate([x0 + wall + 0.3, -inner_w + 0.3, -bay_depth - eps]) cube([bay_len - wall - partition_t - 0.6, 2 * inner_w - 0.6, 2]);
        translate([x0 + wall + 1.8, -inner_w + 1.8, -bay_depth - 1]) cube([bay_len - wall - partition_t - 3.6, 2 * inner_w - 3.6, 4]);
        for (p = lid_screws()) translate([p[0] - 4.5, p[1] - 4.5, -bay_depth - 1]) cube([9, 9, 4]);
      }
      // backpack cradle: two posts with a groove for each long PCB edge
      // The groove takes 0.9 mm of the board edge on the back and only 0.5 mm
      // on the component side, where the XIAO's header strip starts 0.6 mm in.
      for (s = [-1, 1]) mirror([0, s > 0 ? 0 : 1, 0]) translate([bp_x - 2.2, bp_y + backpack[0] / 2 - 0.9, -bay_depth - eps])
        difference() {
          cube([backpack[2] + 4.4, 3.9, 12]);
          translate([2.2 - 0.2, -eps, -1]) cube([backpack[2] + 0.4, 0.9 + 0.25 + eps, 14]);   // board slot
          translate([2.2 + backpack[2], -eps, -1]) cube([2.2 + eps, 0.4 + eps, 14]);          // shorter lip, component side
        }
      cell_cradle();
    }
    for (p = lid_screws()) translate([p[0], p[1], -bay_depth - lid_t])
      if (lid_thumb_screws) translate([0, 0, -1]) cylinder(d = m3_clear, h = lid_t + 2);
      else rotate([180, 0, 0]) m3_countersunk(lid_t + 1);
    // USB-C plug opening (overmold ~12 x 7 mm)
    translate([usb_x - 4, bp_y - 6.75, -bay_depth - lid_t - 1]) cube([8, 13.5, lid_t + 3]);
  }
}

module backpack_ghost() {
  translate([bp_x, bp_y - backpack[0] / 2, -bay_depth]) cube([backpack[2], backpack[0], backpack[1]]);
  translate([bp_x + backpack[2], bp_y - backpack[0] / 2, -bay_depth]) cube([bp_stack_top, backpack[0], backpack[1]]);
}

assert(bp_x - 1 >= rail_x1, "cell cradle is closer than 1 mm to the back of the backpack PCB");
assert(hold_x0 >= x0 + wall + liner_t, "cell holder is pushed into the foam liner");
assert(rail_x0 >= x0 + wall + liner_t + 0.4 - eps, "cradle rails need 0.4 mm to the foam liner");
assert(hold_x0 - 0.2 - sock_wall >= x0 + wall + 0.4 - eps, "cradle front wall needs 0.4 mm to the end wall");
assert(hold_x1 + 1 <= servo_x0 + eps, "cell holder is closer than 1 mm to the servo");
assert(rail_x1 + 1 <= servo_x0 || -bay_depth + rail_h <= servo_z0 - 1.9, "cradle rails reach the servo");
assert(-bay_depth + cell_holder[2] <= -2, "cell holder is too tall for the tower");
assert(rail_y + rail_t + 0.4 <= inner_w - 8, "cradle rails collide with the lid screw bosses");
assert(bp_x + backpack[2] + bp_stack_top < tab_x, "backpack stack collides with the partition");
assert(-bay_depth + backpack[1] < louver_axis_z - servo_body_w / 2, "backpack reaches the servo");

// ---------------------------------------------------------------- fit test
// A short slice of the body + one insert boss: checks boot fit, flange,
// insert hole size and servo opening before a full print.
module fit_test() {
  intersection() {
    body_left();
    translate([x0 - 20, -100, -200]) cube([bay_len + 30, 200, 400]);
  }
}

// ---------------------------------------------------------------- assembly
function vent_angle() = show_open ? 90 : angle;
module placed_louver(side, driven) {
  a = vent_angle();
  translate([louver_x0, side * louver_axis_y, louver_axis_z - explode * 0.6])
    rotate([a, 0, 0]) louver(driven);
}

module servo_ghost() {
  sy0 = -louver_axis_y - servo_shaft_off;
  translate([tab_x - servo_below_tab, sy0, louver_axis_z - servo_body_w / 2])
    cube([servo_below_tab + servo_above_tab, servo_body_len, servo_body_w]);
  translate([tab_x - 2.5, sy0 - 4.85, louver_axis_z - servo_body_w / 2]) cube([2.5, servo_body_len + 9.7, servo_body_w]);
}

module link_in_assembly() {
  a = vent_angle();
  translate([link_x1, -louver_axis_y + crank_y(a), louver_axis_z + crank_z(a)])
    multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0]]) link();   // local x->Y, y->Z, z->X
}

// ---------------------------------------------------------------- output
if (part == "assembly") {
  assembly_clean();
} else if (part == "body_left") {
  mirror([0, 0, 1]) translate([0, 0, -flange_t]) body_left();          // flange down
} else if (part == "body_right") {
  mirror([0, 0, 1]) translate([0, 0, -flange_t]) body_right();
} else if (part == "louver_driven") {
  translate([0, 0, louver_plate_t]) louver(true);                        // flat side down
} else if (part == "louver_follower") {
  translate([0, 0, louver_plate_t]) louver(false);
} else if (part == "link") {
  link();
} else if (part == "lid") {
  translate([0, 0, bay_depth + lid_t]) lid();
} else if (part == "fit_test") {
  mirror([0, 0, 1]) translate([0, 0, -flange_t]) fit_test();
}
// single parts in their assembled position, for collision checks (use with -D angle=...)
else if (part == "asm_body") { body_left(); body_right(); }
else if (part == "asm_driven") placed_louver(-1, true);
else if (part == "asm_follower") placed_louver(1, false);
else if (part == "asm_link") link_in_assembly();
else if (part == "asm_servo") servo_ghost();
else if (part == "asm_lid") lid();
else if (part == "asm_holder") holder_ghost();
else if (part == "asm_backpack") backpack_ghost();

module assembly_clean() {
  color("SteelBlue") translate([-explode / 2, 0, 0]) body_left();
  color("LightSteelBlue") translate([explode / 2, 0, 0]) body_right();
  color("Orange") placed_louver(-1, true);
  color("Gold") placed_louver(1, false);
  color("Tomato") translate([0, 0, -explode * 0.6]) link_in_assembly();
  // the cartridge: lid, backpack and cell holder move together
  translate([0, 0, -explode * 2.5]) {
    color("DimGray") lid();
    color("Purple", 0.6) backpack_ghost();
    color("Green", 0.6) holder_ghost();
  }
  color("Black", 0.6) servo_ghost();
}
if (part == "asm_body_left") body_left();
if (part == "asm_body_right") body_right();
