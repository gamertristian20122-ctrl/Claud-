class_name Player
extends Node2D
## Tallow, the candle. Position = the point under the dish (feet). The wax body is drawn in code so
## it gets shorter as the wax (health + clock) burns down; the light radius shrinks with it.
## Look ("Tallow, reborn", art_source/hero_reborn/): a chubby gumdrop with an overhanging drippy lip,
## a wavy melted edge, a wax tear on each side, two stub arms and rosy cheeks, in a 19x7 brass dish.
## One wax row melts every quarter hour, from the belly first, so the face never melts away; the
## flame (7x10 -> 5x8 -> 3x5), the light and the face (worried near 1:00, tired near 2:00) follow.
## Juice (all visual): breathing, squash & stretch, hops, recoil, hurt flash, tears that run down
## the sides, a guttering flame at low wax, holding a new relic aloft, and a melt-down at the end.

const OUTLINE := Color("#21141b")
const WAX_HI := Color("#fdf7ed")
const WAX := Color("#fdf7ed")
const WAX_SH := Color("#e2b694")
const WAX_DEEP := Color("#c38d70")
const POOL := Color("#e2b694")
const CHEEK := Color("#f78697")
const GLINT := Color("#cae6f5")
const GLINT_SH := Color("#72d6ce")
const RADIUS := 5.0
## Mood thresholds in wax as a 4-floor candle shows it (shown_wax: the fraction of the night left x 120):
## worried from 12:45 AM on a 4-floor night (the mid stage), tired from 1:27; the same fractions on longer nights.
const WORRIED_AT := 75.0
const TIRED_AT := 33.0
## The wavy melted edge under the lip: 1 = it runs one pixel lower at this column (x = -6..6, repeats).
const EDGE_WAVE := [1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0]
## Rows above the belly per stage (the belly rows and the bottom row follow).
const TOP_ROWS := {
	"full": ["rim", "pool", "lip", "edge1", "edge2", "eye1", "eye2", "eye3", "cheek"],
	"mid": ["rim", "pool", "lip", "edge1", "eye1", "eye2", "eye3", "cheek"],
	"low": ["pool", "lip", "eye1", "eye2", "eye3", "cheek"],
}
## Stub arms (o = outline, W = wax, s = shade); "high" is the raised pair for holding a relic aloft.
const ARM_L := [".oo.", "oWWo", "oWso", ".oo."]
const ARM_R := [".oo.", "oWso", "osso", ".oo."]
const ARM_UP_L := [".oo.", "oWWo", "oWWo", "oWso", ".oo."]
const ARM_UP_R := [".oo.", "oWso", "oWso", "osso", ".oo."]
const ARM_POSE := {"rest": Vector2i(0, 0), "low": Vector2i(0, 1), "fwd": Vector2i(1, -1), "back": Vector2i(0, 1),
	"flail": Vector2i(0, -3), "cheer": Vector2i(1, -4)}
## Flame sprites (tools/art_hero_fx_items.py): 9x12 canvases, the wick tip at (4, 11).
const FLAME_KINDS := {"idle": 8.0, "trail": 8.0, "flare": 6.0, "mid": 6.0, "small": 5.0, "blown": 6.0}
const FLAME_OFS := Vector2(-4, -11)
static var _flame_sets := {}
## The flame leans by shifting whole pixel rows (no rotation, so the pixel grid stays intact).
const LEAN_SHADER := preload("res://scripts/game/flame_lean.gdshader")

var world: Node

# ---- stats (items change these)
var damage := 1.0
var fire_delay := 0.42
var shot_speed := 150.0
var shot_range := 120.0
var speed := 74.0
var shots := 1
var spread := 12.0
var pierce := 0
var homing := 0.0
var burn := 0.0
var knockback := 70.0
var shot_scale := 1.0
var blue := false
var drain_mult := 1.0
var wax_coat := false
var coat_ready := true
var revives := 0
var luck := 0.0
var hourglass := 0.0
var slow_aura := 0.0
var witching := false
var hot_drip := false
var hit_mult := 1.0
var light_mult := 1.0     # the size of the candle's light (the Black Taper's is short: Candles "light")
var charred := 0.0        # max wax sold at the Smoke Altar (shown burnt on the bar)
var gutter_used := false  # once per floor a killing hit leaves you at 1 minute
var chill_t := 0.0        # touched by a chilled foe: melt faster for a while
var keepsake := ""        # held charge item
var charge := 0
var rites: Array[String] = []
# ---- which candle this is (Candle Box)
var candle_id := "tallow"
var body_w := 13          # wax width at the eyes (odd; Tallow 13 px, 15 at the gumdrop belly)
var c_hi := WAX_HI
var c_wax := WAX
var c_sh := WAX_SH
var c_deep := WAX_DEEP
var c_cheek := CHEEK
var c_ink := OUTLINE      # eyes and mouth (the Black Taper's are pale, or they vanish on black wax)
var stripes := false
var foil := false
var straight := false     # Altar Pillar: straight sides, no gumdrop belly


func apply_candle(id: String) -> void:
	candle_id = id
	var d: Dictionary = Candles.def_of(id)
	wax = d["wax"]
	wax_max = d["wax"]
	drain_mult *= d["drain"]
	speed *= d["speed"]
	damage *= d["damage"]
	fire_delay *= d["fire_delay"]
	hit_mult *= d.get("hit", 1.0)
	light_mult *= d.get("light", 1.0)
	shots = d["shots"]
	body_w = d["body_w"]
	var cs: Array = d["colours"]
	c_hi = Color(cs[0])
	c_wax = Color(cs[1])
	c_sh = Color(cs[2])
	c_deep = Color(cs[3])
	c_cheek = Color(d.get("cheek", "#f78697"))
	c_ink = Color(d.get("ink", "#21141b"))
	face_state = ""
	stripes = d.get("stripes", false)
	foil = d.get("foil", false)
	straight = d.get("straight", false)
	pierce += int(d.get("pierce", 0))            # Moonwick's sparks pass through one foe
	holder_tex = d.get("holder", "hero/holder")  # Moonwick's silver dish
	moonlit = d.get("moon", false)              # ... and its cool light
	if holder:
		holder.texture = Art.tex(holder_tex)
		_dish_back = Art.tex(holder_tex + "_back")
	if light and moonlit:
		light.color = Color(0.8, 0.88, 1.0)
		glow.color = Color(0.9, 0.94, 1.0)
	queue_redraw()

