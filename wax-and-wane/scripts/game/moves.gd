class_name Moves
extends Node2D
## v2.3 special moves: every candle has one (Candles.LIST "move"), fired by the `special` action
## (Left Shift, F or a mouse thumb button, LT on a pad; Controls) or the HUD's move button
## (MoveButton). LIST is the data (name, one line, cooldown, wax cost, icon); each move is one small
## function below plus its juice. One Moves node lives under the Player (Player._ready) and keeps the
## moment-to-moment state: a Skip in flight, the Slam's wind-up, Flare Up's blaze, Snuff's dark.
##
## Hooks elsewhere (one line each): Player (move_cd, move_ready(), use_move(), the cooldown tick,
## speed_k() on the walk target, shot_mult() on a shot's damage), world.shoot_player (on_shot_made:
## Flare Up's fire and the black flame), enemy.gd / area_ai.gd / house_ai.gd (target_of: lodgers
## seek a snuffed Black Taper where it was), the HUD (MoveButton, the `special` action),
## RelicFx.on_move, achievements (unlocked from here), the bot (MovesBot.think from autotest drive).
## Deterministic: no move reads the floor or loot RNGs; visual randomness only uses randf().
## `--nomoves` turns every move off (balance runs: Tallow with and without).

const LIST := {
	"skip": {"name": "Skip", "line": "A quick dash; nothing can touch you for a moment.",
		"cd": 2.5, "cost": 0.0, "icon": "moves/icon_skip"},
	"sparkler": {"name": "Sparkler", "line": "Twelve sparks burst all around and pop enemy shots.",
		"cd": 8.0, "cost": 0.0, "icon": "moves/icon_sparkler"},
	"slam": {"name": "Slam", "line": "Slam the floor: lodgers are stunned, guardians slowed.",
		"cd": 9.0, "cost": 0.0, "icon": "moves/icon_slam"},
	"blink": {"name": "Blink", "line": "Vanish and step out further on, past pits and rubble.",
		"cd": 4.0, "cost": 0.0, "icon": "moves/icon_blink"},
	"flare": {"name": "Flare Up", "line": "Burn 2 minutes of wax to blaze for 3 seconds.",
		"cd": 10.0, "cost": 2.0, "icon": "moves/icon_flare"},
	"snuff": {"name": "Snuff", "line": "Go dark for 2 s, then a black flame that pierces.",
		"cd": 9.0, "cost": 0.0, "icon": "moves/icon_snuff"},
}
const ORDER := ["skip", "sparkler", "slam", "blink", "flare", "snuff"]

# ---- the knobs (ROADMAP_V2 section 1: starting numbers, tuned with the bot)
const SKIP_DIST := 48.0        # px
const SKIP_TIME := 0.12        # s for the whole dash
const SKIP_INVULN := 0.3
const SPARKS := 12
const SPARK_R := 44.0          # px: how far the sparks fly (and the shot-popping radius)
const SPARK_TIME := 0.2
const SPARK_DMG := 2.0         # x the candle's shot damage, per spark
const SPARK_KNOCK := 150.0
const SLAM_WINDUP := 0.25
const SLAM_R := 40.0
const SLAM_STUN := 1.2         # s; guardians are slowed this long instead
const SLAM_DMG := 2.5          # x shot damage to everything in the ring
const BLINK_DIST := 56.0
const BLINK_INVULN := 0.2
const FLARE_COST := 2.0        # minutes of wax
const FLARE_MIN := 5.0         # refused below this much wax
const FLARE_TIME := 3.0
const FLARE_DMG := 1.5
const FLARE_BURN := 1.6        # s alight
const HEAT_R := 13.0           # px from the candle: lodgers this close are scorched
const HEAT_TICK := 0.3
const HEAT_DMG := 0.6          # x shot damage per tick
const SNUFF_TIME := 2.0
const SNUFF_SPEED := 1.15
const SNUFF_DMG := 3.0
const SNUFF_PIERCE := 3

