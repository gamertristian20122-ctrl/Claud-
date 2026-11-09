class_name AreaGimmicks
extends Node2D
## What makes the Long Night's new areas play differently (one node per room of an area theme):
##   Kitchen  stove tops that glow on and off (a dull-red warning, then hot: they burn), and boiling copper pots
##            (template U) that spill a scalding puddle when shot. Flour Ghosts' clouds swallow every shot.
##   Library  bookcases that slide along their rails on a timer (moving cover; they never trap Tallow, never move
##            into anyone, never cut a door off), and an occasional shelf-door: shoot the book that sticks out.
##            On a floor whose Hollow hides behind a top wall, that wall is a shelf-door too.
##   Attic    deep dark (Tallow's light is smaller), lanterns on the walls that light when shot, and dust sheets
##            over the furniture that hide what is behind them until a shot tears them off.
## Hooks (one line each): Room.build -> attach(), Room._obstacle_tex -> obstacle_tex(), Room.shot_hits -> shot_at(),
## Room.break_obstacle "U" -> urn_broken(), RoomDecor.setup -> dress(), Player light -> light_mult(),
## autotest drive -> bot_push(), main --checkrooms -> check(). Lodgers and guardians call flour_cloud(), ink_puddle(),
## scald(), hush_ring() and spin_sheets() (scripts/game/area_ai.gd).
## Placement is seeded from the room's seed (the same house for everyone); rewards use world.rng.

const THEMES := ["kitchen", "library", "attic"]
const ATTIC_LIGHT := 0.78          # Tallow's light up in the attic
const STOVE_PERIOD := 6.0          # a stove top: cold, then 1 s of dull-red warning, then 2.2 s hot
const STOVE_HOT := 1.8
const STOVE_WARN := 1.0
const STOVE_HIT := 3.0
const SCALD_HIT := 3.0
const SHELF_PERIOD := 3.6          # a sliding bookcase moves one cell every 3.6 s (0.6 s shudder first)
const SHELF_SLIDE := 0.5
const NOOK_HITS := 3
const LANTERN_R := 46.0
const LANTERN_COL := Color(1.0, 0.72, 0.42)
const MOON := Color(0.62, 0.72, 1.0)

## Shots everywhere check these (flour clouds swallow shots; hush rings snuff Tallow's embers).
static var clouds: Array = []
static var hushes: Array = []

var room: Room
var theme := ""
var _t := 0.0
var stoves: Array = []       # {c, phase, glow: Sprite2D, state}
var steam := {}              # Vector2i -> AnimatedSprite2D over a boiling pot
var shelves: Array = []      # {rail: Dictionary (in room.data["slide"]), t, warned}
var nook := {}               # {t, spr, hits, open, hollow}
var lanterns: Array = []     # {pos, side, spr, glow, light, lit}
var _burn_t := 0.0


# ================================================================= hooks

static func attach(r: Room) -> void:
	if not r.theme in THEMES:
		return
	var g := AreaGimmicks.new()
	g.name = "AreaGimmicks"
	g.room = r
	g.theme = r.theme
	r.add_child(g)
	g._setup()


static func of(r: Room) -> AreaGimmicks:
	if r == null or not r.theme in THEMES:
		return null
	return r.get_node_or_null("AreaGimmicks") as AreaGimmicks


## Tallow's light multiplier for the room on screen (deep dark in the attic).
static func light_mult(w: Node) -> float:
	if w == null or not is_instance_valid(w) or w.get("room") == null:
		return 1.0
	return ATTIC_LIGHT if (w.room as Room).theme == "attic" else 1.0


## True when `wp` lies in the pool of a lit lantern (the mannequins freeze there).
static func lit_at(w: Node, wp: Vector2) -> bool:
	var g := of(w.room)
	if g == null:
		return false
	for L in g.lanterns:
		if L["lit"] and wp.distance_to(g.room.position + L["pool"]) < LANTERN_R:
			return true
	return false


## Room._obstacle_tex: the areas' furniture (B), crates (C) and the kitchen's boiling pots (U).
static func obstacle_tex(r: Room, c: Vector2i, ch: String) -> Texture2D:
	if not r.theme in THEMES or not ch in ["B", "C", "U"]:
		return null
	var h := posmod(c.x * 7 + c.y * 13 + int(r.data["seed"]), 3)
	match r.theme:
		"kitchen":
			if ch == "U":
				return Art.tex("areas/kitchen/pot")
			if ch == "C":
				return Art.tex("decor/prop_kitchen_sacks")
			var lb := r.char_at(c + Vector2i.LEFT) == "B"
			var rb := r.char_at(c + Vector2i.RIGHT) == "B"
			if lb or rb:
				return Art.tex("decor/prop_kitchen_table_" + ("m" if lb and rb else ("l" if rb else "r")))
			return Art.tex("decor/prop_kitchen_range" if h != 0 else "decor/prop_kitchen_block")
		"library":
			if ch == "U":
				return null
			if ch == "C":
				return Art.tex("decor/prop_library_stack")
			for rail in r.data.get("slide", []):
				if not rail.get("dead", false) and rail["cells"][int(rail["at"])] == c:
					return Art.tex("decor/prop_library_slide")
			var lb2 := r.char_at(c + Vector2i.LEFT) == "B"
			var rb2 := r.char_at(c + Vector2i.RIGHT) == "B"
			if lb2 or rb2:
				return Art.tex("decor/prop_library_shelf_" + ("m" if lb2 and rb2 else ("l" if rb2 else "r")))
			return Art.tex("decor/prop_library_desk" if h != 0 else "decor/prop_library_globe")
		"attic":
			if ch == "U":
				return null
			if ch == "C":
				return Art.tex("decor/prop_attic_trunk")
			if c in r.data.get("unsheeted", []):
				return Art.tex(["decor/prop_attic_wardrobe", "decor/prop_attic_chair", "decor/prop_attic_mirror"][h])
			return Art.tex(["decor/prop_attic_sheet_a", "decor/prop_attic_sheet_b", "decor/prop_attic_sheet_c"][h])
	return null