# ---- state
var wax := 120.0
var wax_max := 120.0
var coins := 0
var bombs := 1
var relics: Array[String] = []
var vel := Vector2.ZERO
var move_input := Vector2.ZERO
var aim_input := Vector2.ZERO
var facing := Vector2.RIGHT
var fire_cd := 0.0
var move_cd := 0.0         # v2.3: seconds until the special move is back (Moves, scripts/game/moves.gd)
## Design pass (docs/design/MDA.md): a fire press in the last FIRE_BUFFER s of the cooldown fires the
## moment the flame is ready; turning back from a run uses TURN_ACCEL so a dodge reads at once.
const FIRE_BUFFER := 0.2
const TURN_ACCEL := 2600.0
## v2.8 (pace): walking through rooms with nothing in them was 44% of a run (two bot runs on 2.7.0). In a room
## that is clear and quiet Tallow walks HURRY times as fast; it builds over HURRY_RAMP seconds and is gone
## HURRY_DROP seconds after a room wakes. His fighting pace (and every dodge) is unchanged.
const HURRY := 1.6
const HURRY_RAMP := 0.45
const HURRY_DROP := 0.12
const HURRY_STRIDE := 1.3   # the hops speed up a little less than the feet
var hurry := 0.0            # 0..1: how much of the hurry is on
var _fire_buf := 0.0
var _buf_dir := Vector2.RIGHT
var invuln := 0.0
var dead := false
var frozen := false
var face_state := "open"
var _blink := 2.0
var _hurt_face := 0.0
var _happy_face := 0.0
var _bob := 0.0
var _drip_t := 0.0
var _recoil := 0.0
var _lean := 0.0
# ---- juice state (visual only)
var _sq := 0.0            # > 0 stretch (taller, narrower), < 0 squash
var _sq_v := 0.0
var _was_moving := false
var _breath := 0.0
var _white := 0.0         # hurt flash
var _hit_t := 0.0         # v2.6: the hit mark on the side a blow came from (seconds left)
var _hit_dir := Vector2.ZERO
var _hitmark: Node2D
var _recoil_off := Vector2.ZERO
var _drips: Array = []    # [side -1/1, progress 0..1, speed]
var _drip_spawn := 0.8
var _sput := 0.0          # low wax: the flame gutters
var _sput_t := 0.5
var _wisp_t := 0.4
var _hold_t := 0.0        # holding a new relic aloft
var _held: Sprite2D
var _glint: AnimatedSprite2D
var _melt := 0.0          # death: 0..1 over ~1.2 real seconds
var _melt_from := -1
var _popped := false
var _stained := false
var _pool: Node2D         # the melt puddle (drawn above the dish)
var _front: Node2D        # in front of the dish: the wax collecting in it, the arms, the clock rite's gear
## Title screen: the wick starts unlit, then the light blooms (light_k 0 -> ~1.3 -> 1).
var unlit := false
var light_k := 1.0
# the body's shape this frame, in whole pixels (set in _process, used by _draw)
var _h := 12              # wax rows (with the juice)
var _bw := 13
var _top := -17           # the outline row over the top of the wax
var _base := -5           # the bottom wax row (it stands in the dish)
var _g := {}              # Player.shape(): rows, spans, face row, wick tip...
var _lift := 0            # hopping: the whole candle (and its dish) leaves the floor
var _look := 0            # the face turns 1 px toward where Tallow runs or aims
var _arms: Array = ["rest", "rest"]
var _tears := [0, 0]      # extra rows on the left / right tear (a drip running down while walking)

var flame: AnimatedSprite2D
var holder: Sprite2D
var holder_tex := "hero/holder"
var _dish_back: Texture2D
var moonlit := false   # Moonwick: a cool, moon-white light
var face: Sprite2D
var light: PointLight2D
var glow: PointLight2D
var _shown_h := 12


func _ready() -> void:
	_dish_back = Art.tex(holder_tex + "_back")
	# draw order: the body (_draw), the face, the dish's front, then the arms and the wax in the dish
	# Tallow is the light: the wax, face, dish and costumes draw in their own colours (unshaded, see
	# _process) like the concept's in-game mock-up; the children share the Player's material.
	face = Sprite2D.new()
	face.centered = false
	face.region_enabled = true
	face.use_parent_material = true
	add_child(face)
	holder = Sprite2D.new()
	holder.texture = Art.tex(holder_tex)
	holder.centered = false
	holder.offset = Vector2(-9, -5)
	holder.use_parent_material = true
	add_child(holder)
	_front = Node2D.new()
	_front.use_parent_material = true
	_front.draw.connect(_draw_front)
	add_child(_front)
	flame = AnimatedSprite2D.new()
	flame.centered = false
	flame.offset = FLAME_OFS
	flame.z_index = 2
	var fm := ShaderMaterial.new()
	fm.shader = LEAN_SHADER
	flame.material = fm
	add_child(flame)
	_set_flame_frames()
	_update_shape()
	light = PointLight2D.new()
	light.texture = Art.light_tex
	light.color = Color(1.0, 0.74, 0.44) if not moonlit else Color(0.8, 0.88, 1.0)
	light.energy = 1.15
	light.shadow_enabled = true
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	light.shadow_color = Color(0, 0, 0, 0.45)
	light.texture_scale = 1.4
	add_child(light)
	# a tight warm glow so the candle itself always reads in the dark
	glow = PointLight2D.new()
	glow.texture = Art.light_tex
	glow.color = Color(1.0, 0.85, 0.6) if not moonlit else Color(0.9, 0.94, 1.0)
	glow.energy = 0.55
	glow.texture_scale = 0.22
	add_child(glow)
	_pool = Node2D.new()
	_pool.z_index = 1
	_pool.use_parent_material = true
	_pool.draw.connect(_draw_pool)
	add_child(_pool)
	add_child(Costumes.new())
	add_child(Moves.new())   # v2.3 special moves: the candle's own move and its effects
	_hitmark = Node2D.new()   # v2.6: where a blow came from (self-lit, drawn over the candle)
	_hitmark.z_index = 3
	_hitmark.material = Art.unshaded
	_hitmark.draw.connect(_draw_hitmark)
	add_child(_hitmark)


## Call a world effect if this world has it (the title screen's stand-in world does not).
func _fx(method: String, args: Array) -> void:
	if world and world.has_method(method):
		world.callv(method, args)


## Tallow's flame: one SpriteFrames per colour with an animation per kind (idle, trail, flare, mid,
## small, blown), from hero/flame_<kind>_f* and hero/flame_blue_<kind>_f*.
static func flame_frames(is_blue: bool) -> SpriteFrames:
	if _flame_sets.has(is_blue):
		return _flame_sets[is_blue]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for k in FLAME_KINDS:
		sf.add_animation(k)
		sf.set_animation_speed(k, FLAME_KINDS[k])
		sf.set_animation_loop(k, true)
		for t in Art.seq("hero/flame_%s%s" % ["blue_" if is_blue else "", k]):
			sf.add_frame(k, t)
	_flame_sets[is_blue] = sf
	return sf


func _set_flame_frames() -> void:
	var kind := flame.animation if flame.sprite_frames else &"idle"
	flame.sprite_frames = Player.flame_frames(blue)
	flame.play(kind)
	if flame2:
		flame2.sprite_frames = flame.sprite_frames
		flame2.play(kind)


var flame2: AnimatedSprite2D


func refresh_rite_look() -> void:
	if "wick" in rites and flame2 == null:
		flame2 = AnimatedSprite2D.new()
		flame2.centered = false
		flame2.offset = FLAME_OFS
		flame2.z_index = 2
		flame2.material = flame.material
		flame2.sprite_frames = flame.sprite_frames
		flame2.play(flame.animation)
		flame2.frame = 2
		flame2.flip_h = true
		add_child(flame2)
	if "hearth" in rites and not blue:
		light.color = Color(1.0, 0.55, 0.25)
	queue_redraw()


func set_blue(b: bool) -> void:
	blue = b
	_set_flame_frames()
	light.color = Color(0.6, 0.8, 1.0) if b else Color(1.0, 0.74, 0.44)


## Minutes in tonight's night (world.night_minutes: 120 for 4 floors, 210 for 7); 120 away from a run.
func night() -> float:
	return float(world.night_minutes()) if world and world.has_method("night_minutes") else Game.END_MINUTES


## The fraction of the night the wax still holds (1.0 = a full candle; up to 1.35 with spare minutes).
func wax_frac() -> float:
	return clampf(wax / night(), 0.0, 1.35)