const SOLID_HARD := ["R", "Q", "U", "C", "B", "Z", "O", "X", "K"]   # Blink hops one tile of these
const SPARK_COLS := [Color("#fdf7ed"), Color("#facb3e"), Color("#ee8e2e"), Color("#da4e38"), Color("#8f4029")]
const MOON_COLS := [Color("#fdf7ed"), Color("#cae6f5"), Color("#b6cbcf"), Color("#7b8994")]
const RING_COLS := [Color("#facb3e"), Color("#fdf7ed")]
const BLACK_TEXT := Color("#cae6f5")   # "Black flame!" (pale on the dark, like the flame's core)

## --nomoves (balance runs) turns every move off; the bot and the button then do nothing.
static var enabled := not ("--nomoves" in OS.get_cmdline_user_args())
## This run: move id -> times used (the bot prints it per run); reset when a run's Moves node starts.
static var uses := {}
## The physics frame the last move fired on (the latency probe, MovesCheck).
static var fired_frame := -1
## A Black Taper is snuffed (enemies ask target_of() only while this is true).
static var dark := false
static var _dark_at := Vector2.ZERO
static var _dark_t := 0.0

var p: Player
var w: Node
var ready_flash := 0.0      # s: the move just came back (the HUD button flashes)
var denied := 0.0           # s: a press was turned away (the button shakes)
var _live := false
var _was_ready := true
var _cell := Vector2i(-99, -99)
# Skip
var _dash_left := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_trail := 0.0
var _skip_t := 0.0
var _shaved := {}
# Slam
var _slam_t := -1.0
# Blink
var _pits := 0
# Flare Up
var _flare_t := 0.0
var _heat_t := 0.0
var _flare_kills0 := 0
var _back: Node2D           # the heat ring's back half (drawn behind the candle)
var _anim := 0.0
# Snuff
var _snuff_t := 0.0
var _wisp_t := 0.0
var _black := false          # the next shot is a black flame
var _black_shot: WeakRef
var _black_hits := 0
# the volley being fired this physics frame (shot_mult -> on_shot_made)
var _volley_frame := -1
var _volley_flare := false
var _volley_black := false


# ================================================================ the table

## The move of a candle ("" if none).
static func for_candle(candle: String) -> String:
	return str(Candles.def_of(candle).get("move", ""))


static func def(id: String) -> Dictionary:
	return LIST.get(id, {})


static func name_of(id: String) -> String:
	return L.t(str(def(id).get("name", ""))) if LIST.has(id) else ""


static func line_of(id: String) -> String:
	return L.t(str(def(id).get("line", ""))) if LIST.has(id) else ""


static func icon(id: String) -> String:
	return str(def(id).get("icon", ""))


static func cooldown(id: String) -> float:
	return float(def(id).get("cd", 1.0))


## The player's Moves node (null on stand-in players without one).
static func of(pl: Node) -> Moves:
	if pl == null or not is_instance_valid(pl) or not pl.has_meta("moves"):
		return null
	var m: Variant = pl.get_meta("moves")
	return m if m != null and is_instance_valid(m) else null


# ================================================================ hooks

## Fire the player's move now (Player.use_move). `dir` overrides the direction (the bot).
static func use(pl: Player, _w: Node, dir := Vector2.ZERO) -> bool:
	var m := of(pl)
	return m != null and m._use(dir)


## Player._physics_process: the walk target's speed (the Slam roots, Snuff is a little quicker).
static func speed_k(pl: Player) -> float:
	var m := of(pl)
	if m == null:
		return 1.0
	if m._dash_left > 0.0 or m._slam_t >= 0.0:
		return 0.0
	return SNUFF_SPEED if m._snuff_t > 0.0 else 1.0


## Player._fire: the damage of the volley about to leave (Flare Up x1.5, the black flame x3).
static func shot_mult(pl: Player) -> float:
	var m := of(pl)
	if m == null:
		return 1.0
	m._volley_frame = Engine.get_physics_frames()
	m._volley_flare = m._flare_t > 0.0
	m._volley_black = m._black
	m._black = false
	return (FLARE_DMG if m._volley_flare else 1.0) * (SNUFF_DMG if m._volley_black else 1.0)


