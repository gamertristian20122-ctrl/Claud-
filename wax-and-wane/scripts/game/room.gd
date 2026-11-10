class_name Room
extends Node2D
## One room on screen: background, decor and wall lights (RoomDecor), doors, obstacles (in the shared
## y-sorted layer), candelabras, spikes, cobwebs, hearths, oil jars, light occluders and grid
## collision. The room's persistent state lives in `data` (its grid is edited as things break).

const W := 272
const H := 192
const TILE := 16
const IN := Vector2(16, 32)
const COLS := 15
const ROWS := 9
const DIR_NAME := {Vector2i.UP: "top", Vector2i.DOWN: "bottom", Vector2i.LEFT: "left", Vector2i.RIGHT: "right"}
const DOOR_POS := {Vector2i.UP: Vector2(120, 0), Vector2i.DOWN: Vector2(120, 176), Vector2i.LEFT: Vector2(0, 88), Vector2i.RIGHT: Vector2(256, 88)}
## Template chars (see RoomTemplates): R rock, Q soot rock, U urn, C crate, B furniture, Z skull pile,
## O oil jar, G hearth (g = doused), X column, P pit, K candelabra.
const SOLID := ["R", "Q", "U", "C", "B", "Z", "O", "G", "g", "X", "P", "K"]
const SHOT_SOLID := ["R", "Q", "U", "C", "B", "Z", "O", "G", "g", "X", "K"]
const HP := {"U": 2, "C": 3, "B": 4, "Z": 2, "O": 1, "G": 4}
## What a bomb breaks; an oil blast is weaker and only breaks SHOT_BREAK.
const BOMB_BREAK := ["R", "Q", "U", "C", "B", "Z", "O", "G", "g"]
const SHOT_BREAK := ["U", "C", "B", "Z", "O"]
const OIL_R := 26.0
const WEB_SLOW := 0.5
const SFX_DIR := "res://assets/audio/sfx/"

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
var hidden_dirs: Array = []
var decor: RoomDecor
var webs := {}            # Vector2i -> Sprite2D
var hearths: Array[Vector2i] = []
var _fires: Array = []    # [PointLight2D, base energy, phase]
var _burn_t := 0.0
var _t := 0.0
# walker flow field toward one target cell (rebuilt when the target moves or the grid changes)
var _flow := PackedInt32Array()
var _flow_to := Vector2i(-99, -99)


func build(w: Node, c: Vector2i, d: Dictionary, th: String, neighbours: Dictionary) -> void:
	world = w
	cell = c
	data = d
	theme = th
	position = Vector2(c.x * W, c.y * H)
	var bg := Sprite2D.new()
	bg.centered = false
	if Art.has("rooms/room_" + theme):
		bg.texture = RoomDecor.background(theme, int(data["seed"]))
	elif Art.has("rooms/room_cellar"):
		bg.texture = Art.tex("rooms/room_cellar")
	else:
		bg.texture = _fallback_bg()
	bg.modulate = AREA_TINT.get(theme, Color.WHITE)   # v2.10: one set of 0x72 tiles, a tint per area
	bg.z_index = -20
	add_child(bg)
	floor_layer = Node2D.new()
	floor_layer.z_index = -15
	add_child(floor_layer)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	objects.position = position
	world.actors.add_child(objects)
	# doors
	for dir in neighbours.keys():
		var kind := "normal"
		var ntype: String = neighbours[dir]
		if ntype == "hidden":
			hidden_dirs.append(dir)
			_hollow_hint(dir)
			continue
		if ntype == "boss" or data["type"] == "boss":
			kind = "boss"
		elif ntype == "treasure" or data["type"] == "treasure":
			kind = "gold"
		elif Specials.door_style(ntype, data["type"]) != "":
			kind = Specials.door_style(ntype, data["type"])
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
	# hidden chests ($): stocked once, then the cell is plain floor
	for y in ROWS:
		for x in COLS:
			if data["grid"][y][x] == "$":
				data["grid"][y][x] = "."
				if not data.get("pocket", false):
					data["pickups"].append({"kind": "chest", "pos": cell_center(Vector2i(x, y)) + Vector2(0, 4), "item": "", "price": 0})
	data["pocket"] = true
	# obstacles
	for y in ROWS:
		for x in COLS:
			var ch: String = data["grid"][y][x]
			match ch:
				"R", "Q", "U", "C", "X", "B", "Z", "O", "G", "g":
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
				"W":
					var wb := Sprite2D.new()
					var wv: String = ["decor/prop_web", "decor/prop_web_b", "decor/prop_web_c"][posmod(x * 3 + y * 5 + int(data["seed"]), 3)]
					wb.texture = Art.tex(wv) if Art.has(wv) else Art.tex("decor/prop_web")
					wb.centered = false
					wb.position = cell_pos(Vector2i(x, y))
					wb.flip_h = (x + y) % 2 == 1
					wb.flip_v = (x * y) % 3 == 1
					floor_layer.add_child(wb)
					webs[Vector2i(x, y)] = wb
	# decor, wall lights and the floor variant
	decor = RoomDecor.new()
	add_child(decor)
	var lit_fires := 0
	for hc in hearths:
		if char_at(hc) == "G":
			lit_fires += 1
	decor.setup(self, candles.size() + lit_fires)
	AreaGimmicks.attach(self)   # the Long Night's areas: stoves, sliding shelves, lanterns... (area_gimmicks.gd)
	set_open(data["cleared"], true)
	if data["cleared"]:
		light_candles(true)
	Records.on_room(self)   # the Journal (special rooms found) + the chalk drawings in the first room


