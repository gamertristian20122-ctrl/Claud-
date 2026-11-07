class_name FloorGen
extends RefCounted
## Builds one floor: a branching grid of rooms with a start, a boss room at the farthest dead end,
## a treasure room and a shop. Returns {cells: {Vector2i: Dictionary}, start: Vector2i, boss: Vector2i}.

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
	var target := 6 + floor_num * 2 + extra
	for attempt in 200:
		var res := _try(floor_num, target, rng, treasures)
		if not res.is_empty():
			_add_hollow(res, rng)
			return res
	var fb := _try(floor_num, 4, rng, 1)
	_add_hollow(fb, rng)
	return fb


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
			_: tpl = RoomTemplates.pick_normal(rng)
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
