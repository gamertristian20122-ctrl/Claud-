class_name MoveFx
extends Node2D
## World-space effects of the special moves (Moves), one per world in its fx_layer: the Sparkler's
## flying sparks (they hit, knock back and pop enemy shots on the way out), sprite bursts (the
## Sparkler's flash, Blink's moon sparkle, the black flame relighting), the Slam's shockwave ring on
## the floor, and short light pulses. Art: tools/art_moves.py -> assets/art/moves/.

var w: Node
var moves: Moves             # who to tell when a Sparkler burst is done
var popped := 0              # enemy shots popped by the current Sparkler (with the instant pop)
var hits := 0                # creatures its sparks hit
var _sparks: Array = []      # [pos, dir, left px, dmg, burn, travelled]
var _anims: Array = []       # [pos, frames, t, fps, reverse, floor]
var _lights: Array = []      # [PointLight2D, t, dur, energy]
var _floor: Node2D           # under the creatures (the Slam's ring lies on the floor)
var _pop_frame := -1


static func of(world: Node) -> MoveFx:
	var f: Variant = world.get_meta("move_fx") if world.has_meta("move_fx") else null
	if f != null and is_instance_valid(f):
		return f
	var nf := MoveFx.new()
	nf.w = world
	world.set_meta("move_fx", nf)
	var layer: Variant = world.get("fx_layer")
	(layer if layer != null else world).add_child(nf)
	return nf


func _ready() -> void:
	name = "MoveFx"
	z_index = 3
	material = Art.unshaded
	_floor = Node2D.new()
	_floor.z_index = -28           # fx_layer is z 20: this lands at -8, above the stains, under creatures
	_floor.material = Art.unshaded
	_floor.draw.connect(_draw_anims.bind(true))
	add_child(_floor)


## One Sparkler spark from `from` along `dir` (it flies Moves.SPARK_R px in Moves.SPARK_TIME s).
func spark(from: Vector2, dir: Vector2, dmg: float, burn: float) -> void:
	if _sparks.is_empty():
		popped = 0
		hits = 0
	_sparks.append([from, dir, Moves.SPARK_R, dmg, burn, 0.0])
	moves = Moves.of(w.player)


## A centred sprite animation (moves/burst, moves/blink ...) played once; `reverse` plays it backwards.
func burst(at: Vector2, prefix: String, fps: float, reverse := false) -> void:
	var frames: Array[Texture2D] = Art.seq(prefix)
	if frames.is_empty():
		return
	_anims.append([at, frames, 0.0, fps, reverse, false])


## The Slam's shockwave: drawn on the floor, under the creatures.
func ring(at: Vector2, prefix: String, fps: float) -> void:
	var frames: Array[Texture2D] = Art.seq(prefix)
	if frames.is_empty():
		return
	_anims.append([at, frames, 0.0, fps, false, true])


## A short light pulse (the moves light the room for a blink of an eye).
func flash(at: Vector2, col: Color, energy: float, sc: float) -> void:
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = col
	l.texture_scale = sc
	l.energy = energy
	l.position = at
	add_child(l)
	_lights.append([l, 0.0, 0.28, energy])


## An enemy shot popped: a puff of gold (one tick of sound per frame however many burst).
func pop(at: Vector2) -> void:
	Juice.of(w).hot.burst(at, 5, 20.0, 55.0, Vector2.ZERO, PI, 0.22, FxParts.GOLD, 0.0, 3.0)
	if _pop_frame != Engine.get_physics_frames():
		_pop_frame = Engine.get_physics_frames()
		Audio.play("hit_wall", -6.0, 0.1, 1.7)


