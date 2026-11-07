class_name SettingsPanel
extends RefCounted
## The settings modal, used from the title screen and the pause menu.


static func open(parent: Control) -> void:
	var m := UI.modal(parent, "SETTINGS")
	var root: Control = m[0]
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	v.add_child(UI.slider_row("Music", Game.settings["music"], func(x): Game.set_setting("music", x)))
	v.add_child(UI.slider_row("Sound", Game.settings["sfx"], func(x):
		Game.set_setting("sfx", x)
		Audio.play("coin_pickup")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	grid.add_child(UI.toggle("Aim assist", Game.settings["aim_assist"], func(b): Game.set_setting("aim_assist", b)))
	grid.add_child(UI.toggle("Swap sticks", Game.settings["swap_sticks"], func(b): Game.set_setting("swap_sticks", b)))
	grid.add_child(UI.toggle("Vibration", Game.settings["vibration"], func(b): Game.set_setting("vibration", b)))
	grid.add_child(UI.toggle("Screen shake", Game.settings["shake"], func(b): Game.set_setting("shake", b)))
	grid.add_child(UI.toggle("FPS counter", Game.settings["show_fps"], func(b): Game.set_setting("show_fps", b)))
	grid.add_child(UI.toggle("Gentle burn", Game.settings.get("gentle", false), func(b): Game.set_setting("gentle", b)))
	v.add_child(grid)
	v.add_child(UI.button("Back", func():
		Audio.play("ui_back")
		root.queue_free()))
