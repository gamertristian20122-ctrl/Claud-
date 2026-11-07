class_name Player
extends Node2D
## Tallow, the candle. Position = the point under the dish (feet). The wax body is drawn in code so
## it gets shorter as the wax (health + clock) burns down; the light radius shrinks with it.
## Juice (all visual): breathing, squash & stretch, recoil, hurt flash, drips that run down the sides,
## a guttering flame at low wax, holding a new relic aloft, and a melt-down when the flame goes out.

const OUTLINE := Color("#21141b")
const WAX_HI := Color("#fdf7ed")
const WAX := Color("#f3e6cf")
const WAX_SH := Color("#d3bfa9")
const WAX_DEEP := Color("#aa8d7a")
const POOL := Color("#e2b694")
const RADIUS := 5.0
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
var charred := 0.0        # max wax sold at the Smoke Altar (shown burnt on the bar)
var gutter_used := false  # once per floor a killing hit leaves you at 1 minute
var chill_t := 0.0        # touched by a chilled foe: melt faster for a while
var keepsake := ""        # held charge item
var charge := 0
var rites: Array[String] = []
# ---- which candle this is (Candle Box)
var candle_id := "tallow"
var body_w := 10
var c_hi := WAX_HI
var c_wax := WAX
var c_sh := WAX_SH
var c_deep := WAX_DEEP
var stripes := false
var foil := false


func apply_candle(id: String) -> void:
	candle_id = id
	var d: Dictionary = Candles.def_of(id)
	wax = d["wax"]
	wax_max = d["wax"]
	drain_mult *= d["drain"]
	speed *= d["speed"]
	damage *= d["damage"]
	fire_delay *= d["fire_delay"]
	shots = d["shots"]
	body_w = d["body_w"]
	var cs: Array = d["colours"]
	c_hi = Color(cs[0])
	c_wax = Color(cs[1])
	c_sh = Color(cs[2])
	c_deep = Color(cs[3])
	stripes = d.get("stripes", false)
	foil = d.get("foil", false)
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
## Title screen: the wick starts unlit, then the light blooms (light_k 0 -> ~1.3 -> 1).
var unlit := false
var light_k := 1.0
# the body's shape this frame, in whole pixels (set in _process, used by _draw)
var _h := 14
var _bw := 10
var _top := -19
var _base := -5

var flame: AnimatedSprite2D
var holder: Sprite2D
var face: Sprite2D
var light: PointLight2D
var glow: PointLight2D
var _shown_h := 14


func _ready() -> void:
	holder = Sprite2D.new()
	holder.texture = Art.tex("hero/holder")
	holder.centered = false
	holder.offset = Vector2(-9, -7)
	add_child(holder)
	face = Sprite2D.new()
	face.centered = false
	face.z_index = 1
	add_child(face)
	flame = AnimatedSprite2D.new()
	flame.centered = false
	flame.offset = Vector2(-4, -12)
	flame.z_index = 2
	var fm := ShaderMaterial.new()
	fm.shader = LEAN_SHADER
	flame.material = fm
	add_child(flame)
	_set_flame_frames()
	flame.play("default")
	light = PointLight2D.new()
	light.texture = Art.light_tex
	light.color = Color(1.0, 0.74, 0.44)
	light.energy = 1.15
	light.shadow_enabled = true
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	light.shadow_color = Color(0, 0, 0, 0.45)
	light.texture_scale = 1.4
	add_child(light)
	# a tight warm glow so the candle itself always reads in the dark
	glow = PointLight2D.new()
	glow.texture = Art.light_tex
	glow.color = Color(1.0, 0.85, 0.6)
	glow.energy = 0.55
	glow.texture_scale = 0.22
	add_child(glow)
	_pool = Node2D.new()
	_pool.z_index = 1
	_pool.draw.connect(_draw_pool)
	add_child(_pool)
	add_child(Costumes.new())


## Call a world effect if this world has it (the title screen's stand-in world does not).
func _fx(method: String, args: Array) -> void:
	if world and world.has_method(method):
		world.callv(method, args)


func _set_flame_frames() -> void:
	flame.sprite_frames = Art.anim("hero/flame_blue" if blue else "hero/flame", 10.0)


var flame2: AnimatedSprite2D


