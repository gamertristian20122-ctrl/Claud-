extends Node
## Automated play-test bot + screenshot tour.
##   -- --autotest --playtest [--runs=N] [--speed=4] [--seed=N]   plays full runs, prints a summary
##   -- --autotest --tour --shots=/abs/dir                         screenshots of every screen

var main: Node
var args := {}
var mode := "playtest"
var runs_left := 1
var results: Array = []
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _shots_dir := ""
var _shot_i := 0
var _bomb_cd := 0.0
var _room_t := 0.0
var _room_t_total := 0.0
var _last_cell := Vector2i(-99, -99)


func _ready() -> void:
	main = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1]
		elif a.begins_with("--"):
			args[a.substr(2)] = true
	if args.has("tour"):
		mode = "tour"
	runs_left = int(args.get("runs", "1"))
	_shots_dir = str(args.get("shots", ""))
	Game.base_time_scale = float(args.get("speed", "1"))
	Engine.time_scale = Game.base_time_scale
	Game.settings["aim_assist"] = true
	await get_tree().create_timer(0.8).timeout
	if mode == "tour":
		_tour()
	else:
		_next_run()


func _next_run() -> void:
	while main._busy:
		await get_tree().process_frame
	var params := {}
	if args.has("unlockall"):
		Game.records["unlocked"] = Candles.ORDER.duplicate()
	if args.has("candle"):
		params["candle"] = str(args["candle"])
	if args.has("seed"):
		params["seed"] = int(args["seed"]) + results.size()
	main.goto("game", params)


var _status_t := 0.0


func _process(dt: float) -> void:
	if mode != "playtest":
		return
	var cur: Node = main.current
	_status_t += dt
	if _status_t > 10.0 and cur and cur.name == "Game":
		_status_t = 0.0
		var w: Node = cur
		print("[status] t=%.0f floor=%d cell=%s type=%s cleared=%s wax=%.1f enemies=%d coins=%d bombs=%d relics=%d pos=%s" % [w.run_time, w.floor_num, w.cur_cell, w.room.data["type"], w.room.data["cleared"], w.player.wax, w.count_enemies(), w.player.coins, w.player.bombs, w.player.relics.size(), w.player.global_position - w.room.position])
		if w.count_enemies() > 0 and _room_t_total > 15.0:
			var lst := []
			for e in w.enemies:
				if is_instance_valid(e) and e.alive:
					lst.append("%s@%s act=%s st=%s cell=%s" % [e.kind, (e.global_position - w.room.position).round(), e.active, e.state, w.room.char_at(w.room.cell_of(e.global_position - w.room.position))])
			print("   [enemies] ", lst, " grid=", w.room.data["grid"])
	if cur and cur.name == "Results" and cur.get("params") != null and not cur.get_meta("logged", false):
		cur.set_meta("logged", true)
		var p: Dictionary = cur.params
		results.append(p)
		print("[playtest] run %d: %s floor=%d clock=%s kills=%d rooms=%d time=%.0fs relics=%s" % [
			results.size(), "WIN" if p["won"] else "LOSS", p["floor"], Game.clock_text(p["clock"]), p["kills"], p["rooms"], p["time"], p["relics"]])
		print("[playtest]    best streak x%d, hits %d" % [p.get("streak", 0), p.get("hits", 0)])
		runs_left -= 1
		if runs_left > 0:
			await get_tree().create_timer(0.5).timeout
			_next_run()
		else:
			var wins := results.filter(func(r): return r["won"]).size()
			var avg_floor := 0.0
			for r in results:
				avg_floor += r["floor"]
			print("[playtest] SUMMARY runs=%d wins=%d avg_floor=%.2f" % [results.size(), wins, avg_floor / results.size()])
			get_tree().quit()


