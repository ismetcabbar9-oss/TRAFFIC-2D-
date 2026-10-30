extends SceneTree
## Dev helper: screenshots every menu page in one language with sample progress.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution WxH --script res://tools/capture_menu.gd -- <out_prefix> <en|tr>
## The sample progress is never saved.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "user://menu"
	await process_frame # autoloads load the real save in their _ready first
	var progress := root.get_node("Progress")
	progress.language = args[1] if args.size() > 1 else "en"
	progress._apply_settings()
	progress.coins = 1240
	progress.levels = {}
	var sample := [3, 3, 2, 3, 1, 2, 3]
	for i in sample.size():
		progress.levels["0:%d" % i] = {"stars": sample[i], "time": 20.0, "combo": 3}
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	progress.inventory = {"hint": 2, "crane": 1}
	progress.owned = ["arrow_gold", "smoke_pink"]
	progress.equipped_items = {"arrow": "arrow_gold"}
	progress.gift = {"last_day": Daily.day_before(Daily.today()), "index": 2}
	progress.daily_puzzle = {"last_day": Daily.day_before(Daily.today()), "streak": 3}
	progress.stats = {"cars": 140, "best_combo": 5, "cranes": 1}
	progress.claimed = ["first_win"]
	for page in ["home", "world", "settings", "credits", "shop", "garage", "gift", "achievements", "wheel"]:
		menu._show(page, false)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s_%s.png" % [prefix, page])
	print("saved ", prefix)
	quit()
