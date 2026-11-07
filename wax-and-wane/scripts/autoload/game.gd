extends Node
## Settings, records and the save file. Written atomically to user://save.cfg.

signal settings_changed
signal unlocked_now(key: String)

const VERSION := "1.0.1"
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
}
var records := {
	"runs": 0,
	"wins": 0,
	"best_floor": 0,
	"best_finish": 0.0,   # earliest clock minute a run was won at (0 = never)
	"kills": 0,
	"seen_intro": false,
	"unlocked": ["tallow"],
	"daily_date": "",
	"daily_first": 0,
	"daily_best": 0,
}


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


func save() -> void:
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


func _set_bus(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


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
	if settings["vibration"] and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## 0..120 minutes after midnight -> "12:47 AM" / "1:05 AM" / "2:00 AM".
static func clock_text(minutes: float) -> String:
	var m := clampi(int(floor(minutes)), -720, 120)
	if m < 0:
		var pm := 720 + m
		return "%d:%02d PM" % [12 if pm / 60 == 0 else pm / 60, pm % 60]
	var h := m / 60
	return "%d:%02d AM" % [12 if h == 0 else h, m % 60]