## Room.shot_hits (every shot, every frame): true when a gimmick takes the shot.
static func shot_at(r: Room, wp: Vector2, dmg: float, friendly: bool) -> bool:
	for c in clouds:
		if is_instance_valid(c) and c.swallows(wp):
			c.puff(wp)
			return true
	if friendly:
		for h in hushes:
			if is_instance_valid(h) and h.on_ring(wp, 5.0):
				r.world.fx_poof(wp + Vector2(0, -6), false, 0.6)
				return true
	if not friendly:
		return false
	var g := of(r)
	return g != null and g._shot(wp, dmg)


## Room.break_obstacle for "U": true when the area handled it (a kitchen pot spills).
static func urn_broken(r: Room, c: Vector2i) -> bool:
	var g := of(r)
	if g == null or g.theme != "kitchen":
		return false
	g._spill(c)
	return true


## RoomDecor.setup, before the wall lights: area dressing that uses lights. Returns the lights it used or reserved.
static func dress(d: RoomDecor, free_top: Array, budget: int) -> int:
	var r: Room = d.room
	var kind: String = r.data["type"]
	match r.theme:
		"library":
			# a shelf-door in some ordinary rooms: two top-wall tiles kept free for it
			if kind == "normal" and d.rng.randf() < 0.32:
				var spans: Array = []
				for t in [1, 2, 3, 10, 11, 12]:
					if t in free_top and (t + 1) in free_top:
						spans.append(t)
				if not spans.is_empty():
					var t2: int = spans[d.rng.randi() % spans.size()]
					d.set_meta("nook", t2)
					free_top.erase(t2)
					free_top.erase(t2 + 1)
			return 0
		"attic":
			var used := 0
			# the round window high in the wall, and its pool of moonlight
			if budget >= 1:
				var spans2: Array = []
				for t in [2, 3, 10, 11]:
					if t in free_top and (t + 1) in free_top:
						spans2.append(t)
				if not spans2.is_empty():
					var t3: int = spans2[d.rng.randi() % spans2.size()]
					var pos := Vector2(16 + 16 * t3 + 5, 6)
					d._add(Art.tex("areas/attic/window_round"), pos)
					var gl := Sprite2D.new()
					gl.texture = Art.tex("areas/attic/window_round_glass")
					gl.centered = false
					gl.position = pos
					gl.material = Art.unshaded
					gl.z_index = -18
					gl.modulate = Color(0.85, 0.85, 0.9)
					r.add_child(gl)
					var pool := Art.tex("areas/attic/light/moon_round") if Art.has("areas/attic/light/moon_round") else null
					var l := d._light(pos + Vector2(11, 56), MOON, 0.7, 0.9, 0.02, pool)
					if pool == null:
						l.texture_scale = 0.4
					free_top.erase(t3)
					free_top.erase(t3 + 1)
					used += 1
			# lanterns on the wall, unlit: each keeps a light of the budget for when it is lit
			var n := clampi(budget - used, 0, 3)
			var spots: Array = []
			var tops: Array = []
			for t in [2, 3, 4, 10, 11, 12, 1, 13]:
				if t in free_top:
					tops.append(t)
			FloorGen.shuffle(tops, d.rng)
			while spots.size() < n and not tops.is_empty():
				var t4: int = tops.pop_back()
				spots.append([Vector2(16 + 16 * t4 + 3, 16), "top"])
				free_top.erase(t4)
				tops.erase(t4 - 1)
				tops.erase(t4 + 1)
			d.set_meta("lanterns", spots)
			return used + spots.size()
	return 0


# ================================================================= the room's gimmicks

func _setup() -> void:
	z_index = 0
	match theme:
		"kitchen":
			_setup_kitchen()
		"library":
			_setup_library()
		"attic":
			_setup_attic()


func _live() -> bool:
	return room.world != null and room.world.get("layout") != null and room.world.get("player") != null


func _process(dt: float) -> void:
	if not _live() or room.world.room != room:
		return
	_t += dt
	match theme:
		"kitchen":
			_kitchen_step(dt)
		"library":
			_library_step(dt)


# ---------------------------------------------------------------- Kitchen

func _setup_kitchen() -> void:
	var cells: Array[Vector2i] = []
	# the layout's spikes are stove tops here
	for s in room.spikes:
		cells.append(room.cell_of(s.position))
		s.queue_free()
	room.spikes.clear()
	if room.data["type"] == "normal":
		var rng := RandomNumberGenerator.new()
		rng.seed = int(room.data["seed"]) ^ 0x5707e
		var cands: Array[Vector2i] = []
		for y in range(1, Room.ROWS - 1):
			for x in range(1, Room.COLS - 1):
				var c := Vector2i(x, y)
				if room.char_at(c) == "." and _open_floor(c) and not c in cells:
					cands.append(c)
		FloorGen.shuffle(cands, rng)
		var want := rng.randi_range(2, 4)
		for c in cands:
			if want <= 0:
				break
			var near := false
			for o in cells:
				if absi(o.x - c.x) <= 1 and absi(o.y - c.y) <= 1:
					near = true
			if not near:
				cells.append(c)
				want -= 1
	for i in cells.size():
		var c: Vector2i = cells[i]
		var base := Sprite2D.new()
		base.texture = Art.tex("areas/kitchen/stove")
		base.centered = false
		base.position = room.cell_pos(c)
		room.floor_layer.add_child(base)
		var glow := Sprite2D.new()
		glow.centered = false
		glow.position = room.cell_pos(c)
		glow.material = Art.unshaded
		glow.z_index = -14
		glow.visible = false
		room.add_child(glow)
		stoves.append({"c": c, "phase": (i % 2) * STOVE_PERIOD * 0.5, "glow": glow, "state": "cold"})
	# steam over every boiling pot
	for c in room.obstacle_nodes.keys():
		if room.char_at(c) == "U":
			_add_steam(c)


## A floor cell that may hold a stove / rail: clear of door lanes, the door mouths, the reward cells and corners.
func _open_floor(c: Vector2i) -> bool:
	if c in RoomTemplates.LANES or c in RoomTemplates.REWARD_CELLS:
		return false
	for dc in RoomTemplates.DOORS:
		if absi(dc.x - c.x) + absi(dc.y - c.y) <= 2:
			return false
	return not (c.y == 4 and c.x >= 5 and c.x <= 9)