func refresh_rite_look() -> void:
	if "wick" in rites and flame2 == null:
		flame2 = AnimatedSprite2D.new()
		flame2.centered = false
		flame2.offset = Vector2(-4, -12)
		flame2.z_index = 2
		flame2.material = flame.material
		flame2.sprite_frames = flame.sprite_frames
		flame2.play("default")
		flame2.frame = 3
		add_child(flame2)
	if "hearth" in rites and not blue:
		light.color = Color(1.0, 0.55, 0.25)
	queue_redraw()


func set_blue(b: bool) -> void:
	blue = b
	_set_flame_frames()
	if flame2:
		flame2.sprite_frames = flame.sprite_frames
		flame2.play("default")
	flame.play("default")
	light.color = Color(0.6, 0.8, 1.0) if b else Color(1.0, 0.74, 0.44)


func wax_frac() -> float:
	return clampf(wax / 120.0, 0.0, 1.35)


func body_height() -> int:
	return clampi(int(round(3.0 + 12.0 * wax_frac())), 3, 19)


func _physics_process(dt: float) -> void:
	if dead or frozen or _hold_t > 0.0 or Juice.holding(world):
		vel = vel.move_toward(Vector2.ZERO, 600 * dt)
		return
	var target := move_input.limit_length(1.0) * speed
	var accel := 900.0 if target.length() > 1 else 1100.0
	vel = vel.move_toward(target, accel * dt)
	_move(vel * dt)
	if vel.length() > 8:
		_bob += dt * 14.0
		if aim_input.length() < 0.2:
			facing = vel.normalized()
		if fmod(_bob, PI) < 14.0 * dt:
			Audio.play("step", -2.0, 0.15)
	else:
		_bob = 0.0
	# shooting
	fire_cd -= dt
	if aim_input.length() > 0.3:
		facing = aim_input.normalized()
		if fire_cd <= 0.0:
			var rate := fire_delay
			if witching and wax < 30.0:
				rate *= 0.7
			fire_cd = rate
			_fire(aim_input.normalized())
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
	var dmg := damage
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
	Audio.play("player_hurt")
	Game.vibrate(60)
	world.on_player_hurt(amount)
	if wax <= 0:
		die()


func _hurt_fx() -> void:
	_white = 0.1
	_sq = -1.0
	_sq_v = 0.0
	_hurt_face = maxf(_hurt_face, 0.6)


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
	# face
	_blink -= dt
	_hurt_face -= dt
	_happy_face -= dt
	var f := "open"
	if dead:
		f = "hurt"
	elif _hurt_face > 0:
		f = "hurt"
	elif _happy_face > 0:
		f = "happy"
	elif _blink < 0.12:
		f = "blink"
	if _blink < 0:
		_blink = randf_range(2.0, 4.5)
	if f != face_state or face.texture == null:
		face_state = f
		face.texture = Art.tex("hero/face_" + f)
	_juice_step(dt)
	var h := _h
	var top := _top
	var o := _recoil_off if _recoil > 0.0 else Vector2.ZERO
	face.position = Vector2(-5, top + clampi(2 + h / 5, 2, 5)) + o
	if dead and h < 6:
		face.visible = false
	holder.position = o
	flame.position = Vector2(0, top - 2) + o
	# flame leans against movement, recovers from recoil
	_lean = lerpf(_lean, clampf(-vel.x / speed, -1.0, 1.0), minf(1.0, dt * 10.0))
	(flame.material as ShaderMaterial).set_shader_parameter("lean", _lean)
	_recoil -= dt
	var dip := (1 if _recoil > 0 else 0) + (2 if _sput > 0.0 else 0)
	flame.offset = Vector2(-4, -12 + dip)
	flame.self_modulate = Color(1.0, 0.62, 0.45) if _sput > 0.0 else Color.WHITE
	flame.visible = (not dead or _melt < 0.25) and not unlit
	# light: flicker + shrink with wax (and die with the flame)
	var t := Time.get_ticks_msec() / 1000.0
	var flick := 1.0 + 0.045 * sin(t * 13.0) + 0.03 * sin(t * 23.7 + 1.3) + randf_range(-0.015, 0.015)
	var wf := clampf(wax / 120.0, 0.0, 1.0)
	light.texture_scale = lerpf(0.95, 1.5, wf) * flick
	if world and world.get("omen") == "smoky_halls":
		light.texture_scale = maxf(0.95, light.texture_scale * 0.85)
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
		flame2.position = flame.position + Vector2(3, 2)
		flame2.visible = flame.visible
	if "hearth" in rites:
		light.texture_scale *= 1.12
	glow.position = light.position
	glow.energy = 0.55 * keep if dead else (0.0 if unlit else 0.55 * minf(1.0, light_k))
	_shown_h = h
	queue_redraw()
	_pool.queue_redraw()


