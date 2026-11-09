class_name RelicFx
extends Node2D
## Everything a relic does beyond changing a stat: shot modifiers (split, bounce, smoke-ring
## boomerangs, fans, chain sparks, crits), attacks that replace firing (the Blowlamp jet, the Stove
## Door charge), curses on hit (hard wax, fright, charm, poison), little helpers, defences, clock
## relics, unlabelled tonics and the new keepsakes.
##
## One instance per run, a child of the world (RelicFx.of(world)). The rest of the game only calls
## the static hooks below, one line each:
##   Player._fire        before_fire() / after_fire()     Player.hurt   on_hurt()
##   Shot (wall / hit)   shot_wall() / shot_hit()         world.shoot_player  on_shot_made()
##   world               on_enter_room() on_clear() on_kill() next_relic() on_blast()
## Hard caps keep entity counts sane however relics stack (MAX_SHOTS, one helper of each kind).

const MAX_SHOTS := 80          # no split shards / extra sparks past this many live player shots
const MAX_SPARKS := 36         # tinderbox sparks alive at once
const MAX_JET := 90            # flame-jet particles
const CURSE := {
	# relic: [status, chance per hit, seconds]
	"cold_wax": ["slow", 0.3, 2.2],
	"shadow_puppet": ["fear", 0.14, 1.8],
	"love_letter": ["charm", 0.09, 3.0],
	"nightshade": ["poison", 0.3, 4.0],
}
const STATUS_KINDS := ["slow", "fear", "charm", "poison", "stun"]
const FIRE_COLS := [Color("#fdf7ed"), Color("#facb3e"), Color("#ee8e2e"), Color("#da4e38"), Color("#8f4029")]
const BLUE_COLS := [Color("#cae6f5"), Color("#72d6ce"), Color("#5698cc"), Color("#5956bd"), Color("#417089")]
const PALE_COLS := [Color("#fdf7ed"), Color("#cae6f5"), Color("#b6cbcf"), Color("#7b8994"), Color("#483b3a")]

## Unlabelled tonics: each run the eight flask colours hide eight of these (seeded by the run seed).
const TONIC_FX := {
	"ember": {"name": "Ember Tonic", "desc": "+damage", "good": 1},
	"quick": {"name": "Quickening", "desc": "You fire faster", "good": 1},
	"fleet": {"name": "Fleetfoot", "desc": "You move faster", "good": 1},
	"long": {"name": "Long Wick", "desc": "Shots fly further", "good": 1},
	"ten": {"name": "Ten Minutes", "desc": "Wax comes back: +10 min", "good": 1},
	"big_flame": {"name": "Big Flame", "desc": "Bigger, heavier shots", "good": 1},
	"tallow": {"name": "Tallow Draught", "desc": "+8 max minutes", "good": 1},
	"feather": {"name": "Feather", "desc": "Smaller, faster shots", "good": 0},
	"hot_head": {"name": "Hot Head", "desc": "+damage, but you melt faster", "good": 0},
	"leaden": {"name": "Leaden", "desc": "Your feet turn heavy", "good": -1},
	"fog": {"name": "Fog", "desc": "Your light is short this floor", "good": -1},
	"sputter": {"name": "Sputter", "desc": "Your flame gutters: -3 min", "good": -1},
	"butterfingers": {"name": "Butterfingers", "desc": "Coins slip from your dish", "good": -1},
}
const FLASKS := ["flask_red", "flask_blue", "flask_green", "flask_yellow",
	"flask_big_red", "flask_big_blue", "flask_big_green", "flask_big_yellow"]

static var _cur: RelicFx
static var _primary := false     # true while Player._fire makes its volley
static var _spawning := false    # true while we make child shots (they never split again)
static var _big := false         # the shot being made is a full Stove Door flame
static var _last_shot: Shot
static var live_shots := 0

var world: Node
var p: Player
var has := {}                    # relic id -> true
var helper_mult := 1.0
# tonics
var tonic_map := {}
var known := {}
var fog_floor := -1
var fog_mult := 1.0
# attacks
var charge := 0.0
var _charge_dir := Vector2.RIGHT
var _charge_snd := false
var _jet_on := false
var _jet_tick := 0.0
var _jet_snd := 0.0
var _jet_len := 0.0
var _jet_dir := Vector2.RIGHT
var _jet_origin := Vector2.ZERO
var _jet_parts: Array = []      # [pos, vel, life, max]
var _jet_light: PointLight2D
# defence
var chimney_ready := true
var chimney_t := 0.0
var brooch := 0
var mirror_t := 0.0
var salt_t := 0.0
var _salt_at := Vector2.ZERO
# clock
var cuckoo_max := 0
var pendulum_on := false
var magpie_f := 1.0
# curses
var afflicted: Array = []
# helpers
var fams: Array = []             # Dictionaries
var mouse_t := 1.5
var sweep_t := 0.0
var sweep_delay := 0.0
var _steer: Array = []           # boomerang / swarm shots
var _zaps: Array = []            # chain lightning [points, t]
var _floor := -1
var _frame := 0


## The current run's instance (made on first use).
static func of(w: Node) -> RelicFx:
	if is_instance_valid(_cur) and _cur.world == w:
		return _cur
	var fx := RelicFx.new()
	fx.world = w
	fx.p = w.player
	fx.name = "RelicFx"
	fx.z_index = 21
	fx.material = Art.unshaded
	_cur = fx
	live_shots = 0
	fx._roll_tonics()
	w.add_child(fx)
	return fx


static func _inst() -> RelicFx:
	return _cur if is_instance_valid(_cur) else null


func _ready() -> void:
	_jet_light = PointLight2D.new()
	_jet_light.texture = Art.light_tex
	_jet_light.texture_scale = 0.5
	_jet_light.energy = 0.0
	_jet_light.color = Color(1.0, 0.7, 0.35)
	add_child(_jet_light)
	Lighting.haze(_jet_light, Vector2(-12, -9), Vector2(24, 12), _jet_light)


# ================================================================ relic pool

## world._next_relic(): a weighted pick for the room you are in (treasure, shop, boss, altar, hollow).
static func next_relic(w: Node) -> String:
	return of(w)._pick_relic()


func _pick_relic() -> String:
	var pool := "treasure"
	if world.room:
		match String(world.room.data.get("type", "")):
			"shop": pool = "shop"
			"secret": pool = "hollow"
			"boss": pool = "altar" if world.room.data.get("altar", false) else "boss"
	var cand: Array = []
	var wts: Array = []
	var total := 0.0
	for pass_i in 2:
		for id in world.relic_pool:
			if not Items.RELICS.has(id) or id in p.relics or _excluded(id):
				continue
			var d: Dictionary = Items.RELICS[id]
			if pass_i == 0 and not pool in d.get("pools", []):
				continue
			var wt := _weight(int(d.get("q", 1)), pool)
			cand.append(id)
			wts.append(wt)
			total += wt
		if not cand.is_empty():
			break
	if cand.is_empty():
		return "flask_red"
	var r: float = world.rng.randf() * total
	var pick: String = cand[cand.size() - 1]
	for i in cand.size():
		r -= wts[i]
		if r <= 0.0:
			pick = cand[i]
			break
	world.relic_pool.erase(pick)
	return pick


func _weight(q: int, pool: String) -> float:
	var w: float = [10.0, 8.0, 5.5, 3.0, 1.4][clampi(q, 0, 4)]
	if q >= 3:
		w *= 1.0 + 0.2 * ((world.depth() if world.has_method("depth") else float(world.floor_num)) - 1.0)   # by depth (v2.2)
	match pool:
		"boss":
			w *= [0.35, 0.7, 1.0, 1.3, 1.6][clampi(q, 0, 4)]
		"altar":
			w *= [0.1, 0.2, 1.0, 1.4, 2.0][clampi(q, 0, 4)]
		"shop":
			w *= [1.3, 1.1, 1.0, 0.8, 0.6][clampi(q, 0, 4)]
	return w


func _excluded(id: String) -> bool:
	for h in p.relics:
		if Items.EXCLUSIVE.has(h) and id in Items.EXCLUSIVE[h]:
			return true
	return false


# ================================================================ taking relics

