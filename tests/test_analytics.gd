extends TestCase
## Analytics events use GameAnalytics' format and signing.

const AnalyticsScript := preload("res://scripts/game/analytics.gd")


func test_progression_event_format() -> void:
	var a: Node = AnalyticsScript.new()
	a.level("Complete", 1, 6, false, 3, {"time": 12.5})
	var e: Dictionary = a._queue[0]
	check_eq(e.category, "progression", "category")
	check_eq(e.event_id, "Complete:world2:level07", "event id")
	check_eq(e.score, 3, "score")
	check_eq(e.v, 2, "api version")
	for field in ["user_id", "session_id", "session_num", "client_ts", "sdk_version", "platform", "os_version", "device", "build"]:
		check(e.has(field), "has " + field)
	check_eq(a._queue[1].event_id, "level:complete:time", "extra values as design events")
	check_eq(a._queue[1].value, 12.5, "design value")
	a.free()


func test_resource_and_daily_events() -> void:
	var a: Node = AnalyticsScript.new()
	a.coins("Sink", 120, "rescue", "crane")
	a.coins("Source", 0, "level", "world1") # nothing earned: no event
	a.level("Start", 0, 0, true)
	check_eq(a._queue.size(), 2, "zero amounts are skipped")
	check_eq(a._queue[0].event_id, "Sink:coins:rescue:crane", "resource id")
	check_eq(a._queue[0].amount, 120, "amount")
	check_eq(a._queue[1].event_id, "Start:daily", "daily puzzle id")
	a.free()


func test_body_signature() -> void:
	var a: Node = AnalyticsScript.new()
	a._config = {"secret_key": "secret123"}
	var headers: PackedStringArray = a._headers('[{"a":1}]')
	check_eq(headers[0], "Authorization: mWsAHF6DXlaPll8Bmiak0ujCQnlvdS7EBHKUKe+gRt8=", "HMAC-SHA256, base64")
	a.free()


func test_uuid_shape() -> void:
	var id: String = AnalyticsScript._uuid()
	check_eq(id.length(), 36, "uuid length")
	check_eq(id[14], "4", "version 4")
