class_name MoveButton
extends Control
## v2.3: the special move on the HUD (Moves). On a touch screen it is the third round button on the
## right edge, under the bomb and the keepsake and the biggest of the three (34 px, a 42 px hit
## area): the move's icon, a stepped cooldown ring (12 segments that light up as it recharges) and a
## bright flash when it is ready. With Swap sticks it moves to the left edge with the others. With
## keys or a pad it is a small icon (the same ring) under the keepsake, its key underneath ("SHIFT",
## "LT"). Flare Up below 5 minutes of wax shows a red ring (it would be refused).
##
## The press fires on the next physics step (Hud._physics_process asks take()); a drag that starts
## on the button becomes the aim stick, like the bomb's. Hud: one line each in _ready, _layout and
## _physics_process.

const BIG := 34.0            # touch: the button's size (the ring's outer diameter)
const SMALL := 30.0          # keys / pad: like the keepsake button
const GROW := 4.0            # the touch hit area reaches this far outside the button (42 px)
const SEGMENTS := 12
const GOLD := Color("#facb3e")
const CREAM := Color("#fdf7ed")
const DIM_RING := Color("#775c55")
const DISC := Color("#21141b")
const RIM := Color("#aa8d7a")
const RED := Color("#da4e38")

var hud: Node
var key_label: Label
var _touch := true
var _idx := -1                # the finger on the button
var _press_at := Vector2.ZERO
var _pending := false         # pressed since the last physics step
var _bump := 0.0
var _rings := {}              # radius -> segment -> Array[Vector2i] (cached pixel rings)
var _t := 0.0


func _init(h: Node) -> void:
	hud = h


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("fit_group", "buttons")
	key_label = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	key_label.set_meta("fit_group", "buttons")
	add_child(key_label)
	Controls.device_changed.connect(func(_d): _refresh())
	Game.settings_changed.connect(_refresh)
	_refresh()


func _player() -> Player:
	var w: Variant = hud.get("world")
	return w.player if w != null and is_instance_valid(w) else null


func _move_id() -> String:
	var p := _player()
	return Moves.for_candle(p.candle_id) if p else ""


func _refresh() -> void:
	_touch = Controls.touch_visible()
	key_label.text = "" if _touch else Controls.glyph("special")
	place()


## Lay out the right-hand (or, with Swap sticks, left-hand) stack: keepsake on top, the bomb, then
## this button, nearest the aiming thumb. Called from Hud._layout (after it placed the others).
func place() -> void:
	if hud == null or not hud.is_inside_tree():
		return
	var vs: Vector2 = hud.view_size()
	var ins: Vector2 = hud.safe_insets()
	var bomb: Control = hud.bomb_btn
	var keep: Control = hud.keep_btn
	if _touch:
		size = Vector2(BIG, BIG)
		var cx := bomb.position.x + bomb.size.x / 2.0   # one column with the bomb and the keepsake
		position = Vector2(roundf(cx - BIG / 2.0), bomb.position.y + bomb.size.y + 4.0)
		if Game.settings.get("swap_sticks", false):
			position.x = maxf(position.x, 1.0 + ins.x)
		else:
			position.x = minf(position.x, vs.x - BIG - 1.0 - ins.y)
	else:
		size = Vector2(SMALL, SMALL)
		position = Vector2(keep.position.x, keep.position.y + keep.size.y + 12.0)
	key_label.size = Vector2(size.x + 8.0, 10)
	key_label.position = Vector2(-4.0, size.y)
	visible = _move_id() != "" and Moves.enabled
	queue_redraw()


## Hud._physics_process: a touch / click press waiting to fire the move.
func take() -> bool:
	var was := _pending
	_pending = false
	return was


func bump() -> void:
	_bump = 0.12


func hit_rect() -> Rect2:
	return Rect2(position, size).grow(GROW if _touch else 2.0)


