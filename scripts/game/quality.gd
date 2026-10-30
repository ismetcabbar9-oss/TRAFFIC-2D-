class_name Quality
## Graphics quality: "auto" (default), "high" or "low". Low turns off shadows,
## renders the 3D view at 75% resolution and thins out the scenery, for older
## and cheaper phones. Auto starts low on weak devices (Compatibility
## renderer, few CPU cores) and drops to low for good if the first levels run
## below LOW_FPS.

const LOW_FPS := 40.0
const LOW_SCALE := 0.75
const SAMPLE_SECONDS := 6.0 ## how long auto mode measures a level


static func is_low(progress: Node) -> bool:
	match progress.graphics:
		"low":
			return true
		"high":
			return false
	return progress.flag("auto_low_graphics") or weak_device()


static func weak_device() -> bool:
	if _dev_tool():
		return false # screenshots and measurements use the full look unless asked
	return RenderingServer.get_current_rendering_method() == "gl_compatibility" or OS.get_processor_count() <= 4


## A dev tool script drives the game (its main loop has a script).
static func _dev_tool() -> bool:
	return (Engine.get_main_loop() as Object).get_script() != null


## Applies the setting to the game scene's light and viewport (the scenery
## asks is_low itself when it is built).
static func apply(progress: Node, sun: DirectionalLight3D, viewport: Viewport) -> void:
	var low := is_low(progress)
	sun.shadow_enabled = not low
	viewport.scaling_3d_scale = LOW_SCALE if low else 1.0


## Auto mode: frame rate measured during a level; below LOW_FPS the game
## stays on low from now on. Returns true if it just switched.
static func report_fps(progress: Node, fps: float) -> bool:
	if progress.graphics != "auto" or is_low(progress) or fps >= LOW_FPS:
		return false
	if _dev_tool():
		return false # slow off-screen renders say nothing about a player's phone
	progress.set_flag("auto_low_graphics")
	return true
