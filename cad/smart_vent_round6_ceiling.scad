// Yet Another Smart Vent - 6" round CEILING vent with parallel louvers.
// Original parametric design. Battery + electronics live in a separate pod
// on the ceiling beside the vent (room temperature, easy to reach).
//
// Coordinates: Z up into the duct, Z=0 = ceiling surface. The face plate
// hangs below the ceiling (Z<0); the neck and louvers sit above it.
// Louver axes run along X at Y = (i - 2.5) * pitch.
//
//   openscad -D 'part="body"' -o body.stl smart_vent_round6_ceiling.scad
// Parts: assembly, body, slat0..slat5, link, pod_base, pod_cover

part = "assembly";
show_open = false;

/* [Fit - MEASURE YOUR VENT] */
duct_id      = 152;    // inside of the round duct / boot the neck slides into (6")
neck_clear   = 2;      // diametral clearance
neck_h       = 34;     // how far the neck reaches up into the duct (moving parts top out at ~31)
face_d       = 252.4;  // 9-15/16" like the Ameriflow 1500W6 (needs a 256 mm bed; 230 also covers a 6" hole)
face_t       = 5;
screw_circle = 175;    // diameter of the 3-screw circle (photo estimate 170-178)
screw_angles = [90, 210, 330];   // screw positions (deg); the cable groove leaves near +Y
screw_d      = 4.5;    // clearance hole; countersunk on the room side
screw_head_d = 9;

/* [Louvers] */
n_slats   = 6;
pitch     = 24;
chord     = 23;        // < pitch so neighbours never touch while turning
plate_t   = 3;
hub_d     = 8;
z_axis    = 14;        // louver axes above the ceiling
crank_r   = 10;
crank_phase = -45;     // crank angle from vertical when closed; swings -45 -> +45 (never hits the dead point)
crank_x   = -12;       // X position of the crank fins / link bar
pin_d     = 1.75 + 0.2;  // 1.75 mm filament pins
wall      = 2;

/* [Servo - Feetech FT90M-FB (23.2 x 12 x 25.5 mm per Feetech), VERIFY] */
servo_slat    = 4;     // which slat the servo drives (Y = +36)
servo_top_x   = 29;    // case top (spline side) X position
servo_case    = [23.2, 12.2, 23];  // along Z, along Y, along X (case height)
servo_shaft_off = 5.9; // shaft centre from the case end
tab_below_top = 6.6;   // tab plane below the case top
tab_span      = 32.5;
tab_hole_spacing = 27.8;

/* [Pod] */
cell_holder = [78, 21, 21];      // 18650 holder L x W x H
backpack    = [48, 19, 15];      // PCB L x W x stack height
pod_wall    = 2;
insert_d    = 4.0; insert_depth = 7.0; m3_clear = 3.4; m3_head_d = 6.4;

$fn = 64;
eps = 0.01;

// ---------------------------------------------------------------- derived
neck_od = duct_id - neck_clear;
R_in    = neck_od / 2 - wall;          // air opening radius
R_slat  = R_in - 1.0;                  // slat outline radius
function y_of(i) = (i - (n_slats - 1) / 2) * pitch;
function x_hub(i) = sqrt(R_slat * R_slat - pow(abs(y_of(i)) + hub_d / 2, 2)) - 0.3;
function x_end_pos(i) = i == servo_slat ? servo_top_x - 1.5 : x_hub(i);
function pivot_on(i, s) = !(i == servo_slat && s > 0);
link_t  = 2.5;
link_x1 = crank_x - 1 - 0.3 - link_t;  // link plane (beside the fins, toward -X)
link_end = abs(y_of(0)) + 3 + crank_r * sin(abs(crank_phase)); // furthest the link bar reaches in Y

assert(face_d / 2 > screw_circle / 2 + screw_head_d / 2 + 3, "face too small for the screw circle");
assert(screw_circle / 2 - screw_head_d / 2 > neck_od / 2 + 1, "screws would hit the neck");
assert(chord < pitch, "slats would collide");
assert(link_end < sqrt(R_in * R_in - pow(link_x1, 2)) - 0.8, "link bar hits the neck wall when it moves");

