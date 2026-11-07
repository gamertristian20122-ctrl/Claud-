class_name Room
extends Node2D
## One room on screen: background, doors, obstacles (in the shared y-sorted layer), candelabras,
## spikes, light occluders and grid collision. The room's persistent state lives in `data`.

const W := 272
const H := 192
const TILE := 16
const IN := Vector2(16, 32)
const COLS := 15
const ROWS := 9
const DIR_NAME := {Vector2i.UP: "top", Vector2i.DOWN: "bottom", Vector2i.LEFT: "left", Vector2i.RIGHT: "right"}
const DOOR_POS := {Vector2i.UP: Vector2(120, 0), Vector2i.DOWN: Vector2(120, 176), Vector2i.LEFT: Vector2(0, 88), Vector2i.RIGHT: Vector2(256, 88)}
const SOLID := ["R", "U", "C", "X", "P", "K"]
const SHOT_SOLID := ["R", "U", "C", "X", "K"]
const HP := {"U": 2, "C": 3}

var world: Node
var cell: Vector2i
var data: Dictionary
var theme := "cellar"
var objects: Node2D
var doors := {}
var door_kind := {}
var candles: Array = []
var obstacle_nodes := {}
var obstacle_hp := {}
var spikes: Array = []
var spike_t := 0.0
var spikes_up := true
var is_open := true
var floor_layer: Node2D


func build(w: Node, c: Vector2i, d: Dictionary, th: String, neighbours: Dictionary) -> void:
	world = w
	cell = c
	data = d
	theme = th
	position = Vector2(c.x * W, c.y * H)
	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = Art.tex("rooms/room_" + theme) if Art.has("rooms/room_" + theme) else Art.tex("rooms/room_cellar")
	if not Art.has("rooms/room_cellar"):
		bg.texture = _fallback_bg()
	bg.z_index = -20
	add_child(bg)
	floor_layer = Node2D.new()
	floor_layer.z_index = -15
	add_child(floor_layer)
	_decals()
	objects = Node2D.new()
	objects.y_sort_enabled = true
	objects.position = position
	world.actors.add_child(objects)
	# doors
	for dir in neighbours.keys():
		var kind := "normal"
		var ntype: String = neighbours[dir]
		if ntype == "boss" or data["type"] == "boss":
			kind = "boss"
		elif ntype == "treasure" or data["type"] == "treasure":
			kind = "gold"
		door_kind[dir] = kind
		var s := Sprite2D.new()
		s.centered = false
		s.position = DOOR_POS[dir]
		s.z_index = -12
		add_child(s)
		doors[dir] = s
	# candelabras in the corners (they light up when the room is cleared)
	var spots := [Vector2i(0, 0), Vector2i(14, 0)]
	if data["type"] == "boss":
		spots += [Vector2i(0, 8), Vector2i(14, 8)]
	for sp in spots:
		var cch: String = data["grid"][sp.y][sp.x]
		if cch == "." or cch == "K":
			data["grid"][sp.y][sp.x] = "K"
			_add_candelabra(sp)
	# obstacles
	for y in ROWS:
		for x in COLS:
			var ch: String = data["grid"][y][x]
			match ch:
				"R", "U", "C", "X":
					_add_obstacle(Vector2i(x, y), ch)
				"P":
					var p := Sprite2D.new()
					p.centered = false
					# autotile: pick the pit piece by which neighbours are pits too (N=1 E=2 S=4 W=8)
					var mask := 0
					for k in 4:
						var nb: Vector2i = Vector2i(x, y) + [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][k]
						if char_at(nb) == "P":
							mask |= 1 << k
					var pit_path := "rooms/pit_%d" % mask
					p.texture = Art.tex(pit_path) if Art.has(pit_path) else (Art.tex("rooms/pit") if Art.has("rooms/pit") else Art.tex("0x72/hole"))
					p.position = cell_pos(Vector2i(x, y))
					floor_layer.add_child(p)
				"S":
					var s := AnimatedSprite2D.new()
					s.sprite_frames = Art.anim("0x72/floor_spikes_anim", 12.0, false)
					s.centered = false
					s.position = cell_pos(Vector2i(x, y))
					s.frame = 3
					floor_layer.add_child(s)
					spikes.append(s)
	set_open(data["cleared"], true)
	if data["cleared"]:
		light_candles(true)