func on_relic(id: String) -> void:
	has[id] = true
	match id:
		"house_deed":
			_reveal_rooms()
		"dowsing_rod":
			_reveal_hollows()
			_mark_hollow_walls()
		"warming_pan":
			for k in 3:
				_add_fam("coal", k)
		"matchling":
			_add_fam("matchling", 0)
		"paper_lantern":
			_add_fam("lantern", 0)
		"dust_bunny":
			_add_fam("bunny", 0)
		"glass_chimney":
			chimney_ready = true
		"cuckoo_clock":
			cuckoo_max = int(world.clock_minutes() / 15.0)
		"stove_door", "blowlamp":
			if Game.tip(id):
				world.hud.show_hint("Hold the right thumb to stoke it" if id == "stove_door" else "Hold the right thumb: a jet of flame", 3.0)
	if has.has("magpie_nest"):
		var f := 1.0 + 0.04 * p.relics.size()
		p.damage = p.damage / magpie_f * f
		magpie_f = f
		world.fx_text(p.global_position + Vector2(0, -46), "the nest grows: +%d%%" % int(round((f - 1.0) * 100.0)), UI.GOLD)


func on_rite(r: String) -> void:
	match r:
		"household":
			helper_mult = 1.5
			if has.has("matchling") or _count_fam("matchling") == 0:
				_add_fam("matchling", 1)
		"seance":
			pass   # curse rolls read p.rites


# ================================================================ firing

static func before_fire(pl: Player, _dir: Vector2) -> bool:
	var fx := _inst()
	if fx == null or fx.p != pl:
		return false
	if fx.has.has("blowlamp") or fx.has.has("stove_door"):
		return true   # the jet / the charge own the trigger
	_primary = true
	return false


static func after_fire(pl: Player, dir: Vector2) -> void:
	var fx := _inst()
	if fx == null or fx.p != pl:
		_primary = false
		return
	if fx.has.has("lace_fan"):
		fx._fan(dir, fx._shot_dmg() * 0.75)
	_primary = false
	if fx.brooch > 0:
		fx.brooch -= 1


func _shot_dmg() -> float:
	return p.damage * (1.6 if p.witching and p.wax < 30.0 else 1.0)


func _fan(dir: Vector2, dmg: float) -> void:
	var a := 20.0 if p.shots < 3 else 26.0
	for sgn in [-1.0, 1.0]:
		world.shoot_player(p.global_position + Vector2(0, -6) + dir * 4, dir.rotated(deg_to_rad(a * sgn)), p, dmg)


## world.shoot_player(): every friendly shot passes through here once it is set up.
static func on_shot_made(s: Shot, _pl: Player) -> void:
	_last_shot = s
	live_shots += 1
	s.tree_exiting.connect(func(): RelicFx.live_shots -= 1)
	var fx := _inst()
	if fx == null or fx.world != s.world:
		return
	fx._mod_shot(s, _primary and not _spawning)
	_last_shot = s   # children made inside _mod_shot must not hide the shot that was asked for


func _mod_shot(s: Shot, primary: bool) -> void:
	if has.has("tin_sconce"):
		s.set_meta("bounce", 2)
	if has.has("pale_taper"):
		s.set_meta("ghost", true)
		_set_frames(s, "items/fx/ghost")
		if s.light:
			s.light.color = Color(0.75, 0.85, 1.0)
	if not primary:
		return
	s.set_meta("gen", 0)
	if brooch > 0:
		s.dmg *= 2.0
		s.spr.modulate = Color(1.0, 0.55, 0.75)
	if has.has("wick_trimmer") and randf() < 0.2:
		s.dmg *= 3.0
		s.set_meta("crit", true)
		_set_frames(s, "fx/ember_big")
		s.radius += 1.0
	if has.has("old_pipe"):
		var v0 := s.vel.length()
		# slows to a stop at about the normal range, hangs there a moment, then comes home
		var out_t := maxf(0.3, 1.8 * p.shot_range / maxf(v0, 1.0))
		s.set_meta("boom", {"dir": s.vel.normalized(), "v0": v0, "decel": v0 / out_t, "back": false})
		s.life = out_t * 2.4 + 0.5
		s.pierce += 1
		if not has.has("pale_taper"):
			_set_frames(s, "items/fx/ring")
		_steer.append(s)
	if has.has("tinderbox"):
		_swarm(s)


func _set_frames(s: Shot, prefix: String) -> void:
	if s.spr and Art.has(prefix + "_f0"):
		s.spr.sprite_frames = Art.anim(prefix, 12.0)
		s.spr.play("default")


## Tinderbox: the shot breaks into a little swarm of seeking sparks.
func _swarm(s: Shot) -> void:
	var extra := 7 if _big else 2
	if not _big:
		s.dmg *= 0.5
		s.life *= 1.5
		_set_frames(s, "items/fx/spark_blue" if p.blue else "items/fx/spark")
		s.set_meta("swarm", randf() * TAU)
		_steer.append(s)
	var n := 0
	for st in _steer:
		if is_instance_valid(st) and st.has_meta("swarm"):
			n += 1
	for k in extra:
		if n >= MAX_SPARKS or live_shots >= MAX_SHOTS:
			break
		var a := s.vel.angle() + (k - (extra - 1) / 2.0) * (0.45 if not _big else 0.7)
		var c := _child(s.global_position, Vector2.from_angle(a), s.dmg * (0.35 if _big else 1.0), "items/fx/spark_blue" if p.blue else "items/fx/spark")
		if c:
			c.life = s.life if not _big else 1.6
			c.vel *= randf_range(0.85, 1.12)   # so the swarm never flies in a neat line
			c.set_meta("swarm", randf() * TAU)
			_steer.append(c)
			n += 1


## A child shot (split shard, spark, reflected shot). It never splits again.
func _child(pos: Vector2, dir: Vector2, dmg: float, frames := "") -> Shot:
	_spawning = true
	_last_shot = null
	world.shoot_player(pos, dir, p, dmg)
	_spawning = false
	var c := _last_shot
	if c == null or not is_instance_valid(c):
		return null
	c.position = pos
	c.vel = dir * p.shot_speed
	c.set_meta("gen", 1)
	if frames != "":
		_set_frames(c, frames)
	return c


# ================================================================ shots in flight

## Shot hit a wall or a solid obstacle: true = keep flying (bounce, ghost).
static func shot_wall(s: Shot) -> bool:
	if not s.friendly:
		return false
	var room: Room = s.world.room
	if room == null:
		return false
	if s.has_meta("ghost"):
		var lp := s.global_position - room.position
		return lp.x > 4.0 and lp.x < Room.W - 4.0 and lp.y > 4.0 and lp.y < Room.H - 4.0
	var b := int(s.get_meta("bounce", 0))
	if b <= 0:
		return false
	s.set_meta("bounce", b - 1)
	var dt := s.get_physics_process_delta_time()
	var prev := s.global_position - s.vel * dt
	var g := Vector2(0, 6)
	var hx := _solid(room, Vector2(s.global_position.x, prev.y) + g)
	var hy := _solid(room, Vector2(prev.x, s.global_position.y) + g)
	if hx:
		s.vel.x = -s.vel.x
	if hy:
		s.vel.y = -s.vel.y
	if not hx and not hy:
		s.vel = -s.vel
	s.global_position = prev
	s._hit.clear()
	if s.has_meta("boom"):
		s.get_meta("boom")["back"] = true
	Audio.play("hit_wall", -9.0, 0.1, 1.7)
	return true


## Pure wall/obstacle test (Room.shot_hits without breaking anything).
static func _solid(room: Room, wp: Vector2) -> bool:
	var lp := wp - room.position
	if lp.x < Room.IN.x or lp.x > Room.IN.x + Room.COLS * Room.TILE or lp.y < Room.IN.y - 4 or lp.y > Room.IN.y + Room.ROWS * Room.TILE:
		return true
	var c := room.cell_of(lp)
	if room.char_at(c) in Room.SHOT_SOLID:
		var rect := Rect2(Room.IN + Vector2(c.x * Room.TILE + 2, c.y * Room.TILE + 2), Vector2(Room.TILE - 4, Room.TILE - 3))
		return rect.has_point(lp)
	return false


## A friendly shot just hit `e` (after take_hit).
static func shot_hit(s: Shot, e: Enemy) -> void:
	var fx := _inst()
	if fx == null or fx.world != s.world:
		return
	fx._on_hit(s, e)


func _on_hit(s: Shot, e: Enemy) -> void:
	var gen := int(s.get_meta("gen", -1))
	if s.has_meta("crit"):
		world.fx_text(s.global_position + Vector2(0, -10), "SNIP", UI.GOLD)
		Audio.play("hit_wall", -2.0, 0.05, 2.0)
	if has.has("fire_tongs") and randf() < 0.22:
		status(e, "stun", 0.45)
	_curse_roll(e, 1.0)
	if gen != 0 or live_shots >= MAX_SHOTS:
		return
	if has.has("split_wick"):
		var base := s.vel.angle()
		for k in 3:
			var c := _child(s.global_position, Vector2.from_angle(base + (k - 1) * 0.6), s.dmg * 0.4, "items/fx/spark_blue" if p.blue else "items/fx/spark")
			if c:
				c._hit[e] = true
				c.life = 0.45
				c.pierce = 0
	if has.has("bell_wire"):
		_chain(e, s.dmg * 0.5, 2)


