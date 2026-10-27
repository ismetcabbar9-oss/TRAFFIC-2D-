class_name Haptics
## Short vibrations on phones/tablets (needs the VIBRATE permission on Android).

static var enabled := true


static func pulse(duration_ms: int, amplitude := -1.0) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms, amplitude)