## Squash & stretch, breathing, drips, guttering, the held relic and the melt-down.
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
	# the body's shape in whole pixels: stretch = taller + narrower, squash = shorter + wider
	var dh := int(roundf(_sq * 3.0))
	var side := -int(roundf(_sq * 1.5))
	var still := not moving and vel.length() < 8.0
	var breathe := 1 if (still and not dead and sin(_breath * 2.6) > 0.55) else 0
	var bob := -1 if sin(_bob) > 0.3 else 0
	var h := body_height() + dh + breathe
	if dead:
		var k := clampf(_melt / 0.85, 0.0, 1.0)
		var from := _melt_from if _melt_from > 0 else 4
		h = int(roundf(float(from) * (1.0 - k * k * (3.0 - 2.0 * k))))
	_h = clampi(h, 0, 22)
	_bw = maxi(6, body_w + 2 * side) if not dead else body_w
	_base = -5 + bob
	_top = _base - _h
	# wax drips run down the sides while walking, then drop to the floor
	if moving and vel.length() > 20.0 and _h >= 8:
		_drip_spawn -= dt
		if _drip_spawn <= 0.0:
			_drip_spawn = randf_range(0.7, 1.5)
			if _drips.size() < 2:
				_drips.append([-1 if randf() < 0.5 else 1, 0.0, randf_range(0.8, 1.25)])
	var i := _drips.size() - 1
	while i >= 0:
		var d: Array = _drips[i]
		d[1] += dt * 0.9 * float(d[2]) * (1.0 if moving else 0.4)
		if d[1] >= 1.0 or dead:
			_drips.remove_at(i)
			if not dead:
				var x := (-_bw / 2 - 1) if d[0] < 0 else (_bw / 2)
				_fx("fx_wax_drop", [global_position + Vector2(x, _base - 2), vel * 0.3])
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
			_fx("fx_wisp", [flame.global_position + Vector2(0, -10)])
	# holding a relic aloft (a gold glint winks on it)
	if _hold_t > 0.0:
		_hold_t -= dt
		var up := minf(1.0, (0.9 - _hold_t) / 0.15)
		_held.position = Vector2(0, roundf(_top - 22 - 3.0 * up))
		_glint.position = _held.position + Vector2(6, -6)
		_glint.visible = fmod(_hold_t, 0.3) > 0.1
		if _hold_t <= 0.0:
			_held.visible = false
			_glint.visible = false
			_fx("fx_glint", [_held.global_position])
	# death: the body sinks into a widening puddle, the flame shrinks and pops into smoke
	if dead:
		if _melt == 0.0:
			_drips.clear()
			if _melt_from < 0:
				_melt_from = 4
		_melt = minf(1.0, _melt + dt / maxf(Engine.time_scale, 0.01) / 1.2)
		if _melt >= 0.8 and not _popped:
			_popped = true
			_fx("fx_smoke", [global_position + Vector2(0, _base - _h - 8)])
			_fx("fx_wisp", [global_position + Vector2(0, _base - _h - 4)])
		if _melt >= 0.95 and not _stained:
			_stained = true
			_fx("fx_stain", [global_position + Vector2(0, -1), "wax", true])