func _fallback_bg() -> Texture2D:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color("#2a2a3a"))
	img.fill_rect(Rect2i(16, 32, 240, 144), Color("#483b3a"))
	return ImageTexture.create_from_image(img)


func _decals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data["seed"])
	var names := ["decal_crack_0", "decal_crack_1", "decal_crack_2", "decal_crack_3", "decal_cobweb", "decal_bones", "decal_wax_puddle"]
	for i in rng.randi_range(1, 4):
		var n: String = names[rng.randi() % names.size()]
		if not Art.has("rooms/" + n):
			continue
		var s := Sprite2D.new()
		s.texture = Art.tex("rooms/" + n)
		s.position = IN + Vector2(rng.randi_range(1, 14) * 16, rng.randi_range(1, 8) * 16)
		if n == "decal_cobweb":
			s.position = IN + Vector2([8.0, 232.0][rng.randi() % 2], 8)
			s.flip_h = s.position.x > 100
		s.modulate.a = 0.85
		floor_layer.add_child(s)


func cell_pos(c: Vector2i) -> Vector2:
	return IN + Vector2(c.x * TILE, c.y * TILE)


func cell_center(c: Vector2i) -> Vector2:
	return position + IN + Vector2(c.x * TILE + 8, c.y * TILE + 8)


func _add_obstacle(c: Vector2i, ch: String) -> void:
	var holder := Node2D.new()
	holder.position = cell_pos(c) + Vector2(8, 16)   # feet = bottom centre of the tile
	var s := Sprite2D.new()
	s.centered = false
	var t: Texture2D
	match ch:
		"R": t = Art.tex("rooms/rock" if (c.x + c.y) % 3 != 0 or not Art.has("rooms/rock_b") else "rooms/rock_b")
		"U": t = Art.tex("rooms/urn")
		"C": t = Art.tex("0x72/crate")
		"X": t = Art.tex("0x72/column")
	s.texture = t
	s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	if ch == "X":
		s.offset.y += 9   # the column sprite has empty rows below its base
	holder.add_child(s)
	if ch == "R":
		var rr := RandomNumberGenerator.new()
		rr.seed = int(data["seed"]) + c.x * 31 + c.y * 7
		if rr.randf() < 0.14:
			holder.set_meta("waxy", true)
			var drip := Sprite2D.new()
			drip.texture = Art.tex("rooms/decal_wax_puddle") if Art.has("rooms/decal_wax_puddle") else Art.tex("pickups/wax_small")
			drip.position = Vector2(0, -9)
			holder.add_child(drip)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-7, -13), Vector2(7, -13), Vector2(7, -2), Vector2(-7, -2)])
	occ.occluder = poly
	holder.add_child(occ)
	objects.add_child(holder)
	obstacle_nodes[c] = holder
	if HP.has(ch):
		obstacle_hp[c] = HP[ch]


func _add_candelabra(c: Vector2i) -> void:
	var holder := Node2D.new()
	holder.position = cell_pos(c) + Vector2(8, 15)
	var s := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.add_animation("off")
	sf.add_frame("off", Art.tex("rooms/candelabra_unlit"))
	sf.add_animation("on")
	sf.set_animation_speed("on", 7.0)
	for t in Art.seq("rooms/candelabra_lit"):
		sf.add_frame("on", t)
	s.sprite_frames = sf
	s.animation = "off"
	s.centered = false
	var tex: Texture2D = sf.get_frame_texture("off", 0)
	s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	holder.add_child(s)
	var light := PointLight2D.new()
	light.texture = Art.light_tex
	light.color = Color(1.0, 0.72, 0.42)
	light.energy = 0.0
	light.enabled = false
	light.texture_scale = 0.9
	light.position = Vector2(0, -20)
	holder.add_child(light)
	objects.add_child(holder)
	candles.append([s, light])


func light_candles(instant := false) -> void:
	var i := 0
	for pair in candles:
		var s: AnimatedSprite2D = pair[0]
		var l: PointLight2D = pair[1]
		l.enabled = true
		if instant:
			s.play("on")
			l.energy = 0.75
		else:
			var tw := create_tween()
			tw.tween_interval(0.25 + i * 0.22)
			tw.tween_callback(func():
				s.play("on")
				Audio.play("tick", -4.0, 0.1, 1.6)
				if world and world.has_method("fx_smoke"):
					world.fx_smoke(s.global_position + Vector2(0, -22)))
			tw.tween_property(l, "energy", 0.75, 0.5)
		i += 1