## Bell Wire: a spark jumps from foe to foe.
func _chain(from: Enemy, dmg: float, jumps: int) -> void:
	var pts: Array = [from.global_position + Vector2(0, -from.half_h)]
	var done := {from: true}
	var cur := from
	for j in jumps:
		var best: Enemy = null
		var bd := 76.0 * 76.0
		for o in world.enemies:
			if not is_instance_valid(o) or not o.alive or not o.active or done.has(o):
				continue
			var d: float = o.global_position.distance_squared_to(cur.global_position)
			if d < bd:
				bd = d
				best = o
		if best == null:
			break
		done[best] = true
		pts.append(best.global_position + Vector2(0, -best.half_h))
		best.take_hit(dmg, Vector2.ZERO, 0.0)
		cur = best
	if pts.size() > 1:
		_zaps.append([pts, 0.16])
		Audio.play("tick", -6.0, 0.1, 2.2)


func _tick_steer(dt: float) -> void:
	var i := _steer.size() - 1
	while i >= 0:
		var s: Shot = _steer[i] if is_instance_valid(_steer[i]) else null
		if s == null or s._dead:
			_steer.remove_at(i)
			i -= 1
			continue
		if s.has_meta("boom"):
			var st: Dictionary = s.get_meta("boom")
			if not st["back"]:
				s.vel -= st["dir"] * st["decel"] * dt
				if s.vel.dot(st["dir"]) <= 0.0:
					st["back"] = true
					s._hit.clear()
			else:
				var to := p.global_position + Vector2(0, -6) - s.global_position
				if to.length() < 7.0:
					s.end()
				else:
					s.vel = s.vel.move_toward(to.normalized() * st["v0"], st["v0"] * 4.0 * dt)
		elif s.has_meta("swarm"):
			var ph: float = s.get_meta("swarm")
			var spd := maxf(90.0, s.vel.length())
			var tgt: Enemy = world.nearest_enemy(s.global_position, 150.0)
			var want := s.vel.normalized()
			if tgt:
				want = (tgt.global_position + Vector2(0, -tgt.half_h) - s.global_position).normalized()
			want = (want + want.orthogonal() * sin(Time.get_ticks_msec() * 0.012 + ph) * 0.55).normalized()
			s.vel = s.vel.lerp(want * spd, minf(1.0, dt * 6.0))
		i -= 1


# ================================================================ curses

func _curse_roll(e: Enemy, mult: float) -> void:
	if not is_instance_valid(e) or not e.alive:
		return
	var sea := "seance" in p.rites
	for id in CURSE:
		if has.has(id):
			var c: Array = CURSE[id]
			if randf() < float(c[1]) * mult * (2.0 if sea else 1.0):
				status(e, c[0], float(c[2]) * (1.4 if sea else 1.0))


## Put a status on a foe: slow (hard wax), fear, charm, poison or stun. Bosses only ever slow.
func status(e: Enemy, kind: String, dur: float) -> void:
	if not is_instance_valid(e) or not e.alive or not e.active:
		return
	if e.boss:
		if kind == "stun" or kind == "poison":
			if kind == "stun":
				return
		elif kind != "slow":
			kind = "slow"
			dur *= 0.5
	if kind == "fear" and float(e.get("_jump_h") if e.get("_jump_h") != null else 0.0) > 2.0:
		return
	var st: Dictionary = e.get_meta("rfx_st", {})
	if st.is_empty():
		e.set_meta("rfx_st", st)
		afflicted.append(e)
		var mark := StatusMark.new()
		mark.e = e
		mark.st = st
		mark.z_index = 4
		mark.material = Art.unshaded
		e.add_child(mark)
		st["_mark"] = mark
	var fresh := float(st.get(kind, 0.0)) <= 0.0
	st[kind] = maxf(float(st.get(kind, 0.0)), dur)
	if fresh:
		match kind:
			"charm":
				world.fx_text(e.global_position + Vector2(0, -e.half_h * 2.5 - 8), "charmed", Color("#f78697"))
			"fear":
				Audio.play("teleport", -10.0, 0.1, 1.8)
			"slow":
				Audio.play("hit_wall", -8.0, 0.1, 0.6)


func _tick_status(dt: float) -> void:
	var i := afflicted.size() - 1
	while i >= 0:
		if i >= afflicted.size():
			i -= 1
			continue
		var e: Enemy = afflicted[i] if is_instance_valid(afflicted[i]) else null
		if e == null:
			afflicted.remove_at(i)
			i -= 1
			continue
		var st: Dictionary = e.get_meta("rfx_st", {})
		if not e.alive or st.is_empty():
			_end_status(e, st)
			afflicted.remove_at(i)
			i -= 1
			continue
		var any := false
		for k in STATUS_KINDS:
			var v := float(st.get(k, 0.0))
			if v > 0.0:
				v -= dt
				st[k] = v
				if v > 0.0:
					any = true
		var feared := float(st.get("fear", 0.0)) > 0.0
		var run := true
		if float(st.get("stun", 0.0)) > 0.0 or feared:
			run = false
		elif float(st.get("slow", 0.0)) > 0.0:
			run = (_frame % (4 if e.boss else 2)) != 0
		if e.is_physics_processing() != run:
			e.set_physics_process(run)
		if not run:
			var fl = e.get("_flash")
			if fl != null and float(fl) > 0.0:
				e.set("_flash", maxf(0.0, float(fl) - dt * 6.0))
				var m = e.get("mat")
				if m is ShaderMaterial:
					m.set_shader_parameter("flash", e.get("_flash"))
		if feared:
			_flee(e, dt)
			st["shook"] = true
		elif st.get("shook", false):
			st.erase("shook")
			if e.spr:
				e.spr.position.x = 0.0
		if float(st.get("charm", 0.0)) > 0.0:
			_charm_step(e, st, dt)
		elif st.get("was_charmed", false):
			st.erase("was_charmed")
			e.active = true
		if float(st.get("poison", 0.0)) > 0.0:
			st["ptick"] = float(st.get("ptick", 0.5)) - dt
			if float(st["ptick"]) <= 0.0:
				st["ptick"] = 0.5
				if e.has_method("_damage"):
					e._damage(0.35 + p.damage * 0.22, false)
		if not e.boss and is_instance_valid(e):
			e.modulate = _tint(st)
		var mk = st.get("_mark")
		if is_instance_valid(mk):
			mk.queue_redraw()
		if not any and is_instance_valid(e):
			_end_status(e, st)
			afflicted.erase(e)
		i -= 1


func _tint(st: Dictionary) -> Color:
	if float(st.get("charm", 0.0)) > 0.0:
		return Color(1.0, 0.72, 0.86)
	if float(st.get("fear", 0.0)) > 0.0:
		return Color(0.8, 0.72, 0.95)
	if float(st.get("poison", 0.0)) > 0.0:
		return Color(0.74, 1.0, 0.66)
	if float(st.get("slow", 0.0)) > 0.0 or float(st.get("stun", 0.0)) > 0.0:
		return Color(0.86, 0.88, 0.96)
	return Color.WHITE


func _end_status(e: Enemy, st: Dictionary) -> void:
	if not is_instance_valid(e):
		return
	e.set_physics_process(true)
	if not e.boss:
		e.modulate = Color.WHITE
		if e.spr:
			e.spr.position.x = 0.0
	if st.get("was_charmed", false):
		e.active = true
	var mk = st.get("_mark")
	if is_instance_valid(mk):
		mk.queue_free()
	if e.has_meta("rfx_st"):
		e.remove_meta("rfx_st")


func _flee(e: Enemy, dt: float) -> void:
	var away := e.global_position - p.global_position
	if away.length() < 0.1:
		away = Vector2.RIGHT
	var spd: float = maxf(float(e.speed), 30.0) * 1.15 * world.time_scale_enemies()
	if e.has_method("_move"):
		var d := away.normalized() * spd * dt
		if not e._move(d):
			if not e._move(d.rotated(1.2)):
				e._move(d.rotated(-1.2))
		if e.kvel.length() > 1.0:
			e._move(e.kvel * dt)
			e.kvel = e.kvel.move_toward(Vector2.ZERO, 500.0 * dt)
	if e.spr and not e.boss:
		e.spr.position.x = 1.0 if (_frame / 3) % 2 == 0 else 0.0


