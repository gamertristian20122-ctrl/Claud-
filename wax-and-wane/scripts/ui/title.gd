extends Node2D
## Title screen: the little candle alone in a dark cellar, the logo, Play / Settings / Credits.

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
	dark.color = Color(0.12, 0.09, 0.1)
	add_child(dark)
	var fw := FakeWorld.new()
	add_child(fw)
	hero = Player.new()
	hero.world = fw
	hero.position = Vector2(-78, 44)
	hero.wax = 105.0
	add_child(hero)
	hero.set_physics_process(false)
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var logo := TextureRect.new()
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
	var menu := VBoxContainer.new()
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
	RunSave.add_continue_button(menu, main)   # "Continue / Floor N - 12:41 AM" when a run is saved
	# --- the Candle Box: pick which candle to light
	var box := HBoxContainer.new()
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
	Controls.set_page_handler(root, _cycle)   # LB / RB (Q / E) pick a candle
	var rec := Game.records
	var line := "Runs %d   Wins %d" % [rec["runs"], rec["wins"]]
	if rec.get("daily_date", "") == Time.get_date_string_from_system():
		line += "   Tonight: %d" % int(rec.get("daily_first", 0))
	if float(rec["best_finish"]) != 0.0:
		line += "   Best: done by %s" % Game.clock_text(float(rec["best_finish"]))
	var stats := UI.label(line, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	stats.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	stats.size = Vector2(300, 10)
	stats.position = Vector2(-150, -12)
	root.add_child(stats)
	var ver := UI.label("v" + Game.VERSION, 8, Color(0.4, 0.33, 0.33))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-28, -12)
	root.add_child(ver)


func _process(dt: float) -> void:
	_t += dt
	hero.vel.x = sin(_t * 0.7) * 20.0   # the flame sways in a draught


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
	var top: Node = root.get_child(root.get_child_count() - 1)
	if top.get_meta("modal", false):
		top.queue_free()
		return
	Controls.quit_prompt(root)   # phones close at once; desktops ask first
