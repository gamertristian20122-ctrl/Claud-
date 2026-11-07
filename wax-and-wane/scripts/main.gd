class_name Main
extends Node
## Root: owns the current screen, fade transitions, the Android back button and the FPS overlay.

const SCREENS := {
	"title": "res://scripts/ui/title.gd",
	"game": "res://scripts/game/world.gd",
	"results": "res://scripts/ui/results.gd",
}

var current: Node
var _fade: ColorRect
var _fps: Label
var _busy := false
var autotest: Node


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	# match physics to the display (90/120 Hz phones) so motion is smooth
	var hz := roundi(DisplayServer.screen_get_refresh_rate(60.0))
	Engine.physics_ticks_per_second = clampi(hz, 60, 120)
	get_tree().set_quit_on_go_back(false)
	var top := CanvasLayer.new()
	top.layer = 100
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	_fade = ColorRect.new()
	_fade.color = Color(0.035, 0.027, 0.035, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	tw.tween_property(_fade, "color:a", 1.0, 0.3 if current else 0.0)
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
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
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