## The wax as a 4-floor candle shows it: the body, the face, the dish and the light follow the fraction of the
## night left, so a full 7-floor candle looks like a full 4-floor one (no giant candles). Danger cues (the
## sputter, the HUD's low-wax warnings) stay in real minutes.
func shown_wax() -> float:
	var n := night()
	return wax if n == Game.END_MINUTES else wax * Game.END_MINUTES / n   # a 4-floor night: exactly as it was


## Wax rows at this much wax: one row melts every 18 minutes. Full Tallow (120 wax) = 12 rows, 72 = 9
## (the worried "mid" stage, one melted row under the lip), 30 = 7 (the slump), then he sinks into the dish.
static func rows_for(wax_amount: float) -> int:
	return clampi(int(roundf((clampf(wax_amount, 0.0, 162.0) + 96.0) / 18.0)), 0, 15)


func body_height() -> int:
	return Player.rows_for(shown_wax())


## Where the wick tip is (local), for the title's match and anything that lights or watches the flame.
func wick_tip() -> Vector2:
	return Vector2(_g.get("tip", Vector2i(1, -20))) + (_recoil_off if _recoil > 0.0 else Vector2.ZERO)


## The body's geometry this frame (Costumes and others anchor to it): see Player.shape().
func geo() -> Dictionary:
	return _g


func _physics_process(dt: float) -> void:
	if dead or frozen or _hold_t > 0.0 or Juice.holding(world):
		vel = vel.move_toward(Vector2.ZERO, 600 * dt)
		if not dead:
			# v2.6 (feel): control is away for a moment (a room pan, a trapdoor, a relic held aloft): the flame
			# keeps recharging, and a fire tap in the last FIRE_BUFFER before control returns is kept, not eaten
			fire_cd -= dt
			_fire_buf -= dt
			if aim_input.length() > 0.3:
				_fire_buf = FIRE_BUFFER
				_buf_dir = aim_input.normalized()
		return
	move_cd = maxf(0.0, move_cd - dt)   # the move recharges only in play (not held aloft, carded, melting or paused)
	# v2.8 (pace): in a room that is clear and quiet Tallow hurries; the moment a room wakes he is back to his fighting pace
	var quiet: bool = world != null and world.room != null and bool(world.hurry_ok())
	hurry = move_toward(hurry, 1.0 if quiet else 0.0, dt / (HURRY_RAMP if quiet else HURRY_DROP))
	var target := move_input.limit_length(1.0) * speed * Moves.speed_k(self) * lerpf(1.0, HURRY, hurry)
	var accel := 900.0 if target.length() > 1 else 1100.0
	if target.length() > 1 and vel.length() > 1:
		var turn := vel.dot(target) / (vel.length() * target.length())   # cosine of the swing
		if turn < -0.2:
			accel = TURN_ACCEL   # a dodge: turning back bites at once (design pass: 7 -> 4 frames)
		elif turn < 0.7:
			accel = lerpf(900.0, TURN_ACCEL, (0.7 - turn) / 0.9)   # v2.6: a sharp side-step bites too (90 deg: 7 -> 5 frames)
	accel *= lerpf(1.0, HURRY, hurry)   # v2.8: the hurry turns as sharply as the fighting pace (a 90-degree swing stays 5 frames)
	vel = vel.move_toward(target, accel * dt)
	_move(vel * dt)
	if vel.length() > 8:
		_bob += dt * 14.0 * lerpf(1.0, HURRY_STRIDE, hurry)
		if aim_input.length() < 0.2:
			facing = vel.normalized()
		if fmod(_bob, PI) < 14.0 * dt:
			Audio.play("step", -2.0, 0.15)
	else:
		_bob = 0.0
	# shooting
	fire_cd -= dt
	_fire_buf -= dt
	var aiming := aim_input.length() > 0.3
	if aiming:
		facing = aim_input.normalized()
		if fire_cd > 0.0 and fire_cd <= FIRE_BUFFER:
			_fire_buf = FIRE_BUFFER   # a quick tap just before the flame is ready is kept, not eaten
			_buf_dir = facing
	if (aiming or _fire_buf > 0.0) and fire_cd <= 0.0:
		_fire_buf = 0.0
		var rate := fire_delay
		if witching and wax < 30.0:
			rate *= 0.7
		fire_cd = rate
		_fire(facing if aiming else _buf_dir)
	if invuln > 0:
		invuln -= dt
	# blink only the wax body while invulnerable; the flame and lights stay on (no screen flashing)
	var on := invuln <= 0 or fmod(invuln, 0.16) > 0.07
	self_modulate.a = 1.0 if on else 0.3
	holder.self_modulate.a = self_modulate.a
	face.visible = on
	if hot_drip:
		_drip_t -= dt
		if _drip_t <= 0 and vel.length() > 10:
			_drip_t = 0.35
			world.spawn_hot_drip(global_position)
	if world.room and world.room.spike_hurts(global_position):
		hurt(6.0, Vector2.ZERO)


func _move(d: Vector2) -> void:
	var room: Room = world.room
	if room == null:
		position += d
		return
	d *= room.slow_at(position)   # cobwebs
	var np := position + Vector2(d.x, 0)
	if not room.blocked(np, RADIUS, false, true):
		position = np
	else:
		vel.x = 0
	np = position + Vector2(0, d.y)
	if not room.blocked(np, RADIUS, false, true):
		position = np
	else:
		vel.y = 0


func _fire(dir: Vector2) -> void:
	if RelicFx.before_fire(self, dir): return
	dir = world.assist_aim(global_position, dir)
	var n := shots
	var dmg := damage * Moves.shot_mult(self)   # Flare Up x1.5, the black flame after Snuff x3
	if witching and wax < 30.0:
		dmg *= 1.6
	# extra flames fire in near-parallel lanes so they all reach the same target
	for i in n:
		var k := i - (n - 1) / 2.0
		var off := dir.orthogonal() * k * 4.0
		world.shoot_player(global_position + Vector2(0, -6) + dir * 4 + off, dir.rotated(deg_to_rad(k * 2.5)), self, dmg)
	Audio.play("shoot", 0.0, 0.08)
	_recoil = 0.08
	_recoil_off = Vector2(roundf(-dir.x * 0.75), roundf(-dir.y * 0.75))
	_sq_v -= 2.5
	_fx("fx_muzzle", [global_position + Vector2(0, -6) + dir * 6.0, dir, blue])
	RelicFx.after_fire(self, dir)


func hurt(amount: float, from_dir: Vector2) -> void:
	if dead or invuln > 0 or frozen or _hold_t > 0.0:
		return
	if RelicFx.on_hurt(self, amount, from_dir): return
	if wax_coat and coat_ready:
		coat_ready = false
		invuln = 0.8
		world.fx_text(global_position + Vector2(0, -26), "BLOCKED", UI.GOLD)
		Audio.play("hit_wall", 2.0, 0.05, 0.7)
		return
	amount *= hit_mult
	if wax - amount <= 0.0 and not gutter_used and wax > 1.0:
		# Guttering: the flame clings on once per floor
		gutter_used = true
		amount = wax - 1.0
		wax = 1.0
		invuln = 1.6
		_hurt_fx()
		world.fx_text(global_position + Vector2(0, -34), "GUTTERING!", UI.EMBER)
		if Game.tip("gutter", 1):
			world.hud.show_hint("Guttering: your flame clung on once this floor. Find wax!", 3.0)
		Audio.play("low_wax")
		world.on_player_hurt(amount)
		return
	wax -= amount
	invuln = 1.2
	_hurt_face = 0.6
	_hurt_fx()
	vel += from_dir.normalized() * 140.0
	if from_dir.length() > 0.01:
		# v2.6 (feel): show where it came from - a hot chevron on that side and sparks flying back at it
		_hit_dir = from_dir.normalized()
		_hit_t = HIT_MARK
		_hitmark.queue_redraw()
		_fx("fx_sparks", [global_position + Vector2(0, -8) - _hit_dir * 6.0, -_hit_dir, 5, false])
	Audio.play("player_hurt")
	Game.vibrate(60)
	world.on_player_hurt(amount)
	if wax <= 0:
		die()