func _add_steam(c: Vector2i) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("areas/kitchen/pot_steam", 6.0)
	a.centered = false
	a.position = room.cell_pos(c) + Vector2(5, -6)
	a.z_index = -10
	a.play("default")
	a.frame = posmod(c.x + c.y, 4)
	room.add_child(a)
	steam[c] = a


func stove_state(s: Dictionary) -> String:
	var k := fmod(_t - 1.5 + float(s["phase"]), STOVE_PERIOD)
	if _t < 1.5 or k < 0.0:
		return "cold"
	if k < STOVE_HOT:
		return "hot"
	if k > STOVE_PERIOD - STOVE_WARN:
		return "warn"
	return "cold"


func _kitchen_step(dt: float) -> void:
	var w: Node = room.world
	var p: Player = w.player
	_burn_t -= dt
	var sizzle := _burn_t <= 0.0
	if sizzle:
		_burn_t = 0.5
	for s in stoves:
		var st := stove_state(s)
		var glow: Sprite2D = s["glow"]
		if st != s["state"]:
			s["state"] = st
			if st == "warn":
				glow.texture = Art.tex("areas/kitchen/stove_glow_f0")
				Audio.play("sizzle", -16.0, 0.1, 1.3)
			elif st == "hot":
				Audio.play("burn_whoosh", -14.0, 0.1, 1.2)
		glow.visible = st != "cold"
		if st == "warn":
			glow.visible = fmod(_t, 0.3) < 0.2           # a flicker as it warms
		elif st == "hot":
			glow.texture = Art.tex("areas/kitchen/stove_glow_f%d" % (1 + int(_t * 6.0) % 2))
		if st != "hot":
			continue
		# v2.7: a hot top throws a few rising embers, like a hearth's coals: it reads at a glance on a phone
		s["ember"] = float(s.get("ember", 0.0)) - dt
		if float(s["ember"]) <= 0.0:
			s["ember"] = 0.1
			Juice.of(w).hot.emit(room.position + room.cell_pos(s["c"]) + Vector2(randf_range(3.0, 13.0), randf_range(4.0, 11.0)),
				Vector2(randf_range(-5.0, 5.0), randf_range(-34.0, -20.0)), randf_range(0.35, 0.6), FxParts.EMBER, -6.0, 0.5)
		var rect := Rect2(room.position + room.cell_pos(s["c"]) + Vector2(2, 3), Vector2(12, 11))
		if not p.dead and Room._touches(rect, p.global_position, Player.RADIUS * 0.7):
			Records.blame("stove")
			p.hurt(STOVE_HIT, p.global_position - rect.get_center())
			if Game.tip("stove"):
				w.hud.show_hint("Stove tops glow red before they burn: step off", 3.0)
		if sizzle:
			for e in w.enemies:
				if is_instance_valid(e) and e.alive and e.active and not e.flying and Room._touches(rect, e.global_position, e.radius * 0.6):
					e.take_hit(0.8, Vector2.ZERO)


func _spill(c: Vector2i) -> void:
	var w: Node = room.world
	if steam.has(c):
		(steam[c] as Node).queue_free()
		steam.erase(c)
	var spilt := Sprite2D.new()
	spilt.texture = Art.tex("areas/kitchen/pot_spilt")
	spilt.position = room.cell_pos(c) + Vector2(8, 10)
	room.floor_layer.add_child(spilt)
	Audio.play("splash", 0.0, 0.08, 0.7)
	Audio.play("sizzle", -4.0, 0.08, 1.0)
	if w != null and w.has_method("fx_smoke"):
		w.fx_smoke(room.cell_center(c) + Vector2(0, -6))
		scald(w, room.cell_center(c) + Vector2(0, 4), 5.0, 17.0)
		if Game.tip("pot"):
			w.hud.show_hint("Boiling pots spill when shot: scalding for anyone in the puddle", 3.0)


# ---------------------------------------------------------------- Library

func _setup_library() -> void:
	var d := room.decor
	if room.data["type"] == "normal":
		if not room.data.has("slide"):
			room.data["slide"] = _pick_rails()
		for rail in room.data["slide"]:
			if rail.get("dead", false):
				continue
			var c: Vector2i = rail["cells"][int(rail["at"])]
			if room.char_at(c) == ".":
				room.data["grid"][c.y][c.x] = "B"
				room._add_obstacle(c, "B")
			elif room.char_at(c) != "B":
				rail["dead"] = true
				continue
			for i in 3:
				var rc: Vector2i = rail["cells"][i]
				var rs := Sprite2D.new()
				rs.texture = Art.tex("areas/library/rail_" + ["l", "m", "r"][i])
				rs.centered = false
				rs.position = room.cell_pos(rc)
				room.floor_layer.add_child(rs)
			shelves.append({"rail": rail, "t": SHELF_PERIOD * (0.6 + 0.4 * float(shelves.size())), "warned": false, "moving": false})
	# a shelf-door nook kept free on the top wall by dress()
	if d and d.has_meta("nook"):
		_make_nook(Vector2(16 + 16 * int(d.get_meta("nook")), 2), false)
	# the floor's Hollow behind the top wall: a shelf-door instead of cracks
	if Vector2i.UP in room.hidden_dirs:
		_make_nook(Room.DOOR_POS[Vector2i.UP] + Vector2(0, 2), true)


func _make_nook(pos: Vector2, hollow: bool) -> void:
	var key := "nook_hollow" if hollow else "nook_open"
	var a := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", 10.0)
	for f in 4:
		sf.add_frame("default", Art.tex("areas/library/shelfdoor_f%d" % f))
	a.sprite_frames = sf
	a.centered = false
	a.position = pos
	a.z_index = -11
	var opened: bool = room.data.get(key, false)
	a.frame = 3 if opened else 0
	room.add_child(a)
	nook = {"pos": pos, "spr": a, "hits": 0, "open": opened, "hollow": hollow}