func _charm_step(e: Enemy, st: Dictionary, dt: float) -> void:
	st["was_charmed"] = true
	e.active = false
	var tgt: Enemy = null
	var bd := 220.0 * 220.0
	for o in world.enemies:
		if o == e or not is_instance_valid(o) or not o.alive or not o.active:
			continue
		var d: float = o.global_position.distance_squared_to(e.global_position)
		if d < bd:
			bd = d
			tgt = o
	if tgt == null:
		st["charm"] = 0.0
		e.active = true
		st.erase("was_charmed")
		return
	var to := tgt.global_position - e.global_position
	if e.has_method("_move") and to.length() > e.radius + tgt.radius:
		e._move(to.normalized() * maxf(float(e.speed), 32.0) * 1.25 * dt)
	st["bite"] = float(st.get("bite", 0.0)) - dt
	if to.length() < e.radius + tgt.radius + 4.0 and float(st["bite"]) <= 0.0:
		st["bite"] = 0.45
		tgt.take_hit((1.2 + p.damage * 0.8) * helper_mult, to.normalized() * 80.0, 0.0)


# ================================================================ hurt / defence

## Player.hurt(): true = the hit never lands (dodged or blocked).
static func on_hurt(pl: Player, _amount: float, _from_dir: Vector2) -> bool:
	var fx := _inst()
	if fx == null or fx.p != pl:
		return false
	return fx._hurt()


func _hurt() -> bool:
	var at := p.global_position + Vector2(0, -26)
	if has.has("thimble") and randf() < 0.2:
		p.invuln = 0.5
		world.fx_text(at, "SLIPPED BY", UI.CREAM)
		Audio.play("teleport", -6.0, 0.1, 1.6)
		return true
	if has.has("glass_chimney") and chimney_ready:
		chimney_ready = false
		chimney_t = 20.0
		p.invuln = 0.8
		world.fx_text(at, "THE GLASS TAKES IT", Color("#cae6f5"))
		world.fx_ring(p.global_position + Vector2(0, -14), Color("#b6cbcf"))
		Audio.play("hit_wall", 2.0, 0.05, 1.8)
		for k in 5:
			world.fx_drop(p.global_position + Vector2(0, -16), Vector2.from_angle(randf_range(-PI, 0)) * randf_range(30, 60))
		return true
	if p.wax_coat and p.coat_ready:
		return false   # the coat will block it: not a real hit
	if has.has("scalding_wax"):
		var hit := false
		for e in world.enemies:
			if is_instance_valid(e) and e.alive and e.active and e.global_position.distance_to(p.global_position) < 26.0 + e.radius:
				e.take_hit(2.0 + p.damage, (e.global_position - p.global_position).normalized() * 120.0, 2.5)
				hit = true
		world.fx_ring(p.global_position + Vector2(0, -6), UI.EMBER)
		if hit:
			world.fx_text(p.global_position + Vector2(0, -40), "SCALDED", UI.EMBER)
	if has.has("stopped_clock"):
		world.freeze_t = maxf(world.freeze_t, 1.5)
		Audio.play("tick", 0.0, 0.0, 0.6)
		world.fx_text(p.global_position + Vector2(0, -40), "tick...", UI.GOLD)
	if has.has("jet_brooch"):
		brooch = 6
	return false


## v2.3: the candle used its special move (Moves.use; `id` is a key of Moves.LIST). The hook for
## move synergies. Two to start: the Jet Brooch charges two strong shots, and a Glass Chimney that
## is regrowing comes back 4 s sooner.
static func on_move(pl: Player, id: String) -> void:
	var fx := _inst()
	if fx == null or fx.p != pl:
		return
	fx._moved(id)


func _moved(_id: String) -> void:
	if has.has("jet_brooch"):
		brooch = maxi(brooch, 2)
	if has.has("glass_chimney") and not chimney_ready:
		chimney_t = maxf(0.0, chimney_t - 4.0)


func _tick_defence(dt: float) -> void:
	if has.has("glass_chimney") and not chimney_ready:
		chimney_t -= dt
		if chimney_t <= 0.0:
			chimney_ready = true
			world.fx_ring(p.global_position + Vector2(0, -18), Color("#cae6f5"))
			Audio.play("tick", -4.0, 0.0, 2.0)
	salt_t = maxf(0.0, salt_t - dt)
	if mirror_t > 0.0:
		mirror_t -= dt
		var c := p.global_position + Vector2(0, -8)
		for s in world.enemy_shots:
			if is_instance_valid(s) and not s._dead and s.global_position.distance_to(c) < 30.0:
				var tgt: Enemy = world.nearest_enemy(s.global_position, 200.0)
				var dir: Vector2 = (tgt.global_position + Vector2(0, -tgt.half_h) - s.global_position).normalized() if tgt else -s.vel.normalized()
				var r := _child(s.global_position, dir, 1.5 + p.damage, "items/fx/spark")
				if r:
					r.life = 1.2
				s.end()


# ================================================================ rooms, kills, floors

static func on_enter_room(w: Node) -> void:
	of(w)._entered()


func _entered() -> void:
	if world.floor_num != _floor:
		_floor = world.floor_num
		if has.has("house_deed"):
			_reveal_rooms()
		if has.has("dowsing_rod"):
			_reveal_hollows()
	charge = 0.0
	if has.has("dowsing_rod"):
		_mark_hollow_walls()
	if has.has("salt_line") and not world.room.data["cleared"]:
		p.invuln = maxf(p.invuln, 2.0)
		salt_t = 2.0
		_salt_at = p.global_position
	for f in fams:
		f["pos"] = p.global_position + Vector2(randf_range(-8, 8), randf_range(-4, 4))


static func on_clear(w: Node) -> void:
	var fx := _inst()
	if fx == null or fx.world != w:
		return
	fx._cleared()


func _cleared() -> void:
	var d: Dictionary = world.room.data
	var c: Vector2 = world.room.center()
	if d["type"] == "normal":
		if has.has("collection_plate"):
			for k in world.rng.randi_range(1, 2):
				world.add_pickup("coin", c, "", 0, Vector2.from_angle(world.rng.randf() * TAU) * 40.0)
		if has.has("pantry_key") and world.rng.randf() < 0.3:
			world.add_pickup("chest", world.free_spot_near(c + Vector2(0, 22), 8.0))
	if has.has("sweep_brush"):
		sweep_delay = 0.6
		sweep_t = 2.6


static func on_kill(w: Node, e: Enemy) -> void:
	var fx := _inst()
	if fx == null or fx.world != w:
		return
	fx._killed(e)


func _killed(e: Enemy) -> void:
	if has.has("minute_hand"):
		p.heal(0.07)
		world.fx_text(e.global_position + Vector2(0, -e.half_h * 2.5 - 4), "+4s", UI.CREAM)
	if has.has("bell_rope") and e.boss:
		p.heal(5.0)
		world.fx_text(p.global_position + Vector2(0, -44), "THE BELL ROPE: +5 min", UI.GOLD)
		Audio.play("bell_toll", 0.0, 0.0, 1.15)
	if has.has("honeycomb") and not e.boss and world.rng.randf() < 0.06:
		world.add_pickup("wax_small", e.global_position, "", 0, Vector2.from_angle(world.rng.randf() * TAU) * 20.0)
	var st: Dictionary = e.get_meta("rfx_st", {})
	if float(st.get("poison", 0.0)) > 0.0 and has.has("nightshade"):
		for o in world.enemies:
			if o != e and is_instance_valid(o) and o.alive and o.global_position.distance_to(e.global_position) < 40.0:
				status(o, "poison", 3.0)


static func on_blast(w: Node, pos: Vector2) -> void:
	var fx := _inst()
	if fx == null or fx.world != w or not fx.has.has("powder_tin"):
		return
	w.spawn_hot_drip(pos)
	for k in 6:
		w.spawn_hot_drip(pos + Vector2.from_angle(TAU * k / 6.0) * 15.0)


func _reveal_rooms() -> void:
	for c in world.layout["cells"].keys():
		var d: Dictionary = world.layout["cells"][c]
		if d["type"] != "secret":
			d["seen"] = true


func _reveal_hollows() -> void:
	for c in world.layout["cells"].keys():
		var d: Dictionary = world.layout["cells"][c]
		if d["type"] == "secret":
			d["seen"] = true


## Dowsing Rod: a shimmer on the cracked wall that hides a hollow.
func _mark_hollow_walls() -> void:
	if world.room == null:
		return
	var slot := {Vector2i.UP: Vector2(136, 18), Vector2i.DOWN: Vector2(136, 182), Vector2i.LEFT: Vector2(8, 104), Vector2i.RIGHT: Vector2(264, 104)}
	for dir in slot.keys():
		var nc: Vector2i = world.cur_cell + dir
		if world.layout["cells"].has(nc):
			var nd: Dictionary = world.layout["cells"][nc]
			if nd["type"] == "secret" and not nd.get("revealed", false):
				var sh := Shimmer.new()
				sh.cell = nd
				sh.position = slot[dir]
				sh.material = Art.unshaded
				sh.z_index = 3
				world.room.objects.add_child(sh)