const HIT_MARK := 0.3


## A pixel chevron 11 px out on the side the blow came from, pointing at the candle: tip cream, arms red;
## for its last 0.12 s only the tip is left (stepped, no alpha fade).
func _draw_hitmark() -> void:
	if _hit_t <= 0.0 or dead:
		return
	var f := _hit_dir
	var side := Vector2(-f.y, f.x)
	var m := Vector2(0, -8) - f * 11.0
	var tip := (m + f * 2.0).round()
	_hitmark.draw_rect(Rect2(tip - Vector2(1, 1), Vector2(2, 2)), WAX_HI)
	if _hit_t > 0.12:
		for k in [-1.0, 1.0]:
			for step in [1.5, 3.0]:
				var q: Vector2 = (m - f * (step - 1.0) + side * k * step).round()
				_hitmark.draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), Color("#da4e38"))


func _hurt_fx() -> void:
	_white = 0.1
	_sq = -1.0
	_sq_v = 0.0
	_hurt_face = maxf(_hurt_face, 0.6)
	# a little wax is knocked off his shoulders (the concept's hurt frame)
	for s in [-1, 1]:
		_fx("fx_wax_drop", [global_position + Vector2(s * (body_w / 2 + 2), _top + 3),
			Vector2(s * randf_range(25.0, 45.0), -randf_range(40.0, 70.0))])


## A relic was taken: hold it up above the flame for a moment (no moving, no harm meanwhile).
func hold_aloft(tex: Texture2D) -> void:
	if dead or tex == null:
		return
	if _held == null:
		_held = Sprite2D.new()
		_held.z_index = 4
		_held.material = Art.unshaded
		add_child(_held)
		_glint = AnimatedSprite2D.new()
		_glint.sprite_frames = Art.anim("fx/glint", 8.0)
		_glint.material = Art.unshaded
		_glint.z_index = 5
		_glint.play("default")
		add_child(_glint)
	_held.texture = tex
	_held.visible = true
	_glint.visible = true
	_hold_t = 0.9
	_happy_face = 1.4
	_sq_v += 6.0
	vel = Vector2.ZERO


## v2.3 special moves (Moves): ready when recharged and the candle is free to act.
func move_ready() -> bool:
	var m := Moves.of(self)
	return m != null and move_cd <= 0.0 and m.move_id() != "" and Moves.enabled and not m.busy()


## Fire the candle's move (the `special` action, the HUD's move button, the bot). True if it fired.
func use_move(dir := Vector2.ZERO) -> bool:
	return Moves.use(self, world, dir)


func heal(amount: float) -> void:
	wax = minf(wax + amount, wax_max)
	_happy_face = 0.8


func die() -> void:
	if revives > 0:
		revives -= 1
		wax = 40.0
		invuln = 2.0
		world.fx_text(global_position + Vector2(0, -28), "REKINDLED!", UI.GOLD)
		Audio.play("item_get")
		world.fx_ring(global_position, Color(1, 0.6, 0.2))
		return
	_melt_from = maxi(body_height(), 4)
	wax = 0
	dead = true
	world.on_player_died()


func _process(dt: float) -> void:
	_blink -= dt
	_hurt_face -= dt
	_happy_face -= dt
	if _hit_t > 0.0:
		var was := _hit_t
		_hit_t = maxf(0.0, _hit_t - dt)
		if (was > 0.12) != (_hit_t > 0.12) or _hit_t == 0.0:
			_hitmark.queue_redraw()
	# self-lit while the flame burns; unlit (title intro) and melted down, the room's light shows him
	var want: Material = Art.unshaded if not unlit and not dead and light_k >= 0.5 else null
	if material != want:
		material = want
	if _blink < 0:
		_blink = randf_range(2.0, 4.5)
	_juice_step(dt)
	_update_shape()
	var o := _recoil_off if _recoil > 0.0 else Vector2.ZERO
	# face: the mood follows the clock (worried around 1:00 AM, tired near 2:00), hurt and happy on top
	var f := _face_name()
	if f != face_state or face.texture == null:
		face_state = f
		face.texture = Player.face_tex(f, c_ink)
	var fy: int = _g["fy"]
	face.position = Vector2(int(_g["cx"]) - 5, fy) + o
	# rows below the floor are inside the dish (the melt-down sinks him into it)
	face.region_rect = Rect2(0, 0, 11, clampi(-fy, 0, 6))
	face.visible = face.visible and not (dead and _h < 4)
	holder.position = Vector2(0, -_lift) + o
	# flame: 7x10 -> 5x8 -> 3x5 as the wax goes; it streams back while running, flares on a shot or a
	# happy moment, is torn sideways by a hit; it also leans against movement and dips on recoil
	var kind := _flame_kind()
	if flame.animation != kind:
		flame.play(kind)
	flame.flip_h = kind == "trail" and vel.x < 0.0
	var tip: Vector2i = _g["tip"]
	flame.position = Vector2(tip) + o
	_lean = lerpf(_lean, clampf(-vel.x / speed, -1.0, 1.0), minf(1.0, dt * 10.0))
	(flame.material as ShaderMaterial).set_shader_parameter("lean", 0.0 if kind == "trail" else _lean)
	_recoil -= dt
	# (the flare is the shot's own kick; the smaller flames dip on a shot instead)
	var dip := (1 if _recoil > 0 and kind != "flare" else 0) + ((1 if _g["stage"] == "low" else 2) if _sput > 0.0 else 0)
	flame.offset = FLAME_OFS + Vector2(0, dip)
	flame.self_modulate = Color(1.0, 0.62, 0.45) if _sput > 0.0 else Color.WHITE
	flame.visible = (not dead or _melt < 0.25) and not unlit
	# light: flicker + shrink with wax (and die with the flame)
	var t := Time.get_ticks_msec() / 1000.0
	var flick := 1.0 + 0.045 * sin(t * 13.0) + 0.03 * sin(t * 23.7 + 1.3) + randf_range(-0.015, 0.015)
	var wf := clampf(wax_frac(), 0.0, 1.0)
	light.texture_scale = lerpf(0.95, 1.5, wf) * flick * light_mult
	if world and world.get("omen") == "smoky_halls":
		light.texture_scale = maxf(0.95 * light_mult, light.texture_scale * 0.85)
	light.texture_scale *= AreaGimmicks.light_mult(world)   # the attic's deep dark
	var keep := clampf(1.0 - _melt / 0.8, 0.0, 1.0)
	if dead:
		light.energy = 1.0 * keep * flick
		light.texture_scale *= lerpf(0.55, 1.0, keep)
	else:
		light.energy = lerpf(0.95, 1.2, wf) * flick * (0.55 if _sput > 0.0 else 1.0)
	if unlit or light_k != 1.0:
		var lk := 0.0 if unlit else light_k
		light.energy *= lk
		light.texture_scale *= 0.3 + 0.7 * minf(lk, 1.0) + 0.25 * maxf(0.0, lk - 1.0)
	light.position = flame.position + Vector2(0, -4)
	if flame2:
		var tip2: Vector2i = _g["tip2"]
		flame2.position = Vector2(tip2) + o
		flame2.offset = flame.offset
		var kind2 := "small" if kind in ["mid", "small"] else "mid"   # the second wick burns smaller
		if flame2.animation != kind2:
			flame2.play(kind2)
		flame2.flip_h = not flame.flip_h if kind != "trail" else flame.flip_h
		flame2.visible = flame.visible
	if "hearth" in rites:
		light.texture_scale *= 1.12
	glow.position = light.position
	glow.energy = 0.55 * keep if dead else (0.0 if unlit else 0.55 * minf(1.0, light_k))
	_shown_h = _h
	queue_redraw()
	_front.queue_redraw()
	_pool.queue_redraw()