// ---------------------------------------------------------------- body (face + neck)
module countersink() {
  translate([0, 0, -face_t - 1]) cylinder(d = screw_d, h = face_t + 2);
  translate([0, 0, -face_t - eps]) cylinder(d1 = screw_head_d, d2 = screw_d, h = (screw_head_d - screw_d) / 2);
}

// rod along X from x0 to x1 (x0 < x1)
module xrod(x0, x1, y, z, d) { translate([x0, y, z]) rotate([0, 90, 0]) cylinder(d = d, h = x1 - x0); }

module pin_holes() {
  for (i = [0 : n_slats - 1]) for (s = [-1, 1]) if (pivot_on(i, s)) {
    if (s > 0) xrod(x_hub(i) - 6, neck_od / 2 + 1, y_of(i), z_axis, pin_d);
    else       xrod(-neck_od / 2 - 1, -x_hub(i) + 6, y_of(i), z_axis, pin_d);
  }
}

module internals() {
  // pivot bosses from the wall in to each slat hub
  for (i = [0 : n_slats - 1]) for (s = [-1, 1]) if (pivot_on(i, s)) {
    if (s > 0) xrod(x_hub(i) + 0.4, R_in + 1, y_of(i), z_axis, 6);
    else       xrod(-R_in - 1, -x_hub(i) - 0.4, y_of(i), z_axis, 6);
  }
  // servo bracket: a fin standing on the face; the servo tabs screw to it
  difference() {
    translate([servo_top_x + tab_below_top, y_of(servo_slat) - servo_case[1] / 2 - 4, 0])
      cube([2.5, servo_case[1] + 8, z_axis + tab_span / 2 + 2]);
    translate([servo_top_x + tab_below_top - 1, y_of(servo_slat) - servo_case[1] / 2 - 0.3, z_axis - servo_shaft_off - 0.3])
      cube([5, servo_case[1] + 0.6, servo_case[0] + 0.6]);
    for (s = [-1, 1]) translate([servo_top_x + tab_below_top - 1, y_of(servo_slat), z_axis - servo_shaft_off + servo_case[0] / 2 + s * tab_hole_spacing / 2])
      rotate([0, 90, 0]) cylinder(d = 1.8, h = 5);
  }
  // bracket foot so the fin is anchored to the neck wall
  translate([servo_top_x + tab_below_top, y_of(servo_slat) - servo_case[1] / 2 - 4, 0])
    cube([R_in, servo_case[1] + 8, 3]);
  // limit switch pad: above slat 0's +Y edge near the -X wall. That edge
  // drops as the vent opens, so the switch is pressed only when closed.
  translate([-R_in - 1, y_of(0) + chord / 2 - 4, z_axis + plate_t / 2 + 4]) cube([R_in + 1 - 24, 6, 5]);
}

module body() {
  difference() {
    union() {
      translate([0, 0, -face_t]) cylinder(d1 = face_d - 4, d2 = face_d, h = face_t);   // face
      difference() {                                                                   // neck tube
        cylinder(d = neck_od, h = neck_h);
        translate([0, 0, -1]) cylinder(r = R_in, h = neck_h + 2);
      }
      intersection() {                         // internal features, never outside the wall
        cylinder(r = R_in + 1, h = neck_h);
        internals();
      }
    }
    translate([0, 0, -face_t - 1]) cylinder(r = R_in, h = face_t + 1 + eps);   // air opening through the face
    for (a = screw_angles) rotate([0, 0, a]) translate([screw_circle / 2, 0, 0]) countersink();
    pin_holes();
    // cable: through the neck base on the servo side, then a groove in the
    // face's ceiling side out to the edge (toward the pod at +X)
    translate([R_in - 1, y_of(servo_slat) - 2.5, 3]) cube([wall + 2, 5, 4]);
    translate([R_in - 1, y_of(servo_slat) - 2.5, -2.5]) cube([face_d / 2, 5, 2.5 + 3 + eps]);
  }
}