## world.shoot_player: a friendly shot was set up (before it enters the tree). Shots of the
## player's own volley this frame get Flare Up's fire or the black flame's pierce and look.
static func on_shot_made(s: Shot, pl: Player) -> void:
	var m := of(pl)
	if m == null or m._volley_frame != Engine.get_physics_frames():
		return
	if m._volley_flare:
		s.burn = maxf(s.burn, FLARE_BURN)
		if not pl.blue and s.spr and Art.has("fx/ember_big_f0"):
			s.spr.sprite_frames = Art.anim("fx/ember_big", 12.0)
			s.spr.play("default")
	if m._volley_black:
		s.pierce += SNUFF_PIERCE
		s.set_meta("black_flame", true)
		if s.spr and Art.has("moves/blackflame_f0"):
			s.spr.sprite_frames = Art.anim("moves/blackflame", 12.0)
			s.spr.play("default")
		if s.light:
			s.light.color = Color(0.72, 0.5, 1.0)
		m._black_shot = weakref(s)
		m._black_hits = 0
		Audio.play("burn_whoosh", -3.0, 0.05, 0.7)


## Where a creature thinks the candle is: a snuffed Black Taper is sought where it went dark
## (lodgers wander round that spot); guardians are never fooled. enemy.gd / area_ai.gd / house_ai.gd.
static func target_of(e: Node, pl: Node2D) -> Vector2:
	if pl == null:
		return Vector2.ZERO
	if not dark or (e != null and bool(e.get("boss"))):
		return pl.global_position
	var a := float(e.get_instance_id() % 360) * 0.0174533 + _dark_t * 1.3 if e else 0.0
	return _dark_at + Vector2.from_angle(a) * 10.0


# ================================================================ node

func _ready() -> void:
	name = "Moves"
	p = get_parent() as Player
	w = p.world if p else null
	# only a real run has foes and rooms (the title's and the hero sheet's stand-in candles do not)
	_live = w != null and w.get("enemy_shots") != null and w.has_method("shoot_player")
	p.set_meta("moves", self)
	process_physics_priority = -1   # before the world and the candle: a dash moves Tallow this frame
	material = Art.unshaded
	z_index = 3
	set_physics_process(_live)
	set_process(_live)
	if not _live:
		return
	uses = {}
	dark = false
	_back = Node2D.new()
	_back.show_behind_parent = true
	_back.material = Art.unshaded
	_back.draw.connect(_draw_heat.bind(true))
	p.add_child.call_deferred(_back)


func _exit_tree() -> void:
	if _snuff_t > 0.0:
		dark = false


func move_id() -> String:
	return Moves.for_candle(p.candle_id) if p else ""


func busy() -> bool:
	return _dash_left > 0.0 or _slam_t >= 0.0


func _can_act() -> bool:
	if not _live or p.dead or p.frozen or p._hold_t > 0.0 or Juice.holding(w):
		return false
	return not (w.paused or w.finished or w.transitioning)


func _use(dir: Vector2) -> bool:
	var id := move_id()
	if id == "" or not enabled or not _can_act() or busy():
		return false
	if p.move_cd > 0.0:
		denied = 0.25
		Audio.play("tick", -14.0, 0.0, 0.7)
		return false
	if id == "flare" and p.wax < FLARE_MIN:
		denied = 0.35
		Audio.play("ui_back", -4.0)
		w.fx_text(p.global_position + Vector2(0, -30), L.t("Too little wax"), UI.RED)
		return false
	var ok := false
	var d := _aim(dir)
	match id:
		"skip": ok = _use_skip(d)
		"sparkler": ok = _use_sparkler()
		"slam": ok = _use_slam()
		"blink": ok = _use_blink(d)
		"flare": ok = _use_flare()
		"snuff": ok = _use_snuff()
	if not ok:
		return false
	p.move_cd = Moves.cooldown(id)
	_was_ready = false
	fired_frame = Engine.get_physics_frames()
	uses[id] = int(uses.get(id, 0)) + 1
	var life: Dictionary = Game.records.get("move_uses", {})
	life[id] = int(life.get(id, 0)) + 1
	Game.records["move_uses"] = life
	RelicFx.on_move(p, id)
	return true


