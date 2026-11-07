class_name BossCard
extends CanvasLayer
## The boss "versus" card (~1.8 s): the screen dims, two slanted bands slide in from opposite sides,
## the guardian stands large (nearest x3) with its name, Tallow small on the other band showing the
## time left. The world is paused while it shows; any tap, key or pad button skips it.

const IN_T := 0.24
const OUT_AT := 1.55
const END_T := 1.8
const INK := Color("#21141b")

var juice: Node
var world: Node
var kind := ""
var title := ""
var _t := 0.0
var _out := false
var _vs := Vector2(480, 216)
var _bands: Node2D
var _boss: AnimatedSprite2D
var _hero: Node2D
var _name: Label
var _sub: Label
var _who: Label
var _dim: ColorRect
var _landed := false
var _shake := 0.0
## speed streaks inside the bands: [band, depth 0..1, x, length, speed]
var _streaks: Array = []


func setup(j: Node, k: String, t: String) -> void:
	juice = j
	world = j.world
	kind = k
	title = t


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vs = get_viewport().get_visible_rect().size
	get_tree().paused = true
	Audio.play("boss_sting")
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.015, 0.02, 0.0)
	_dim.size = _vs
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_bands = Node2D.new()
	_bands.draw.connect(_draw_bands)
	add_child(_bands)
	# the guardian, large
	var d: Dictionary = Enemy.DEFS.get(kind, {})
	_boss = AnimatedSprite2D.new()
	var sname: String = d.get("sprite", kind)
	_boss.sprite_frames = Art.creature(sname)
	_boss.play("idle")
	_boss.centered = false
	var tex: Texture2D = _boss.sprite_frames.get_frame_texture("idle", 0)
	var tsz := tex.get_size() if tex else Vector2(32, 36)
	_boss.offset = Vector2(-tsz.x / 2.0, -tsz.y)
	_boss.scale = Vector2(3, 3)
	_boss.flip_h = true
	_boss.modulate = d.get("tint", Color.WHITE)
	_boss.position = Vector2(_boss_x(), _band_bottom(0, _boss_x()) + 2)
	add_child(_boss)
	# Tallow, small, on the other band
	_hero = Player.new()
	_hero.world = null
	add_child(_hero)
	_hero.set_physics_process(false)
	var p: Node = world.get("player")
	if p:
		_hero.apply_candle(p.candle_id)
		_hero.wax = maxf(p.wax, 12.0)
		_hero.rites = p.rites.duplicate()
		if p.blue:
			_hero.set_blue(true)
	_hero.light.enabled = false
	_hero.glow.enabled = false
	_hero.scale = Vector2(2, 2)
	_hero.position = Vector2(_vs.x * 0.16, _band_bottom(1, _vs.x * 0.16) - 3)
	# words
	_name = UI.label(title, 16, UI.CREAM)
	_name.position = Vector2(_vs.x * 0.07, 50)
	add_child(_name)
	var fl: Dictionary = world.FLOORS.get(world.floor_num, {})
	_sub = UI.label("Guardian of %s" % fl.get("name", "the house"), 8, Color("#d3bfa9"))
	_sub.position = Vector2(_vs.x * 0.07 + 2, 70)
	add_child(_sub)
	var who := "TALLOW"
	if p:
		who = str(Candles.def_of(p.candle_id).get("name", "Tallow")).to_upper()
	_who = UI.label("%s   %s" % [who, Game.clock_text(world.clock_minutes()) if world.has_method("clock_minutes") else ""], 8, UI.GOLD)
	_who.position = Vector2(_vs.x * 0.16 + 26, _band_top(1, _vs.x * 0.16 + 26) + 14)
	add_child(_who)
	for i in 14:
		var b := i % 2
		_streaks.append([b, randf_range(0.12, 0.88), randf() * _vs.x, randf_range(18, 60), randf_range(160, 320)])
	_apply(0.0)


func _boss_x() -> float:
	return _vs.x * 0.7


## Band 0 (the guardian's) runs high and slants up to the right; band 1 (Tallow's) runs low.
func _band_top(b: int, x: float) -> float:
	var k := x / _vs.x
	return lerpf(30.0, 12.0, k) if b == 0 else lerpf(150.0, 136.0, k)


func _band_bottom(b: int, x: float) -> float:
	var k := x / _vs.x
	return lerpf(126.0, 108.0, k) if b == 0 else lerpf(192.0, 178.0, k)


