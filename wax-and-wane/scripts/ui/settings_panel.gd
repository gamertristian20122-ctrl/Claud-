class_name SettingsPanel
extends RefCounted
## The settings modal, used from the title screen and the pause menu. Three pages (Game, Controls,
## Keys) so it fits a 384x216 screen; LB/RB (Q/E) switch pages with a gamepad or keyboard.
## Keys (v2.3): the special move, the bomb and the keepsake can move to another key / pad button.

const PAGES := ["Game", "Controls", "Keys"]
const BIND_NAMES := {"special": "Special move", "bomb": "Bomb", "keepsake": "Keepsake"}


static func open(parent: Control, page := 0) -> void:
	var m := UI.modal(parent, "")
	var root: Control = m[0]
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.custom_minimum_size = Vector2(306, 112)
	v.add_child(body)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 6)
	v.add_child(bottom)
	var st := {"page": page}
	var tab_btns: Array[Button] = []
	var show_page := func(i: int, focus_tab: bool):
		st["page"] = i
		for c in body.get_children():
			body.remove_child(c)
			c.queue_free()
		if i == 0:
			_game_page(body, parent)
		elif i == 1:
			_controls_page(body)
		else:
			_keys_page(body, func(): (st["show"] as Callable).call(2, false))
		for k in tab_btns.size():
			var on := k == i
			tab_btns[k].add_theme_color_override("font_color", UI.GOLD if on else UI.DIM)
			tab_btns[k].set_meta("default_focus", on)
		if focus_tab:
			tab_btns[i].grab_focus(not Controls.uses_buttons())
	st["show"] = show_page
	# the Keys page needs keys or a pad: a phone played by touch alone does not list it
	var n_pages := PAGES.size() if OS.has_feature("pc") or Controls.device != Controls.TOUCH else PAGES.size() - 1
	for i in n_pages:
		var b := UI.button(L.t(PAGES[i]), func(): pass, 72)
		b.pressed.connect(func(): show_page.call(i, true))
		tabs.add_child(b)
		tab_btns.append(b)
	if OS.has_feature("pc") or Controls.device != Controls.TOUCH:
		tabs.add_child(_hint("Q / E" if Controls.device != Controls.PAD else "LB / RB"))
	bottom.add_child(UI.button("Achievements  %d/%d" % [Achievements.count(), Achievements.LIST.size()], func():
		Achievements.open_list(parent), 150))
	var back := UI.button("Back", func():
		Audio.play("ui_back")
		root.queue_free(), 96)
	bottom.add_child(back)
	show_page.call(mini(page, n_pages - 1), false)
	Controls.set_page_handler(root, func(d: int): show_page.call((st["page"] + d + n_pages) % n_pages, true))


static func _hint(t: String) -> Label:
	var l := UI.label(t, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 24)
	return l


static func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	return grid


static func _game_page(body: VBoxContainer, _parent: Control) -> void:
	var sliders := HBoxContainer.new()
	sliders.add_theme_constant_override("separation", 12)
	sliders.alignment = BoxContainer.ALIGNMENT_CENTER
	sliders.add_child(UI.slider_row("Music", Game.settings["music"], func(x): Game.set_setting("music", x)))
	sliders.add_child(UI.slider_row("Sound", Game.settings["sfx"], func(x):
		Game.set_setting("sfx", x)
		Audio.play("coin_pickup")))
	body.add_child(sliders)
	var grid := _grid()
	grid.add_child(UI.toggle("Screen shake", Game.settings["shake"], func(b): Game.set_setting("shake", b)))
	grid.add_child(UI.toggle("Vibration", Game.settings["vibration"], func(b):
		Game.set_setting("vibration", b)
		if b:
			Game.vibrate(60)))
	# (Gentle burn is gone: difficulty level 1 replaces it, chosen per save slot on the Slots screen)
	grid.add_child(UI.cycle("Effects", ["full", "lite"], ["Full", "Lite"], Game.settings.get("effects", "full"),
		func(v): Game.set_setting("effects", v)))
	grid.add_child(_hint("Lite: no heat haze or shockwaves"))
	grid.add_child(UI.toggle("FPS counter", Game.settings["show_fps"], func(b): Game.set_setting("show_fps", b)))
	if OS.has_feature("pc"):   # F11 / Alt+Enter also switch it
		var fs := UI.toggle("Fullscreen (F11)", Game.settings.get("fullscreen", false), func(b): Game.set_setting("fullscreen", b))
		grid.add_child(fs)
	body.add_child(grid)