func _draw() -> void:
	# ground shadow (pixel ellipse)
	var sh := Color(0, 0, 0, 0.35)
	draw_rect(Rect2(-6, -1, 12, 2), sh)
	draw_rect(Rect2(-8, 0, 16, 1), sh)
	var o := _recoil_off if _recoil > 0.0 else Vector2.ZERO
	var h := _h
	var base := _base
	var top := _top
	var bw := _bw
	var white := _white > 0.0
	var c_w := Color.WHITE if white else c_wax
	var c_h := Color.WHITE if white else c_hi
	var c_s := Color.WHITE if white else c_sh
	var c_d := Color.WHITE if white else c_deep
	var c_p := Color.WHITE if white else POOL
	var ha := holder.self_modulate.a
	holder.self_modulate = Color(3, 3, 3, ha) if white else Color(1, 1, 1, ha)
	if h <= 0:
		_draw_wick(o, top, true)
		return
	# body: bw px wide, centred on x = 0 (Tallow is 10 px: x -5..4)
	var L := -bw / 2
	var R := L + bw
	draw_rect(Rect2(Vector2(L, top) + o, Vector2(bw, h)), OUTLINE)
	draw_rect(Rect2(Vector2(L + 1, top + 1) + o, Vector2(bw - 2, h - 1)), c_w)
	draw_rect(Rect2(Vector2(L + 1, top + 1) + o, Vector2(1, h - 1)), c_h)
	if bw >= 10:
		draw_rect(Rect2(Vector2(R - 4, top + 1) + o, Vector2(2, h - 1)), c_s)
	else:
		draw_rect(Rect2(Vector2(R - 3, top + 1) + o, Vector2(1, h - 1)), c_s)
	draw_rect(Rect2(Vector2(R - 2, top + 1) + o, Vector2(1, h - 1)), c_d)
	if stripes:
		var row := top + 3
		while row < base - 1:
			draw_rect(Rect2(Vector2(L + 1, row) + o, Vector2(bw - 2, 1)), c_s)
			draw_rect(Rect2(Vector2(R - 2, row) + o, Vector2(1, 1)), c_d)
			row += 3
	# melted rim + pool
	draw_rect(Rect2(Vector2(L + 1, top + 1) + o, Vector2(bw - 2, 1)), c_h)
	draw_rect(Rect2(Vector2(L + 2, top + 1) + o, Vector2(bw - 4, 1)), c_p)
	if bw >= 8:
		draw_rect(Rect2(Vector2(L + 3, top + 2) + o, Vector2(bw - 6, 1)), c_s)
	# drips over the rim (fixed pattern so they read as wax, not noise)
	if h >= 6:
		draw_rect(Rect2(Vector2(L, top + 1) + o, Vector2(1, 3)), OUTLINE)
		draw_rect(Rect2(Vector2(L - 1, top + 2) + o, Vector2(1, 3)), OUTLINE)
		draw_rect(Rect2(Vector2(L, top + 2) + o, Vector2(1, 2)), c_h)
		draw_rect(Rect2(Vector2(L - 1, top + 5) + o, Vector2(2, 1)), OUTLINE)
		draw_rect(Rect2(Vector2(R - 1, top + 1) + o, Vector2(1, 4)), OUTLINE)
		draw_rect(Rect2(Vector2(R, top + 3) + o, Vector2(1, 3)), OUTLINE)
		draw_rect(Rect2(Vector2(R - 1, top + 3) + o, Vector2(1, 2)), c_s)
	if h >= 11 and bw >= 10:
		draw_rect(Rect2(Vector2(0, top + 2) + o, Vector2(1, h / 2)), c_s)
		draw_rect(Rect2(Vector2(-1, top + 2 + h / 2) + o, Vector2(3, 1)), c_s)
	# running drips (they slide down the sides while walking)
	for d in _drips:
		var k: float = d[1]
		var fr := 0 if k < 0.35 else (1 if k < 0.7 else 2)
		var x := (L - 1) if d[0] < 0 else (R - 2)
		var y := top + 2 + int(k * maxf(0.0, h - 8.0))
		draw_texture(Art.tex("hero/drip_f%d" % fr), Vector2(x, y) + o)
	if foil:
		# a tea light's foil cup
		draw_rect(Rect2(Vector2(L - 1, base - 4) + o, Vector2(bw + 2, 5)), OUTLINE)
		draw_rect(Rect2(Vector2(L, base - 3) + o, Vector2(bw, 3)), Color.WHITE if white else Color("#b6cbcf"))
		draw_rect(Rect2(Vector2(L, base - 1) + o, Vector2(bw, 1)), Color("#7b8994"))
		draw_rect(Rect2(Vector2(L + 1, base - 3) + o, Vector2(1, 2)), Color("#fdf7ed"))
	_draw_wick(o, top, false)
	if "clock" in rites:
		# a little brass gear on the dish
		draw_rect(Rect2(Vector2(5, -5) + o, Vector2(3, 3)), Color("#facb3e"))
		draw_rect(Rect2(Vector2(6, -6) + o, Vector2(1, 5)), Color("#c56025"))
		draw_rect(Rect2(Vector2(4, -4) + o, Vector2(5, 1)), Color("#c56025"))
		draw_rect(Rect2(Vector2(6, -4) + o, Vector2(1, 1)), Color("#21141b"))