## The move's direction: the bot's, else where Tallow is walking, else where it aims or faces.
func _aim(dir: Vector2) -> Vector2:
	if dir.length() > 0.1:
		return dir.normalized()
	var hud: Variant = w.get("hud")
	var mv: Vector2 = hud.move_vec if hud else Vector2.ZERO
	if mv.length() < 0.2:
		mv = p.move_input
	if mv.length() >= 0.2:
		return mv.normalized()
	var aim: Vector2 = hud.aim_vec if hud else Vector2.ZERO
	if aim.length() < 0.3:
		aim = p.aim_input
	if aim.length() >= 0.3:
		return aim.normalized()
	return p.facing.normalized() if p.facing.length() > 0.1 else Vector2.RIGHT


func _physics_process(dt: float) -> void:
	if p.dead:
		_end_snuff(false)
		_dash_left = 0.0
		_slam_t = -1.0
		return
	if p._hold_t > 0.0 or Juice.holding(w):
		_dash_left = 0.0
		return
	if w.cur_cell != _cell:
		_cell = w.cur_cell
		_pits = 0
		_dash_left = 0.0
		_slam_t = -1.0
		_end_snuff(false)
	var ready := p.move_cd <= 0.0
	if ready and not _was_ready and move_id() != "":
		ready_flash = 0.4
		Audio.play("tick", -9.0, 0.0, 1.8)
	_was_ready = ready
	ready_flash = maxf(0.0, ready_flash - dt)
	denied = maxf(0.0, denied - dt)
	if _dash_left > 0.0:
		_dash_step(dt)
	if _skip_t > 0.0:
		_skip_t -= dt
		_watch_shave()
	if _slam_t >= 0.0:
		_slam_t -= dt
		if _slam_t < 0.0:
			_slam_hit()
	if _flare_t > 0.0:
		_flare_step(dt)
	if _snuff_t > 0.0:
		_snuff_t -= dt
		_dark_t += dt
		p.fire_cd = maxf(p.fire_cd, dt * 1.5)   # no flame, no sparks (a held fire key waits for the relight)
		if _snuff_t <= 0.0:
			_end_snuff(true)
	_watch_black()
	if p.world and p.world.hud and move_id() == "flare" and ready and p.wax >= FLARE_MIN and w.count_enemies() > 0:
		w.hud.preview_cost(FLARE_COST)   # the price, marching on the wax bar while Flare Up is ready


func _process(dt: float) -> void:
	_anim += dt
	if _snuff_t > 0.0:
		# the flame is out: no flame, a faint wick glow, the body unlit by its own light
		p.flame.visible = false
		if p.flame2:
			p.flame2.visible = false
		p.light.energy *= 0.12
		p.light.texture_scale *= 0.6
		p.glow.energy *= 0.25
		p.material = null
		_wisp_t -= dt
		if _wisp_t <= 0.0:
			_wisp_t = 0.22
			w.fx_wisp(p.to_global(p.wick_tip()))
	elif _flare_t > 0.0:
		p.light.texture_scale *= 1.35
		p.light.energy *= 1.15
		if randf() < dt * 18.0:
			Juice.of(w).hot.emit(p.to_global(p.wick_tip()) + Vector2(randf_range(-3, 3), -2),
				Vector2(randf_range(-10, 10), randf_range(-38, -22)), randf_range(0.4, 0.7), FxParts.EMBER, -10.0, 0.5)
	queue_redraw()
	if _back:
		_back.queue_redraw()


# ================================================================ Skip (Tea Light)