## Cracks and seeping wax mark a hollow wall.
func _hollow_hint(dir: Vector2i) -> void:
	if world and world.hud and Game.tip("hollow", 1):
		world.hud.show_hint("That wall is cracked and seeping wax... a bomb might open it", 3.0)
	var crack := Sprite2D.new()
	crack.centered = false
	crack.z_index = -11
	match dir:
		Vector2i.UP:
			crack.texture = Art.tex("0x72/wall_hole_1")
			crack.position = DOOR_POS[dir] + Vector2(8, 16)
		Vector2i.DOWN:
			crack.texture = Art.tex("rooms/decal_crack_2")
			crack.position = DOOR_POS[dir] + Vector2(8, 0)
		Vector2i.LEFT:
			crack.texture = Art.tex("rooms/decal_crack_1")
			crack.position = Vector2(4, 98)
		Vector2i.RIGHT:
			crack.texture = Art.tex("rooms/decal_crack_1")
			crack.position = Vector2(252, 98)
			crack.flip_h = true
	add_child(crack)
	var puddle := Sprite2D.new()
	puddle.texture = Art.tex("rooms/decal_wax_puddle")
	puddle.z_index = -14
	match dir:
		Vector2i.UP: puddle.position = Vector2(136, 40)
		Vector2i.DOWN: puddle.position = Vector2(136, 170)
		Vector2i.LEFT: puddle.position = Vector2(24, 106)
		Vector2i.RIGHT: puddle.position = Vector2(248, 106)
	floor_layer.add_child(puddle)


## A bomb near a hollow wall: returns its direction (or ZERO).
func reveal_near(wp: Vector2, r: float) -> Vector2i:
	var lp := wp - position
	var centres := {Vector2i.UP: Vector2(136, 28), Vector2i.DOWN: Vector2(136, 178), Vector2i.LEFT: Vector2(10, 106), Vector2i.RIGHT: Vector2(262, 106)}
	for d in hidden_dirs:
		if lp.distance_to(centres[d]) < r + 14.0:
			return d
	return Vector2i.ZERO


## Open a doorway in this room (used when a hollow wall is blown open).
func add_door(dir: Vector2i, kind := "normal") -> void:
	hidden_dirs.erase(dir)
	door_kind[dir] = kind
	var s := Sprite2D.new()
	s.centered = false
	s.position = DOOR_POS[dir]
	s.z_index = -12
	add_child(s)
	doors[dir] = s
	set_open(is_open, true)


