class_name RoomDecor
extends Node2D
## Hand-placed-looking detail for one room: the floor variant, wall pieces (shelves, niches, windows,
## clocks...), wall lights with a warm flicker, chapel window light pools and flat floor decals.
## Everything is chosen from the room's own seed, so a seed (and Tonight's Candle) always dresses a
## room the same way. Static pieces are drawn in one canvas item (`_draw`); only flames, glass and
## lights are separate nodes. Art: tools/art_decor.py -> assets/art/decor/.

const LIGHT_BUDGET := 6          # static lights per room, candelabras and hearths included
const TOP_TILES := [1, 2, 3, 4, 5, 9, 10, 11, 12, 13]   # top wall face tiles clear of corners and the top door
const SIDE_Y := [40, 136]        # side wall slots (y of a 16 px piece), away from the side doors (88..120)

## theme -> sconce look: flame kind, flame spots (in the mount sprite), light colour, energy, scale
const SCONCE := {
	"cellar": {"flame": "torch", "top": [Vector2(8, 6)], "side": [Vector2(6, 3)], "col": Color(1.0, 0.6, 0.3), "e": 0.95, "s": 0.62},
	"crypt": {"flame": "glass", "top": [Vector2(8, 10)], "side": [Vector2(5, 10)], "col": Color(0.95, 0.78, 0.52), "e": 0.8, "s": 0.55},
	"chapel": {"flame": "candle", "top": [Vector2(8, 4)], "side": [Vector2(6, 4)], "col": Color(1.0, 0.74, 0.45), "e": 0.8, "s": 0.55},
	"belfry": {"flame": "glass", "top": [Vector2(8, 9)], "side": [Vector2(5, 8)], "col": Color(1.0, 0.66, 0.36), "e": 0.9, "s": 0.6},
}
## theme -> top wall pieces: [name, width in tiles, x offset, y]. The first is the theme's signature
## piece and is tried first in most rooms.
const WALL := {
	"cellar": [["wall_shelf", 2, 0, 16], ["wall_herbs", 1, 0, 16], ["wall_winerack", 2, 0, 16], ["wall_herbs", 1, 0, 16]],
	"crypt": [["wall_niche_skull", 1, 0, 16], ["wall_niche_urn", 1, 0, 16], ["wall_niche_candle", 1, 0, 16],
		["wall_chains", 1, 0, 16], ["wall_niche_skull", 1, 0, 16]],
	"chapel": [["wall_banner_torn", 1, 0, 16], ["wall_votives", 2, 0, 16], ["wall_banner_torn", 1, 0, 16]],
	"belfry": [["wall_clock", 2, 4, 10], ["wall_gear", 1, 0, 16], ["wall_rope", 1, 4, 10], ["wall_gear", 1, 0, 16]],
}
const SIDE := {"cellar": "side_herbs", "crypt": "side_chains", "chapel": "side_banner", "belfry": "side_rope"}
const CORNER_WEBS := ["cellar", "crypt"]
## theme -> flat floor decals (any floor cell) and wall-foot decals (row 0, leaning on the top wall)
const FLOOR := {
	"cellar": ["decor/floor_straw_0", "decor/floor_straw_1", "decor/floor_puddle", "decor/floor_grain", "rooms/decal_crack_0", "rooms/decal_crack_1"],
	"crypt": ["decor/floor_ribs", "decor/floor_bone_bits", "rooms/decal_bones", "decor/floor_slab", "rooms/decal_crack_2", "rooms/decal_crack_3", "decor/floor_bone_bits"],
	"chapel": ["decor/floor_pages_0", "decor/floor_pages_1", "decor/floor_book", "rooms/decal_crack_1", "decor/floor_pages_1"],
	"belfry": ["decor/floor_feathers_0", "decor/floor_feathers_1", "decor/floor_cog", "decor/floor_rope_coil", "rooms/decal_crack_0", "decor/floor_feathers_0"],
}
const FOOT := {"cellar": ["decor/floor_sack"], "crypt": ["decor/floor_candle_stubs"],
	"chapel": ["decor/floor_candle_stubs", "decor/floor_book"], "belfry": ["decor/floor_rope_coil"]}
