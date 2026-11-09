class_name FxParts
extends Node2D
## Cheap pixel particles (sparks, embers, dust puffs, wax drops), all drawn in one _draw call.
## Each particle steps through a short colour ramp as it ages (no alpha fades, so it stays pixel art).
## Capped: when full, the oldest particle is replaced.

const RAMPS := [
	# 0 fire spark: white-hot -> yellow -> orange -> red
	[Color("#fdf7ed"), Color("#facb3e"), Color("#ee8e2e"), Color("#da4e38")],
	# 1 ember (slow, rises): yellow -> orange -> red -> dark red
	[Color("#facb3e"), Color("#ee8e2e"), Color("#da4e38"), Color("#8f4029")],
	# 2 dust: pale -> mid -> dark brown
	[Color("#aa8d7a"), Color("#775c55"), Color("#483b3a")],
	# 3 smoke: light grey -> grey -> dark
	[Color("#b6cbcf"), Color("#7b8994"), Color("#483b3a")],
	# 4 wax drop
	[Color("#fdf7ed"), Color("#e2b694"), Color("#d8a57d")],
	# 5 gold glint
	[Color("#fdf7ed"), Color("#facb3e"), Color("#ee8e2e")],
	# 6 blue spark (Blue Flame)
	[Color("#cae6f5"), Color("#72d6ce"), Color("#5698cc"), Color("#5956bd")],
	# 7 cold mote (dust in the light)
	[Color("#fdf7ed"), Color("#d3bfa9"), Color("#aa8d7a")],
	# 8 moon (Moonwick's Blink, scripts/game/moves.gd): cream -> pale blue -> grey-blue -> pewter
	[Color("#fdf7ed"), Color("#cae6f5"), Color("#b6cbcf"), Color("#7b8994")],
	# 9 void (the Black Taper's black flame): pale core -> violet -> plum -> ink
	[Color("#cae6f5"), Color("#5956bd"), Color("#5f2d56"), Color("#2a2a3a")],
]
const SPARK := 0
const EMBER := 1
const DUST := 2
const SMOKE := 3
const WAX := 4
const GOLD := 5
const BLUE := 6
const MOON := 8
const VOID := 9

var cap := 200
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat32Array()
var dur := PackedFloat32Array()
var grav := PackedFloat32Array()
var drag := PackedFloat32Array()
var ramp := PackedByteArray()
var size := PackedByteArray()
var trail := PackedByteArray()
## Called with the ground position of a WAX particle when it lands (z ramp ends): used for drip dots.
var on_land: Callable
var _oldest := 0
var _was_empty := true


func emit(p: Vector2, v: Vector2, d: float, ramp_i: int, g := 0.0, dr := 0.0, sz := 1, tr := false) -> void:
	if pos.size() >= cap:
		# replace the oldest slot instead of growing
		_oldest = (_oldest + 1) % cap
		var i := _oldest
		pos[i] = p
		vel[i] = v
		life[i] = d
		dur[i] = d
		grav[i] = g
		drag[i] = dr
		ramp[i] = ramp_i
		size[i] = sz
		trail[i] = 1 if tr else 0
		return
	pos.append(p)
	vel.append(v)
	life.append(d)
	dur.append(d)
	grav.append(g)
	drag.append(dr)
	ramp.append(ramp_i)
	size.append(sz)
	trail.append(1 if tr else 0)


## A burst of n particles in a cone around dir (or all round when dir is zero).
func burst(p: Vector2, n: int, spd_min: float, spd_max: float, dir: Vector2, cone: float, d: float, ramp_i: int,
		g := 0.0, dr := 0.0, sz := 1, tr := false) -> void:
	for k in n:
		var a := randf() * TAU
		if dir != Vector2.ZERO:
			a = dir.angle() + randf_range(-cone, cone)
		emit(p, Vector2.from_angle(a) * randf_range(spd_min, spd_max), d * randf_range(0.7, 1.25), ramp_i, g, dr, sz, tr)


func clear() -> void:
	pos.clear()
	vel.clear()
	life.clear()
	dur.clear()
	grav.clear()
	drag.clear()
	ramp.clear()
	size.clear()
	trail.clear()
	queue_redraw()


func count() -> int:
	return pos.size()


func _process(dt: float) -> void:
	var n := pos.size()
	if n == 0:
		if not _was_empty:
			_was_empty = true
			queue_redraw()
		return
	_was_empty = false
	var i := 0
	while i < n:
		life[i] -= dt
		if life[i] <= 0.0:
			if ramp[i] == WAX and on_land.is_valid():
				on_land.call(pos[i])
			# swap-remove
			n -= 1
			pos[i] = pos[n]
			vel[i] = vel[n]
			life[i] = life[n]
			dur[i] = dur[n]
			grav[i] = grav[n]
			drag[i] = drag[n]
			ramp[i] = ramp[n]
			size[i] = size[n]
			trail[i] = trail[n]
			continue
		var v := vel[i]
		v.y += grav[i] * dt
		if drag[i] > 0.0:
			v = v * maxf(0.0, 1.0 - drag[i] * dt)
		vel[i] = v
		pos[i] += v * dt
		i += 1
	if n != pos.size():
		pos.resize(n)
		vel.resize(n)
		life.resize(n)
		dur.resize(n)
		grav.resize(n)
		drag.resize(n)
		ramp.resize(n)
		size.resize(n)
		trail.resize(n)
		_oldest = 0
	queue_redraw()


func _draw() -> void:
	for i in pos.size():
		var r: Array = RAMPS[ramp[i]]
		var k := clampi(int((1.0 - life[i] / dur[i]) * r.size()), 0, r.size() - 1)
		var p := pos[i].round()
		var s := float(size[i])
		if trail[i] == 1:
			var v := vel[i]
			if v.length_squared() > 900.0:
				# a short spark trail: 2 px behind in the next (cooler) colour
				var back := (v.normalized() * -1.5).round()
				var c2: Color = r[mini(k + 1, r.size() - 1)]
				draw_rect(Rect2(p + back, Vector2(1, 1)), c2)
				if v.length_squared() > 6400.0:
					draw_rect(Rect2(p + back * 2.0, Vector2(1, 1)), r[r.size() - 1])
		draw_rect(Rect2(p, Vector2(s, s)), r[k])
