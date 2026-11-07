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
	v.add_child(UI.toggle("Aim assist", Game.settings["aim_assist"], func(b): Game.set_setting("aim_assist", b)))
	v.add_child(UI.toggle("Swap sticks", Game.settings["swap_sticks"], func(b): Game.set_setting("swap_sticks", b)))
	v.add_child(UI.toggle("Vibration", Game.settings["vibration"], func(b): Game.set_setting("vibration", b)))
	v.add_child(UI.toggle("Screen shake", Game.settings["shake"], func(b): Game.set_setting("shake", b)))
	v.add_child(UI.toggle("FPS counter", Game.settings["show_fps"], func(b): Game.set_setting("show_fps", b)))
	v.add_child(UI.button("Back", func():
		Audio.play("ui_back")
		root.queue_free()))