const WINDOW_LIGHT := {"a": Color(0.42, 0.62, 1.0), "b": Color(1.0, 0.38, 0.5), "c": Color(0.62, 0.48, 1.0)}

var room: Room
var rng := RandomNumberGenerator.new()
var _items: Array = []           # [Texture2D, Vector2 pos, bool flip]
var lights: Array = []           # [PointLight2D, base energy, phase, flicker amount]
var _t := 0.0


## Floor variant for a theme, picked from the room seed (0 = the classic floor).
static func background(theme: String, seed_: int) -> Texture2D:
	var names := ["rooms/room_" + theme]
	for i in [1, 2]:
		if Art.has("rooms/room_%s_%d" % [theme, i]):
			names.append("rooms/room_%s_%d" % [theme, i])
	var r := RandomNumberGenerator.new()
	r.seed = seed_ ^ 0x6b1d
	return Art.tex(names[r.randi() % names.size()])


func setup(r: Room, used_lights: int) -> void:
	room = r
	rng.seed = int(room.data["seed"]) ^ 0x2d3c
	z_index = -19
	var th := room.theme
	if not SCONCE.has(th):
		th = "cellar"
	var kind: String = room.data["type"]
	var budget := LIGHT_BUDGET - used_lights
	if kind in ["shop", "treasure", "secret"]:
		budget -= 2   # their pedestals carry lights of their own
	var free_top: Array = TOP_TILES.duplicate()
	var free_side := {Vector2i.LEFT: SIDE_Y.duplicate(), Vector2i.RIGHT: SIDE_Y.duplicate()}
	# ---- chapel windows: a symmetric pair throwing coloured light pools onto the floor
	if th == "chapel" and budget >= 2:
		var a: int = [2, 3, 4][rng.randi() % 3]
		var style: String = ["a", "b", "c"][rng.randi() % 3]
		var style2: String = style if rng.randf() < 0.5 else ["a", "b", "c"][rng.randi() % 3]
		_window(a, style)
		_window(14 - a, style2)
		free_top.erase(a)
		free_top.erase(14 - a)
		budget -= 2
	# ---- sconces: a symmetric pair on the top wall or the side walls
	var want := 2 if th != "chapel" else 2
	if kind == "boss":
		want = 2
	var n := mini(want, budget)
	if n >= 2:
		if rng.randf() < 0.5:
			var choices := []
			for t in [2, 3, 4, 5]:
				if t in free_top and (14 - t) in free_top:
					choices.append(t)
			if choices.is_empty():
				_side_pair(free_side)
			else:
				var t2: int = choices[rng.randi() % choices.size()]
				_sconce_top(t2)
				_sconce_top(14 - t2)
				free_top.erase(t2)
				free_top.erase(14 - t2)
		else:
			_side_pair(free_side)
		n -= 2
		budget -= 2
	if n == 1:
		var t3: int = [5, 9][rng.randi() % 2]
		if t3 in free_top:
			_sconce_top(t3)
			free_top.erase(t3)
		budget -= 1
	# ---- wall pieces on what is left of the top wall
	var pool: Array = WALL[th]
	var tries := 0
	var placed := 0
	var goal := rng.randi_range(2, 4)
	var signature := rng.randf() < 0.7
	var used_wide := {}
	while placed < goal and tries < 24 and not free_top.is_empty():
		tries += 1
		var it: Array = pool[0] if signature else pool[rng.randi() % pool.size()]
		var w: int = it[1]
		if w == 2 and used_wide.has(it[0]):
			continue   # one clock, one shelf, one rack per room
		used_wide[it[0]] = true
		var spots: Array = free_top
		if w == 2:
			spots = free_top.filter(func(t): return (t + 1) in free_top and (t <= 4 or t >= 9))
		signature = false
		if spots.is_empty():
			continue
		var t4: int = spots[rng.randi() % spots.size()]
		var nm: String = "decor/" + it[0]
		if not Art.has(nm):
			continue
		_add(Art.tex(nm), Vector2(16 + 16 * t4 + int(it[2]), int(it[3])), rng.randf() < 0.5 and w == 1 and it[0] != "wall_clock")
		if it[0] == "wall_niche_candle":
			_flame("candle", Vector2(16 + 16 * t4 + 8, 16 + 6), false)
		if it[0] == "wall_votives" and budget > 0:
			_votives(Vector2(16 + 16 * t4, 16))
			budget -= 1
		free_top.erase(t4)
		if w == 2:
			free_top.erase(t4 + 1)
		# leave a gap next to each piece so the wall breathes
		if rng.randf() < 0.6:
			free_top.erase(t4 - 1)
			free_top.erase(t4 + w)
		placed += 1
	# ---- side walls and corner webs
	for side in [Vector2i.LEFT, Vector2i.RIGHT]:
		if not free_side[side].is_empty() and rng.randf() < 0.55 and Art.has("decor/" + SIDE[th]):
			var y: int = free_side[side][rng.randi() % free_side[side].size()]
			_side_piece(Art.tex("decor/" + SIDE[th]), side, y)
	if th in CORNER_WEBS:
		for side in [0, 1]:
			if rng.randf() < 0.45:
				_add(Art.tex("decor/wall_web"), Vector2(16 if side == 0 else 240, 16), side == 1)
	# ---- floor decals
	_floor_decals(th)
	queue_redraw()


