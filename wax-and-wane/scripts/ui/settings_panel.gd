class_name SettingsPanel
extends RefCounted
## The settings modal, used from the title screen and the pause menu. Two pages (Game, Controls)
## so it fits a 384x216 screen; LB/RB (Q/E) switch pages with a gamepad or keyboard.

const PAGES := ["Game", "Controls"]


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
		else:
			_controls_page(body)
		for k in tab_btns.size():
			var on := k == i
			tab_btns[k].add_theme_color_override("font_color", UI.GOLD if on else UI.DIM)
			tab_btns[k].set_meta("default_focus", on)
		if focus_tab:
			tab_btns[i].grab_focus(not Controls.uses_buttons())
	for i in PAGES.size():
		var b := UI.button(PAGES[i], func(): pass, 84)
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
	show_page.call(page, false)
	Controls.set_page_handler(root, func(d: int): show_page.call((st["page"] + d + PAGES.size()) % PAGES.size(), true))


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
	grid.add_child(UI.toggle("Gentle burn", Game.settings.get("gentle", false), func(b): Game.set_setting("gentle", b)))
	grid.add_child(UI.toggle("FPS counter", Game.settings["show_fps"], func(b): Game.set_setting("show_fps", b)))
	if OS.has_feature("pc"):
		var fs := UI.toggle("Fullscreen", Game.settings.get("fullscreen", false), func(b): Game.set_setting("fullscreen", b))
		grid.add_child(fs)
		grid.add_child(_hint("F11 or Alt+Enter"))
	body.add_child(grid)


static func _controls_page(body: VBoxContainer) -> void:
	var grid := _grid()
	grid.add_child(UI.cycle("Touch", ["auto", "on", "off"], ["AUTO", "ON", "OFF"], Game.settings.get("touch_controls", "auto"),
		func(x): Game.set_setting("touch_controls", x)))
	grid.add_child(UI.toggle("Swap sticks", Game.settings["swap_sticks"], func(b): Game.set_setting("swap_sticks", b)))
	grid.add_child(UI.toggle("Aim assist", Game.settings["aim_assist"], func(b): Game.set_setting("aim_assist", b)))
	if OS.has_feature("pc"):
		grid.add_child(UI.toggle("Mouse aim", Game.settings.get("mouse_aim", true), func(b): Game.set_setting("mouse_aim", b)))
	body.add_child(grid)
	var lines := [
		["Keys", "WASD move   Arrows shoot   E bomb   Q keepsake   Esc pause"],
		["Mouse", "Hold left: fire at the cursor   Right: bomb"],
		["Pad", "Sticks move + aim   ABXY fire   RB bomb   LB keepsake"],
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
