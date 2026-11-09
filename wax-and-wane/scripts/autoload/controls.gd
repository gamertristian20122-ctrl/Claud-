extends Node
## Every input device in one place: the InputMap actions, the last device used (touch, keyboard,
## mouse or gamepad), the move/aim vectors the HUD feeds to Tallow, the pixel mouse cursors,
## keyboard/gamepad focus for menus and the desktop window (min size, fullscreen hotkeys).
##
## Gameplay reads hud.move_vec / hud.aim_vec; the HUD merges touch sticks with move_vector(),
## aim_vector() and the mouse. Menus get focus automatically when a key or the gamepad is used.

signal device_changed(device: String)
## LB/RB, Q/E or PageUp/PageDown in a menu: -1 or +1 (see set_page_handler).
signal page(dir: int)

const TOUCH := "touch"
const KEYS := "keyboard"
const MOUSE := "mouse"
const PAD := "gamepad"

const MOVE_DEADZONE := 0.22
const AIM_DEADZONE := 0.35
const TRIGGER_PRESS := 0.5
const BASE := Vector2i(384, 216)

var device := TOUCH
var _nav_ms := -1000
var _cursor_scale := 0
var _crosshair := false
var _modals: Array = []          # [{root, prev}] in the order they opened
var _page_handlers := {}         # menu root -> Callable(dir)
var _focus_t := 0.0
var _last_focus: Control
var _headless := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_setup_actions()
	device = TOUCH if OS.has_feature("mobile") else KEYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--device="):     # tours / testing: --device=touch|keyboard|mouse|gamepad
			device = a.get_slice("=", 1)
	# On desktop the mouse is a mouse (aim, click menus), not a fake finger.
	if not OS.has_feature("mobile"):
		Input.emulate_touch_from_mouse = "--touchmouse" in OS.get_cmdline_user_args()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_window().window_input.connect(_detect_device)
	Input.joy_connection_changed.connect(_on_joy_connection)
	get_viewport().size_changed.connect(_refresh_cursors)
	Game.settings_changed.connect(_refresh_cursors)
	if not _headless and OS.has_feature("pc"):
		DisplayServer.window_set_min_size(BASE * 2)
		_fit_window()
	_refresh_cursors()


# ---------------------------------------------------------------- actions

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.device = -1
	return e


func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = -1
	return e


func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e


func _add(action: String, events: Array, deadzone := 0.5) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	for e in events:
		if not InputMap.action_has_event(action, e):
			InputMap.action_add_event(action, e)


func _setup_actions() -> void:
	# movement: WASD, left stick, d-pad
	_add("move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)], 0.2)
	_add("move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)], 0.2)
	_add("move_up", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)], 0.2)
	_add("move_down", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)], 0.2)
	# shooting: arrow keys, right stick, face buttons (Y up, A down, X left, B right)
	_add("shoot_left", [_key(KEY_LEFT), _axis(JOY_AXIS_RIGHT_X, -1.0), _btn(JOY_BUTTON_X)], 0.3)
	_add("shoot_right", [_key(KEY_RIGHT), _axis(JOY_AXIS_RIGHT_X, 1.0), _btn(JOY_BUTTON_B)], 0.3)
	_add("shoot_up", [_key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0), _btn(JOY_BUTTON_Y)], 0.3)
	_add("shoot_down", [_key(KEY_DOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0), _btn(JOY_BUTTON_A)], 0.3)
	_add("bomb", [_key(KEY_E), _key(KEY_SPACE), _btn(JOY_BUTTON_RIGHT_SHOULDER),
		_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _mouse(MOUSE_BUTTON_RIGHT)], TRIGGER_PRESS)
	_add("keepsake", [_key(KEY_Q), _btn(JOY_BUTTON_LEFT_SHOULDER), _mouse(MOUSE_BUTTON_MIDDLE)], TRIGGER_PRESS)
	# v2.3: the candle's special move (Moves): Left Shift or F, a mouse thumb button, LT
	var lshift := _key(KEY_SHIFT)
	lshift.location = KEY_LOCATION_LEFT
	_add("special", [lshift, _key(KEY_F), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0),
		_mouse(MOUSE_BUTTON_XBUTTON1), _mouse(MOUSE_BUTTON_XBUTTON2)], TRIGGER_PRESS)
	_add("pause", [_key(KEY_ESCAPE), _key(KEY_P), _btn(JOY_BUTTON_START), _btn(JOY_BUTTON_BACK)])
	# menus: WASD and the d-pad navigate too (the left stick is read in _menu_stick, with a
	# repeat delay, so one flick moves one step); B / Esc go back
	_add("ui_up", [_key(KEY_W), _btn(JOY_BUTTON_DPAD_UP)])
	_add("ui_down", [_key(KEY_S), _btn(JOY_BUTTON_DPAD_DOWN)])
	_add("ui_left", [_key(KEY_A), _btn(JOY_BUTTON_DPAD_LEFT)])
	_add("ui_right", [_key(KEY_D), _btn(JOY_BUTTON_DPAD_RIGHT)])
	_add("ui_accept", [_btn(JOY_BUTTON_A)])
	_add("ui_cancel", [_btn(JOY_BUTTON_B)])
	_add("ui_page_prev", [_btn(JOY_BUTTON_LEFT_SHOULDER), _key(KEY_Q), _key(KEY_PAGEUP)])
	_add("ui_page_next", [_btn(JOY_BUTTON_RIGHT_SHOULDER), _key(KEY_E), _key(KEY_PAGEDOWN)])
	for a in BINDABLE:
		_defaults[a] = InputMap.action_get_events(a).map(func(e): return e.duplicate())
	apply_binds()