## Up to two rails of three cells for sliding bookcases: every position of every rail keeps all the doors joined
## and no floor cell sealed off (checked for each combination).
func _pick_rails() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(room.data["seed"]) ^ 0x51ed
	var cands: Array = []
	for y in range(1, Room.ROWS - 1):
		for x in range(1, Room.COLS - 3):
			var ok := true
			for i in 3:
				var c := Vector2i(x + i, y)
				if room.char_at(c) != "." or not _open_floor(c):
					ok = false
			if ok:
				cands.append([Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 2, y)])
	FloorGen.shuffle(cands, rng)
	var picked: Array = []
	var want := 1 if rng.randf() < 0.55 else 2
	for cand in cands:
		if picked.size() >= want:
			break
		var clash := false
		for p in picked:
			for c in p:
				for c2 in cand:
					if absi(c.x - c2.x) <= 1 and absi(c.y - c2.y) <= 1:
						clash = true
		if clash or not rails_ok(room.data["grid"], picked + [cand]):
			continue
		picked.append(cand)
	var out: Array = []
	for p in picked:
		out.append({"cells": p, "at": 1, "dir": 1 if rng.randf() < 0.5 else -1, "dead": false})
	return out


## Every combination of shelf positions keeps the room whole (all doors joined, no cell sealed off).
static func rails_ok(grid: Array, rails: Array) -> bool:
	var combos: Array = [[]]
	for r in rails:
		var nxt: Array = []
		for cmb in combos:
			for c in r:
				nxt.append(cmb + [c])
		combos = nxt
	for cmb in combos:
		var g: Array = []
		for row in grid:
			g.append((row as Array).duplicate())
		for c in cmb:
			g[c.y][c.x] = "B"
		if not _whole(g):
			return false
	return true


static func _whole(g: Array) -> bool:
	var walk := func(c: Vector2i) -> bool: return c.x >= 0 and c.y >= 0 and c.x < Room.COLS and c.y < Room.ROWS and not str(g[c.y][c.x]) in Room.SOLID
	var start: Vector2i = RoomTemplates.DOORS[0]
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for o in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + o
			if not seen.has(n) and walk.call(n):
				seen[n] = true
				q.append(n)
	for y in Room.ROWS:
		for x in Room.COLS:
			var c := Vector2i(x, y)
			if walk.call(c) and not seen.has(c):
				return false
	return true


func _library_step(dt: float) -> void:
	# a bomb opened the hollow behind a shelf-door: swing it aside too
	if not nook.is_empty() and nook["hollow"] and not nook["open"] and not Vector2i.UP in room.hidden_dirs:
		nook["open"] = true
		room.data["nook_hollow"] = true
		(nook["spr"] as AnimatedSprite2D).play("default")
	for s in shelves:
		var rail: Dictionary = s["rail"]
		if rail.get("dead", false) or s["moving"]:
			continue
		var c: Vector2i = rail["cells"][int(rail["at"])]
		if not room.obstacle_nodes.has(c) or room.char_at(c) != "B":
			rail["dead"] = true   # broken
			continue
		s["t"] -= dt
		var node: Node2D = room.obstacle_nodes[c]
		if s["t"] <= 0.6:
			if not s["warned"]:
				s["warned"] = true
				Audio.play("step", -6.0, 0.1, 0.5)
				room.world.fx_poof(room.cell_center(c) + Vector2(0, 6), false, 0.6)
			(node.get_child(0) as Node2D).position.x = -1.0 if fmod(_t, 0.12) < 0.06 else 0.0   # it shudders
		if s["t"] > 0.0:
			continue
		(node.get_child(0) as Node2D).position.x = 0.0
		s["warned"] = false
		var at := int(rail["at"])
		var dir := int(rail.get("dir", 1))
		if at + dir < 0 or at + dir > 2:
			dir = -dir
			rail["dir"] = dir
		var nc: Vector2i = rail["cells"][at + dir]
		if _busy(nc):
			s["t"] = 0.8   # someone is in the way: wait
			continue
		s["t"] = SHELF_PERIOD
		_slide(s, c, nc, at + dir)


## Tallow, a walking creature or a pickup on the cell (a bookcase never moves into anyone).
func _busy(c: Vector2i) -> bool:
	var w: Node = room.world
	var rect := Rect2(room.position + room.cell_pos(c), Vector2(16, 16))
	if Room._touches(rect, w.player.global_position, Player.RADIUS + 3.0):
		return true
	for e in w.enemies:
		if is_instance_valid(e) and e.alive and not e.flying and Room._touches(rect, e.global_position, e.radius + 2.0):
			return true
	for o in room.objects.get_children():
		if o is Pickup and not o.taken and rect.grow(2.0).has_point(o.global_position):
			return true
	return false


## Tallow left mid-roll: the room's data takes the case where it was going (the room is rebuilt from it).
func _exit_tree() -> void:
	for s in shelves:
		if s.get("moving", false):
			s["moving"] = false
			var from: Vector2i = s["from"]
			room.data["grid"][from.y][from.x] = "."
			(s["rail"] as Dictionary)["at"] = s["nat"]


func _slide(s: Dictionary, c: Vector2i, nc: Vector2i, nat: int) -> void:
	var rail: Dictionary = s["rail"]
	var node: Node2D = room.obstacle_nodes[c]
	room.data["grid"][nc.y][nc.x] = "B"          # both cells are solid while it rolls
	room._flow_to = Vector2i(-99, -99)
	s["moving"] = true
	s["from"] = c
	s["nat"] = nat
	Audio.play("thud_heavy", -14.0, 0.1, 0.7)
	var tw := node.create_tween()
	tw.tween_property(node, "position", room.cell_pos(nc) + Vector2(8, 16), SHELF_SLIDE).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		s["moving"] = false
		if not is_instance_valid(node) or not room.obstacle_nodes.has(c) or room.obstacle_nodes[c] != node:
			# broken on the way: nothing is left on either cell
			room.data["grid"][nc.y][nc.x] = "."
			rail["dead"] = true
			room._flow_to = Vector2i(-99, -99)
			return
		room.data["grid"][c.y][c.x] = "."
		room.obstacle_nodes.erase(c)
		room.obstacle_nodes[nc] = node
		if room.obstacle_hp.has(c):
			room.obstacle_hp[nc] = room.obstacle_hp[c]
			room.obstacle_hp.erase(c)
		rail["at"] = nat
		room._flow_to = Vector2i(-99, -99))


