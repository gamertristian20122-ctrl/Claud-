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
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 3)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	menu.position = Vector2(-30, -98)
	root.add_child(menu)
	play_btn = UI.button("Light the wick", _play, 110)
	menu.add_child(play_btn)
	menu.add_child(UI.button("Tonight's Candle", _daily, 110))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.add_child(UI.button("Settings", func(): SettingsPanel.open(root), 54))
	row.add_child(UI.button("Credits", _credits, 54))
	menu.add_child(row)
	# --- the Candle Box: pick which candle to light
	box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.position = Vector2(-140, -40)
	root.add_child(box)
	box.add_child(UI.button("<", func(): _cycle(-1), 18))
	sel_name = UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	sel_name.custom_minimum_size = Vector2(62, 24)
	sel_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(sel_name)
	box.add_child(UI.button(">", func(): _cycle(1), 18))
	sel = Game.settings.get("candle", "tallow")
	if not Candles.is_unlocked(sel):
		sel = "tallow"
	_show_candle()
	var rec := Game.records
	var line := "Runs %d   Wins %d" % [rec["runs"], rec["wins"]]
	if rec.get("daily_date", "") == Time.get_date_string_from_system():
		line += "   Tonight: %d" % int(rec.get("daily_first", 0))
	if float(rec["best_finish"]) != 0.0:
		line += "   Best: done by %s" % Game.clock_text(float(rec["best_finish"]))
	stats = UI.label(line, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	stats.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	stats.size = Vector2(300, 10)
	stats.position = Vector2(-150, -12)
	root.add_child(stats)
	ver = UI.label("v" + Game.VERSION, 8, Color(0.4, 0.33, 0.33))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-28, -12)
	root.add_child(ver)
	_intro_begin()


# ---------------------------------------------------------------- opening

func _intro_begin() -> void:
	for c in [logo, sub, menu, box, stats, ver]:
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
	return hero.position + Vector2(1, hero._top - 3)


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
		var goal := _wick_point() + Vector2(4, 2)
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
	for c in [menu, box]:
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
	play_btn.disabled = not unlocked
	play_btn.modulate.a = 1.0 if unlocked else 0.4
	if unlocked:
		Game.settings["candle"] = sel
		Game.save()


func _play() -> void:
	if not Candles.is_unlocked(sel):
		return
	Audio.play("ui_open")
	main.goto("game", {"candle": sel})


func _daily() -> void:
	Audio.play("ui_open")
	var date := Time.get_date_string_from_system()
	main.goto("game", {"seed": hash("wax&wane" + date), "daily": true, "candle": "tallow"})


func _credits() -> void:
	var m := UI.modal(root, "CREDITS")
	var v: VBoxContainer = m[1]
	for line in [
		"Design, code: made for you with Claude",
		"Dungeon art: 0x72 - DungeonTileset II (CC0)",
		"Fonts: Kenney Pixel & Mini (CC0)",
		"Sounds: Kenney audio packs (CC0)",
		"Music: original, synthesized for this game",
		"Engine: Godot Engine (MIT)",
	]:
		v.add_child(UI.label(line, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.button("Back", func(): m[0].queue_free()))


func on_back() -> void:
	if _intro:
		_intro_finish()
		return
	var top: Node = root.get_child(root.get_child_count() - 1)
	if top.get_meta("modal", false):
		top.queue_free()
		return
	get_tree().quit()