## WASD / left stick / d-pad, circular deadzone, length <= 1.
func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down", MOVE_DEADZONE)


## Arrow keys / right stick / face buttons: a unit direction (fire) or zero.
func aim_vector() -> Vector2:
	var v := Input.get_vector("shoot_left", "shoot_right", "shoot_up", "shoot_down", AIM_DEADZONE)
	return v.normalized() if v.length() > 0.0 else Vector2.ZERO


# ---------------------------------------------------------------- devices

## Every event passes here before any node sees it (nodes may consume it), so the last device is
## always right.
func _detect_device(event: InputEvent) -> void:
	var dev := ""
	if event is InputEventKey:
		if event.pressed:
			dev = KEYS
	elif event is InputEventJoypadButton:
		if event.pressed:
			dev = PAD
	elif event is InputEventJoypadMotion:
		var trig: bool = event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT
		if (trig and event.axis_value > 0.6) or (not trig and absf(event.axis_value) > 0.6):
			dev = PAD
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		dev = MOUSE if event.device == InputEvent.DEVICE_ID_EMULATION else TOUCH
	elif event is InputEventMouseButton:
		if event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed:
			dev = MOUSE
	elif event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION and event.relative.length() > 3.0:
			dev = MOUSE
	if dev != "" and dev != device:
		set_device(dev, false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_hotkeys(event)
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") \
			or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		_nav_ms = Time.get_ticks_msec()
		# the first key/gamepad press in a menu only shows where the focus is
		if uses_buttons() and _ensure_focus():
			get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("ui_accept")) and uses_buttons() and _ensure_focus():
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_page_prev") or event.is_action_pressed("ui_page_next"):
		var dir := -1 if event.is_action_pressed("ui_page_prev") else 1
		var r := menu_root()
		if r and _page_handlers.has(r) and (_page_handlers[r] as Callable).is_valid():
			(_page_handlers[r] as Callable).call(dir)
			Audio.play("ui_move")
			get_viewport().set_input_as_handled()
			page.emit(dir)
		return
	if event.is_action_pressed("ui_cancel"):
		# the game screen handles its own pause / back; every other screen goes back here
		var cur := _screen()
		if cur and cur.name != "Game" and cur.has_method("on_back"):
			Audio.play("ui_back")
			cur.on_back()
			get_viewport().set_input_as_handled()


func _hotkeys(e: InputEventKey) -> void:
	if e.echo or not OS.has_feature("pc"):
		return
	if e.physical_keycode == KEY_F11 or (e.physical_keycode == KEY_ENTER and e.alt_pressed):
		Game.set_setting("fullscreen", not Game.settings.get("fullscreen", false))
		get_viewport().set_input_as_handled()


## `show_focus`: place / reveal menu focus now (false when the press itself will do it).
func set_device(dev: String, show_focus := true) -> void:
	if dev == device:
		return
	device = dev
	if not _headless and OS.has_feature("pc"):
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if dev == PAD else Input.MOUSE_MODE_VISIBLE
	device_changed.emit(dev)
	if uses_buttons():
		if show_focus:
			_ensure_focus()
	else:
		# pointer players never see the keyboard frame (the button stays focused, quietly)
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.grab_focus(true)


