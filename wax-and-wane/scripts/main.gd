class_name Main
extends Node
## Root: owns the current screen, the paper-burn screen transitions, the Android back button and the FPS overlay.

const SCREENS := {
	"title": "res://scripts/ui/title.gd",
	"game": "res://scripts/game/world.gd",
	"results": "res://scripts/ui/results.gd",
}

var current: Node
var _fade: ColorRect
var _burn: ShaderMaterial
var _fps: Label
var _busy := false
var autotest: Node


func _ready() -> void:
	UI.install()   # v2.6: the UI kit's Theme under every Control (scripts/ui/ui.gd)
	get_tree().set_auto_accept_quit(false)
	# physics ticks at a steady 60 Hz on every screen (project.godot [physics]); following a 90/120 Hz
	# display used to double its CPU cost on fast phones for no gameplay gain (QA-17)
	get_tree().set_quit_on_go_back(false)
	var top := CanvasLayer.new()
	top.layer = 100
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	_fade = ColorRect.new()
	_fade.color = Color(0.035, 0.027, 0.035, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# screen changes burn like paper: a glowing ember edge eats the old screen, then the dark burns away
	_burn = Juice.burn_material()
	_fade.material = _burn
	top.add_child(_fade)
	_fps = UI.label("", 8)
	_fps.position = Vector2(2, 200)
	top.add_child(_fps)
	Game.settings_changed.connect(_on_settings)
	_on_settings()
	var args := OS.get_cmdline_user_args()
	if "--checkscripts" in args:
		_check_scripts("res://scripts")
		get_tree().quit()
		return
	if "--checkrooms" in args:   # validate every room layout (scripts/game/room_templates.gd)
		get_tree().quit(1 if RoomTemplates.validate() + RoomDecor.check_dressing() + AreaGimmicks.check() > 0 else 0)
		return
	if "--autotest" in args:
		autotest = load("res://scripts/autotest.gd").new()
		add_child(autotest)
	goto("title")


func _check_scripts(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var sc: GDScript = load(dir + "/" + f)
			print("[check] ", dir + "/" + f, " ok" if sc and sc.can_instantiate() else " FAILED")
	for d in DirAccess.get_directories_at(dir):
		_check_scripts(dir + "/" + d)


func _on_settings() -> void:
	_fps.visible = Game.settings["show_fps"]


func _process(_dt: float) -> void:
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func goto(screen: String, params := {}) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var calm := UI.calm()   # Settings > Reduce motion: a plain short fade instead of the paper burn
	_fade.material = null if calm else _burn
	Juice.burn_prepare(_burn, false, _fade.size)
	tw.tween_property(_fade, "color:a", 1.0, (0.15 if calm else 0.42) if current else 0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = Game.base_time_scale
	if current:
		current.queue_free()
		await get_tree().process_frame
	var script: GDScript = load(SCREENS[screen])
	current = script.new()
	current.name = screen.capitalize()
	if current.has_method("setup"):
		current.setup(params)
	add_child(current)
	move_child(current, 0)
	var tw2 := create_tween()
	tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	Juice.burn_prepare(_burn, true, _fade.size)
	tw2.tween_property(_fade, "color:a", 0.0, 0.15 if calm else 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current and current.has_method("on_back"):
			current.on_back()
		elif what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if current and current.has_method("on_focus_lost"):
			current.on_focus_lost()
