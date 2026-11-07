class_name HouseAI
extends RefCounted
## Behaviours of the house's own monsters (and the late 0x72 lodgers). Enemy calls
## `<ai>(enemy, ddt, to_player, dist)` every physics frame while the creature is active
## (or buried). Optional hooks: `init_<ai>(e)` on spawn, `touched_<ai>(e)` after a contact hit.
## Every dangerous move is telegraphed: a flash, a wind-up frame, a dashed lane or a ring.

const RED := Color("#da4e38")
const GOLD := Color("#facb3e")
const PALE := Color("#cae6f5")


static func _shot_origin(e: Enemy) -> Vector2:
	return e.global_position + Vector2(0, -e.half_h - e._jump_h)


## Flyers drift over everything but stay inside the room.
static func _fly(e: Enemy, want: Vector2, spd: float, ddt: float) -> void:
	if want.length() < 0.01:
		return
	var r: Rect2 = e.world.room.inner_rect().grow(-4)
	e.global_position = (e.global_position + want.normalized() * spd * ddt).clamp(r.position, r.end)
	if e._anim_lock <= 0.0 and e.spr.animation != "run" and e.spr.sprite_frames.has_animation("run"):
		e.spr.play("run")


static func _fan(e: Enemy, at: Vector2, base: float, n: int, spread: float, spd: float, kind: String) -> void:
	for i in n:
		e.world.enemy_shot(at, Vector2.from_angle(base + (i - (n - 1) / 2.0) * spread) * spd, kind)


# ---------------------------------------------------------------- Rose Melt: squashy hops
func blob(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	match e.state:
		"hop":
			e._walk(ddt, e.dir, e.speed * 2.7)
			e._jump_h = sin((1.0 - e.t / 0.38) * PI) * 4.0
			if e.t <= 0:
				e.state = "idle"
				e._jump_h = 0.0
				e.t = randf_range(0.3, 0.55)
				e.spr.play("idle")
				e.scale = Vector2(1.15, 0.85)
				e.create_tween().tween_property(e, "scale", Vector2.ONE, 0.18)
		_:
			e._jump_h = 0.0
			if e.t <= 0:
				e.state = "hop"
				e.t = 0.38
				e.dir = (to_p.normalized() + Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))).normalized()