## A gamepad that drops out mid-run pauses the game (the Steam Deck way).
func _on_joy_connection(_pad: int, connected: bool) -> void:
	if connected or device != PAD:
		return
	var cur := _screen()
	if cur and cur.name == "Game" and not cur.paused and not cur.finished and cur.has_method("toggle_pause"):
		cur.toggle_pause()


## True while the player uses keys or a gamepad (menus show a focus frame).
func uses_buttons() -> bool:
	return device == KEYS or device == PAD


## True for a desktop keyboard + mouse player.
func uses_kbm() -> bool:
	return device == KEYS or device == MOUSE


## Touch controls setting: "auto" (shown after a touch), "on", "off".
func touch_mode() -> String:
	return str(Game.settings.get("touch_controls", "auto"))


func touch_enabled() -> bool:
	return touch_mode() != "off"


func touch_visible() -> bool:
	var m := touch_mode()
	return m == "on" or (m == "auto" and device == TOUCH)


## Short name of the key/button for an action on the current device ("Q", "LB" ...).
func glyph(action: String) -> String:
	var pad := device == PAD
	match action:
		"bomb": return bound_glyph("bomb", pad) if pad or device != TOUCH else "BOMB"
		"keepsake": return bound_glyph("keepsake", pad)
		"special": return bound_glyph("special", pad) if pad or device != TOUCH else L.t("SPECIAL")
		"pause": return "START" if pad else "ESC"
		"move": return "Left stick" if pad else ("WASD" if device != TOUCH else thumb(false))
		"aim":
			if pad:
				return "Right stick"
			if device == TOUCH:
				return thumb(true)
			return "Arrows / mouse" if Game.settings.get("mouse_aim", true) else "Arrows"
	return action


## Touch: which thumb moves / aims ("Settings > Controls > Swap sticks" trades them, UX-08).
func thumb(aim: bool) -> String:
	return "Left thumb" if aim == bool(Game.settings.get("swap_sticks", false)) else "Right thumb"


## The side of the screen the bomb and keepsake buttons are on (under the aiming thumb).
func button_side() -> String:
	return "left" if bool(Game.settings.get("swap_sticks", false)) else "right"


## The one-line controls reminder shown at the start of a run.
func controls_hint(with_wax := true) -> String:
	var t := ""
	match device:
		TOUCH: t = "%s: move   %s: aim + shoot   Bomb: %s button" % [thumb(false), thumb(true), button_side()]
		PAD: t = "Left stick: move    Right stick: shoot    %s: bomb" % glyph("bomb")
		_: t = "WASD: move    %s: shoot    %s: bomb" % [glyph("aim"), glyph("bomb")]
	if device != TOUCH and not with_wax:   # v2.3: the long first-run line names the special move too
		t += "    " + L.t("{key}: {move}", {"key": glyph("special"), "move": _move_word()})
	return t + ("    Wax = health = time" if with_wax else "")


## v2.3: one line on the candle's special move (the first rooms of a candle's first runs, Moves).
func special_hint(move_id: String) -> String:
	if not Moves.LIST.has(move_id):
		return ""
	if device == TOUCH:
		return L.t("{move}: tap the big round button. {line}", {"move": Moves.name_of(move_id), "line": Moves.line_of(move_id)})
	return L.t("{move}: press {key}. {line}", {"move": Moves.name_of(move_id), "key": glyph("special"), "line": Moves.line_of(move_id)})


## The candle's move in the run on screen ("special" on the title and elsewhere).
func _move_word() -> String:
	var cur := _screen()
	var p: Variant = cur.get("player") if cur else null
	if p != null and is_instance_valid(p):
		var id := Moves.for_candle(str(p.candle_id))
		if id != "":
			return Moves.name_of(id)
	return L.t("special")


# ---------------------------------------------------------------- rebinding (v2.3, Settings > Keys)

## The button actions a player may move to another key or pad button (Settings > Keys). Their
## defaults are kept; Game.settings["binds"] = {action: {"key": physical keycode, "loc": location,
## "pad": "b<button>" | "a<axis>"}} replaces the keyboard keys / the pad input of that action.
const BINDABLE := ["special", "bomb", "keepsake"]
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_START: "START", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "UP", JOY_BUTTON_DPAD_DOWN: "DOWN", JOY_BUTTON_DPAD_LEFT: "LEFT",
	JOY_BUTTON_DPAD_RIGHT: "RIGHT"}
var _defaults := {}


