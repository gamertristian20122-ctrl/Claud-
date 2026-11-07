class_name Player
extends Node2D
## Tallow, the candle. Position = the point under the dish (feet). The wax body is drawn in code so
## it gets shorter as the wax (health + clock) burns down; the light radius shrinks with it.

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
	flame.play("default")
	light.color = Color(0.6, 0.8, 1.0) if b else Color(1.0, 0.74, 0.44)


func wax_frac() -> float:
	return clampf(wax / 120.0, 0.0, 1.35)


func body_height() -> int:
	return clampi(int(round(3.0 + 12.0 * wax_frac())), 3, 19)


func _physics_process(dt: float) -> void:
	if dead or frozen:
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


func hurt(amount: float, from_dir: Vector2) -> void:
	if dead or invuln > 0 or frozen:
		return
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
		world.fx_text(global_position + Vector2(0, -34), "GUTTERING!", UI.EMBER)
		if Game.tip("gutter", 1):
			world.hud.show_hint("Guttering: your flame clung on once this floor. Find wax!", 3.0)
		Audio.play("low_wax")
		world.on_player_hurt(amount)
		return
	wax -= amount
	invuln = 1.2
	_hurt_face = 0.6
	vel += from_dir.normalized() * 140.0
	Audio.play("player_hurt")
	Game.vibrate(60)
	world.on_player_hurt(amount)
	if wax <= 0:
		die()


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
	var h := body_height()
	var bob := -1 if sin(_bob) > 0.3 else 0
	var top := -5 - h + bob
	face.position = Vector2(-5, top + clampi(2 + h / 5, 2, 5))
	holder.position.y = 0
	flame.position = Vector2(0, top - 2)
	# flame leans against movement, recovers from recoil
	_lean = lerpf(_lean, clampf(-vel.x / speed, -1.0, 1.0), minf(1.0, dt * 10.0))
	(flame.material as ShaderMaterial).set_shader_parameter("lean", _lean)
	_recoil -= dt
	flame.offset = Vector2(-4, -12 + (1 if _recoil > 0 else 0))
	flame.visible = not dead
	# light: flicker + shrink with wax
	var t := Time.get_ticks_msec() / 1000.0
	var flick := 1.0 + 0.045 * sin(t * 13.0) + 0.03 * sin(t * 23.7 + 1.3) + randf_range(-0.015, 0.015)
	var wf := clampf(wax / 120.0, 0.0, 1.0)
	light.texture_scale = lerpf(0.95, 1.5, wf) * flick
	if world and world.get("omen") == "smoky_halls":
		light.texture_scale = maxf(0.95, light.texture_scale * 0.85)
	light.energy = (lerpf(0.95, 1.2, wf) * flick) if not dead else move_toward(light.energy, 0.0, dt * 1.5)
	light.position = flame.position + Vector2(0, -4)
	if flame2:
		flame2.position = flame.position + Vector2(3, 2)
		flame2.visible = flame.visible
	if "hearth" in rites:
		light.texture_scale *= 1.12
	glow.position = light.position
	glow.energy = 0.0 if dead else 0.55
	if h != _shown_h or bob != 0:
		_shown_h = h
	queue_redraw()


func _draw() -> void:
	# ground shadow (pixel ellipse)
	var sh := Color(0, 0, 0, 0.35)
	draw_rect(Rect2(-6, -1, 12, 2), sh)
	draw_rect(Rect2(-8, 0, 16, 1), sh)
	var h := body_height()
	var bob := -1 if sin(_bob) > 0.3 else 0
	var base := -5 + bob   # body bottom sits inside the dish
	var top := base - h
	# body: body_w px wide, centred on x = 0 (Tallow is 10 px: x -5..4)
	var L := -body_w / 2
	var R := L + body_w
	draw_rect(Rect2(L, top, body_w, h), OUTLINE)
	draw_rect(Rect2(L + 1, top + 1, body_w - 2, h - 1), c_wax)
	draw_rect(Rect2(L + 1, top + 1, 1, h - 1), c_hi)
	if body_w >= 10:
		draw_rect(Rect2(R - 4, top + 1, 2, h - 1), c_sh)
	else:
		draw_rect(Rect2(R - 3, top + 1, 1, h - 1), c_sh)
	draw_rect(Rect2(R - 2, top + 1, 1, h - 1), c_deep)
	if stripes:
		var row := top + 3
		while row < base - 1:
			draw_rect(Rect2(L + 1, row, body_w - 2, 1), c_sh)
			draw_rect(Rect2(R - 2, row, 1, 1), c_deep)
			row += 3
	# melted rim + pool
	draw_rect(Rect2(L + 1, top + 1, body_w - 2, 1), c_hi)
	draw_rect(Rect2(L + 2, top + 1, body_w - 4, 1), POOL)
	if body_w >= 8:
		draw_rect(Rect2(L + 3, top + 2, body_w - 6, 1), c_sh)
	# drips over the rim (fixed pattern so they read as wax, not noise)
	if h >= 6:
		draw_rect(Rect2(L, top + 1, 1, 3), OUTLINE)
		draw_rect(Rect2(L - 1, top + 2, 1, 3), OUTLINE)
		draw_rect(Rect2(L, top + 2, 1, 2), c_hi)
		draw_rect(Rect2(L - 1, top + 5, 2, 1), OUTLINE)
		draw_rect(Rect2(R - 1, top + 1, 1, 4), OUTLINE)
		draw_rect(Rect2(R, top + 3, 1, 3), OUTLINE)
		draw_rect(Rect2(R - 1, top + 3, 1, 2), c_sh)
	if h >= 11 and body_w >= 10:
		draw_rect(Rect2(0, top + 2, 1, h / 2), c_sh)
		draw_rect(Rect2(-1, top + 2 + h / 2, 3, 1), c_sh)
	if foil:
		# a tea light's foil cup
		draw_rect(Rect2(L - 1, base - 4, body_w + 2, 5), OUTLINE)
		draw_rect(Rect2(L, base - 3, body_w, 3), Color("#b6cbcf"))
		draw_rect(Rect2(L, base - 1, body_w, 1), Color("#7b8994"))
		draw_rect(Rect2(L + 1, base - 3, 1, 2), Color("#fdf7ed"))
	# wick
	draw_rect(Rect2(0, top - 2, 1, 3), OUTLINE)
	if "wick" in rites:
		draw_rect(Rect2(3, top, 1, 3), OUTLINE)
	if "clock" in rites:
		# a little brass gear on the dish
		draw_rect(Rect2(5, -5, 3, 3), Color("#facb3e"))
		draw_rect(Rect2(6, -6, 1, 5), Color("#c56025"))
		draw_rect(Rect2(4, -4, 5, 1), Color("#c56025"))
		draw_rect(Rect2(6, -4, 1, 1), Color("#21141b"))
