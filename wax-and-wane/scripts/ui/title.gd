extends Node2D
## Title screen: the little candle alone in a dark cellar, the logo, Play / Settings / Credits.
## Opening (about 2.2 s, any tap skips): darkness, a match strikes and lights Tallow's wick, the room
## light blooms, the logo flickers on, embers drift up and the menu slides in.
##
## v2.6 layout (docs/streams/v26_gui.md): the logo at the top; Tallow (the chosen candle) in the middle on a stack of
## old books, lit, his light pooled on the floor and the slot's numbers under him; the Candle Box on the left
## (arrows, the candle's name, its special move and lines, in a panel); the actions on the right (Continue, ONE big
## brass "Light the wick", Tonight's Candle); Journal / Seed / Settings / Credits (/ Quit) as small icon buttons
## along the bottom; the version small in the top-right corner. Every piece is placed from the screen's centre
## (_layout), so 384x216, 384x240 and the phone's 480x216 keep the same composition.

const INTRO_END := 2.2

var main: Node
var ui: CanvasLayer
var root: Control
var hero: Player
var dark: CanvasModulate
var _t := 0.0
var sel := "tallow"
var sub: Label           # the candle's line (or what unlocks it), in the Candle Box
var sel_name: Label
var play_btn: Button
var journal_btn: Button
var cont_btn: Button   # Continue (the saved run of the slot played last), or null
## UX-05: menu buttons are 24 px tall with 4 px gaps (thumb-sized on a phone); the main action is 32 px.
const MENU_W := 120
const MENU_H := 24
const BIG_H := 32
const GAP := 4
const BOX_W := 132       # the Candle Box panel
const SIDE := 56         # the Candle Box and the actions keep this far from the centre (Tallow's stage)
const STAND := Vector2(0, 16)   # Tallow's feet, from the room's centre (on top of the books)
var bar: HBoxContainer
# ---- opening
var logo: TextureRect
var tagline: Label
var menu: VBoxContainer
var box: PanelContainer
var stats: Label
var ver: Label
var books: Sprite2D
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
	# Tallow's stand: three old books in the middle of the room (lit by him like the rest of the room)
	books = Sprite2D.new()
	books.texture = Art.tex("ui/title_books")
	books.centered = false
	books.position = STAND + Vector2(-18, -1)
	add_child(books)
	hero = Player.new()
	hero.world = fw
	hero.position = STAND
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
	# ---- the logo and the tagline
	logo = TextureRect.new()
	logo.texture = Art.tex("ui/title_logo") if Art.has("ui/title_logo") else null
	logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	logo.size = Vector2(210, 41)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo)
	if logo.texture == null:
		# v2.10: the drawn logo is gone: the name is set in the game's font, twice the size, in candle gold
		var t := UI.outlined(UI.label("WAX & WANE", 32, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		t.size = Vector2(210, 36)
		t.position = Vector2(0, 4)
		logo.add_child(t)
	tagline = UI.label(L.t("Burn through the house before the clock strikes two."), 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(tagline)
	Unlocks.take_new()   # anything unlocked since the last visit gets its Journal dot
	# ---- the actions (right): [Continue] / LIGHT THE WICK / Tonight's Candle
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", GAP)
	root.add_child(menu)
	play_btn = UI.icon_button(L.t("Light the wick"), "ui/ico_flame_dark", _play, MENU_W, "primary")
	play_btn.custom_minimum_size.y = BIG_H
	play_btn.set_meta("default_focus", true)
	menu.add_child(play_btn)
	var daily := UI.icon_button(L.t("Tonight's Candle"), "ui/ico_moon", _daily, MENU_W)
	daily.custom_minimum_size.y = MENU_H
	menu.add_child(daily)
	cont_btn = RunSave.add_continue_button(menu, main)   # "Continue / Slot N: Floor N - 12:41 AM" when a run is saved
	if cont_btn:
		cont_btn.custom_minimum_size.x = MENU_W
		play_btn.set_meta("default_focus", false)
	# ---- the rest (bottom): Journal | Seed | Settings | Credits [| Quit on desktop], small icon buttons
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", GAP)
	journal_btn = _small_btn(L.t("Journal"), "ui/ico_journal", func(): Journal.open(root).tree_exited.connect(journal_btn.queue_redraw))
	journal_btn.draw.connect(func():
		if Records.any_new():
			Journal._dot(journal_btn, Vector2(journal_btn.size.x - 7, 5)))
	bar.add_child(journal_btn)
	bar.add_child(_small_btn(L.t("Seed"), "ui/ico_seed", open_seed_pad))
	bar.add_child(_small_btn(L.t("Settings"), "ui/ico_settings", func(): SettingsPanel.open(root)))
	bar.add_child(_small_btn(L.t("Credits"), "ui/ico_credits", _credits))
	if OS.has_feature("pc"):   # QA-22: desktops get a Quit button (it asks first)
		bar.add_child(_small_btn(L.t("Quit"), "ui/ico_quit", func(): Controls.quit_prompt(root)))
	root.add_child(bar)
	# ---- the Candle Box (left): pick which candle to light
	box = UI.panel(Vector2(BOX_W, 0))
	box.set_meta("fit_group", "candle_box")
	root.add_child(box)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	box.add_child(bv)
	bv.add_child(UI.label(L.t("THE CANDLE BOX"), 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var pick := HBoxContainer.new()
	pick.add_theme_constant_override("separation", 2)
	pick.add_child(UI.button("<", func(): _cycle(-1), 24))
	sel_name = UI.label("", 16, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	sel_name.custom_minimum_size = Vector2(54, 24)
	sel_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pick.add_child(sel_name)
	pick.add_child(UI.button(">", func(): _cycle(1), 24))
	bv.add_child(pick)
	_add_move_caption(bv)   # v2.3: the candle's special move (icon, name, its line)
	sub = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(BOX_W - 18, 24)
	sub.max_lines_visible = 3
	sub.add_theme_constant_override("line_spacing", 0)
	bv.add_child(sub)
	sel = str(Game.records.get("candle", "tallow"))   # each save slot remembers its own candle
	if not Candles.is_unlocked(sel):
		sel = "tallow"
	_show_candle()
	Controls.set_page_handler(root, _cycle)   # LB / RB (Q / E) pick a candle
	# ---- the slot's numbers, under Tallow's books
	stats = UI.label(_stats_text(), 8, UI.WAX, HORIZONTAL_ALIGNMENT_CENTER)
	stats.add_theme_constant_override("line_spacing", 0)
	root.add_child(stats)
	ver = UI.label("v" + Game.VERSION, 8, UI.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	root.add_child(ver)
	Game.slot_changed.connect(refresh_slot)   # the Slots screen deleted the slot in use or changed its level
	get_viewport().size_changed.connect(_layout)
	_layout()
	_intro_begin()
	if UI.calm():   # Settings > Reduce motion: the title is simply there
		_intro_finish()


## Places every piece from the screen's centre (see the header). The opening slides the menu, the Candle Box and
## the bottom row in from below these spots (_home).
func _layout() -> void:
	if not is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	var cx := floorf(vs.x / 2.0)
	var cy := floorf(vs.y / 2.0)
	var at := {}
	at[logo] = Vector2(cx - 105, cy - 104)
	tagline.size = Vector2(300, 10)
	at[tagline] = Vector2(cx - 150, cy - 61)
	var bottom := vs.y - 4 - MENU_H
	bar.size = bar.get_combined_minimum_size()
	at[bar] = Vector2(cx - floorf(bar.size.x / 2.0), bottom)
	var mid := floorf((cy - 50 + bottom - 4) / 2.0)   # the middle of the band between the tagline and the bottom row
	box.size = box.get_combined_minimum_size()
	at[box] = Vector2(cx - SIDE - box.size.x, mid - floorf(box.size.y / 2.0))
	menu.size = menu.get_combined_minimum_size()
	at[menu] = Vector2(cx + SIDE, mid - floorf(menu.size.y / 2.0))
	stats.size = Vector2(2 * SIDE - 8, 40)
	at[stats] = Vector2(cx - SIDE + 4, cy + STAND.y + 17)
	ver.size = Vector2(60, 10)
	at[ver] = Vector2(vs.x - 63, 3)
	for c in at:
		_home[c] = at[c]
		(c as Control).position = at[c]


## "Slot 1 - level 2" / "Runs 23   Wins 4" / "Best: 12:58 AM" / "Tonight: 4120": short lines under the books.
func _stats_text() -> String:
	var rec := Game.records
	var lines: Array[String] = []
	if Game.slot_live:   # the slot played last (the Slots screen switches slots)
		lines.append(L.t("Slot {n} - level {lv}", {"n": Game.slot, "lv": Game.level}))
	if int(rec["runs"]) == 0:
		lines.append(L.t("Your first night"))
	else:
		lines.append(L.t("Runs {r}   Wins {w}", {"r": rec["runs"], "w": rec["wins"]}))
	if float(rec["best_finish"]) != 0.0:
		lines.append(L.t("Best: {t}", {"t": Game.clock_text(float(rec["best_finish"]))}))
	if rec.get("daily_date", "") == Time.get_date_string_from_system():
		lines.append(L.t("Tonight: {n}", {"n": int(rec.get("daily_first", 0))}))
	return "\n".join(lines)


## A small icon + word button for the bottom row (24 px tall: still a thumb-sized target).
func _small_btn(text: String, icon: String, cb: Callable) -> Button:
	var b := UI.icon_button(text, icon, cb, 0)
	b.custom_minimum_size.y = MENU_H
	return b


## The slot in use changed under the title (deleted, or a new level): its line, Continue and the
## Candle Box follow at once.
func refresh_slot() -> void:
	if not is_inside_tree() or stats == null:
		return
	stats.text = _stats_text()
	if is_instance_valid(cont_btn) and not RunSave.has_snapshot():
		menu.remove_child(cont_btn)
		cont_btn.queue_free()
		cont_btn = null
		play_btn.set_meta("default_focus", true)
	sel = str(Game.records.get("candle", "tallow"))
	if not Candles.is_unlocked(sel):
		sel = "tallow"
	_show_candle()
	journal_btn.queue_redraw()
	_layout.call_deferred()


# ---------------------------------------------------------------- opening

func _intro_begin() -> void:
	for c in [logo, tagline, menu, box, bar, stats, ver]:
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
	for c in [tagline, stats, ver]:
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
		var lf := logo.position + Vector2(93, 1) - get_viewport().get_visible_rect().size / 2.0
		embers.emit(lf + Vector2(randf_range(-1, 1), 0), Vector2(randf_range(-4, 4), randf_range(-14, -8)), randf_range(0.8, 1.4), FxParts.EMBER, -3.0, 0.5)


## v2.3 special moves in the Candle Box: the move's icon and name (gold) under the candle's name, and the move's
## line under them; the candle's own line (or what unlocks it) at the bottom of the panel. Fixed heights, so the
## panel keeps its size from candle to candle.
var move_icon: TextureRect
var move_name: Label
var move_line: Label


func _add_move_caption(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	row.custom_minimum_size.y = 16
	move_icon = TextureRect.new()
	move_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	move_icon.custom_minimum_size = Vector2(16, 16)
	row.add_child(move_icon)
	move_name = UI.label("", 8, UI.GOLD)
	move_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(move_name)
	v.add_child(row)
	move_line = UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	move_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	move_line.custom_minimum_size = Vector2(BOX_W - 18, 20)
	move_line.max_lines_visible = 2
	move_line.add_theme_constant_override("line_spacing", 0)
	v.add_child(move_line)


func _show_move(unlocked: bool) -> void:
	if move_name == null:
		return
	var mv := Moves.for_candle(sel)
	var on := unlocked and mv != ""
	move_name.text = Moves.name_of(mv) if on else L.t("? ? ?")
	move_icon.texture = Art.tex(Moves.icon(mv)) if on and Moves.icon(mv) != "" else null
	move_line.text = Moves.line_of(mv) if on else ""


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
	sel_name.text = L.t(str(def["name"])) if unlocked else L.t("? ? ?")
	_show_move(unlocked)
	sub.text = L.t(str(def["line"])) if unlocked else L.t("Locked: {how}", {"how": L.t(str(def["unlock_text"]))})
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
## v2.8: on a first launch (Game.first_night) it goes straight to the first night. A newcomer was asked to pick
## a slot, a difficulty and a night's length before ever seeing a room, and a publisher's reviewer plays a build
## once ("we'll only play the build the first time you send it", Raw Fury's pitch page). The slots, the levels and
## the night's length are all there from the second night on, when the choice means something.
func _play() -> void:
	if Game.first_night():
		_first_night()
		return
	Slots.open(root, main)


## Slot 1 at Midnight (the game as it was made), four floors, Tallow. `extra`: a test's fixed seed.
func _first_night(extra := {}) -> void:
	Game.start_slot(1, Game.DEFAULT_LEVEL)
	Records.set_night_floors(Areas.MIN_FLOORS)
	Audio.play("ui_open")
	var p := {"candle": "tallow", "floors": Areas.MIN_FLOORS}
	p.merge(extra, true)
	main.goto("game", p)


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
	var light := UI.primary(L.t("Light it"), func():
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



# ---------------------------------------------------------------- a seeded run (the keypad)

## Light a house from a number a friend read out (results screen / Journal: "Seed 4821 7730").
## Seeded runs use the house's default relic pool, so the same seed is the same run for everyone; the night's
## length sits next to the keypad (the slot's, as the Share text names it: "seed 4821 7730, 7 floors").
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
	var go := UI.button(L.t("Light"), func(): pass, 30, "primary")
	var night := Slots.NightSlider.new()   # the night's length: the same seed and floors are the same house
	night.lo = Areas.MIN_FLOORS
	night.hi = Areas.max_floors()
	night.value = Records.night_floors()
	night.custom_minimum_size = Vector2(150, 26)
	var refresh := func():
		var d: String = st["digits"]
		shown.text = (Records.seed_text(int(d)) if d != "" else "") + ("_" if d.length() < 10 else "")
		if d != "":
			hint.text = "Same seed, same floors: the same house, for anyone"
		elif not last.is_empty():
			hint.text = "Your last run: %s, %d floors" % [Records.seed_text(int(last[0].get("seed", 0))), Records.night_of(last[0])]
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
		var floors: int = night.value
		mr.queue_free()
		_abandon_check(func():
			Records.set_night_floors(floors)   # the slot remembers the night's length
			Audio.play("ui_open")
			main.goto("game", {"seed": seed_n, "candle": sel if Candles.is_unlocked(sel) else "tallow", "floors": floors}))
	go.pressed.connect(light)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0"]:
		var b := UI.button(k if k != "<" else "Del", press.bind(k), 34)
		b.custom_minimum_size.y = MENU_H
		if k == "1":
			b.set_meta("default_focus", true)
		grid.add_child(b)
	go.custom_minimum_size = Vector2(34, MENU_H)
	grid.add_child(go)
	# the keypad, and the night's length beside it
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 10)
	mid.add_child(grid)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	var big := UI.label("", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(big)
	col.add_child(night)
	var until := UI.label("", 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(until)
	mid.add_child(col)
	var show_night := func(n: int):
		big.text = "%d FLOORS" % n
		until.text = "Until %s" % Game.clock_text(Game.night_minutes(n), false)
	night.changed.connect(show_night)
	night.accepted.connect(light)
	show_night.call(night.value)
	v.add_child(mid)
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
