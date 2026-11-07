class_name Shot
extends Node2D
## A projectile. Position is where it is drawn (in the air); the ground point used for walls is a few
## pixels below. Player embers light the floor as they fly.

var world: Node
var vel := Vector2.ZERO
var dmg := 1.0
var life := 1.0
var friendly := true
var pierce := 0
var homing := 0.0
var burn := 0.0
var knock := 60.0
var radius := 3.0
var spr: AnimatedSprite2D
var light: PointLight2D
var _hit := {}
var _dead := false
# lobbed shots (flasks): fly to a target point in an arc, burst on landing
var lob := false
var lob_from := Vector2.ZERO
var lob_to := Vector2.ZERO
var lob_t := 0.0
var lob_dur := 0.9
## Ember lights are capped so a room never exceeds the renderer's per-item light limit.
static var _lights := 0
var _blue := false
var _tr_t := 0.0
const TRAIL := [Color("#ee8e2e"), Color("#da4e38"), Color("#8f4029")]
const TRAIL_BLUE := [Color("#72d6ce"), Color("#5698cc"), Color("#5956bd")]


func setup(w: Node, pos: Vector2, v: Vector2, kind: String, is_friendly: bool) -> void:
	world = w
	position = pos
	vel = v
	friendly = is_friendly
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = Art.anim("fx/" + kind, 12.0)
	spr.play("default")
	spr.material = Art.unshaded
	add_child(spr)
	z_index = 5
	_blue = kind.contains("blue")
	if friendly:
		material = Art.unshaded   # the spark trail glows like the ember
	if friendly and _lights < 6:
		_lights += 1
		tree_exiting.connect(func(): _lights -= 1)
		light = PointLight2D.new()
		light.texture = Art.light_tex
		light.texture_scale = 0.28
		light.energy = 0.7
		light.color = Color(0.6, 0.8, 1.0) if kind.contains("blue") else Color(1.0, 0.65, 0.3)
		add_child(light)


func _physics_process(dt: float) -> void:
	if _dead:
		return
	if not friendly and (world.freeze_t > 0.0 or Juice.holding(world)):
		return
	if lob:
		_lob_step(dt)
		return
	if homing > 0.0 and friendly:
		var tgt: Node2D = world.nearest_enemy(global_position, 90.0)
		if tgt:
			var want := (tgt.global_position + Vector2(0, -6) - global_position).normalized() * vel.length()
			vel = vel.lerp(want, minf(1.0, homing * dt * 6.0))
	position += vel * dt
	life -= dt
	var room: Room = world.room
	if room and room.shot_hits(global_position + Vector2(0, 6), dmg, friendly):
		if friendly and world.has_method("fx_sparks"):
			world.fx_sparks(global_position, -vel.normalized(), 4, _blue)
		if RelicFx.shot_wall(self): return
		end()
		Audio.play("hit_wall", -3.0)
		return
	if friendly:
		for e in world.enemies:
			if not is_instance_valid(e) or not e.alive or not e.active or _hit.has(e):
				continue
			if (e.global_position + Vector2(0, -e.half_h - e._jump_h)).distance_squared_to(global_position) < pow(e.radius + radius + 1.0, 2):
				_hit[e] = true
				e.take_hit(dmg, vel.normalized() * knock, burn)
				if world.has_method("fx_sparks"):
					world.fx_sparks(global_position, vel.normalized(), 2, _blue)
				RelicFx.shot_hit(self, e)
				if pierce <= 0:
					end()
					return
				pierce -= 1
	else:
		var p: Player = world.player
		if p and not p.dead and (p.global_position + Vector2(0, -8)).distance_squared_to(global_position) < pow(radius + 4.0, 2):
			p.hurt(5.0 * world.enemy_dmg_mult(), vel)
			end()
			return
	if life <= 0:
		end()
	if friendly:
		_tr_t += dt
		queue_redraw()


## A short spark trail behind player embers (3 pixels, cooling as they trail off).
func _draw() -> void:
	if not friendly or _dead or vel.length_squared() < 100.0:
		return
	var back := -vel.normalized()
	var cols: Array = TRAIL_BLUE if _blue else TRAIL
	var flick := int(_tr_t * 30.0) % 2
	for i in 3:
		if i == 2 and flick == 1:
			continue
		var p := (back * (4.0 + 3.0 * i)).round()
		draw_rect(Rect2(p, Vector2.ONE), cols[i])


func _lob_step(dt: float) -> void:
	lob_t += dt
	var k := clampf(lob_t / lob_dur, 0.0, 1.0)
	position = lob_from.lerp(lob_to, k) + Vector2(0, -sin(k * PI) * 40.0)
	spr.rotation += dt * 9.0
	if k >= 1.0:
		_dead = true
		world.burst(lob_to, 6, 70.0, "bullet_green", randf() * TAU)
		Audio.play("splash")
		queue_free()


func end() -> void:
	if _dead:
		return
	_dead = true
	world.fx_poof(global_position, friendly)
	queue_free()