func _slide(b: int) -> float:
	# 0 = in place; slides in from the right (band 0) / left (band 1), out the other way
	var w := _vs.x + 40.0
	if not _out:
		var k := clampf(_t / IN_T, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		return (1.0 - e) * w * (1.0 if b == 0 else -1.0)
	var k2 := clampf((_t - OUT_AT) / (END_T - OUT_AT), 0.0, 1.0)
	return k2 * k2 * w * (-1.0 if b == 0 else 1.0)


func _apply(dt: float) -> void:
	var s0 := _slide(0)
	var s1 := _slide(1)
	_bands.position = Vector2.ZERO
	for st in _streaks:
		# guardian streaks run left, Tallow's run right
		st[2] = wrapf(st[2] + (-1.0 if st[0] == 0 else 1.0) * st[4] * dt, -80.0, _vs.x + 20.0)
	_bands.queue_redraw()
	var a := clampf(_t / 0.15, 0.0, 1.0) if not _out else 1.0 - clampf((_t - OUT_AT) / (END_T - OUT_AT), 0.0, 1.0)
	_dim.color.a = 0.72 * a
	var bx := _boss_x()
	# the guardian lags its band a little, then lands
	var lag := s0 * 1.25 if not _out else s0
	_boss.position = Vector2(round(bx + lag), round(_band_bottom(0, bx) + 2))
	_name.position.x = round(_vs.x * 0.07 + s0 * 0.85)
	_sub.position.x = round(_vs.x * 0.07 + 2 + s0 * 0.95)
	_hero.position.x = round(_vs.x * 0.16 + s1)
	_who.position.x = round(_vs.x * 0.16 + 26 + s1 * 1.1)
	_name.visible = _t > 0.12
	_sub.visible = _t > 0.2
	if not _landed and _t >= IN_T * 1.1:
		_landed = true
		_shake = 3.0
		_boss.modulate = Color(4, 4, 4, 1)
		Game.vibrate(40)
	elif _landed and _t > IN_T * 1.1 + 0.06:
		var d: Dictionary = Enemy.DEFS.get(kind, {})
		_boss.modulate = d.get("tint", Color.WHITE)
	if _shake > 0.0 and Juice.shake_scale() > 0.0:
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round() * Juice.shake_scale()
	else:
		offset = Vector2.ZERO


func _draw_bands() -> void:
	var s0 := _slide(0)
	var s1 := _slide(1)
	var w := _vs.x
	# guardian band: dark red with a bright lower edge
	_band(0, s0, Color("#62232f"), Color("#9f294e"), Color("#da4e38"))
	# Tallow's band: night blue with a warm candle-light edge
	_band(1, s1, Color("#2a2a3a"), Color("#314152"), Color("#ee8e2e"))
	for st in _streaks:
		var b: int = st[0]
		var sx := s0 if b == 0 else s1
		var x0: float = st[2] + sx
		var x1: float = x0 + st[3]
		var y0 := roundf(lerpf(_band_top(b, x0) + 3.0, _band_bottom(b, x0) - 4.0, st[1]))
		var y1 := roundf(lerpf(_band_top(b, x1) + 3.0, _band_bottom(b, x1) - 4.0, st[1]))
		_bands.draw_line(Vector2(x0, y0), Vector2(x1, y1), Color("#9f294e") if b == 0 else Color("#314152"), 1.0)
	# a thin ember line between them (where they cross the screen)
	var y0 := lerpf(134.0, 118.0, 0.0)
	var y1 := lerpf(134.0, 118.0, 1.0)
	if not _out and _t > IN_T:
		var k := clampf((_t - IN_T) / 0.2, 0.0, 1.0)
		_bands.draw_line(Vector2(0, y0), Vector2(w * k, lerpf(y0, y1, k)), Color("#8f4029"), 1.0)


func _band(b: int, sx: float, fill: Color, hi: Color, edge: Color) -> void:
	var w := _vs.x
	var pts := PackedVector2Array([
		Vector2(sx - 20, _band_top(b, -20)), Vector2(sx + w + 20, _band_top(b, w + 20)),
		Vector2(sx + w + 20, _band_bottom(b, w + 20)), Vector2(sx - 20, _band_bottom(b, -20))])
	_bands.draw_colored_polygon(pts, fill)
	# 1 px highlight under the top edge, 2 px glowing lower edge, ink outline
	_bands.draw_line(Vector2(sx - 20, _band_top(b, -20) + 1), Vector2(sx + w + 20, _band_top(b, w + 20) + 1), hi, 1.0)
	_bands.draw_line(Vector2(sx - 20, _band_top(b, -20)), Vector2(sx + w + 20, _band_top(b, w + 20)), INK, 1.0)
	_bands.draw_line(Vector2(sx - 20, _band_bottom(b, -20) - 2), Vector2(sx + w + 20, _band_bottom(b, w + 20) - 2), edge, 2.0)
	_bands.draw_line(Vector2(sx - 20, _band_bottom(b, -20)), Vector2(sx + w + 20, _band_bottom(b, w + 20)), INK, 1.0)


func _process(dt: float) -> void:
	if world.paused:
		# the pause menu is open: hide and wait
		visible = false
		return
	visible = true
	get_tree().paused = true
	_t += dt
	_shake = move_toward(_shake, 0.0, dt * 14.0)
	if _t >= OUT_AT:
		_out = true
	_apply(dt)
	if _t >= END_T:
		_finish()


func _input(event: InputEvent) -> void:
	if world.paused or _t < 0.15:
		return
	var press := false
	if event is InputEventKey:
		press = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		press = event.pressed
	if press:
		get_viewport().set_input_as_handled()
		if _t < OUT_AT:
			_t = OUT_AT
			_out = true


func _finish() -> void:
	set_process(false)
	set_process_input(false)
	if not world.paused:
		get_tree().paused = false
	if world.get("hud") and world.hud.has_method("release_sticks"):
		world.hud.release_sticks()
	juice.card_done()
	queue_free()