func _use_skip(dir: Vector2) -> bool:
	_dash_dir = dir
	_dash_left = SKIP_DIST
	_dash_trail = 0.0
	_skip_t = SKIP_INVULN
	_shaved.clear()
	p.invuln = maxf(p.invuln, SKIP_INVULN)
	p.vel = Vector2.ZERO
	p._sq = -0.8 if absf(dir.x) > absf(dir.y) else 0.8   # squashed wide into a sideways dash, tall up/down
	p._sq_v = 0.0
	Audio.play("dodge", 1.0, 0.08)
	Juice.of(w).kick(dir, 1.5)
	var feet := p.global_position + Vector2(0, -1)
	Juice.of(w).lit.burst(feet, 5, 20.0, 45.0, -dir, 0.9, 0.35, FxParts.DUST, 0.0, 5.0, 1)
	return true


func _dash_step(dt: float) -> void:
	var step := minf(_dash_left, SKIP_DIST / SKIP_TIME * dt)
	_dash_left -= step
	var before := p.global_position
	var left := step
	while left > 0.01:   # sub-steps: the bot's 4x speed must not tunnel through a crate
		var s := minf(left, 3.0)
		left -= s
		p._move(_dash_dir * s)
	var moved := p.global_position.distance_to(before)
	_dash_trail += moved
	while _dash_trail >= 5.0:
		_dash_trail -= 5.0
		var at := p.global_position - _dash_dir * _dash_trail + Vector2(randf_range(-2, 2), randf_range(-8, -1))
		Juice.of(w).hot.emit(at, -_dash_dir * randf_range(10, 30) + Vector2(0, -randf_range(4, 14)),
			randf_range(0.18, 0.32), FxParts.SPARK, 30.0, 3.0, 1, false)
	if moved < step * 0.25:   # into a wall: the dash is over
		_dash_left = 0.0
	if _dash_left <= 0.0:
		p.vel = _dash_dir * p.speed * 0.8   # carry on at a run, no slide
		p._sq = 0.5 if absf(_dash_dir.x) > absf(_dash_dir.y) else -0.5


## "Close Shave": an enemy shot passes through Tallow during the Skip's i-frames.
func _watch_shave() -> void:
	var c := p.global_position + Vector2(0, -8)
	for s in w.enemy_shots:
		if is_instance_valid(s) and c.distance_squared_to(s.global_position) < 81.0 and not _shaved.has(s.get_instance_id()):
			_shaved[s.get_instance_id()] = true
			w.fx_text(p.global_position + Vector2(0, -28), L.t("Close shave!"), UI.GOLD)
			Achievements.unlock("move_skip")


# ================================================================ Sparkler (Party Candle)

func _use_sparkler() -> bool:
	var c := p.global_position + Vector2(0, -6)
	var fx := MoveFx.of(w)
	var popped := 0
	for s in w.enemy_shots:
		if is_instance_valid(s) and not s._dead and s.global_position.distance_to(c) <= SPARK_R:
			fx.pop(s.global_position)
			s.end()
			popped += 1
	for i in SPARKS:
		fx.spark(c, Vector2.from_angle(TAU * i / SPARKS - PI / 2.0), SPARK_DMG * p.damage, p.burn)
	fx.burst(c, "moves/burst", 20.0)
	fx.flash(c, Color(1.0, 0.78, 0.4), 1.6, 1.1)
	Audio.play("match_strike", 2.0, 0.05, 1.25)
	Audio.play("burn_whoosh", -2.0, 0.05, 1.5)
	w.shake(2.5)
	p._sq_v += 5.0
	fx.popped = popped
	return true


## Called by MoveFx when the burst's sparks are done: the shots they popped in total.
func sparkler_done(popped: int, hits: int) -> void:
	if popped >= 3:
		Achievements.unlock("move_sparkler")
	if hits >= 2:
		w.hitstop(0.03, 0.12)


# ================================================================ Slam (Altar Pillar)

