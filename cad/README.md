# CAD

`smart_vent_2x12_battery.scad` is an original parametric OpenSCAD model of
the battery/Thread 2x12 vent. It is not derived from the upstream Printables
STLs, which are licensed CC BY-NC-ND.

```bash
# preview the assembly (use -D show_open=true or -D explode=40 for other views)
openscad cad/smart_vent_2x12_battery.scad

# export one part, already in print orientation
openscad -D 'part="body_left"' -o body_left.stl cad/smart_vent_2x12_battery.scad
```

Parts: `body_left`, `body_right`, `louver_driven`, `louver_follower`, `link`,
`lid`, `fit_test`. The STLs in `stl/` are exports of the default parameters.
**Re-export them after you change any measurement.**

All fit-critical dimensions (boot size, tower depth, servo, heat-set
inserts) are parameters at the top of the file. See
[docs/BATTERY_THREAD.md](../docs/BATTERY_THREAD.md) for which ones to
measure.