## Put every bindable action back to its defaults, then lay the saved binds over them.
func apply_binds() -> void:
	var binds: Dictionary = Game.settings.get("binds", {})
	for a in BINDABLE:
		if not _defaults.has(a):
			continue
		InputMap.action_erase_events(a)
		var b: Dictionary = binds.get(a, {})
		for e in _defaults[a]:
			if b.has("key") and e is InputEventKey:
				continue
			if b.has("pad") and (e is InputEventJoypadButton or e is InputEventJoypadMotion):
				continue
			InputMap.action_add_event(a, e)
		if b.has("key"):
			var k := _key(int(b["key"]) as Key)
			k.location = int(b.get("loc", KEY_LOCATION_UNSPECIFIED)) as KeyLocation
			InputMap.action_add_event(a, k)
		if b.has("pad"):
			var pv := str(b["pad"])
			if pv.begins_with("a"):
				InputMap.action_add_event(a, _axis(int(pv.substr(1)) as JoyAxis, 1.0))
			else:
				InputMap.action_add_event(a, _btn(int(pv.substr(1)) as JoyButton))


## Bind `action` to the key / pad input in `event` (Settings > Keys). Returns "" when done, else
## the action that already uses it (nothing changes then).
func rebind(action: String, event: InputEvent) -> String:
	var binds: Dictionary = (Game.settings.get("binds", {}) as Dictionary).duplicate(true)
	var b: Dictionary = binds.get(action, {})
	for other in InputMap.get_actions():
		if other == action or str(other).begins_with("ui_"):
			continue
		for e in InputMap.action_get_events(other):
			if _same_input(e, event):
				return str(other)
	if event is InputEventKey:
		b["key"] = int((event as InputEventKey).physical_keycode)
		b["loc"] = int((event as InputEventKey).location)
	elif event is InputEventJoypadButton:
		b["pad"] = "b%d" % int((event as InputEventJoypadButton).button_index)
	elif event is InputEventJoypadMotion:
		b["pad"] = "a%d" % int((event as InputEventJoypadMotion).axis)
	else:
		return action
	binds[action] = b
	Game.set_setting("binds", binds)
	apply_binds()
	return ""


## The same key (by physical key; Left / Right only when both say), pad button or pad axis.
## Modifier flags are ignored: pressing Shift reports itself as held, the map's Shift does not.
static func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var ca := ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode
		var cb := kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode
		if ca != cb:
			return false
		return ka.location == KEY_LOCATION_UNSPECIFIED or kb.location == KEY_LOCATION_UNSPECIFIED or ka.location == kb.location
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis \
			and signf((a as InputEventJoypadMotion).axis_value) == signf((b as InputEventJoypadMotion).axis_value)
	return false


func reset_binds() -> void:
	Game.set_setting("binds", {})
	apply_binds()


## The key (keyboard) or button (pad) bound to `action` now, as a short label: "SHIFT", "E", "LT".
func bound_glyph(action: String, pad: bool) -> String:
	for e in InputMap.action_get_events(action):
		if pad and e is InputEventJoypadButton:
			return PAD_NAMES.get((e as InputEventJoypadButton).button_index, "B%d" % (e as InputEventJoypadButton).button_index)
		if pad and e is InputEventJoypadMotion:
			match (e as InputEventJoypadMotion).axis:
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
			return "AXIS %d" % (e as InputEventJoypadMotion).axis
		if not pad and e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if not _headless and k.physical_keycode != KEY_NONE:
				code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
			return OS.get_keycode_string(code).to_upper()
	return "-"


func intro_line() -> String:
	match device:
		TOUCH: return "%s moves. %s aims and fires. Bomb: the %s button." % [thumb(false), thumb(true), button_side()]
		PAD: return "Left stick moves. Right stick aims and fires."
	return "WASD moves. The arrow keys%s fire." % (" or the mouse" if Game.settings.get("mouse_aim", true) else "")


func keepsake_hint() -> String:
	if device == TOUCH:
		return "Keepsake: clear rooms to fill its pips, then tap its button"
	return "Keepsake: clear rooms to fill its pips, then press %s" % glyph("keepsake")


# ---------------------------------------------------------------- cursors

## Gameplay asks for the crosshair while a run is live and unpaused.
func want_crosshair(on: bool) -> void:
	on = on and Game.settings.get("mouse_aim", true)
	if on == _crosshair:
		return
	_crosshair = on
	if not _headless:
		Input.set_default_cursor_shape(Input.CURSOR_CROSS if on else Input.CURSOR_ARROW)