# ================================================================ chests, pickups, tonics

static func on_chest(w: Node, pos: Vector2) -> void:
	var fx := _inst()
	if fx == null or fx.world != w or not fx.has.has("pantry_key"):
		return
	var k := "wax_small" if w.rng.randf() < 0.5 else "coin"
	w.add_pickup(k, pos + Vector2(0, 4), "", 0, Vector2.from_angle(w.rng.randf() * TAU) * 55.0)
	w.add_pickup("coin", pos + Vector2(0, 4), "", 0, Vector2.from_angle(w.rng.randf() * TAU) * 55.0)


## How hard loose pickups are pulled to Tallow: [radius, speed].
static func pull(w: Node) -> Vector2:
	var fx := _inst()
	var r := 22.0 if w.player.luck > 0.0 else 0.0
	var spd := 40.0
	if fx and fx.world == w:
		if fx.sweep_t > 0.0 and fx.sweep_delay <= 0.0:
			return Vector2(999.0, 170.0)
		if fx.has.has("lodestone"):
			return Vector2(70.0, 100.0)
	return Vector2(r, spd)


static func wax_mult(w: Node) -> float:
	var fx := _inst()
	return 1.15 if fx and fx.world == w and fx.has.has("honeycomb") else 1.0


func _roll_tonics() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:tonics" % int(world.run_seed))
	var good: Array = []
	var bad: Array = []
	var odd: Array = []
	for k in TONIC_FX.keys():
		var g := int(TONIC_FX[k]["good"])
		(good if g > 0 else (bad if g < 0 else odd)).append(k)
	for arr in [good, bad, odd]:
		for i in range(arr.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var t = arr[i]
			arr[i] = arr[j]
			arr[j] = t
	var chosen: Array = good.slice(0, 5) + bad.slice(0, 2) + odd.slice(0, 1)
	for i in range(chosen.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = chosen[i]
		chosen[i] = chosen[j]
		chosen[j] = t
	for i in FLASKS.size():
		tonic_map[FLASKS[i]] = chosen[i]


static func tonic_name(id: String) -> String:
	var fx := _inst()
	if fx and fx.known.has(id):
		return ("Strong " if id.begins_with("flask_big") else "") + TONIC_FX[fx.tonic_map[id]]["name"]
	return "Unlabelled Tonic" if not id.begins_with("flask_big") else "Big Unlabelled Tonic"


static func tonic_desc(id: String) -> String:
	var fx := _inst()
	if fx and fx.known.has(id):
		return TONIC_FX[fx.tonic_map[id]]["desc"]
	return "???"


static func drink(id: String, pl: Player, w: Node) -> void:
	of(w)._drink(id, pl)


func _drink(id: String, pl: Player) -> void:
	var eff: String = tonic_map.get(id, "ember")
	var m := 1.8 if id.begins_with("flask_big") else 1.0
	var first := not known.has(id)
	known[id] = true
	match eff:
		"ember":
			pl.damage += 0.25 * m
		"quick":
			pl.fire_delay *= 1.0 - 0.12 * m
		"fleet":
			pl.speed *= 1.0 + 0.08 * m
		"long":
			pl.shot_range *= 1.0 + 0.15 * m
			pl.shot_speed *= 1.0 + 0.05 * m
		"ten":
			pl.heal(10.0 * m)
		"big_flame":
			pl.shot_scale *= 1.0 + 0.15 * m
			pl.damage += 0.12 * m
			pl.shot_speed *= 0.95
		"tallow":
			pl.wax_max += 8.0 * m
			pl.heal(8.0 * m)
		"feather":
			pl.shot_speed *= 1.0 + 0.15 * m
			pl.fire_delay *= 1.0 - 0.06 * m
			pl.shot_scale *= 0.85
			pl.damage *= 1.0 - 0.05 * m
		"hot_head":
			pl.damage += 0.3 * m
			pl.drain_mult *= 1.0 + 0.06 * m
		"leaden":
			pl.speed *= 1.0 - 0.07 * m
		"fog":
			fog_floor = world.floor_num
			fog_mult = 0.75 if m < 1.5 else 0.65
		"sputter":
			pl.wax = maxf(1.0, pl.wax - 3.0 * m)
			world.fx_smoke(pl.global_position + Vector2(0, -16))
		"butterfingers":
			var n := mini(pl.coins, int(3 * m))
			pl.coins -= n
			for k in n:
				world.add_pickup("coin", pl.global_position, "", 0, Vector2.from_angle(randf() * TAU) * 70.0)
	var g := int(TONIC_FX[eff]["good"])
	var col := UI.GOLD if g > 0 else (UI.RED if g < 0 else UI.CREAM)
	world.fx_text(pl.global_position + Vector2(0, -34), ("Now you know: " if first else "") + TONIC_FX[eff]["name"], col)


# ================================================================ keepsakes

static func use_keepsake(id: String, pl: Player, w: Node) -> void:
	of(w)._keepsake(id, pl)


func _keepsake(id: String, pl: Player) -> void:
	var at := pl.global_position + Vector2(0, -10)
	match id:
		"censer":
			for e in world.enemies:
				if is_instance_valid(e) and e.alive and e.active:
					status(e, "poison", 6.0)
					world.fx_smoke(e.global_position + Vector2(0, -10))
			for k in 8:
				world.fx_smoke(at + Vector2.from_angle(TAU * k / 8.0) * 16.0)
			world.fx_text(pl.global_position + Vector2(0, -34), "SWEET SMOKE", Color("#97da3f"))
			Audio.play("teleport", -2.0, 0.05, 1.3)
		"oil_jug":
			var dir: Vector2 = pl.aim_input.normalized() if pl.aim_input.length() > 0.3 else pl.facing
			var to: Vector2 = pl.global_position + dir * 56.0
			if world.room:
				to = world.free_spot_near(to, 4.0) if world.room.blocked(to, 4.0) else to
			_throw_jug(pl.global_position + Vector2(0, -8), to)
		"music_box":
			for e in world.enemies:
				if is_instance_valid(e) and e.alive and e.active:
					status(e, "charm", 4.0) if not e.boss else status(e, "slow", 3.0)
			world.fx_text(pl.global_position + Vector2(0, -34), "A LITTLE TUNE", Color("#f78697"))
			world.fx_ring(at, Color("#f78697"))
			for k in 5:
				var tw := create_tween()
				tw.tween_interval(k * 0.14)
				tw.tween_callback(func(): Audio.play("tick", -2.0, 0.0, [1.5, 1.8, 2.0, 1.8, 2.25][k]))
		"hand_mirror":
			mirror_t = 3.0
			world.fx_ring(at, Color("#cae6f5"))
			world.fx_text(pl.global_position + Vector2(0, -34), "LOOK BEHIND YOU", Color("#cae6f5"))
			Audio.play("item_get", -4.0, 0.0, 1.6)


func _throw_jug(from: Vector2, to: Vector2) -> void:
	var jug := Sprite2D.new()
	jug.texture = Art.tex("items/fx/jug")
	jug.material = Art.unshaded
	jug.z_index = 6
	world.fx_layer.add_child(jug)
	jug.global_position = from
	Audio.play("bomb_place", -2.0, 0.05, 1.3)
	var tw := jug.create_tween()
	tw.tween_method(func(k: float):
		jug.global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 26.0)
		jug.rotation = snappedf(k * TAU, PI / 2.0), 0.0, 1.0, 0.5)
	tw.tween_callback(func():
		var r: Room = world.room
		jug.queue_free()
		if r == null or world.finished:
			return
		Audio.play("splash", 0.0, 0.05, 0.8)
		world.fx_poof(to + Vector2(0, -4), true, 1.6)
		world.spawn_hot_drip(to)
		for k in 7:
			world.spawn_hot_drip(to + Vector2.from_angle(TAU * k / 7.0) * 13.0)
		for h in world.hazards.slice(maxi(0, world.hazards.size() - 8)):
			h[1] = 4.5
		for e in world.enemies:
			if is_instance_valid(e) and e.alive and e.active and e.global_position.distance_to(to) < 30.0 + e.radius:
				e.take_hit(3.0 + p.damage, (e.global_position - to).normalized() * 90.0, 4.0))


# ================================================================ helpers (familiars)

func _count_fam(kind: String) -> int:
	var n := 0
	for f in fams:
		if f["kind"] == kind:
			n += 1
	return n


func _add_fam(kind: String, idx: int) -> void:
	if _count_fam(kind) >= (3 if kind == "coal" else 2):
		return
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("items/fam_" + kind, 6.0 if kind != "coal" else 8.0)
	a.play("default")
	a.frame = idx % 2
	if kind in ["matchling", "lantern", "coal"]:
		a.material = Art.unshaded
		a.z_index = 6
		world.fx_layer.add_child(a)
	else:
		a.offset = Vector2(0, -3)
		world.actors.add_child(a)
	fams.append({"kind": kind, "node": a, "pos": p.global_position, "cd": 0.6 + 0.3 * idx, "ang": TAU * idx / 3.0, "idx": idx, "t": 0.0, "tgt": null, "life": 0.0})


func _tick_fams(dt: float) -> void:
	var show: bool = not p.dead and not world.finished
	var i := fams.size() - 1
	while i >= 0:
		var f: Dictionary = fams[i]
		var node: AnimatedSprite2D = f["node"] if is_instance_valid(f["node"]) else null
		if node == null:
			fams.remove_at(i)
			i -= 1
			continue
		node.visible = show
		if show:
			f["t"] += dt
			match String(f["kind"]):
				"matchling": _fam_matchling(f, node, dt)
				"lantern": _fam_lantern(f, node, dt)
				"coal": _fam_coal(f, node, dt)
				"bunny": _fam_bunny(f, node, dt)
				"mouse":
					if _fam_mouse(f, node, dt):
						fams.remove_at(i)
		i -= 1
	# Clockwork Mouse: a new mouse every few seconds while foes are about (two at most)
	if has.has("clockwork_mouse") and show and not world.transitioning:
		mouse_t -= dt
		if mouse_t <= 0.0 and world.count_enemies() > 0 and _count_fam("mouse") < 2:
			mouse_t = 3.2
			_add_fam("mouse", 0)
			Audio.play("tick", -6.0, 0.1, 1.4)


func _fam_matchling(f: Dictionary, node: AnimatedSprite2D, dt: float) -> void:
	var side := -1.0 if int(f["idx"]) == 0 else 1.0
	var behind := p.global_position - p.facing * 12.0 + Vector2(side * 7.0, -4.0)
	f["pos"] = (f["pos"] as Vector2).lerp(behind, minf(1.0, dt * 5.0))
	node.global_position = ((f["pos"] as Vector2) + Vector2(0, sin(f["t"] * 4.0 + side) * 1.5)).round()
	f["cd"] -= dt
	var tgt: Enemy = world.nearest_enemy(f["pos"], 140.0)
	if tgt:
		node.flip_h = tgt.global_position.x < node.global_position.x
		if f["cd"] <= 0.0 and not world.transitioning:
			f["cd"] = maxf(0.45, p.fire_delay * 1.9)
			var dir: Vector2 = (tgt.global_position + Vector2(0, -tgt.half_h) - node.global_position).normalized()
			world.shoot_player(node.global_position + Vector2(0, -4), dir, p, p.damage * 0.5 * helper_mult)
			Audio.play("shoot", -9.0, 0.1, 1.5)
	else:
		node.flip_h = p.facing.x < 0


func _fam_lantern(f: Dictionary, node: AnimatedSprite2D, dt: float) -> void:
	f["ang"] += dt * 1.7
	var c := p.global_position + Vector2(0, -10)
	var pos := c + Vector2(cos(f["ang"]) * 28.0, sin(f["ang"]) * 22.0)
	node.global_position = pos.round()
	for s in world.enemy_shots:
		if is_instance_valid(s) and not s._dead and s.global_position.distance_to(pos) < 8.0:
			s.end()


func _fam_coal(f: Dictionary, node: AnimatedSprite2D, dt: float) -> void:
	f["ang"] += dt * 3.2
	var pos := p.global_position + Vector2(0, -7) + Vector2(cos(f["ang"]) * 20.0, sin(f["ang"]) * 15.0)
	node.global_position = pos.round()
	var now := Time.get_ticks_msec()
	for e in world.enemies:
		if is_instance_valid(e) and e.alive and e.active and (e.global_position + Vector2(0, -e.half_h)).distance_to(pos) < e.radius + 4.0:
			if int(e.get_meta("coal_t", 0)) < now:
				e.set_meta("coal_t", now + 300)
				e.take_hit((0.5 + p.damage * 0.3) * helper_mult, (e.global_position - p.global_position).normalized() * 40.0, 1.5)
	for s in world.enemy_shots:
		if is_instance_valid(s) and not s._dead and s.global_position.distance_to(pos) < 5.0:
			s.end()


func _ground_step(f: Dictionary, goal: Vector2, spd: float, dt: float) -> Vector2:
	var pos: Vector2 = f["pos"]
	var to := goal - pos
	if to.length() < 1.0:
		return Vector2.ZERO
	var d := to.normalized() * minf(spd * dt, to.length())
	var room: Room = world.room
	if room == null or world.transitioning:
		f["pos"] = p.global_position
		return d
	for a in [0.0, 0.8, -0.8, 1.6, -1.6]:
		var np: Vector2 = pos + d.rotated(a)
		if not room.blocked(np, 3.0):
			f["pos"] = np
			return d
	return Vector2.ZERO


func _fam_bunny(f: Dictionary, node: AnimatedSprite2D, dt: float) -> void:
	f["cd"] -= dt
	var tgt: Enemy = world.nearest_enemy(f["pos"], 230.0)
	var goal := p.global_position + Vector2(-14, 3)
	var coin: Pickup = null
	if tgt:
		goal = tgt.global_position
	else:
		if int(f["t"] * 4.0) != int((f["t"] - dt) * 4.0) or not is_instance_valid(f["tgt"]):
			f["tgt"] = _nearest_coin(f["pos"])
		if is_instance_valid(f["tgt"]) and not f["tgt"].taken:
			coin = f["tgt"]
			goal = coin.global_position
	var moved := _ground_step(f, goal, 60.0 if (tgt or coin) else 70.0, dt)
	if (goal - (f["pos"] as Vector2)).length() < 10.0 and tgt == null and coin == null:
		moved = Vector2.ZERO
	node.global_position = (f["pos"] as Vector2).round()
	if moved.length() > 0.05:
		node.flip_h = moved.x < 0
		node.speed_scale = 1.6
	else:
		node.speed_scale = 0.4
	if tgt and (f["pos"] as Vector2).distance_to(tgt.global_position) < tgt.radius + 6.0 and f["cd"] <= 0.0:
		f["cd"] = 0.5
		tgt.take_hit((0.7 + p.damage * 0.35) * helper_mult, (tgt.global_position - (f["pos"] as Vector2)).normalized() * 30.0, 0.0)
	if coin and (f["pos"] as Vector2).distance_to(coin.global_position) < 7.0:
		coin.fetch(p)
		f["tgt"] = null


func _nearest_coin(from: Vector2) -> Pickup:
	if world.room == null:
		return null
	var best: Pickup = null
	var bd := 200.0 * 200.0
	for o in world.room.objects.get_children():
		if o is Pickup and not o.taken and o.kind in ["coin", "bomb"] and o.price == 0:
			var d: float = o.global_position.distance_squared_to(from)
			if d < bd:
				bd = d
				best = o
	return best


## true = the mouse popped and is gone.
func _fam_mouse(f: Dictionary, node: AnimatedSprite2D, dt: float) -> bool:
	f["life"] += dt
	var tgt: Enemy = world.nearest_enemy(f["pos"], 300.0)
	if tgt:
		var mv := _ground_step(f, tgt.global_position, 105.0, dt)
		if mv.length() > 0.05:
			node.flip_h = mv.x < 0
	node.global_position = (f["pos"] as Vector2).round()
	var pop: bool = f["life"] > 2.6 or tgt == null or world.transitioning
	if tgt and (f["pos"] as Vector2).distance_to(tgt.global_position) < tgt.radius + 5.0:
		pop = true
	if not pop:
		return false
	var at: Vector2 = f["pos"]
	if not world.transitioning:
		for e in world.enemies:
			if is_instance_valid(e) and e.alive and e.active and e.global_position.distance_to(at) < 20.0 + e.radius:
				e.take_hit((2.5 + p.damage * 1.2) * helper_mult, (e.global_position - at).normalized() * 90.0, 0.0)
		world.fx_poof(at + Vector2(0, -4), true, 1.2)
		Audio.play("hit_wall", -2.0, 0.1, 1.9)
	node.queue_free()
	return true


# ================================================================ attacks that replace firing

func _aiming() -> bool:
	return p.aim_input.length() > 0.3 and not p.frozen and not p.dead and not world.transitioning and not world.finished


func _tick_attack(dt: float) -> void:
	if has.has("blowlamp"):
		_tick_jet(dt)
	elif has.has("stove_door"):
		_tick_charge(dt)


func _tick_charge(dt: float) -> void:
	var full_t := clampf(0.95 * p.fire_delay / 0.42, 0.45, 1.4)
	if _aiming():
		if charge <= 0.0:
			_charge_snd = false
		charge = minf(1.0, charge + dt / full_t)
		_charge_dir = p.aim_input.normalized()
		if charge > 0.5 and not _charge_snd:
			_charge_snd = true
			Audio.play("charge", -6.0, 0.05, 1.4)
		if charge >= 1.0:
			_release()
	elif charge > 0.0:
		if charge >= 0.3:
			_release()
		else:
			charge = 0.0


func _release() -> void:
	var dir: Vector2 = world.assist_aim(p.global_position, _charge_dir)
	var k := charge
	charge = 0.0
	# a full flame is worth far more than taps: damage grows with the square of the charge
	var dmg := _shot_dmg() * (0.5 + 5.5 * k * k) * (1.0 + 0.6 * (p.shots - 1))
	_primary = true
	_big = k >= 0.99
	world.shoot_player(p.global_position + Vector2(0, -6) + dir * 5, dir, p, dmg)
	if has.has("lace_fan"):
		_fan(dir, dmg * 0.4)
	_primary = false
	_big = false
	var s := _last_shot
	if s and is_instance_valid(s):
		if k >= 0.99:
			if not has.has("tinderbox") and not has.has("pale_taper"):
				_set_frames(s, "items/fx/bigflame_blue" if p.blue else "items/fx/bigflame")
			s.radius = maxf(s.radius, 6.5)
			s.pierce += 3
			s.knock *= 2.5
			s.life *= 1.25
		elif not has.has("tinderbox") and not has.has("pale_taper"):
			_set_frames(s, "fx/ember_big")
			s.radius = maxf(s.radius, 4.5)
	if brooch > 0:
		brooch -= 1
	p.set("_recoil", 0.16)
	if k >= 0.99:
		world.shake(2.0)
		Audio.play("explosion", -9.0, 0.05, 1.6)
	else:
		Audio.play("shoot", 0.0, 0.05, 0.7)


func _tick_jet(dt: float) -> void:
	_jet_on = _aiming()
	if _jet_on:
		var want: Vector2 = world.assist_aim(p.global_position, p.aim_input.normalized())
		_jet_dir = _jet_dir.slerp(want, minf(1.0, dt * 14.0)).normalized()
		_jet_origin = p.global_position + Vector2(0, -8) + _jet_dir * 5.0
		var max_len := clampf(p.shot_range * 0.75, 70.0, 112.0)
		_jet_len = max_len
		var room: Room = world.room
		if room and not has.has("pale_taper"):
			var dd := 4.0
			while dd < max_len:
				if _solid(room, _jet_origin + _jet_dir * dd + Vector2(0, 6)):
					_jet_len = dd
					break
				dd += 4.0
		_jet_tick -= dt
		if _jet_tick <= 0.0:
			_jet_tick = clampf(0.1 * p.fire_delay / 0.42, 0.05, 0.14)
			_jet_damage()
			if room and not has.has("pale_taper"):   # a ghost flame never chips urns or crates
				room.shot_hits(_jet_origin + _jet_dir * (_jet_len + 2.0) + Vector2(0, 6), 1.0)
		_jet_snd -= dt
		if _jet_snd <= 0.0:
			_jet_snd = 0.11
			Audio.play("shoot", -11.0, 0.25, 0.6)
		var cols: Array = PALE_COLS if has.has("pale_taper") else (BLUE_COLS if p.blue else FIRE_COLS)
		for k in 5:
			if _jet_parts.size() >= MAX_JET:
				break
			var life := randf_range(0.22, 0.32)
			var spd := _jet_len / 0.26
			var v := _jet_dir.rotated(randf_range(-0.14, 0.14) * (1.0 + 0.3 * (p.shots - 1))) * spd * randf_range(0.8, 1.1)
			_jet_parts.append([_jet_origin + _jet_dir * randf_range(0.0, 3.0), v, life, life])
		_jet_light.energy = 0.9
		_jet_light.global_position = _jet_origin + _jet_dir * _jet_len * 0.5
		_jet_light.color = Color(0.6, 0.8, 1.0) if p.blue else Color(1.0, 0.7, 0.35)
		_jet_cols = cols
	else:
		_jet_light.energy = move_toward(_jet_light.energy, 0.0, dt * 6.0)
	var i := _jet_parts.size() - 1
	while i >= 0:
		var pt: Array = _jet_parts[i]
		pt[0] += pt[1] * dt
		pt[1] *= 1.0 - dt * 2.0
		pt[2] -= dt
		if pt[2] <= 0.0 or (not has.has("pale_taper") and pt[0].distance_to(_jet_origin) > _jet_len + 6.0):
			_jet_parts.remove_at(i)
		i -= 1


var _jet_cols: Array = FIRE_COLS


func _jet_damage() -> void:
	var half := deg_to_rad(15.0 + 6.0 * (p.shots - 1))
	var dmg := _shot_dmg() * 0.4 * (1.0 + 0.35 * (p.shots - 1))
	for e in world.enemies:
		if not is_instance_valid(e) or not e.alive or not e.active:
			continue
		var to: Vector2 = e.global_position + Vector2(0, -e.half_h) - _jet_origin
		var dist := to.length()
		if dist < _jet_len + e.radius and absf(_jet_dir.angle_to(to)) < half + atan2(e.radius, maxf(dist, 1.0)):
			e.take_hit(dmg, _jet_dir * p.knockback * 0.12, p.burn)
			if e.get("_flash") != null:
				e.set("_flash", 0.35)   # ten licks a second: flicker, never a solid white
			_curse_roll(e, 0.25)
			if has.has("bell_wire") and randf() < 0.08 and is_instance_valid(e):
				_chain(e, dmg * 2.0, 2)
	# the flame eats bullets close in
	for s in world.enemy_shots:
		if is_instance_valid(s) and not s._dead:
			var to2: Vector2 = s.global_position - _jet_origin
			if to2.length() < _jet_len * 0.6 and absf(_jet_dir.angle_to(to2)) < half:
				s.end()


# ================================================================ clock relics, sweeping, fog

func _tick_clock(dt: float) -> void:
	if has.has("pendulum"):
		var low := p.wax < 30.0 and not p.dead
		p.slow_aura = (0.25 if has.has("pocket_watch") else 0.0) + (0.3 if low else 0.0)
		if low and not pendulum_on:
			world.fx_text(p.global_position + Vector2(0, -40), "the pendulum slows...", UI.GOLD)
			Audio.play("tick", 0.0, 0.0, 0.5)
		pendulum_on = low
	if has.has("cuckoo_clock") and not p.dead and not world.finished:
		var n := int(world.clock_minutes() / 15.0)
		if n > cuckoo_max:
			cuckoo_max = n
			p.heal(2.0)
			world.fx_text(p.global_position + Vector2(0, -44), "CUCKOO!  +2 min", UI.GOLD)
			Audio.play("bell_toll", -6.0, 0.0, 2.1)
			for k in 8:
				var c := _child(p.global_position + Vector2(0, -8), Vector2.from_angle(TAU * k / 8.0), p.damage * 1.5)
				if c:
					c.life = 0.7
	if sweep_t > 0.0:
		if sweep_delay > 0.0:
			sweep_delay -= dt
		else:
			sweep_t -= dt


func _process(_dt: float) -> void:
	if p and is_instance_valid(p) and fog_floor == world.floor_num and p.light:
		p.light.texture_scale *= fog_mult
	if _jet_on or not _jet_parts.is_empty() or charge > 0.0 or not _zaps.is_empty() or mirror_t > 0.0 or salt_t > 0.0:
		queue_redraw()
	elif _drew:
		queue_redraw()


func _physics_process(dt: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	_frame += 1
	_tick_attack(dt)
	_tick_steer(dt)
	_tick_status(dt)
	_tick_fams(dt)
	_tick_defence(dt)
	_tick_clock(dt)
	var i := _zaps.size() - 1
	while i >= 0:
		_zaps[i][1] -= dt
		if _zaps[i][1] <= 0.0:
			_zaps.remove_at(i)
		i -= 1


var _drew := false


func _draw() -> void:
	_drew = false
	# flame jet: puffs swell and cool as they fly (oldest drawn first, so the hot core sits on top)
	for pt in _jet_parts:
		var k: float = 1.0 - pt[2] / pt[3]
		var ci := 0 if k < 0.12 else (1 if k < 0.34 else (2 if k < 0.6 else (3 if k < 0.86 else 4)))
		var r := roundf(1.0 + 3.0 * minf(1.0, k * 1.4))
		var at: Vector2 = (pt[0] as Vector2).round()
		if ci >= 2:
			draw_circle(at, r + 1.0, _jet_cols[mini(ci + 1, 4)], true, -1.0, false)
		draw_circle(at, r, _jet_cols[ci], true, -1.0, false)
		_drew = true
	if _jet_on and not _jet_parts.is_empty():
		var a := _jet_origin.round()
		var b := (_jet_origin + _jet_dir * minf(_jet_len, 18.0)).round()
		draw_line(a, b, _jet_cols[1], 3.0)
		draw_line(a, b, _jet_cols[0], 1.0)
	# Bell Wire sparks: a jagged two-tone line
	for z in _zaps:
		var pts: Array = z[0]
		for j in pts.size() - 1:
			var a: Vector2 = pts[j]
			var b: Vector2 = pts[j + 1]
			var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * (3.0 if j % 2 == 0 else -3.0)
			draw_line(a.round(), mid.round(), Color("#facb3e"), 1.0)
			draw_line(mid.round(), b.round(), Color("#fdf7ed"), 1.0)
		_drew = true
	# Stove Door: the gathering flame in front of Tallow
	if charge > 0.0 and is_instance_valid(p):
		var c := (p.global_position + Vector2(0, -9) + _charge_dir * 9.0).round()
		var r := 1.0 + 4.0 * charge
		var cols: Array = BLUE_COLS if p.blue else FIRE_COLS
		var full := charge >= 0.95 and Engine.get_physics_frames() % 6 < 3
		draw_circle(c, r + 1.0, Color("#21141b"), true, -1.0, false)
		draw_circle(c, r, cols[2], true, -1.0, false)
		draw_circle(c + Vector2(-0.5, -0.5), r * 0.6, cols[1], true, -1.0, false)
		draw_circle(c + Vector2(-1, -1), maxf(0.5, r * 0.3), cols[0] if not full else Color.WHITE, true, -1.0, false)
		var pips := 5
		for j in pips:
			var on := charge * pips > j
			draw_rect(Rect2(c + Vector2(-pips * 2 + j * 4 + 1, -r - 5), Vector2(2, 2)), cols[1] if on else Color("#483b3a"))
		_drew = true
	# Hand Mirror: a silver circle catches shots
	if mirror_t > 0.0 and is_instance_valid(p):
		var c2 := p.global_position + Vector2(0, -8)
		var rr := 28.0 + sin(mirror_t * 18.0) * 1.0
		draw_arc(c2, rr, 0, TAU, 32, Color("#cae6f5") if fmod(mirror_t, 0.3) > 0.1 else Color("#7b8994"), 1.0)
		_drew = true
	# Salt Line: a ring of salt on the floor, fading grain by grain
	if salt_t > 0.0 and is_instance_valid(p):
		var n := int(24 * clampf(salt_t / 2.0, 0.0, 1.0))
		for j in n:
			var at2 := (p.global_position + Vector2.from_angle(TAU * j / 24.0) * Vector2(14, 8)).round()
			draw_rect(Rect2(at2, Vector2(1, 1)), Color("#fdf7ed") if j % 3 else Color("#b6cbcf"))
		_drew = true


# ================================================================ save / continue hooks

## For "save and continue": what RelicFx needs on top of the relic list. To restore a run, apply
## the saved relics again with Items.apply (helpers, maps and stats rebuild), then call from_dict().
func to_dict() -> Dictionary:
	return {"known": known.keys(), "fog_floor": fog_floor, "fog_mult": fog_mult, "chimney": chimney_ready,
		"cuckoo": cuckoo_max, "brooch": brooch}


func from_dict(d: Dictionary) -> void:
	for k in d.get("known", []):
		known[k] = true
	fog_floor = int(d.get("fog_floor", -1))
	fog_mult = float(d.get("fog_mult", 1.0))
	chimney_ready = bool(d.get("chimney", true))
	cuckoo_max = maxi(cuckoo_max, int(d.get("cuckoo", 0)))
	brooch = int(d.get("brooch", 0))


# ================================================================ little drawn things

## Curse marks over a foe's head (and wax crust at its feet).
class StatusMark extends Node2D:
	var e: Enemy
	var st: Dictionary

	func _draw() -> void:
		if not is_instance_valid(e):
			return
		var h := e.half_h / 0.4
		var top := -h - 4.0 - float(e.get("_jump_h") if e.get("_jump_h") != null else 0.0)
		var t := Time.get_ticks_msec() / 1000.0
		var ink := Color("#21141b")
		var x := -2.0
		if float(st.get("charm", 0.0)) > 0.0:
			var y := top - 3.0 + roundf(sin(t * 5.0))
			# a small heart
			draw_rect(Rect2(x - 1, y - 1, 7, 5), ink)
			draw_rect(Rect2(x, y + 3, 5, 2), ink)
			draw_rect(Rect2(x + 1, y + 5, 3, 1), ink)
			draw_rect(Rect2(x, y, 2, 3), Color("#dc4a7b"))
			draw_rect(Rect2(x + 3, y, 2, 3), Color("#dc4a7b"))
			draw_rect(Rect2(x + 1, y + 3, 3, 1), Color("#dc4a7b"))
			draw_rect(Rect2(x + 2, y + 4, 1, 1), Color("#9f294e"))
			draw_rect(Rect2(x, y, 1, 1), Color("#f78697"))
			draw_rect(Rect2(x + 2, y + 1, 1, 2), Color("#dc4a7b"))
		elif float(st.get("fear", 0.0)) > 0.0:
			# two shaking exclamation marks
			var j := 1.0 if Engine.get_physics_frames() % 6 < 3 else 0.0
			for k in 2:
				var xx := x - 1.0 + k * 4.0 + j
				draw_rect(Rect2(xx - 1, top - 6, 3, 7), ink)
				draw_rect(Rect2(xx, top - 5, 1, 3), Color("#fdf7ed"))
				draw_rect(Rect2(xx, top - 1, 1, 1), Color("#fdf7ed"))
		if float(st.get("poison", 0.0)) > 0.0:
			for k in 3:
				var ph := fmod(t * 1.2 + k * 0.33, 1.0)
				var bx := -3.0 + k * 3.0
				var by := top + 2.0 - ph * 8.0
				draw_rect(Rect2(bx - 1, by - 1, 3, 3), ink)
				draw_rect(Rect2(bx, by, 1, 1), Color("#97da3f") if k != 1 else Color("#4ba747"))
		if float(st.get("slow", 0.0)) > 0.0:
			# hard wax crusted round the feet, with a few drips running up
			var w := roundf(e.radius * 2.0)
			var x0 := -roundf(w / 2.0)
			draw_rect(Rect2(x0 - 1, -4, w + 2, 4), ink)
			draw_rect(Rect2(x0, -3, w, 3), Color("#d3bfa9"))
			draw_rect(Rect2(x0, -1, w, 1), Color("#aa8d7a"))
			var k2 := 0
			while k2 < int(w):
				draw_rect(Rect2(x0 + k2, -3, 2, 1), Color("#fdf7ed"))
				if k2 % 4 == 0:
					draw_rect(Rect2(x0 + k2 - 1, -6, 3, 3), ink)
					draw_rect(Rect2(x0 + k2, -5, 1, 2), Color("#fdf7ed"))
				k2 += 3
		if float(st.get("stun", 0.0)) > 0.0:
			var a := t * 9.0
			for k in 3:
				var sp := Vector2(cos(a + k * TAU / 3.0) * 5.0, sin(a + k * TAU / 3.0) * 2.0 + top).round()
				draw_rect(Rect2(sp, Vector2(1, 1)), Color("#facb3e"))


## Dowsing Rod: sparkles on the cracked wall in front of a hollow.
class Shimmer extends Node2D:
	var cell: Dictionary

	func _process(_dt: float) -> void:
		if cell.get("revealed", false):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for k in 6:
			var ph := fmod(t * 0.9 + k * 0.19, 1.0)
			if ph > 0.7:
				continue
			var at := Vector2(roundf(sin(k * 2.7) * 7.0), roundf(cos(k * 1.9) * 11.0) - roundf(ph * 3.0))
			var c := Color("#cae6f5") if ph < 0.35 else Color("#72d6ce")
			draw_rect(Rect2(at, Vector2(1, 1)), Color("#fdf7ed"))
			draw_rect(Rect2(at + Vector2(-1, 0), Vector2(1, 1)), c)
			draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 1)), c)
			draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 1)), c)
			draw_rect(Rect2(at + Vector2(0, 1), Vector2(1, 1)), c)