func _draw_wick(o: Vector2, top: int, flat: bool) -> void:
	if flat:
		# melted away: only the wick is left, lying in the puddle
		draw_rect(Rect2(Vector2(-1, _base - 1) + o, Vector2(3, 1)), OUTLINE)
	else:
		draw_rect(Rect2(Vector2(0, top - 2) + o, Vector2(1, 3)), OUTLINE)
		if "wick" in rites:
			draw_rect(Rect2(Vector2(3, top) + o, Vector2(1, 3)), OUTLINE)
	if dead and _melt >= 0.25 and _melt < 0.8:
		# the flame is dying: a small code-drawn flame that shrinks, then pops
		var fy := (top - 2) if not flat else (_base - 1)
		if _melt < 0.55:
			draw_rect(Rect2(Vector2(-1, fy - 4) + o, Vector2(3, 3)), Color("#ee8e2e"))
			draw_rect(Rect2(Vector2(0, fy - 5) + o, Vector2(1, 1)), Color("#da4e38"))
			draw_rect(Rect2(Vector2(0, fy - 3) + o, Vector2(1, 2)), Color("#facb3e"))
		else:
			draw_rect(Rect2(Vector2(0, fy - 2) + o, Vector2(1, 2)), Color("#ee8e2e"))
			draw_rect(Rect2(Vector2(0, fy - 3) + o, Vector2(1, 1)), Color("#da4e38"))


## The melt: wax fills the brass dish, runs down its front and spreads into a puddle on the floor
## (drawn above the holder; the dish spans x -9..8, its bowl rows are y -6..-5).
func _draw_pool() -> void:
	if not dead or _melt <= 0.05:
		return
	var k := clampf((_melt - 0.05) / 0.8, 0.0, 1.0)
	var c := -1   # the dish centre
	# 1) the dish fills (never drawn across the body that is still standing in it)
	var dw := int(roundf(lerpf(float(body_w), 15.0, minf(1.0, k * 2.2))))
	var dl := c - dw / 2
	var bl := -_bw / 2
	var br := bl + _bw
	for x in range(dl - 1, dl + dw + 1):
		if _h > 0 and x >= bl and x < br:
			continue
		var edge := x == dl - 1 or x == dl + dw
		_pool.draw_rect(Rect2(x, -6, 1, 1), OUTLINE if edge else c_hi)
		_pool.draw_rect(Rect2(x, -5, 1, 1), OUTLINE if edge else c_wax)
	# 2) it spills over the front of the dish in two runs of different lengths ...
	if k > 0.3:
		var run := clampi(int((k - 0.3) / 0.25 * 4.0), 1, 4)
		for side in 2:
			var x := c - 4 if side == 0 else c + 3
			var n := run if side == 0 else maxi(1, run - 1)
			_pool.draw_rect(Rect2(x, -4, 2, n), c_wax)
			_pool.draw_rect(Rect2(x, -4, 1, n), c_hi)
			_pool.draw_rect(Rect2(x + 2, -4, 1, n), OUTLINE)
			_pool.draw_rect(Rect2(x, -4 + n, 2, 1), OUTLINE)
	# 3) ... and spreads into a puddle around the base
	if k > 0.55:
		var fw := int(roundf(lerpf(12.0, 28.0, (k - 0.55) / 0.45)))
		var fl := c - fw / 2
		_pool.draw_rect(Rect2(fl, -2, fw, 3), OUTLINE)
		_pool.draw_rect(Rect2(fl - 1, -1, fw + 2, 2), OUTLINE)
		_pool.draw_rect(Rect2(fl + 1, -1, fw - 2, 1), c_hi)
		_pool.draw_rect(Rect2(fl, 0, fw, 1), c_sh)
		_pool.draw_rect(Rect2(fl + 2, -1, maxi(1, fw / 4), 1), POOL)
		_pool.draw_rect(Rect2(fl + fw - 3, 0, 2, 1), c_deep)
