class_name Juice
extends Node2D
## Game feel for one run: floor stains, gibs, sparks and embers, dust in the light, the camera shake,
## the boss "versus" card, the boss finale, room-clear bursts and the burn fade. One Juice node lives
## under the world; the world talks to it through one-line hooks (`Juice.of(self).<event>(...)`).

const BURN_SHADER := preload("res://scripts/game/burn.gdshader")
const DUST_MOTES := 22

var world: Node
var hot: FxParts      # unshaded: sparks, embers, glints (they glow)
var lit: FxParts      # lit by the candle: dust puffs, smoke, wax drops
var gibs: FxGibs
var dust: Node2D
## Stain images per room cell for the current floor (kept when you leave a room).
var stain_store := {}
var _stain_floor := -1
var _cur_stains: Stains
# camera shake: smooth noise amplitude (px) + a directional kick that springs back
var _amp := 0.0
var _kick := Vector2.ZERO
var _st := 0.0
var _ember_t := 0.5
# boss intro
var card: Node
var _await_boss := false
var _bars: Array = []
var _bars_layer: CanvasLayer
var _punch_tw: Tween
# burn fade on the world's own fade rect (trapdoor)
var _fade_mat: ShaderMaterial
var _fade_last := 0.0


static func of(w: Node) -> Juice:
	var j = w.get_meta("juice") if w.has_meta("juice") else null
	if j != null and is_instance_valid(j):
		return j
	var nj := Juice.new()
	nj.world = w
	w.set_meta("juice", nj)
	w.add_child(nj)
	return nj


## True while the boss card holds the world (enemies, the candle and enemy shots wait).
static func holding(w: Node) -> bool:
	if w == null:
		return false
	var j = w.get_meta("juice") if w.has_meta("juice") else null
	return j != null and is_instance_valid(j) and j.card != null and is_instance_valid(j.card)


## The screen shake setting may be a toggle or (later) a 0..1 strength.
static func shake_scale() -> float:
	var s = Game.settings.get("shake", true)
	if s is bool:
		return 1.0 if s else 0.0
	return clampf(float(s), 0.0, 1.0)


func _ready() -> void:
	name = "Juice"
	z_index = -8   # gibs: above the floor and its stains, below creatures
	gibs = FxGibs.new()
	gibs.juice = self
	add_child(gibs)
	var layer: Node2D = world.get("fx_layer")
	if layer == null:
		layer = self
	lit = FxParts.new()
	lit.cap = 140
	lit.z_index = -1
	lit.on_land = _drop_landed
	layer.add_child(lit)
	hot = FxParts.new()
	hot.cap = 180
	hot.z_index = 2
	hot.material = Art.unshaded
	layer.add_child(hot)
	dust = Dust.new()
	dust.z_index = 1
	var dm := CanvasItemMaterial.new()
	dm.light_mode = CanvasItemMaterial.LIGHT_MODE_LIGHT_ONLY
	dust.material = dm
	layer.add_child(dust)
	var f = world.get("_fade")
	if f is ColorRect:
		_fade_mat = burn_material()
		f.material = _fade_mat


## A fresh material for a ColorRect that should burn instead of fade (see burn.gdshader).
static func burn_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BURN_SHADER
	m.set_shader_parameter("seed", randf() * 100.0)
	return m


## Pick a new burn pattern + corner; `reveal` = the dark cover burns away.
static func burn_prepare(m: ShaderMaterial, reveal: bool, size: Vector2) -> void:
	if m == null:
		return
	m.set_shader_parameter("reveal", reveal)
	m.set_shader_parameter("seed", randf() * 100.0)
	m.set_shader_parameter("px_size", size)
	m.set_shader_parameter("origin", Vector2(randi() % 2, randi() % 2))


# ---------------------------------------------------------------- per frame