// ---------------------------------------------------------------- slats
// Built closed (plate horizontal), in place: X along the axis, Y across.
module slat(i) {
  slat_body(i);
  // crank pin into the link bar
  xrod(crank_x - 1 - link_t - 0.8, crank_x - 1 + eps, y_of(i) + crank_r * sin(crank_phase), z_axis + crank_r * cos(crank_phase), 2.5);
}

// the link bar's path as seen from slat i (so the slot follows it exactly)
module bar_local(i, a) {
  translate([0, y_of(i), z_axis]) rotate([a, 0, 0]) translate([0, -y_of(i), -z_axis]) link_placed(a, 0.6);
}
module bar_sweep_local(i) {
  for (k = [0 : 5 : 85]) hull() { bar_local(i, k); bar_local(i, k + 5); }
}

module slat_body(i) {
  y0 = y_of(i);
  xe = x_end_pos(i);
  xs = -x_hub(i);
  difference() {
    union() {
      // plate: strip of the louver row, clipped to the circle and the hubs' span
      translate([0, 0, z_axis - plate_t / 2]) linear_extrude(plate_t)
        intersection() {
          translate([xs, y0 - chord / 2]) square([xe - xs, chord]);
          circle(r = R_slat);
        }
      // end hubs
      xrod(xs, xs + 6, y0, z_axis, hub_d);
      xrod(xe - 6, xe, y0, z_axis, hub_d);
      // stiffening rib along the axis
      translate([xs, y0 - 1, z_axis]) cube([xe - xs, 2, plate_t / 2 + 1.5]);
      // crank fin + pin (pin points -X, into the link bar)
      translate([crank_x - 1, y0, z_axis]) rotate([90, 0, 90]) linear_extrude(2)
        hull() { circle(d = hub_d); translate([crank_r * sin(crank_phase), crank_r * cos(crank_phase)]) circle(d = 5); }
    }
    // slot where the link bar sweeps through the plate (bar never reaches the axis rib)
    intersection() {
      translate([link_x1 - 0.6, -100, -100]) cube([crank_x - 1 - 0.05 - (link_x1 - 0.6), 200, 200]);
      bar_sweep_local(i);
    }
    // (pin re-added below)
    // filament pin holes in the hubs
    xrod(xs - eps, xs + 6.5, y0, z_axis, pin_d);
    if (i != servo_slat) xrod(xe - 6.5, xe + eps, y0, z_axis, pin_d);
    // servo horn pocket on the driven slat (trim a single-arm horn to ~10 mm)
    if (i == servo_slat) {
      xrod(xe - 5, xe + eps, y0, z_axis, 7.6);
      translate([xe - 2.6, y0, z_axis]) rotate([90, 0, 90]) linear_extrude(2.6 + eps)
        hull() { circle(d = 6); translate([0, -10]) circle(d = 4.6); }
    }
  }
}

// ---------------------------------------------------------------- link bar
module link(clear = 0) {
  span = y_of(n_slats - 1) - y_of(0);
  translate([0, 0, -clear]) linear_extrude(link_t + 2 * clear) difference() {
    hull() for (y = [0, span]) translate([y, 0]) circle(d = 6 + 2 * clear);
    if (clear == 0) for (i = [0 : n_slats - 1]) translate([y_of(i) - y_of(0), 0]) circle(d = 2.8);
  }
}
// a = 0 closed, 90 open. The cranks swing from crank_phase to crank_phase + 90.
module link_placed(a, clear = 0) {
  translate([link_x1, y_of(0) + crank_r * sin(crank_phase + a), z_axis + crank_r * cos(crank_phase + a)])
    multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0]]) link(clear);
}