func _use_slam() -> bool:
	_slam_t = SLAM_WINDUP
	p.vel = Vector2.ZERO
	p._sq = 1.0    # rises up tall, then comes down
	p._sq_v = 0.0
	Audio.play("charge", -2.0, 0.0, 1.35)
	return true


func _slam_hit() -> void:
	_slam_t = -1.0
	var c := p.global_position
	var rfx := RelicFx.of(w)
	var stunned := 0
	var hits := 0
	for e in w.enemies.duplicate():
		if not is_instance_valid(e) or not e.alive or not e.active or e.buried:
			continue
		var to: Vector2 = e.global_position - c
		if to.length() > SLAM_R + e.radius:
			continue
		var dir := to.normalized() if to.length() > 0.5 else Vector2.DOWN
		e.take_hit(SLAM_DMG * p.damage, Vector2.ZERO, 0.0)
		hits += 1
		if not e.alive:
			continue
		if e.boss:
			rfx.status(e, "slow", SLAM_STUN)
		else:
			e._move(dir * 5.0)   # shoved back a step, then stunned on the spot
			rfx.status(e, "stun", SLAM_STUN)
			stunned += 1
	# weak obstacles in the ring crack (urns and skull piles break; never oil jars or hearths)
	var room: Room = w.room
	if room:
		var lc := room.cell_of(c - room.position)
		for y in range(lc.y - 3, lc.y + 4):
			for x in range(lc.x - 3, lc.x + 4):
				var cc := Vector2i(x, y)
				if not room.char_at(cc) in ["U", "Z", "C", "B"]:
					continue
				var mid := room.position + Room.IN + Vector2(x * Room.TILE + 8, y * Room.TILE + 8)
				if mid.distance_to(c) <= SLAM_R:
					room.damage_obstacle(cc, 1.0)
					if room.char_at(cc) in ["U", "Z", "C", "B"]:
						room.damage_obstacle(cc, 1.0)
	var fx := MoveFx.of(w)
	fx.ring(c, "moves/ring", 26.0)
	fx.flash(c + Vector2(0, -4), Color(1.0, 0.85, 0.6), 1.2, 1.3)
	for i in 10:
		var a := TAU * i / 10.0
		Juice.of(w).lit.burst(c + Vector2.from_angle(a) * SLAM_R * 0.8, 2, 10.0, 30.0, Vector2.from_angle(a), 0.6, 0.45, FxParts.DUST, -20.0, 4.0, 1)
	Audio.play("thud_heavy", 2.0, 0.05)
	w.shake(5.0)
	w.hitstop(0.06 if hits > 0 else 0.03, 0.08)
	p._sq = -1.0
	p._sq_v = 0.0
	if stunned >= 3:
		Achievements.unlock("move_slam")


# ================================================================ Blink (Moonwick)

func _use_blink(dir: Vector2) -> bool:
	var room: Room = w.room
	if room == null:
		return false
	var from := p.global_position
	var to := Moves.blink_target(room, from, dir, BLINK_DIST)
	var fx := MoveFx.of(w)
	fx.burst(from + Vector2(0, -7), "moves/blink", 18.0)
	var steps := int(from.distance_to(to) / 9.0)
	for i in steps:
		var at := from.lerp(to, (i + 1.0) / (steps + 1.0)) + Vector2(0, -6)
		Juice.of(w).hot.emit(at, Vector2(0, -6), randf_range(0.25, 0.4), FxParts.MOON, -4.0, 2.0, 1)
	p.global_position = to
	p.vel *= 0.4
	p.invuln = maxf(p.invuln, BLINK_INVULN)
	p._sq = 0.9
	p._sq_v = 0.0
	fx.burst(to + Vector2(0, -7), "moves/blink", 18.0, true)
	w.fx_ring(to + Vector2(0, -6), Color("#cae6f5"))
	Audio.play("teleport", 0.0, 0.06, 1.15)
	# over a pit? ("Mind the Gap": three in one room)
	var crossed := false
	for i in 12:
		var at := from.lerp(to, i / 11.0)
		if room.char_at(room.cell_of(at - room.position)) == "P":
			crossed = true
	if crossed:
		_pits += 1
		if _pits >= 3:
			Achievements.unlock("move_blink")
	return true