func _fallback_bg() -> Texture2D:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color("#2a2a3a"))
	img.fill_rect(Rect2i(16, 32, 240, 144), Color("#483b3a"))
	return ImageTexture.create_from_image(img)


func cell_pos(c: Vector2i) -> Vector2:
	return IN + Vector2(c.x * TILE, c.y * TILE)


func cell_center(c: Vector2i) -> Vector2:
	return position + IN + Vector2(c.x * TILE + 8, c.y * TILE + 8)


## Themed furniture for "B": barrels in the cellar, coffins in the crypt, pews (and a lectern) in the
## chapel, fallen beams (and a cracked bell) in the belfry. Runs of B join up left to right.
func _furniture_tex(c: Vector2i) -> Texture2D:
	var l := char_at(c + Vector2i.LEFT) == "B"
	var r := char_at(c + Vector2i.RIGHT) == "B"
	var alt := posmod(c.x * 7 + c.y * 13 + int(data["seed"]), 3) == 0
	var nm := "decor/prop_barrel_b" if alt else "decor/prop_barrel"
	match theme:
		"crypt":
			nm = "decor/prop_coffin_b" if alt else "decor/prop_coffin"
		"chapel":
			var lone := "decor/prop_lectern" if posmod(c.x * 5 + c.y * 3 + int(data["seed"]), 4) == 0 else "decor/prop_kneeler"
			nm = "decor/prop_pew_m" if l and r else ("decor/prop_pew_l" if r else ("decor/prop_pew_r" if l else lone))
		"belfry":
			nm = "decor/prop_beam_m" if l and r else ("decor/prop_beam_l" if r else ("decor/prop_beam_r" if l else "decor/prop_bell"))
		"tower":
			nm = "decor/prop_tower_case" if alt or not (l or r) else "decor/prop_tower_crate"
	return Art.tex(nm) if Art.has(nm) else Art.tex("0x72/crate")


func _obstacle_tex(c: Vector2i, ch: String) -> Texture2D:
	var area_tex := AreaGimmicks.obstacle_tex(self, c, ch)   # the areas' furniture, crates and boiling pots
	if area_tex:
		return area_tex
	match ch:
		"R": return Art.tex("rooms/rock" if (c.x + c.y) % 3 != 0 or not Art.has("rooms/rock_b") else "rooms/rock_b")
		"Q": return Art.tex("decor/prop_soot_rock")
		"U": return Art.tex("rooms/urn")
		"C": return Art.tex("0x72/crate")
		"X": return Art.tex("0x72/column")
		"B": return _furniture_tex(c)
		"Z": return Art.tex("decor/prop_skull_pile")
		"O": return Art.tex("decor/prop_oil_jar")
		"G": return Art.tex("decor/prop_hearth")
		"g": return Art.tex("decor/prop_hearth_cold")
	return Art.tex("rooms/rock")


func _add_obstacle(c: Vector2i, ch: String) -> void:
	var holder := Node2D.new()
	holder.position = cell_pos(c) + Vector2(8, 16)   # feet = bottom centre of the tile
	var s := Sprite2D.new()
	s.centered = false
	var t := _obstacle_tex(c, ch)
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
	if ch == "G" or ch == "g":
		hearths.append(c)
		if ch == "G":
			_light_hearth(holder, c)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-7, -13), Vector2(7, -13), Vector2(7, -2), Vector2(-7, -2)])
	occ.occluder = poly
	holder.add_child(occ)
	objects.add_child(holder)
	obstacle_nodes[c] = holder
	if HP.has(ch):
		obstacle_hp[c] = HP[ch]


