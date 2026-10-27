extends Node
## Autoload "Sfx": plays short sounds from a small pool of players so several
## can overlap. Sounds are registered by name below.

const SOUNDS := {
	"exhaust_pop": ["res://assets/audio/sfx/exhaust_pop.ogg"],
	"car_go": ["res://assets/audio/sfx/car_go.ogg"],
	"horn": ["res://assets/audio/sfx/horn.ogg"],
	"horn_double": ["res://assets/audio/sfx/horn_double.ogg"],
	"crash": [
		"res://assets/audio/sfx/crash_0.ogg",
		"res://assets/audio/sfx/crash_1.ogg",
		"res://assets/audio/sfx/crash_2.ogg",
	],
	"ui_click": ["res://assets/audio/sfx/ui_click.ogg"],
	"win": ["res://assets/audio/music/win.ogg"],
	"lose": ["res://assets/audio/music/lose.ogg"],
}
const POOL_SIZE := 12

var enabled := true

var _streams := {} ## name -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUNDS:
		var list: Array[AudioStream] = []
		for path in SOUNDS[sound_name]:
			list.append(load(path))
		_streams[sound_name] = list
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Plays a sound; `pitch_jitter` randomizes pitch by ± that fraction.
func play(sound_name: String, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.06) -> void:
	if not enabled:
		return
	var list: Array = _streams.get(sound_name, [])
	if list.is_empty():
		push_warning("Unknown sound '%s'" % sound_name)
		return
	# Prefer an idle player; otherwise steal the oldest one.
	var player := _players[_next]
	for i in POOL_SIZE:
		var candidate := _players[(_next + i) % POOL_SIZE]
		if not candidate.playing:
			player = candidate
			break
	_next = (_players.find(player) + 1) % POOL_SIZE
	player.stream = list.pick_random()
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	player.play()
