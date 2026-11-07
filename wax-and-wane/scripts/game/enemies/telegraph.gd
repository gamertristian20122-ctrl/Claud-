class_name Telegraph
extends Node2D
## Warning marks a monster draws before it strikes: blinking dashed lines (dash paths, firing lanes),
## pixel rings (where a hand will burst up, how far a slam reaches) and the Great Pendulum's rod.
## Points are stored in world space so a mark stays put while its owner moves.
## Drawn unshaded so a warning is always readable, even in a dark room.

var shapes: Array = []
## Pendulum rod: world-space anchor; the rod runs to the owner's position + rod_end.
var rod := false
var rod_anchor := Vector2.ZERO
var rod_end := Vector2.ZERO
var _t := 0.0
## The rod hangs from the ceiling in front of everything in the room, so it draws on its own layer.
var _rod_node: Node2D

const DARK := Color("#21141b")
const BRASS := Color("#facb3e")
const BRASS_SH := Color("#c56025")


func _ready() -> void:
	material = Art.unshaded
	z_index = -1
	_rod_node = Node2D.new()
	_rod_node.z_index = 5
	_rod_node.draw.connect(_draw_rod)
	add_child(_rod_node)


func line(a: Vector2, b: Vector2, dur: float, col: Color) -> void:
	shapes.append({"k": "line", "a": a, "b": b, "t": dur, "d": dur, "col": col})
	queue_redraw()


func ring(c: Vector2, r: float, dur: float, col: Color) -> void:
	shapes.append({"k": "ring", "a": c, "r": r, "t": dur, "d": dur, "col": col})
	queue_redraw()


## A dotted path through world points (the pendulum shows its sweep before it starts).
func path(pts: PackedVector2Array, dur: float, col: Color) -> void:
	shapes.append({"k": "path", "pts": pts, "t": dur, "d": dur, "col": col})
	queue_redraw()


func clear() -> void:
	shapes.clear()
	queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	if shapes.is_empty() and not rod:
		return
	for s in shapes:
		s["t"] -= dt
	shapes = shapes.filter(func(s): return s["t"] > 0.0)
	queue_redraw()
	if rod:
		_rod_node.queue_redraw()


func _px(p: Vector2, col: Color) -> void:
	draw_rect(Rect2(p.round(), Vector2.ONE), col)


func _draw() -> void:
	for s in shapes:
		# blink faster as the strike gets closer
		var left: float = s["t"]
		var rate := 0.09 if left < 0.3 else 0.16
		if fmod(_t, rate * 2.0) > rate * 1.35:
			continue
		var col: Color = s["col"]
		match s["k"]:
			"line":
				var a: Vector2 = to_local(s["a"])
				var b: Vector2 = to_local(s["b"])
				var n := int(a.distance_to(b) / 3.0)
				for i in n + 1:
					var p := a.lerp(b, float(i) / maxf(1.0, n))
					_px(p, col)
					if i % 2 == 0:
						_px(p + Vector2(0, 1), col.darkened(0.35))
			"ring":
				var c: Vector2 = to_local(s["a"])
				var r: float = s["r"] * (0.7 + 0.3 * clampf(1.0 - left / float(s["d"]), 0.0, 1.0))
				var n2 := maxi(10, int(r * 1.6))
				for i in n2:
					var ang := TAU * i / n2
					_px(c + Vector2(cos(ang) * r, sin(ang) * r * 0.6), col)
			"path":
				for p2 in s["pts"]:
					_px(to_local(p2), col)


func _draw_rod() -> void:
	if not rod:
		return
	var n := _rod_node
	var a := n.to_local(rod_anchor)
	var b := rod_end
	n.draw_line(a, b, DARK, 4.0)
	n.draw_line(a, b, BRASS_SH, 2.0)
	n.draw_line(a + Vector2(-0.5, 0), b + Vector2(-0.5, 0), BRASS, 1.0)
	# the hub it hangs from
	n.draw_rect(Rect2(a.round() - Vector2(4, 4), Vector2(9, 9)), DARK)
	n.draw_rect(Rect2(a.round() - Vector2(3, 3), Vector2(7, 7)), BRASS_SH)
	n.draw_rect(Rect2(a.round() - Vector2(3, 3), Vector2(5, 5)), BRASS)
	n.draw_rect(Rect2(a.round() - Vector2(1, 1), Vector2(3, 3)), DARK)