func _light_hearth(holder: Node2D, c: Vector2i) -> void:
	var f := AnimatedSprite2D.new()
	f.name = "Fire"
	f.sprite_frames = Art.anim("decor/fire", 10.0)
	f.centered = false
	f.position = Vector2(-5, -17)
	f.material = Art.unshaded
	f.play("default")
	f.frame = posmod(c.x + c.y * 3, 4)
	holder.add_child(f)
	var l := PointLight2D.new()
	l.name = "Glow"
	l.texture = Art.light_tex
	l.color = Color(1.0, 0.56, 0.26)
	l.energy = 0.95
	l.texture_scale = 0.55
	l.position = Vector2(0, -12)
	holder.add_child(l)
	Lighting.haze(holder, Vector2(-6, -29), Vector2(12, 14), l)
	_fires.append([l, 0.95, float(c.x * 1.3 + c.y)])
	# a few sparks lift off the coals
	var em := CPUParticles2D.new()
	em.name = "Embers"
	em.amount = 4
	em.lifetime = 0.9
	em.position = Vector2(0, -14)
	em.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	em.emission_rect_extents = Vector2(4, 1)
	em.direction = Vector2(0, -1)
	em.spread = 22.0
	em.gravity = Vector2(0, -8)
	em.initial_velocity_min = 9.0
	em.initial_velocity_max = 17.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color("#facb3e"))
	ramp.set_color(1, Color("#da4e38"))
	em.color_ramp = ramp
	em.material = Art.unshaded
	em.seed = int(data["seed"]) + c.x * 17 + c.y
	em.use_fixed_seed = true
	holder.add_child(em)


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


## v2.10: the rooms are 0x72's tiles as drawn; an area is told by its tint, a special door by its colour.
const AREA_TINT := {"cellar": Color(1.0, 0.93, 0.84), "crypt": Color(0.78, 0.88, 1.0), "chapel": Color(0.92, 0.8, 1.0),
	"belfry": Color(1.0, 0.84, 0.7), "kitchen": Color(1.0, 0.95, 0.78), "library": Color(0.9, 0.82, 0.7),
	"attic": Color(0.84, 0.86, 0.96), "tower": Color(0.9, 0.92, 0.78)}
const DOOR_TINT := {"boss": Color(1.0, 0.5, 0.45), "gold": Color(1.0, 0.86, 0.4), "seance": Color(0.72, 0.6, 1.0),
	"mirror": Color(0.6, 0.85, 1.0), "musicbox": Color(1.0, 0.62, 0.85), "study": Color(0.62, 1.0, 0.7),
	"font": Color(0.55, 1.0, 0.95)}


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
		elif kind != "normal" and Art.has("specials/door_%s_%s_%s" % [nm, kind, state]):
			path = "specials/door_%s_%s_%s" % [nm, kind, state]
		doors[dir].texture = Art.tex(path)
		doors[dir].modulate = DOOR_TINT.get(kind, Color.WHITE)   # v2.10: one door drawing, a tint per kind
	if not instant:
		Audio.play("door_open" if open else "door_close", -2.0)


func _process(dt: float) -> void:
	_t += dt
	for F in _fires:
		var l: PointLight2D = F[0]
		if is_instance_valid(l):
			l.energy = F[1] * (1.0 + 0.16 * sin(_t * 9.1 + F[2]) + 0.08 * sin(_t * 15.7 + F[2] * 2.0))
	if not hearths.is_empty():
		_hearth_touch(dt)
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


## A lit hearth burns whoever touches it (player: like spikes; foes: a slow sizzle).
func _hearth_touch(dt: float) -> void:
	if world == null or world.room != self or world.player == null:
		return
	_burn_t -= dt
	var sizzle := _burn_t <= 0.0
	if sizzle:
		_burn_t = 0.5
	for c in hearths:
		if char_at(c) != "G":
			continue
		var rect := Rect2(position + IN + Vector2(c.x * TILE + 1, c.y * TILE + 2), Vector2(TILE - 2, TILE - 3)).grow(2.5)
		var p: Player = world.player
		if not p.dead and _touches(rect, p.global_position, Player.RADIUS):
			Records.blame("hearth")
			p.hurt(4.0, p.global_position - cell_center(c))
		if sizzle:
			for e in world.enemies:
				if is_instance_valid(e) and e.alive and e.active and not e.flying and _touches(rect, e.global_position, e.radius):
					e.take_hit(0.8, (e.global_position - cell_center(c)).normalized() * 40.0)


