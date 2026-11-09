extends Node
## Settings (shared by every save slot) and the three save slots. Every file is written atomically
## (tmp + rename):
##   user://save.cfg          settings + which slot was used last ([game] slot)
##   user://slot1.cfg ...     a save slot: its difficulty level ([slot] level) and every record
##   user://run1.cfg ...      that slot's Save & Continue snapshot (scripts/game/run_save.gd)
## Game.records is the slot in use (Game.slot): runs, wins, best times, the Journal, unlocks,
## candles, achievements, the run history and Tonight's Candle all live in the slot. An empty slot
## has no file and is never written; it gets one when a candle is first lit in it.
## A 2.0 save (records inside save.cfg, the run in run.cfg) becomes Slot 1 the first time 2.1
## starts, at level 2 (level 1 if Gentle burn was on); the old save.cfg is kept as save_2.0.cfg.

signal settings_changed
signal unlocked_now(key: String)
signal slot_changed

const VERSION := "2.5.0"
const SAVE_PATH := "user://save.cfg"
const SLOTS := 3
const MAX_LEVEL := 4          # world.LEVELS (difficulty 1-4)
const DEFAULT_LEVEL := 2      # Midnight: the game as it was made (and always Tonight's Candle)
const OLD_SAVE := "user://save_2.0.cfg"   # the 2.0 save file, kept as it was before the move
const OLD_RUN := "user://run.cfg"         # 2.0's saved run (moves to run1.cfg)

## In-game clock: the run starts at midnight and the flame dies at the end of the night: 2:00 AM for the
## 4-floor night as it was made, NIGHT_STEP later for every floor past four (the Long Night: 3:30 AM for 7
## floors, dawn at 5:00 AM for 10). night_minutes() is the one place that length is worked out.
const START_MINUTES := 0.0      # 12:00 AM
const END_MINUTES := 120.0      # 2:00 AM: the end of a 4-floor night (night_minutes(4))
const NIGHT_STEP := 30.0        # minutes each floor past four adds to the night (and to a full candle)
const DAWN_MINUTES := 300.0     # 5:00 AM: the end of the longest night (10 floors); the clock never reads later

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
	"fullscreen": false,        # desktop only
	"mouse_aim": true,          # desktop: hold the left button to fire at the cursor
	"touch_controls": "auto",   # auto (shown after a touch) / on / off
	"effects": "full",          # full / lite (lite: no heat haze, shockwaves or low-wax vignette)
	"shot_size": "large" if OS.has_feature("mobile") else "normal",   # enemy shots: normal (9 px) / large (11 px), shot.gd
	"binds": {},                # v2.3: rebound buttons (Controls.rebind; Settings > Keys)
	"magnet": true,             # v2.6: a cleared room's loose drops drift to Tallow (pickup.gd _sweep_wants)
	"aim": "assist",            # v2.6: assist / auto (touch: the right thumb just fires, world.auto_aim) / off
	"reduce_motion": false,     # v2.6: no panel pops, screen wipes or menu slides (UI.calm)
}
## A fresh slot's records (each slot has its own copy in Game.records).
const RECORDS := {
	"runs": 0,
	"wins": 0,
	"best_floor": 0,
	"best_finish": 0.0,   # earliest clock minute a run was won at (0 = never)
	"kills": 0,
	"seen_intro": false,
	"unlocked": ["tallow"],
	"candle": "tallow",   # the candle this slot lights next (the title's Candle Box)
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
var records: Dictionary = RECORDS.duplicate(true)
var slot := 1                 # the save slot in use (1-3), remembered in save.cfg
var level := DEFAULT_LEVEL    # its difficulty (world.LEVELS); a run keeps the level it was lit at
var slot_live := false        # the slot has a file (a candle was lit in it)
## Tests and screenshot tours set this so a staged Journal never reaches the real save file.
var no_save := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()
	apply_settings()


func load_save() -> void:
	var cf := ConfigFile.new()
	var have := cf.load(SAVE_PATH) == OK
	if have:
		for k in settings.keys():
			settings[k] = cf.get_value("settings", k, settings[k])
		if not cf.has_section_key("settings", "aim"):   # v2.6: the old Aim assist switch becomes Aim: Assist / Off
			settings["aim"] = "assist" if settings["aim_assist"] else "off"
	var last := clampi(int(cf.get_value("game", "slot", 1)), 1, SLOTS) if have else 1
	if have and cf.has_section("records") and not _any_slot():
		last = _migrate(cf)
	use_slot(last, false)   # RunSave reads this slot's snapshot itself when it starts


## 2.0 kept every record in save.cfg and the saved run in run.cfg. They become Slot 1 with nothing
## lost (level 1 if Gentle burn was on, else 2); save.cfg is copied to save_2.0.cfg first.
func _migrate(cf: ConfigFile) -> int:
	DirAccess.copy_absolute(_abs(SAVE_PATH), _abs(OLD_SAVE))
	var rec: Dictionary = RECORDS.duplicate(true)
	for k in cf.get_section_keys("records"):   # per-candle records (best_finish_<candle>) included
		rec[k] = cf.get_value("records", k)
	var cand := str(cf.get_value("settings", "candle", "tallow"))
	rec["candle"] = cand if cand in (rec.get("unlocked", []) as Array) else "tallow"
	var lvl := 1 if bool(cf.get_value("settings", "gentle", false)) else DEFAULT_LEVEL
	_write_slot(1, lvl, rec)
	if FileAccess.file_exists(OLD_RUN) and not FileAccess.file_exists(run_path(1)):
		var run := ConfigFile.new()
		if run.load(OLD_RUN) == OK:   # the saved run keeps the level it was lit at, whatever the slot changes to
			run.set_value("run", "level", lvl)
			_store(run, run_path(1))
			DirAccess.remove_absolute(_abs(OLD_RUN))
	# save.cfg keeps only the settings from now on (and which slot was used last)
	var out := ConfigFile.new()
	for k in settings.keys():
		out.set_value("settings", k, settings[k])
	out.set_value("game", "slot", 1)
	_store(out, SAVE_PATH)
	print("[slots] the 2.0 save is Slot 1 now: level %d, %d runs, %d wins" % [lvl, int(rec.get("runs", 0)), int(rec.get("wins", 0))])
	return 1


func save() -> void:
	if no_save:
		return
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.set_value("game", "slot", slot)
	_store(cf, SAVE_PATH)
	if slot_live:
		_write_slot(slot, level, records)


# ---------------------------------------------------------------- save slots

static func slot_path(n: int) -> String:
	return "user://slot%d.cfg" % n


## Save & Continue's file for slot n (scripts/game/run_save.gd).
static func run_path(n: int) -> String:
	return "user://run%d.cfg" % n


func slot_exists(n: int) -> bool:
	return (n == slot and slot_live) or FileAccess.file_exists(slot_path(n))


func _any_slot() -> bool:
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(n)):
			return true
	return false