## The game's integer pixel scale for the current window (cursors match the art's pixel size).
func pixel_scale() -> int:
	var win := DisplayServer.window_get_size()
	return maxi(1, mini(win.x / BASE.x, win.y / BASE.y))


func _refresh_cursors() -> void:
	if _headless or not DisplayServer.has_feature(DisplayServer.FEATURE_CUSTOM_CURSOR_SHAPE) or OS.has_feature("mobile"):
		return
	var k := mini(pixel_scale(), 6)
	if k == _cursor_scale:
		return
	_cursor_scale = k
	_set_cursor("ui/cursor_arrow", Input.CURSOR_ARROW, Vector2.ZERO, k)
	_set_cursor("ui/cursor_arrow", Input.CURSOR_POINTING_HAND, Vector2.ZERO, k)
	_set_cursor("ui/cursor_cross", Input.CURSOR_CROSS, Vector2(4, 4), k)


func _set_cursor(path: String, shape: Input.CursorShape, hot: Vector2, k: int) -> void:
	if not Art.has(path):
		return
	var img := Art.tex(path).get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	# a centred hotspot sits in the middle of its (scaled) pixel
	var centre := floorf(k / 2.0) if hot != Vector2.ZERO else 0.0
	Input.set_custom_mouse_cursor(img, shape, hot * k + Vector2(centre, centre))


# ---------------------------------------------------------------- window

## Never open a window bigger than the screen (e.g. a Steam Deck in desktop mode): pick the largest
## whole multiple of 384x216 that fits, up to the 1536x864 default.
func _fit_window() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var scr := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr).size
	if usable.x <= 0 or usable.y <= 0:
		return
	var win := DisplayServer.window_get_size()
	if win.x <= usable.x and win.y <= usable.y:
		return
	var k := maxi(1, mini(usable.x / BASE.x, (usable.y - 40) / BASE.y))
	var size := BASE * k
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect(scr).position + (usable - size) / 2)


# ---------------------------------------------------------------- menus and focus

## The screen main.gd shows, or null while main.goto() is swapping it (the old one is queued for
## deletion or already freed: Save & quit / Give up close their modals right then).
func _screen() -> Node:
	var main := get_tree().current_scene
	if main == null or not ("current" in main):
		return null
	var cur: Variant = main.get("current")
	if cur == null or not is_instance_valid(cur) or (cur as Node).is_queued_for_deletion():
		return null
	return cur


## Called by UI.modal: remembers what had focus so it comes back when the modal closes.
## The deferred calls capture instance ids, not the nodes: a modal can be freed (with its screen)
## before they run.
func on_modal_opened(root: Control) -> void:
	var prev := get_viewport().gui_get_focus_owner()
	_modals.append({"root": root, "prev": prev})
	root.tree_exiting.connect(_on_modal_closed.bind(root))
	var rid := root.get_instance_id()
	(func():
		var r := instance_from_id(rid) as Control
		if r and r.is_inside_tree() and not r.is_queued_for_deletion():
			focus_first(r)).call_deferred()


func _on_modal_closed(root: Control) -> void:
	var prev_id := 0
	for i in range(_modals.size() - 1, -1, -1):
		if _modals[i]["root"] == root:
			var p: Variant = _modals[i]["prev"]
			if p != null and is_instance_valid(p):
				prev_id = (p as Object).get_instance_id()
			_modals.remove_at(i)
			break
	_page_handlers.erase(root)
	(func():
		var top := menu_root()
		var prev := instance_from_id(prev_id) as Control if prev_id != 0 else null
		if prev and prev.is_visible_in_tree() and not prev.is_queued_for_deletion() \
				and (top == null or top.is_ancestor_of(prev)):
			prev.grab_focus(not uses_buttons())
		elif top:
			focus_first(top)).call_deferred()


func _top_modal() -> Control:
	for i in range(_modals.size() - 1, -1, -1):
		var r: Variant = _modals[i]["root"]
		if is_instance_valid(r) and (r as Control).is_inside_tree() and (r as Control).is_visible_in_tree():
			return r
	return null


## The menu that keyboard/gamepad focus belongs to right now (the top modal, or the screen's
## own menu on the title / results screens), or null during play.
func menu_root() -> Control:
	var top := _top_modal()
	if top:
		return top
	var cur := _screen()
	if cur == null or cur.name == "Game":
		return null
	if cur is Control:
		return cur
	var r: Variant = cur.get("root")
	return r if r is Control else null


