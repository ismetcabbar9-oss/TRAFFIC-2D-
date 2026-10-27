# Traffic 2D

Grid-based traffic escape puzzle for mobile, built with Godot 4.7.2 (GDScript).

## Layout

- `scripts/core/` – game rules without visuals: grid, level data, move rule, solver, session
- `scripts/data/` – vehicle catalog (types, models, footprint lengths)
- `scripts/view/` – 3D board, vehicles, arrows, camera
- `scripts/game/` – game scene glue (input, session ↔ animations, HUD)
- `scripts/ui/` – HUD, result panel, shared UI style
- `levels/` – level files (JSON, format documented in `scripts/core/level_data.gd`)
- `tests/` – headless unit tests; every level file must be solvable
- `tools/` – dev helpers (screenshot capture, scripted playthrough, model measuring)
- `assets/fonts/` – Baloo 2 (SIL OFL)

## Commands

```sh
godot --headless --path . --import                              # import assets
godot --headless --path . --script res://tests/run_tests.gd     # run tests
xvfb-run -a godot --path . --rendering-method forward_plus \
  --resolution 720x1280 --script res://tools/capture.gd -- out.png   # screenshot
xvfb-run -a godot --path . --rendering-method forward_plus \
  --resolution 720x1280 --script res://tools/play_scenario.gd -- out_dir   # scripted playthrough
```