## Make slot n the one in use: its records and level (an empty slot starts from the defaults).
## RunSave then holds that slot's saved run.
func use_slot(n: int, reload_run := true) -> void:
	n = clampi(n, 1, SLOTS)
	if not (n == slot and slot_live):   # the slot in use is already in memory (and newer than its file)
		if slot_live:
			save()   # the slot we leave is on disk as it is now
		slot = n
		var d := _read_slot(n)
		slot_live = not d.is_empty()
		level = int(d.get("level", DEFAULT_LEVEL))
		records = RECORDS.duplicate(true)
		var rec: Dictionary = d.get("records", {})
		for k in rec:
			records[k] = rec[k]
	if reload_run:
		RunSave.reload()
	slot_changed.emit()


## A slot's level and records ({} for an empty slot). The slot in use comes from memory. Read-only:
## the Slots screen's cards and Steam's list of earned achievements use it.
func slot_data(n: int) -> Dictionary:
	if n == slot:
		return {"level": level, "records": records} if slot_live else {}
	return _read_slot(n)


func _read_slot(n: int) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(slot_path(n)) != OK:
		return {}
	var rec := {}
	if cf.has_section("records"):
		for k in cf.get_section_keys("records"):
			rec[k] = cf.get_value("records", k)
	return {"level": clampi(int(cf.get_value("slot", "level", DEFAULT_LEVEL)), 1, MAX_LEVEL), "records": rec}


## "New candle" on an empty slot: it becomes the slot in use, at this level, and gets its file.
func start_slot(n: int, lvl: int) -> void:
	if not slot_exists(n) and FileAccess.file_exists(run_path(n)):
		DirAccess.remove_absolute(_abs(run_path(n)))   # a new slot starts clean (no stray saved run)
	use_slot(n)
	level = clampi(lvl, 1, MAX_LEVEL)
	slot_live = true
	save()


## A candle was lit (world._ready): an empty slot in use gets its file now (Tonight's Candle or a
## seed from the title on a fresh install starts Slot 1 at level 2).
func light_slot() -> void:
	slot_live = true


## Change a slot's difficulty between runs (a saved run keeps the level it was lit at).
func set_level(n: int, lvl: int) -> void:
	lvl = clampi(lvl, 1, MAX_LEVEL)
	if n == slot:
		level = lvl
		save()
		slot_changed.emit()
		return
	var cf := ConfigFile.new()
	if cf.load(slot_path(n)) == OK:
		cf.set_value("slot", "level", lvl)
		_store(cf, slot_path(n))


## Delete a slot and its saved run for good (the Slots screen asks twice first).
func delete_slot(n: int) -> void:
	for p in [slot_path(n), run_path(n)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(_abs(p))
	if n == slot:
		slot_live = false
		use_slot(n)   # the slot in use is empty now: fresh records, level 2


## Every achievement earned in any slot (Steam gets them all, whichever slot earned them).
func all_achievements() -> Dictionary:
	var out := {}
	for n in range(1, SLOTS + 1):
		var a: Variant = (slot_data(n).get("records", {}) as Dictionary).get("achievements", {})
		if a is Dictionary:
			out.merge(a)
	return out


func _write_slot(n: int, lvl: int, rec: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.set_value("slot", "level", lvl)
	cf.set_value("slot", "version", VERSION)
	for k in rec.keys():
		cf.set_value("records", k, rec[k])
	_store(cf, slot_path(n))


## Atomic write: a crash mid-save leaves the old file whole.
static func _store(cf: ConfigFile, path: String) -> void:
	var tmp := path + ".tmp"
	if cf.save(tmp) == OK:
		DirAccess.rename_absolute(_abs(tmp), _abs(path))


static func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


# ---------------------------------------------------------------- settings

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


## Minutes in a night of `floors` floors: 120 (2:00 AM) for 4, 30 more for every floor past four. A full
## candle holds the whole night (world.night_minutes, the candle's wax), so the clock = night - wax.
static func night_minutes(floors: int) -> float:
	return END_MINUTES + NIGHT_STEP * float(maxi(0, floors - 4))


## 0..300 minutes after midnight -> "12:47 AM" / "1:05 AM" / "2:00 AM" / "3:30 AM".
## The night never starts before midnight: wax past a full candle (minutes < 0) reads
## "12:00 AM +8 min" (8 spare minutes). `spare = false` gives just "12:00 AM" (the HUD shows the
## spare minutes in their own small label, see spare_minutes()).
static func clock_text(minutes: float, spare := true) -> String:
	var m := clampi(int(floor(minutes)), 0, int(DAWN_MINUTES))
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