## LB/RB (and Q/E, PgUp/PgDn) call cb.call(dir) while `root` is the active menu.
func set_page_handler(root: Control, cb: Callable) -> void:
	var fresh := not _page_handlers.has(root)
	_page_handlers[root] = cb
	if fresh:
		root.tree_exiting.connect(func(): _page_handlers.erase(root), CONNECT_ONE_SHOT)


## Give focus to the menu's default button (meta "default_focus") or its first enabled Button.
func focus_first(root: Control) -> bool:
	if root == null:
		return false
	var best := _find_focus(root, true)
	if best == null:
		best = _find_focus(root, false)
	if best == null:
		return false
	best.grab_focus(not uses_buttons())
	_last_focus = best
	return true


func _find_focus(n: Node, want_default: bool) -> Control:
	for c in n.get_children():
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if c is Control:
			var ctl := c as Control
			if ctl.focus_mode != Control.FOCUS_NONE and ctl is Button and not (ctl as BaseButton).disabled:
				if not want_default or ctl.get_meta("default_focus", false):
					return ctl
		var deep := _find_focus(c, want_default)
		if deep:
			return deep
	return null


## Makes sure a key / gamepad press has something to act on. Returns true if focus was placed now.
func _ensure_focus() -> bool:
	var root := menu_root()
	if root == null:
		return false
	var f := get_viewport().gui_get_focus_owner()
	if f and f.is_visible_in_tree() and (root == f or root.is_ancestor_of(f)):
		if not f.has_focus(true):
			# focused by a click/tap (hidden): show it now without moving
			f.grab_focus()
			return true
		return false
	return focus_first(root)


func _on_focus_changed(c: Control) -> void:
	# keep focus inside the top modal (gamepad navigation must not reach the menu behind it)
	var top := _top_modal()
	if top and c and not top.is_ancestor_of(c) and c != top:
		var back := _last_focus if is_instance_valid(_last_focus) and top.is_ancestor_of(_last_focus) else null
		if back:
			back.grab_focus.call_deferred()
		else:
			focus_first.call_deferred(top)
		return
	_last_focus = c
	if Time.get_ticks_msec() - _nav_ms < 200:
		Audio.play("ui_move")


var _stick_dir := Vector2i.ZERO
var _stick_t := 0.0


## The left stick steps through menus: one step per flick, then repeats while held.
func _menu_stick(dt: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty() or menu_root() == null:
		_stick_dir = Vector2i.ZERO
		return
	var v := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_X), Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_Y))
	var d := Vector2i.ZERO
	if v.length() > 0.6:
		d = Vector2i(int(signf(v.x)), 0) if absf(v.x) > absf(v.y) else Vector2i(0, int(signf(v.y)))
	if d == Vector2i.ZERO:
		_stick_dir = Vector2i.ZERO
		return
	if d != _stick_dir:
		_stick_dir = d
		_stick_t = 0.42
	else:
		_stick_t -= dt
		if _stick_t > 0.0:
			return
		_stick_t = 0.13
	var act: String = {Vector2i.UP: "ui_up", Vector2i.DOWN: "ui_down", Vector2i.LEFT: "ui_left", Vector2i.RIGHT: "ui_right"}[d]
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = act
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _process(dt: float) -> void:
	_menu_stick(dt)
	_focus_t -= dt
	if _focus_t <= 0.0:
		_focus_t = 0.25
		if uses_buttons():
			var root := menu_root()
			var f := get_viewport().gui_get_focus_owner()
			if root and (f == null or not f.is_visible_in_tree() or not (root == f or root.is_ancestor_of(f))):
				focus_first(root)


# ---------------------------------------------------------------- quitting (desktop)

## Title screen "back": phones close the app at once; desktops ask first.
func quit_prompt(parent: Control) -> void:
	if OS.has_feature("mobile"):
		get_tree().quit()
		return
	for c in parent.get_children():
		if c.get_meta("quit_prompt", false):
			return
	var m := UI.modal(parent, "BLOW OUT THE CANDLE?")
	var r: Control = m[0]
	r.set_meta("quit_prompt", true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var stay := UI.button("Keep burning", func(): r.queue_free(), 100)
	stay.set_meta("default_focus", true)
	row.add_child(stay)
	row.add_child(UI.button("Quit", func():
		RunSave.flush()
		get_tree().quit(), 80))
	(m[1] as VBoxContainer).add_child(row)
