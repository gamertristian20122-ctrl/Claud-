class_name AreaAI
extends RefCounted
## Behaviours of the Long Night's new lodgers and guardians (the Kitchen, the Library, the Attic).
## Enemy calls `<ai>(enemy, ddt, to_player, dist)` every physics frame while the creature is active (or buried);
## optional hooks: init_<ai>(e) on spawn, touched_<ai>(e) after a contact hit, hit_<ai>(e, dmg, knock) -> bool
## (false turns the hit away) and died_<ai>(e). One dispatch line in enemy.gd sends every `area_*` here.
## Every dangerous move is telegraphed: a flash and a wind-up frame, a lane, a landing ring, a ring with gaps.
## Bullets: the house's own kinds (bullet_water for broth and ink, bolt_page for books) and the pins (bolt_pin).

const RED := Color("#da4e38")
const PALE := Color("#cae6f5")
static var _inst: AreaAI


static func ai() -> AreaAI:
	if _inst == null:
		_inst = AreaAI.new()
	return _inst


static func _clamp_in(e: Enemy, p: Vector2, margin := 10.0) -> Vector2:
	var r: Rect2 = e.world.room.inner_rect().grow(-margin)
	return p.clamp(r.position, r.end)


# ================================================================= THE KITCHEN

# ---------------------------------------------------------------- Pot-Lid Crab: shielded from the front
func init_area_crab(e: Enemy) -> void:
	var face := 1.0 if e.world.player.global_position.x >= e.global_position.x else -1.0
	e.mem["face"] = face
	e.mem["turn"] = 0.0
	e.spr.flip_h = face < 0.0


