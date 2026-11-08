class_name FloorGen
extends RefCounted
## Builds one floor: a branching grid of rooms with a start, a boss room at the farthest dead end,
## a treasure room and a shop, a secret hollow, the special rooms (Specials.TYPES, each a new dead end
## off an ordinary room) and sometimes a mini-boss. Returns {cells: {Vector2i: Dictionary}, start, boss}.

const W := 9
const H := 8
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## Fisher-Yates with our own RNG so a seed always builds the same house.
static func shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func generate(floor_num: int, rng: RandomNumberGenerator, extra := 0, treasures := 1) -> Dictionary:
	if floor_num == Tower.FLOOR:
		return Tower.layout(rng)   # the Clock Tower: short, no shop, no special rooms
	var target := 6 + floor_num * 2 + extra
	for attempt in 200:
		var res := _try(floor_num, target, rng, treasures)
		if not res.is_empty():
			_add_hollow(res, rng)
			_add_specials(res, rng, floor_num)
			_add_mini(res, rng, floor_num)
			return res
	var fb := _try(floor_num, 4, rng, 1)
	_add_hollow(fb, rng)
	_add_specials(fb, rng, floor_num)
	_add_mini(fb, rng, floor_num)
	return fb


## Special rooms: each type rolls its own chance on its floors; it becomes a new dead end hanging off
## one ordinary room and touching nothing else (so the hollow, shop, treasure and boss rooms keep
## their places and walls). Runs after the hollow, from the same floor RNG.
static func _add_specials(res: Dictionary, rng: RandomNumberGenerator, floor_num: int) -> void:
	if res.is_empty() or "--nospecials" in OS.get_cmdline_user_args():   # balance baseline for the bot
		return
	var cells: Dictionary = res["cells"]
	for t in Specials.TYPES:
		var info: Dictionary = Specials.INFO[t]
		var roll := rng.randf()
		if not floor_num in info["floors"] or roll >= float(info["chance"]):
			continue
		var spots: Array = []
		for c in cells.keys():
			if cells[c]["type"] != "normal":
				continue
			for d in DIRS:
				var n: Vector2i = c + d
				if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or cells.has(n):
					continue
				if _neighbours(cells, n) != 1:
					continue
				spots.append([n, c])
		if spots.is_empty():
			continue
		var pick: Array = spots[rng.randi() % spots.size()]
		cells[pick[0]] = {"type": t, "grid": Specials.grid_for(t), "cleared": true, "visited": false,
			"seen": false, "pickups": [], "seed": rng.randi(), "dist": int(cells[pick[1]]["dist"]) + 1}


## Floors 2-4: one ordinary room away from the start may hold a mini-boss. Its layout becomes an
## open one so the champion has room to move.
static func _add_mini(res: Dictionary, rng: RandomNumberGenerator, floor_num: int) -> void:
	if res.is_empty() or floor_num < 2 or floor_num > 4 or "--nospecials" in OS.get_cmdline_user_args():
		return
	if rng.randf() >= Specials.MINI_CHANCE:
		return
	var cand: Array[Vector2i] = []
	for c in res["cells"].keys():
		var d: Dictionary = res["cells"][c]
		if d["type"] == "normal" and int(d["dist"]) >= 2:
			cand.append(c)
	var kinds := Specials.minis_for(floor_num)
	if cand.is_empty() or kinds.is_empty():
		return
	var c: Vector2i = cand[rng.randi() % cand.size()]
	var d: Dictionary = res["cells"][c]
	d["mini"] = kinds[rng.randi() % kinds.size()]
	var open: Array = RoomTemplates.NORMAL.filter(func(t): return "open" in t.get("tags", []) and not "hard" in t.get("tags", []) and not "spikes" in t.get("tags", []))
	if not open.is_empty():
		var rows: Array = (open[rng.randi() % open.size()]["rows"] as Array).duplicate()
		if rng.randf() < 0.5:
			for i in rows.size():
				rows[i] = (rows[i] as String).reverse()
		d["grid"] = RoomTemplates.to_grid(rows)


## One secret "hollow" per floor: an empty cell touching 2+ ordinary rooms (never the boss or start).
static func _add_hollow(res: Dictionary, rng: RandomNumberGenerator) -> void:
	if res.is_empty():
		return
	var cells: Dictionary = res["cells"]
	var best: Array[Vector2i] = []
	var fallback: Array[Vector2i] = []
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if cells.has(c):
				continue
			var n := 0
			var bad := false
			for d in DIRS:
				if cells.has(c + d):
					var t: String = cells[c + d]["type"]
					if t == "boss" or t == "start":
						bad = true
					n += 1
			if bad or n == 0:
				continue
			if n >= 2:
				best.append(c)
			elif n == 1:
				fallback.append(c)
	var pool := best if not best.is_empty() else fallback
	if pool.is_empty():
		return
	var h: Vector2i = pool[rng.randi() % pool.size()]
	cells[h] = {"type": "secret", "grid": RoomTemplates.to_grid(RoomTemplates.TREASURE), "cleared": true,
		"visited": false, "seen": false, "pickups": [], "seed": rng.randi(), "dist": 99, "revealed": false}


