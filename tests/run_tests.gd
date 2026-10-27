extends SceneTree
## Headless test runner: godot --headless --path . --script res://tests/run_tests.gd
## Runs every test_* method of every res://tests/test_*.gd file; exits 1 on failure.

func _initialize() -> void:
	var failed := 0
	var passed := 0
	for file in DirAccess.get_files_at("res://tests/"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var suite: TestCase = load("res://tests/" + file).new()
		for m in suite.get_method_list():
			var method: String = m.name
			if not method.begins_with("test_"):
				continue
			suite.failures.clear()
			suite.call(method)
			if suite.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f in suite.failures:
					printerr("FAIL %s::%s: %s" % [file, method, f])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
