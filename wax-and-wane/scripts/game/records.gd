class_name Records
extends RefCounted
## What the Journal remembers (stored in Game.records): relics seen and taken, lodgers met and
## snuffed, guardians beaten (and how fast), special rooms found, the last 20 runs, and what snuffed
## Tallow. Every hook is a one-line call from the world, the room, a pickup or a shot.
##
##   world.collect_item / on_keepsake_taken   Records.take(w, id)
##   world.on_enemy_killed                    Records.on_kill(w, e)
##   world.on_player_hurt                     Records.on_hurt(w)       (who landed the blow)
##   world.on_player_died                     Records.on_died(w)       (the death note)
##   world._end_run                           Records.end_run(w, won, params) -> params for results
##   pickup preview                           Records.see(id)
##   Room.build                               Records.on_room(r)       (special rooms, the chalk)
##   Shot.setup (enemy shots)                 Records.tag_shot(w, s)   (who fired it)
##   room oil jar / hearth, world bomb        Records.blame("oil" / "hearth" / "bomb")

const HISTORY := 20
const NIGHTS := 14

## A blame set by a hazard just before it calls Player.hurt (same physics frame).
static var _blame := ""
static var _blame_frame := -1


# ---------------------------------------------------------------- small helpers

static func _dict(key: String) -> Dictionary:
	var d: Variant = Game.records.get(key, {})
	if not (d is Dictionary):
		d = {}
	Game.records[key] = d
	return d


static func _arr(key: String) -> Array:
	var a: Variant = Game.records.get(key, [])
	if not (a is Array):
		a = []
	Game.records[key] = a
	return a


static func mark_new(key: String) -> void:
	_dict("journal_new")[key] = 1


static func is_new(key: String) -> bool:
	return _dict("journal_new").has(key)


static func clear_new(key: String) -> void:
	_dict("journal_new").erase(key)


static func any_new(prefix := "") -> bool:
	for k in _dict("journal_new"):
		if prefix == "" or str(k).begins_with(prefix):
			return true
	return false


static func seen(id: String) -> bool:
	return _dict("seen_relics").has(id)


static func taken(id: String) -> int:
	return int(_dict("taken_relics").get(id, 0))


static func met(kind: String) -> bool:
	return _dict("met").has(kind) or int(_dict("kills_by_kind").get(kind, 0)) > 0


static func kills_of(kind: String) -> int:
	return int(_dict("kills_by_kind").get(kind, 0))


static func boss_record(kind: String) -> Dictionary:
	return _dict("bosses_beaten").get(kind, {})


static func room_found(t: String) -> bool:
	return _dict("rooms_found").has(t)


static func mini_beaten(kind: String) -> bool:
	return kind in Game.records.get("minis_beaten", [])


# ---------------------------------------------------------------- relics

## Looked at on a pedestal or a shop shelf (called every frame while near: cheap when known).
static func see(id: String) -> void:
	if id == "" or Items.TONICS.has(id):
		return
	var s := _dict("seen_relics")
	if s.has(id):
		return
	s[id] = 1
	mark_new("r:" + id)
	if s.size() >= Items.RELICS.size():
		var all := true
		for r in Items.RELICS:
			if not s.has(r):
				all = false
				break
		if all:
			Achievements.unlock("curio")


static func take(_w: Node, id: String) -> void:
	if id == "" or Items.TONICS.has(id):
		return
	see(id)
	var t := _dict("taken_relics")
	t[id] = int(t.get(id, 0)) + 1


# ---------------------------------------------------------------- creatures

static func key_of(e: Node) -> String:
	if e == null or not is_instance_valid(e):
		return ""
	return ("m:" if e.has_meta("mini") else "e:") + str(e.get("kind"))


static func _meet(e_key: String) -> void:
	if e_key.length() < 3:
		return
	var kind := e_key.substr(2)
	var m := _dict("met")
	var k := ("mini:" + kind) if e_key.begins_with("m:") else kind
	if m.has(k):
		return
	m[k] = 1
	if e_key.begins_with("m:"):
		mark_new("m:" + kind)
	elif Enemy.DEFS.has(kind) and Enemy.DEFS[kind].get("boss", false):
		mark_new("g:" + kind)
	else:
		mark_new("l:" + kind)
		_check_census()


static func _check_census() -> void:
	for k in BestiaryGallery.regulars():
		if not met(k):
			return
	Achievements.unlock("census")