// ---------------------------------------------------------------- pod
pod_in = [cell_holder[0] + 6, cell_holder[1] + backpack[1] + 5, max(cell_holder[2], backpack[2]) + 4];
pod_out = [pod_in[0] + 2 * pod_wall, pod_in[1] + 2 * pod_wall, pod_in[2]];
pod_base_t = 3;
pod_h = pod_in[2] + pod_base_t;
pod_corner = [[4, 4], [pod_out[0] - 4, 4], [4, pod_out[1] - 4], [pod_out[0] - 4, pod_out[1] - 4]];
module pod_base() {
  // the base screws to the ceiling (Z=0 face against it)
  difference() {
    union() {
      cube([pod_out[0], pod_out[1], pod_base_t]);
      for (c = pod_corner) translate([c[0] - 3.5, c[1] - 3.5, 0]) cube([7, 7, pod_base_t + 9]);
      // cell holder keeper
      translate([pod_wall + 2, pod_wall + 2, 0]) difference() {
        cube([cell_holder[0] + 2, cell_holder[1] + 2, pod_base_t + 3]);
        translate([1, 1, pod_base_t]) cube([cell_holder[0], cell_holder[1], 5]);
      }
    }
    for (c = pod_corner) translate([c[0], c[1], pod_base_t + 9 - insert_depth]) cylinder(d = insert_d, h = insert_depth + 1);
    // two ceiling screws (#8 / drywall anchors), countersunk from inside
    for (x = [pod_out[0] * 0.3, pod_out[0] * 0.7]) translate([x, pod_out[1] - 9, -1]) {
      cylinder(d = 4.5, h = pod_base_t + 2);
      translate([0, 0, pod_base_t + 1 - 2.2]) cylinder(d1 = 4.5, d2 = 9, h = 2.2 + eps);
    }
  }
}
module pod_cover() {
  difference() {
    cube([pod_out[0], pod_out[1], pod_h]);
    translate([pod_wall, pod_wall, -eps]) cube([pod_in[0], pod_in[1], pod_h - pod_wall + eps]);
    for (c = pod_corner) translate([c[0], c[1], pod_h - 3]) {
      cylinder(d = m3_clear, h = 5);
      translate([0, 0, 1.3]) cylinder(d1 = m3_clear, d2 = m3_head_d, h = 1.7 + eps);
    }
    // USB-C (XIAO end of the backpack) and the vent cable entry
    translate([pod_out[0] - pod_wall - 1, pod_wall + cell_holder[1] + 4 + backpack[1] / 2 - 6, pod_base_t + 3]) cube([pod_wall + 2, 12, 7]);
    translate([-1, pod_out[1] - pod_wall - 8, pod_base_t]) cube([pod_wall + 2, 6, 4]);
  }
  for (c = pod_corner) translate([c[0] - 3.5, c[1] - 3.5, pod_base_t + 9]) difference() {
    cube([7, 7, pod_h - pod_base_t - 9 - eps]);
    translate([3.5, 3.5, -1]) cylinder(d = m3_clear + 0.1, h = pod_h);   // not coincident with the lid hole
  }
}

// ---------------------------------------------------------------- assembly
module servo_ghost() {
  translate([servo_top_x, y_of(servo_slat) - servo_case[1] / 2, z_axis - servo_shaft_off])
    cube([servo_case[2], servo_case[1], servo_case[0]]);
}

module assembly() {
  a = show_open ? 90 : 0;
  color("SteelBlue") body();
  for (i = [0 : n_slats - 1])
    color(i == servo_slat ? "Orange" : "Gold")
      translate([0, y_of(i), z_axis]) rotate([-a, 0, 0]) translate([0, -y_of(i), -z_axis]) slat(i);
  color("Tomato") link_placed(a);
  color("Black", 0.6) servo_ghost();
  // pod on the ceiling beside the vent (base up against the ceiling)
  color("DimGray") translate([face_d / 2 + 40, -pod_out[1] / 2, 0]) mirror([0, 0, 1]) { pod_base(); pod_cover(); }
}

if (part == "assembly") assembly();
else if (part == "body") translate([0, 0, face_t]) body();   // face down on the bed, neck up
else if (part == "link") link();
else if (part == "pod_base") pod_base();
else if (part == "pod_cover") translate([0, 0, pod_h]) mirror([0, 0, 1]) pod_cover();   // top down
else for (i = [0 : n_slats - 1]) if (part == str("slat", i))
  // printed on edge, with the edge nearer the vent centre (the longest, straight one) on the bed,
  // so the circle-cut ends only lean inward going up: no overhangs, maximum bed contact
  translate([0, 0, chord / 2]) rotate([y_of(i) < 0 ? -90 : 90, 0, 0]) translate([0, -y_of(i), -z_axis]) slat(i);