func set_open(open: bool, instant := false) -> void:
	if open == is_open and not instant:
		return
	is_open = open
	for dir in doors.keys():
		var kind: String = door_kind[dir]
		var nm: String = DIR_NAME[dir]
		var state := "open" if open else "closed"
		var path := "rooms/door_%s_%s" % [nm, state]
		if kind != "normal" and Art.has("rooms/door_%s_%s_%s" % [nm, kind, state]):
			path = "rooms/door_%s_%s_%s" % [nm, kind, state]
		doors[dir].texture = Art.tex(path)
	if not instant:
		Audio.play("door_open" if open else "door_close", -2.0)


func _process(dt: float) -> void:
	if spikes.is_empty():
		return
	spike_t += dt
	var period := 2.4
	var ph := fmod(spike_t, period)
	var up := ph < period * 0.55
	if not up and ph > period - 0.3:
		for s in spikes:
			s.frame = 1   # rattle: they are about to come up
	if up != spikes_up:
		spikes_up = up
		for s in spikes:
			if up:
				s.play("default")
			else:
				s.play_backwards("default")


# ---------------------------------------------------------------- collision

func cell_of(lp: Vector2) -> Vector2i:
	return Vector2i(floori((lp.x - IN.x) / TILE), floori((lp.y - IN.y) / TILE))


func char_at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return "#"
	return data["grid"][c.y][c.x]


## Is a circle at world position `wp` blocked? Door gaps count as open floor when `doors_ok`.
func blocked(wp: Vector2, r: float, flying := false, doors_ok := false) -> bool:
	var lp := wp - position
	var in_gap := false
	if doors_ok and is_open:
		for dir in doors.keys():
			if _in_gap(lp, dir, r):
				in_gap = true
	if not in_gap:
		if lp.x < IN.x + r or lp.x > IN.x + COLS * TILE - r or lp.y < IN.y + r * 0.6 or lp.y > IN.y + ROWS * TILE - r * 0.4:
			return true
	else:
		return false
	if flying:
		return false
	var c0 := cell_of(lp - Vector2(r, r))
	var c1 := cell_of(lp + Vector2(r, r))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var ch := char_at(Vector2i(cx, cy))
			if ch in SOLID:
				var rect := Rect2(IN + Vector2(cx * TILE + 1, cy * TILE + 2), Vector2(TILE - 2, TILE - 3))
				var closest := Vector2(clampf(lp.x, rect.position.x, rect.end.x), clampf(lp.y, rect.position.y, rect.end.y))
				if closest.distance_squared_to(lp) < r * r:
					return true
	return false


func _in_gap(lp: Vector2, dir: Vector2i, r: float) -> bool:
	match dir:
		Vector2i.UP: return absf(lp.x - 136.0) <= 9.0 - r * 0.2 and lp.y < IN.y + 12 and lp.y > 4
		Vector2i.DOWN: return absf(lp.x - 136.0) <= 9.0 - r * 0.2 and lp.y > IN.y + ROWS * TILE - 12 and lp.y < H - 2
		Vector2i.LEFT: return absf(lp.y - 106.0) <= 9.0 - r * 0.2 and lp.x < IN.x + 12 and lp.x > 2
		Vector2i.RIGHT: return absf(lp.y - 106.0) <= 9.0 - r * 0.2 and lp.x > IN.x + COLS * TILE - 12 and lp.x < W - 2
	return false


## Which door (if any) the world position is walking through.
func door_exit(wp: Vector2) -> Vector2i:
	if not is_open:
		return Vector2i.ZERO
	var lp := wp - position
	for dir in doors.keys():
		match dir:
			Vector2i.UP:
				if lp.y < IN.y - 3 and absf(lp.x - 136.0) < 12:
					return dir
			Vector2i.DOWN:
				if lp.y > IN.y + ROWS * TILE + 3 and absf(lp.x - 136.0) < 12:
					return dir
			Vector2i.LEFT:
				if lp.x < IN.x - 3 and absf(lp.y - 106.0) < 12:
					return dir
			Vector2i.RIGHT:
				if lp.x > IN.x + COLS * TILE + 3 and absf(lp.y - 106.0) < 12:
					return dir
	return Vector2i.ZERO