static func on_kill(w: Node, e: Node) -> void:
	var kind := str(e.get("kind"))
	var kb := _dict("kills_by_kind")
	kb[kind] = int(kb.get(kind, 0)) + 1
	_meet(key_of(e))
	if not e.has_meta("mini"):
		_meet("e:" + kind)
	if bool(e.get("boss")):
		var bb := _dict("bosses_beaten")
		var rec: Dictionary = bb.get(kind, {"n": 0, "best": 0.0})
		var secs := maxf(1.0, float(w.run_time) - float(w.get_meta("room_t", w.run_time)))
		rec["n"] = int(rec.get("n", 0)) + 1
		if float(rec.get("best", 0.0)) <= 0.0 or secs < float(rec["best"]):
			rec["best"] = secs
		bb[kind] = rec
		var all := true
		for b in BestiaryGallery.boss_kinds():
			if Enemy.DEFS.get(b, {}).get("secret", false):
				continue   # the Keeper is not one of the eight
			if not bb.has(b):
				all = false
		if all:
			Achievements.unlock("guardians_all")


# ---------------------------------------------------------------- the death note

## A hazard is about to hurt Tallow ("spikes", "hearth", "oil", "bomb" or an Enemy).
static func blame(what: Variant) -> void:
	_blame = key_of(what) if what is Node else str(what)
	_blame_frame = Engine.get_physics_frames()


## Enemy shots remember who fired them (the nearest creature when they were made; the burst of
## a landing flask inherits the thrower).
static func tag_shot(w: Node, s: Node2D) -> void:
	if w == null or not ("enemies" in w):
		return
	var best: Node = null
	var bd := 1e9
	for e in w.enemies:
		if is_instance_valid(e) and (e.alive or e.boss):
			var d: float = e.global_position.distance_squared_to(s.position)
			if d < bd:
				bd = d
				best = e
	if bd > 400.0 and "fx_layer" in w:
		for o in w.fx_layer.get_children():
			if o is Shot and o != s and o.lob and o._dead and o.lob_to.distance_squared_to(s.position) < 4.0:
				s.set_meta("by", o.get_meta("by", ""))
				return
	if best:
		s.set_meta("by", key_of(best))


static func _infer(w: Node) -> String:
	var p: Node2D = w.player
	var at := p.global_position + Vector2(0, -8)
	for s in w.enemy_shots:
		if is_instance_valid(s) and not s._dead and at.distance_squared_to(s.global_position) < pow(s.radius + 6.0, 2):
			return str(s.get_meta("by", ""))
	var best: Node = null
	var bd := 1e9
	for e in w.enemies:
		if is_instance_valid(e) and (e.alive or e.boss):
			var d: float = e.global_position.distance_to(p.global_position) - float(e.radius)
			if d < bd:
				bd = d
				best = e
	if best and bd < 8.0:
		return key_of(best)
	if w.room and w.room.has_method("spike_hurts") and w.room.spike_hurts(p.global_position):
		return "spikes"
	if best and bd < 34.0:
		return key_of(best)
	return ""


## Called by world.on_player_hurt for every blow that lands (Guttering included).
static func on_hurt(w: Node) -> void:
	var f := Engine.get_physics_frames()
	var k := _blame if _blame_frame == f and _blame != "" else _infer(w)
	_blame = ""
	if k == "":
		return
	w.set_meta("last_hit", k)
	w.set_meta("last_hit_frame", f)
	if k.begins_with("e:") or k.begins_with("m:"):
		_meet(k)


## world.on_player_died: what put the flame out.
static func on_died(w: Node) -> void:
	var k := "clock"
	if float(w.player.wax) > 0.01:
		k = "gave_up"   # Give up: the flame was blown out with wax to spare
	elif w.has_meta("last_hit") and Engine.get_physics_frames() - int(w.get_meta("last_hit_frame", -99)) <= 2:
		k = str(w.get_meta("last_hit"))
	w.set_meta("killer", k)


static func killer_name(k: String) -> String:
	if k.begins_with("m:"):
		return title_case(str(Specials.MINIS.get(k.substr(2), {}).get("name", "a house champion")))
	if k.begins_with("e:"):
		var d: Dictionary = Enemy.DEFS.get(k.substr(2), {})
		return title_case(str(d.get("name", "something in the dark")))
	match k:
		"spikes": return "Floor Spikes"
		"hearth": return "a Lit Hearth"
		"oil": return "an Oil Jar"
		"stove": return "a Hot Stove"
		"scald": return "Scalding Broth"
		"bomb": return "Your Own Bomb"
		"clock": return "the Clock"
		"gave_up": return "Your Own Breath"
	return "Something in the Dark"