# ---------------------------------------------------------------- Lamp Moth: drawn to your flame
func moth(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	e._wob += ddt * 7.0
	var p: Player = e.world.player
	# the brighter Tallow burns, the harder they pull
	var pull := 0.7 + 0.55 * clampf(p.wax / 120.0, 0.0, 1.0)
	var n := to_p.normalized()
	var want := n + n.orthogonal() * sin(e._wob + float(e.get_instance_id() % 7)) * 0.95
	if e.state == "bump":
		want = -n + n.orthogonal() * 0.6
		if e.t <= 0:
			e.state = "idle"
	_fly(e, want, e.speed * pull, ddt)
	e._jump_h = 9.0 + sin(e._wob * 1.3) * 2.0


func touched_moth(e: Enemy) -> void:
	e.state = "bump"
	e.t = 0.7


# ---------------------------------------------------------------- Iron Snuffer: aimed dash
func snuffer(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	match e.state:
		"windup":
			e.spr.position.x = sin(e.t * 70.0)
			if e.t <= 0:
				e.spr.position.x = 0
				e.state = "dash"
				e.t = float(e.mem.get("len", 120.0)) / 205.0
				Audio.play("teleport", -8.0, 0.05, 1.6)
		"dash":
			if not e._move(e.dir * 205.0 * ddt) or e.t <= 0:
				e.state = "stun"
				e.t = 0.75
				e.cd = randf_range(1.5, 2.3)
				e.world.shake(1.5)
				Audio.play("hit_wall", -2.0, 0.05, 0.6)
				e.play_anim("idle", 0.0)
		"stun":
			if e.t <= 0:
				e.state = "idle"
		_:
			e._walk(ddt, to_p, e.speed)
			if e.cd <= 0 and dist < 150 and dist > 20:
				e.state = "windup"
				e.t = 0.7
				e.dir = to_p.normalized()
				var ln := minf(dist + 28.0, 170.0)
				e.mem["len"] = ln
				e.tele().line(e.global_position + Vector2(0, -3), e.global_position + Vector2(0, -3) + e.dir * ln, 0.7, RED)
				e.play_anim("atk", 0.7)
				e._telegraph(Color(1, 0.4, 0.3))
				Audio.play("charge", -4.0, 0.05, 1.2)


# ---------------------------------------------------------------- Grave Light: blinks, then fires
func blinker(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	e._wob += ddt * 2.0
	e._jump_h = 5.0 + sin(e._wob * 1.7) * 1.5
	match e.state:
		"fade":
			e.spr.modulate.a = clampf(e.t / 0.3, 0.0, 1.0)
			if e.t <= 0:
				e.global_position = e.free_spot(e.world.player.global_position, 56.0, 120.0)
				e.state = "appear"
				e.t = 0.3
				Audio.play("teleport", -10.0, 0.1, 1.5)
		"appear":
			e.spr.modulate.a = clampf(1.0 - e.t / 0.3, 0.0, 1.0)
			if e.t <= 0:
				e.spr.modulate.a = 1.0
				e.state = "aim"
				e.t = 0.5
				e.play_anim("atk", 0.5)
				e._telegraph(PALE)
		"aim":
			if e.t <= 0:
				_fan(e, _shot_origin(e), to_p.angle(), 3, 0.2, 80.0, "bullet_water")
				Audio.play("enemy_shoot", -2.0, 0.08, 1.3)
				e.state = "idle"
				e.cd = randf_range(2.2, 3.0)
		_:
			var want := to_p.orthogonal() * (1.0 if sin(e._wob * 0.6) > 0 else -1.0)
			if dist < 50:
				want = -to_p
			_fly(e, want, e.speed, ddt)
			if e.cd <= 0:
				e.state = "fade"
				e.t = 0.3


# ---------------------------------------------------------------- Sootling: leaves slowing soot
func sooter(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	e._wob += ddt * 6.0
	var n := to_p.normalized()
	var want := n + n.orthogonal() * sin(e._wob) * 1.2
	if dist < 24:
		want = n.orthogonal() * (1.0 if sin(e._wob * 0.3) > 0 else -1.0)
	e._walk(ddt, want, e.speed)
	e._jump_h = absf(sin(e._wob * 1.5)) * 2.0
	if e.cd <= 0:
		e.cd = randf_range(0.9, 1.3)
		SootPatch.drop(e.world, e.global_position)


# ---------------------------------------------------------------- Waxwork Bride: only moves unwatched
func statue(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	var p: Player = e.world.player
	var watched := false
	if dist > 3.0:
		var from_p := (-to_p).normalized()
		watched = p.facing.normalized().dot(from_p) > 0.5
		if p.aim_input.length() > 0.3 and p.aim_input.normalized().dot(from_p) > 0.75:
			watched = true
	if watched:
		if e.state != "still":
			e.state = "still"
			e.spr.play("idle")
			e.spr.pause()
	else:
		if e.state == "still":
			e.state = "creep"
			Audio.play("step", -4.0, 0.1, 0.55)
		e._walk(ddt, to_p, e.speed)


# ---------------------------------------------------------------- Cinder Rat: fast, erratic darts
func rat(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	match e.state:
		"dart":
			e._walk(ddt, e.dir, e.speed)
			if e.t <= 0:
				e.state = "idle"
				e.t = randf_range(0.22, 0.45)
				e.spr.play("idle")
		_:
			if e.t <= 0:
				e.state = "dart"
				e.t = randf_range(0.28, 0.48)
				e.dir = to_p.normalized().rotated(randf_range(-0.95, 0.95))


# ---------------------------------------------------------------- Restless Psalter: fans of pages
func fanner(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	e._wob += ddt
	var want := to_p.orthogonal() * (1.0 if sin(e._wob * 0.7) > 0 else -1.0)
	if dist < 70:
		want = -to_p
	elif dist > 115:
		want = to_p
	_fly(e, want, e.speed, ddt)
	e._jump_h = 6.0 + sin(e._wob * 3.0) * 1.5
	if e.cd <= 0.5 and e.state != "aim":
		e.state = "aim"
		e.play_anim("atk", 0.6)
		e._telegraph(Color(1, 1, 0.85))
		Audio.play("tick", -8.0, 0.1, 0.8)
	if e.cd <= 0:
		e.state = "idle"
		e.cd = randf_range(2.4, 3.0)
		var n := 5 if e._pattern % 2 == 0 else 3
		e._pattern += 1
		_fan(e, _shot_origin(e), to_p.angle(), n, 0.24, 70.0, "bolt_page")
		Audio.play("enemy_shoot", -2.0, 0.1, 1.25)


# ---------------------------------------------------------------- Clapper Bat: rings a sonic circle
func bellbat(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	if e.state == "ring":
		e._jump_h = 8.0
		if e.t <= 0:
			e.world.burst(_shot_origin(e), 10, 52.0, "bolt_ring", randf() * TAU)
			Audio.play("bell_toll", -10.0, 0.05, 2.2)
			e.state = "idle"
			e.cd = randf_range(2.8, 3.6)
		return
	e._wob += ddt * 4.5
	var n := to_p.normalized()
	var want := n + n.orthogonal() * sin(e._wob) * 1.3
	if dist < 46:
		want = -n + n.orthogonal() * 0.8
	_fly(e, want, e.speed, ddt)
	e._jump_h = 8.0 + sin(e._wob * 1.9) * 2.5
	if e.cd <= 0 and dist < 135:
		e.state = "ring"
		e.t = 0.6
		e.play_anim("atk", 0.6)
		e._telegraph(Color(1, 0.95, 0.6))
		e.tele().ring(e.global_position, 18.0, 0.6, PALE)
		Audio.play("tick", -4.0, 0.0, 1.7)


# ---------------------------------------------------------------- Deathwatch Beetle: rolls and rebounds
func init_bouncer(e: Enemy) -> void:
	e.dir = Vector2(1.0 if randf() < 0.5 else -1.0, 1.0 if randf() < 0.5 else -1.0).normalized()


func bouncer(e: Enemy, ddt: float, _to_p: Vector2, _dist: float) -> void:
	var room: Room = e.world.room
	var step := e.dir * e.speed * ddt
	var gp := e.global_position
	var bounced := false
	var nx := gp + Vector2(step.x, 0)
	if room.blocked(nx, e.radius):
		e.dir.x = -e.dir.x
		bounced = true
	else:
		gp = nx
	var ny := gp + Vector2(0, step.y)
	if room.blocked(ny, e.radius):
		e.dir.y = -e.dir.y
		bounced = true
	else:
		gp = ny
	e.global_position = gp
	if bounced:
		e._pattern += 1
		Audio.play("tick", -10.0, 0.1, 1.5)
		# every few rebounds it turns its head toward the light
		if e._pattern % 4 == 0:
			var to: Vector2 = e.world.player.global_position - gp
			e.dir = Vector2(signf(to.x) if absf(to.x) > 4 else e.dir.x, signf(to.y) if absf(to.y) > 4 else e.dir.y).normalized()
		if e.room_stuck():
			e.global_position = e.world.free_spot_near(gp, e.radius)
	if e.spr.animation != "run":
		e.spr.play("run")


# ---------------------------------------------------------------- Grave Hand: burrow and grab
func burrow(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	var p: Player = e.world.player
	match e.state:
		"tell":
			e.spr.position.x = sin(e.t * 60.0) * 1.0
			if e.t <= 0:
				e.spr.position.x = 0
				e.buried = false
				e.active = true
				e.spr.modulate.a = 1.0
				e.play_anim("rise", 0.3)
				e.state = "rise"
				e.t = 0.3
				Audio.play("urn_break", -6.0, 0.1, 0.6)
		"rise":
			if e.t <= 0:
				if dist < e.radius + 9.0 and not p.dead:
					p.hurt(6.0 * e.world.enemy_dmg_mult(), to_p)
					e.play_anim("grab", 0.4)
				e.state = "up"
				e.t = 1.9
		"up":
			if e.t <= 0:
				e.state = "sink"
				e.t = 0.3
				e.play_anim("rise", 0.3)
		"sink":
			if e.t <= 0:
				_go_under(e)
		"under":
			e.active = false
			e._move(to_p.normalized() * e.speed * ddt)
			if e.t <= 0 or dist < 5.0:
				e.state = "tell"
				e.t = 0.75
				e.tele().ring(e.global_position, 11.0, 0.75, RED)
				Audio.play("charge", -10.0, 0.1, 0.7)
		_:
			_go_under(e)


static func _go_under(e: Enemy) -> void:
	e.buried = true
	e.active = false
	e.state = "under"
	e.t = randf_range(1.2, 2.0)
	e.spr.play("mound")
	e._anim_lock = 0.0
	e.spr.modulate.a = 0.9


# ---------------------------------------------------------------- Gutterspout: fires along its lines
func turret(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	match e.state:
		"aim":
			if e.t <= 0:
				e.state = "fire"
				e._pattern = 3
				e._wob = 0.0
		"fire":
			e._wob -= ddt
			if e._wob <= 0.0:
				e._wob = 0.13
				e._pattern -= 1
				e.world.enemy_shot(e.global_position + Vector2(0, -9), e.dir * 108.0, "bullet_water")
				Audio.play("splash", -10.0, 0.1, 1.6)
				if e._pattern <= 0:
					e.state = "idle"
					e.cd = 1.5
		_:
			var lined := absf(to_p.x) < 10.0 or absf(to_p.y) < 10.0
			if e.cd <= 0 and lined and dist < 230:
				e.dir = Vector2(signf(to_p.x), 0) if absf(to_p.y) < absf(to_p.x) else Vector2(0, signf(to_p.y))
				e.state = "aim"
				e.t = 0.45
				e.play_anim("atk", 0.8)
				e._telegraph(Color(0.75, 0.9, 1.0))
				var a := e.global_position + Vector2(0, -3)
				e.tele().line(a, a + e.dir * minf(dist, 90.0), 0.45, PALE)
				Audio.play("tick", -6.0, 0.0, 0.6)


# ---------------------------------------------------------------- Gilt Cherub: circles and fires
func orbit(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	if not e.mem.has("ang"):
		e.mem["ang"] = (-to_p).angle()
		e.mem["sgn"] = 1.0 if randf() < 0.5 else -1.0
	e.mem["ang"] += ddt * 0.9 * float(e.mem["sgn"])
	var p: Player = e.world.player
	var want_pos: Vector2 = p.global_position + Vector2.from_angle(e.mem["ang"]) * 66.0
	var d := want_pos - e.global_position
	if d.length() > 3.0:
		_fly(e, d, e.speed, ddt)
	e._wob += ddt
	e._jump_h = 8.0 + sin(e._wob * 4.0) * 1.5
	if e.cd <= 0.4 and e.state != "aim":
		e.state = "aim"
		e._telegraph(Color(1, 0.9, 0.5))
	if e.cd <= 0:
		e.state = "idle"
		e.cd = randf_range(2.0, 2.6)
		e.world.enemy_shot(_shot_origin(e), to_p.normalized() * 86.0, "bullet_water")
		Audio.play("enemy_shoot", -4.0, 0.08, 1.4)
	if dist < 10:
		e.mem["sgn"] = -float(e.mem["sgn"])


# ---------------------------------------------------------------- Belfry Brute: ground slam
func brute(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	match e.state:
		"windup":
			e.spr.position.x = sin(e.t * 80.0)
			if e.t <= 0:
				e.spr.position.x = 0
				e.scale = Vector2.ONE
				var at := e.global_position + Vector2(0, -4)
				e.world.burst(at, 10, 68.0, "bullet_green", randf() * TAU)
				e.world.shake(2.5)
				Audio.play("explosion", -10.0, 0.05, 1.5)
				var p: Player = e.world.player
				if dist < 28.0 and not p.dead:
					p.hurt(6.0 * e.world.enemy_dmg_mult(), to_p)
				e.state = "recover"
				e.t = 0.6
		"recover":
			if e.t <= 0:
				e.state = "idle"
				e.cd = 1.9
		_:
			e._walk(ddt, to_p, e.speed)
			if dist < 36 and e.cd <= 0:
				e.state = "windup"
				e.t = 0.55
				e._telegraph(Color(1, 0.35, 0.3))
				e.scale = Vector2(1.15, 0.85)
				e.tele().ring(e.global_position, 28.0, 0.55, RED)
				Audio.play("charge", -6.0, 0.05, 0.8)


# ---------------------------------------------------------------- Potted Sleeper: spits a fan
func spitter(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	match e.state:
		"aim":
			if e.t <= 0:
				_fan(e, e.global_position + Vector2(0, -12), to_p.angle(), 3, 0.26, 74.0, "bullet_green")
				Audio.play("splash", -6.0, 0.1, 1.3)
				e.state = "idle"
				e.cd = randf_range(2.4, 3.0)
		_:
			e._walk(ddt, to_p, e.speed)
			if e.cd <= 0 and dist < 140:
				e.state = "aim"
				e.t = 0.5
				e._telegraph(Color(0.7, 1.0, 0.6))