func _input(event: InputEvent) -> void:
	if not visible or hud == null:
		return
	var w: Variant = hud.get("world")
	if w == null or w.paused or w.finished or w.player == null:
		return
	if event is InputEventScreenTouch and Controls.touch_enabled():
		if event.pressed and _idx < 0 and _mine(event.position):
			_idx = event.index
			_press_at = event.position
			_pending = true
			bump()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _idx:
			_idx = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _idx and Controls.touch_enabled():
		if event.position.distance_to(_press_at) > 8.0:
			# the thumb slides off: it becomes the aim stick, like a drag that starts on the bomb
			_idx = -1
			if int(hud._r_idx) < 0 and not Game.settings.get("swap_sticks", false):
				hud._r_idx = event.index
				hud._r_origin = _press_at
				hud.stick_r.position = _press_at
				hud.stick_r.set_meta("knob", Vector2.ZERO)
				hud.stick_r.visible = true
			elif int(hud._l_idx) < 0 and Game.settings.get("swap_sticks", false):
				hud._l_idx = event.index
				hud._l_origin = _press_at
				hud.stick_l.position = _press_at
				hud.stick_l.set_meta("knob", Vector2.ZERO)
				hud.stick_l.visible = true
		else:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and hit_rect().has_point(event.position):
		hud._mouse_block = true   # the click is for the button, not a shot at the cursor
		_pending = true
		bump()
		get_viewport().set_input_as_handled()


## A touch at `pos` belongs to this button: inside its hit area and nearer its centre than the
## bomb's (the two hit areas touch).
func _mine(pos: Vector2) -> bool:
	if not hit_rect().has_point(pos):
		return false
	var bomb: Control = hud.bomb_btn
	if bomb.visible and Rect2(bomb.position, bomb.size).grow(4).has_point(pos):
		var mine_c := position + size / 2.0
		var bomb_c := bomb.position + bomb.size / 2.0
		return pos.distance_to(mine_c) < pos.distance_to(bomb_c)
	return true


func _process(dt: float) -> void:
	_t += dt
	_bump = maxf(0.0, _bump - dt)
	if visible:
		queue_redraw()


# ---------------------------------------------------------------- drawing

## The pixels of a ring (outer radius r, 2 px thick) split into SEGMENTS arcs with a 1 px gap.
func _ring(r: int) -> Array:
	if _rings.has(r):
		return _rings[r]
	var segs := []
	for i in SEGMENTS:
		segs.append([])
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := Vector2(x + 0.5, y + 0.5).length()
			if d < r - 2.0 or d >= r:
				continue
			# clockwise from 12 o'clock
			var a := fposmod(atan2(x + 0.5, -(y + 0.5)), TAU)
			var f := a / TAU * SEGMENTS
			var k := int(f)
			if f - k < 0.08 or f - k > 0.92:
				continue   # the gap between two segments
			segs[k].append(Vector2i(x, y))
	_rings[r] = segs
	return segs


func _draw() -> void:
	var p := _player()
	var id := _move_id()
	if p == null or id == "":
		return
	var m := Moves.of(p)
	var full := Moves.cooldown(id)
	var k := 1.0 - clampf(p.move_cd / full, 0.0, 1.0) if full > 0.0 else 1.0
	var ready := p.move_cd <= 0.0
	var refused := id == "flare" and p.wax < Moves.FLARE_MIN
	var r := int(size.x / 2.0)
	var c := Vector2(r, r)
	if m and m.denied > 0.0:
		c.x += 1.0 if int(_t * 40.0) % 2 == 0 else -1.0
	var sc := 0.9 if _bump > 0.0 else 1.0
	# the disc and its rim
	var disc_r := float(r - 3) * sc
	draw_circle(c, disc_r + 1.0, (GOLD if ready and not refused else RIM) if not refused else RED, true, -1.0, false)
	draw_circle(c, disc_r, DISC, true, -1.0, false)
	# the stepped ring: lit segments recharge clockwise from the top
	var lit := SEGMENTS if ready else int(floorf(k * SEGMENTS))
	var segs := _ring(r)
	for i in SEGMENTS:
		var col := DIM_RING
		if refused:
			col = RED if i % 2 == 0 else DIM_RING
		elif i < lit:
			col = GOLD if ready else CREAM
		for px in segs[i]:
			draw_rect(Rect2(c + Vector2(px), Vector2.ONE), col)
	# the ready flash: a cream ring opening out for 0.4 s
	if m and m.ready_flash > 0.0 and not refused:
		var step := int((0.4 - m.ready_flash) / 0.1)
		var fr := r - 1 + step * 2
		for seg in _ring(fr):
			for px in seg:
				draw_rect(Rect2(c + Vector2(px), Vector2.ONE), CREAM)
	# the icon
	var icon_path := Moves.icon(id)
	if Art.has(icon_path):
		var tex := Art.tex(icon_path)
		var a := 1.0 if ready and not refused else 0.45
		if ready and not refused:
			a = 0.85 + 0.15 * sin(_t * 6.0)
		draw_texture(tex, (c - tex.get_size() / 2.0).floor(), Color(1, 1, 1, a))