func _nook_shot(lp: Vector2) -> bool:
	if nook.is_empty() or nook["open"]:
		return false
	var pos: Vector2 = nook["pos"]
	if lp.y > Room.IN.y - 4 or lp.x < pos.x + 2 or lp.x > pos.x + 30:
		return false
	nook["hits"] = int(nook["hits"]) + 1
	var w: Node = room.world
	w.fx_sparks(room.position + Vector2(lp.x, Room.IN.y - 8), Vector2(0, 1), 3)
	Audio.play("page_flip", -2.0, 0.1, 1.2 - 0.15 * int(nook["hits"]))
	if int(nook["hits"]) < NOOK_HITS:
		return true
	nook["open"] = true
	(nook["spr"] as AnimatedSprite2D).play("default")
	Audio.play("door_burst", -2.0, 0.05, 1.1)
	if nook["hollow"]:
		room.data["nook_hollow"] = true
		var hd := Vector2i.UP
		if hd in room.hidden_dirs and w.layout["cells"].has(room.cell + hd):
			w.layout["cells"][room.cell + hd]["revealed"] = true
			w.layout["cells"][room.cell + hd]["seen"] = true
			room.add_door(hd)
			w.hud.show_hint("The shelf swings open: a hollow behind the books!", 2.4)
	else:
		room.data["nook_open"] = true
		var at: Vector2 = room.position + pos + Vector2(16, 40)
		var r: float = w.rng.randf()
		w.add_pickup("chest" if r < 0.55 else ("wax_big" if r < 0.85 else "bomb"), at, "", 0, Vector2(0, 30))
		w.fx_text(at + Vector2(0, -20), "a hidden shelf!", UI.GOLD)
	return true


# ---------------------------------------------------------------- Attic

func _setup_attic() -> void:
	var d := room.decor
	var spots: Array = d.get_meta("lanterns", []) if d else []
	var lit: Array = room.data.get("lit", [])
	for i in spots.size():
		var pos: Vector2 = spots[i][0]
		var side: String = spots[i][1]
		var spr := Sprite2D.new()
		spr.centered = false
		spr.position = pos
		spr.z_index = -11
		spr.flip_h = side == "right"
		room.add_child(spr)
		var pool := pos + (Vector2(5, 24) if side == "top" else Vector2(14 if side == "left" else -4, 12))
		var L := {"pos": pos, "side": side, "spr": spr, "glow": null, "light": null, "lit": false, "pool": pool}
		lanterns.append(L)
		_set_lantern(L, i in lit, true)


func _set_lantern(L: Dictionary, on: bool, instant := false) -> void:
	var spr: Sprite2D = L["spr"]
	spr.texture = Art.tex("areas/attic/lantern_on" if on else "areas/attic/lantern_off")
	if not on or L["lit"]:
		return
	L["lit"] = true
	var g := Sprite2D.new()
	g.texture = Art.tex("areas/attic/lantern_glow")
	g.centered = false
	g.position = spr.position
	g.flip_h = spr.flip_h
	g.material = Art.unshaded
	g.z_index = -10
	room.add_child(g)
	L["glow"] = g
	if room.decor:
		L["light"] = room.decor._light(L["pool"] + Vector2(0, -10), LANTERN_COL, 0.85, 0.55, 0.12)
	if not instant and _live():
		Audio.play("match_strike", -4.0, 0.08)
		room.world.fx_glint(room.position + L["pos"] + Vector2(5, 8))


func _lantern_shot(lp: Vector2) -> bool:
	for i in lanterns.size():
		var L: Dictionary = lanterns[i]
		if L["lit"]:
			continue
		var pos: Vector2 = L["pos"]
		var hit := false
		match L["side"]:
			"top":
				hit = lp.y < Room.IN.y - 2 and lp.x >= pos.x - 3 and lp.x <= pos.x + 13
			"left":
				hit = lp.x < Room.IN.x + 2 and lp.y - 6 >= pos.y - 3 and lp.y - 6 <= pos.y + 18
			"right":
				hit = lp.x > Room.IN.x + Room.COLS * Room.TILE - 2 and lp.y - 6 >= pos.y - 3 and lp.y - 6 <= pos.y + 18
		if hit:
			_set_lantern(L, true)
			var lit: Array = room.data.get("lit", [])
			lit.append(i)
			room.data["lit"] = lit
			if Game.tip("lantern"):
				room.world.hud.show_hint("A lit lantern holds back the dark (and what moves in it)", 3.0)
			return true
	return false