## Where a Blink from `from` toward `dir` lands: as far as `dist` along the line, over pits, spikes,
## cobwebs, hearths and single tiles of rubble, never through two solid tiles in a row, a wall or a
## closed door; then the nearest free spot to that point (the candle is never put inside anything).
static func blink_target(room: Room, from: Vector2, dir: Vector2, dist: float) -> Vector2:
	var reach := 0.0
	var run_cells := {}       # solid cells crossed in the current run
	var run_d := 0.0          # where that run began
	var stopped := false      # a wall or two tiles of rubble ended the line early
	var last_ok := 0.0        # the furthest free point on the line (before any stop)
	var d := 0.0
	while d <= dist:
		var at := from + dir * d
		var lp := at - room.position
		if lp.x < Room.IN.x + Player.RADIUS or lp.x > Room.IN.x + Room.COLS * Room.TILE - Player.RADIUS \
				or lp.y < Room.IN.y + 3.0 or lp.y > Room.IN.y + Room.ROWS * Room.TILE - 2.0:
			stopped = true
			break   # the wall (and every door in it)
		var c := room.cell_of(lp)
		if room.char_at(c) in SOLID_HARD:
			if run_cells.is_empty():
				run_d = d
			run_cells[c] = true
			if run_cells.size() >= 2:
				reach = maxf(0.0, run_d - 2.0)   # two solid tiles in a row: a wall of rubble, stop in front
				stopped = true
				break
		else:
			run_cells.clear()
		reach = d
		if not room.blocked(at, Player.RADIUS):
			last_ok = d
		d += 2.0
	last_ok = minf(last_ok, reach)
	var goal := from + dir * reach
	if not room.blocked(goal, Player.RADIUS):
		return goal
	# the nearest free spot round the goal (rings of 16 directions); never further along the line than
	# the stop when something stopped it (no sliding round a wall of rubble), else the last free point
	var want := from + dir * (reach if stopped else dist)
	for r in [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]:
		var best := Vector2.INF
		for k in 16:
			var q: Vector2 = goal + Vector2.from_angle(TAU * k / 16.0) * float(r)
			if room.blocked(q, Player.RADIUS) or q.distance_to(from) > dist + 4.0:
				continue
			if stopped and (q - from).dot(dir) > reach + 0.5:
				continue
			if best == Vector2.INF or q.distance_to(want) < best.distance_to(want):
				best = q
		if best != Vector2.INF:
			return best
	return from + dir * last_ok


# ================================================================ Flare Up (Tallow)

func _use_flare() -> bool:
	p.wax -= FLARE_COST
	_flare_t = FLARE_TIME
	_heat_t = 0.0
	_flare_kills0 = int(w.kills)
	w.fx_text(p.global_position + Vector2(0, -30), L.t("-{n} min", {"n": int(FLARE_COST)}), UI.EMBER)
	MoveFx.of(w).flash(p.global_position + Vector2(0, -12), Color(1.0, 0.62, 0.3), 1.8, 1.4)
	Juice.of(w).hot.burst(p.to_global(p.wick_tip()), 14, 40.0, 110.0, Vector2.UP, 1.1, 0.45, FxParts.SPARK, 60.0, 1.5, 1, true)
	Audio.play("burn_whoosh", 3.0, 0.04, 0.9)
	Audio.play("fire_crackle", -6.0)
	w.shake(2.0)
	p._sq_v += 6.0
	return true


