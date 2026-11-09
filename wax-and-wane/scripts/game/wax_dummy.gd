class_name WaxDummy
extends Node2D
## v2.7: the primer's practice target (scripts/ui/primer.gd): an old wax figure on a wooden post with a target painted
## on its chest. Harmless and outside the game's books: not a lodger (no AI, no contact damage, no drops, no Kindling,
## not in world.enemies, never a kill), so aim assist does not reach it (its hit circle is generous instead). The
## primer finds the embers that reach it (catch()); it wobbles and flashes, and pops on the third.
## Art: tools/art_primer.py -> assets/art/primer/dummy_f0..2, dummy_hit. Its origin is at its feet (y-sorted).

const HITS := 3
const RADIUS := 10.0
const CHEST := Vector2(0, -13)

var world: Node
var hits := 0
var popped := false
var calm := false
var _spr: Sprite2D
var _frames: Array[Texture2D] = []
var _hit_tex: Texture2D
var _t := 0.0
var _wob := 0.0
var _flash := 0.0
var _land := 0.0


func _ready() -> void:
	name = "WaxDummy"
	for i in 3:
		_frames.append(Art.tex("primer/dummy_f%d" % i))
	_hit_tex = Art.tex("primer/dummy_hit")
	_spr = Sprite2D.new()
	_spr.centered = false
	_spr.texture = _frames[0]
	_spr.position = Vector2(-9, -25)
	add_child(_spr)
	queue_redraw()


## Drops in from above with a bump and a puff (Reduce motion: it is simply there).
func appear() -> void:
	if calm:
		return
	_spr.position.y = -25.0 - 36.0
	_land = 0.32
	var tw := create_tween()
	tw.tween_property(_spr, "position:y", -25.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Audio.play("thud_heavy", -10.0, 0.05, 1.3)
		if world:
			world.fx_poof(global_position + Vector2(0, -2), true, 0.8)
			world.shake(1.0))


## The chest, where embers land.
func target() -> Vector2:
	return global_position + CHEST


## Embers in the air that reach it end on it (a spark each). Returns how many landed this frame.
func catch() -> int:
	if popped or world == null or _land > 0.0:
		return 0
	var n := 0
	for s in world.fx_layer.get_children():
		if not (s is Shot) or not s.friendly or s.get("_dead"):
			continue
		if (s as Node2D).global_position.distance_to(target()) < RADIUS + float(s.radius):
			var v: Vector2 = s.vel
			s.end()
			hit(v.normalized())
			n += 1
			if popped:
				break
	return n


func hit(dir: Vector2) -> void:
	if popped:
		return
	hits += 1
	_flash = 0.08
	_wob = 0.5
	Audio.play("hit_enemy", -2.0, 0.08)
	if world:
		world.fx_sparks(target(), dir, 3, false)
	if hits >= HITS:
		pop()


## Bursts into warm wax: a puff, splashes that leave drops on the floor, bits of the post, a stain that stays.
func pop() -> void:
	if popped:
		return
	popped = true
	_spr.visible = false
	Audio.play("splat", 0.0, 0.05)
	Audio.play("enemy_die", -4.0, 0.05, 1.2)
	if world:
		world.fx_poof(target(), true, 1.5)
		for i in 7:
			world.fx_drop(target(), Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(35.0, 75.0))
		world.fx_debris(global_position + Vector2(0, -3), "C")
		world.fx_stain(global_position, "wax")
		world.shake(2.5)
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)


## Gone without a fuss (Skip): a puff.
func vanish() -> void:
	if popped:
		return
	popped = true
	if world:
		world.fx_poof(target(), true, 1.0)
	queue_free()


func _process(dt: float) -> void:
	_t += dt
	_land = maxf(0.0, _land - dt)
	_wob = maxf(0.0, _wob - dt)
	_flash = maxf(0.0, _flash - dt)
	if popped:
		return
	var f := 0
	if _wob > 0.0:
		f = [0, 1, 0, 2][int(_wob * 16.0) % 4]
	elif not calm:
		f = [0, 1, 0, 2][int(_t * 2.5) % 4] if fmod(_t, 2.4) < 1.6 else 0   # a slow sway now and then: "hit me"
	_spr.texture = _hit_tex if _flash > 0.0 else _frames[f]
	queue_redraw()


## The target ring painted on the floor under it: gold, pulsing (stepped), drawn under the figure.
func _draw() -> void:
	if popped:
		return
	var on := calm or fmod(_t, 0.8) < 0.5
	var col := Color("#facb3e") if on else Color("#ee8e2e")
	# a 15x5 pixel ellipse
	var rows := [[-4, 4, -2], [-7, -5, -1], [5, 7, -1], [-7, -6, 0], [6, 7, 0], [-7, -5, 1], [5, 7, 1], [-4, 4, 2]]
	for r in rows:
		draw_rect(Rect2(Vector2(r[0], r[2] + 1), Vector2(r[1] - r[0] + 1, 1)), Color("#21141b"))
	for r in rows:
		draw_rect(Rect2(Vector2(r[0], r[2]), Vector2(r[1] - r[0] + 1, 1)), col)