func _sheet_shot(lp: Vector2) -> bool:
	var c := room.cell_of(lp)
	if room.char_at(c) != "B" or c in room.data.get("unsheeted", []):
		return false
	var rect := Rect2(Room.IN + Vector2(c.x * Room.TILE + 2, c.y * Room.TILE + 2), Vector2(Room.TILE - 4, Room.TILE - 3))
	if not rect.has_point(lp):
		return false
	var un: Array = room.data.get("unsheeted", [])
	un.append(c)
	room.data["unsheeted"] = un
	var node: Node2D = room.obstacle_nodes.get(c)
	if node:
		var s := node.get_child(0) as Sprite2D
		var t := room._obstacle_tex(c, "B")
		s.texture = t
		s.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	var w: Node = room.world
	var fly := AnimatedSprite2D.new()
	fly.sprite_frames = Art.anim("areas/attic/sheet_fly", 8.0, false)
	fly.position = room.cell_center(c) + Vector2(0, -16)
	fly.z_index = 4
	w.fx_layer.add_child(fly)
	fly.play("default")
	var tw := fly.create_tween()
	tw.tween_property(fly, "position", fly.position + Vector2(18, -26), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fly, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw.tween_callback(fly.queue_free)
	Audio.play("moth_flutter", -2.0, 0.1, 0.7)
	w.fx_poof(room.cell_center(c) + Vector2(0, -10), false, 1.2)
	var r: float = w.rng.randf()
	if r < 0.2:
		w.add_pickup("coin", room.cell_center(c) + Vector2(0, 10), "", 0, Vector2(0, 40))
	elif r < 0.3:
		w.add_pickup("wax_small", room.cell_center(c) + Vector2(0, 10))
	if Game.tip("sheet"):
		w.hud.show_hint("Dust sheets hide what is behind them: shoot them off", 3.0)
	return true


# ---------------------------------------------------------------- shots

func _shot(wp: Vector2, _dmg: float) -> bool:
	if not _live():
		return false
	var lp := wp - room.position
	match theme:
		"library":
			return _nook_shot(lp)
		"attic":
			return _lantern_shot(lp) or _sheet_shot(lp)
	return false


# ================================================================= things the lodgers and guardians leave

## A puddle on the floor: "scald" (hot broth: burns, drawn unlit) or "ink" (slows Tallow, like soot).
class Puddle extends Node2D:
	var world: Node
	var kind := "scald"
	var life := 5.0
	var radius := 14.0
	var small := false
	var _spr: AnimatedSprite2D
	var _tick := 0.0
	var _shape := 0

	func _ready() -> void:
		if kind == "scald":
			_spr = AnimatedSprite2D.new()
			_spr.sprite_frames = Art.anim("areas/kitchen/scald", 6.0)
			_spr.play("default")
			_spr.material = Art.unshaded
			add_child(_spr)
		_shape = randi() % 3

	func _draw() -> void:
		if kind != "ink":
			return
		var blots: Array = [[[-6, -2, 12, 4], [-4, -3, 8, 6], [-7, 0, 2, 2], [5, 1, 3, 1]],
			[[-5, -2, 10, 4], [-7, -1, 3, 3], [2, 0, 6, 3], [-2, 2, 4, 2]],
			[[-6, -1, 12, 3], [-3, -3, 6, 6], [4, -2, 3, 2]]][_shape]
		var k := 0.6 if small else 1.0
		for r in blots:
			draw_rect(Rect2(r[0] * k, r[1] * k, maxf(1.0, r[2] * k), maxf(1.0, r[3] * k)), Color("#1f1833"))
		draw_rect(Rect2(-2 * k, -2 * k, 3, 1), Color("#314152"))

	func _physics_process(dt: float) -> void:
		if world == null or world.player == null or Juice.holding(world):
			return
		life -= dt
		if life <= 0.0:
			queue_free()
			return
		modulate.a = clampf(life / 0.8, 0.0, 1.0) * (0.9 if kind == "ink" else 1.0)
		var p: Player = world.player
		var d: Vector2 = p.global_position - global_position
		var inside := absf(d.x) < radius and absf(d.y) < radius * 0.55
		if kind == "ink":
			if inside and not p.dead and not p.frozen:
				p.position -= p.vel * dt * 0.45   # wading through ink, like soot
				if Game.tip("ink"):
					world.hud.show_hint("Ink is sticky: it slows you down", 2.5)
			return
		_tick -= dt
		if _tick > 0.0:
			return
		_tick = 0.5
		if inside and not p.dead:
			Records.blame("scald")
			p.hurt(AreaGimmicks.SCALD_HIT, d)
		for e in world.enemies:
			if is_instance_valid(e) and e.alive and e.active and not e.flying and not e.boss:
				var de: Vector2 = e.global_position - global_position
				if absf(de.x) < radius and absf(de.y) < radius * 0.55:
					e.take_hit(1.0, Vector2.ZERO)


static func scald(w: Node, wp: Vector2, life := 5.0, radius := 15.0) -> void:
	_puddle(w, wp, "scald", life, radius, false)


static func ink_puddle(w: Node, wp: Vector2, small := false) -> void:
	_puddle(w, wp, "ink", 6.0 if not small else 4.0, 9.0 if not small else 6.0, small)


static func _puddle(w: Node, wp: Vector2, kind: String, life: float, radius: float, small: bool) -> void:
	if w == null or w.get("room") == null or w.finished:
		return
	var r: Room = w.room
	var inner := r.inner_rect().grow(-6.0)
	wp = wp.clamp(inner.position, inner.end)
	var mine := 0
	for c in r.floor_layer.get_children():
		if c is Puddle:
			mine += 1
	if mine >= 14:
		return
	var p := Puddle.new()
	p.world = w
	p.kind = kind
	p.life = life
	p.radius = radius
	p.small = small
	p.position = (wp - r.position).round()
	p.z_index = 1 if kind == "scald" else 0
	r.floor_layer.add_child(p)


## A Flour Ghost's cloud: it swallows every shot that flies into it (Tallow's and the lodgers').
class FlourCloud extends Node2D:
	var world: Node
	var life := 2.8
	var radius := 13.0
	var _spr: AnimatedSprite2D

	func _ready() -> void:
		_spr = AnimatedSprite2D.new()
		_spr.sprite_frames = Art.anim("areas/kitchen/flour", 5.0)
		_spr.play("default")
		_spr.position = Vector2(0, -4)
		add_child(_spr)
		z_index = 7
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 0.92, 0.25)
		AreaGimmicks.clouds.append(self)

	func _exit_tree() -> void:
		AreaGimmicks.clouds.erase(self)

	func swallows(wp: Vector2) -> bool:
		var d := wp - global_position
		return life > 0.25 and Vector2(d.x, d.y * 1.3).length() < radius

	func puff(wp: Vector2) -> void:
		world.fx_poof(wp + Vector2(0, -6), false, 0.7)

	func _physics_process(dt: float) -> void:
		if Juice.holding(world):
			return
		life -= dt
		if life <= 0.4:
			modulate.a = maxf(0.0, life / 0.4) * 0.92
		if life <= 0.0:
			queue_free()


static func flour_cloud(w: Node, wp: Vector2) -> void:
	if w == null or w.finished:
		return
	var c := FlourCloud.new()
	c.world = w
	c.global_position = wp
	w.fx_layer.add_child(c)


