extends Node
## Achievements (autoload "Achievements"): the list, local unlocks in Game.records["achievements"]
## (id -> unix time; each save slot earns its own), a small pixel toast at the top of the screen, and a
## bridge to Steam when a GodotSteam singleton is present (Steam API names are the ids below, exactly;
## Steam gets every achievement earned in any slot).
##
## Most triggers are read from the running world each frame (_watch), so other scripts need no
## hooks. New mechanics can call Achievements.unlock("id") directly.

signal unlocked(id: String)

const LIST := [
	{"id": "first_snuff", "name": "First Snuff", "desc": "Snuff out your first creature."},
	{"id": "night_shift", "name": "Night Shift", "desc": "Snuff 100 creatures."},
	{"id": "chimney_sweep", "name": "Chimney Sweep", "desc": "Snuff 1,000 creatures."},
	{"id": "floor_crypt", "name": "Down the Stairs", "desc": "Burn your way down to the Crypt."},
	{"id": "floor_chapel", "name": "Holy Smoke", "desc": "Reach the Chapel."},
	{"id": "floor_belfry", "name": "Bell Climber", "desc": "Climb into the Belfry."},
	{"id": "boss_cellar", "name": "Cellar Cleared", "desc": "Snuff the guardian of the Cellar."},
	{"id": "boss_crypt", "name": "Crypt Sealed", "desc": "Snuff the guardian of the Crypt."},
	{"id": "boss_chapel", "name": "Last Rites", "desc": "Snuff the guardian of the Chapel."},
	{"id": "boss_untouched", "name": "Not a Scratch", "desc": "Snuff a guardian without a scratch."},
	{"id": "win", "name": "Before Two", "desc": "Win a night before two."},
	{"id": "win_early", "name": "Early to Bed", "desc": "Win before 1:00 AM."},
	{"id": "win_tea_light", "name": "Small Mercies", "desc": "Win as the Tea Light."},
	{"id": "win_party", "name": "Party's Over", "desc": "Win as the Party Candle."},
	{"id": "win_pillar", "name": "Pillar of Wax", "desc": "Win as the Altar Pillar."},
	{"id": "win_black_taper", "name": "Darkest Hour", "desc": "Win as the Black Taper."},
	{"id": "win_plain", "name": "Plain Wax", "desc": "Win with four relics or fewer.", "hidden": true},
	{"id": "tonight", "name": "Same Time Tomorrow", "desc": "Light Tonight's Candle."},
	{"id": "tonight_win", "name": "Tonight's the Night", "desc": "Win Tonight's Candle."},
	{"id": "kindling_8", "name": "Inferno", "desc": "Reach a x8 Kindling streak."},
	{"id": "kindling_12", "name": "Wildfire", "desc": "Reach a x12 Kindling streak.", "hidden": true},
	{"id": "mantel", "name": "Cluttered Mantel", "desc": "Carry 12 relics in one run."},
	{"id": "hollow", "name": "Someone Hid This", "desc": "Bomb your way into a Hollow."},
	{"id": "smoke_pact", "name": "Smoke Pact", "desc": "Pay minutes at the Smoke Altar."},
	{"id": "customer", "name": "Regular Customer", "desc": "Buy from the Tallow Merchant."},
	{"id": "ks_hand_bell", "name": "Hush", "desc": "Ring the Hand Bell."},
	{"id": "ks_flare_match", "name": "Strike a Light", "desc": "Light the Flare Match."},
	{"id": "ks_winding_key", "name": "Wind It Back", "desc": "Turn the Winding Key."},
	{"id": "ks_smoke_jar", "name": "Up in Smoke", "desc": "Open the Smoke Jar."},
	{"id": "rite", "name": "Candle Rite", "desc": "Complete a Candle Rite."},
	{"id": "rite_all", "name": "Keeper of Rites", "desc": "Complete all six Candle Rites."},
	{"id": "guttering", "name": "Clinging On", "desc": "Live through a Guttering."},
	{"id": "two_oclock", "name": "Two O'Clock", "desc": "Melt all the way down to 2:00 AM.", "hidden": true},
	{"id": "candle_box", "name": "Full Candle Box", "desc": "Unlock every candle."},
	# special moves (v2.3, scripts/game/moves.gd unlocks them): one feat per candle's move
	{"id": "move_skip", "name": "Close Shave", "desc": "Skip right through an enemy shot."},
	{"id": "move_sparkler", "name": "Party Popper", "desc": "Pop 3 enemy shots with one Sparkler."},
	{"id": "move_slam", "name": "Pillar Drop", "desc": "Stun 3 lodgers with one Slam."},
	{"id": "move_blink", "name": "Moon Hop", "desc": "Blink over 3 pits in one room."},
	{"id": "move_flare", "name": "Burning Bright", "desc": "Snuff 3 creatures during one Flare Up."},
	{"id": "move_snuff", "name": "Through and Through", "desc": "Run one black flame through 3 foes."},
	# special rooms and mini-bosses (specials stream)
	{"id": "seance", "name": "Spirits Answered", "desc": "Ring the Seance bell and see it through."},
	{"id": "mirror_deal", "name": "Looking Glass", "desc": "Strike a bargain with the Cracked Mirror."},
	{"id": "music_box", "name": "The Lucky Tune", "desc": "Wind a relic out of the Music Box."},
	{"id": "font_5", "name": "Generous Wick", "desc": "Feed the Wax Font five times in one run."},
	{"id": "mini_boss", "name": "Big Game", "desc": "Snuff a house champion."},
	{"id": "mini_all", "name": "Trophy Wall", "desc": "Snuff all six house champions.", "hidden": true},
	# the Journal (meta stream, scripts/game/records.gd)
	{"id": "census", "name": "House Census", "desc": "Meet every lodger in the house."},
	{"id": "curio", "name": "Curio Cabinet", "desc": "Find every relic in the house."},
	{"id": "guardians_all", "name": "Night Watch", "desc": "Snuff all twelve floor guardians."},
	# the Clock Tower and the true ending (endgame stream, scripts/game/tower.gd)
	{"id": "tower", "name": "Above the Bells", "desc": "Climb the ladder of light into the Clock Tower.", "hidden": true},
	{"id": "keeper", "name": "Time's Up", "desc": "Still the Keeper of Hours.", "hidden": true},
	{"id": "true_early", "name": "Home Before Half Past", "desc": "Reach the true ending before 1:30 AM.", "hidden": true},
	{"id": "keeper_tallow", "name": "The Last Candle", "desc": "Still the Keeper as Tallow.", "hidden": true},
	{"id": "keeper_tea_light", "name": "Small Hours", "desc": "Still the Keeper as the Tea Light.", "hidden": true},
	{"id": "keeper_party", "name": "Many Happy Returns", "desc": "Still the Keeper as the Party Candle.", "hidden": true},
	{"id": "keeper_pillar", "name": "Load-Bearing", "desc": "Still the Keeper as the Altar Pillar.", "hidden": true},
	{"id": "keeper_black_taper", "name": "Midnight Oil", "desc": "Still the Keeper as the Black Taper.", "hidden": true},
	{"id": "keeper_moonwick", "name": "Moon Over the Tower", "desc": "Still the Keeper as Moonwick.", "hidden": true},
	# difficulty levels (v2.1 save slots): a win on a higher level counts for the lower one too
	{"id": "win_level3", "name": "Spellbound", "desc": "Win a night on level 3 (Witching Hour) or higher."},
	{"id": "win_level4", "name": "Dead of Night", "desc": "Win a night on level 4 (Two O'Clock)."},
	# the Long Night (v2.2 night stream): a night of seven floors or more, won
	{"id": "small_hours", "name": "The Small Hours", "desc": "Win a night of seven floors or more."},
	# the diary and its endings (v2.5 story stream, scripts/game/diary.gd unlocks them)
	{"id": "diary_first", "name": "Dear Diary", "desc": "Find a page of the housekeeper's diary."},
	{"id": "diary_half", "name": "Half the Story", "desc": "Find 12 diary pages."},
	{"id": "diary_all", "name": "Every Last Page", "desc": "Find all 24 diary pages."},
	{"id": "end_housekeeper", "name": "The Housekeeper", "desc": "Win a night with 12 diary pages found."},
	{"id": "end_windows", "name": "A Candle in Every Window", "desc": "See the ending of a seven-floor night.", "hidden": true},
	{"id": "end_story", "name": "The Whole Story", "desc": "Still the Keeper of Hours with every diary page found.", "hidden": true},
]
## Guardians and floors by area (a longer night puts them on other floor numbers).
const BOSS_IDS := {"cellar": "boss_cellar", "crypt": "boss_crypt", "chapel": "boss_chapel"}
const FLOOR_IDS := {"crypt": "floor_crypt", "chapel": "floor_chapel", "belfry": "floor_belfry"}
const TOAST_TIME := 2.0
const TOAST_GAP := 0.4     # s between two toasts, and after whatever held them
const TOAST_TEXT_W := 180  # px: longer lines wrap, so a toast fits between the wax bar and the minimap