static func _touches(rect: Rect2, p: Vector2, r: float) -> bool:
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return q.distance_squared_to(p) < r * r


# ---------------------------------------------------------------- collision

func cell_of(lp: Vector2) -> Vector2i:
	return Vector2i(floori((lp.x - IN.x) / TILE), floori((lp.y - IN.y) / TILE))


func char_at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return "#"
	return data["grid"][c.y][c.x]


## Steering for walkers: the direction to walk from `from_wp` to reach `to_wp`. Straight at it when
## nothing solid is in between, otherwise along the shortest path round rocks, pits and furniture
## (a breadth-first flow field over the grid, cached per target cell).
func path_dir(from_wp: Vector2, to_wp: Vector2) -> Vector2:
	var d := to_wp - from_wp
	if d.length_squared() < 1.0:
		return Vector2.ZERO
	if _clear_line(from_wp, to_wp):
		return d.normalized()
	var fc := _clamp_cell(cell_of(from_wp - position))
	var tc := _clamp_cell(cell_of(to_wp - position))
	if tc != _flow_to:
		_build_flow(tc)
	var best := fc
	var bd: int = _flow[fc.y * COLS + fc.x]
	for k in 8:
		var o: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)][k]
		var n := fc + o
		if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS:
			continue
		if o.x != 0 and o.y != 0 and (char_at(Vector2i(fc.x + o.x, fc.y)) in SOLID or char_at(Vector2i(fc.x, fc.y + o.y)) in SOLID):
			continue   # no cutting corners
		var v: int = _flow[n.y * COLS + n.x]
		if v >= 0 and (bd < 0 or v < bd):
			bd = v
			best = n
	if best == fc:
		return d.normalized()
	return (cell_center(best) + Vector2(0, 4) - from_wp).normalized()


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 0, COLS - 1), clampi(c.y, 0, ROWS - 1))


## Nothing solid along the segment (sampled every 6 px).
func _clear_line(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 6.0) + 1
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n) - position
		if char_at(cell_of(p)) in SOLID:
			return false
	return true


func _build_flow(target: Vector2i) -> void:
	_flow_to = target
	_flow.resize(COLS * ROWS)
	_flow.fill(-1)
	_flow[target.y * COLS + target.x] = 0
	var q: Array[Vector2i] = [target]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var v: int = _flow[c.y * COLS + c.x]
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS or _flow[n.y * COLS + n.x] >= 0:
				continue
			if char_at(n) in SOLID:
				continue
			_flow[n.y * COLS + n.x] = v + 1
			q.append(n)


## Speed factor for a walker at world position `wp` (cobwebs halve it).
func slow_at(wp: Vector2) -> float:
	return WEB_SLOW if char_at(cell_of(wp - position)) == "W" else 1.0


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
## Player embers (`friendly`) burn cobwebs as they fly through them.
func shot_hits(wp: Vector2, dmg: float, friendly := true) -> bool:
	if AreaGimmicks.shot_at(self, wp, dmg, friendly):   # flour clouds, hush rings, lanterns, dust sheets, shelf-doors
		return true
	var lp := wp - position
	if lp.x < IN.x or lp.x > IN.x + COLS * TILE or lp.y < IN.y - 4 or lp.y > IN.y + ROWS * TILE:
		return true
	var c := cell_of(lp)
	var ch := char_at(c)
	if ch == "W":
		if friendly:
			burn_web(c)
		return false
	if ch in SHOT_SOLID:
		var rect := Rect2(IN + Vector2(c.x * TILE + 2, c.y * TILE + 2), Vector2(TILE - 4, TILE - 3))
		if rect.has_point(lp):
			if obstacle_hp.has(c):
				damage_obstacle(c, dmg)
			elif friendly and c == Specials.PROP_CELL and Specials.is_special(data.get("type", "")):
				Specials.prop_shot(self, c)
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
		if char_at(c) == "G":
			douse_hearth(c)
		else:
			break_obstacle(c)