## The Head Librarian's hush: a dotted ring that spreads from her. Where it passes Tallow (outside its gaps) he
## cannot shoot for a moment; it snuffs his embers as it goes. It does no harm by itself.
class HushRing extends Node2D:
	var world: Node
	var r := 6.0
	var speed := 70.0
	var max_r := 230.0
	var gaps: Array = []
	var gap_w := 0.42
	var _hit := false
	const SQUASH := 0.62

	func _ready() -> void:
		material = Art.unshaded
		z_index = 6
		AreaGimmicks.hushes.append(self)

	func _exit_tree() -> void:
		AreaGimmicks.hushes.erase(self)

	func in_gap(a: float) -> bool:
		for g in gaps:
			if absf(angle_difference(a, float(g))) < gap_w:
				return true
		return false

	func on_ring(wp: Vector2, tol: float) -> bool:
		var d := wp - global_position
		var e := Vector2(d.x, d.y / SQUASH)
		return absf(e.length() - r) < tol and not in_gap(e.angle())

	func _physics_process(dt: float) -> void:
		if world.freeze_t > 0.0 or Juice.holding(world):
			return
		r += speed * dt * world.time_scale_enemies()
		if r > max_r:
			queue_free()
			return
		var p: Player = world.player
		if not _hit and p and not p.dead and on_ring(p.global_position, 6.0):
			_hit = true
			p.fire_cd = maxf(p.fire_cd, 1.3)
			world.fx_text(p.global_position + Vector2(0, -28), "hushed", Color("#cae6f5"))
			Audio.play("snuff_out", -8.0, 0.05, 1.6)
		queue_redraw()

	func _draw() -> void:
		var n := maxi(28, int(r * 1.1))
		for i in n:
			var a := TAU * i / n
			if in_gap(a):
				continue
			var pt := Vector2(cos(a) * r, sin(a) * r * SQUASH).round()
			draw_rect(Rect2(pt, Vector2(2, 1)), Color("#cae6f5") if i % 2 == 0 else Color("#b6cbcf"))
		for g in gaps:   # the gap's edges, so the way through reads at a glance
			for s: float in [-1.0, 1.0]:
				var a2: float = float(g) + s * gap_w
				var pt2 := Vector2(cos(a2) * r, sin(a2) * r * SQUASH).round()
				draw_rect(Rect2(pt2 + Vector2(0, -2), Vector2(1, 5)), Color("#72d6ce"))


static func hush_ring(w: Node, at: Vector2, gaps: Array, speed := 70.0) -> void:
	if w == null or w.finished:
		return
	var h := HushRing.new()
	h.world = w
	h.gaps = gaps
	h.speed = speed
	h.global_position = at
	w.fx_layer.add_child(h)


## The Dressmaker's Form's spinning sheets: dust sheets whirling round it like a skirt. They unfold first
## (harmless, flickering), whirl, then fly off. Touching one melts Tallow.
class SpinSheets extends Node2D:
	var owner_e: Enemy
	var n := 2
	var dur := 3.2
	var t := 0.0
	var spin := 0.0
	var _hit_cd := 0.0
	const UNFOLD := 0.8

	func _ready() -> void:
		z_index = 3
		for i in n:
			var s := AnimatedSprite2D.new()
			s.sprite_frames = Art.anim("areas/attic/sheet_fly", 8.0)
			s.play("default")
			s.frame = i % 4
			add_child(s)

	func radius() -> float:
		if t < UNFOLD:
			return lerpf(10.0, 34.0, t / UNFOLD)
		return 34.0 + 6.0 * sin((t - UNFOLD) * 2.4)

	func sheet_pos(i: int) -> Vector2:
		var a := spin + TAU * i / float(n)
		return Vector2(cos(a), sin(a) * 0.7) * radius() + Vector2(0, -12)

	func _physics_process(dt: float) -> void:
		if owner_e == null or not is_instance_valid(owner_e) or not owner_e.alive:
			queue_free()
			return
		var w: Node = owner_e.world
		if w.freeze_t > 0.0 or Juice.holding(w):
			return
		var k: float = w.time_scale_enemies()
		t += dt * k
		spin += dt * k * (1.6 if t < UNFOLD else 2.6)
		global_position = owner_e.global_position
		_hit_cd -= dt
		for i in n:
			var s := get_child(i) as Node2D
			s.position = sheet_pos(i).round()
			s.visible = t >= UNFOLD or fmod(t, 0.16) < 0.1
		if t >= UNFOLD and _hit_cd <= 0.0:
			var p: Player = w.player
			for i in n:
				if not p.dead and (global_position + sheet_pos(i) + Vector2(0, 12)).distance_to(p.global_position) < 10.0:
					_hit_cd = 0.6
					Records.blame(owner_e)
					p.hurt(5.0 * w.enemy_dmg_mult(), p.global_position - global_position)
					break
		if t >= dur:
			for i in n:
				w.fx_poof(global_position + sheet_pos(i), false, 1.0)
			queue_free()


static func spin_sheets(e: Enemy, n: int, dur: float) -> void:
	var s := SpinSheets.new()
	s.owner_e = e
	s.n = n
	s.dur = dur
	s.global_position = e.global_position
	e.world.fx_layer.add_child(s)


# ================================================================= the bot (autotest drive)

## A push for the play-test bot: off hot or warming stove tops, out of scalding broth and ink, away from the
## Dressmaker's whirling sheets.
static func bot_push(w: Node, pos: Vector2) -> Vector2:
	var out := Vector2.ZERO
	var r: Room = w.room
	var g := of(r)
	if g and g.theme == "kitchen":
		for s in g.stoves:
			if g.stove_state(s) != "cold":
				var c: Vector2 = r.cell_center(s["c"])
				var d := pos - c
				if d.length() < 20.0:
					out += d.normalized() * (20.0 - d.length()) / 20.0 * 4.0
	if r and is_instance_valid(r.floor_layer):
		for p in r.floor_layer.get_children():
			if p is Puddle:
				var d2: Vector2 = pos - p.global_position
				var reach: float = p.radius + 8.0
				if d2.length() < reach:
					out += d2.normalized() * (reach - d2.length()) / reach * (2.5 if p.kind == "scald" else 0.8)
	for s2 in w.fx_layer.get_children():
		if s2 is SpinSheets and s2.t > 0.3:
			var d3: Vector2 = pos - s2.global_position
			if d3.length() < 52.0:
				out += d3.normalized() * 1.8
	return out


# ================================================================= --checkrooms