## Called by the world every physics frame: returns [move, aim] or [] to leave input alone.
func drive(w: Node) -> Array:
	if mode == "tour" and not args.has("drive"):
		return []
	var p: Player = w.player
	if args.has("god") and p:
		p.wax = maxf(p.wax, 80.0)
	if p == null or p.dead or w.transitioning:
		return [Vector2.ZERO, Vector2.ZERO]
	var dt := w.get_physics_process_delta_time()
	_bomb_cd -= dt
	if w.cur_cell != _last_cell:
		_last_cell = w.cur_cell
		_room_t = 0.0
		_room_t_total = 0.0
	_room_t_total += dt
	if w.count_enemies() > 0:
		_room_t = 0.0
	_room_t += dt
	var pos := p.global_position
	if args.has("trace") and Engine.get_physics_frames() % 30 == 0:
		print("[trace] cell=%s lp=%s exit=%s open=%s doors=%s frozen=%s trans=%s" % [w.cur_cell, pos - w.room.position, w.room.door_exit(pos), w.room.is_open, w.room.doors.keys(), p.frozen, w.transitioning])
	# stuck handling
	if pos.distance_to(_last_pos) < 0.3:
		_stuck_t += dt
	else:
		_stuck_t = 0.0
	_last_pos = pos
	if _stuck_t > 1.0:
		_wander = Vector2.from_angle(randf() * TAU)
		_wander_t = 0.5
		_stuck_t = 0.0
	if _wander_t > 0:
		_wander_t -= dt
		var tgt0: Enemy = w.nearest_enemy(pos)
		return [_wander, (tgt0.global_position - pos).normalized() if tgt0 else Vector2.ZERO]
	var tgt: Enemy = w.nearest_enemy(pos)
	if tgt:
		var to: Vector2 = tgt.global_position + Vector2(0, -tgt.half_h) - (pos + Vector2(0, -6))
		var d := to.length()
		var mv := Vector2.ZERO
		if _room_t_total > 12.0 and d > 30:
			mv = to.normalized()
		elif d > 85:
			mv = to.normalized() * 0.7
		else:
			mv = to.normalized().orthogonal() * (1.0 if int(Time.get_ticks_msec() / 1500) % 2 == 0 else -1.0) * 0.6
		# keep away from every enemy body (contact damage) ...
		for e in w.enemies:
			if not is_instance_valid(e) or not e.alive:
				continue
			var rel: Vector2 = pos - e.global_position
			var dd := rel.length()
			var safe: float = 34.0 + e.radius * 2.0
			if dd < safe and dd > 0.1:
				mv += rel / dd * (safe - dd) / safe * 2.2
		# ... and from bullets heading our way
		for sh in w.enemy_shots:
			if not is_instance_valid(sh):
				continue
			var rel2: Vector2 = pos + Vector2(0, -8) - sh.global_position
			var d2 := rel2.length()
			if d2 < 36 and sh.vel.dot(rel2) > 0:
				var side: Vector2 = sh.vel.normalized().orthogonal()
				mv += side * signf(side.dot(rel2) + 0.001) * (36.0 - d2) / 36.0 * 2.5
		# drift back toward the middle so we do not hug walls
		var c: Vector2 = w.room.center()
		if pos.distance_to(c) > 80:
			mv += (c - pos).normalized() * 0.5
		if w.keepsake_full() and (w.count_enemies() >= 3 or (w.boss and is_instance_valid(w.boss))):
			w.use_keepsake()
		if w.boss and is_instance_valid(w.boss) and p.bombs > 0 and _bomb_cd <= 0 and pos.distance_to(w.boss.global_position) < 30:
			_bomb_cd = 3.0
			w.place_bomb()
		return [mv.normalized(), to.normalized()]
	# room is clear: pick up what is worth picking up
	var pick := _best_pickup(w, p) if _room_t < 9.0 else null
	if pick:
		return [(pick.global_position - pos).normalized(), Vector2.ZERO]
	# break urns/crates near the path occasionally is skipped; head to the next room
	var dir := _next_dir(w)
	if dir == Vector2i.ZERO:
		return [Vector2.ZERO, Vector2.ZERO]
	var door_cell: Vector2i
	var exit_pt: Vector2
	match dir:
		Vector2i.UP:
			door_cell = Vector2i(7, 0)
			exit_pt = w.room.position + Vector2(136, 20)
		Vector2i.DOWN:
			door_cell = Vector2i(7, 8)
			exit_pt = w.room.position + Vector2(136, 190)
		Vector2i.LEFT:
			door_cell = Vector2i(0, 4)
			exit_pt = w.room.position + Vector2(4, 106)
		_:
			door_cell = Vector2i(14, 4)
			exit_pt = w.room.position + Vector2(268, 106)
	var room: Room = w.room
	var my_cell := room.cell_of(pos - room.position)
	if _room_t_total > 20.0 and Engine.get_physics_frames() % 120 == 0:
		print("   [nav] cell=%s dir=%s my=%s door=%s next=%s grid=%s" % [w.cur_cell, dir, my_cell, door_cell, _path_next(room, my_cell, door_cell), room.data["grid"]])
	if my_cell == door_cell or my_cell.x < 0 or my_cell.y < 0 or my_cell.x >= Room.COLS or my_cell.y >= Room.ROWS:
		return [(exit_pt - pos).normalized(), Vector2.ZERO]
	var wp := _path_next(room, my_cell, door_cell)
	var goal: Vector2 = room.cell_center(wp) + Vector2(0, 2)
	return [(goal - pos).normalized(), Vector2.ZERO]


