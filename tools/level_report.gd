extends SceneTree
## Dev tool: quality report for every level. Read-only: never changes a level.
## Usage: godot --headless --path . --script res://tools/level_report.gd -- [out.md]
##
## Flags:
## - EASY: not a breather, yet over half the cars can leave at the start or
##   the solution is 2+ waves shorter than the difficulty target
## - SOFT_HARD: marked hard but not deeper than the levels just before it
## - DIP: noticeably easier than the previous non-breather level
## - SIMILAR: shares most of its vehicle placements with another level
## - NO_MECHANIC: a mechanic world level (after the intro) without it
## - IDLE_GATE: a gate no car has to drive through
## - OPEN: from level 11 on (not a breather), more than 3 cars free at the start
## - NO_TRAP: from level 11 on, cargo or turn vehicles but no move that can
##   lose the level

const SIMILARITY := 0.6


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var lines := PackedStringArray()
	var flagged := 0
	var all := []
	for w in LevelCatalog.world_count():
		var mechanic: String = LevelCatalog.world(w).mechanic
		var rows := []
		for i in LevelCatalog.level_count(w):
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelCatalog.path(w, i)))
			var level := LevelData.from_dict(data)
			var report := LevelSolver.solve(level)
			var spec := LevelGenerator.spec(w, i, mechanic)
			var counts := LevelGenerator._count_mechanics(data)
			var traps := LevelGenerator._traps(level, report.order) if counts.cargo + counts.turn > 0 else 0
			rows.append({"w": w, "i": i, "data": data, "cars": data.vehicles.size(), "depth": report.rounds,
				"target": spec.depth, "free": report.first_free, "breather": i in LevelGenerator.BREATHERS,
				"hard": i in LevelGenerator.HARD, "counts": counts, "sig": _signature(data),
				"size": "%dx%d" % [data.cols, data.rows], "flags": [],
				"sharp": spec.get("sharp", false), "traps": traps})
		_flag(rows, mechanic)
		all.append(rows)

	for rows in all:
		_flag_similar(rows)
	for rows in all:
		var w: int = rows[0].w
		lines.append("\n## World %d (%s)\n" % [w + 1, LevelCatalog.world(w).id])
		lines.append("| Lvl | Board | Cars | Waves (target) | Free at start | Traps | Mechanics | Flags |")
		lines.append("|---|---|---|---|---|---|---|---|")
		for r in rows:
			var mech := PackedStringArray()
			for m in r.counts:
				if r.counts[m] > 0:
					mech.append("%s %d" % [m, r.counts[m]])
			var tag := " (breather)" if r.breather else (" (hard)" if r.hard else "")
			lines.append("| %d%s | %s | %d | %d (%d) | %d | %d | %s | %s |" % [r.i + 1, tag, r.size, r.cars, r.depth,
				r.target, r.free, r.traps, ", ".join(mech), ", ".join(r.flags)])
			if not r.flags.is_empty():
				flagged += 1
	var text := "# Level quality report\n\n%d of %d levels flagged.\n" % [flagged, all.reduce(func(a, r): return a + r.size(), 0)] + "\n".join(lines) + "\n"
	print(text)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
	quit()


func _flag(rows: Array, mechanic: String) -> void:
	var last_depth := -1
	var recent: Array = []
	for r in rows:
		if not r.breather:
			if r.free * 2 > r.cars or r.depth <= r.target - 2:
				r.flags.append("EASY")
			if r.sharp and r.free > 3:
				r.flags.append("OPEN")
			if r.sharp and r.traps == 0 and r.counts.cargo + r.counts.turn > 0:
				r.flags.append("NO_TRAP")
			if last_depth >= 0 and r.depth < last_depth - 2 and r.i % LevelGenerator.ACT_LENGTH != 0:
				r.flags.append("DIP")
			if r.hard and not recent.is_empty() and r.depth <= recent.max():
				r.flags.append("SOFT_HARD")
			last_depth = r.depth
			recent.append(r.depth)
			if recent.size() > 3:
				recent.pop_front()
		if mechanic != "" and r.i >= 2 and r.counts[mechanic] == 0:
			r.flags.append("NO_MECHANIC")
		if r.counts.gate > LevelGenerator._gates_in_the_way(r.data):
			r.flags.append("IDLE_GATE")


func _flag_similar(rows: Array) -> void:
	for a in rows.size():
		for b in range(a + 1, rows.size()):
			var ra: Dictionary = rows[a]
			var rb: Dictionary = rows[b]
			if ra.size != rb.size:
				continue
			var inter := 0
			for key in ra.sig:
				if rb.sig.has(key):
					inter += 1
			var union: int = ra.sig.size() + rb.sig.size() - inter
			if union > 0 and float(inter) / union >= SIMILARITY:
				rb.flags.append("SIMILAR to %d" % (ra.i + 1))


static func _signature(data: Dictionary) -> Dictionary:
	var sig := {}
	for e in data.vehicles:
		sig["%d,%d,%s,%s" % [e.col, e.row, e.dir, VehicleCatalog.cells(e.type)]] = true
	return sig