var _by_id := {}
var _layer: CanvasLayer
var _queue: Array[String] = []
var _toast: Control
var _toast_tw: Tween
var _last_screen := 0   # instance id of the screen seen last frame
var _gap := 0.0
var _toast_ids: Array[String] = []   # what the toast on screen shows (put back if it is pulled early)
var _toast_ms := 0                   # when it came up
var _steam: Object
# what the watcher saw last frame in the current run
var _w: Node
var _area_floor := {}   # tonight: area -> its floor number (FLOOR_IDS), worked out once per run
var _coins := 0
var _ks := ""
var _ks_full := false
var _ended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in LIST:
		_by_id[a["id"]] = a
	_layer = CanvasLayer.new()
	_layer.layer = 110
	add_child(_layer)
	Game.unlocked_now.connect(func(_k): _check_candles())
	_steam_init()


func _records() -> Dictionary:
	var d: Variant = Game.records.get("achievements", {})
	if not (d is Dictionary):
		d = {}
	Game.records["achievements"] = d
	return d


func is_unlocked(id: String) -> bool:
	return _records().has(id)


func count() -> int:
	var n := 0
	for a in LIST:
		if is_unlocked(a["id"]):
			n += 1
	return n


## Unlock an achievement (once). Shows the toast and tells Steam. Returns true the first time.
func unlock(id: String) -> bool:
	if not _by_id.has(id) or is_unlocked(id):
		return false
	_records()[id] = int(Time.get_unix_time_from_system())
	Game.save()
	_queue.append(id)
	_steam_set(id)
	unlocked.emit(id)
	return true


