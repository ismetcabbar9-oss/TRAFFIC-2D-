extends TestCase
## Every game script must load (catches parse errors in scripts no other test
## touches, such as the HUD and menu).


func test_all_scripts_compile() -> void:
	for file in _scripts("res://scripts"):
		var script := load(file) as GDScript
		check(script != null and script.can_instantiate(), "%s does not compile" % file)


func _scripts(dir: String) -> Array:
	var out := []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out
