class_name FxGibs
extends Node2D
## Little chunks thrown out when a creature dies: they fly on a fake-z arc, bounce once, then settle
## and are baked into the room's stain image (so they cost nothing once they stop).

const GRAVITY := 520.0
const MAX := 48

var juice: Node
## ground position (world), height above the ground, vertical speed, ground velocity
var gpos := PackedVector2Array()
var z := PackedFloat32Array()
var vz := PackedFloat32Array()
var vel := PackedVector2Array()
var rest := PackedFloat32Array()
var bounced := PackedByteArray()
var idx := PackedByteArray()
var mats: Array[String] = []
var texs: Array[Texture2D] = []


func throw(at: Vector2, n: int, mat: String, power := 1.0, away := Vector2.ZERO) -> void:
	for k in n:
		if gpos.size() >= MAX:
			_settle(0)
		var a := randf() * TAU
		var v := Vector2.from_angle(a) * randf_range(16.0, 46.0) * power
		if away != Vector2.ZERO:
			v += away.normalized() * 22.0 * power
		gpos.append(at + Vector2(randf_range(-2, 2), randf_range(-1, 1)))
		z.append(randf_range(4.0, 9.0))
		vz.append(randf_range(60.0, 115.0) * sqrt(power))
		vel.append(v)
		rest.append(0.0)
		bounced.append(0)
		var i := randi() % Stains.GIBS
		idx.append(i)
		mats.append(mat)
		texs.append(Stains.tex_of("gib_%d" % i, mat))


func clear() -> void:
	gpos.clear()
	z.clear()
	vz.clear()
	vel.clear()
	rest.clear()
	bounced.clear()
	idx.clear()
	mats.clear()
	texs.clear()
	queue_redraw()


func _remove(i: int) -> void:
	gpos.remove_at(i)
	z.remove_at(i)
	vz.remove_at(i)
	vel.remove_at(i)
	rest.remove_at(i)
	bounced.remove_at(i)
	idx.remove_at(i)
	mats.remove_at(i)
	texs.remove_at(i)


## Bake gib i into the floor and drop it.
func _settle(i: int) -> void:
	var st: Stains = juice.stains_here() if juice else null
	if st:
		# most chunks soak in as a drop; a few stay as a chunk on the floor
		if randf() < 0.22:
			st.gib(gpos[i], idx[i], mats[i])
		else:
			st.dot(gpos[i], mats[i], 2 + randi() % 2)
	_remove(i)


func _process(dt: float) -> void:
	if gpos.is_empty():
		return
	var room: Node2D = juice.world.room if juice else null
	var i := gpos.size() - 1
	while i >= 0:
		if bounced[i] == 2:
			rest[i] += dt
			if rest[i] > 0.15:
				_settle(i)
			i -= 1
			continue
		var g := gpos[i] + vel[i] * dt
		# bounce off walls and solid things (checked at the ground point)
		if room and room.has_method("blocked") and room.blocked(g, 1.0, false):
			vel[i] = -vel[i] * 0.4
			g = gpos[i]
		gpos[i] = g
		vz[i] -= GRAVITY * dt
		z[i] += vz[i] * dt
		if z[i] <= 0.0:
			z[i] = 0.0
			if bounced[i] == 0:
				bounced[i] = 1
				vz[i] = -vz[i] * 0.32
				vel[i] = vel[i] * 0.45
			else:
				bounced[i] = 2
				vel[i] = Vector2.ZERO
		i -= 1
	queue_redraw()


func _draw() -> void:
	for i in gpos.size():
		var t := texs[i]
		var g := gpos[i].round()
		if z[i] > 2.0:
			draw_rect(Rect2(g + Vector2(-1, 0), Vector2(2, 1)), Color(0.08, 0.05, 0.07, 0.5))
		var p := (gpos[i] + Vector2(0, -z[i])).round() - (t.get_size() / 2.0).floor()
		draw_texture(t, p)
