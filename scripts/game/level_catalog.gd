class_name LevelCatalog
## Ordered list of the level files in res://levels (level_01.json, ...).

const DIR := "res://levels/"

static var _paths: PackedStringArray = []


static func paths() -> PackedStringArray:
	if _paths.is_empty():
		for file in DirAccess.get_files_at(DIR):
			if file.begins_with("level_") and file.ends_with(".json"):
				_paths.append(DIR + file)
		_paths.sort()
	return _paths


static func count() -> int:
	return paths().size()


static func path(index: int) -> String:
	return paths()[index]
