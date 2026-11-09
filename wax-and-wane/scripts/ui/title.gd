extends Node2D
## Title screen: the little candle alone in a dark cellar, the logo, Play / Settings / Credits.
## Opening (about 2.2 s, any tap skips): darkness, a match strikes and lights Tallow's wick, the room
## light blooms, the logo flickers on, embers drift up and the menu slides in.

const INTRO_END := 2.2

var main: Node
var ui: CanvasLayer
var root: Control
var hero: Player
var dark: CanvasModulate
var _t := 0.0
var sel := "tallow"
var sub: Label
var sel_name: Label
var play_btn: Button
var journal_btn: Button
## UX-05: menu buttons are 24 px tall with 4 px gaps (thumb-sized on a phone). The two big actions
## (and Continue) stand in the column on the right; Journal / Seed / Settings / Credits (and Quit on
## desktop) are a row along the bottom edge.
const MENU_W := 120
const MENU_H := 24
const GAP := 4
var bar: HBoxContainer
# ---- opening
var logo: TextureRect
var menu: VBoxContainer
var box: HBoxContainer
var stats: Label
var ver: Label
var embers: FxParts
var match_spr: Sprite2D
var match_flame: AnimatedSprite2D
var match_light: PointLight2D
var _intro := true
var _it := 0.0
var _struck := false
var _lit := false
var _home := {}
const DARK_LIT := Color(0.12, 0.09, 0.1)
const DARK_OFF := Color(0.012, 0.01, 0.012)


class FakeWorld extends Node:
	var room = null
	var paused := false
	func spawn_hot_drip(_p): pass
	func on_player_hurt(_a): pass
	func on_player_died(): pass
	func fx_text(_a, _b, _c): pass
	func fx_ring(_a, _b): pass
	func assist_aim(_p, d): return d
	func shoot_player(_a, _b, _c, _d): pass