## Where the player appears when entering through `from_dir` (the side they came in from).
func entry_point(from_dir: Vector2i) -> Vector2:
	match from_dir:
		Vector2i.UP: return position + Vector2(136, IN.y + 10)
		Vector2i.DOWN: return position + Vector2(136, IN.y + ROWS * TILE - 6)
		Vector2i.LEFT: return position + Vector2(IN.x + 10, 110)
		Vector2i.RIGHT: return position + Vector2(IN.x + COLS * TILE - 10, 110)
	return center()


func center() -> Vector2:
	return position + Vector2(136, 104)


func inner_rect() -> Rect2:
	return Rect2(position + IN, Vector2(COLS * TILE, ROWS * TILE))


## A shot at world position: returns true when it hits something solid (and damages breakables).
func shot_hits(wp: Vector2, dmg: float) -> bool:
	var lp := wp - position
	if lp.x < IN.x or lp.x > IN.x + COLS * TILE or lp.y < IN.y - 4 or lp.y > IN.y + ROWS * TILE:
		return true
	var c := cell_of(lp)
	var ch := char_at(c)
	if ch in SHOT_SOLID:
		var rect := Rect2(IN + Vector2(c.x * TILE + 2, c.y * TILE + 2), Vector2(TILE - 4, TILE - 3))
		if rect.has_point(lp):
			if obstacle_hp.has(c):
				damage_obstacle(c, dmg)
			return true
	return false


func damage_obstacle(c: Vector2i, dmg: float) -> void:
	if not obstacle_hp.has(c):
		return
	obstacle_hp[c] -= 1 if dmg < 99 else 99
	var node: Node2D = obstacle_nodes.get(c)
	if node:
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector2(1.15, 0.85), 0.05)
		tw.tween_property(node, "scale", Vector2.ONE, 0.08)
	if obstacle_hp[c] <= 0:
		break_obstacle(c)


func break_obstacle(c: Vector2i) -> void:
	var ch := char_at(c)
	if ch == "#" or ch == "." or ch == "X" or ch == "K" or ch == "P":
		return
	data["grid"][c.y][c.x] = "."
	obstacle_hp.erase(c)
	var node: Node2D = obstacle_nodes.get(c)
	obstacle_nodes.erase(c)
	var wp := cell_center(c)
	var waxy: bool = node != null and node.get_meta("waxy", false)
	if node:
		node.queue_free()
	if waxy and world:
		world.add_pickup("wax_big" if world.rng.randf() < 0.6 else "chest", wp + Vector2(0, 4))
	match ch:
		"U":
			Audio.play("urn_break")
			if Art.has("rooms/urn_broken"):
				var s := Sprite2D.new()
				s.texture = Art.tex("rooms/urn_broken")
				s.position = cell_pos(c) + Vector2(8, 8)
				floor_layer.add_child(s)
		"C":
			Audio.play("crate_break")
		"R":
			Audio.play("hit_wall", 2.0, 0.1, 0.6)
	if world:
		world.fx_debris(wp, ch)
		if ch != "R":
			world.roll_obstacle_drop(wp)


## Bombs: break everything breakable in a radius.
func blast(wp: Vector2, radius: float) -> void:
	var lp := wp - position
	for c in obstacle_nodes.keys().duplicate():
		var cc: Vector2 = IN + Vector2(c.x * TILE + 8, c.y * TILE + 8)
		if cc.distance_to(lp) <= radius + 6 and char_at(c) in ["R", "U", "C"]:
			break_obstacle(c)


func spike_hurts(wp: Vector2) -> bool:
	if spikes.is_empty() or not spikes_up or fmod(spike_t, 2.4) < 0.3:
		return false
	return char_at(cell_of(wp - position)) == "S"


## Spawn slots for enemies ("e", "h", "f", "T") as [letter, world position].
func spawn_slots() -> Array:
	var out := []
	for y in ROWS:
		for x in COLS:
			var ch: String = data["grid"][y][x]
			if ch in ["e", "h", "f", "T"]:
				out.append([ch, cell_center(Vector2i(x, y)) + Vector2(0, 6)])
	return out


func dispose() -> void:
	if is_instance_valid(objects):
		objects.queue_free()
	queue_free()