func _mood() -> String:
	if shown_wax() < TIRED_AT:
		return "tired"
	if shown_wax() < WORRIED_AT:
		return "worried"
	return ""


func _face_name() -> String:
	if dead or _hurt_face > 0.0:
		return "hurt"
	if _happy_face > 0.0 or _hold_t > 0.0:
		return "happy"
	var mood := _mood()
	if _blink < 0.12:
		return "blink" + ("_" + mood if mood != "" else "")
	if mood != "":
		return mood
	if _recoil > 0.0:
		return "shout"
	if move_input.length() > 0.2 or aim_input.length() > 0.3:
		return "brave"
	return "open"


func _flame_kind() -> String:
	var stage: String = _g["stage"]
	if dead:
		return "small"
	if stage == "low":
		return "small"
	if stage == "mid":
		return "mid"
	if _hurt_face > 0.3:
		return "blown"
	if _recoil > 0.0 or _happy_face > 0.0 or _hold_t > 0.0:
		return "flare"
	if absf(vel.x) > speed * 0.45:
		return "trail"
	return "idle"


## Squash & stretch, breathing, hops, drips, guttering, the held relic and the melt-down.
func _juice_step(dt: float) -> void:
	var held := Juice.holding(world)
	var moving := move_input.length() > 0.2 and not frozen and not dead and _hold_t <= 0.0 and not held
	if moving != _was_moving:
		_sq_v += 11.0 if moving else -11.0
		_was_moving = moving
	var rest := 0.35 if _hold_t > 0.0 else 0.0
	_sq_v += (-(_sq - rest) * 300.0 - _sq_v * 18.0) * dt
	_sq = clampf(_sq + _sq_v * dt, -1.2, 1.2)
	_white -= dt
	_breath += dt
	# hops while running: two little hops per stride (one per footstep), the dish leaves the floor
	_lift = 0
	var hop_dn := 0
	if moving and vel.length() > 8.0:
		var s := absf(sin(_bob))
		_lift = 2 if s > 0.8 else (1 if s > 0.35 else 0)
		hop_dn = _lift - 1   # squashed on landing, stretched at the top
	# arms: swing while running, flail when hit, cheer when happy, up when holding a relic aloft
	var fx := 1 if facing.x > 0.3 else (-1 if facing.x < -0.3 else 0)
	_look = fx if (moving or aim_input.length() > 0.3 or _recoil > 0.0) and not dead else 0
	if dead:
		_arms = [null, null]
	elif _hold_t > 0.0:
		_arms = ["high", "high"]
	elif _hurt_face > 0.0:
		_arms = ["flail", "flail"]
	elif _happy_face > 0.0:
		_arms = ["cheer", "cheer"]
	elif _recoil > 0.0 and fx != 0:
		_arms = ["rest", "fwd"] if fx > 0 else ["fwd", "rest"]
	elif _lift != 1 and moving and vel.length() > 8.0:
		var a := ["back", "fwd"] if (int(_bob / PI) % 2 == 0) == (_lift == 0) else ["fwd", "back"]
		if vel.x < 0.0:
			a.reverse()
		_arms = a
	elif shown_wax() < TIRED_AT:
		_arms = ["low", "low"]
	else:
		_arms = ["rest", "rest"]
	var still := not moving and vel.length() < 8.0
	var breathe := -1 if (still and not dead and sin(_breath * 2.6) > 0.55 and body_height() >= 10) else 0
	# happy (a relic, a heal, the ending): a little victory jump, stretched up
	if _happy_face > 0.0 and _hold_t <= 0.0 and not moving and not dead:
		_lift = 1
		hop_dn = 1
	_dn = int(roundf(_sq * 2.0)) + breathe + hop_dn
	_side = clampi(-int(roundf(_sq)), -1, 1)
	_h0 = body_height()
	if dead:
		var k := clampf(_melt / 0.85, 0.0, 1.0)
		var from := _melt_from if _melt_from > 0 else 4
		_h0 = int(roundf(float(from) * (1.0 - k * k * (3.0 - 2.0 * k))))
		_dn = 0
		_side = 0
		_lift = 0
	# wax tears run down the sides while walking, then drop to the floor
	var stage := "full" if _h0 >= 10 else ("mid" if _h0 == 9 else "low")
	if moving and vel.length() > 20.0 and stage != "low":
		_drip_spawn -= dt
		if _drip_spawn <= 0.0:
			_drip_spawn = randf_range(0.7, 1.5)
			if _drips.size() < 2:
				_drips.append([-1 if randf() < 0.5 else 1, 0.0, randf_range(0.8, 1.25)])
	var i := _drips.size() - 1
	_tears = [0, 0]
	while i >= 0:
		var d: Array = _drips[i]
		d[1] += dt * 0.9 * float(d[2]) * (1.0 if moving else 0.4)
		if d[1] >= 1.0 or dead or stage == "low":
			_drips.remove_at(i)
			if not dead and stage != "low":
				var x := (-body_w / 2 - 2) if d[0] < 0 else (body_w / 2 + 2)
				_fx("fx_wax_drop", [global_position + Vector2(x, _base - 1), vel * 0.3])
		else:
			var side_i := 0 if d[0] < 0 else 1
			_tears[side_i] = maxi(_tears[side_i], int(float(d[1]) * 6.0))
		i -= 1
	# low wax: the flame sputters and smokes
	_sput -= dt
	if not dead and wax < 24.0:
		_sput_t -= dt
		if _sput_t <= 0.0:
			_sput_t = randf_range(0.25, 1.1)
			_sput = randf_range(0.06, 0.16)
		_wisp_t -= dt
		if _wisp_t <= 0.0:
			_wisp_t = randf_range(0.35, 0.8)
			_fx("fx_wisp", [flame.global_position + Vector2(0, -7)])
	# holding a relic aloft (a gold glint winks on it)
	if _hold_t > 0.0:
		_hold_t -= dt
		var up := minf(1.0, (0.9 - _hold_t) / 0.15)
		_held.position = Vector2(0, roundf(_top - 20 - 3.0 * up))
		_glint.position = _held.position + Vector2(6, -6)
		_glint.visible = fmod(_hold_t, 0.3) > 0.1
		if _hold_t <= 0.0:
			_held.visible = false
			_glint.visible = false
			_fx("fx_glint", [_held.global_position])
	# death: the body sinks into the dish, the wax fills it and spills, the flame pops into smoke
	if dead:
		if _melt == 0.0:
			_drips.clear()
			if _melt_from < 0:
				_melt_from = 4
		_melt = minf(1.0, _melt + dt / maxf(Engine.time_scale, 0.01) / 1.2)
		if _melt >= 0.8 and not _popped:
			_popped = true
			_fx("fx_smoke", [global_position + Vector2(0, _top - 6)])
			_fx("fx_wisp", [global_position + Vector2(0, _top - 2)])
		if _melt >= 0.95 and not _stained:
			_stained = true
			_fx("fx_stain", [global_position + Vector2(0, -1), "wax", true])