## BFS over the room grid; returns the next cell to walk to (or the goal itself).
func _path_next(room: Room, from: Vector2i, to: Vector2i) -> Vector2i:
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for d in FloorGen.DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or n.x < 0 or n.y < 0 or n.x >= Room.COLS or n.y >= Room.ROWS:
				continue
			if room.char_at(n) in Room.SOLID:
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(to):
		return to
	var step := to
	while prev[step] != from:
		step = prev[step]
	return step


func _best_pickup(w: Node, p: Player) -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for o in w.room.objects.get_children():
		if not (o is Pickup) or o.taken or o.opened:
			continue
		if o.kind in ["wax_small", "wax_big"] and p.wax >= p.wax_max - 1:
			continue
		if o.kind == "trapdoor":
			continue
		if o.price > 0 and p.coins < int(round(o.price * w.shop_discount)):
			continue
		if o.record and int(o.record.get("cost_wax", 0)) > 0 and p.wax_max - int(o.record["cost_wax"]) < 90:
			continue
		var d: float = o.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = o
	if best == null:
		for o in w.room.objects.get_children():
			if o is Pickup and o.kind == "trapdoor":
				return o
	return best


func _next_dir(w: Node) -> Vector2i:
	var cells: Dictionary = w.layout["cells"]
	var start: Vector2i = w.cur_cell
	# BFS to the nearest unvisited room; the boss room last
	var prev := {start: start}
	var q: Array[Vector2i] = [start]
	var goal := Vector2i(-1, -1)
	var boss_cell := Vector2i(-1, -1)
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if cells[c]["type"] == "secret" and not cells[c].get("revealed", false):
			continue
		if c != start and not cells[c]["visited"]:
			if cells[c]["type"] == "boss":
				boss_cell = c
			elif goal == Vector2i(-1, -1):
				goal = c
				break
		for d in FloorGen.DIRS:
			var n: Vector2i = c + d
			if cells.has(n) and not prev.has(n):
				prev[n] = c
				q.append(n)
	if goal == Vector2i(-1, -1):
		goal = boss_cell
	if goal == Vector2i(-1, -1):
		return Vector2i.ZERO
	var step := goal
	while prev[step] != start:
		step = prev[step]
	return step - start


# ---------------------------------------------------------------- tour

func _shot(name: String) -> void:
	if _shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_i += 1
	img.save_png("%s/%02d_%s.png" % [_shots_dir, _shot_i, name])
	print("[tour] shot ", name)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _jump(w: Node, c: Vector2i) -> void:
	w.cur_cell = c
	w.room.dispose()
	w.room = w._build_room(c)
	w.player.position = w.room.center() + Vector2(0, 40)
	w.cam.position = w._cam_target(w.room)
	w._on_enter_room()


func _tour() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	await _wait(1.0)
	await _shot("title")
	main.goto("game", {"seed": 7})
	await _wait(1.6)
	await _shot("start_room")
	var w: Node = main.current
	args["drive"] = true
	# let the bot play a while and take pictures along the way
	for i in 10:
		await _wait(2.5)
		await _shot("play_%d" % i)
	w.toggle_pause()
	await _wait(0.4)
	await _shot("pause")
	w.toggle_pause()
	args.erase("drive")
	for t in ["treasure", "shop"]:
		for c in w.layout["cells"].keys():
			if w.layout["cells"][c]["type"] == t:
				_jump(w, c)
				await _wait(1.2)
				w.player.position = w.room.center() + Vector2(-26, 22)
				await _wait(0.6)
				await _shot(t)
				break
	args["drive"] = true
	# jump straight to the final boss for a look
	w.player.wax = 60.0
	w._start_floor(4)
	var bcell: Vector2i = w.layout["boss"]
	await _wait(0.5)
	w.cur_cell = bcell
	w.room.dispose()
	w.room = w._build_room(bcell)
	w.player.position = w.room.center() + Vector2(0, 40)
	w.cam.position = w._cam_target(w.room)
	w._on_enter_room()
	await _wait(3.0)
	await _shot("boss")
	await _wait(3.0)
	await _shot("boss_2")
	w.player.wax = 0.0
	await _wait(7.0)
	await _shot("results")
	get_tree().quit()