func _add(tex: Texture2D, pos: Vector2, flip := false) -> void:
	_items.append([tex, pos, flip])


func _draw() -> void:
	for it in _items:
		var tex: Texture2D = it[0]
		var pos: Vector2 = it[1]
		if it[2]:
			draw_set_transform(pos + Vector2(tex.get_width(), 0), 0.0, Vector2(-1, 1))
			draw_texture(tex, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture(tex, pos)


# ---------------------------------------------------------------- lights

func _light(pos: Vector2, col: Color, energy: float, sc: float, flicker := 0.14, tex: Texture2D = null) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex if tex else Art.light_tex
	l.color = col
	l.energy = energy
	l.texture_scale = sc
	l.position = pos
	room.add_child(l)
	lights.append([l, energy, rng.randf() * TAU, flicker])
	return l


## `bottom_centre` is in left-wall terms; `mirror` puts the flame on the right wall, pixel-mirrored
## about the room's centre line (x -> 271 - x) like the mirrored mounts.
func _flame(kind: String, bottom_centre: Vector2, mirror: bool) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("decor/flame_" + kind, 9.0 if kind == "torch" else 7.0)
	a.centered = false
	var t: Texture2D = a.sprite_frames.get_frame_texture("default", 0)
	a.position = bottom_centre - Vector2(floorf(t.get_width() / 2.0), t.get_height())
	if mirror:
		a.position.x = 271.0 - (a.position.x + t.get_width() - 1.0)
	a.flip_h = mirror
	a.material = Art.unshaded
	a.z_index = -11
	a.play("default")
	a.frame = rng.randi() % maxi(1, a.sprite_frames.get_frame_count("default"))
	room.add_child(a)
	return a


func _sconce_top(tile: int) -> void:
	var th := room.theme if SCONCE.has(room.theme) else "cellar"
	var cfg: Dictionary = SCONCE[th]
	var base := Vector2(16 + 16 * tile, 16)
	_add(Art.tex("decor/sconce_%s_top" % th), base)
	var mid := Vector2.ZERO
	for p in cfg["top"]:
		_flame(cfg["flame"], base + (p as Vector2), false)
		mid += p
	mid /= float((cfg["top"] as Array).size())
	_light(base + mid + Vector2(0, 6), cfg["col"], cfg["e"], cfg["s"])


func _side_pair(free_side: Dictionary) -> void:
	var y: int = SIDE_Y[rng.randi() % SIDE_Y.size()]
	for side in [Vector2i.LEFT, Vector2i.RIGHT]:
		_sconce_side(side, y)
		free_side[side].erase(y)


func _sconce_side(side: Vector2i, y: int) -> void:
	var th := room.theme if SCONCE.has(room.theme) else "cellar"
	var cfg: Dictionary = SCONCE[th]
	var tex := Art.tex("decor/sconce_%s_side" % th)
	var right := side == Vector2i.RIGHT
	_side_piece(tex, side, y)
	for p in cfg["side"]:
		var fp: Vector2 = p
		_flame(cfg["flame"], Vector2(15.0 + fp.x, y + fp.y), right)
		var lx := 21.0 + fp.x
		_light(Vector2(lx if not right else 271.0 - lx, y + fp.y + 4.0), cfg["col"], cfg["e"], cfg["s"])


## Side pieces start on the side wall's inner outline (x 15) and poke over the floor edge.
func _side_piece(tex: Texture2D, side: Vector2i, y: int) -> void:
	if side == Vector2i.LEFT:
		_add(tex, Vector2(15, y))
	else:
		_add(tex, Vector2(257 - tex.get_width(), y), true)


func _window(tile: int, style: String) -> void:
	var pos := Vector2(16 + 16 * tile, 14)
	_add(Art.tex("decor/wall_window_%s" % style), pos)
	var g := Sprite2D.new()
	g.texture = Art.tex("decor/wall_window_%s_glass" % style)
	g.centered = false
	g.position = pos
	g.material = Art.unshaded
	g.z_index = -18
	g.modulate = Color(0.9, 0.9, 0.9)
	room.add_child(g)
	# the pool leans right: the moon is high on the left
	var pool := Art.tex("decor/light/window_pool") if Art.has("decor/light/window_pool") else null
	var l := _light(pos + Vector2(14, 40), WINDOW_LIGHT[style], 0.75, 1.0, 0.03, pool)
	if pool == null:
		l.texture_scale = 0.35
	# dust drifting through the beam (lit by it, nearly invisible outside it)
	var motes := CPUParticles2D.new()
	motes.amount = 5
	motes.lifetime = 5.0
	motes.preprocess = 5.0
	motes.position = pos + Vector2(16, 54)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(8, 14)
	motes.direction = Vector2(0.3, 1)
	motes.spread = 70.0
	motes.gravity = Vector2(0, 1.2)
	motes.initial_velocity_min = 1.5
	motes.initial_velocity_max = 3.5
	motes.color = Color("#cae6f5")
	motes.z_index = -10
	motes.randomness = 1.0
	motes.seed = rng.randi()
	motes.use_fixed_seed = true
	room.add_child(motes)


func _votives(pos: Vector2) -> void:
	if Art.has("decor/wall_votives_glow_f0"):
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Art.anim("decor/wall_votives_glow", 5.0)
		a.centered = false
		a.position = pos
		a.material = Art.unshaded
		a.z_index = -11
		a.play("default")
		room.add_child(a)
	_light(pos + Vector2(16, 10), Color(1.0, 0.76, 0.46), 0.7, 0.55)


func _process(dt: float) -> void:
	_t += dt
	for L in lights:
		var l: PointLight2D = L[0]
		var ph: float = L[2]
		var k: float = L[3]
		var n := sin(_t * 7.3 + ph) * 0.5 + sin(_t * 12.9 + ph * 1.7) * 0.3 + sin(_t * 2.3 + ph * 0.6) * 0.2
		l.energy = L[1] * (1.0 + k * n)


# ---------------------------------------------------------------- floor decals

func _floor_decals(th: String) -> void:
	var cells: Array[Vector2i] = []
	for y in Room.ROWS:
		for x in Room.COLS:
			var c := Vector2i(x, y)
			if room.char_at(c) == "." and not c in RoomTemplates.LANES and not (y == 0 and (x == 0 or x == 14)):
				cells.append(c)
	FloorGen.shuffle(cells, rng)
	var names: Array = FLOOR.get(th, FLOOR["cellar"])
	var n := rng.randi_range(3, 6)
	var used := {}
	for c in cells:
		if n <= 0:
			break
		var near := false
		for u in used.keys():
			if absi(u.x - c.x) <= 1 and absi(u.y - c.y) <= 1:
				near = true
				break
		if near:
			continue
		var nm: String = names[rng.randi() % names.size()]
		if not Art.has(nm):
			continue
		var tex := Art.tex(nm)
		var off := Vector2(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		var p := room.cell_pos(c) + Vector2(8 - tex.get_width() / 2, 8 - tex.get_height() / 2) + off
		_add(tex, p.round(), rng.randf() < 0.5)
		used[c] = true
		n -= 1
	# things leaning on the foot of the top wall
	var foot: Array = FOOT.get(th, [])
	for i in rng.randi_range(0, 2):
		if foot.is_empty():
			break
		var x2: int = [1, 2, 3, 4, 10, 11, 12, 13][rng.randi() % 8]
		var c2 := Vector2i(x2, 0)
		if room.char_at(c2) != "." or used.has(c2):
			continue
		var tex2 := Art.tex(foot[rng.randi() % foot.size()])
		_add(tex2, Vector2(16 + 16 * x2 + 8 - tex2.get_width() / 2, 32 - tex2.get_height() + 6), rng.randf() < 0.5)
		used[c2] = true


# ---------------------------------------------------------------- test (run by -- --checkrooms)

## Builds every layout as a real Room for every theme and room type (with a stand-in world) and checks
## the static light budget and that no decor ever covers a door slot. Returns the number of problems.
static func check_dressing() -> int:
	var stub_script := GDScript.new()
	stub_script.source_code = "extends Node2D\nvar actors := Node2D.new()\nvar hud = null\nvar room = null\nvar player = null\nvar enemies := []\nvar floor_num := 1\n"
	stub_script.reload()
	var stub: Node2D = stub_script.new()
	var errs := 0
	var most := 0
	var slots: Array[Rect2] = [Rect2(120, 0, 32, 32), Rect2(120, 176, 32, 16), Rect2(0, 88, 16, 32), Rect2(256, 88, 16, 32)]
	var layouts: Array = []
	for t in RoomTemplates.NORMAL:
		layouts.append(["normal", t["id"], t["rows"]])
	for k in ["start", "shop"]:
		layouts.append([k, k, RoomTemplates.START])
	layouts.append(["treasure", "treasure", RoomTemplates.TREASURE])
	layouts.append(["secret", "secret", RoomTemplates.TREASURE])
	layouts.append(["boss", "boss", RoomTemplates.BOSS])
	var n := 0
	for th in ["cellar", "crypt", "chapel", "belfry"]:
		for L in layouts:
			for sd in [1, 77, 4242]:
				var d := {"type": L[0], "grid": RoomTemplates.to_grid(L[2]), "cleared": true, "visited": true,
					"seen": true, "pickups": [], "seed": hash("%s:%s:%d" % [th, L[1], sd]), "dist": 3}
				var r := Room.new()
				r.build(stub, Vector2i.ZERO, d, th, {Vector2i.UP: "normal", Vector2i.DOWN: "boss", Vector2i.LEFT: "hidden", Vector2i.RIGHT: "treasure"})
				n += 1
				var lights: int = r.decor.lights.size() + r.candles.size() + r._fires.size()
				most = maxi(most, lights)
				if lights > LIGHT_BUDGET:
					errs += 1
					print("[checkrooms] %s %s seed %d: %d static lights" % [th, L[1], sd, lights])
				for it in r.decor._items:
					var tex: Texture2D = it[0]
					var rect := Rect2(it[1], tex.get_size())
					for sl in slots:
						if rect.intersects(sl):
							errs += 1
							print("[checkrooms] %s %s: %s covers a door slot at %s" % [th, L[1], tex.resource_path.get_file(), rect])
				r.objects.free()
				r.free()
	stub.actors.free()
	stub.free()
	print("[checkrooms] dressed %d rooms: most static lights in one room = %d (budget %d), %d problems" % [n, most, LIGHT_BUDGET, errs])
	return errs
