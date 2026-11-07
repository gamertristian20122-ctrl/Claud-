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


func setup(w: Node, pos: Vector2, v: Vector2, kind: String, is_friendly: bool) -> void:
	world = w
	position = pos
	vel = v
	friendly = is_friendly
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = Art.anim("fx/" + kind, 12.0)
	spr.play("default")
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	spr.material = mat
	add_child(spr)
	z_index = 5
	if friendly:
		light = PointLight2D.new()
		light.texture = Art.light_tex
		light.texture_scale = 0.28
		light.energy = 0.7
		light.color = Color(0.6, 0.8, 1.0) if kind.contains("blue") else Color(1.0, 0.65, 0.3)
		add_child(light)


func _physics_process(dt: float) -> void:
	if _dead:
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
	spr.rotation = vel.angle() if not friendly else 0.0
	var room: Room = world.room
	if room and room.shot_hits(global_position + Vector2(0, 6), dmg):
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
