class_name FloorGen
extends RefCounted
## Builds one floor: a branching grid of rooms with a start, a boss room at the farthest dead end,
## a treasure room and a shop. Returns {cells: {Vector2i: Dictionary}, start: Vector2i, boss: Vector2i}.

const W := 9
const H := 8
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


static func generate(floor_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var target := 6 + floor_num * 2
	for attempt in 200:
		var res := _try(floor_num, target, rng)
		if not res.is_empty():
			return res
	return _try(floor_num, 4, rng)


static func _neighbours(cells: Dictionary, c: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if cells.has(c + d):
			n += 1
	return n


static func _try(floor_num: int, target: int, rng: RandomNumberGenerator) -> Dictionary:
	var start := Vector2i(4, 4)
	var cells := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty() and cells.size() < target:
		var c: Vector2i = queue.pop_front()
		var dirs := DIRS.duplicate()
		dirs.shuffle()
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
	var need := 3
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
	rest.shuffle()
	var treasure: Vector2i = rest[0]
	var shop: Vector2i = rest[1]
	var out := {}
	for c in cells.keys():
		var type := "normal"
		if c == start:
			type = "start"
		elif c == boss:
			type = "boss"
		elif c == treasure:
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