func name_of(id: String) -> String:
	return str(_by_id.get(id, {}).get("name", id))


## Shows an achievement's toast without unlocking it (screenshot tours, store trailers).
func show_toast(id: String) -> void:
	if _by_id.has(id):
		_queue.append(id)


# ---------------------------------------------------------------- the watcher

func _world() -> Node:
	var cur := _screen()
	if cur == null or cur.name != "Game" or cur.get("player") == null:
		return null
	return cur


func _process(dt: float) -> void:
	_steam_tick()
	_pump(dt)
	var w := _world()
	if w == null:
		_w = null
		return
	var p: Node = w.player
	if w != _w:
		_w = w
		_area_floor = {}
		_coins = int(p.coins)
		_ks = str(p.keepsake)
		_ks_full = bool(w.keepsake_full())
		_ended = false
	_watch(w, p)


func _watch(w: Node, p: Node) -> void:
	var kills := int(w.kills)
	if kills > 0:
		unlock("first_snuff")
	var total := int(Game.records.get("kills", 0)) + kills
	if total >= 100:
		unlock("night_shift")
	if total >= 1000:
		unlock("chimney_sweep")
	var f := int(w.floor_num)
	if _area_floor.is_empty():
		var nf := int(w.get("night_floors")) if w.get("night_floors") != null else 4
		for a in FLOOR_IDS:
			_area_floor[a] = Areas.depth_in(a, nf)
	for a in FLOOR_IDS:
		if f >= int(_area_floor[a]):   # reached that area (or past it) tonight
			unlock(FLOOR_IDS[a])
	if w.daily:
		unlock("tonight")
	var b: Variant = w.boss
	if b != null and is_instance_valid(b) and not b.alive:
		var area := str(w.fdef().get("area", "")) if w.has_method("fdef") else ""
		if BOSS_IDS.has(area):
			unlock(BOSS_IDS[area])
		if int(w.room_hits) == 0:
			unlock("boss_untouched")
	if int(w.best_streak) >= 8:
		unlock("kindling_8")
	if int(w.best_streak) >= 12:
		unlock("kindling_12")
	if (p.relics as Array).size() >= 12:
		unlock("mantel")
	if w.room and is_instance_valid(w.room) and w.room.data.get("type", "") == "secret":
		unlock("hollow")
	if str(w.pact) == "smoke":
		unlock("smoke_pact")
	var coins := int(p.coins)
	if coins < _coins and w.room and is_instance_valid(w.room) and w.room.data.get("type", "") == "shop":
		unlock("customer")
	_coins = coins
	# a keepsake was used: same keepsake, it was full, now it is empty
	var full := bool(w.keepsake_full())
	var ks := str(p.keepsake)
	if ks == _ks and ks != "" and _ks_full and int(p.charge) == 0:
		unlock("ks_" + ks)
	_ks = ks
	_ks_full = full
	if not (p.rites as Array).is_empty():
		unlock("rite")
		var done: Array = Game.records.get("rites_done", [])
		var grew := false
		for r in p.rites:
			if not r in done:
				done.append(r)
				grew = true
		if grew:
			Game.records["rites_done"] = done
			Game.save()
		if done.size() >= Items.RITES.size():
			unlock("rite_all")
	if bool(p.gutter_used):
		unlock("guttering")
	if bool(w.finished) and not _ended:
		_ended = true
		_run_over(w, p)