func _process(dt: float) -> void:
	_shake_step(dt)
	_fade_watch()
	var p: Node2D = world.get("player")
	var room: Node2D = world.get("room")
	if room and is_instance_valid(room):
		if dust.position != room.position:
			dust.move_to(room.position)   # the old room keeps its motes while the camera pans away
		if _cur_stains == null or not is_instance_valid(_cur_stains) or _cur_stains.room != room:
			_cur_stains = room.get_meta("stains") if room.has_meta("stains") else null
			gibs.clear()
	if p and is_instance_valid(p) and not p.dead:
		_flame_embers(p, dt)
	if _await_boss:
		var b = world.get("boss")
		if b != null and is_instance_valid(b):
			_await_boss = false
			_punch_in(b.global_position + Vector2(0, -12))


func _flame_embers(p: Node2D, dt: float) -> void:
	if p.frozen or not p.flame.visible:
		return
	var fast: bool = p.vel.length() > 50.0
	var rate := 0.24 if fast else 0.75
	if "hearth" in p.rites:
		rate *= 0.45
	_ember_t -= dt
	if _ember_t > 0.0:
		return
	_ember_t = rate * randf_range(0.6, 1.4)
	var tip: Vector2 = p.flame.global_position + Vector2(randf_range(-1, 1), -9)
	var v := Vector2(randf_range(-6, 6) - p.vel.x * 0.25, randf_range(-30, -18))
	hot.emit(tip, v, randf_range(0.7, 1.3), FxParts.BLUE if p.blue else FxParts.EMBER, -6.0, 0.6)


## Keep the world's fade rect burning the right way: dark spreading in, then burning away.
func _fade_watch() -> void:
	if _fade_mat == null:
		return
	var f: ColorRect = world.get("_fade")
	var a := f.color.a
	if a > _fade_last and _fade_last <= 0.001:
		burn_prepare(_fade_mat, false, f.size)
	elif a < _fade_last and _fade_last >= 0.999:
		burn_prepare(_fade_mat, true, f.size)
	_fade_last = a


# ---------------------------------------------------------------- camera

## amount ~ pixels. Small hits stay subtle, big moments hit hard.
func shake(amount: float) -> void:
	var k := 0.55 if amount < 2.5 else (0.85 if amount < 5.0 else 1.15)
	_amp = maxf(_amp, amount * k)


func kick(dir: Vector2, px: float) -> void:
	if dir == Vector2.ZERO:
		return
	_kick += dir.normalized() * px


func _shake_step(dt: float) -> void:
	var cam: Camera2D = world.get("cam")
	if cam == null:
		return
	if _amp <= 0.05 and _kick.length() < 0.3:
		_amp = 0.0
		_kick = Vector2.ZERO
		return
	_st += dt
	var s := shake_scale()
	var n := Vector2(sin(_st * 47.0) + 0.5 * sin(_st * 83.0 + 1.7), sin(_st * 53.0 + 0.6) + 0.5 * sin(_st * 71.0 + 2.9)) / 1.5
	cam.offset = ((n * _amp + _kick) * s).round()
	_amp = move_toward(_amp, 0.0, dt * (4.0 + _amp * 5.0))
	_kick = _kick.move_toward(Vector2.ZERO, dt * 45.0)


# ---------------------------------------------------------------- stains

func attach_stains(r: Node2D) -> void:
	var fn: int = world.get("floor_num")
	if fn != _stain_floor:
		_stain_floor = fn
		stain_store.clear()
	var st := Stains.new()
	var cell: Vector2i = r.get("cell")
	st.setup(r, stain_store.get(cell))
	var fl: Node2D = r.get("floor_layer")
	if fl:
		fl.add_child(st)
		fl.move_child(st, 0)
	else:
		st.z_index = -14
		r.add_child(st)
	r.set_meta("stains", st)
	st.tree_exiting.connect(func():
		if st.img and fn == _stain_floor:
			stain_store[cell] = st.img)


func stains_here() -> Stains:
	if _cur_stains and is_instance_valid(_cur_stains):
		return _cur_stains
	var room: Node2D = world.get("room")
	if room and is_instance_valid(room):
		_cur_stains = room.get_meta("stains") if room.has_meta("stains") else null
	return _cur_stains


