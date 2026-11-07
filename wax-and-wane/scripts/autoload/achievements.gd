extends Node
## Achievements (autoload "Achievements"): the list, local unlocks in Game.records["achievements"]
## (id -> unix time), a small pixel toast at the top of the screen, and a bridge to Steam when a
## GodotSteam singleton is present (Steam API names are the ids below, exactly).
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
	{"id": "win", "name": "Before Two", "desc": "Snuff the Hour Fiend before two."},
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
	{"id": "rite_all", "name": "Keeper of Rites", "desc": "Complete all four Candle Rites."},
	{"id": "guttering", "name": "Clinging On", "desc": "Live through a Guttering."},
	{"id": "two_oclock", "name": "Two O'Clock", "desc": "Melt all the way down to 2:00 AM.", "hidden": true},
	{"id": "candle_box", "name": "Full Candle Box", "desc": "Unlock every candle."},
	# special rooms and mini-bosses (specials stream)
	{"id": "seance", "name": "Spirits Answered", "desc": "Ring the Seance bell and see it through."},
	{"id": "mirror_deal", "name": "Looking Glass", "desc": "Strike a bargain with the Cracked Mirror."},
	{"id": "music_box", "name": "The Lucky Tune", "desc": "Wind a relic out of the Music Box."},
	{"id": "font_5", "name": "Generous Wick", "desc": "Feed the Wax Font five times in one run."},
	{"id": "mini_boss", "name": "Big Game", "desc": "Snuff a house champion."},
	{"id": "mini_all", "name": "Trophy Wall", "desc": "Snuff all six house champions.", "hidden": true},
]
const BOSS_IDS := {1: "boss_cellar", 2: "boss_crypt", 3: "boss_chapel"}
const FLOOR_IDS := {2: "floor_crypt", 3: "floor_chapel", 4: "floor_belfry"}
const TOAST_TIME := 2.0

var _by_id := {}
var _layer: CanvasLayer
var _queue: Array[String] = []
var _toast: Control
var _toast_tw: Tween
var _last_screen := 0   # instance id of the screen seen last frame
var _wait := 0.0
var _steam: Object
# what the watcher saw last frame in the current run
var _w: Node
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


## Shows an achievement's toast without unlocking it (screenshot tours, store trailers).
func show_toast(id: String) -> void:
	if _by_id.has(id):
		_queue.append(id)


# ---------------------------------------------------------------- the watcher

func _world() -> Node:
	var main := get_tree().current_scene
	if main == null or not ("current" in main):
		return null
	var cur: Node = main.current
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
	for k in FLOOR_IDS:
		if f >= k:
			unlock(FLOOR_IDS[k])
	if w.daily:
		unlock("tonight")
	var b: Variant = w.boss
	if b != null and is_instance_valid(b) and not b.alive:
		if BOSS_IDS.has(f):
			unlock(BOSS_IDS[f])
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
	unlock("win")
	var cid := str(w.candle_id)
	if cid != "tallow":
		unlock("win_" + cid)
	if float(w.clock_minutes()) < 60.0:
		unlock("win_early")
	if w.daily:
		unlock("tonight_win")
	if (p.relics as Array).size() <= 4:
		unlock("win_plain")


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
		_wait = 0.0
		if _toast_tw:
			_toast_tw.kill()
			_toast_tw = null
		if _toast and is_instance_valid(_toast):
			_toast.queue_free()
		_toast = null
		return
	if _toast != null or _queue.is_empty():
		return
	# wait for a floor / relic banner to clear first (they share the top of the screen)
	var w := _world()
	var hud: Variant = w.get("hud") if w else null
	if hud and is_instance_valid(hud) and hud.banner and hud.banner.modulate.a > 0.05 and _wait < 3.0:
		_wait += dt
		return
	_wait = 0.0
	_show(_queue.pop_front())


func _screen() -> Node:
	var main := get_tree().current_scene
	if main == null or not ("current" in main):
		return null
	var c: Variant = main.get("current")
	return c if c != null and is_instance_valid(c) else null


func _show(id: String) -> void:
	var a: Dictionary = _by_id[id]
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
	col.add_child(UI.label(a["name"].to_upper(), 8, UI.GOLD))
	col.add_child(UI.label(a["desc"], 8, UI.CREAM))
	_layer.add_child(box)
	_toast = box
	box.reset_size()
	var sz := box.get_combined_minimum_size()
	var in_game := _world() != null
	var y := 14.0 if in_game else 4.0
	var scr := _screen()
	var hidden := -sz.y - 2.0
	if scr and scr.name == "Title":   # under the menu, never over the logo
		y = vs.y - sz.y - 4.0
		hidden = vs.y + 2.0
	box.position = Vector2(floorf((vs.x - sz.x) / 2.0), hidden)
	if ResourceLoader.exists("res://assets/audio/sfx/achievement.ogg") or ResourceLoader.exists("res://assets/audio/sfx/achievement.wav"):
		Audio.play("achievement")
	else:
		Audio.play("tick", -2.0, 0.0, 1.6)
	var tw := create_tween().set_ignore_time_scale(true)
	_toast_tw = tw
	tw.tween_property(box, "position:y", y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(TOAST_TIME)
	tw.tween_property(box, "position:y", hidden, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		box.queue_free()
		_toast = null
		_toast_tw = null)


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
	# achievements earned before Steam was there light up now
	for id in _records():
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
