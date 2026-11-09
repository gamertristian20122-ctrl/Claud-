extends Node
## Settings, records and the save file. Written atomically to user://save.cfg.

signal settings_changed
signal unlocked_now(key: String)

const VERSION := "2.0.0"
const SAVE_PATH := "user://save.cfg"

## In-game clock: the run starts at midnight and the flame dies at 2:00 AM.
const START_MINUTES := 0.0      # 12:00 AM
const END_MINUTES := 120.0      # 2:00 AM

## 1.0 normally; the play-test bot raises it to run faster than real time.
var base_time_scale := 1.0

var settings := {
	"music": 0.7,
	"sfx": 0.85,
	"vibration": true,
	"shake": true,
	"aim_assist": true,
	"show_fps": false,
	"swap_sticks": false,
	"candle": "tallow",
	"gentle": false,
	"fullscreen": false,        # desktop only
	"mouse_aim": true,          # desktop: hold the left button to fire at the cursor
	"touch_controls": "auto",   # auto (shown after a touch) / on / off
	"effects": "full",          # full / lite (lite: no heat haze, shockwaves or low-wax vignette)
}
var records := {
	"runs": 0,
	"wins": 0,
	"best_floor": 0,
	"best_finish": 0.0,   # earliest clock minute a run was won at (0 = never)
	"kills": 0,
	"seen_intro": false,
	"unlocked": ["tallow"],
	"tips": {},
	"daily_date": "",
	"daily_first": 0,
	"daily_best": 0,
	"achievements": {},   # id -> unix time it was earned (see scripts/autoload/achievements.gd)
	"rites_done": [],     # every Candle Rite ever completed
	# ---- the Journal (scripts/game/records.gd keeps these up to date)
	"seen_relics": {},    # relic / keepsake / gift id -> 1 (looked at on a pedestal or in a shop)
	"taken_relics": {},   # id -> times taken
	"met": {},            # creature kind (or "mini:<kind>") -> 1
	"kills_by_kind": {},  # creature kind -> creatures snuffed
	"bosses_beaten": {},  # guardian kind -> {"n": times, "best": fastest fight in seconds}
	"run_history": [],    # the last 20 runs, newest first
	"best_streak": 0,
	"wins_by_candle": {}, # candle id -> wins
	"daily_history": [],  # [{date, first, best, won}], newest first (14 nights)
	"rooms_found": {},    # special room type -> 1
	"journal_new": {},    # Journal entry key -> 1 until it has been looked at
	"unlocks_known": [],  # unlocked relics / keepsakes already announced
}
## Tests and screenshot tours set this so a staged Journal never reaches the real save file.
var no_save := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()
	apply_settings()


func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cf.get_value("settings", k, settings[k])
	for k in records.keys():
		records[k] = cf.get_value("records", k, records[k])
	if cf.has_section("records"):
		# per-candle records (best_finish_<candle>) are not in the defaults above
		for k in cf.get_section_keys("records"):
			if not records.has(k):
				records[k] = cf.get_value("records", k)


func save() -> void:
	if no_save:
		return
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	for k in records.keys():
		cf.set_value("records", k, records[k])
	var tmp := SAVE_PATH + ".tmp"
	if cf.save(tmp) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	save()
	settings_changed.emit()


func apply_settings() -> void:
	_set_bus("Music", settings["music"])
	_set_bus("SFX", settings["sfx"])
	_apply_window()


## Desktop: fullscreen or a window (a maximised window stays maximised).
func _apply_window() -> void:
	if not OS.has_feature("pc") or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if settings.get("fullscreen", false) and not full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not settings.get("fullscreen", false) and full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## True the first few times a tip is requested (tips teach new mechanics once, then stay quiet).
func tip(key: String, times := 2) -> bool:
	var t: Dictionary = records.get("tips", {})
	var n: int = t.get(key, 0)
	if n >= times:
		return false
	t[key] = n + 1
	records["tips"] = t
	set_meta("tip_frame", Engine.get_process_frames())   # the HUD holds a tip that lands mid boss fight
	return true


## Unlock a candle; returns true the first time.
func unlock(key: String) -> bool:
	var u: Array = records.get("unlocked", ["tallow"])
	if key in u:
		return false
	u.append(key)
	records["unlocked"] = u
	save()
	unlocked_now.emit(key)
	return true


func vibrate(ms: int) -> void:
	if not settings["vibration"]:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
	# gamepads rumble too (strength grows with the length of the buzz)
	var k := clampf(ms / 80.0, 0.2, 1.0)
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, 0.5 * k, 0.8 * k, ms / 1000.0)


## 0..120 minutes after midnight -> "12:47 AM" / "1:05 AM" / "2:00 AM".
## The night never starts before midnight: wax past a full candle (minutes < 0) reads
## "12:00 AM +8 min" (8 spare minutes). `spare = false` gives just "12:00 AM" (the HUD shows the
## spare minutes in their own small label, see spare_minutes()).
static func clock_text(minutes: float, spare := true) -> String:
	var m := clampi(int(floor(minutes)), 0, 120)
	var h := m / 60
	var t := "%d:%02d AM" % [12 if h == 0 else h, m % 60]
	var s := spare_minutes(minutes)
	if spare and s > 0:
		t += " +%d min" % s
	return t


## The whole minute the clock shows for `minutes` (clock_text floors): rules that promise a time
## ("done by 1:00 AM", "before 1:00 AM") compare this, so they agree with what the player saw.
static func shown_minute(minutes: float) -> int:
	return int(floor(minutes))


## Whole minutes of wax beyond a full night (0 when the clock is at or past midnight).
static func spare_minutes(minutes: float) -> int:
	return maxi(0, int(floor(-minutes)))