## Shots put a hearth out: it stays (cold, still in the way) and sometimes gives something up.
func douse_hearth(c: Vector2i) -> void:
	if char_at(c) != "G":
		return
	data["grid"][c.y][c.x] = "g"
	obstacle_hp.erase(c)
	var node: Node2D = obstacle_nodes.get(c)
	var wp := cell_center(c)
	if node:
		(node.get_child(0) as Sprite2D).texture = Art.tex("decor/prop_hearth_cold")
		for nm in ["Fire", "Embers"]:
			var f := node.get_node_or_null(nm)
			if f:
				f.queue_free()
		var l: PointLight2D = node.get_node_or_null("Glow")
		if l:
			for F in _fires:
				if F[0] == l:
					_fires.erase(F)
					break
			var tw := l.create_tween()
			tw.tween_property(l, "energy", 0.0, 0.4)
			tw.tween_callback(l.queue_free)
	_snd("hearth_out", "snuff_out", -4.0, 0.08, 1.2)
	if world:
		world.fx_smoke(wp + Vector2(0, -10))
		world.fx_smoke(wp + Vector2(3, -14))
		var r: float = world.rng.randf()
		if r < 0.3:
			world.add_pickup("wax_small", wp + Vector2(0, 8))
		elif r < 0.5:
			world.add_pickup("coin", wp + Vector2(0, 8), "", 0, Vector2.from_angle(world.rng.randf() * TAU) * 30.0)


func break_obstacle(c: Vector2i) -> void:
	var ch := char_at(c)
	if not ch in BOMB_BREAK:
		return
	data["grid"][c.y][c.x] = "."
	_flow_to = Vector2i(-99, -99)
	obstacle_hp.erase(c)
	var node: Node2D = obstacle_nodes.get(c)
	obstacle_nodes.erase(c)
	var wp := cell_center(c)
	var waxy: bool = node != null and node.get_meta("waxy", false)
	if node:
		var l: PointLight2D = node.get_node_or_null("Glow")
		if l:
			for F in _fires:
				if F[0] == l:
					_fires.erase(F)
					break
		node.queue_free()
	if waxy and world:
		world.add_pickup("wax_big" if world.rng.randf() < 0.6 else "chest", wp + Vector2(0, 4))
	match ch:
		"U":
			if AreaGimmicks.urn_broken(self, c):   # a kitchen's boiling pot spills instead
				pass
			else:
				Audio.play("urn_break")
				if Art.has("rooms/urn_broken"):
					var s := Sprite2D.new()
					s.texture = Art.tex("rooms/urn_broken")
					s.position = cell_pos(c) + Vector2(8, 8)
					floor_layer.add_child(s)
		"C":
			Audio.play("crate_break")
		"B":
			_snd("furniture_break", "crate_break", 0.0, 0.08, 0.85)
			for d in [Vector2i.LEFT, Vector2i.RIGHT]:
				_retile(c + d)
		"Z":
			_snd("bones_break", "urn_break", -2.0, 0.1, 1.35)
			var b := Sprite2D.new()
			b.texture = Art.tex("rooms/decal_bones")
			b.position = cell_pos(c) + Vector2(8, 10)
			floor_layer.add_child(b)
		"R", "Q":
			Audio.play("hit_wall", 2.0, 0.1, 0.6)
		"G", "g":
			_snd("furniture_break", "crate_break", -2.0, 0.08, 0.6)
		"O":
			_oil_blast(c)
	if world:
		world.fx_debris(wp, "C" if ch in ["B", "O"] else ("U" if ch == "Z" else ch))
		if ch == "Q":
			world.add_pickup("bomb", wp + Vector2(0, 4))
			world.fx_text(wp + Vector2(0, -16), "a bomb in the soot!", UI.GOLD)
		elif ch in ["U", "C", "B", "Z"]:
			world.roll_obstacle_drop(wp)


