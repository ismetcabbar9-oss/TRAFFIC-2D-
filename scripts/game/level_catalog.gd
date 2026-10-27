class_name LevelCatalog
## Worlds (res://data/worlds.json) and their level files
## (res://levels/world_N/level_01.json, ...). A world without level files is
## shown as "coming soon".

const WORLDS_PATH := "res://data/worlds.json"

static var _worlds: Array = []
static var _paths := {} ## world index -> PackedStringArray


static func worlds() -> Array:
	if _worlds.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORLDS_PATH))
		_worlds = data if data is Array else []
	return _worlds


static func world_count() -> int:
	return worlds().size()


static func world(index: int) -> Dictionary:
	return worlds()[index]


static func level_count(world_index: int) -> int:
	return paths(world_index).size()


static func paths(world_index: int) -> PackedStringArray:
	if not _paths.has(world_index):
		var list := PackedStringArray()
		var dir: String = world(world_index).levels
		var files := DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()
		for file in files:
			if file.begins_with("level_") and file.ends_with(".json"):
				list.append(dir + file)
		list.sort()
		_paths[world_index] = list
	return _paths[world_index]


static func path(world_index: int, level_index: int) -> String:
	return paths(world_index)[level_index]