func _drop_landed(at: Vector2) -> void:
	var st := stains_here()
	if st:
		st.dot(at, "wax", 1 + randi() % 2)


## A falling wax drop that leaves a dot where it lands.
func wax_drop(at: Vector2, v := Vector2.ZERO, fall := 0.22) -> void:
	lit.emit(at, v + Vector2(randf_range(-6, 6), 30.0), fall, FxParts.WAX, 220.0, 0.0, 1)


func splat(at: Vector2, mat: String, big := false) -> void:
	var st := stains_here()
	if st:
		st.splat(at, mat, big)


## The bomb's mark on the floor (and a short freeze for the blast).
func scorch(at: Vector2) -> void:
	world.hitstop(0.045, 0.1)
	hot.burst(at + Vector2(0, -6), 14, 40.0, 120.0, Vector2.ZERO, PI, 0.4, FxParts.SPARK, 120.0, 1.5, 1, true)
	lit.burst(at, 10, 15.0, 50.0, Vector2.ZERO, PI, 0.8, FxParts.SMOKE, -25.0, 2.5, 2)
	var st := stains_here()
	if st:
		st.stamp_image(Stains.image("scorch", "soot"), at)
		for i in 3:
			st.splat(at + Vector2(randf_range(-12, 12), randf_range(-7, 7)), "soot")


# ---------------------------------------------------------------- events

func enemy_killed(e: Node2D) -> void:
	var mat := Stains.material_of(e.kind)
	var at: Vector2 = e.global_position
	if e.boss:
		return   # the finale does its own thing
	var big: bool = e.radius > 6.5 or e.champ != ""
	var kv: Vector2 = e.kvel
	var st := stains_here()
	if st:
		st.splat(at + Vector2(0, -1), mat, big)
		# a few drops thrown the way it was hit
		var away := kv.normalized() if kv.length() > 5.0 else Vector2.from_angle(randf() * TAU)
		for k in (3 if big else 2):
			st.speck(at + away.rotated(randf_range(-0.8, 0.8)) * randf_range(7.0, 13.0), mat)
	gibs.throw(at + Vector2(0, -3), randi_range(4, 6) + (2 if big else 0), mat, 1.0, kv)
	lit.burst(at + Vector2(0, -4), 3, 10.0, 25.0, Vector2.ZERO, PI, 0.35, FxParts.DUST, -20.0, 2.0)
	shake(1.6 if not big else 3.0)
	if big:
		world.hitstop(0.035, 0.12)   # a heavy or marked foe lands with a tiny freeze