static func _controls_page(body: VBoxContainer) -> void:
	var grid := _grid()
	grid.add_child(UI.cycle("Touch", ["auto", "on", "off"], ["AUTO", "ON", "OFF"], Game.settings.get("touch_controls", "auto"),
		func(x): Game.set_setting("touch_controls", x)))
	grid.add_child(UI.toggle("Swap sticks", Game.settings["swap_sticks"], func(b): Game.set_setting("swap_sticks", b)))
	grid.add_child(UI.toggle("Aim assist", Game.settings["aim_assist"], func(b): Game.set_setting("aim_assist", b)))
	if OS.has_feature("pc"):
		grid.add_child(UI.toggle("Mouse aim", Game.settings.get("mouse_aim", true), func(b): Game.set_setting("mouse_aim", b)))
	grid.add_child(UI.cycle("Enemy shots", ["normal", "large"], ["Normal", "Large"], Game.settings.get("shot_size", "normal"),
		func(v): Game.set_setting("shot_size", v)))   # v2.1: bigger, bolder enemy shots (shot.gd)
	body.add_child(grid)
	var lines := [
		["Keys", "WASD move   Arrows shoot   %s bomb   %s keepsake   %s special" % [
			Controls.bound_glyph("bomb", false), Controls.bound_glyph("keepsake", false), Controls.bound_glyph("special", false)]],
		["Mouse", "Hold left: fire at the cursor   Right: bomb   Thumb: special"],
		["Pad", "Sticks move + aim   ABXY fire   %s bomb   %s keepsake   %s special" % [
			Controls.bound_glyph("bomb", true), Controls.bound_glyph("keepsake", true), Controls.bound_glyph("special", true)]],
	]
	if not OS.has_feature("pc"):
		lines[1] = ["Touch", "Left thumb moves   Right thumb aims   Auto hides on a pad"]
	for ln in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var k := UI.label(ln[0], 8, UI.GOLD)
		k.custom_minimum_size = Vector2(30, 0)
		row.add_child(k)
		row.add_child(UI.label(ln[1], 8, UI.CREAM))
		body.add_child(row)


## v2.3: rebind the special move, the bomb and the keepsake (keyboard key and pad button each).
## Pick a button, then press the new key or pad button; Esc / the same button keeps the old one.
## A key another action already uses is refused ("E is the bomb"). Controls.rebind / apply_binds.
static func _keys_page(body: VBoxContainer, refresh: Callable) -> void:
	var head := UI.label(L.t("Pick one, then press the new key or pad button."), 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	for a in Controls.BINDABLE:
		var l := UI.label(L.t(BIND_NAMES[a]), 16, UI.GOLD)
		l.custom_minimum_size = Vector2(96, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(l)
		for pad in [false, true]:
			grid.add_child(_bind_button(a, pad, head, refresh))
	body.add_child(grid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.button(L.t("Reset"), func():
		Controls.reset_binds()
		refresh.call(), 64))
	var fixed := UI.label(L.t("WASD move   Arrows shoot   Esc pause"), 8, UI.CREAM)
	fixed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fixed.custom_minimum_size = Vector2(0, 24)
	row.add_child(fixed)
	body.add_child(row)


static func _bind_button(action: String, pad: bool, head: Label, refresh: Callable) -> Button:
	var b := UI.button(Controls.bound_glyph(action, pad), func(): pass, 84 if not pad else 72)
	b.pressed.connect(func():
		if b.has_meta("catcher"):
			return
		b.text = L.t("Press...") if not pad else L.t("Pad...")
		var c := BindCatcher.new()
		c.pad = pad
		c.done = func(ev: InputEvent):
			b.remove_meta("catcher")
			if ev == null:
				refresh.call()
				return
			var clash := Controls.rebind(action, ev)
			if clash == "":
				Audio.play("ui_click")
				refresh.call()
			else:
				Audio.play("ui_back")
				head.text = L.t("Taken: that one is {what}.", {"what": L.t(BIND_NAMES.get(clash, clash.replace("_", " ")))})
				head.add_theme_color_override("font_color", UI.RED)
				b.text = Controls.bound_glyph(action, pad)
		b.set_meta("catcher", c)
		b.add_child(c))
	return b


## Waits for the next key (or pad button / trigger) and hands it over; Esc or B keeps the old one.
class BindCatcher extends Node:
	var pad := false
	var done: Callable
	var _armed := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		# the press that opened the catcher must not be caught: listen from the next frame on
		get_tree().process_frame.connect(func(): _armed = true, CONNECT_ONE_SHOT)

	func _input(event: InputEvent) -> void:
		if not _armed:
			return
		var got: InputEvent = null
		var cancel := false
		if event is InputEventKey and event.pressed and not event.echo:
			cancel = (event as InputEventKey).physical_keycode == KEY_ESCAPE or pad
			got = null if cancel else event
		elif event is InputEventJoypadButton and event.pressed:
			cancel = (event as InputEventJoypadButton).button_index == JOY_BUTTON_B and not pad or not pad
			got = null if cancel else event
		elif pad and event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6 \
				and (event as InputEventJoypadMotion).axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			got = event
		elif event is InputEventMouseButton and event.pressed:
			cancel = true
		else:
			return
		get_viewport().set_input_as_handled()
		var cb := done
		queue_free()
		cb.call(null if cancel else got)
