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
//
// All structural fasteners are M3 screws into M3 heat-set inserts.

part = "assembly";
explode = 0;          // assembly view only: spread the parts apart (mm)
show_open = false;    // assembly view only: louvers open instead of closed

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
slot_w     = 4;
slot_pitch = 7;

/* [Structure] */
wall       = 2;
partition_t = 3;      // wall between the louvers and the electronics bay
bay_len    = 46;      // outer length of the electronics tower
liner_t    = 3;       // foam liner on the tower's end wall (heat from a gas furnace)
split_clear = 0.15;   // gap per side at the centre split

/* [Louvers] */
louver_axis_z  = -19;
louver_axis_y  = 11.8;   // +/- from centre
louver_half_chord = 11;
louver_plate_t = 4;      // plate sits below the axis (flat side down to print)
end_block_len  = 9;      // must exceed insert_depth
crank_r        = 8;      // crank pin radius from the louver axis
pin_d          = 3;
louver_end_gap = 0.5;    // clearance at each end of a louver

/* [M3 hardware] */
// M3 x 4.6 OD x 5.7 mm inserts: 4.0 mm hole, 7 mm deep (room for displaced plastic)
insert_d     = 4.0;
insert_depth = 7.0;
m3_clear     = 3.4;
m3_head_d    = 6.4;   // countersink diameter for M3 flat head

/* [Servo - DFRobot DMS-MG90-A / MG90S class: VERIFY WITH CALIPERS] */
servo_body_len  = 22.8;   // along Y
servo_body_w    = 12.2;   // along Z
servo_shaft_off = 5.9;    // shaft centre from the near end of the body
servo_tab_hole_spacing = 27.8;
servo_above_tab = 6.6;    // case height above the mounting tabs
servo_spline_above_tab = 12; // top of the output spline above the tabs
servo_below_tab = 16;     // case depth below the tabs (into the bay)

/* [Electronics] */
cell_holder = [21, 21, 78];   // single 18650 holder, standing upright
xiao = [17.8, 21, 1.2];       // XIAO ESP32-C6: width, length, PCB thickness

$fn = 48;

assert(bay_depth + 2.5 + 5 <= boot_depth,
       str("Tower (", bay_depth + 2.5, " mm incl. lid) needs 5 mm clearance in a ", boot_depth, " mm boot"));
assert(end_block_len >= insert_depth + 1, "Louver end blocks are too short for the inserts");
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
    translate([0, 0, 0]) hull() {
      translate([0, 0, 0]) linear_extrude(flange_t - 1.5) rrect([flange_len, flange_w], flange_r);
      translate([0, 0, flange_t - 1.5]) linear_extrude(1.5) rrect([flange_len - 3, flange_w - 3], flange_r - 1.5);
    }
    // grille slots over the louvers (solid band at the centre split)
    for (x = [grille_x0 + slot_w / 2 : slot_pitch : grille_x1 - slot_w / 2])
      if (abs(x) > 12)
        translate([x, 0, -1]) linear_extrude(flange_t + 2)
          hull() for (s = [-1, 1]) translate([0, s * (inner_w - 3 - slot_w / 2)]) circle(d = slot_w);
  }
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
  // limit switch pad on the louver side of the partition, above the link
  translate([part_x - eps, -5, -6]) cube([3.5, 10, 6]);
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
  // wire hole for the limit switch
  translate([tab_x - 1, 7, -4]) rotate([0, 90, 0]) cylinder(d = 3.5, h = partition_t + 2);
  // lid inserts
  for (p = lid_screws()) translate([p[0], p[1], -bay_depth]) rotate([180, 0, 0]) insert_hole();
  // zip-tie slots in the end wall for the cell holder
  for (z = [-30, -65]) translate([x0 - 1, -6, z]) cube([wall + 2, 3.5, 1.8]);
  for (z = [-30, -65]) translate([x0 - 1, 2.5, z]) cube([wall + 2, 3.5, 1.8]);
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
  square([2 * louver_half_chord, 8], center = true);
}
module crank_2d() {
  hull() { circle(d = 8); translate([0, crank_r]) circle(d = 6); }
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
      translate([eps, 0, crank_r]) rotate([0, -90, 0]) cylinder(d = pin_d, h = link_t + 0.5 + eps);
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
    linear_extrude(link_t) hull() for (x = [0, link_len]) translate([x, 0]) circle(d = 6);
    for (x = [0, link_len]) translate([x, 0, -1]) cylinder(d = pin_d + 0.3, h = link_t + 2);
  }
}

// ---------------------------------------------------------------- lid
lid_t = 2.5;
xiao_pos = [tab_x - 8, 6];   // centre of the XIAO footprint (x, y)
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
      // XIAO cradle: two grooved posts holding the board upright, USB-C down
      for (s = [-1, 1]) translate([xiao_pos[0] - 2.5, xiao_pos[1] + s * (xiao[0] / 2 + 0.6) - 1.5, -bay_depth - eps])
        difference() {
          cube([5, 3, 9]);
          translate([2.5 - (xiao[2] + 0.4) / 2, s > 0 ? -eps : 1.5, -1]) cube([xiao[2] + 0.4, 1.5 + eps, 11]);
        }
    }
    for (p = lid_screws()) translate([p[0], p[1], -bay_depth - lid_t]) rotate([180, 0, 0]) m3_countersunk(lid_t + 1);
    // USB-C plug opening
    translate([xiao_pos[0] - 3.5, xiao_pos[1] - 6.5, -bay_depth - lid_t - 1]) cube([7, 13, lid_t + 3]);
  }
}

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
module placed_louver(side, driven) {
  a = show_open ? 90 : 0;
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
  a = show_open ? 90 : 0;
  translate([link_x1, -louver_axis_y - sin(a) * crank_r, louver_axis_z + cos(a) * crank_r])
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

module assembly_clean() {
  a = show_open ? 90 : 0;
  color("SteelBlue") translate([-explode / 2, 0, 0]) body_left();
  color("LightSteelBlue") translate([explode / 2, 0, 0]) body_right();
  color("Orange") placed_louver(-1, true);
  color("Gold") placed_louver(1, false);
  color("Tomato") translate([0, 0, -explode * 0.6]) link_in_assembly();
  color("DimGray") translate([0, 0, -explode]) lid();
  color("Black", 0.6) servo_ghost();
  color("Green", 0.6) translate([x0 + wall + liner_t, -cell_holder[0] / 2, -bay_depth + 2]) cube(cell_holder);
}