## A few words for a row in the Journal's run list.
static func short_killer(k: String) -> String:
	match k:
		"clock": return "Melted down to two"
		"gave_up": return "Gave up"
		"bomb": return "Own bomb"
		"spikes": return "Floor spikes"
		"hearth": return "A lit hearth"
		"oil": return "An oil jar"
		"stove": return "A hot stove"
		"scald": return "Scalding broth"
	return killer_name(k)


## One line for the results screen and the Journal.
static func death_line(k: String) -> String:
	match k:
		"clock": return "The clock struck two."
		"gave_up": return "You blew out your own flame."
		"": return "Your flame went out."
	return "Snuffed by %s" % killer_name(k)


## A small picture of the killer: the creature's first idle frame, or a prop.
static func killer_icon(k: String, big := true) -> Texture2D:
	if k.begins_with("m:"):
		var kind := k.substr(2)
		if big and Art.has("specials/mini_%s_idle_f0" % kind):
			return Art.tex("specials/mini_%s_idle_f0" % kind)
		k = "e:" + kind
	if k.begins_with("e:"):
		return portrait(k.substr(2))
	var path: String = {"spikes": "0x72/floor_spikes_anim_f3", "hearth": "decor/prop_hearth", "oil": "decor/prop_oil_jar",
		"stove": "areas/kitchen/stove", "scald": "areas/kitchen/pot",
		"bomb": "0x72/bomb_f0", "clock": "items/pocket_watch", "gave_up": "items/snuffer_cap"}.get(k, "items/snuffer_cap")
	for p in [path, "items/snuffer_cap"]:
		if Art.has(p):
			return Art.tex(p)
	return null


## The first idle frame of a creature (for portraits).
static func portrait(kind: String) -> Texture2D:
	var d: Dictionary = Enemy.DEFS.get(kind, {})
	var sf := Enemy.frames_for(str(d.get("sprite", kind)))
	if sf == null:
		return null
	var anim := "idle" if sf.has_animation("idle") else "default"
	if not sf.has_animation(anim) or sf.get_frame_count(anim) == 0:
		return null
	return sf.get_frame_texture(anim, 0)


static func title_case(s: String) -> String:
	if s != s.to_upper():
		return s   # creature names are already in Title Case; guardians shout
	var words := s.to_lower().split(" ")
	for i in words.size():
		var wd: String = words[i]
		if wd == "" or (i > 0 and wd in ["of", "the", "a", "an"]):
			continue
		words[i] = wd.substr(0, 1).to_upper() + wd.substr(1)
	return " ".join(words)


# ---------------------------------------------------------------- rooms

## Room.build: special rooms found, the moment a room was entered (guardian fight times),
## and the chalk drawings on the floor of the very first room.
static func on_room(r: Node2D) -> void:
	var w: Node = r.get("world")
	if w and "run_time" in w:
		w.set_meta("room_t", w.run_time)
	var t := str(r.data.get("type", ""))
	if Specials.is_special(t):
		var rf := _dict("rooms_found")
		if not rf.has(t):
			rf[t] = 1
			mark_new("s:" + t)
	Chalk.attach(r)


# ---------------------------------------------------------------- end of a run

## world._end_run: writes the run into the history and returns the results screen's params with
## the death note, the seed and anything that just moved into the house.
static func end_run(w: Node, won: bool, params: Dictionary) -> Dictionary:
	var killer := "" if won else str(w.get_meta("killer", "clock"))
	params["killer"] = killer
	params["seed"] = int(w.run_seed)
	params["seeded"] = bool(w.get_meta("seeded", false))
	params["candle"] = str(w.candle_id)
	params["area"] = str(w.fdef().get("area", "")) if w.has_method("fdef") else ""   # the area the run ended in
	if int(w.best_streak) > int(Game.records.get("best_streak", 0)):
		Game.records["best_streak"] = int(w.best_streak)
	if won:
		var wc := _dict("wins_by_candle")
		wc[w.candle_id] = int(wc.get(w.candle_id, 0)) + 1
	for c in w.unlocked_this_run:
		mark_new("c:" + str(c))
	# Tonight's Candle belongs to the night it was lit, even when it ends after midnight (QA-15)
	var lit := str(w.get("daily_date")) if bool(w.daily) and str(w.get("daily_date")) != "" else Time.get_date_string_from_system()
	var hist := _arr("run_history")
	hist.push_front({"won": won, "candle": str(w.candle_id), "floor": int(w.floor_num), "clock": float(w.clock_minutes()),
		"killer": killer, "relics": (w.player.relics as Array).duplicate(), "time": float(w.run_time), "kills": int(w.kills),
		"streak": int(w.best_streak), "seed": int(w.run_seed), "daily": bool(w.daily), "date": lit,
		"n": int(Game.records.get("runs", 0)), "level": int(w.level), "area": params["area"]})
	while hist.size() > HISTORY:
		hist.pop_back()
	if bool(w.daily):
		params["date"] = lit   # the Share text (results.gd) uses it
		score_night(params, lit)
	params["new_unlocks"] = Unlocks.take_new()
	Game.save()
	return params


