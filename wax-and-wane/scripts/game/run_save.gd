extends Node
## Save & Continue (autoload "RunSave").
##
## At the start of every floor the run is snapshotted to the save slot's own file, user://run<N>.cfg
## (Game.run_path; atomic write, like Game.save): the run seed, floor, candle, level, daily flag, the
## omens so far, the relic pool, every plain player stat (final values, so relic effects come back
## exactly), relics, rites, keepsake + charge, coins, bombs, wax, wax_max, guttering and the run
## counters. `snap` is the snapshot of the slot in use (Game.slot); peek(n) reads another slot's.
## "Continue" rebuilds that floor from the seed (the same house, the same loot) and restores the
## stats, at the level the run was lit at. The snapshot is deleted the moment a run ends (death,
## win, give up).
##
## world.gd hooks (one line each):
##   _ready():        _start_floor(RunSave.begin(self))     # floor 1, or the saved floor
##   _start_floor():  RunSave.on_floor_start(self)           # last line
## Other streams: a world var that must survive a Continue goes in WORLD_KEYS, or give the world
## save_extra() -> Dictionary / load_extra(d: Dictionary). New Player stats are picked up by
## themselves (any plain script variable not in SKIP_PLAYER and not starting with "_").

const FORMAT := 1
## Player variables that are moment-to-moment state, not stats.
const SKIP_PLAYER := ["world", "vel", "move_input", "aim_input", "facing", "fire_cd", "invuln", "dead",
	"frozen", "face_state", "chill_t", "move_cd"]
## World variables a run carries from floor to floor.
const WORLD_KEYS := ["kills", "rooms_cleared", "run_time", "best_streak", "hits_total", "boss_hits", "pact",
	"declined_smoke", "altar_floor", "bomb_radius", "unlocked_this_run", "relic_pool", "_bells", "_bell_paid"]

var snap := {}            # what is on disk: {"run": {...}, "player": {...}, "world": {...}}
var _pending := false     # the title asked to continue; the next world picks it up
var _restore := {}        # snapshot being restored into the world that is starting
var _omens := {}          # floor -> omen, so a rebuilt floor rolls the same omen
var _world: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	snap = _read(Game.run_path(Game.slot))


## Game.use_slot: the slot in use changed (or came back from the disk).
func reload() -> void:
	_pending = false
	_restore = {}
	snap = _read(Game.run_path(Game.slot))


func has_snapshot() -> bool:
	return not snap.is_empty()


## "Floor 3 - 12:41 AM"
func summary() -> String:
	return summary_of(snap)


