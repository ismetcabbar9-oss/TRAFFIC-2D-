extends Node
## Autoload "Sfx": plays short sounds from a small pool of players so several
## can overlap, and the background music (cross-faded between tracks, ducked
## under jingles). Sounds and tracks are registered by name below.

const SOUNDS := {
	"exhaust_pop": ["res://assets/audio/sfx/exhaust_pop.ogg"],
	"car_go": ["res://assets/audio/sfx/car_go.ogg"],
	"engine_sports": ["res://assets/audio/sfx/engine_sports.ogg"],
	"engine_truck": ["res://assets/audio/sfx/engine_truck.ogg"],
	"tire_squeal": ["res://assets/audio/sfx/tire_squeal.ogg"],
	"horn": ["res://assets/audio/sfx/horn.ogg"],
	"horn_double": ["res://assets/audio/sfx/horn_double.ogg"],
	"horn_sedan": ["res://assets/audio/sfx/horn_sedan.ogg"],
	"horn_small": ["res://assets/audio/sfx/horn_small.ogg"],
	"horn_truck": ["res://assets/audio/sfx/horn_truck.ogg"],
	"horn_air": ["res://assets/audio/sfx/horn_air.ogg"],
	"siren_police": ["res://assets/audio/sfx/siren_police.ogg"],
	"siren_ambulance": ["res://assets/audio/sfx/siren_ambulance.ogg"],
	"crash": [
		"res://assets/audio/sfx/crash_0.ogg",
		"res://assets/audio/sfx/crash_1.ogg",
		"res://assets/audio/sfx/crash_2.ogg",
	],
	"ui_click": ["res://assets/audio/sfx/ui_click.ogg"],
	"combo": ["res://assets/audio/sfx/combo.ogg"],
	"celebrate": ["res://assets/audio/sfx/celebrate.ogg"],
	"lock_rattle": ["res://assets/audio/sfx/lock_rattle.ogg"],
	"unlock": ["res://assets/audio/sfx/unlock.ogg"],
	"gate_open": ["res://assets/audio/sfx/gate_open.ogg"],
	"win": ["res://assets/audio/music/win.ogg"],
	"lose": ["res://assets/audio/music/lose.ogg"],
}
const POOL_SIZE := 16
const MUSIC := {
	"menu": "res://assets/audio/music/menu_theme.ogg",
	"game": "res://assets/audio/music/game_theme.ogg",
	"beach": "res://assets/audio/music/beach_theme.ogg",
	"snow": "res://assets/audio/music/snow_theme.ogg",
	"night": "res://assets/audio/music/night_theme.ogg",
	"airport": "res://assets/audio/music/airport_theme.ogg",
}
const MUSIC_DB := -9.0 ## music sits under the effects
const MUSIC_FADE := 0.8 ## seconds for a cross-fade

var music_enabled := true:
	set(value):
		music_enabled = value
		_apply_music_volume(0.4)

var enabled := true

var _streams := {} ## name -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = [] ## two players for cross-fades
var _music_active := 0
var _music_name := ""
var _duck_db := 0.0


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
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


func _exit_tree() -> void:
	for p in _music + _players:
		p.stop()
		p.stream = null


## Starts a music track (no-op if it is already playing), fading the old one out.
func play_music(track: String) -> void:
	if not MUSIC.has(track):
		track = "game" # worlds without their own track yet
	if track == _music_name:
		return
	_music_name = track
	var old := _music[_music_active]
	_music_active = 1 - _music_active
	var new := _music[_music_active]
	new.stream = load(MUSIC[track])
	new.volume_db = -80.0
	new.play()
	create_tween().tween_property(old, "volume_db", -80.0, MUSIC_FADE)
	get_tree().create_timer(MUSIC_FADE).timeout.connect(func(): if _music[_music_active] != old: old.stop())
	_apply_music_volume(MUSIC_FADE)


## Lowers the music for `seconds` (e.g. under a win jingle), then restores it.
func duck_music(seconds: float, depth_db := -12.0) -> void:
	_duck_db = depth_db
	_apply_music_volume(0.15)
	get_tree().create_timer(seconds).timeout.connect(func():
		_duck_db = 0.0
		_apply_music_volume(0.8))


func _apply_music_volume(fade: float) -> void:
	if _music.is_empty():
		return
	var target := MUSIC_DB + _duck_db if music_enabled else -80.0
	create_tween().tween_property(_music[_music_active], "volume_db", target, fade)


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