func boss_finale(e: Node2D) -> void:
	var at: Vector2 = e.global_position
	var mat := Stains.material_of(e.kind)
	var m: ShaderMaterial = e.get("mat")
	# four flashes + poofs, each one harder, then one huge splat
	for i in 4:
		var tw := create_tween()
		tw.tween_interval(0.08 + i * 0.2)
		tw.tween_callback(func():
			if is_instance_valid(e) and m:
				m.set_shader_parameter("tint", Color(1, 1, 1))
				m.set_shader_parameter("flash", 1.0)
			_flash_light(at + Vector2(0, -14), 1.4 + i * 0.4, 0.7 + i * 0.25)
			world.fx_poof(at + Vector2(randf_range(-14, 14), randf_range(-26, -2)), false, 1.6 + i * 0.2)
			gibs.throw(at + Vector2(randf_range(-6, 6), -6), 3 + i, mat, 1.3)
			hot.burst(at + Vector2(0, -14), 6 + 2 * i, 40.0, 110.0, Vector2.ZERO, PI, 0.4, FxParts.SPARK, 90.0, 1.5, 1, true)
			shake(4.0 + i * 1.5)
			Audio.play("hit_enemy", 2.0, 0.1, 0.7 - i * 0.08))
		tw.tween_interval(0.06)
		tw.tween_callback(func():
			if is_instance_valid(e) and m:
				m.set_shader_parameter("flash", 0.0))
	# slow-motion right after the world's hit-stop
	var sm := create_tween().set_ignore_time_scale(true)
	sm.tween_interval(0.36)
	sm.tween_callback(func():
		if not world.finished:
			Engine.time_scale = 0.3 * Game.base_time_scale)
	sm.tween_interval(0.4)
	sm.tween_callback(func():
		if not world.finished:
			Engine.time_scale = Game.base_time_scale)
	var fin := create_tween()
	fin.tween_interval(0.8)
	fin.tween_callback(func():
		var st := stains_here()
		if st:
			st.huge(at, mat)
			for k in 5:
				st.splat(at + Vector2.from_angle(k * TAU / 5.0 + randf()) * randf_range(16, 24) * Vector2(1, 0.7), mat, k % 2 == 0)
			for k in 6:
				st.speck(at + Vector2.from_angle(randf() * TAU) * randf_range(22, 34) * Vector2(1, 0.7), mat)
		gibs.throw(at + Vector2(0, -8), 12, mat, 1.7)
		_flash_light(at + Vector2(0, -14), 2.6, 1.8)
		hot.burst(at + Vector2(0, -12), 24, 50.0, 150.0, Vector2.ZERO, PI, 0.55, FxParts.SPARK, 80.0, 1.2, 1, true)
		lit.burst(at + Vector2(0, -6), 14, 20.0, 60.0, Vector2.ZERO, PI, 0.7, FxParts.SMOKE, -30.0, 2.5, 2)
		shake(9.0)
		Game.vibrate(120))


func _flash_light(at: Vector2, energy: float, sc: float) -> void:
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(1.0, 0.85, 0.65)
	l.energy = energy
	l.texture_scale = sc
	l.global_position = at
	world.fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