func _physics_process(dt: float) -> void:
	if _sparks.is_empty():
		return
	var spd := Moves.SPARK_R / Moves.SPARK_TIME
	var i := _sparks.size() - 1
	while i >= 0:
		var s: Array = _sparks[i]
		var step := minf(float(s[2]), spd * dt)
		var done := false
		var moved := 0.0
		while moved < step - 0.01 and not done:   # sub-steps (the bot plays at 4x)
			var d := minf(3.0, step - moved)
			moved += d
			s[0] = (s[0] as Vector2) + (s[1] as Vector2) * d
			s[5] = float(s[5]) + d
			done = _spark_hits(s)
		s[2] = float(s[2]) - step
		if done or float(s[2]) <= 0.01:
			Juice.of(w).hot.burst(s[0], 2, 10.0, 40.0, s[1], 0.6, 0.18, FxParts.SPARK, 40.0, 3.0)
			_sparks.remove_at(i)
		i -= 1
	queue_redraw()
	if _sparks.is_empty() and moves != null and is_instance_valid(moves):
		moves.sparkler_done(popped, hits)


func _spark_hits(s: Array) -> bool:
	var pos: Vector2 = s[0]
	for e in w.enemies:
		if not is_instance_valid(e) or not e.alive or not e.active:
			continue
		if (e.global_position + Vector2(0, -e.half_h - e._jump_h)).distance_squared_to(pos) < pow(e.radius + 3.0, 2):
			e.take_hit(float(s[3]), (s[1] as Vector2) * Moves.SPARK_KNOCK, float(s[4]))
			hits += 1
			Juice.of(w).sparks(pos, s[1], 3)
			return true
	for sh in w.enemy_shots:
		if is_instance_valid(sh) and not sh._dead and sh.global_position.distance_squared_to(pos) < 36.0:
			pop(sh.global_position)
			sh.end()
			popped += 1
	var room: Room = w.room
	return room != null and room.shot_hits(pos + Vector2(0, 6), float(s[3]), true)


func _process(dt: float) -> void:
	var any := not _sparks.is_empty()
	var i := _anims.size() - 1
	while i >= 0:
		var a: Array = _anims[i]
		a[2] = float(a[2]) + dt
		if float(a[2]) * float(a[3]) >= (a[1] as Array).size():
			_anims.remove_at(i)
		i -= 1
	i = _lights.size() - 1
	while i >= 0:
		var l: Array = _lights[i]
		l[1] = float(l[1]) + dt
		var k := 1.0 - float(l[1]) / float(l[2])
		var light: PointLight2D = l[0]
		if k <= 0.0:
			light.queue_free()
			_lights.remove_at(i)
		else:
			light.energy = float(l[3]) * k
		i -= 1
	if any or not _anims.is_empty():
		queue_redraw()
		_floor.queue_redraw()
	elif get_meta("drawn", false):
		set_meta("drawn", false)
		queue_redraw()
		_floor.queue_redraw()


func _draw() -> void:
	var spark_frames: Array[Texture2D] = Art.seq("moves/spark")
	for s in _sparks:
		var pos: Vector2 = (s[0] as Vector2).round()
		var k := clampf(float(s[5]) / Moves.SPARK_R, 0.0, 0.999)
		# a 5 px trail behind each spark, stepping down the fire ramp
		for t in 5:
			var at := (pos - (s[1] as Vector2) * (2.0 + t * 1.5)).round()
			draw_rect(Rect2(at, Vector2.ONE), Moves.SPARK_COLS[mini(1 + t / 2 + int(k * 2.0), 4)])
		if not spark_frames.is_empty():
			var tex: Texture2D = spark_frames[mini(int(k * spark_frames.size()), spark_frames.size() - 1)]
			draw_texture(tex, pos - (tex.get_size() / 2.0).floor())
	_draw_anims(false)
	if not _sparks.is_empty() or not _anims.is_empty():
		set_meta("drawn", true)


func _draw_anims(on_floor: bool) -> void:
	var target: CanvasItem = _floor if on_floor else self
	for a in _anims:
		if bool(a[5]) != on_floor:
			continue
		var frames: Array = a[1]
		var f := mini(int(float(a[2]) * float(a[3])), frames.size() - 1)
		if bool(a[4]):
			f = frames.size() - 1 - f
		var tex: Texture2D = frames[f]
		target.draw_texture(tex, ((a[0] as Vector2) - (tex.get_size() / 2.0).floor()).round())