func _run_over(w: Node, p: Node) -> void:
	if bool(p.dead):
		# snuffed by the clock itself (not by a blow): no recent hit when the wax ran out
		if float(w.clock_minutes()) >= 119.5 and float(p.invuln) <= 0.0:
			unlock("two_oclock")
		return
	on_win(w, float(w.clock_minutes()))
	var cid := str(w.candle_id)
	if cid != "tallow":
		unlock("win_" + cid)
	if w.daily:
		unlock("tonight_win")
	if (p.relics as Array).size() <= 4:
		unlock("win_plain")
	var lv := int(w.get("level")) if w.get("level") != null else 2   # Tonight's Candle is always 2
	if lv >= 3:
		unlock("win_level3")
	if lv >= 4:
		unlock("win_level4")


## A night won at clock minute `t` (the Belfry's guardian fell): the time-based achievements say what they
## mean on any night length. Before Two: the clock still before 2:00 AM (every 4-floor win; a longer night only
## if it was that quick). Early to Bed: before 1:00 AM. The Long Night: a night of seven floors or more.
func on_win(w: Node, t: float) -> void:
	if Game.shown_minute(t) < int(Game.END_MINUTES):
		unlock("win")
	if Game.shown_minute(t) < 60:   # "Win before 1:00 AM": a clock showing 12:59 AM or earlier
		unlock("win_early")
	if w.get("night_floors") != null and int(w.night_floors) >= 7:
		unlock("small_hours")


func _check_candles() -> void:
	for k in Candles.ORDER:
		if not Candles.is_unlocked(k):
			return
	unlock("candle_box")


# ---------------------------------------------------------------- toast

func _pump(dt: float) -> void:
	# toasts belong to the run (and its results): arriving on the title drops what is left, so
	# nothing lands on the logo (they are all saved and listed under Achievements anyway)
	var scr := _screen()
	var sid := scr.get_instance_id() if scr else 0
	var arrived := sid != _last_screen
	_last_screen = sid
	if arrived and scr and scr.name == "Title":
		_queue.clear()
		_pull(false)
		return
	# hold the queue (and pull a toast that is up) while something else owns the screen: a floor or
	# relic banner, the boss card, the pause menu, the end of the run, the ending, a screen change,
	# the results (they list what is pending: take_pending())
	var hold := _hold_reason(scr)
	if hold != "":
		if _toast != null:
			_pull(hold != "results")
		_gap = TOAST_GAP * 0.5
		return
	if _toast != null or _queue.is_empty():
		return
	if _gap > 0.0:
		_gap -= dt
		return
	if _queue.size() >= 3:   # a burst (a boss falls, a floor starts): one toast names them all
		var ids: Array[String] = _queue.duplicate()
		_queue.clear()
		_show_many(ids)
	else:
		_show(_queue.pop_front())


## Why toasts must wait right now ("" = they may show).
func _hold_reason(scr: Node) -> String:
	if scr == null or scr.is_queued_for_deletion():
		return "switch"
	var main := get_tree().current_scene
	if main and bool(main.get("_busy")):
		return "switch"
	if scr.name == "Results":
		return "results"
	if scr.name == "Title":
		return "title"   # its bottom edge is the button row now: a rare unlock there waits for the next run
	var w := _world()
	if w == null:
		return ""
	if bool(w.get("finished")):
		return "end"
	if bool(w.get("paused")) or get_tree().paused:
		return "pause"
	if Juice.holding(w):
		return "card"
	for c in w.get_children():
		if c is Ending:
			return "ending"
	var hud: Variant = w.get("hud")
	if hud and is_instance_valid(hud):
		var bb: Variant = hud.get("boss_box")
		if bb and (bb as CanvasItem).visible:
			return "boss"   # a guardian fight: the medal can wait for the victory (and its banner)
		for l in [hud.get("banner"), hud.get("banner_sub")]:
			if l and is_instance_valid(l) and (l as CanvasItem).modulate.a > 0.05 and str(l.text) != "":
				return "banner"
	return ""