var _dn := 0      # belly rows added (stretch, hop) or taken (squash, breath) this frame
var _side := 0    # 1 px wider (squash) or narrower (stretch)
var _h0 := 12     # wax rows from the wax alone (sets the stage, so the face never jumps)


func _update_shape() -> void:
	var w := maxi(5, body_w / 2 + _side)
	_g = Player.shape(_h0, _dn, w, _lift, _look, straight, foil, "wick" in rites)
	_h = int(_g["h"])
	_bw = 2 * w + 1
	_base = int(_g["base"])
	_top = int(_g["top"]) - 1


func _colours() -> Dictionary:
	var white := _white > 0.0
	if white:
		var wc := Color.WHITE
		return {"ol": OUTLINE, "hi": wc, "wax": wc, "sh": wc, "deep": wc, "cheek": wc, "foil": wc, "foil_sh": wc}
	return {"ol": OUTLINE, "hi": c_hi, "wax": c_wax, "sh": c_sh, "deep": c_deep, "cheek": c_cheek,
		"foil": Color("#b6cbcf"), "foil_sh": Color("#7b8994")}


func _draw() -> void:
	# ground shadow (pixel ellipse; it stays on the floor when Tallow hops)
	var sh := Color(0, 0, 0, 0.35)
	draw_rect(Rect2(-7, -1, 15, 1), sh)
	draw_rect(Rect2(-9, 0, 19, 1), sh)
	var o := _recoil_off if _recoil > 0.0 else Vector2.ZERO
	var white := _white > 0.0
	var c := _colours()
	var ha := holder.self_modulate.a
	holder.self_modulate = Color(3, 3, 3, ha) if white else Color(1, 1, 1, ha)
	_front.self_modulate.a = self_modulate.a
	if _dish_back:
		draw_texture(_dish_back, Vector2(-9, -7 - _lift) + o, Color(3, 3, 3) if white else Color.WHITE)
	if _h <= 0:
		_draw_wick(o, true)
		return
	Player.paint_body(self, o, _g, c, stripes, _tears)
	if face.visible and face_state != "hurt":
		Player.paint_cheeks(self, o, _g, c["cheek"])
	if face.visible and face_state in ["tired", "blink_tired"]:
		# a sweat drop by his head
		var sx: int = Player.span_at(_g, int(_g["fy"])).y + 2
		var sy: int = int(_g["fy"]) - 2
		draw_rect(Rect2(Vector2(sx + 1, sy) + o, Vector2(1, 2)), GLINT)
		draw_rect(Rect2(Vector2(sx, sy + 1) + o, Vector2(1, 1)), GLINT)
		draw_rect(Rect2(Vector2(sx + 1, sy + 1) + o, Vector2(1, 1)), GLINT_SH)
	_draw_wick(o, false)


## In front of the dish: the wax it collects as the night goes on, the stub arms, the clock rite.
func _draw_front() -> void:
	var o := _recoil_off if _recoil > 0.0 else Vector2.ZERO
	var c := _colours()
	var d := o + Vector2(0, -_lift)
	if not dead:
		# clean at full wax, a puddle from about a quarter gone, spilling over the lip near the end
		var sw := shown_wax()
		var p := clampf((105.0 - sw) / 65.0, 0.0, 1.0)
		var span := int(roundf(2.0 + 5.0 * p)) if p > 0.05 else 0
		var runs := Vector2i.ZERO
		if sw < 42.0:
			runs = Vector2i(3 if sw < 18.0 else (2 if sw < 34.0 else 1), 2 if sw < 18.0 else 1)
		Player.paint_dish_wax(_front, d, span, runs, c)
	if _h > 0 and not dead:
		Player.paint_arms(_front, o, _g, c, _arms)
	if "clock" in rites:
		# a little brass gear on the dish
		_front.draw_rect(Rect2(Vector2(-7, -4) + d, Vector2(3, 3)), Color("#facb3e"))
		_front.draw_rect(Rect2(Vector2(-8, -3) + d, Vector2(1, 1)), Color("#c56025"))
		_front.draw_rect(Rect2(Vector2(-4, -3) + d, Vector2(1, 1)), Color("#c56025"))
		_front.draw_rect(Rect2(Vector2(-6, -1) + d, Vector2(1, 1)), Color("#c56025"))
		_front.draw_rect(Rect2(Vector2(-6, -3) + d, Vector2(1, 1)), Color("#21141b"))


func _draw_wick(o: Vector2, flat: bool) -> void:
	var tip: Vector2i = _g["tip"]
	if flat:
		# melted away: only the wick is left, lying in the dish
		draw_rect(Rect2(Vector2(-1, -5) + o, Vector2(3, 1)), OUTLINE)
	else:
		Player.paint_wick(self, o, _g, OUTLINE)
	if dead and _melt >= 0.25 and _melt < 0.8:
		# the flame is dying: a small code-drawn flame that shrinks, then pops
		var fx := tip.x if not flat else 0
		var fy := (tip.y - 1) if not flat else -6
		if _melt < 0.55:
			draw_rect(Rect2(Vector2(fx - 1, fy - 2) + o, Vector2(3, 3)), Color("#ee8e2e"))
			draw_rect(Rect2(Vector2(fx, fy - 3) + o, Vector2(1, 1)), Color("#da4e38"))
			draw_rect(Rect2(Vector2(fx, fy - 1) + o, Vector2(1, 2)), Color("#facb3e"))
		else:
			draw_rect(Rect2(Vector2(fx, fy - 1) + o, Vector2(1, 2)), Color("#ee8e2e"))
			draw_rect(Rect2(Vector2(fx, fy - 2) + o, Vector2(1, 1)), Color("#da4e38"))


## The melt-down: wax fills the brass dish, runs down its front and spreads into a puddle on the floor
## (drawn above the dish; its bowl row is y = -4, the floor row y = 0).
func _draw_pool() -> void:
	if not dead or _melt <= 0.05:
		return
	var k := clampf((_melt - 0.05) / 0.8, 0.0, 1.0)
	var c := _colours()
	# 1) the dish fills, 2) it spills over the front in two runs of different lengths ...
	var span := int(roundf(lerpf(4.0, 8.0, minf(1.0, k * 2.2))))
	var runs := Vector2i.ZERO
	if k > 0.3:
		var run := clampi(int((k - 0.3) / 0.25 * 3.0), 1, 3)
		runs = Vector2i(run, maxi(1, run - 1))
	Player.paint_dish_wax(_pool, Vector2.ZERO, span, runs, c)
	# 3) ... and spreads into a puddle around the dish
	if k > 0.55:
		var fw := int(roundf(lerpf(14.0, 30.0, (k - 0.55) / 0.45)))
		var fl := -fw / 2
		_pool.draw_rect(Rect2(fl, -1, fw, 3), OUTLINE)
		_pool.draw_rect(Rect2(fl - 1, 0, fw + 2, 2), OUTLINE)
		_pool.draw_rect(Rect2(fl + 1, 0, fw - 2, 1), c["hi"])
		_pool.draw_rect(Rect2(fl, 1, fw, 1), c["sh"])
		_pool.draw_rect(Rect2(fl + 2, 0, maxi(1, fw / 4), 1), c["wax"])
		_pool.draw_rect(Rect2(fl + fw - 3, 1, 2, 1), c["deep"])


# ================================================================ the body, in whole pixels
# Static so the Journal's Candle Box page, the title and the tests paint candles the same way.

