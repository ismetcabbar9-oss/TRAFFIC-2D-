extends Node
## Autoload "Analytics": every measurement goes through here.
##
## Events follow GameAnalytics' categories (progression, resource, design,
## user / session_end) so they can be sent to its REST API unchanged. They
## queue on the device (user://analytics_queue.json) and are sent in batches
## when keys are set in res://data/analytics.json; until then they only stay
## in the queue and in `recent` (shown in developer mode).

const CONFIG_PATH := "res://data/analytics.json"
const QUEUE_PATH := "user://analytics_queue.json"
const ID_PATH := "user://analytics_id.cfg"
const API := "https://api.gameanalytics.com/v2/%s/%s"
const SANDBOX_API := "https://sandbox-api.gameanalytics.com/v2/%s/%s"
const RECENT_MAX := 100

var recent: Array = [] ## newest last: {"time", "category", "event_id", ...}
var sending_enabled := false ## keys present and the server said yes

var _config := {}
var _queue: Array = []
var _user_id := ""
var _session_id := ""
var _session_num := 0
var _session_start := 0
var _http: HTTPRequest
var _in_flight := 0 ## events in the request being sent
var _timer := 0.0
var _dirty := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	_config = parsed if parsed is Dictionary else {}
	_load_identity()
	_load_queue()
	_session_id = _uuid()
	_session_start = int(Time.get_unix_time_from_system())
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_add("user", {})
	if str(_config.get("game_key", "")) != "" and str(_config.get("secret_key", "")) != "":
		_send_init()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < float(_config.get("flush_seconds", 20)):
		return
	_timer = 0.0
	flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_add("session_end", {"length": int(Time.get_unix_time_from_system()) - _session_start})
		_save_queue()
		flush()


# --- Events ---------------------------------------------------------------------------

## Level started / completed / failed. `status`: "Start", "Complete" or "Fail".
## The id reads e.g. "Complete:world2:level07" (daily puzzles: "daily").
func level(status: String, world: int, level_index: int, daily := false, score := -1, extra := {}) -> void:
	var id := "%s:daily" % status if daily else "%s:world%d:level%02d" % [status, world + 1, level_index + 1]
	var fields := {"event_id": id}
	if score >= 0:
		fields["score"] = score
	_add("progression", fields)
	if not extra.is_empty():
		for key in extra:
			design("level:%s:%s" % [status.to_lower(), key], float(extra[key]))


## Coins earned ("Source") or spent ("Sink"); `item_type`/`item` say where.
func coins(flow: String, amount: int, item_type: String, item: String) -> void:
	if amount <= 0:
		return
	_add("resource", {"event_id": "%s:coins:%s:%s" % [flow, item_type, item], "amount": amount})


## Anything else, e.g. "rescue:hint:free" or "ad:rewarded:continue".
func design(event_id: String, value := NAN) -> void:
	var fields := {"event_id": event_id}
	if not is_nan(value):
		fields["value"] = value
	_add("design", fields)


# --- Queue and sending -------------------------------------------------------------------

func _add(category: String, fields: Dictionary) -> void:
	var e := {
		"category": category,
		"v": 2,
		"user_id": _user_id,
		"session_id": _session_id,
		"session_num": _session_num,
		"client_ts": int(Time.get_unix_time_from_system()),
		"sdk_version": "rest api v2",
		"platform": _platform(),
		"os_version": "%s %s" % [_platform(), OS.get_version()],
		"device": OS.get_model_name() if OS.get_model_name() != "GenericDevice" else "unknown",
		"manufacturer": "unknown",
		"build": str(ProjectSettings.get_setting("application/config/version", "dev")),
	}
	e.merge(fields, true)
	_queue.append(e)
	var max_queue := int(_config.get("max_queue", 2000))
	if _queue.size() > max_queue:
		_queue = _queue.slice(_queue.size() - max_queue)
	recent.append({"time": Time.get_time_string_from_system(), "category": category,
		"event_id": fields.get("event_id", ""), "value": fields.get("value", fields.get("amount", ""))})
	if recent.size() > RECENT_MAX:
		recent.pop_front()
	_dirty = true
	if _queue.size() % 10 == 0:
		_save_queue()


func queued() -> int:
	return _queue.size()


## Sends the oldest queued events (one batch at a time) when allowed.
func flush() -> void:
	if _dirty:
		_save_queue()
	if not sending_enabled or _in_flight > 0 or _queue.is_empty():
		return
	var batch := _queue.slice(0, int(_config.get("batch_size", 100)))
	_in_flight = batch.size()
	var body := JSON.stringify(batch)
	var err := _http.request(_url("events"), _headers(body), HTTPClient.METHOD_POST, body)
	if err != OK:
		_in_flight = 0


func _send_init() -> void:
	var body := JSON.stringify({"platform": _platform(), "os_version": "%s %s" % [_platform(), OS.get_version()],
		"sdk_version": "rest api v2"})
	_in_flight = -1 # marks the init request
	if _http.request(_url("init"), _headers(body), HTTPClient.METHOD_POST, body) != OK:
		_in_flight = 0


func _on_request_completed(_result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	if _in_flight < 0: # init
		_in_flight = 0
		var answer: Variant = JSON.parse_string(body.get_string_from_utf8())
		sending_enabled = code == 200 and answer is Dictionary and bool(answer.get("enabled", true))
		if sending_enabled:
			flush()
		return
	if code == 200:
		_queue = _queue.slice(_in_flight)
		_save_queue()
	elif code == 400:
		# The server rejected the batch as malformed: drop it rather than retry forever.
		push_warning("Analytics batch rejected: %s" % body.get_string_from_utf8().left(300))
		_queue = _queue.slice(_in_flight)
	_in_flight = 0


func _url(path: String) -> String:
	var base := SANDBOX_API if bool(_config.get("sandbox", false)) else API
	return base % [str(_config.game_key), path]


## GameAnalytics signs each body with HMAC-SHA256 of the secret key.
func _headers(body: String) -> PackedStringArray:
	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA256, str(_config.secret_key).to_utf8_buffer())
	hmac.update(body.to_utf8_buffer())
	return PackedStringArray([
		"Authorization: " + Marshalls.raw_to_base64(hmac.finish()),
		"Content-Type: application/json",
	])


# --- Storage ----------------------------------------------------------------------------

func _load_identity() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ID_PATH)
	_user_id = cfg.get_value("analytics", "user_id", "")
	if _user_id == "":
		_user_id = _uuid()
	_session_num = int(cfg.get_value("analytics", "sessions", 0)) + 1
	cfg.set_value("analytics", "user_id", _user_id)
	cfg.set_value("analytics", "sessions", _session_num)
	cfg.save(ID_PATH)


func _load_queue() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH)) if FileAccess.file_exists(QUEUE_PATH) else null
	_queue = parsed if parsed is Array else []


func _save_queue() -> void:
	_dirty = false
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_queue))


static func _platform() -> String:
	match OS.get_name():
		"Android": return "android"
		"iOS": return "ios"
		"Windows": return "windows"
		"macOS": return "mac_osx"
	return "linux"


static func _uuid() -> String:
	var b := PackedByteArray()
	for i in 16:
		b.append(randi() % 256)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