## Every layout dressed as a room of each new area (3 seeds): light budget with every lantern lit, gimmicks clear
## of door slots and lanes, every sliding-shelf position keeps the room whole, the same seed gives the same room.
static func check() -> int:
	var stub_script := GDScript.new()
	stub_script.source_code = "extends Node2D\nvar actors := Node2D.new()\nvar hud = null\nvar room = null\nvar player = null\nvar enemies := []\nvar floor_num := 1\n"
	stub_script.reload()
	var stub: Node2D = stub_script.new()
	var errs := 0
	# the night's order (LONG_NIGHT.md): [Cellar, Crypt] + middle + [Belfry], the Chapel just before the upper areas
	var want_seq := {4: "cellar crypt chapel belfry", 5: "cellar crypt kitchen chapel belfry",
		6: "cellar crypt kitchen library chapel belfry", 7: "cellar crypt kitchen library chapel attic belfry"}
	for k in [3, 4, 5, 6, 7, 8, 10]:
		var got := " ".join(Areas.sequence(k))
		var want: String = want_seq[clampi(k, 4, Areas.max_floors())]
		if got != want:
			errs += 1
			print("[checkrooms] areas: sequence(%d) = %s, expected %s" % [k, got, want])
	for id in Areas.LIST:
		var d := Areas.def(id)
		if not d.get("built", false):
			continue
		for slot in ["e", "h", "f"]:
			for kind in (d["pool"] as Dictionary).get(slot, []):
				if not Enemy.DEFS.has(kind):
					errs += 1
					print("[checkrooms] areas: %s's pool names an unknown lodger %s" % [id, kind])
		for b in d["bosses"]:
			if not Enemy.DEFS.has(b) or not Enemy.DEFS[b].get("boss", false):
				errs += 1
				print("[checkrooms] areas: %s's guardian %s is not a guardian" % [id, b])
		if not Art.has("rooms/room_" + str(d["theme"])) or not ResourceLoader.exists("res://assets/audio/music/%s.ogg" % d["music"]):
			errs += 1
			print("[checkrooms] areas: %s has no room art or no music" % id)
	var n := 0
	var counts := {"stoves": 0, "rails": 0, "nooks": 0, "lanterns": 0, "pots": 0}
	var slots: Array[Rect2] = [Rect2(120, 0, 32, 32), Rect2(120, 176, 32, 16), Rect2(0, 88, 16, 32), Rect2(256, 88, 16, 32)]
	var layouts: Array = []
	for t in RoomTemplates.NORMAL:
		layouts.append(["normal", t["id"], t["rows"]])
	for k in ["start", "shop"]:
		layouts.append([k, k, RoomTemplates.START])
	layouts.append(["treasure", "treasure", RoomTemplates.TREASURE])
	layouts.append(["boss", "boss", RoomTemplates.BOSS])
	for th in THEMES:
		for L in layouts:
			for sd in [1, 77, 4242]:
				var mk := func() -> Room:
					var d := {"type": L[0], "grid": RoomTemplates.to_grid(L[2]), "cleared": true, "visited": true,
						"seen": true, "pickups": [], "seed": hash("%s:%s:%d" % [th, L[1], sd]), "dist": 3}
					var r := Room.new()
					r.build(stub, Vector2i.ZERO, d, th, {Vector2i.UP: "normal", Vector2i.DOWN: "boss", Vector2i.LEFT: "hidden", Vector2i.RIGHT: "treasure"})
					return r
				var r: Room = mk.call()
				n += 1
				var g := of(r)
				if g == null:
					errs += 1
					print("[checkrooms] %s %s: no area gimmicks" % [th, L[1]])
					continue
				var lights: int = r.decor.lights.size() + r.candles.size() + r._fires.size()
				for Lt in g.lanterns:
					if not Lt["lit"]:
						lights += 1
				if lights > RoomDecor.LIGHT_BUDGET:
					errs += 1
					print("[checkrooms] %s %s seed %d: %d lights with every lantern lit" % [th, L[1], sd, lights])
				var sprites: Array = []
				for Lt in g.lanterns:
					sprites.append(Rect2(Lt["pos"], Vector2(10, 15)))
				if not g.nook.is_empty() and not g.nook["hollow"]:
					sprites.append(Rect2(g.nook["pos"], Vector2(32, 30)))
				for rect in sprites:
					for sl in slots:
						if rect.intersects(sl):
							errs += 1
							print("[checkrooms] %s %s: a gimmick covers a door slot at %s" % [th, L[1], rect])
				for s in g.stoves:
					if s["c"] in RoomTemplates.LANES:
						errs += 1
						print("[checkrooms] %s %s: a stove top in a door lane %s" % [th, L[1], s["c"]])
				var rails: Array = []
				for rail in r.data.get("slide", []):
					rails.append(rail["cells"])
					for c in rail["cells"]:
						if c in RoomTemplates.LANES:
							errs += 1
							print("[checkrooms] %s %s: a shelf rail in a door lane %s" % [th, L[1], c])
				if not rails.is_empty():
					var base := RoomTemplates.to_grid(L[2])
					if not rails_ok(base, rails):
						errs += 1
						print("[checkrooms] %s %s seed %d: a sliding shelf can cut the room" % [th, L[1], sd])
				counts["stoves"] += g.stoves.size()
				counts["pots"] += g.steam.size()
				counts["rails"] += rails.size()
				counts["nooks"] += 0 if g.nook.is_empty() else 1
				counts["lanterns"] += g.lanterns.size()
				var r2: Room = mk.call()   # the same seed dresses the same room
				var g2 := of(r2)
				var sig := func(gg: AreaGimmicks) -> String:
					var st := []
					for s in gg.stoves:
						st.append(s["c"])
					var ln := []
					for Lt in gg.lanterns:
						ln.append(Lt["pos"])
					return str([st, gg.room.data.get("slide", []), gg.nook.get("pos", null), ln])
				if sig.call(g) != sig.call(g2):
					errs += 1
					print("[checkrooms] %s %s: area gimmicks are not deterministic" % [th, L[1]])
				for rr in [r, r2]:
					rr.objects.free()
					rr.free()
	stub.actors.free()
	stub.free()
	print("[checkrooms] areas: %d rooms, %s, %d problems" % [n, counts, errs])
	return errs