static func summary_of(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	var r: Dictionary = s["run"]
	return "Floor %d - %s" % [int(r["floor"]), Game.clock_text(float(r["clock"]))]


## Another slot's saved run ({} if it has none); the slot in use answers from memory.
func peek(n: int) -> Dictionary:
	return snap if n == Game.slot else _read(Game.run_path(n))


## The title's Continue button.
func continue_run(main: Node) -> void:
	if snap.is_empty():
		return
	var r: Dictionary = snap["run"]
	_pending = true
	Audio.play("ui_open")
	# the saved seed rebuilds the house; it does not make an ordinary run "a seeded run" (QA-08).
	# Snapshots from before 2.0 kept the flag only in the Journal's extra.
	var old: Dictionary = (snap["world"].get("__extra", {}) as Dictionary).get("records", {})
	var params := {"seed": int(r["run_seed"]), "candle": str(r["candle"]), "daily": bool(r["daily"]),
		"seeded": bool(r.get("seeded", old.get("seeded", false))), "continued": true,
		"level": int(r.get("level", Game.level))}   # the level it was lit at (2.0 runs: the slot's)
	if r.has("date"):
		params["date"] = str(r["date"])   # Tonight's Candle keeps the night it was lit
	main.goto("game", params)


## world._ready(): returns the floor to start on (1 for a new run).
func begin(w: Node) -> int:
	_world = w
	_restore = {}
	_omens = {}
	var go := _pending
	_pending = false
	if not go or snap.is_empty():
		return 1
	var r: Dictionary = snap["run"]
	if int(r["run_seed"]) != int(w.run_seed) or str(r["candle"]) != str(w.candle_id):
		return 1
	# the same run goes on: it was counted when it was first lit
	Game.records["runs"] = maxi(0, int(Game.records["runs"]) - 1)
	_restore = snap.duplicate(true)
	_omens = (r.get("omens", {}) as Dictionary).duplicate()
	var f := int(r["floor"])
	# the floor rolls its omen avoiding the previous floor's, so put that one back first
	w.omen = str(_omens.get(f - 1, ""))
	var wd: Dictionary = _restore["world"]
	if wd.has("relic_pool"):
		(w.relic_pool as Array).assign(wd["relic_pool"])
	return f


## world._start_floor(), last line: restore a continued run, then snapshot this floor's start.
func on_floor_start(w: Node) -> void:
	_world = w
	if not _restore.is_empty():
		var shown := Game.clock_text(w.clock_minutes())   # the floor banner was written with this
		_apply(w, _restore)
		_restore = {}
		var hud: Variant = w.hud
		if hud and "banner_sub" in hud and hud.banner_sub:
			hud.banner_sub.text = str(hud.banner_sub.text).replace(shown, Game.clock_text(w.clock_minutes()))
		if hud and "shown_wax" in hud:
			hud.shown_wax = float(w.player.wax)
			hud.ghost_wax = float(w.player.wax)
	_omens[int(w.floor_num)] = str(w.omen)
	snap = _capture(w)
	_write(snap)


## Forget the saved run (it ended).
func clear() -> void:
	snap = {}
	_restore = {}
	var path := Game.run_path(Game.slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Throw away slot n's saved run (a new run in that slot replaces it).
func clear_slot(n: int) -> void:
	if n == Game.slot:
		clear()
		return
	var path := Game.run_path(n)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Make sure the floor-start snapshot is on disk (window closed, app sent to the background).
func flush() -> void:
	if not snap.is_empty() and _run_live():
		_write(snap)


func _run_live() -> bool:
	return is_instance_valid(_world) and _world.is_inside_tree() and not bool(_world.get("finished"))


func _process(_dt: float) -> void:
	# a finished run (death, win, give up) can never be continued
	if is_instance_valid(_world) and bool(_world.get("finished")):
		_world = null
		clear()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			flush()
			if not OS.has_feature("mobile"):
				get_tree().quit()       # desktop: the window's X closes the game (the run is saved)
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST:
			flush()


# ---------------------------------------------------------------- capture / apply

static func _plain(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_COLOR, TYPE_VECTOR2, TYPE_VECTOR2I:
			return true
		TYPE_ARRAY:
			for x in v:
				if not _plain(x):
					return false
			return true
		TYPE_DICTIONARY:
			for k in v:
				if not _plain(k) or not _plain(v[k]):
					return false
			return true
	return false


func _capture(w: Node) -> Dictionary:
	var p: Node = w.player
	var pd := {}
	for prop in p.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = prop["name"]
		if n.begins_with("_") or n in SKIP_PLAYER:
			continue
		var v: Variant = p.get(n)
		if typeof(v) in [TYPE_VECTOR2, TYPE_VECTOR2I]:
			continue
		if _plain(v):
			pd[n] = v.duplicate(true) if v is Array or v is Dictionary else v
	var wd := {}
	for n in WORLD_KEYS:
		var v: Variant = w.get(n)
		if v != null and _plain(v):
			wd[n] = v.duplicate(true) if v is Array or v is Dictionary else v
	if w.has_method("save_extra"):
		wd["__extra"] = w.save_extra()
	var run := {
		"format": FORMAT,
		"version": Game.VERSION,
		"run_seed": int(w.run_seed),
		"floor": int(w.floor_num),
		"candle": str(w.candle_id),
		"level": int(w.level),
		"daily": bool(w.daily),
		"seeded": bool(w.get_meta("seeded", false)),
		"date": str(w.daily_date),
		"omen": str(w.omen),
		"omens": _omens.duplicate(),
		"clock": float(w.clock_minutes()),
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	return {"run": run, "player": pd, "world": wd}


func _apply(w: Node, s: Dictionary) -> void:
	var p: Node = w.player
	var pd: Dictionary = s["player"]
	# 1. re-take the relics on a clean slate so their looks come back (blue flame, moths, costumes) ...
	for m in w.moths:
		if is_instance_valid(m):
			m.queue_free()
	w.moths.clear()
	(p.relics as Array).clear()
	for id in pd.get("relics", []):
		Items.apply(str(id), p, w)
	# 2. ... then put back the exact numbers they (and tonics, boss growth, altars) left behind
	for k in pd:
		_set_prop(p, k, pd[k])
	var wd: Dictionary = s["world"]
	for k in wd:
		if k != "__extra":
			_set_prop(w, k, wd[k])
	if wd.has("__extra") and w.has_method("load_extra"):
		w.load_extra(wd["__extra"])
	if "moth" in p.rites:
		w.add_moth()
	p.set_blue(bool(p.blue))
	p.refresh_rite_look()
	w.recompute_discount()
	p.vel = Vector2.ZERO
	p.invuln = 1.0
	w.hud.show_hint("The house remembers you. Floor %d begins again." % int(w.floor_num), 4.0)


static func _set_prop(o: Object, k: String, v: Variant) -> void:
	if not (k in o):
		return
	var cur: Variant = o.get(k)
	if cur is Array and v is Array:
		(cur as Array).assign(v)
	elif cur is Dictionary and v is Dictionary:
		(cur as Dictionary).clear()
		(cur as Dictionary).merge(v)
	elif typeof(cur) == typeof(v) or (typeof(cur) in [TYPE_INT, TYPE_FLOAT] and typeof(v) in [TYPE_INT, TYPE_FLOAT]):
		o.set(k, float(v) if typeof(cur) == TYPE_FLOAT else (int(v) if typeof(cur) == TYPE_INT else v))


# ---------------------------------------------------------------- file

func _write(s: Dictionary) -> void:
	if s.is_empty():
		return
	var cf := ConfigFile.new()
	for sec in ["run", "player", "world"]:
		var d: Dictionary = s[sec]
		for k in d:
			cf.set_value(sec, k, d[k])
	var path := Game.run_path(Game.slot)
	var tmp := path + ".tmp"
	if cf.save(tmp) == OK:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


static func _read(path: String) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return {}
	var s := {"run": {}, "player": {}, "world": {}}
	for sec in s.keys():
		if cf.has_section(sec):
			for k in cf.get_section_keys(sec):
				s[sec][k] = cf.get_value(sec, k)
	var r: Dictionary = s["run"]
	if int(r.get("format", 0)) != FORMAT or not r.has("run_seed") or not r.has("floor") \
			or not Candles.LIST.has(str(r.get("candle", ""))):
		return {}
	return s


# ---------------------------------------------------------------- title screen

## Adds "Continue / Slot 1: Floor N - 12:41 AM" on top of the title menu (and moves the menu up to
## fit): the saved run of the slot played last.
func add_continue_button(menu: Container, main: Node) -> Button:
	if snap.is_empty():
		return null
	var b := UI.button("", func(): continue_run(main), 110)
	b.custom_minimum_size = Vector2(110, 30)
	var top := UI.label("Continue", 16, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 1
	top.offset_bottom = 17
	b.add_child(top)
	var sub := UI.label("Slot %d: %s" % [Game.slot, summary()], 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)   # the slot played last
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 17
	sub.offset_bottom = 27
	b.add_child(sub)
	var hl := func(on: bool): top.add_theme_color_override("font_color", UI.GOLD if on else UI.CREAM)
	b.focus_entered.connect(hl.bind(true))
	b.focus_exited.connect(hl.bind(false))
	b.mouse_entered.connect(hl.bind(true))
	b.mouse_exited.connect(func(): hl.call(b.has_focus()))
	b.set_meta("default_focus", true)
	menu.add_child(b)
	menu.move_child(b, 0)
	menu.position.y -= b.custom_minimum_size.y + float(menu.get_theme_constant("separation"))
	return b
