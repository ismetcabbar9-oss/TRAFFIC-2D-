extends SceneTree
## Dev tool: generates one level and prints its summary without saving.
## Usage: godot --headless --path . --script res://tools/try_level.gd -- <world> <level>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]) - 1
	var i := int(args[1]) - 1
	var info := LevelCatalog.world(w)
	var attempts := LevelGenerator.HARD_ATTEMPTS if i in LevelGenerator.HARD else LevelGenerator.ATTEMPTS
	if i >= LevelGenerator.SHARP_FROM:
		attempts *= 2
	var start := Time.get_ticks_msec()
	var result := LevelGenerator.generate(LevelGenerator.spec(w, i, info.mechanic), [w, i], attempts)
	print("W%d L%d: %s  (%.1f s)" % [w + 1, i + 1, result.get("note", "none"), (Time.get_ticks_msec() - start) / 1000.0])
	quit()