## Geometry for `h0` wax rows (from the wax alone: it sets the stage, full / mid / low), `dn` belly
## rows added by the juice (negative = squashed: once the belly is gone the body sinks into the dish),
## half-width `w` (Tallow 6), `lift` px off the floor, the face turned `look` px. Rows: [y, kind, lo, hi].
static func shape(h0: int, dn: int, w: int, lift: int, look: int, is_straight: bool, is_foil: bool,
		two_wicks := false) -> Dictionary:
	var stage := "full" if h0 >= 10 else ("mid" if h0 == 9 else "low")
	var kinds: Array = (TOP_ROWS[stage] as Array).duplicate()
	var n := h0 - kinds.size() - 1 + dn
	var sink := 0
	if n < 0:
		sink = -n
		n = 0
	for i in n:
		kinds.append("belly")
	kinds.append("bottom")
	if is_foil:
		kinds.append_array(["foil", "foil"])   # the tea light's cup: it never melts
	var base := -5 - lift
	var t := base + sink - kinds.size() + 1
	var rows: Array = []
	var at := {}
	for i in kinds.size():
		var k: String = kinds[i]
		var y := t + i
		if not at.has(k):
			at[k] = y
		var hw := w
		var bulge := w if is_straight else w + 1
		if stage == "low":
			hw = w - 1 if k == "pool" else (w + 1 if k == "lip" else bulge)
		elif k == "rim":
			hw = w - 2
		elif k == "lip":
			hw = w + 1
		elif k in ["cheek", "belly", "bottom", "foil"]:
			hw = bulge
		if k == "foil":
			hw = w + 1
		rows.append([y, k, -hw, hw])
	var yp: int = at["pool"]
	var bent := stage == "low"
	var tip := Vector2i(1, yp - 2) if bent else Vector2i(1, yp - 3)
	var tip2 := Vector2i(-5, yp - 2) if bent else Vector2i(-5, yp - 3)
	return {"rows": rows, "at": at, "w": w, "stage": stage, "clip": base, "base": base, "top": t,
		"h": kinds.size() - sink - (2 if is_foil else 0), "sink": sink, "cx": look, "fy": at["eye1"],
		"lift": lift, "tip": tip, "tip2": tip2, "bent": bent, "two_wicks": two_wicks}


static var _faces := {}


## A face sprite (hero/face_<name>) with its dark pixels in `ink` (cached per ink).
static func face_tex(fname: String, ink: Color) -> Texture2D:
	var t := Art.tex("hero/face_" + fname)
	if ink == OUTLINE or t == null:
		return t
	var key := fname + ink.to_html()
	if _faces.has(key):
		return _faces[key]
	var img := t.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a > 0.5 and px.is_equal_approx(OUTLINE):
				img.set_pixel(x, y, ink)
	var tex := ImageTexture.create_from_image(img)
	_faces[key] = tex
	return tex


## The fill span (lo, hi) of row y, or (0, -1) if there is none.
static func span_at(g: Dictionary, y: int) -> Vector2i:
	for r in g["rows"]:
		if int(r[0]) == y:
			return Vector2i(int(r[2]), int(r[3]))
	return Vector2i(0, -1)


static func _px(ci: CanvasItem, o: Vector2, x: int, y: int, w: int, col: Color) -> void:
	if w > 0:
		ci.draw_rect(Rect2(o.x + x, o.y + y, w, 1), col)


## The outline row next to a span: the part of [lo, hi] that the neighbouring row does not cover.
static func _gap(ci: CanvasItem, o: Vector2, lo: int, hi: int, nlo: int, nhi: int, y: int, col: Color) -> void:
	_px(ci, o, lo, y, mini(hi, nlo - 1) - lo + 1, col)
	var a := maxi(lo, nhi + 1)
	_px(ci, o, a, y, hi - a + 1, col)


static func _grid(ci: CanvasItem, o: Vector2, x0: int, y0: int, rows: Array, cmap: Dictionary, clip := 99) -> void:
	for j in rows.size():
		if y0 + j > clip:
			return
		var r: String = rows[j]
		for i in r.length():
			var ch := r[i]
			if cmap.has(ch):
				ci.draw_rect(Rect2(o.x + x0 + i, o.y + y0 + j, 1, 1), cmap[ch])


## Outline, wax, shade, the rim and the pool round the wick, the wavy melted edge under the lip,
## the party stripes, the tea light's foil cup and a wax tear stuck on each side.
static func paint_body(ci: CanvasItem, o: Vector2, g: Dictionary, c: Dictionary, has_stripes := false,
		tears := [0, 0]) -> void:
	var rows: Array = g["rows"]
	var clip: int = g["clip"]
	var ol: Color = c["ol"]
	var w: int = g["w"]
	var at: Dictionary = g["at"]
	var stage: String = g["stage"]
	var n := rows.size()
	# outline: 4-neighbour, none under the bottom row (that is inside the dish)
	for i in n:
		var r: Array = rows[i]
		var y: int = r[0]
		if y > clip:
			break
		var lo: int = r[2]
		var hi: int = r[3]
		_px(ci, o, lo - 1, y, 1, ol)
		_px(ci, o, hi + 1, y, 1, ol)
		if i == 0:
			_px(ci, o, lo, y - 1, hi - lo + 1, ol)
		else:
			_gap(ci, o, lo, hi, rows[i - 1][2], rows[i - 1][3], y - 1, ol)
		if i < n - 1 and y + 1 <= clip:
			_gap(ci, o, lo, hi, rows[i + 1][2], rows[i + 1][3], y + 1, ol)
	# fill: wax, the right edge in shade (two columns from the lip down, light from the top-left)
	var lip: int = at["lip"]
	for r in rows:
		var y: int = r[0]
		if y > clip:
			break
		var k: String = r[1]
		var lo: int = r[2]
		var hi: int = r[3]
		if k == "foil":
			var top_foil: bool = y == int(at["foil"])
			_px(ci, o, lo, y, hi - lo + 1, c["foil"])
			_px(ci, o, hi - 1, y, 2, c["foil_sh"])
			if top_foil:
				var x := lo + 1
				while x < hi - 1:
					_px(ci, o, x, y, 1, c["foil_sh"])   # the crimped rim of the cup
					x += 2
			else:
				_px(ci, o, lo + 1, y, 1, c["hi"])
			continue
		var two := y >= lip and hi >= w
		_px(ci, o, lo, y, hi - lo + 1, c["wax"])
		_px(ci, o, hi - 1 if two else hi, y, 2 if two else 1, c["sh"])
		if k == "rim":
			_px(ci, o, lo, y, hi - lo, c["hi"])
		elif k == "pool":
			_px(ci, o, lo + 2, y, hi - lo - 3, c["sh"])
	# the wavy melted edge under the lip
	if stage == "full":
		for x in range(-w, w + 1):
			var yy: int = at["edge1"] + int(EDGE_WAVE[posmod(x + 6, 13)])
			if yy <= clip:
				_px(ci, o, x, yy, 1, c["sh"])
	elif stage == "mid" and int(at["edge1"]) <= clip:
		for x in range(-w, w + 1):
			if int(EDGE_WAVE[posmod(x + 6, 13)]) == 0:
				_px(ci, o, x, at["edge1"], 1, c["sh"])
	# party candle: pink stripes spiral round the wax (on the sides of the face and the belly)
	if has_stripes:
		var fy: int = g["fy"]
		var cx: int = g["cx"]
		for r in rows:
			var y: int = r[0]
			if y > clip:
				break
			if y < fy - 1 or r[1] == "foil":
				continue
			var lo: int = r[2]
			var hi: int = r[3]
			for x in range(lo, hi + 1):
				if posmod(x - y, 4) != 0:
					continue
				if y >= fy - 1 and y <= fy + 3 and x >= cx - 6 and x <= cx + 6:
					continue
				_px(ci, o, x, y, 1, c["deep"] if (y >= lip and x >= hi - 1) else c["sh"])
	# tears: stuck on each side, the left one in the light; in the slump they run into the dish
	var tc := {"o": ol, "W": c["hi"], "s": c["sh"]}
	if stage == "low":
		var yb: int = at["bottom"]
		for y in range(lip + 1, mini(yb, clip) + 1):
			_grid(ci, o, -w - 2, y, ["oWo"], tc)
			_grid(ci, o, w, y, ["oso"], tc)
		_px(ci, o, -w - 1, lip, 1, c["hi"])
		_px(ci, o, w + 1, lip, 1, c["sh"])
	else:
		var full := stage == "full"
		_grid(ci, o, -w - 2, lip + 1, _tear(3 + int(tears[0]) if full else int(tears[0]), 1 if full else 2, "W"), tc, clip)
		_px(ci, o, -w - 1, lip, 1, c["hi"])
		_grid(ci, o, w, lip + 1, _tear(int(tears[1]), 2, "s"), tc, clip)
		_px(ci, o, w + 1, lip, 1, c["sh"])