## Take the toast off the screen now; `requeue` puts what it showed back at the front of the queue.
func _pull(requeue: bool) -> void:
	if _toast_tw:
		_toast_tw.kill()
		_toast_tw = null
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	_toast = null
	if requeue and Time.get_ticks_msec() - _toast_ms < 1200:   # it was barely seen: show it again later
		for i in range(_toast_ids.size() - 1, -1, -1):
			_queue.push_front(_toast_ids[i])
	_toast_ids.clear()


## The results screen lists the achievements still waiting (instead of toasting over its panel).
func take_pending() -> Array[String]:
	var out: Array[String] = _toast_ids.duplicate()
	out.append_array(_queue)
	_queue.clear()
	_pull(false)
	return out


func _screen() -> Node:
	var main := get_tree().current_scene
	if main == null or not ("current" in main):
		return null
	var c: Variant = main.get("current")
	return c if c != null and is_instance_valid(c) else null


func _show(id: String) -> void:
	var a: Dictionary = _by_id[id]
	var reward := Items.display_name(Unlocks.reward_of(id)) if Unlocks.reward_of(id) != "" else ""
	_toast_ids = [id]
	_pop(a["name"].to_upper(), a["desc"], reward)


## Three or more at once: one toast that names them all.
func _show_many(ids: Array[String]) -> void:
	var names: Array = []
	var rewards: Array = []
	for id in ids:
		names.append(_by_id[id]["name"])
		if Unlocks.reward_of(id) != "":
			rewards.append(Items.display_name(Unlocks.reward_of(id)))
	_toast_ids = ids
	_pop("%d ACHIEVEMENTS" % ids.size(), ", ".join(names), ", ".join(rewards))


func _line(text: String, col: Color) -> Label:
	var l := UI.label(text, 8, col)
	if Art.font_small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > TOAST_TEXT_W:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = TOAST_TEXT_W
	return l