## Tonight's Candle score. results.gd _daily_score shows the same number (same formula).
static func daily_score(params: Dictionary) -> int:
	var s := 1000 * int(params.get("floor", 1)) + 60 * int(params.get("rooms", 0)) + 5 * int(params.get("kills", 0)) - 40 * int(params.get("hits", 0))
	if params.get("won", false):
		s += 2000 + int(25.0 * (120.0 - float(params.get("clock", 120.0))))
	return maxi(s, 0)


## Tonight's Candle bookkeeping (first try / best of the night, the nights list) under the night the
## candle was lit. Sets params["scored"], so results.gd only shows the numbers.
static func score_night(params: Dictionary, date: String) -> void:
	if params.get("scored", false):
		return
	params["scored"] = true
	var s := daily_score(params)
	var last := str(Game.records.get("daily_date", ""))
	if last != "" and date < last:
		return   # an older night finished late (Save & Continue): tonight's record stays as it is
	if last != date:
		Game.records["daily_date"] = date
		Game.records["daily_first"] = s
		Game.records["daily_best"] = s
	else:
		Game.records["daily_best"] = maxi(int(Game.records["daily_best"]), s)
	log_night(date, int(Game.records["daily_first"]), int(Game.records["daily_best"]), bool(params.get("won", false)))


## Tonight's Candle: one line per night (score_night; results.gd for runs that skip end_run).
static func log_night(date: String, first: int, best: int, won: bool) -> void:
	var nights := _arr("daily_history")
	if not nights.is_empty() and nights[0].get("date", "") == date:
		nights[0]["best"] = best
		nights[0]["won"] = bool(nights[0].get("won", false)) or won
	else:
		nights.push_front({"date": date, "first": first, "best": best, "won": won})
	while nights.size() > NIGHTS:
		nights.pop_back()


## A difficulty level's entry in world.LEVELS (name, line and the multipliers world.difficulty() uses).
static func level_def(n: int) -> Dictionary:
	var lv: Dictionary = preload("res://scripts/game/world.gd").LEVELS
	return lv.get(n, lv[preload("res://scripts/game/world.gd").DEFAULT_LEVEL])


## "Level 3 - Witching Hour": the number is always shown with the name.
static func level_text(n: int) -> String:
	return "Level %d - %s" % [n, str(level_def(n)["name"])]


## "The Cellar" for floor 1 (any floor the world defines; "the House" past them). `area`: the area of the house the
## floor was built from (world.fdef()["area"], kept with each run), which names it on longer nights.
static func floor_name(n: int, lower_the := false, area := "") -> String:
	var floors: Dictionary = preload("res://scripts/game/world.gd").FLOORS
	var nm: String = str(floors[n]["name"]) if floors.has(n) else "The House"
	if area != "" and Areas.LIST.has(area):
		nm = str(Areas.def(area)["name"])
	return ("the " + nm.substr(4)) if lower_the and nm.begins_with("The ") else nm


static func floor_count() -> int:
	return int(preload("res://scripts/game/world.gd").LAST_FLOOR)


## The save slot's night length (the Night length picker on the Slots screen): 4 .. Areas.max_floors(), 4 until
## the slot picks another. world.setup reads it for every run but Tonight's Candle (always 4).
static func night_floors() -> int:
	return clampi(int(Game.records.get("night_floors", Areas.MIN_FLOORS)), Areas.MIN_FLOORS, Areas.max_floors())


static func set_night_floors(n: int) -> void:
	Game.records["night_floors"] = clampi(n, Areas.MIN_FLOORS, Areas.max_floors())
	Game.save()


## Save & Continue (world.save_extra / load_extra): the run-long bits the Journal needs.
static func to_dict(w: Node) -> Dictionary:
	return {"seeded": bool(w.get_meta("seeded", false))}


static func from_dict(w: Node, d: Dictionary) -> void:
	w.set_meta("seeded", bool(d.get("seeded", w.get_meta("seeded", false))))   # the saved value, true or false


## "4821 7730" style grouping so a seed is easy to read out to a friend.
static func seed_text(s: int) -> String:
	var t := str(absi(s))
	var out := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 4 == 0:
			out += " "
		out += t[i]
	return out