## A tear: `wn` rows of wax, `sn` rows of shade, then its round outline tip.
static func _tear(wn: int, sn: int, ch: String) -> Array:
	var out: Array = []
	for i in wn:
		out.append("o%so" % ch)
	for i in sn:
		out.append("oso")
	out.append(".o.")
	return out


## Rosy cheeks under the eyes (each candle has its own blush).
static func paint_cheeks(ci: CanvasItem, o: Vector2, g: Dictionary, col: Color) -> void:
	var y: int = int(g["fy"]) + 3
	if y > int(g["clip"]):
		return
	var sp := span_at(g, y)
	var cx: int = g["cx"]
	for x in [cx - 6, cx - 5, cx + 5, cx + 6]:
		if x >= sp.x and x <= sp.y:
			_px(ci, o, x, y, 1, col)


## The wick stands in the pool (crooked; at low wax it flops over), a second one for two flames.
static func paint_wick(ci: CanvasItem, o: Vector2, g: Dictionary, col: Color) -> void:
	var yp: int = g["at"]["pool"]
	var bent: bool = g["bent"]
	for x in ([0, -4] if g.get("two_wicks", false) else [0]):
		_px(ci, o, x, yp - 1, 1, col)
		if not bent:
			_px(ci, o, x, yp - 2, 1, col)
		var tip: Vector2i = g["tip"] if x == 0 else g["tip2"]
		_px(ci, o, tip.x, tip.y, 1, col)


## Stub arms at the cheek row; their inner outline sits on the body's outline.
static func paint_arms(ci: CanvasItem, o: Vector2, g: Dictionary, c: Dictionary, arms: Array) -> void:
	var at: Dictionary = g["at"]
	var ay: int = int(at["cheek"]) - 1
	var hw: int = span_at(g, at["eye3"]).y
	var w: int = g["w"]
	var cm := {"o": c["ol"], "W": c["wax"], "s": c["sh"]}
	for side in [-1, 1]:
		var pose: Variant = arms[0] if side < 0 else arms[1]
		if pose == null:
			continue
		if pose == "high":
			var yy: int = int(at["lip"]) - 4
			if side < 0:
				_grid(ci, o, -w - 4, yy, ARM_UP_L, cm)
			else:
				_grid(ci, o, w + 1, yy, ARM_UP_R, cm)
			continue
		var d: Vector2i = ARM_POSE.get(pose, Vector2i.ZERO)
		if side < 0:
			_grid(ci, o, -hw - 4 - d.x, ay + d.y, ARM_L, cm)
		else:
			_grid(ci, o, hw + 1 + d.x, ay + d.y, ARM_R, cm)


## Wax collected in the dish's bowl (row -4, `span` px each side of the centre) and `runs` = how far
## two runs spill over its front (left, right). `o` = the dish's offset.
static func paint_dish_wax(ci: CanvasItem, o: Vector2, span: int, runs: Vector2i, c: Dictionary) -> void:
	if span > 0:
		_px(ci, o, -span, -4, 2 * span - 1, c["wax"])
		_px(ci, o, span - 1, -4, 2, c["sh"])
	for side in 2:
		var x0 := -5 if side == 0 else 3
		var n := runs.x if side == 0 else runs.y
		if n <= 0:
			continue
		for k in n:
			_px(ci, o, x0, -3 + k, 1, c["wax"])
			_px(ci, o, x0 + 1, -3 + k, 1, c["sh"])
		_px(ci, o, x0, -3 + n, 2, c["ol"])
		if n > 1:
			_px(ci, o, x0 - 1, -3 + n - 1, 1, c["ol"])
			_px(ci, o, x0 + 2, -3 + n - 1, 1, c["ol"])


## A whole candle from the Candle Box in one CanvasItem (Journal, menus): the dish, the body at full
## wax, the open face, the arms, the wick and an idle flame. `feet` = the point under the dish.
## opts: "sil" (Color: a locked silhouette, no face or flame), "tex" (Callable: texture filter),
## "frame" (flame frame), "wax" (override), "face" (face name).
static func paint_preview(ci: CanvasItem, feet: Vector2, cid: String, opts := {}) -> void:
	var d: Dictionary = Candles.def_of(cid)
	var cs: Array = d["colours"]
	var sil: Variant = opts.get("sil", null)
	var tf: Callable = opts.get("tex", func(t): return t)
	var c := {"ol": OUTLINE, "hi": Color(cs[0]), "wax": Color(cs[1]), "sh": Color(cs[2]), "deep": Color(cs[3]),
		"cheek": Color(d.get("cheek", "#f78697")), "foil": Color("#b6cbcf"), "foil_sh": Color("#7b8994")}
	if sil != null:
		for k in c:
			if k != "ol":
				c[k] = sil
	var two := int(d.get("shots", 1)) > 1
	var g := Player.shape(Player.rows_for(float(opts.get("wax", d["wax"]))), 0, int(d["body_w"]) / 2, 0, 0,
		d.get("straight", false), d.get("foil", false), two)
	var o := feet.floor()
	var dish: String = d.get("holder", "hero/holder")
	var back: Texture2D = tf.call(Art.tex(dish + "_back"))
	if back:
		ci.draw_texture(back, o + Vector2(-9, -7))
	Player.paint_body(ci, o, g, c, d.get("stripes", false) and sil == null)
	if sil == null:
		Player.paint_cheeks(ci, o, g, c["cheek"])
		var face: Texture2D = Player.face_tex(str(opts.get("face", "open")), Color(d.get("ink", "#21141b")))
		ci.draw_texture(face, o + Vector2(int(g["cx"]) - 5, int(g["fy"])))
	var front: Texture2D = tf.call(Art.tex(dish))
	if front:
		ci.draw_texture(front, o + Vector2(-9, -5))
	Player.paint_arms(ci, o, g, c, ["rest", "rest"])
	Player.paint_wick(ci, o, g, OUTLINE)
	if sil != null or opts.get("unlit", false):   # unlit: no flame (an empty save slot's sleeping candle)
		return
	var sf := Player.flame_frames(false)
	var fr := int(opts.get("frame", 0))
	for k in (2 if two else 1):
		var fk := "idle" if k == 0 else "mid"
		var tex: Texture2D = sf.get_frame_texture(fk, (fr + k) % sf.get_frame_count(fk))
		var tip: Vector2i = g["tip"] if k == 0 else g["tip2"]
		ci.draw_texture(tex, o + Vector2(tip) + FLAME_OFS)
