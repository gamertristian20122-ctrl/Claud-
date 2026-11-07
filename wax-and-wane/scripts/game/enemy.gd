class_name Enemy
extends Node2D
## All creatures of the house (0x72 sprites) driven by a small data table + behaviour functions.
## Bosses are the same class with `boss` set and their own pattern functions.

const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, tint.rgb, flash), c.a);
}
"""

const DEFS := {
	"tiny_zombie": {"hp": 4.0, "speed": 26.0, "ai": "chase", "r": 5.0},
	"goblin": {"hp": 5.0, "speed": 40.0, "ai": "chase", "jitter": true, "r": 5.0},
	"tiny_slug": {"hp": 3.0, "speed": 20.0, "ai": "chase", "r": 4.0},
	"slug": {"hp": 8.0, "speed": 17.0, "ai": "chase", "r": 6.0},
	"muddy": {"hp": 9.0, "speed": 0.0, "ai": "hop", "r": 6.0},
	"swampy": {"hp": 8.0, "speed": 0.0, "ai": "hop", "shoot4": true, "r": 6.0},
	"imp": {"hp": 4.0, "speed": 46.0, "ai": "fly", "r": 5.0, "fly": true},
	"skelet": {"hp": 6.0, "speed": 30.0, "ai": "shooter", "r": 5.0, "cd": 1.9},
	"pumpkin_dude": {"hp": 10.0, "speed": 22.0, "ai": "charger", "r": 6.0, "charge": 150.0},
	"chort": {"hp": 9.0, "speed": 32.0, "ai": "charger", "r": 6.0, "charge": 175.0},
	"wogol": {"hp": 10.0, "speed": 30.0, "ai": "jumper", "r": 6.0},
	"orc_shaman": {"hp": 12.0, "speed": 18.0, "ai": "caster", "r": 6.0, "cd": 2.6},
	"masked_orc": {"hp": 20.0, "speed": 24.0, "ai": "chase", "r": 7.0, "heavy": true},
	"necromancer": {"hp": 14.0, "speed": 20.0, "ai": "summoner", "r": 6.0},
	"doc": {"hp": 12.0, "speed": 22.0, "ai": "lobber", "r": 6.0},
	"ice_zombie": {"hp": 11.0, "speed": 30.0, "ai": "chase", "r": 5.0, "death_burst": true},
	"mimic": {"hp": 16.0, "speed": 48.0, "ai": "chase", "r": 6.0, "sprite": "chest_mimic"},
	# bosses
	"big_zombie": {"hp": 70.0, "speed": 20.0, "ai": "boss_rot", "r": 11.0, "boss": true, "heavy": true, "name": "OLD ROT"},
	"ogre": {"hp": 100.0, "speed": 26.0, "ai": "boss_gaoler", "r": 11.0, "boss": true, "heavy": true, "name": "THE GAOLER"},
	"necro_boss": {"hp": 120.0, "speed": 24.0, "ai": "boss_vicar", "r": 10.0, "boss": true, "heavy": true, "name": "THE HOLLOW VICAR", "sprite": "necromancer", "scale": 2.0},
	"big_demon": {"hp": 190.0, "speed": 30.0, "ai": "boss_fiend", "r": 12.0, "boss": true, "heavy": true, "name": "THE HOUR FIEND"},
}

var world: Node
var kind := ""
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var speed := 20.0
var radius := 5.0
var half_h := 6.0
var alive := true
var active := false
var boss := false
var flying := false
var heavy := false
var spr: AnimatedSprite2D
var mat: ShaderMaterial
var kvel := Vector2.ZERO
var state := "idle"
var t := 0.0
var cd := 1.0
var dir := Vector2.ZERO
var phase := 1
var minions: Array = []
var burn_t := 0.0
var _burn_tick := 0.0
var _flash := 0.0
var _wob := 0.0
var _jump_h := 0.0
var _spin := 0.0
var _pattern := 0
var target_pos := Vector2.ZERO
var _hand_base := 0.0
var shadow: Sprite2D
static var _shadow_tex: Texture2D
static var _flash_shader: Shader


func setup(w: Node, k: String, pos: Vector2, floor_num: int) -> void:
	world = w
	kind = k
	def = DEFS[k]
	position = pos
	var f := float(floor_num - 1)
	max_hp = float(def["hp"]) * (1.0 + 0.25 * f) if not def.get("boss", false) else float(def["hp"])
	hp = max_hp
	speed = float(def["speed"]) * (1.0 + 0.05 * f)
	radius = float(def["r"])
	boss = def.get("boss", false)
	flying = def.get("fly", false)
	heavy = def.get("heavy", false)
	cd = float(def.get("cd", 1.5)) * randf_range(0.6, 1.2)
	_wob = randf() * TAU


func _ready() -> void:
	spr = AnimatedSprite2D.new()
	var sname: String = def.get("sprite", kind)
	if sname == "chest_mimic":
		spr.sprite_frames = Art.anim("0x72/chest_mimic_open_anim", 8.0)
	else:
		spr.sprite_frames = Art.creature(sname)
	var anim := "default" if sname == "chest_mimic" else "idle"
	spr.play(anim)
	spr.frame = randi() % 4
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(anim, 0)
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	var sc: float = def.get("scale", 1.0)
	spr.scale = Vector2(sc, sc)
	half_h = tex.get_height() * sc * 0.4
	if _shadow_tex == null:
		var img := Image.create(10, 3, false, Image.FORMAT_RGBA8)
		var c := Color(0.13, 0.08, 0.1, 0.45)
		for x in range(2, 8):
			img.set_pixel(x, 0, c)
			img.set_pixel(x, 2, c)
		for x in 10:
			img.set_pixel(x, 1, c)
		_shadow_tex = ImageTexture.create_from_image(img)
	shadow = Sprite2D.new()
	shadow.texture = _shadow_tex
	shadow.position = Vector2(0, -1)
	add_child(shadow)
	mat = ShaderMaterial.new()
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = FLASH_SHADER
	mat.shader = _flash_shader
	spr.material = mat
	add_child(spr)
	# spawn-in
	active = false
	spr.modulate.a = 0.0
	scale = Vector2(0.4, 1.6)
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25 if not boss else 0.6)
	tw.tween_callback(func(): active = true)


func _physics_process(dt: float) -> void:
	if not alive:
		return
	_flash = maxf(0.0, _flash - dt * 6.0)
	mat.set_shader_parameter("flash", _flash)
	if burn_t > 0:
		burn_t -= dt
		_burn_tick -= dt
		spr.self_modulate = Color(1.0, 0.7, 0.5)
		if _burn_tick <= 0:
			_burn_tick = 0.5
			_damage(0.5 + world.player.damage * 0.25, false)
			if not alive:
				return
	else:
		spr.self_modulate = Color.WHITE
	if not active:
		return
	var p: Player = world.player
	var slow: float = world.time_scale_enemies()
	var ddt := dt * slow
	t -= ddt
	cd -= ddt
	# knockback
	if kvel.length() > 1:
		_move(kvel * dt)
		kvel = kvel.move_toward(Vector2.ZERO, 500 * dt)
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	var ai: String = def["ai"]
	call("_ai_" + ai, ddt, to_p, dist)
	# face the player
	if absf(to_p.x) > 2 and state != "charge":
		spr.flip_h = to_p.x < 0
	# contact damage
	if not p.dead and (flying or _jump_h < 4.0) and dist < radius + 5.0:
		p.hurt((8.0 if boss else 6.0) * world.enemy_dmg_mult(), to_p)
	# gentle separation
	for e in world.enemies:
		if e == self or not is_instance_valid(e) or not e.alive:
			continue
		var d: Vector2 = global_position - e.global_position
		var l := d.length()
		if l > 0.01 and l < radius + e.radius:
			_move(d / l * (radius + e.radius - l) * 0.3)
	spr.position.y = -_jump_h
	if shadow:
		var k := clampf(1.0 - _jump_h / 40.0, 0.4, 1.0)
		shadow.scale = Vector2(k, k) * (radius / 5.0)


## Collision is checked in world coordinates (our parent layer sits at the room's origin).
func _move(d: Vector2) -> bool:
	var room: Room = world.room
	if room == null:
		return false
	var moved := false
	var gp := global_position
	var np := gp + Vector2(d.x, 0)
	if not room.blocked(np, radius, flying):
		gp = np
		moved = true
	np = gp + Vector2(0, d.y)
	if not room.blocked(np, radius, flying):
		gp = np
		moved = true
	global_position = gp
	return moved


func _walk(ddt: float, want: Vector2, spd: float) -> void:
	if want.length() < 0.01:
		return
	var d := want.normalized() * spd * ddt
	if not _move(d):
		# simple steering around obstacles
		for a in [0.9, -0.9, 1.6, -1.6]:
			if _move(d.rotated(a)):
				break
	if spr.animation != "run" and spr.sprite_frames.has_animation("run"):
		spr.play("run")


func _telegraph(color := Color(1, 1, 1)) -> void:
	mat.set_shader_parameter("tint", color)
	_flash = 0.85


# ---------------------------------------------------------------- behaviours

func _ai_chase(ddt: float, to_p: Vector2, _dist: float) -> void:
	var want := to_p
	if def.get("jitter", false):
		_wob += ddt * 5.0
		want = to_p.normalized() + to_p.normalized().orthogonal() * sin(_wob) * 0.7
	_walk(ddt, want, speed)


func _ai_fly(ddt: float, to_p: Vector2, _dist: float) -> void:
	_wob += ddt * 4.0
	var want := to_p.normalized() + to_p.normalized().orthogonal() * sin(_wob) * 1.1
	var r: Rect2 = world.room.inner_rect().grow(-4)
	global_position = (global_position + want.normalized() * speed * ddt).clamp(r.position, r.end)
	_jump_h = 5.0 + sin(_wob * 1.7) * 2.0


func _ai_hop(ddt: float, to_p: Vector2, _dist: float) -> void:
	match state:
		"idle":
			_jump_h = 0.0
			if t <= 0:
				state = "hop"
				t = 0.42
				dir = (to_p.normalized() + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))).normalized()
		"hop":
			_walk(ddt, dir, 115.0 * (1.0 + 0.05 * world.floor_num))
			_jump_h = sin((1.0 - t / 0.42) * PI) * 9.0
			if t <= 0:
				state = "idle"
				_jump_h = 0.0
				t = randf_range(0.7, 1.1)
				if def.get("shoot4", false):
					var a := 0.0 if _pattern % 2 == 0 else PI / 4
					_pattern += 1
					world.burst(global_position + Vector2(0, -6), 4, 75.0, "bullet_water", a)
					Audio.play("splash", -6.0)


func _ai_shooter(ddt: float, to_p: Vector2, dist: float) -> void:
	var want := Vector2.ZERO
	if dist < 60:
		want = -to_p
	elif dist > 110:
		want = to_p
	else:
		_wob += ddt
		want = to_p.orthogonal() * (1.0 if sin(_wob * 0.8) > 0 else -1.0)
	_walk(ddt, want, speed)
	if cd <= 0.35 and state != "aim":
		state = "aim"
		_telegraph(Color(1, 1, 0.8))
	if cd <= 0:
		state = "idle"
		cd = float(def["cd"]) * randf_range(0.85, 1.2)
		world.enemy_shot(global_position + Vector2(0, -8), to_p.normalized() * 85.0, "bullet_green")
		Audio.play("enemy_shoot")


func _ai_charger(ddt: float, to_p: Vector2, dist: float) -> void:
	match state:
		"idle":
			if t <= 0:
				t = randf_range(1.0, 1.8)
				dir = Vector2.from_angle(randf() * TAU)
			_walk(ddt, dir + to_p.normalized() * 0.6, speed)
			var aligned := absf(to_p.x) < 9 or absf(to_p.y) < 9
			if aligned and dist < 170 and cd <= 0:
				state = "windup"
				t = 0.45
				dir = Vector2(signf(to_p.x), 0) if absf(to_p.y) < 9 else Vector2(0, signf(to_p.y))
				_telegraph(Color(1, 0.4, 0.3))
				Audio.play("charge", -4.0)
		"windup":
			spr.position.x = sin(t * 80.0) * 1.0
			if t <= 0:
				spr.position.x = 0
				state = "charge"
				t = 1.3
		"charge":
			spr.flip_h = dir.x < 0
			if not _move(dir * float(def["charge"]) * ddt) or t <= 0:
				state = "stun"
				t = 0.6
				cd = 1.4
				if world.room:
					world.shake(2.0)
		"stun":
			if t <= 0:
				state = "idle"


func _ai_jumper(ddt: float, to_p: Vector2, _dist: float) -> void:
	match state:
		"idle":
			_walk(ddt, to_p, speed * 0.5)
			if cd <= 0:
				state = "crouch"
				t = 0.3
				scale = Vector2(1.2, 0.8)
		"crouch":
			if t <= 0:
				state = "air"
				t = 0.55
				scale = Vector2.ONE
				target_pos = world.player.global_position
				dir = global_position
		"air":
			var k := 1.0 - t / 0.55
			var np: Vector2 = (dir as Vector2).lerp(target_pos, clampf(k, 0, 1))
			if not world.room.blocked(np, radius, true):
				global_position = np
			_jump_h = sin(clampf(k, 0, 1) * PI) * 22.0
			if t <= 0:
				_jump_h = 0.0
				state = "idle"
				cd = randf_range(1.4, 2.0)
				world.shake(1.5)
				if world.floor_num >= 3:
					world.burst(global_position + Vector2(0, -4), 6, 70.0, "bullet_purple", randf() * TAU)


func _ai_caster(ddt: float, to_p: Vector2, _dist: float) -> void:
	if t <= 0:
		t = randf_range(1.2, 2.0)
		dir = Vector2.from_angle(randf() * TAU)
	if state != "cast":
		_walk(ddt, dir, speed)
	if cd <= 0.6 and state != "cast":
		state = "cast"
		_telegraph(Color(0.8, 0.5, 1.0))
	if cd <= 0:
		state = "idle"
		cd = float(def["cd"]) * randf_range(0.9, 1.15)
		_pattern += 1
		world.burst(global_position + Vector2(0, -10), 8, 70.0, "bullet_purple", 0.0 if _pattern % 2 == 0 else PI / 8)
		Audio.play("enemy_shoot", 2.0, 0.05, 0.8)


func _ai_summoner(ddt: float, to_p: Vector2, dist: float) -> void:
	_walk(ddt, -to_p if dist < 70 else to_p.orthogonal(), speed)
	if dist < 36 and state != "tp":
		_teleport()
	minions = minions.filter(func(m): return is_instance_valid(m) and m.alive)
	if cd <= 0:
		cd = 4.2
		if minions.size() < 3:
			_telegraph(Color(0.5, 1.0, 0.6))
			for i in 2:
				var m: Enemy = world.spawn_enemy("tiny_zombie", global_position + Vector2.from_angle(randf() * TAU) * 14.0)
				if m:
					minions.append(m)
			Audio.play("teleport", -4.0, 0.1, 0.7)


func _teleport() -> void:
	var spot: Vector2 = world.random_free_spot(global_position, 70.0)
	world.fx_smoke(global_position + Vector2(0, -8))
	global_position = spot
	world.fx_smoke(global_position + Vector2(0, -8))
	Audio.play("teleport", -2.0)
	cd = maxf(cd, 0.8)


func _ai_lobber(ddt: float, to_p: Vector2, dist: float) -> void:
	_walk(ddt, -to_p if dist < 70 else to_p.orthogonal() * (1 if sin(_wob) > 0 else -1), speed)
	_wob += ddt * 0.7
	if cd <= 0:
		cd = randf_range(2.2, 2.8)
		_telegraph(Color(0.6, 1.0, 0.6))
		world.lob(global_position + Vector2(0, -12), world.player.global_position)


# ---------------------------------------------------------------- bosses

func _boss_phase() -> int:
	var f := hp / max_hp
	return 1 if f > 0.66 else (2 if f > 0.33 else 3)


func _ai_boss_rot(ddt: float, to_p: Vector2, _dist: float) -> void:
	phase = _boss_phase()
	match state:
		"idle":
			_walk(ddt, to_p, speed * (1.0 + 0.25 * (phase - 1)))
			if cd <= 0:
				state = "slam_wind"
				t = 0.7
				_telegraph(Color(1, 0.5, 0.4))
				scale = Vector2(1.15, 0.85)
		"slam_wind":
			if t <= 0:
				scale = Vector2.ONE
				world.shake(4.0)
				Audio.play("explosion", -4.0, 0.05, 0.6)
				_pattern += 1
				world.burst(global_position + Vector2(0, -6), 10 + phase * 2, 72.0, "bullet_green", _pattern * 0.3)
				if phase >= 2 and _pattern % 2 == 0 and world.count_enemies() < 4:
					for i in 2:
						world.spawn_enemy("tiny_zombie", global_position + Vector2.from_angle(randf() * TAU) * 18.0)
				state = "idle"
				cd = 2.2 - 0.35 * phase


func _ai_boss_gaoler(ddt: float, to_p: Vector2, dist: float) -> void:
	phase = _boss_phase()
	match state:
		"idle":
			_walk(ddt, to_p, speed)
			if cd <= 0:
				_pattern += 1
				if _pattern % 3 == 0:
					state = "throw"
					t = 0.5
					_telegraph(Color(1, 0.9, 0.6))
				else:
					state = "windup"
					t = 0.55
					dir = to_p.normalized()
					_telegraph(Color(1, 0.35, 0.3))
					Audio.play("boss_roar", -6.0, 0.05, 1.2)
		"windup":
			spr.position.x = sin(t * 90.0) * 1.5
			if t <= 0:
				spr.position.x = 0
				state = "charge"
				t = 1.5
		"charge":
			spr.flip_h = dir.x < 0
			if not _move(dir * (165.0 + 20.0 * phase) * ddt) or t <= 0:
				world.shake(5.0)
				Audio.play("explosion", -6.0, 0.05, 0.5)
				if phase >= 2:
					world.burst(global_position + Vector2(0, -8), 8, 65.0, "bullet_purple", 0.0)
				state = "stun"
				t = 0.8 - 0.15 * phase
		"stun":
			if t <= 0:
				state = "idle"
				cd = 0.6
		"throw":
			if t <= 0:
				var base := to_p.angle()
				for i in 5:
					world.enemy_shot(global_position + Vector2(0, -14), Vector2.from_angle(base + (i - 2) * 0.22) * 90.0, "bullet_purple")
				Audio.play("enemy_shoot", 2.0)
				state = "idle"
				cd = 1.0


func _ai_boss_vicar(ddt: float, to_p: Vector2, dist: float) -> void:
	phase = _boss_phase()
	match state:
		"idle":
			_walk(ddt, -to_p if dist < 80 else to_p.orthogonal(), speed)
			if dist < 34:
				_teleport()
			if cd <= 0:
				_pattern += 1
				match _pattern % 3:
					0:
						state = "summon"
						t = 0.6
						_telegraph(Color(0.5, 1.0, 0.6))
					_:
						state = "spiral"
						t = 2.2 + 0.4 * phase
						_spin = randf() * TAU
						_wob = 0.35
						_telegraph(Color(0.8, 0.5, 1.0))
		"spiral":
			_wob -= ddt
			if _wob <= 0:
				_wob = 0.11
				_spin += 0.42
				for k in phase:
					world.enemy_shot(global_position + Vector2(0, -18), Vector2.from_angle(_spin + k * TAU / phase) * 70.0, "bullet_purple")
			if t <= 0:
				state = "idle"
				cd = 1.6
				_teleport()
		"summon":
			if t <= 0:
				minions = minions.filter(func(m): return is_instance_valid(m) and m.alive)
				if minions.size() < 4:
					for i in 2:
						var m: Enemy = world.spawn_enemy("skelet", world.random_free_spot(global_position, 40.0))
						if m:
							minions.append(m)
				Audio.play("teleport", 0.0, 0.05, 0.6)
				state = "idle"
				cd = 1.4


func _ai_boss_fiend(ddt: float, to_p: Vector2, dist: float) -> void:
	var np := _boss_phase()
	if np != phase:
		phase = np
		state = "roar"
		t = 1.0
		world.on_boss_phase(phase)
	match state:
		"roar":
			_telegraph(Color(1, 0.3, 0.2))
			if t <= 0:
				state = "idle"
				cd = 0.5
		"idle":
			_walk(ddt, to_p, speed * (1.0 + 0.2 * phase))
			if cd <= 0:
				_pattern += 1
				var opts := ["fan", "dash"]
				if phase >= 2:
					opts.append("hands")
				if phase >= 3:
					opts.append("toll")
				state = opts[_pattern % opts.size()]
				match state:
					"fan":
						t = 0.45
						dir = to_p.normalized()
					"dash":
						t = 0.5
						dir = to_p.normalized()
						Audio.play("boss_roar", -6.0, 0.05, 1.1)
					"hands":
						t = 3.0
						_spin = 0.0
						_wob = 0.5
						_hand_base = to_p.angle() + PI * 0.5
					"toll":
						t = 2.4
						_wob = 0.4
				_telegraph(Color(1, 0.4, 0.3))
		"fan":
			if t <= 0:
				var base := dir.angle()
				var n := 5 + phase
				for i in n:
					world.enemy_shot(global_position + Vector2(0, -18), Vector2.from_angle(base + (i - (n - 1) / 2.0) * 0.24) * (85.0 + 5 * phase), "bullet_purple")
				Audio.play("enemy_shoot", 3.0, 0.05, 0.7)
				state = "idle"
				cd = 1.3 - 0.2 * phase
		"dash":
			if t > 0:
				spr.position.x = sin(t * 90.0) * 1.5
			else:
				spr.position.x = 0
				spr.flip_h = dir.x < 0
				if not _move(dir * 190.0 * ddt) or t < -0.9:
					world.shake(5.0)
					world.burst(global_position + Vector2(0, -10), 10, 70.0, "bullet_purple", randf() * TAU)
					state = "idle"
					cd = 0.9
		"hands":
			# two clock hands sweep the room
			_wob -= ddt
			_spin += ddt * (0.85 + 0.15 * phase)
			if _wob <= 0:
				_wob = 0.09
				for k in 2:
					var a := _hand_base + k * PI + _spin * (1.0 if k == 0 else 0.5)
					world.enemy_shot(global_position + Vector2(0, -18), Vector2.from_angle(a) * 95.0, "bullet_purple")
			if t <= 0:
				state = "idle"
				cd = 1.2
		"toll":
			_wob -= ddt
			if _wob <= 0:
				_wob = 0.8
				Audio.play("bell_toll", -4.0, 0.0, 1.0)
				world.shake(3.0)
				world.burst(global_position + Vector2(0, -12), 16, 62.0, "bullet_purple", randf() * TAU)
				if world.count_enemies() < 4:
					world.spawn_enemy("imp", world.random_free_spot(global_position, 50.0))
			if t <= 0:
				state = "idle"
				cd = 1.0


# ---------------------------------------------------------------- damage

func take_hit(dmg: float, knock: Vector2, burn := 0.0) -> void:
	if not alive or not active:
		return
	if burn > 0.0:
		burn_t = maxf(burn_t, burn)
	if not heavy:
		kvel += knock
	else:
		kvel += knock * 0.15
	mat.set_shader_parameter("tint", Color(1, 1, 1))
	_flash = 1.0
	_damage(dmg, true)


func _damage(dmg: float, sound: bool) -> void:
	hp -= dmg
	if sound:
		Audio.play("hit_enemy", 0.0, 0.1)
	if boss:
		world.on_boss_hp(self)
	if hp <= 0:
		_die()


func _die() -> void:
	alive = false
	if def.get("death_burst", false):
		var at := global_position + Vector2(0, -6)
		var off: float = (world.player.global_position - global_position).angle() + PI / 6.0
		world.fx_ring(at, Color("#72d6ce"))
		var w := world
		get_tree().create_timer(0.4, false).timeout.connect(func():
			if is_instance_valid(w) and not w.finished:
				w.burst(at, 6, 65.0, "bullet_water", off))
	world.on_enemy_killed(self)
	if boss:
		return   # the world plays the boss death sequence and frees us
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.3), 0.12)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