func _pop(title: String, desc: String, reward: String) -> void:
	var vs := get_viewport().get_visible_rect().size
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxTexture.new()
	if Art.has("ui/panel_9"):
		sb.texture = Art.tex("ui/panel_9")
		sb.texture_margin_left = 8
		sb.texture_margin_right = 8
		sb.texture_margin_top = 8
		sb.texture_margin_bottom = 8
	sb.content_margin_left = 7
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	box.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var ic := TextureRect.new()
	ic.texture = Art.tex("ui/icon_medal")
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(11, 18)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(_line(title, UI.GOLD))
	col.add_child(_line(desc, UI.CREAM))
	if reward != "":
		col.add_child(_line("NEW IN THE HOUSE: " + reward, UI.EMBER))
	box.set_meta("fit_group", "toast")
	_layer.add_child(box)
	_toast = box
	_toast_ms = Time.get_ticks_msec()
	box.reset_size()
	var sz := box.get_combined_minimum_size()
	box.size = sz
	var at := _lane(sz, vs)
	var y := at.y
	var hidden := -sz.y - 2.0
	var scr := _screen()
	if scr and scr.name == "Title":   # under the menu, never over the logo
		y = vs.y - sz.y - 4.0
		hidden = vs.y + 2.0
	box.position = Vector2(at.x, hidden)
	if ResourceLoader.exists("res://assets/audio/sfx/achievement.ogg") or ResourceLoader.exists("res://assets/audio/sfx/achievement.wav"):
		Audio.play("achievement")
	else:
		Audio.play("tick", -2.0, 0.0, 1.6)
	var tw := create_tween().set_ignore_time_scale(true)
	_toast_tw = tw
	box.set_meta("fit_skip", true)   # FitCheck: sliding in / out is off the screen on purpose
	tw.tween_property(box, "position:y", y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(box.set_meta.bind("fit_skip", false))
	tw.tween_interval(TOAST_TIME)
	tw.tween_callback(box.set_meta.bind("fit_skip", true))
	tw.tween_property(box, "position:y", hidden, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		box.queue_free()
		_toast = null
		_toast_tw = null
		_toast_ids.clear()
		_gap = TOAST_GAP)


## Where a toast of this size goes. In play: centred at the top when it fits between the wax bar
## (and its "+N min") and the minimap; on narrow screens (384 px wide) that gap is too small, so it
## drops into its own lane just under the HUD (below the minimap, clear of the bar, the counters and
## the floor name in the left gutter). Elsewhere: top centre.
func _lane(sz: Vector2, vs: Vector2) -> Vector2:
	var x := floorf((vs.x - sz.x) / 2.0)
	var w := _world()
	var hud: Variant = w.get("hud") if w else null
	if hud == null or not is_instance_valid(hud) or hud.get("bar") == null or hud.get("minimap") == null:
		return Vector2(x, 4.0)
	var bar: Control = hud.bar
	var mm: Control = hud.minimap
	var left := bar.position.x + bar.size.x
	var spare: Variant = hud.get("spare_label")
	if spare and str(spare.text) != "":
		left = maxf(left, (spare as Control).position.x + Art.font_small.get_string_size(str(spare.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	left += 4.0
	var right := mm.position.x - 4.0
	if sz.x <= right - left:
		return Vector2(clampf(x, left, right - sz.x), 3.0)
	return Vector2(x, mm.position.y + mm.size.y + 2.0)


# ---------------------------------------------------------------- list screen

## A paged list of every achievement (locked secrets stay "? ? ?"). Opened from Settings.
func open_list(parent: Control) -> void:
	var m := UI.modal(parent, "")
	var root: Control = m[0]
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	var head := UI.label("", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(head)
	var gridc := GridContainer.new()
	gridc.columns = 2
	gridc.add_theme_constant_override("h_separation", 10)
	gridc.add_theme_constant_override("v_separation", 3)
	v.add_child(gridc)
	var per := 10
	var pages := ceili(LIST.size() / float(per))
	var st := {"page": 0}
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 6)
	var page_lbl := UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	page_lbl.custom_minimum_size = Vector2(40, 0)
	page_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var fill := func():
		for c in gridc.get_children():
			c.queue_free()
		head.text = "ACHIEVEMENTS  %d/%d" % [count(), LIST.size()]
		page_lbl.text = "%d / %d" % [st["page"] + 1, pages]
		for i in range(st["page"] * per, mini(LIST.size(), (st["page"] + 1) * per)):
			gridc.add_child(_entry(LIST[i]))
	var turn := func(d: int):
		st["page"] = (st["page"] + d + pages) % pages
		fill.call()
	nav.add_child(UI.button("<", func(): turn.call(-1), 22))
	nav.add_child(page_lbl)
	nav.add_child(UI.button(">", func(): turn.call(1), 22))
	var back := UI.button("Back", func():
		Audio.play("ui_back")
		root.queue_free(), 70)
	back.set_meta("default_focus", true)
	nav.add_child(back)
	v.add_child(nav)
	fill.call()
	Controls.set_page_handler(root, func(d): turn.call(d))


func _entry(a: Dictionary) -> Control:
	var got := is_unlocked(a["id"])
	var secret: bool = a.get("hidden", false) and not got
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(162, 18)
	var ic := TextureRect.new()
	ic.texture = Art.tex("ui/icon_medal" if got else "ui/icon_medal_off")
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(10, 18)
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -1)
	row.add_child(col)
	col.add_child(UI.label("? ? ?" if secret else a["name"], 8, UI.GOLD if got else UI.CREAM))
	col.add_child(UI.label("A secret of the house." if secret else a["desc"], 8, UI.CREAM if got else UI.DIM))
	if Unlocks.reward_of(a["id"]) != "" and not secret: col.add_child(UI.label("Brings: " + Items.display_name(Unlocks.reward_of(a["id"])), 8, UI.EMBER if got else Color("#775c55")))
	return row


# ---------------------------------------------------------------- Steam (GodotSteam, optional)

func _steam_init() -> void:
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	if _steam.has_method("isSteamRunning") and not _steam.call("isSteamRunning"):
		_steam = null
		return
	if _steam.has_method("steamInitEx"):
		var res: Variant = _steam.call("steamInitEx")
		if res is Dictionary and int(res.get("status", 0)) != 0:
			push_warning("Steam init failed: %s" % res.get("verbal", ""))
			_steam = null
			return
	# achievements earned before Steam was there light up now, from every save slot (Steam has one
	# list per account: an achievement earned in any slot counts)
	for id in Game.all_achievements():
		_steam_set(id, false)
	_steam_store()


func _steam_set(id: String, store := true) -> void:
	if _steam == null or not _steam.has_method("setAchievement"):
		return
	_steam.call("setAchievement", id)
	if store:
		_steam_store()


func _steam_store() -> void:
	if _steam and _steam.has_method("storeStats"):
		_steam.call("storeStats")


func _steam_tick() -> void:
	if _steam and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")