func _ready() -> void:
	main = get_parent()
	Audio.music("title")
	var bg := Sprite2D.new()
	bg.texture = Art.tex("rooms/room_cellar")
	bg.centered = true
	add_child(bg)
	dark = CanvasModulate.new()
	dark.color = DARK_LIT
	add_child(dark)
	Lighting.attach(self)   # banded pixel light (lighting.gd)
	var fw := FakeWorld.new()
	add_child(fw)
	hero = Player.new()
	hero.world = fw
	hero.position = Vector2(-78, 44)
	hero.wax = 105.0
	add_child(hero)
	hero.set_physics_process(false)
	embers = FxParts.new()
	embers.cap = 60
	embers.z_index = 10
	embers.material = Art.unshaded
	add_child(embers)
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	logo = TextureRect.new()
	logo.texture = Art.tex("ui/title_logo") if Art.has("ui/title_logo") else null
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	logo.position = Vector2(-110, 10)
	logo.size = Vector2(220, 60)
	root.add_child(logo)
	if logo.texture == null:
		var t := UI.label("WAX & WANE", 16, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		t.size = Vector2(220, 20)
		t.position = Vector2(-110, 30)
		logo.add_child(t)
	sub = UI.label("Burn through the house before the clock strikes two.", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.size = Vector2(300, 10)
	sub.position = Vector2(-150, 70)
	root.add_child(sub)
	# ---- the menu: [Continue] / Light the wick / Tonight's Candle, and along the bottom edge
	# Journal | Seed | Settings | Credits [| Quit on desktop]
	Unlocks.take_new()   # anything unlocked since the last visit gets its Journal dot
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", GAP)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	menu.position = Vector2(-6, -(4 + MENU_H + 8) - (MENU_H * 2 + GAP))
	root.add_child(menu)
	play_btn = _menu_btn("Light the wick", _play, MENU_W)
	menu.add_child(play_btn)
	menu.add_child(_menu_btn("Tonight's Candle", _daily, MENU_W))
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", GAP)
	journal_btn = _menu_btn("Journal", func(): Journal.open(root).tree_exited.connect(journal_btn.queue_redraw), 56)
	journal_btn.draw.connect(func():
		if Records.any_new():
			Journal._dot(journal_btn, Vector2(journal_btn.size.x - 7, 5)))
	bar.add_child(journal_btn)
	bar.add_child(_menu_btn("Seed", open_seed_pad, 44))
	bar.add_child(_menu_btn("Settings", func(): SettingsPanel.open(root), 60))
	bar.add_child(_menu_btn("Credits", _credits, 56))
	if OS.has_feature("pc"):   # QA-22: desktops get a Quit button (it asks first)
		bar.add_child(_menu_btn("Quit", func(): Controls.quit_prompt(root), 44))
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)   # centred, 4 px above the bottom edge
	var bw := bar.get_combined_minimum_size().x
	bar.offset_left = -floorf(bw / 2.0)
	bar.offset_right = bar.offset_left + bw
	bar.offset_top = -4 - MENU_H
	bar.offset_bottom = -4
	root.add_child(bar)
	var cont := RunSave.add_continue_button(menu, main)   # "Continue / Floor N - 12:41 AM" when a run is saved
	if cont:
		cont.custom_minimum_size.x = MENU_W
	# --- the Candle Box: pick which candle to light
	box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.position = Vector2(-140, -(4 + MENU_H + 8) - 24)
	root.add_child(box)
	box.add_child(UI.button("<", func(): _cycle(-1), 24))
	sel_name = UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	sel_name.custom_minimum_size = Vector2(62, 24)
	sel_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(sel_name)
	box.add_child(UI.button(">", func(): _cycle(1), 24))
	sel = str(Game.records.get("candle", "tallow"))   # each save slot remembers its own candle
	if not Candles.is_unlocked(sel):
		sel = "tallow"
	_show_candle()
	Controls.set_page_handler(root, _cycle)   # LB / RB (Q / E) pick a candle
	var rec := Game.records
	var line := "Runs %d   Wins %d" % [rec["runs"], rec["wins"]]
	if Game.slot_live:   # the slot played last (the Slots screen switches slots)
		line = "Slot %d, level %d   %s" % [Game.slot, Game.level, line]
	if rec.get("daily_date", "") == Time.get_date_string_from_system():
		line += "   Tonight: %d" % int(rec.get("daily_first", 0))
	if float(rec["best_finish"]) != 0.0:
		line += "   Best: done by %s" % Game.clock_text(float(rec["best_finish"]))
	stats = UI.label(line, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	stats.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stats.size = Vector2(300, 10)
	stats.position = Vector2(-150, 81)   # under the candle's line (the bottom edge holds the button row)
	root.add_child(stats)
	ver = UI.label("v" + Game.VERSION, 8, Color(0.4, 0.33, 0.33))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-28, -12)
	root.add_child(ver)
	_intro_begin()


# ---------------------------------------------------------------- opening

func _intro_begin() -> void:
	for c in [logo, sub, menu, box, bar, stats, ver]:
		_home[c] = c.position
		c.modulate.a = 0.0
	dark.color = DARK_OFF
	hero.unlit = true
	match_spr = Sprite2D.new()
	match_spr.texture = Art.tex("pickups/match_f0")
	match_spr.centered = false
	match_spr.offset = Vector2(-3, 0)   # head at the top-centre
	match_spr.z_index = 6
	match_spr.position = hero.position + Vector2(40, -8)
	add_child(match_spr)
	match_flame = AnimatedSprite2D.new()
	match_flame.sprite_frames = Art.anim("fx/ember", 14.0)
	match_flame.material = Art.unshaded
	match_flame.position = Vector2(0, -3)
	match_flame.visible = false
	match_flame.play("default")
	match_spr.add_child(match_flame)
	match_light = PointLight2D.new()
	match_light.texture = Art.light_tex
	match_light.color = Color(1.0, 0.7, 0.4)
	match_light.energy = 0.0
	match_light.texture_scale = 0.55
	match_light.position = Vector2(0, -3)
	match_spr.add_child(match_light)


func _wick_point() -> Vector2:
	return hero.position + hero.wick_tip()


func _intro_step(dt: float) -> void:
	_it += dt
	# 0.0-0.35 dark; 0.35 strike; 0.35-0.8 carry to the wick; 0.8 the wick catches
	if not _struck and _it >= 0.35:
		_struck = true
		Audio.play("match_strike")
		match_flame.visible = true
		var head := match_spr.position + Vector2(0, -2)
		embers.burst(head, 10, 30.0, 90.0, Vector2(-0.6, -1), 1.1, 0.35, FxParts.SPARK, 160.0, 1.5, 1, true)
		match_light.energy = 1.6
	if _struck and not _lit:
		var k := clampf((_it - 0.35) / 0.45, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var start := hero.position + Vector2(40, -8)
		var goal := _wick_point() + Vector2(3, -1)
		match_spr.position = start.lerp(goal, e).round()
		match_light.energy = lerpf(1.6, 0.9, k) * (1.0 + 0.1 * sin(_it * 40.0))
		if k >= 1.0:
			_light_wick()
	if _lit:
		var k2 := clampf((_it - 0.8) / 0.55, 0.0, 1.0)
		# the room light blooms past full, then settles
		hero.light_k = lerpf(0.0, 1.35, minf(1.0, k2 * 1.6)) if k2 < 0.62 else lerpf(1.35, 1.0, (k2 - 0.62) / 0.38)
		dark.color = DARK_OFF.lerp(DARK_LIT, k2)
		# the match withdraws and goes out
		match_spr.position += Vector2(30, 14) * dt
		match_light.energy = maxf(0.0, match_light.energy - dt * 3.0)
		match_spr.modulate.a = maxf(0.0, 1.0 - (_it - 0.95) * 3.0)
		if match_spr.modulate.a <= 0.0 and match_flame.visible:
			match_flame.visible = false
	# 1.05-1.4 the logo flickers on like a bad bulb
	if _it >= 1.05:
		var steps := [0.0, 0.7, 0.15, 0.9, 0.35, 1.0]
		var si := mini(int((_it - 1.05) / 0.06), steps.size() - 1)
		logo.modulate.a = steps[si]
	# 1.45-1.95 the menu slides in
	var mk := clampf((_it - 1.45) / 0.5, 0.0, 1.0)
	var back := 1.0 + 2.2 * pow(mk - 1.0, 3.0) + 1.2 * pow(mk - 1.0, 2.0)   # ease-out-back
	for c in [menu, box, bar]:
		c.position = _home[c] + Vector2(0, roundf((1.0 - back) * 70.0))
		c.modulate.a = minf(1.0, mk * 2.0)
	for c in [sub, stats, ver]:
		c.modulate.a = clampf((_it - 1.6) / 0.35, 0.0, 1.0)
	if _it >= INTRO_END:
		_intro_finish()


func _light_wick() -> void:
	_lit = true
	hero.unlit = false
	hero.light_k = 0.0
	Audio.play("ui_open", -4.0)
	var w := _wick_point()
	embers.burst(w + Vector2(0, -4), 8, 20.0, 60.0, Vector2.UP, 0.9, 0.4, FxParts.SPARK, 60.0, 2.0, 1, true)
	embers.burst(w + Vector2(0, -6), 4, 8.0, 20.0, Vector2.UP, 0.5, 1.0, FxParts.EMBER, -10.0, 0.8)


func _intro_finish() -> void:
	if not _intro:
		return
	_intro = false
	if not _struck:
		Audio.play("match_strike")
	hero.unlit = false
	hero.light_k = 1.0
	dark.color = DARK_LIT
	for c in _home.keys():
		if is_instance_valid(c):
			c.position = _home[c]
			c.modulate.a = 1.0
	if is_instance_valid(match_spr):
		match_spr.queue_free()


func _input(event: InputEvent) -> void:
	if not _intro:
		return
	var press := false
	if event is InputEventKey:
		press = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		press = event.pressed
	if press:
		# the first tap only skips the opening; it never presses a button underneath
		get_viewport().set_input_as_handled()
		_intro_finish()


func _process(dt: float) -> void:
	_t += dt
	hero.vel.x = sin(_t * 0.7) * 20.0   # the flame sways in a draught
	if _intro:
		_intro_step(dt)
	# embers drift up from Tallow's flame and from the logo's little candle
	if not hero.unlit and is_instance_valid(hero) and randf() < dt * 1.6:
		var tip := hero.flame.global_position + Vector2(randf_range(-1, 1), -9)
		embers.emit(tip, Vector2(randf_range(-5, 5), randf_range(-26, -16)), randf_range(0.9, 1.5), FxParts.EMBER, -5.0, 0.5)
	if logo.modulate.a > 0.5 and randf() < dt * 1.1:
		embers.emit(Vector2(-12 + randf_range(-1, 1), -88), Vector2(randf_range(-4, 4), randf_range(-14, -8)), randf_range(0.8, 1.4), FxParts.EMBER, -3.0, 0.5)


func _cycle(d: int) -> void:
	var i := Candles.ORDER.find(sel)
	sel = Candles.ORDER[(i + d + Candles.ORDER.size()) % Candles.ORDER.size()]
	_show_candle()


func _show_candle() -> void:
	var def: Dictionary = Candles.def_of(sel)
	var unlocked := Candles.is_unlocked(sel)
	var n := 0
	for k in Candles.ORDER:
		if Candles.is_unlocked(k):
			n += 1
	sel_name.text = def["name"] if unlocked else "? ? ?"
	sub.text = def["line"] if unlocked else "Locked: %s" % def["unlock_text"]
	sub.add_theme_color_override("font_color", UI.DIM if unlocked else UI.RED)
	# rebuild the preview candle with this candle's look
	var pos := hero.position
	var was_unlit := hero.unlit
	hero.queue_free()
	hero = Player.new()
	hero.world = get_child(2) if get_child_count() > 2 else null
	for c in get_children():
		if c is FakeWorld:
			hero.world = c
	hero.position = pos
	add_child(hero)
	hero.set_physics_process(false)
	hero.apply_candle(sel)
	hero.wax = hero.wax_max * 0.88
	hero.unlit = was_unlit
	if not unlocked:
		hero.modulate = Color(0.12, 0.1, 0.11)
		hero.light.enabled = false
		hero.glow.enabled = false
	# Light the wick opens the Slots screen whatever is shown here: each slot lights its own unlocked candle
	if unlocked and str(Game.records.get("candle", "")) != sel:
		Game.records["candle"] = sel
		Game.save()


## Light the wick: the three save slots (scripts/ui/slots.gd), each with its own difficulty level.
func _play() -> void:
	Slots.open(root, main)


func _daily() -> void:
	var go := func():
		_abandon_check(func():
			Audio.play("ui_open")
			var date := Time.get_date_string_from_system()
			main.goto("game", {"seed": hash("wax&wane" + date), "daily": true, "candle": "tallow"}))
	if bool(Game.records.get("daily_explained", false)):
		go.call()
		return
	# UX-05: the first time, one card says what it is (its first try is the score that counts)
	var m := UI.modal(root, "TONIGHT'S CANDLE")
	var r: Control = m[0]
	var v: VBoxContainer = m[1]
	for line in ["One house for everyone tonight: the same rooms, the same relics.",
			"Only your first try counts. A new house tomorrow."]:
		v.add_child(UI.label(line, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var light := UI.button("Light it", func():
		Game.records["daily_explained"] = true
		Game.save()
		r.queue_free()
		go.call(), 90)
	light.set_meta("default_focus", true)
	row.add_child(light)
	row.add_child(UI.button("Not now", func(): r.queue_free(), 90))
	v.add_child(row)


## QA-02: a saved run is never thrown away silently. Tonight's Candle or a seed lit while the slot in
## use has a saved run asks first (Slots.abandon_check; the Slots screen's Play asks the same).
func _abandon_check(start: Callable) -> void:
	Slots.abandon_check(root, Game.slot, start)


func _credits() -> void:
	var m := UI.modal(root, "CREDITS")
	var v: VBoxContainer = m[1]
	v.add_theme_constant_override("separation", 3)
	var pages := preload("res://scripts/ui/credits_pages.gd")
	for line in [
		["Made by", "one developer, with Claude (AI)"],
		["Made for this game", "Tallow, %s, the relics," % pages.cast_line(true).replace(" and ", ", ")],
		["", "the rooms, effects, jingles and logo"],
		["Dungeon art (CC0)", "0x72: tiles, %s" % pages.cast_line(false).replace(" and ", ", ")],
		["Music (CC0)", "Ninja Adventure by Pixel-boy and AAA"],
		["Sound effects (CC0)", "Kenney packs, Ninja Adventure"],
		["Fonts (CC0)", "Kenney Pixel and Kenney Mini"],
		["Engine (MIT)", "Godot Engine"],
	]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 5)
		var k := UI.label(line[0], 8, UI.EMBER, HORIZONTAL_ALIGNMENT_RIGHT)
		k.custom_minimum_size = Vector2(120, 0)
		row.add_child(k)
		var val := UI.label(line[1], 8, UI.CREAM)
		val.custom_minimum_size = Vector2(170, 0)
		row.add_child(val)
		v.add_child(row)
	# the licences (assets, Godot and its parts) and the privacy policy, each on its own page
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 4)
	btns.add_child(UI.button("Licences", func(): pages.licences(root), 84))
	btns.add_child(UI.button("Privacy", func(): pages.privacy(root), 84))
	var back := UI.button("Back", func(): m[0].queue_free(), 84)
	back.set_meta("default_focus", true)
	btns.add_child(back)
	v.add_child(btns)


## Menu buttons are MENU_H (24) px tall: a thumb-sized target (UX-05).
func _menu_btn(text: String, cb: Callable, w: int) -> Button:
	var b := UI.button(text, cb, w)
	b.custom_minimum_size.y = MENU_H
	return b


# ---------------------------------------------------------------- a seeded run (the keypad)

## Light a house from a number a friend read out (results screen / Journal: "Seed 4821 7730").
## Seeded runs use the house's default relic pool, so the same seed is the same run for everyone.
func open_seed_pad() -> void:
	var m := UI.modal(root, "LIGHT A SEED")
	var mr: Control = m[0]
	var v: VBoxContainer = m[1]
	v.add_theme_constant_override("separation", 3)
	var st := {"digits": ""}
	var last: Array = Game.records.get("run_history", [])
	var shown := UI.label("", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	shown.custom_minimum_size = Vector2(150, 16)
	v.add_child(shown)
	var hint := UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var go := UI.button("Light", func(): pass, 30)
	var refresh := func():
		var d: String = st["digits"]
		shown.text = (Records.seed_text(int(d)) if d != "" else "") + ("_" if d.length() < 10 else "")
		if d != "":
			hint.text = "Same seed, same house, for anyone"
		elif not last.is_empty():
			hint.text = "Your last run: " + Records.seed_text(int(last[0].get("seed", 0)))
		else:
			hint.text = "Type the number a friend gave you"
		go.disabled = d == ""
		go.modulate.a = 0.4 if d == "" else 1.0
	var press := func(k: String):
		var d: String = st["digits"]
		if k == "<":
			d = d.substr(0, maxi(0, d.length() - 1))
		elif d.length() < 10 and not (d == "" and k == "0"):
			d += k
		st["digits"] = d
		refresh.call()
	var light := func():
		if st["digits"] == "":
			return
		var seed_n := int(st["digits"])
		mr.queue_free()
		_abandon_check(func():
			Audio.play("ui_open")
			main.goto("game", {"seed": seed_n, "candle": sel if Candles.is_unlocked(sel) else "tallow"}))
	go.pressed.connect(light)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0"]:
		var b := UI.button(k if k != "<" else "Del", press.bind(k), 34)
		b.custom_minimum_size.y = MENU_H
		if k == "1":
			b.set_meta("default_focus", true)
		grid.add_child(b)
	go.custom_minimum_size = Vector2(34, MENU_H)
	grid.add_child(go)
	v.add_child(grid)
	var back := UI.button("Back", func(): mr.queue_free(), 70)
	back.custom_minimum_size.y = MENU_H
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	refresh.call()
	# a keyboard can type the number straight in
	var catcher := Node.new()
	catcher.set_script(preload("res://scripts/ui/key_catcher.gd"))
	catcher.set_meta("cb", func(ev: InputEventKey):
		var kc: int = ev.keycode
		if kc >= KEY_0 and kc <= KEY_9:
			press.call(str(kc - KEY_0))
		elif kc >= KEY_KP_0 and kc <= KEY_KP_9:
			press.call(str(kc - KEY_KP_0))
		elif kc == KEY_BACKSPACE:
			press.call("<")
		elif kc == KEY_KP_ENTER:
			light.call())
	mr.add_child(catcher)


func on_back() -> void:
	if _intro:
		_intro_finish()
		return
	var top: Node = root.get_child(root.get_child_count() - 1)
	if top.get_meta("modal", false):
		top.queue_free()
		return
	Controls.quit_prompt(root)   # phones close at once; desktops ask first