func _flare_step(dt: float) -> void:
	_flare_t -= dt
	_heat_t -= dt
	if _heat_t <= 0.0:
		_heat_t = HEAT_TICK
		var c := p.global_position + Vector2(0, -4)
		for e in w.enemies.duplicate():
			if not is_instance_valid(e) or not e.alive or not e.active or e.boss or e.buried:
				continue
			var to: Vector2 = e.global_position - c
			if to.length() <= HEAT_R + e.radius:
				e.take_hit(HEAT_DMG * p.damage, to.normalized() * 60.0, FLARE_BURN)
				Juice.of(w).sparks(e.global_position + Vector2(0, -e.half_h), to.normalized(), 3)
	if int(w.kills) - _flare_kills0 >= 3:
		Achievements.unlock("move_flare")
	if _flare_t <= 0.0:
		_flare_t = 0.0
		Audio.play("sizzle", -8.0)


# ================================================================ Snuff (Black Taper)

func _use_snuff() -> bool:
	_snuff_t = SNUFF_TIME
	_wisp_t = 0.0
	dark = true
	_dark_at = p.global_position
	_dark_t = 0.0
	var tip := p.to_global(p.wick_tip())
	w.fx_smoke(tip + Vector2(0, -4))
	Juice.of(w).lit.burst(tip, 6, 6.0, 18.0, Vector2.UP, 0.8, 0.8, FxParts.SMOKE, -10.0, 1.5, 1)
	Audio.play("snuff_out", 0.0, 0.05)
	p._sq_v -= 4.0
	return true


func _end_snuff(relight: bool) -> void:
	if _snuff_t <= 0.0 and not dark:
		return
	_snuff_t = 0.0
	dark = false
	if not relight or not _live:
		return
	_black = true
	var tip := p.to_global(p.wick_tip())
	MoveFx.of(w).burst(tip + Vector2(0, -3), "moves/relight", 16.0)
	Juice.of(w).hot.burst(tip, 8, 20.0, 60.0, Vector2.UP, 1.2, 0.35, FxParts.VOID, 20.0, 2.0, 1)
	Audio.play("match_strike", 0.0, 0.04, 0.8)
	p._sq_v += 4.0


## The black flame: "Lights Out" when one shot runs through three foes.
func _watch_black() -> void:
	if _black_shot == null:
		return
	var s: Shot = _black_shot.get_ref()
	if s == null or not is_instance_valid(s):
		_black_shot = null
		return
	var n: int = s._hit.size()
	if n > _black_hits:
		_black_hits = n
		Juice.of(w).hot.burst(s.global_position, 6, 25.0, 70.0, s.vel.normalized(), 0.8, 0.3, FxParts.VOID, 0.0, 3.0, 1, true)
		if n == 1:
			w.fx_text(s.global_position + Vector2(0, -14), L.t("Black flame!"), BLACK_TEXT)
			w.hitstop(0.035, 0.1)
		if n >= 3:
			Achievements.unlock("move_snuff")


# ================================================================ drawing (around the candle)

func _draw() -> void:
	if _slam_t >= 0.0:
		# the Slam's reach, chalked on the floor as it winds up (gold and cream dots)
		var k := 1.0 - clampf(_slam_t / SLAM_WINDUP, 0.0, 1.0)
		var r := SLAM_R * (0.55 + 0.45 * k)
		var n := 28
		for i in n:
			var at := (Vector2.from_angle(TAU * i / n) * r).round()
			draw_rect(Rect2(at - Vector2(0, 1), Vector2(2, 1)), RING_COLS[i % 2])
	if _flare_t > 0.0:
		_draw_heat(false)


## Flare Up's ring of heat: eight small flames circling the candle's foot (the back half is drawn
## behind the candle by `_back`, the front half in front of it).
func _draw_heat(back: bool) -> void:
	if _flare_t <= 0.0:
		return
	var frames: Array[Texture2D] = Art.seq("hero/flame_small")
	if frames.is_empty():
		return
	var target: CanvasItem = _back if back else self
	for i in 8:
		var a := TAU * i / 8.0 + _anim * 3.2
		var at := Vector2(cos(a) * 11.0, sin(a) * 5.0 - 2.0).round()
		if (sin(a) < 0.0) != back:
			continue
		var tex: Texture2D = frames[(int(_anim * 10.0) + i) % frames.size()]
		target.draw_texture(tex, at - Vector2(4, 11))