func room_cleared() -> void:
	var r: Node2D = world.room
	if r == null:
		return
	var doors: Dictionary = r.get("doors")
	for dir in doors.keys():
		var s: Sprite2D = doors[dir]
		if not is_instance_valid(s) or s.texture == null:
			continue
		var c: Vector2 = s.global_position + s.texture.get_size() / 2.0
		var inward := -Vector2(dir)
		var mouth := c + inward * 8.0
		lit.burst(mouth, 10, 25.0, 70.0, inward, 0.9, 0.5, FxParts.DUST, -10.0, 4.0, 1)
		lit.burst(mouth, 3, 8.0, 20.0, inward, 1.2, 0.8, FxParts.SMOKE, -16.0, 2.0, 2)
		world.fx_poof(mouth + Vector2(0, -2), false, 1.2)
	# a soft ring of light from the candle
	var p: Node2D = world.player
	var ring := LightRing.new()
	ring.position = p.global_position + Vector2(0, -8)
	# the ring stays on the floor: never over the walls or out into the dark margin
	ring.clip = Rect2(r.global_position + Room.IN - ring.position, Vector2(Room.COLS * Room.TILE, Room.ROWS * Room.TILE))
	world.fx_layer.add_child(ring)
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(1.0, 0.8, 0.5)
	l.energy = 0.0
	l.texture_scale = 0.4
	l.global_position = p.global_position + Vector2(0, -10)
	world.fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.7, 0.12)
	tw.parallel().tween_property(l, "texture_scale", 2.4, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	shake(2.0)


## Tallow takes a relic: hold it above the flame for a moment.
func relic_taken(id: String) -> void:
	var p = world.get("player")
	if p == null or not p.has_method("hold_aloft"):
		return
	if Items.TONICS.has(id):
		# tonics are small change: a quick sparkle, no pause
		glint(p.global_position + Vector2(0, -20))
		return
	p.hold_aloft(Art.tex(Items.icon(id)))


func player_died() -> void:
	# the room goes dark with the flame
	var d: CanvasModulate = world.get("dark")
	if d:
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(d, "color", d.color.darkened(0.55), 1.6)


func descended() -> void:
	var p: Node2D = world.player
	lit.burst(p.global_position, 12, 20.0, 60.0, Vector2.UP, 1.3, 0.5, FxParts.DUST, 40.0, 3.0)
	hot.burst(p.global_position + Vector2(0, -10), 8, 15.0, 45.0, Vector2.UP, 0.7, 0.8, FxParts.EMBER, -20.0, 1.0)


func sparks(at: Vector2, dir: Vector2, n := 4, blue := false) -> void:
	hot.burst(at, n, 30.0, 85.0, dir, 1.0, 0.22, FxParts.BLUE if blue else FxParts.SPARK, 140.0, 2.0, 1, true)


func muzzle(at: Vector2, dir: Vector2, blue := false) -> void:
	hot.burst(at + dir * 2.0, 2, 25.0, 55.0, dir, 0.45, 0.12, FxParts.BLUE if blue else FxParts.SPARK, 0.0, 6.0)
	lit.emit(at + dir * 3.0 + Vector2(0, -1), dir * 8.0 + Vector2(0, -10), 0.35, FxParts.SMOKE, -8.0, 2.0, 1)


func wisp(at: Vector2) -> void:
	lit.emit(at, Vector2(randf_range(-4, 4), -14.0), 0.7, FxParts.SMOKE, -6.0, 1.0, 1)
	if randf() < 0.5:
		lit.emit(at + Vector2(1, 1), Vector2(randf_range(-3, 3), -10.0), 0.6, FxParts.SMOKE, -4.0, 1.0, 1)


func glint(at: Vector2) -> void:
	hot.burst(at, 6, 15.0, 40.0, Vector2.ZERO, PI, 0.45, FxParts.GOLD, 0.0, 3.0)


# ---------------------------------------------------------------- boss intro

func boss_card(kind: String, title: String) -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	if world.main and world.main.autotest and world.main.autotest.get("args") is Dictionary \
			and world.main.autotest.args.has("nocard"):
		return
	card = BossCard.new()
	card.setup(self, kind, title)
	add_child(card)


## Called by the card when it is gone: bars + a quick punch-in once the boss shows up.
func card_done() -> void:
	card = null
	_show_bars(true)
	_await_boss = true


func _show_bars(on: bool) -> void:
	if _bars_layer == null:
		_bars_layer = CanvasLayer.new()
		_bars_layer.layer = 11
		add_child(_bars_layer)
		for i in 2:
			var b := ColorRect.new()
			b.color = Color(0.035, 0.027, 0.035)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bars_layer.add_child(b)
			_bars.append(b)
	var vs := get_viewport().get_visible_rect().size
	var h := 22.0
	var tw := create_tween().set_parallel(true)
	for i in 2:
		var b: ColorRect = _bars[i]
		b.size = Vector2(vs.x, h)
		var shown := Vector2(0, 0 if i == 0 else vs.y - h)
		var hidden := Vector2(0, -h if i == 0 else vs.y)
		if on:
			b.position = hidden
		tw.tween_property(b, "position", shown if on else hidden, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _punch_in(at: Vector2) -> void:
	var cam: Camera2D = world.cam
	var home: Vector2 = world._cam_target(world.room)
	if _punch_tw:
		_punch_tw.kill()
	_punch_tw = create_tween()
	var target := home.lerp(at, 0.35)
	_punch_tw.tween_property(cam, "zoom", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch_tw.parallel().tween_property(cam, "position", target, 0.12)
	_punch_tw.tween_interval(0.35)
	_punch_tw.tween_property(cam, "zoom", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_punch_tw.parallel().tween_property(cam, "position", home, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_punch_tw.tween_callback(func():
		cam.zoom = Vector2.ONE
		cam.position = world._cam_target(world.room)
		_show_bars(false))
	shake(3.0)


func _exit_tree() -> void:
	if card and is_instance_valid(card) and get_tree():
		get_tree().paused = false


# ---------------------------------------------------------------- small drawn effects

## Slow motes that only show where light falls on them (light-only material).
class Dust extends Node2D:
	var pts := PackedVector2Array()
	var ph := PackedFloat32Array()
	var col: Array[Color] = [Color("#fdf7ed"), Color("#d3bfa9"), Color("#aa8d7a")]
	var _t := 0.0
	# the motes of the room we just left (drawn where that room is) until the camera pan is over
	var old_pts := PackedVector2Array()
	var old_off := Vector2.ZERO
	var _old_t := 0.0
	var _placed := false

	func _ready() -> void:
		_scatter()

	func _scatter() -> void:
		pts.clear()
		ph.clear()
		for i in DUST_MOTES:
			pts.append(Vector2(randf_range(16, 256), randf_range(32, 176)))
			ph.append(randf() * TAU)

	## A new room: its own motes; the old ones stay put in the old room (no snap at the pan start).
	func move_to(origin: Vector2) -> void:
		if _placed:
			old_pts = pts.duplicate()
			old_off = position - origin
			_old_t = 0.6
		_placed = true
		position = origin
		_scatter()

	func _drift(arr: PackedVector2Array, dt: float) -> void:
		for i in arr.size():
			var p := arr[i]
			p += Vector2(sin(_t * 0.31 + ph[i]) * 2.2, -1.1 - 0.6 * sin(ph[i] * 3.0)) * dt
			if p.y < 30.0:
				p.y = 176.0
				p.x = randf_range(16, 256)
			p.x = wrapf(p.x, 16.0, 256.0)
			arr[i] = p

	func _process(dt: float) -> void:
		_t += dt
		_drift(pts, dt)
		if _old_t > 0.0:
			_old_t -= dt
			_drift(old_pts, dt)
			if _old_t <= 0.0:
				old_pts.clear()
		queue_redraw()

	func _draw() -> void:
		for i in pts.size():
			# motes twinkle as they turn: brighter for part of their cycle
			var k := int(fposmod(_t * 0.5 + ph[i], 3.0))
			draw_rect(Rect2(pts[i].round(), Vector2.ONE), col[k])
		for i in old_pts.size():
			var k := int(fposmod(_t * 0.5 + ph[i], 3.0))
			draw_rect(Rect2((old_pts[i] + old_off).round(), Vector2.ONE), col[k])


## An expanding 1 px ring of warm light (room clear).
class LightRing extends Node2D:
	var r := 4.0
	var t := 0.0
	var clip := Rect2(-9999, -9999, 19998, 19998)   # ring-local area the ring may draw in
	const COLS: Array[Color] = [Color("#fdf7ed"), Color("#facb3e"), Color("#ee8e2e"), Color("#8f4029")]

	func _ready() -> void:
		material = Art.unshaded
		z_index = 3

	func _process(dt: float) -> void:
		t += dt
		r = 4.0 + 78.0 * (1.0 - pow(1.0 - minf(t / 0.6, 1.0), 2.0))
		if t >= 0.6:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var c: Color = COLS[mini(int(t / 0.6 * COLS.size()), COLS.size() - 1)]
		# midpoint circle: crisp 1 px pixels, a few skipped so it reads as a soft shimmer
		var x := int(r)
		var y := 0
		var err := 1 - x
		var n := 0
		var gap := 3 if t < 0.3 else 2   # the ring thins out as it spreads
		while x >= y:
			n += 1
			if n % gap != 0:
				for q in [Vector2(x, y), Vector2(y, x), Vector2(-y, x), Vector2(-x, y), Vector2(-x, -y), Vector2(-y, -x), Vector2(y, -x), Vector2(x, -y)]:
					if clip.has_point(q):
						draw_rect(Rect2(q, Vector2.ONE), c)
			y += 1
			if err < 0:
				err += 2 * y + 1
			else:
				x -= 1
				err += 2 * (y - x) + 1