## Layout tags that keep a room "easy": no pits, spikes, fire, oil, webs, choke points or flyers.
const EASY_TAGS := ["open", "cover", "furniture"]


## A template's tier: "hard" (tagged so), "easy" (only EASY_TAGS and 2-3 lodger slots), or "normal".
static func tier_of_template(t: Dictionary) -> String:
	var tags: Array = t.get("tags", [])
	if "hard" in tags:
		return "hard"
	for tag in tags:
		if not tag in EASY_TAGS:
			return "normal"
	var n := slots_in("".join(t["rows"]))
	return "easy" if n >= 2 and n <= 3 else "normal"


static func slots_in(s: String) -> int:
	return s.count("e") + s.count("h") + s.count("f")


## The tier of an ordinary room as built: from its template id when the floor stored it, otherwise by
## matching its grid against every template and its mirror images (DesignCheck reads old layouts too).
static func tier_of(cell: Dictionary) -> String:
	if cell.has("tpl"):
		for t in RoomTemplates.NORMAL:
			if t["id"] == cell["tpl"]:
				return tier_of_template(t)
	var have := _grid_sig(cell["grid"])
	for t in RoomTemplates.NORMAL:
		var rows: Array = t["rows"]
		for flip in 4:
			var r := rows.duplicate()
			if flip & 1:
				for i in r.size():
					r[i] = (r[i] as String).reverse()
			if flip & 2:
				r.reverse()
			if _grid_sig(RoomTemplates.to_grid(r)) == have:
				return tier_of_template(t)
	return "?"


static func _grid_sig(g: Array) -> String:
	var s := ""
	for row in g:
		s += "".join(row)
	return s.replace("Q", "R").replace("Z", "U")


static func _neighbours(cells: Dictionary, c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if cells.has(c + d):
			n += 1
	return n


static func _try(floor_num: int, target: int, rng: RandomNumberGenerator, treasures := 1) -> Dictionary:
	var start := Vector2i(4, 4)
	var cells := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and cells.size() < target:
		var c: Vector2i = queue.pop_front()
		var dirs := DIRS.duplicate()
		shuffle(dirs, rng)
		for d in dirs:
			var n: Vector2i = c + d
			if cells.has(n) or n.x < 0 or n.y < 0 or n.x >= W or n.y >= H:
				continue
			if _neighbours(cells, n) > 1:
				continue
			if c != start and rng.randf() < 0.45:
				continue
			if cells.size() >= target:
				break
			cells[n] = true
			queue.append(n)
	if cells.size() < target:
		return {}
	var dead: Array[Vector2i] = []
	for c in cells.keys():
		if c != start and _neighbours(cells, c) == 1:
			dead.append(c)
	var need := 2 + treasures
	if dead.size() < need:
		return {}
	# BFS distances from start
	var dist := {start: 0}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in DIRS:
			var n: Vector2i = c + d
			if cells.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				q.append(n)
	dead.sort_custom(func(a, b): return dist[a] > dist[b])
	var boss: Vector2i = dead[0]
	if dist[boss] < 3:
		return {}
	var rest := dead.slice(1)
	shuffle(rest, rng)
	var treasure: Vector2i = rest[0]
	var shop: Vector2i = rest[1]
	var treasure2: Vector2i = rest[2] if treasures >= 2 and rest.size() > 2 else Vector2i(-99, -99)
	var out := {}
	for c in cells.keys():
		var type := "normal"
		if c == start:
			type = "start"
		elif c == boss:
			type = "boss"
		elif c == treasure or c == treasure2:
			type = "treasure"
		elif c == shop:
			type = "shop"
		var tpl: Array
		match type:
			"start", "shop": tpl = RoomTemplates.START
			"treasure": tpl = RoomTemplates.TREASURE
			"boss": tpl = RoomTemplates.BOSS
			_: tpl = RoomTemplates.pick_normal(rng, floor_num, dist[c])
		out[c] = {
			"type": type,
			"grid": RoomTemplates.to_grid(tpl),
			"cleared": type != "normal" and type != "boss",
			"visited": false,
			"seen": false,
			"pickups": [],
			"seed": rng.randi(),
			"dist": dist[c],
		}
	return {"cells": out, "start": start, "boss": boss, "floor": floor_num}