func area_crab(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	# it turns round slowly (a little hop), so getting past its lid works
	var face: float = e.mem.get("face", 1.0)
	var want := 1.0 if to_p.x >= 0.0 else -1.0
	if want != face and absf(to_p.x) > 6.0 and e.state != "snap":
		e.mem["turn"] = float(e.mem.get("turn", 0.0)) + ddt
		if float(e.mem["turn"]) > 0.75:
			e.mem["face"] = want
			e.mem["turn"] = 0.0
			e.spr.flip_h = want < 0.0
			e._jump_h = 3.0
	else:
		e.mem["turn"] = 0.0
	e._jump_h = maxf(0.0, e._jump_h - ddt * 18.0)
	match e.state:
		"wind":
			e.spr.position.x = sin(e.t * 70.0)
			if e.t <= 0.0:
				e.spr.position.x = 0.0
				e.state = "snap"
				e.t = 0.28
		"snap":
			e._move(e.dir * 125.0 * ddt)
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = float(e.def["cd"]) * randf_range(0.9, 1.3)
		_:
			# scuttle in: mostly sideways, as crabs do
			var pd: Vector2 = e.world.room.path_dir(e.global_position, e.global_position + to_p)
			e._walk(ddt, Vector2(pd.x, pd.y * 0.75), e.speed)
			if dist < 34.0 and e.cd <= 0.0:
				e.state = "wind"
				e.t = 0.45
				e.dir = to_p.normalized()
				e.play_anim("atk", 0.8)
				e._telegraph(Color(1, 0.5, 0.35))
				Audio.play("charge", -6.0, 0.05, 1.3)


## The lid turns away shots that come at its front (bombs and big blows still land).
func hit_area_crab(e: Enemy, dmg: float, knock: Vector2) -> bool:
	if dmg >= 8.0 or knock.length() < 0.01:
		return true
	var face: float = e.mem.get("face", 1.0)
	if knock.normalized().x * face < -0.65:
		Audio.play("hit_wall", -2.0, 0.1, 1.5)
		e.world.fx_sparks(e.global_position + Vector2(face * 7.0, -8.0), Vector2(face, -0.3), 3)
		HouseAI._tip(e, "lid_crab", "The lid takes it: hit the crab from behind, above or below")
		return false
	return true


# ---------------------------------------------------------------- Flour Ghost: its clouds swallow shots
func area_flour(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	e._wob += ddt * 3.0
	match e.state:
		"puff":
			if e.t <= 0.0:
				AreaGimmicks.flour_cloud(e.world, e.global_position + Vector2(0, -6))
				Audio.play("splat", -4.0, 0.1, 1.5)
				HouseAI._tip(e, "flour", "Flour clouds swallow every shot, yours and theirs")
				e.state = "hide"
				e.t = 0.7
		"hide":
			if e.t <= 0.0:
				e.state = "idle"
		"bump":
			HouseAI._fly(e, -to_p, e.speed, ddt)
			if e.t <= 0.0:
				e.state = "idle"
		_:
			var n := to_p.normalized()
			HouseAI._fly(e, n + n.orthogonal() * sin(e._wob) * 0.8, e.speed * (0.55 if dist < 40.0 else 1.0), ddt)
			if e.cd <= 0.0 and dist < 130.0:
				e.cd = float(e.def["cd"]) * randf_range(0.9, 1.2)
				e.state = "puff"
				e.t = 0.45
				e.play_anim("atk", 0.6)
				e._telegraph(Color(1, 1, 0.9))
	e._jump_h = 6.0 + sin(e._wob * 1.4) * 2.0


func touched_area_flour(e: Enemy) -> void:
	e.state = "bump"
	e.t = 0.6


# ================================================================= THE LIBRARY

# ---------------------------------------------------------------- Bookworm: tunnels through shelves
static func _soft(ch: String) -> bool:
	return ch == "B" or ch == "C"


## Blocked for a bookworm: walls, rocks, pits... but not furniture or crates (it eats through them).
static func _worm_blocked(e: Enemy, gp: Vector2) -> bool:
	var room: Room = e.world.room
	if room.blocked(gp, e.radius, true):
		return true
	var lp := gp - room.position
	var c0 := room.cell_of(lp - Vector2(e.radius, e.radius))
	var c1 := room.cell_of(lp + Vector2(e.radius, e.radius))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var ch := room.char_at(Vector2i(cx, cy))
			if ch in Room.SOLID and not _soft(ch):
				var rect := Rect2(Room.IN + Vector2(cx * Room.TILE + 1, cy * Room.TILE + 2), Vector2(Room.TILE - 2, Room.TILE - 3))
				var q := Vector2(clampf(lp.x, rect.position.x, rect.end.x), clampf(lp.y, rect.position.y, rect.end.y))
				if q.distance_squared_to(lp) < e.radius * e.radius:
					return true
	return false


static func _worm_move(e: Enemy, d: Vector2) -> bool:
	var gp := e.global_position
	var moved := false
	var np := gp + Vector2(d.x, 0)
	if not _worm_blocked(e, np):
		gp = np
		moved = true
	np = gp + Vector2(0, d.y)
	if not _worm_blocked(e, np):
		gp = np
		moved = true
	e.global_position = gp
	return moved


func area_worm(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	var room: Room = e.world.room
	var inside := _soft(room.char_at(room.cell_of(e.global_position - room.position)))
	if inside != bool(e.mem.get("inside", false)):
		e.mem["inside"] = inside
		e.spr.visible = not inside
		e.world.fx_poof(e.global_position + Vector2(0, -6), false, 0.8)
		Audio.play("page_flip", -6.0, 0.1, 1.2)
		if inside:
			HouseAI._tip(e, "bookworm", "Bookworms tunnel through the shelves: wait for them to come out")
	e.buried = inside            # inside a shelf: no bite, shots pass
	e.active = not inside
	if inside:
		e.mem["dust"] = float(e.mem.get("dust", 0.0)) - ddt
		if float(e.mem["dust"]) <= 0.0:
			e.mem["dust"] = 0.35
			e.world.fx_debris(e.global_position + Vector2(randf_range(-4, 4), -4), "C")
	match e.state:
		"rear":
			if e.t <= 0.0:
				e.state = "bite"
				e.t = 0.3
		"bite":
			_worm_move(e, e.dir * 110.0 * ddt)
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = float(e.def["cd"]) * randf_range(0.9, 1.3)
		_:
			var want := to_p.normalized()
			if not _worm_move(e, want * e.speed * ddt):
				var pd: Vector2 = room.path_dir(e.global_position, e.global_position + to_p)
				if not _worm_move(e, pd * e.speed * ddt):
					for a in [0.9, -0.9, 1.6, -1.6]:
						if _worm_move(e, want.rotated(a) * e.speed * ddt):
							break
			e.dir = want
			if e._anim_lock <= 0.0 and e.spr.animation != "run":
				e.spr.play("run")
			if not inside and dist < 26.0 and e.cd <= 0.0:
				e.state = "rear"
				e.t = 0.4
				e.dir = to_p.normalized()
				e.play_anim("atk", 0.7)
				e._telegraph(Color(1, 0.6, 0.7))
				Audio.play("charge", -8.0, 0.05, 1.5)


# ---------------------------------------------------------------- Inkblot: hops, spits ink, bursts into puddles
func area_ink(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	match e.state:
		"hop":
			e._walk(ddt, e.dir, e.speed * 2.4)
			e._jump_h = sin((1.0 - e.t / 0.4) * PI) * 5.0
			if e.t <= 0.0:
				e.state = "idle"
				e._jump_h = 0.0
				e.t = randf_range(0.35, 0.6)
				BossAI._squash(e, 0.8)
		"aim":
			if e.t <= 0.0:
				BossAI._fan(e, e.global_position + Vector2(0, -7), to_p.angle(), 3, 0.32, 72.0, "bullet_water")
				Audio.play("splat", -4.0, 0.08, 0.8)
				e.state = "idle"
				e.t = 0.5
				e.cd = float(e.def["cd"]) * randf_range(0.9, 1.2)
		_:
			e._jump_h = 0.0
			if e.cd <= 0.0 and dist < 120.0:
				e.state = "aim"
				e.t = 0.5
				e.play_anim("atk", 0.6)
				e._telegraph(Color(0.6, 0.75, 1.0))
			elif e.t <= 0.0:
				e.state = "hop"
				e.t = 0.4
				var pd: Vector2 = e.world.room.path_dir(e.global_position, e.global_position + to_p)
				e.dir = (pd + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))).normalized()


func died_area_ink(e: Enemy) -> void:
	for i in 3:
		AreaGimmicks.ink_puddle(e.world, e.global_position + Vector2.from_angle(TAU * i / 3.0 + randf()) * 9.0)


func area_inkdrop(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	e._wob += ddt * 6.0
	var pd: Vector2 = e.world.room.path_dir(e.global_position, e.global_position + to_p)
	e._walk(ddt, pd + pd.orthogonal() * sin(e._wob) * 0.6, e.speed)
	e.mem["drip"] = float(e.mem.get("drip", 1.4)) - ddt
	if float(e.mem["drip"]) <= 0.0:
		e.mem["drip"] = 1.8
		AreaGimmicks.ink_puddle(e.world, e.global_position, true)


func died_area_inkdrop(e: Enemy) -> void:
	AreaGimmicks.ink_puddle(e.world, e.global_position, true)


# ================================================================= THE ATTIC

## How far Tallow's light holds back what fears it (px): the bright core of his candle, smaller as he melts and
## smaller in the attic's deep dark.
static func light_reach(w: Node) -> float:
	var p: Player = w.player
	return (26.0 + 26.0 * clampf(p.wax_frac(), 0.0, 1.0)) * AreaGimmicks.light_mult(w)   # follows Player's light (night fraction)


static func lit(w: Node, pos: Vector2) -> bool:
	var p: Player = w.player
	if p != null and not p.dead and pos.distance_to(p.global_position) < light_reach(w):
		return true
	return AreaGimmicks.lit_at(w, pos)


# ---------------------------------------------------------------- Lantern-Shy Mannequin: moves only in the dark
func area_dummy(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	match e.state:
		"tell":
			if e.t <= 0.0:
				e.state = "lunge"
				e.t = 0.34
				Audio.play("dodge", -2.0, 0.05, 0.8)
		"lunge":
			e._move(e.dir * 200.0 * ddt)
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = float(e.def["cd"]) * randf_range(0.9, 1.3)
		_:
			if lit(e.world, e.global_position):
				if e.state != "still":
					e.state = "still"
					e.spr.play("idle")
					e.spr.pause()
				return
			if e.state == "still":
				e.state = "idle"
				Audio.play("step", -4.0, 0.1, 0.55)
				HouseAI._tip(e, "mannequin", "It only moves in the dark. Keep it in your light, or light a lantern")
			var pd: Vector2 = e.world.room.path_dir(e.global_position, e.global_position + to_p)
			e._walk(ddt, pd, e.speed)
			if dist < 64.0 and dist > 18.0 and e.cd <= 0.0:
				e.state = "tell"
				e.t = 0.6
				e.dir = to_p.normalized()
				var reach := minf(dist + 24.0, 110.0)
				e.tele().line(e.global_position + Vector2(0, -2), _clamp_in(e, e.global_position + e.dir * reach), 0.6, RED)
				e.play_anim("atk", 0.9)
				e._telegraph(Color(1, 0.4, 0.3))


# ---------------------------------------------------------------- Snapping Trunk: a trunk among trunks
func init_area_trunk(e: Enemy) -> void:
	e.state = "shut"
	e.spr.play("idle")
	e.spr.frame = 0
	e.spr.pause()


func area_trunk(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	match e.state:
		"shut":
			e.spr.frame = 0
			if dist < 46.0 or e.hp < e.max_hp:
				e.state = "rattle"
				e.t = 0.55
				e._telegraph(Color(1, 0.45, 0.35))
				Audio.play("chest_open", -4.0, 0.05, 0.7)
				HouseAI._tip(e, "trunk", "That trunk has teeth")
		"rattle":
			e.spr.position.x = sin(e.t * 90.0)
			if e.t <= 0.0:
				e.spr.position.x = 0.0
				e.mem["hops"] = 3
				_trunk_crouch(e)
		"crouch":
			if e.t <= 0.0:
				e.state = "leap"
				e.t = 0.36
				e.dir = to_p.normalized()
				e.play_anim("atk", 0.4)
		"leap":
			e._move(e.dir * e.speed * ddt)
			e._jump_h = sin((1.0 - e.t / 0.36) * PI) * 7.0
			if e.t <= 0.0:
				e._jump_h = 0.0
				Audio.play("thud_heavy", -8.0, 0.1, 1.4)
				e.mem["hops"] = int(e.mem.get("hops", 0)) - 1
				if int(e.mem["hops"]) > 0:
					_trunk_crouch(e)
				else:
					e.state = "rest"
					e.t = 1.4
					e.spr.play("idle")
					e.spr.frame = 0
					e.spr.pause()
		"rest":
			if e.t <= 0.0:
				e.mem["hops"] = 3
				_trunk_crouch(e)


static func _trunk_crouch(e: Enemy) -> void:
	e.state = "crouch"
	e.t = 0.2
	e.spr.play("run")
	BossAI._squash(e, 0.6)


# ================================================================= GUARDIANS

## The phase gate: no burst skips a phase. Damage past the next threshold waits (Enemy._damage's hp_floor, as the
## Keeper's) until the guardian has turned to that phase; a hair under the line, so the phase always changes.
static func _phase_gate(e: Enemy) -> void:
	var thr := 0.66 if e.phase <= 1 else (0.33 if e.phase == 2 else -1.0)
	if thr > 0.0:
		e.mem["hp_floor"] = e.max_hp * (thr - 0.002)
	else:
		e.mem.erase("hp_floor")

# A ball of broth lobbed in an arc: its landing spot is ringed while it flies; it splashes and (later) scalds.
class Glob extends Node2D:
	var world: Node
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var t := 0.0
	var dur := 0.9
	var puddle := false
	var _spr: AnimatedSprite2D

	func _ready() -> void:
		_spr = AnimatedSprite2D.new()
		_spr.sprite_frames = Art.anim("fx/bullet_water", 12.0)
		_spr.play("default")
		_spr.material = Art.unshaded
		add_child(_spr)
		z_index = 5

	func _physics_process(dt: float) -> void:
		if world.finished:
			queue_free()
			return
		if world.freeze_t > 0.0 or Juice.holding(world):
			return
		t += dt * world.time_scale_enemies()
		var k := clampf(t / dur, 0.0, 1.0)
		position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 46.0)
		if k >= 1.0:
			world.burst(to, 6, 60.0, "bullet_water", randf() * TAU)
			if puddle:
				AreaGimmicks.scald(world, to, 3.0, 11.0)
			Audio.play("splash", -4.0, 0.08, 0.9)
			queue_free()


static func _lob(e: Enemy, from: Vector2, to: Vector2, dur: float, puddle: bool) -> void:
	var g := Glob.new()
	g.world = e.world
	g.from = from
	g.to = to
	g.dur = dur
	g.puddle = puddle
	g.position = from
	e.world.fx_layer.add_child(g)
	e.tele().ring(to, 12.0, dur, RED)


# ---------------------------------------------------------------- THE STOCKPOT (the Kitchen)
func area_stockpot(e: Enemy, ddt: float, to_p: Vector2, _dist: float) -> void:
	_phase_gate(e)
	if e.state == "idle" and BossAI._phase_check(e):
		return
	if BossAI._roar(e):
		return
	var rim := e.global_position + Vector2(0, -26)
	match e.state:
		"idle":
			e._walk(ddt, to_p, e.speed * (1.0 + 0.2 * (e.phase - 1)))
			if e.cd <= 0.0:
				e._pattern += 1
				var opts := ["arcs", "spill", "arcs", "pests"]
				if e.phase >= 2:
					opts = ["arcs", "spill", "stir", "arcs", "pests"]
				if e.phase >= 3:
					opts = ["spill", "arcs", "stir", "spill", "pests", "arcs"]
				e.state = opts[(e._pattern - 1) % opts.size()]
				if e.state == "pests" and e.world.count_enemies() >= 4:
					e.state = "arcs"
				match e.state:
					"arcs":
						e.t = 0.6
						e.play_anim("atk", 0.9)
						e._telegraph(Color(1, 0.7, 0.4))
						Audio.play("wax_bubble", 0.0, 0.05, 0.7)
					"spill":
						_spill_tell(e, to_p)
					"stir":
						e.t = 0.7
						e.play_anim("atk", 0.8)
						e._telegraph(Color(1, 0.6, 0.4))
						Audio.play("charge_up", -4.0)
					"pests":
						e.t = 0.6
						e._telegraph(Color(0.8, 1.0, 0.6))
						Audio.play("bell_small", -4.0, 0.05, 0.6)   # the ladles clang
		"arcs":
			if e.t <= 0.0:
				var n := 2 + e.phase
				var p: Vector2 = e.world.player.global_position
				for i in n:
					var tgt := p
					if i > 0:
						tgt = p + Vector2.from_angle(TAU * i / float(n - 1) + randf() * 0.6) * randf_range(26.0, 48.0)
					_lob(e, rim, _clamp_in(e, tgt), 0.85 + 0.1 * i, e.phase >= 2)
				Audio.play("splash", 0.0, 0.05, 0.7)
				e.state = "rest"
				e.t = 0.9
		"spill_tell":
			if e.t <= 0.0:
				_spill(e)
		"stir":
			if e.t <= 0.0:
				e.state = "stirring"
				e.t = 1.6 + 0.4 * (e.phase - 2)
				e._spin = randf() * TAU
				e._wob = 0.0
		"stirring":
			e._wob -= ddt
			if e._wob <= 0.0:
				e._wob = 0.16
				e._spin += 0.42
				var arms := 2 if e.phase < 3 else 3
				for k in arms:
					e.world.enemy_shot(rim + Vector2(0, 10), Vector2.from_angle(e._spin + k * TAU / arms) * 58.0, "bullet_water")
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = 1.2
		"pests":
			if e.t <= 0.0:
				var kinds := ["cinder_rat", "cinder_rat"] if e.phase < 3 else ["lid_crab", "cinder_rat"]
				for i in kinds.size():
					var sx := -1 if i == 0 else 1
					var m: Enemy = e.world.spawn_enemy(kinds[i], e.global_position + Vector2(20 * sx, 8))
					if m:
						m.kvel = Vector2(80 * sx, 30)
				BossAI._squash(e, 1.2)
				e.world.shake(2.0)
				Audio.play("summon", -4.0)
				e.state = "rest"
				e.t = 0.7
		"rest":
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = 2.1 - 0.3 * e.phase


func _spill_tell(e: Enemy, to_p: Vector2) -> void:
	e.state = "spill_tell"
	e.t = 0.85
	var a := to_p.angle()
	var lanes: Array = [a] if e.phase < 3 else [a - 0.4, a + 0.4]
	e.mem["lanes"] = lanes
	for la in lanes:
		var from := e.global_position + Vector2(0, -4)
		e.tele().line(from, _clamp_in(e, from + Vector2.from_angle(la) * 100.0), 0.85, RED)
	e.play_anim("atk", 1.2)
	e._telegraph(Color(1, 0.45, 0.3))
	Audio.play("charge_up", -4.0, 0.05, 0.8)


func _spill(e: Enemy) -> void:
	var lanes: Array = e.mem.get("lanes", [0.0])
	for la in lanes:
		for k in 4:
			var at := _clamp_in(e, e.global_position + Vector2.from_angle(la) * (22.0 + 22.0 * k))
			var w: Node = e.world
			e.later(0.12 * k, func(): AreaGimmicks.scald(w, at, 3.6, 13.0))
		BossAI._fan(e, e.global_position + Vector2(0, -8), la, 3, 0.25, 80.0, "bullet_water")
	Audio.play("splash", 2.0, 0.05, 0.6)
	Audio.play("sizzle", -2.0)
	e.world.shake(3.0)
	BossAI._squash(e, 1.4)
	e.state = "rest"
	e.t = 1.0


# ---------------------------------------------------------------- THE HEAD LIBRARIAN (the Library)
func area_librarian(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	_phase_gate(e)
	if e.state == "idle" and BossAI._phase_check(e):
		return
	if BossAI._roar(e):
		return
	var hand := e.global_position + Vector2(0, -30)
	match e.state:
		"idle":
			var want := Vector2.ZERO
			if dist < 70.0:
				want = -to_p
			elif dist > 110.0:
				want = to_p
			else:
				e._wob += ddt * 0.7
				want = to_p.orthogonal() * (1.0 if sin(e._wob) > 0.0 else -1.0)
			e._walk(ddt, want, e.speed * (1.0 + 0.15 * (e.phase - 1)))
			if e.phase >= 2 and dist < 34.0 and float(e.mem.get("blink", 0.0)) <= 0.0:
				e.mem["blink"] = 3.5
				e._teleport()   # she will not be crowded: a fade and she is elsewhere
			e.mem["blink"] = float(e.mem.get("blink", 0.0)) - ddt
			if e.cd <= 0.0:
				e._pattern += 1
				var opts := ["books", "hush", "books"]
				if e.phase >= 2:
					opts = ["hush", "wall", "books", "hush", "wall"]
				if e.phase >= 3:
					opts = ["hush", "spiral", "wall", "hush", "books", "spiral"]
				e.state = opts[(e._pattern - 1) % opts.size()]
				match e.state:
					"books", "wall", "spiral":
						e.t = 0.55
						e.play_anim("atk", 0.8)
						e._telegraph(Color(1, 0.9, 0.7))
						Audio.play("page_flip", 0.0, 0.05, 0.8)
					"hush":
						e.t = 0.8
						e.play_anim("atk", 1.0)
						e._telegraph(PALE)
						e.world.fx_text(e.global_position + Vector2(0, -56), "Shhh...", PALE)
						var gaps: Array = _hush_gaps(e, to_p)
						e.mem["gaps"] = gaps
						e.tele().ring(e.global_position, 30.0, 0.8, PALE)
						Audio.play("dodge", -2.0, 0.05, 0.5)
		"books":
			if e.t <= 0.0:
				BossAI._fan(e, hand, to_p.angle(), 5, 0.2, 78.0, "bolt_page")
				Audio.play("enemy_shoot", -2.0, 0.05, 0.9)
				if e.phase >= 2:
					e.later(0.35, func():
						var a: float = (e.world.player.global_position - e.global_position).angle()
						BossAI._fan(e, hand, a, 3, 0.3, 84.0, "bolt_page"))
				e.state = "rest"
				e.t = 0.6
		"hush":
			if e.t <= 0.0:
				AreaGimmicks.hush_ring(e.world, e.global_position + Vector2(0, -2), e.mem.get("gaps", []), 66.0 + 6.0 * e.phase)
				HouseAI._tip(e, "hush", "Her hush stops your flame shooting: stand in a gap of the ring")
				if e.phase >= 3:
					e.later(0.9, func():
						AreaGimmicks.hush_ring(e.world, e.global_position + Vector2(0, -2), _hush_gaps(e, e.world.player.global_position - e.global_position), 74.0))
				e.later(0.55, func():
					var a: float = (e.world.player.global_position - e.global_position).angle()
					BossAI._fan(e, hand, a, 3 + e.phase, 0.22, 74.0, "bolt_page"))
				e.state = "rest"
				e.t = 1.0
		"wall":
			if e.t <= 0.0:
				_book_wall(e, to_p)
				if e.phase >= 3:
					e.later(0.75, func(): _book_wall(e, e.world.player.global_position - e.global_position))
				e.state = "rest"
				e.t = 0.8
		"spiral":
			if e.t <= 0.0:
				e.state = "spinning"
				e.t = 2.0
				e._spin = randf() * TAU
				e._wob = 0.0
		"spinning":
			e._wob -= ddt
			if e._wob <= 0.0:
				e._wob = 0.13
				e._spin += 0.33
				for k in 3:
					e.world.enemy_shot(hand, Vector2.from_angle(e._spin + k * TAU / 3.0) * 62.0, "bolt_page")
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = 1.2
		"rest":
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = 2.0 - 0.3 * e.phase


## Gaps in a hush ring: one (two early on), never right where Tallow stands, so he has to move to one.
func _hush_gaps(e: Enemy, to_p: Vector2) -> Array:
	var a := to_p.angle()
	var off := randf_range(0.9, 1.6) * (1.0 if randf() < 0.5 else -1.0)
	var gaps: Array = [a + off]
	if e.phase <= 1:
		gaps.append(a - off * 1.4)
	return gaps


## A wall of books flying at Tallow with a gap two books wide.
func _book_wall(e: Enemy, to_p: Vector2) -> void:
	var d := to_p.normalized()
	var n := d.orthogonal()
	var gap := randi_range(2, 6)
	var base := e.global_position + Vector2(0, -16) - d * 10.0
	for k in 9:
		if k == gap or k == gap + 1:
			continue
		e.world.enemy_shot(base + n * (k - 4) * 13.0, d * 54.0, "bolt_page")
	Audio.play("page_flip", 2.0, 0.05, 0.7)


# ---------------------------------------------------------------- THE DRESSMAKER'S FORM (the Attic)
func area_form(e: Enemy, ddt: float, to_p: Vector2, dist: float) -> void:
	_phase_gate(e)
	if e.state == "idle" and BossAI._phase_check(e):
		return
	if BossAI._roar(e):
		return
	var chest := e.global_position + Vector2(0, -28)
	match e.state:
		"idle":
			e._walk(ddt, to_p if dist > 50.0 else to_p.orthogonal(), e.speed * (1.0 + 0.2 * (e.phase - 1)))
			if e.cd <= 0.0:
				e._pattern += 1
				var opts := ["pins", "dash", "pins"]
				if e.phase >= 2:
					opts = ["sheets", "pins", "dash", "pins"]
				if e.phase >= 3:
					opts = ["dash", "sheets", "pins", "dash", "ring"]
				e.state = opts[(e._pattern - 1) % opts.size()]
				match e.state:
					"pins":
						e.t = 0.5
						e.play_anim("atk", 0.7)
						e._telegraph(Color(1, 0.9, 0.85))
						Audio.play("charge", -4.0, 0.05, 1.4)
					"dash":
						_dash_tell(e, to_p)
					"sheets":
						e.t = 0.6
						e._telegraph(Color(1, 1, 0.9))
						AreaGimmicks.spin_sheets(e, 2 if e.phase < 3 else 3, 3.2)
						Audio.play("moth_flutter", 0.0, 0.05, 0.6)
					"ring":
						e.t = 0.6
						e.tele().ring(e.global_position, 30.0, 0.6, RED)
						e._telegraph(Color(1, 0.5, 0.4))
		"pins":
			if e.t <= 0.0:
				BossAI._fan(e, chest, to_p.angle(), 5, 0.17, 92.0, "bolt_pin")
				Audio.play("enemy_shoot", -2.0, 0.05, 1.3)
				if e.phase >= 2:
					e.later(0.3, func():
						var a: float = (e.world.player.global_position - e.global_position).angle()
						BossAI._fan(e, chest, a, 4, 0.2, 92.0, "bolt_pin"))
				e.state = "rest"
				e.t = 0.6
		"ring":
			if e.t <= 0.0:
				e.world.burst(chest, 14, 70.0, "bolt_pin", randf() * TAU)
				BossAI._fan(e, chest, to_p.angle(), 3, 0.2, 96.0, "bolt_pin")
				Audio.play("enemy_shoot", 0.0, 0.05, 1.2)
				e.state = "rest"
				e.t = 0.7
		"dash_tell":
			e.spr.position.x = sin(e.t * 60.0)
			if e.t <= 0.0:
				e.spr.position.x = 0.0
				e.state = "dash"
				e.t = 1.4
				e.mem["dash_from"] = e.global_position
				Audio.play("dodge", 0.0, 0.05, 0.7)
		"dash":
			var moved := e._move(e.dir * 230.0 * ddt)
			var gone: float = e.global_position.distance_to(e.mem.get("dash_from", e.global_position))
			if not moved or gone >= float(e.mem.get("dash_len", 200.0)) or e.t <= 0.0:
				e.world.shake(3.0)
				Audio.play("thud_heavy", -2.0, 0.05, 1.1)
				if e.phase >= 2:
					e.world.burst(chest, 8, 64.0, "bolt_pin", randf() * TAU)
				e.mem["dashes"] = int(e.mem.get("dashes", 0)) + 1
				if e.phase >= 3 and int(e.mem["dashes"]) % 2 == 1:
					_dash_tell(e, e.world.player.global_position - e.global_position)
				else:
					e.state = "rest"
					e.t = 0.8
		"sheets":
			if e.t <= 0.0:
				e.state = "rest"
				e.t = 0.5
		"rest":
			if e.t <= 0.0:
				e.state = "idle"
				e.cd = 1.9 - 0.25 * e.phase


## The sewing-needle dash: a red lane to the wall first, then it runs the lane.
func _dash_tell(e: Enemy, to_p: Vector2) -> void:
	e.state = "dash_tell"
	e.t = 0.85 if e.phase < 3 else 0.62
	e.dir = to_p.normalized()
	var r: Rect2 = e.world.room.inner_rect().grow(-e.radius)
	var from := e.global_position
	var len := 0.0
	while len < 240.0 and r.has_point(from + e.dir * (len + 4.0)):
		len += 4.0
	e.mem["dash_len"] = len
	e.tele().line(from + Vector2(0, -4), from + e.dir * len + Vector2(0, -4), e.t, RED)
	e.play_anim("atk", e.t + 1.2)
	e._telegraph(Color(1, 0.4, 0.3))
	Audio.play("charge_up", -4.0, 0.05, 1.2)