## A broken piece of furniture leaves its neighbours with open ends.
func _retile(c: Vector2i) -> void:
	if char_at(c) != "B" or not obstacle_nodes.has(c):
		return
	var spr := (obstacle_nodes[c] as Node2D).get_child(0) as Sprite2D
	if spr:
		spr.texture = _furniture_tex(c)


## Oil jars burst in a small fireball: hurts everything close, breaks light things, sets off other jars.
func _oil_blast(c: Vector2i) -> void:
	if world == null:
		return
	var wp := cell_center(c) + Vector2(0, 2)
	_snd("oil_blast", "explosion", -3.0, 0.1, 1.3)
	world.shake(3.5)
	Game.vibrate(40)
	var ex := AnimatedSprite2D.new()
	ex.sprite_frames = Art.anim("fx/explosion", 20.0, false)
	ex.position = wp + Vector2(0, -10)
	ex.material = Art.unshaded
	world.fx_layer.add_child(ex)
	ex.play("default")
	ex.animation_finished.connect(ex.queue_free)
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(1.0, 0.55, 0.25)
	l.energy = 1.3
	l.texture_scale = 0.7
	ex.add_child(l)
	var lt := l.create_tween()
	lt.tween_property(l, "energy", 0.0, 0.35)
	if Art.has("fx/scorch"):
		var sc := Sprite2D.new()
		sc.texture = Art.tex("fx/scorch")
		sc.position = wp - position
		sc.modulate.a = 0.8
		floor_layer.add_child(sc)
	for e in world.enemies:
		if is_instance_valid(e) and e.alive and e.global_position.distance_to(wp) < OIL_R + e.radius:
			e.active = true
			e.take_hit(4.0 + 1.5 * (world.depth() if world.has_method("depth") else float(world.floor_num)), (e.global_position - wp).normalized() * 130.0)
	var p: Player = world.player
	if p and not p.dead and p.global_position.distance_to(wp) < OIL_R * 0.8:
		Records.blame("oil")
		p.hurt(5.0, p.global_position - wp)
	var tw := create_tween()
	tw.tween_interval(0.1)
	tw.tween_callback(blast.bind(wp, OIL_R, false))


## Embers, bombs and blasts burn cobwebs away.
func burn_web(c: Vector2i) -> void:
	if char_at(c) != "W":
		return
	data["grid"][c.y][c.x] = "."
	var s: Sprite2D = webs.get(c)
	webs.erase(c)
	if s:
		var tw := s.create_tween()
		tw.tween_property(s, "modulate", Color(1.0, 0.55, 0.25, 0.0), 0.25)
		tw.tween_callback(s.queue_free)
	if world:
		world.fx_poof(cell_center(c) + Vector2(0, -2), true, 1.0)
	_snd("web_burn", "tick", -6.0, 0.2, 0.7)


## Bombs: break everything breakable in a radius. `strong` = false for oil blasts (light things only).
func blast(wp: Vector2, radius: float, strong := true) -> void:
	var lp := wp - position
	for c in obstacle_nodes.keys().duplicate():
		if not obstacle_nodes.has(c):
			continue
		var cc: Vector2 = IN + Vector2(c.x * TILE + 8, c.y * TILE + 8)
		var ch := char_at(c)
		if cc.distance_to(lp) <= radius + 6 and ((strong and ch in BOMB_BREAK) or (not strong and ch in SHOT_BREAK)):
			break_obstacle(c)
	for c in webs.keys().duplicate():
		var cw: Vector2 = IN + Vector2(c.x * TILE + 8, c.y * TILE + 8)
		if cw.distance_to(lp) <= radius + 8:
			burn_web(c)


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


## Plays `n` if the audio stream has made it, otherwise an existing stand-in.
func _snd(n: String, fallback: String, db := 0.0, jitter := 0.06, pitch := 1.0) -> void:
	var have := ResourceLoader.exists(SFX_DIR + n + ".ogg") or ResourceLoader.exists(SFX_DIR + n + ".wav")
	Audio.play(n if have else fallback, db, jitter, pitch)


func dispose() -> void:
	if is_instance_valid(objects):
		objects.queue_free()
	queue_free()
