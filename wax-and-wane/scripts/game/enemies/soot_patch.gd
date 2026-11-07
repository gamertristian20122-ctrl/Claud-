class_name SootPatch
extends Node2D
## A smear of chimney soot left by a Sootling. Standing in it drags at Tallow (about half speed).
## Lives on the room's floor layer, so it is cleaned up with the room.

const LIFE := 6.0
const MAX_PER_ROOM := 12
## Fixed pixel blotches (x, y, w, h) so the smears read as hand-placed, not noise.
const SHAPES := [
	[[-5, -1, 10, 3], [-3, -2, 6, 5], [-6, 0, 2, 1], [4, 1, 3, 1], [-1, 3, 2, 1]],
	[[-4, -2, 9, 4], [-6, -1, 3, 2], [2, 1, 5, 2], [-2, 2, 3, 1], [5, -2, 1, 1]],
	[[-5, -1, 11, 2], [-2, -3, 5, 6], [-6, 1, 3, 1], [3, -2, 2, 1]],
]

var world: Node
var life := LIFE
var _shape := 0
var _puff := 0.0


static func drop(w: Node, gpos: Vector2) -> void:
	var room: Room = w.room
	if room == null or not is_instance_valid(room.floor_layer):
		return
	var mine: Array = []
	for c in room.floor_layer.get_children():
		if c is SootPatch:
			mine.append(c)
	if mine.size() >= MAX_PER_ROOM:
		(mine[0] as SootPatch).life = minf((mine[0] as SootPatch).life, 0.4)
	var s := SootPatch.new()
	s.world = w
	s.position = (gpos - room.position).round()
	s._shape = randi() % SHAPES.size()
	room.floor_layer.add_child(s)


func _draw() -> void:
	for r in SHAPES[_shape]:
		draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color("#2a2a3a"))
	var hi: Array = SHAPES[_shape][1]
	draw_rect(Rect2(hi[0] + 1, hi[1], 2, 1), Color("#483b3a"))


func _physics_process(dt: float) -> void:
	if world == null or world.player == null:
		return
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	modulate.a = clampf(life / 1.0, 0.0, 0.85)
	var p: Player = world.player
	if p.dead or p.frozen:
		return
	var d: Vector2 = p.global_position - global_position
	if absf(d.x) < 7.0 and absf(d.y) < 4.5:
		# give back part of this frame's step: Tallow wades through the soot
		p.position -= p.vel * dt * 0.45
		_puff -= dt
		if _puff <= 0.0 and p.vel.length() > 10.0:
			_puff = 0.35
			world.fx_smoke(p.global_position + Vector2(0, -2))
		if Game.tip("soot"):
			world.hud.show_hint("Soot clings to your wax: it slows you down", 2.5)
