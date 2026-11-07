extends Node
## Automated play-test bot + screenshot tour.
##   -- --autotest --playtest [--runs=N] [--speed=4] [--seed=N]   plays full runs, prints a summary
##        [--god] [--stress] [--unlockall --candle=id] [--relics=a,b] [--savecycle: Save & quit + Continue each floor]
##   -- --autotest --tour --shots=/abs/dir                         screenshots of every screen
##   -- --autotest --audiotest                                     audio catalogue + live-mix check (audio_check.gd)
##   -- --autotest --herosheet --shots=/abs/dir                    Tallow in every juice state (pixel check)
##   -- --autotest --tour --rooms --shots=/abs/dir                 three dressed rooms on every floor
##   -- --autotest --bench [--secs=6] [--seed=N] [--ablate]        busiest rooms: CPU per physics step / frame, lights, leaks
##                                                                 (--ablate: floor 1 again with each script group switched off)

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
		if not args.has("platform") and not args.has("device"):
			Controls.set_device(Controls.TOUCH)   # the main tour shows the phone HUD
	if args.has("audiotest"):
		mode = "audiotest"
	if args.has("bench"):
		mode = "bench"
	runs_left = int(args.get("runs", "1"))
	_shots_dir = str(args.get("shots", ""))
	Game.base_time_scale = float(args.get("speed", "1"))
	Engine.time_scale = Game.base_time_scale
	Game.settings["aim_assist"] = true
	await get_tree().create_timer(0.8).timeout
	if args.has("herosheet"):
		_hero_sheet()
	elif mode == "tour" and args.has("relictour"):
		_relic_tour()
	elif mode == "tour":
		_tour()
	elif mode == "audiotest":
		add_child(load("res://scripts/audio_check.gd").new())
	elif mode == "bench":
		_bench()
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
	_cycled = -1
	main.goto("game", params)
	if args.has("relics") or args.has("keepsake"):
		# wait for the new run (the screen fade can take longer than a fixed delay)
		var waited := 0.0
		while waited < 8.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		_grant(main.current)


## --relics=a,b,c gives those relics at the start; --keepsake=id hands over a full keepsake.
func _grant(w: Node) -> void:
	if w == null or w.get("player") == null:
		return
	for id in str(args.get("relics", "")).split(",", false):
		if not Items.RELICS.has(id):
			print("[playtest] unknown relic ", id)
		elif not id in w.player.relics:
			w.collect_item(id, w.player.global_position)
	print("[playtest] granted ", w.player.relics)
	if args.has("keepsake") and Items.KEEPSAKES.has(str(args["keepsake"])):
		w.player.keepsake = str(args["keepsake"])
		w.player.charge = int(Items.KEEPSAKES[w.player.keepsake]["pips"])


var _status_t := 0.0
var _stress_cell := Vector2i(-99, -99)
var _cycled := -1
var _cycling := false


func _save_cycle() -> void:
	_cycling = true
	await get_tree().create_timer(0.8).timeout
	var w: Node = main.current
	# compare with the floor-start snapshot (relics picked up since then are not in it, by design)
	var pd: Dictionary = RunSave.snap.get("player", {})
	var before: String = "snapshot relics %d wax %.0f" % [pd.get("relics", []).size(), float(pd.get("wax", 0.0))]
	RunSave.flush()
	main.goto("title")
	await get_tree().create_timer(1.6).timeout
	RunSave.continue_run(main)
	var waited := 0.0
	while waited < 8.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	await get_tree().create_timer(0.5).timeout
	w = main.current
	_stress_cell = w.cur_cell   # the restored run must match its snapshot exactly (no stress relic yet)
	print("[savecycle] floor %d: %s -> %s (floor %d)" % [_cycled, before, "relics %d wax %.0f" % [w.player.relics.size(), w.player.wax], w.floor_num])
	_cycling = false


func _process(dt: float) -> void:
	if mode != "playtest":
		return
	var cur: Node = main.current
	_status_t += dt
	# --stress: a random relic in every new room, so every combination gets played
	if args.has("stress") and not _cycling and cur and cur.name == "Game" and cur.get("player") and not cur.finished and cur.cur_cell != _stress_cell:
		_stress_cell = cur.cur_cell
		var left: Array = Items.RELICS.keys().filter(func(k): return not k in cur.player.relics)
		if not left.is_empty():
			cur.collect_item(left[randi() % left.size()], cur.player.global_position)
	# --savecycle: at the start of floors 2-4, Save & quit to the title and Continue (Save & Continue
	# gets played with whatever the run holds; with --stress that is a lot of relics)
	if args.has("savecycle") and not _cycling and cur and cur.name == "Game" and cur.get("player") and not cur.finished \
			and cur.floor_num >= 2 and cur.floor_num != _cycled and RunSave.has_snapshot() \
			and int(RunSave.snap["run"].get("floor", 0)) == cur.floor_num:
		_cycled = cur.floor_num
		_save_cycle()
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
		var parts: Array = []
		for f in _diag.keys():
			var d: Array = _diag[f]
			parts.append("f%d %ds hits %d lost %d gained %d" % [f, d[0], d[1], d[2], d[3]])
		print("[diag]    ", " | ".join(parts))
		var src: Array = _diag_src.keys()
		src.sort_custom(func(a, b): return _diag_src[a] > _diag_src[b])
		print("[diag]    hit by ", src.slice(0, 6).map(func(k): return "%s %d" % [k, _diag_src[k]]))
		_diag_src = {}
		_diag = {}
		_diag_wax = -1.0
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
			Audio.stop_all()   # no playback left running at exit (keeps the log free of leak warnings)
			await get_tree().create_timer(0.3, true, false, true).timeout
			get_tree().quit()


## Called by the world every physics frame: returns [move, aim] or [] to leave input alone.
func drive(w: Node) -> Array:
	if (mode == "tour" or mode == "audiotest") and not args.has("drive"):
		return []
	var p: Player = w.player
	if args.has("god") and p:
		p.wax = maxf(p.wax, 80.0)
	_diag_tick(w, p)
	if p == null or p.dead or w.transitioning:
		return [Vector2.ZERO, Vector2.ZERO]
	var dt := w.get_physics_process_delta_time()
	_bomb_cd -= dt
	if w.cur_cell != _last_cell:
		_last_cell = w.cur_cell
		_room_t = 0.0
		_room_t_total = 0.0
	_room_t_total += dt
	if _room_t_total > 120.0 and _room_t_total - dt <= 120.0:   # a soft-lock shows up in the log
		print("[stuck] 120 s in floor %d room %s (%s, cleared=%s, enemies %d)" % [w.floor_num, w.cur_cell, w.room.data["type"], w.room.data["cleared"], w.count_enemies()])
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
	var tgt: Enemy = w.nearest_enemy(pos) if _room_t_total < 25.0 else _toughest(w)   # summoners first when a room drags on
	if tgt:
		if _room_t_total > 30.0 and p.bombs > 0 and _bomb_cd <= 0 and pos.distance_to(tgt.global_position) < 40:
			_bomb_cd = 4.0
			w.place_bomb()
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
	if pick == null and w.room.data["type"] == "boss" and w.room.data["cleared"] and _next_dir(w) == Vector2i.ZERO:
		for o in w.room.objects.get_children():
			if o is Pickup and o.kind == "trapdoor":
				pick = o
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


## Per floor: seconds, hits, wax lost to hits and wax gained back (printed with each result).
var _diag := {}
var _diag_wax := -1.0
var _diag_floor := 0
var _diag_src := {}   # what hit us: the touching foe's kind, or "shot or hazard" (shots are gone by the next frame)


func _hit_source(w: Node, p: Player) -> String:
	var at: Vector2 = p.global_position
	for e in w.enemies:
		if is_instance_valid(e) and e.alive and e.global_position.distance_to(at) < e.radius + 8.0:
			return e.kind
	for sh in w.enemy_shots:
		if is_instance_valid(sh) and (sh.global_position - (at + Vector2(0, -6))).length() < 14.0:
			return "shot:" + str(sh.get("kind")) if sh.get("kind") != null else "shot"
	return "shot or hazard"


func _diag_tick(w: Node, p: Player) -> void:
	if p == null or p.dead or mode != "playtest":
		return
	var f: int = w.floor_num
	var d: Array = _diag.get(f, [0.0, 0, 0.0, 0.0])
	if _diag_wax >= 0.0 and f == _diag_floor:
		var dw: float = p.wax - _diag_wax
		if dw < -0.5:
			d[1] += 1
			d[2] += -dw
			_diag_src[_hit_source(w, p)] = int(_diag_src.get(_hit_source(w, p), 0)) + 1
		elif dw > 0.05:
			d[3] += dw
	d[0] += w.get_physics_process_delta_time()
	_diag[f] = d
	_diag_floor = f
	_diag_wax = p.wax


## The living foe with the most max HP (a summoner that keeps a room from ever clearing).
func _toughest(w: Node) -> Enemy:
	var best: Enemy = null
	for e in w.enemies:
		if is_instance_valid(e) and e.alive and e.active and (best == null or e.max_hp > best.max_hp):
			best = e
	return best if best else w.nearest_enemy(w.player.global_position)


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


func _can_walk(room: Room, from: Vector2i, to: Vector2i) -> bool:
	if from == to or room.char_at(to) == "#":
		return true
	return _path_next(room, from, to) != to or _adjacent(from, to)


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


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
		if not _can_walk(w.room, w.room.cell_of(p.global_position - w.room.position), w.room.cell_of(o.global_position - w.room.position)):
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
	if goal == Vector2i(-1, -1) and start != w.layout["boss"] and prev.has(w.layout["boss"]):
		goal = w.layout["boss"]   # everything explored after an early boss: go back to its trapdoor
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


## One cleared, dressed room of every floor (all four themes).
func _theme_shots(w: Node) -> void:
	for n in [1, 2, 3, 4]:
		w._start_floor(n)
		await _wait(2.9)   # let the floor banner clear
		var c := _normal_cells(w)[0] as Vector2i
		w.layout["cells"][c]["cleared"] = true
		_jump(w, c)
		w.player.position = w.room.center() + Vector2(0, 10)
		w.player.wax = 100.0
		await _wait(1.0)
		await _shot("floor_%d_%s" % [n, w.FLOORS[n]["theme"]])


## Three hand-picked layouts per floor showing the new props and hazards.
func _room_tour(w: Node) -> void:
	var picks := {1: ["storeroom", "web_corners", "oil_cellar", "fireplaces"], 2: ["coffin_rows", "bone_yard", "soot_vaults", "twin_holes"],
		3: ["aisle", "hearth_hall", "pew_rows", "crate_fort"], 4: ["long_pews", "braziers", "spike_crossing", "bell_shafts"]}
	for n in [1, 2, 3, 4]:
		w._start_floor(n)
		await _wait(2.9)
		var cells := _normal_cells(w)
		var i := 0
		for id in picks[n]:
			var c: Vector2i = cells[i % cells.size()]
			i += 1
			for t in RoomTemplates.NORMAL:
				if t["id"] == id:
					w.layout["cells"][c]["grid"] = RoomTemplates.to_grid(t["rows"])
			w.layout["cells"][c]["cleared"] = i % 2 == 1
			_jump(w, c)
			w.player.position = w.room.center() + Vector2(0, 10)
			w.player.wax = 100.0
			await _wait(1.2)
			await _shot("room_%d_%s" % [n, id])
			if id == "oil_cellar":   # set one jar off and catch the fireball
				for y in Room.ROWS:
					for x in Room.COLS:
						if w.room.char_at(Vector2i(x, y)) == "O" and y < 4:
							w.room.damage_obstacle(Vector2i(x, y), 1.0)
							await _wait(0.12)
							await _shot("room_%d_%s_blast" % [n, id])
							break


func _normal_cells(w: Node) -> Array:
	var out := []
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] == "normal":
			out.append(c)
	out.sort()
	return out


func _tour() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	if args.has("platform"):
		await _platform_tour()
		get_tree().quit()
		return
	if args.has("gallery") or args.has("bosses"):
		await _wait(1.0)
		await BestiaryGallery.tour(self)
		get_tree().quit()
		return
	await _wait(0.25)
	await _shot("title_intro")
	await _wait(1.8)
	await _shot("title")
	main.goto("game", {"seed": 7})
	await _wait(0.28)
	await _shot("burn_cover")
	await _wait(0.42)
	await _shot("burn_reveal")
	await _wait(0.9)
	await _shot("start_room")
	var w: Node = main.current
	w.player.keepsake = "hand_bell"
	w.player.charge = 2
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
	await _tour_juice(w)
	await _theme_shots(w)
	if args.has("rooms"):
		await _room_tour(w)
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
	await _wait(0.55)
	await _shot("boss_card")
	await _wait(1.9)
	await _shot("boss_punch")
	await _wait(2.5)
	await _shot("boss")
	await _wait(3.0)
	await _shot("boss_2")
	# the finale: flashes, poofs, slow-motion, one huge splat
	if w.boss and is_instance_valid(w.boss):
		w.boss.active = true
		w.boss.take_hit(99999.0, Vector2.ZERO)
		await _wait(0.5)
		await _shot("boss_finale")
		await _wait(1.2)
		await _shot("boss_splat")
	await _wait(6.0)
	await _shot("results")
	Audio.stop_all()
	await _wait(0.3)
	get_tree().quit()


# ---------------------------------------------------------------- platform tour (--tour --platform)
# Save & Continue round trip (prints any stat that did not come back exactly), keyboard / gamepad
# input through the InputMap, gamepad focus in menus, settings pages, achievements. Run it at
# several window sizes: the shot names carry the game's visible size (e.g. 426x266 = 1280x800).

func _vs() -> String:
	var s := get_viewport().get_visible_rect().size
	return "%dx%d" % [s.x, s.y]


func _press(action: String, s: float) -> void:
	Input.action_press(action)
	await _wait(s)
	Input.action_release(action)


func _ui(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(0.2)


func _pad(b: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await _wait(0.2)


func _layout_sig(w: Node) -> String:
	var parts: Array = []
	for c in w.layout["cells"].keys():
		parts.append("%s:%s" % [c, w.layout["cells"][c]["type"]])
	parts.sort()
	return ",".join(parts)


func _platform_tour() -> void:
	var tag := _vs()
	var fails := 0
	print("[platform] visible size ", tag, "  window ", DisplayServer.window_get_size(), "  pixel scale ", Controls.pixel_scale())
	Controls.set_device(Controls.PAD)
	# a run with relics, a rite, a keepsake and coins, moved on to floor 3
	main.goto("game", {"seed": 11})
	await _wait(1.6)
	var w: Node = main.current
	var p: Player = w.player
	for id in ["blue_flame", "moth_friend", "twin_wick", "candelabra", "sharp_wick", "matchbook"]:
		w.collect_item(id, p.global_position)
	Items.apply("flask_red", p, w)
	p.coins = 17
	p.keepsake = "winding_key"
	p.charge = 4
	p.wax = 81.0
	w.kills = 23
	await _wait(0.4)
	w._start_floor(3)
	await _wait(0.6)
	var sig := _layout_sig(w)
	var before: Dictionary = RunSave.snap.duplicate(true)
	print("[platform] saved: ", RunSave.summary(), "  relics=", p.relics, " rites=", p.rites, " omen=", w.omen)
	main.goto("title")
	await _wait(1.4)
	await _shot("title_continue_" + tag)
	SettingsPanel.open(main.current.root)
	await _wait(0.5)
	await _shot("settings_game_" + tag)
	await _ui("ui_page_next")
	await _ui("ui_down")
	await _shot("settings_controls_" + tag)
	await _ui("ui_cancel")
	Achievements.open_list(main.current.root)
	await _wait(0.5)
	await _shot("achievements_" + tag)
	await _ui("ui_cancel")
	await _wait(0.3)
	# Continue: the same floor, the same stats
	RunSave.continue_run(main)
	await _wait(1.8)
	w = main.current
	p = w.player
	var after: Dictionary = RunSave.snap
	for sec in ["player", "world"]:
		for k in before[sec]:
			if str(before[sec][k]) != str(after[sec].get(k)):
				fails += 1
				print("[platform] MISMATCH %s.%s: %s -> %s" % [sec, k, before[sec][k], after[sec].get(k)])
	for k in ["run_seed", "floor", "candle", "omen", "daily"]:
		if str(before["run"][k]) != str(after["run"][k]):
			fails += 1
			print("[platform] MISMATCH run.%s: %s -> %s" % [k, before["run"][k], after["run"][k]])
	if _layout_sig(w) != sig:
		fails += 1
		print("[platform] MISMATCH layout")
	if w.moths.size() != 1:
		fails += 1
		print("[platform] MISMATCH moths: ", w.moths.size())
	print("[platform] continue restored floor %d, relics %s, rites %s, wax %.1f, coins %d" % [w.floor_num, p.relics, p.rites, p.wax, p.coins])
	await _shot("continued_" + tag)
	# keyboard input runs through the InputMap into the HUD vectors
	Controls.set_device(Controls.KEYS)
	var x0 := p.global_position.x
	await _press("move_right", 0.5)
	if p.global_position.x <= x0 + 4.0:
		fails += 1
		print("[platform] FAIL move_right did not move Tallow")
	var shots := 0
	Input.action_press("shoot_up")
	for i in 20:
		await get_tree().physics_frame
		for s in w.fx_layer.get_children():
			if s is Shot and s.friendly:
				shots += 1
	Input.action_release("shoot_up")
	if shots == 0:
		fails += 1
		print("[platform] FAIL shoot_up fired nothing")
	var b0: int = p.bombs
	await _press("bomb", 0.1)
	if p.bombs != b0 - 1:
		fails += 1
		print("[platform] FAIL bomb %d -> %d" % [b0, p.bombs])
	await _press("move_left", 0.9)
	await _wait(1.2)
	await _shot("play_keyboard_" + tag)
	# a real gamepad press: Start pauses (and switches the HUD to gamepad), the d-pad moves, B resumes
	await _pad(JOY_BUTTON_START)
	await _wait(0.5)
	if not w.paused or Controls.device != Controls.PAD:
		fails += 1
		print("[platform] FAIL Start: paused=%s device=%s" % [w.paused, Controls.device])
	await _shot("pause_gamepad_" + tag)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var f := get_viewport().gui_get_focus_owner()
	if not (f is Button and (f as Button).text == "Settings"):
		fails += 1
		print("[platform] FAIL d-pad down focus: ", f)
	await _shot("pause_gamepad_down_" + tag)
	await _pad(JOY_BUTTON_B)
	await _wait(0.3)
	if w.paused:
		fails += 1
		print("[platform] FAIL B did not resume")
	Achievements.show_toast("boss_cellar")
	await _wait(0.45)
	await _shot("toast_" + tag)
	await _wait(2.4)
	# giving up ends the run, and the saved run with it
	w.toggle_pause()
	await _wait(0.2)
	w.give_up()
	await _wait(4.5)
	await _shot("results_" + tag)
	if RunSave.has_snapshot():
		fails += 1
		print("[platform] FAIL the snapshot survived the end of the run")
	# back, back: results -> title -> "blow out the candle?" (desktop)
	await _ui("ui_cancel")
	await _wait(1.4)
	await _ui("ui_cancel")
	await _wait(0.4)
	await _shot("quit_prompt_" + tag)
	print("[platform] DONE fails=%d" % fails)
## Juice tour shots: gibs in flight, floor stains, a relic held aloft, the melt-down.
func _tour_juice(w: Node) -> void:
	var pick: Vector2i = w.cur_cell
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] == "normal" and c != w.cur_cell:
			pick = c
			if not w.layout["cells"][c]["cleared"]:
				break   # an uncleared room, so the clear burst shows too
	_jump(w, pick)
	await _wait(0.8)
	for e in w.enemies:
		if is_instance_valid(e):
			e.queue_free()
	w.enemies.clear()
	var kinds := ["slug", "skelet", "chort", "pumpkin_dude", "goblin", "ice_zombie", "muddy", "imp"]
	var c0: Vector2 = w.room.center()
	for i in kinds.size():
		var e: Enemy = w.spawn_enemy(kinds[i], c0 + Vector2(-84 + 24 * i, -30 + 26 * (i % 2)))
		await get_tree().process_frame
		e.active = true
		e.take_hit(999.0, Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 60.0)
	w.player.position = c0 + Vector2(0, 40)
	await _wait(0.12)
	await _shot("gibs")
	await _wait(0.2)
	await _shot("room_clear")
	w.place_bomb()
	await _wait(2.4)
	await _shot("stains")
	# stains stay on the floor: leave the room and come back
	var sc: Vector2i = w.cur_cell
	for c in w.layout["cells"].keys():
		if c != sc and w.layout["cells"][c]["type"] == "start":
			_jump(w, c)
			break
	await _wait(0.4)
	_jump(w, sc)
	await _wait(0.5)
	await _shot("stains_return")
	# a relic held aloft
	w.collect_item("blue_flame" if Items.RELICS.has("blue_flame") else Items.RELICS.keys()[0], w.player.global_position)
	await _wait(0.35)
	await _shot("relic_aloft")
	await _wait(1.0)
	# the melt-down (shown without ending the run)
	var p: Player = w.player
	p.dead = true
	p._melt_from = p.body_height()
	await _wait(0.45)
	await _shot("melt_1")
	await _wait(0.55)
	await _shot("melt_2")
	p.dead = false
	p._melt = 0.0
	p._popped = false
	p._stained = false
	p._melt_from = -1
	p.face.visible = true


## Tallow in every juice state side by side (squash, stretch, flash, drips, guttering, holding, melting).
func _hero_sheet() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#483b3a")
	bg.size = Vector2(480, 216)
	layer.add_child(bg)
	var ps: Array = []
	for i in 12:
		var p := Player.new()
		p.world = null
		p.position = Vector2(20 + (i % 6) * 34, 60 + (i / 6) * 70)
		layer.add_child(p)
		p.set_physics_process(false)
		p.light.enabled = false
		p.glow.enabled = false
		ps.append(p)
	await get_tree().process_frame
	ps[4]._drips = [[-1, 0.3, 1.0], [1, 0.75, 1.0]]
	ps[5].wax = 20.0
	ps[6].hold_aloft(Art.tex("items/blue_flame"))
	for k in [7, 8, 9]:
		ps[k].dead = true
		ps[k]._melt_from = ps[k].body_height()
	ps[7]._melt = 0.3
	ps[8]._melt = 0.6
	ps[9]._melt = 0.95
	ps[10].apply_candle("tea_light")
	ps[11].apply_candle("pillar")
	for f in 3:
		ps[1]._sq = -1.0
		ps[1]._sq_v = 0.0
		ps[2]._sq = 0.7
		ps[2]._sq_v = 0.0
		ps[3]._white = 1.0
		ps[5]._sput = 0.1
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img = img.get_region(Rect2i(0, 0, 210, 160))
	img.resize(img.get_width() * 6, img.get_height() * 6, Image.INTERPOLATE_NEAREST)
	img.save_png(_shots_dir + "/hero_states.png")
	print("[tour] hero sheet")
	get_tree().quit()


# ---------------------------------------------------------------- relic tour (--tour --relictour)

func _give(w: Node, ids: Array) -> void:
	for id in ids:
		if not id in w.player.relics:
			w.collect_item(id, w.player.global_position)


func _room_of(w: Node, t: String, skip := 0) -> Vector2i:
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] == t and not w.layout["cells"][c]["cleared"]:
			if skip <= 0:
				return c
			skip -= 1
	return Vector2i(-99, -99)


func _dummy(w: Node, pos: Vector2, relics: Array, rites: Array = []) -> Player:
	var d := Player.new()
	d.world = w
	d.apply_candle("tallow")
	d.wax = 100.0
	d.frozen = true
	d.revives = 1
	for r in relics:
		d.relics.append(r)
	for r in rites:
		d.rites.append(r)
	w.actors.add_child(d)
	d.light.enabled = false
	d.global_position = pos
	return d


func _relic_tour() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	main.goto("game", {"seed": 11})
	await _wait(1.6)
	var w: Node = main.current
	w.player.wax = 110.0
	RelicFx.of(w)
	# 1. the costume line-up: one dummy Tallow per piece you can see
	var looks := [["glass_chimney"], ["tin_sconce"], ["old_pipe"], ["wax_coat"], ["lace_fan"], ["bell_wire"],
		["scalding_wax"], ["pale_taper"], ["stopped_clock"], ["love_letter"], ["jet_brooch"], ["nightshade"],
		["phoenix_feather"], ["both_ends"], []]
	var dummies: Array = []
	for i in looks.size():
		var pos: Vector2 = w.room.position + Vector2(40 + (i % 8) * 28, 80 + (i / 8) * 44)
		dummies.append(_dummy(w, pos, looks[i], ["household", "seance"] if i == looks.size() - 1 else []))
	w.player.position = w.room.center() + Vector2(0, 60)
	await _wait(1.2)
	await _shot("lab_costumes")
	for d in dummies:
		d.queue_free()
	# 2. curses on foes, frozen in place
	var c := _room_of(w, "normal")
	if c.x > -99:
		_jump(w, c)
	await _wait(1.4)
	for e in w.enemies:
		if is_instance_valid(e):
			e.queue_free()
	w.enemies.clear()
	var kinds := ["charm", "fear", "poison", "slow", "stun"]
	var foes: Array = []
	for i in kinds.size():
		foes.append(w.spawn_enemy(["goblin", "skelet", "tiny_zombie", "masked_orc", "imp"][i], w.room.position + Vector2(56 + i * 40, 96)))
	await _wait(1.0)
	w.freeze_t = 30.0
	for i in kinds.size():
		RelicFx.of(w).status(foes[i], kinds[i], 30.0)
	w.player.position = w.room.center() + Vector2(0, 50)
	await _wait(0.5)
	for e in foes:
		if is_instance_valid(e):
			e.take_hit(0.01, Vector2.ZERO)
	await _wait(0.7)
	await _shot("lab_curses")
	w.freeze_t = 0.0
	for e in foes:
		if is_instance_valid(e):
			e.queue_free()
	w.enemies.clear()
	# 3. helpers + Tinderbox in a fight
	_give(w, ["matchling", "paper_lantern", "warming_pan", "dust_bunny", "clockwork_mouse", "tinderbox"])
	args["drive"] = true
	c = _room_of(w, "normal")
	if c.x > -99:
		_jump(w, c)
	for i in 2:
		await _wait(1.4)
		await _shot("relic_helpers_%d" % i)
	# 4. the Blowlamp (and every curse)
	_give(w, ["blowlamp", "cold_wax", "shadow_puppet", "love_letter", "nightshade", "bell_wire", "split_wick"])
	c = _room_of(w, "normal")
	if c.x > -99:
		_jump(w, c)
	for i in 3:
		await _wait(1.0)
		await _shot("relic_blowlamp_%d" % i)
	# 5. the pause menu with a long relic list
	_give(w, ["bellows", "spare_wick", "house_deed", "dowsing_rod", "lodestone", "pendulum", "cuckoo_clock", "honeycomb", "magpie_nest", "thimble", "salt_line", "scalding_wax", "minute_hand", "bell_rope", "glass_chimney", "tin_sconce", "old_pipe", "wax_coat"])
	w.toggle_pause()
	await _wait(0.4)
	await _shot("relic_pause")
	w.toggle_pause()
	args.erase("drive")
	# 6. shop and treasure rooms
	for t in ["shop", "treasure"]:
		for cc in w.layout["cells"].keys():
			if w.layout["cells"][cc]["type"] == t:
				_jump(w, cc)
				await _wait(1.0)
				w.player.position = w.room.center() + (Vector2(0, 14) if t == "shop" else Vector2(-26, 20))
				await _wait(0.6)
				await _shot("relic_" + t)
				break
	# 7. the Dowsing Rod's shimmer on a cracked wall
	for cc in w.layout["cells"].keys():
		var found := false
		for dd in FloorGen.DIRS:
			var nb: Vector2i = cc + dd
			if w.layout["cells"].has(nb) and w.layout["cells"][nb]["type"] == "secret" and w.layout["cells"][cc]["type"] != "secret":
				found = true
		if found:
			_jump(w, cc)
			for e in w.enemies:
				if is_instance_valid(e):
					e.queue_free()
			w.enemies.clear()
			await _wait(1.0)
			await _shot("relic_dowsing")
			break
	# 8. results with a long relic row
	w.player.revives = 0
	w.player.wax = 0.0
	await _wait(6.0)
	await _shot("relic_results")
	get_tree().quit()


# ---------------------------------------------------------------- bench (--bench)
# The busiest room of every floor (most static lights, every candelabra lit), a crowd of foes kept
# at 20+, a moth swarm, Blowlamp + Tinderbox + Twin Wick + Candelabra + helpers, and the floor stain
# image filled to its cap; the bot fights in god mode. Per room: average / worst process and physics
# frame times, node / light / particle counts. Then three trips through the four floors with node and
# object counts after each floor: a leak shows up as steady growth from trip to trip.

var _bench_rows: Array = []


func _bench() -> void:
	args["god"] = true
	# headless Godot sleeps this long after every frame (no window can draw); measure the bare CPU work
	OS.low_processor_usage_mode_sleep_usec = 0
	var secs := float(args.get("secs", "6"))
	if args.has("ablate"):
		await _bench_measure(main.current, "TITLE baseline", 3.0)
	main.goto("game", {"seed": int(args.get("seed", "5"))})
	await _wait(1.6)
	var w: Node = main.current
	_give(w, ["blowlamp", "tinderbox", "twin_wick", "candelabra", "matchling", "warming_pan", "paper_lantern", "moth_friend", "dust_bunny"])
	await _wait(1.2)
	print("[bench] physics %d Hz, relics %s" % [Engine.physics_ticks_per_second, w.player.relics])
	for n in [1, 2, 3, 4]:
		w._start_floor(n)
		await _wait(0.4)
		var best := _bench_busiest(w)
		w.layout["cells"][best]["cleared"] = false
		_jump(w, best)
		w.room.light_candles(true)
		await _wait(0.6)
		_bench_crowd(w, 20)
		var st: Stains = Juice.of(w).stains_here()
		var mats := ["goo", "ash", "blood", "wax", "soot", "red"]
		var k := 0
		while st and st.stamps < Stains.MAX_STAMPS and k < 2000:
			k += 1
			st.splat(w.room.position + Vector2(randf_range(20, 252), randf_range(36, 172)), mats[k % mats.size()], k % 3 == 0)
		await _bench_measure(w, "floor %d %s %s" % [n, w.FLOORS[n]["theme"], w.room.data.get("tpl", best)], secs)
		if args.has("ablate"):
			for grp in ["Enemy", "Shot", "Player", "world", "juice", "relic", "room", "hud"]:
				var off: Array = []
				_ablate_collect(get_tree().root, grp, off)
				for o in off:
					o.set_physics_process(false)
					o.set_process(false)
				await _bench_measure(w, "  without %s (%d nodes)" % [grp, off.size()], secs)
				for o in off:
					if is_instance_valid(o):
						o.set_physics_process(true)
						o.set_process(true)
			break
	print("[bench] ---- leak check: three trips through the four floors (counts after each floor)")
	var first := {}
	for trip in [1, 2, 3]:
		for n in [1, 2, 3, 4]:
			w._start_floor(n)
			for i in 3:   # walk through a few rooms so they get built, stained and disposed
				var cells := _normal_cells(w)
				_jump(w, cells[i % cells.size()])
				await _wait(0.5)
				_bench_crowd(w, 8)
				await _wait(1.0)
			await _wait(0.5)
			var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
			var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
			var line := "[bench] trip %d floor %d: nodes=%d objects=%d orphans=%d resources=%d fx=%d enemies=%d hazards=%d" % [
				trip, n, nodes, objs, orphans, res, w.fx_layer.get_child_count(), w.enemies.size(), w.hazards.size()]
			if trip > 1:
				line += "  (vs trip %d: nodes %+d, objects %+d)" % [trip - 1, nodes - first[n][0], objs - first[n][1]]
			first[n] = [nodes, objs]
			print(line)
	print("[bench] SUMMARY")
	for r in _bench_rows:
		print("[bench]   ", r)
	Audio.stop_all()
	await _wait(0.3)
	get_tree().quit()


## The normal room of this floor with the most static lights (decor + candelabras + hearths).
func _bench_busiest(w: Node) -> Vector2i:
	var best: Vector2i = w.cur_cell
	var most := -1
	for c in _normal_cells(w):
		var r: Room = w._build_room(c)
		var n: int = r.decor.lights.size() + r.candles.size() + r._fires.size()
		r.dispose()
		if n > most:
			most = n
			best = c
	return best


## Top the room up to `n` live foes (a moth swarm included), at most `most` new ones per call.
func _bench_crowd(w: Node, n: int, most := 40) -> int:
	var pool: Dictionary = w.POOLS[w.floor_num]
	var have: int = w.count_enemies()
	var made := 0
	var i := 0
	while have < n and i < most:
		i += 1
		var list: Array = pool["f"] if i % 4 == 0 else (pool["h"] if i % 3 == 0 else pool["e"])
		var e: Enemy = w.spawn_enemy(list[randi() % list.size()], w.random_free_spot(w.player.global_position, 60.0), ["", "", "", "ember"][i % 4])
		if e:
			e.active = true
			have += 1
			made += 1
	if not w.enemies.any(func(e): return is_instance_valid(e) and e.kind == "moth"):
		for j in 3:
			w.spawn_enemy("moth", w.random_free_spot(w.player.global_position, 60.0))
			made += 1
	return made


## Counts live lights (out[0]), shadowed lights (out[1]) and CPU particles (out[2]); `by` tallies the
## lights by the script / class of the node that owns them.
func _bench_lights(n: Node, out: Array, by: Dictionary) -> void:
	for c in n.get_children():
		if c is PointLight2D and c.enabled and c.is_visible_in_tree():
			out[0] += 1
			if c.shadow_enabled:
				out[1] += 1
			var o: Node = c.get_parent()
			var sc: Script = o.get_script()
			var key: String = sc.resource_path.get_file().get_basename() if sc else o.get_class()
			by[key] = int(by.get(key, 0)) + 1
		if c is CPUParticles2D and c.emitting:
			out[2] += c.amount
		_bench_lights(c, out, by)


## CPU cost per physics step (physics_frame signal -> the next process_frame) and per process-only
## frame (frames without a physics step), wall clock, with the headless frame sleep switched off;
## plus the engine's own per-second worst process / physics times.
var _ph_t0 := 0
var _ph_on := false


func _bench_ph_begin() -> void:
	_ph_t0 = Time.get_ticks_usec()
	_ph_on = true


func _bench_stats(a: Array[float]) -> Array:
	var sum := 0.0
	for x in a:
		sum += x
	var srt := a.duplicate()
	srt.sort()
	if srt.is_empty():
		return [0.0, 0.0, 0.0]
	return [sum / srt.size(), srt[int(srt.size() * 0.95)], srt.back()]


func _bench_measure(w: Node, label: String, secs: float) -> void:
	var t := 0.0
	var proc: Array[float] = []
	var phys: Array[float] = []
	var proc_max := 0.0
	var phys_max := 0.0
	var lights_max := 0
	var shadows_max := 0
	var cpu_parts_max := 0
	var parts_max := 0
	var nodes_max := 0
	var shots_max := 0
	var enemies_min := 999
	var by_max := {}
	var refill := 0.0
	var game: bool = w.get("player") != null
	var j: Juice = Juice.of(w) if game else null
	var frames := 0
	var spawn_ms: Array[float] = []
	if not get_tree().physics_frame.is_connected(_bench_ph_begin):
		get_tree().physics_frame.connect(_bench_ph_begin)
	await get_tree().process_frame
	var last := Time.get_ticks_usec()
	while t < secs:
		_ph_on = false
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var real := (now - last) / 1000.0
		frames += 1
		if frames > 5:   # the first frames still carry the room build
			if _ph_on:
				phys.append((now - _ph_t0) / 1000.0)
			else:
				proc.append(real)
		last = now
		t += real / 1000.0
		proc_max = maxf(proc_max, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys_max = maxf(phys_max, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		if frames % 60 == 0 and game:
			var o := [0, 0, 0]
			var by := {}
			_bench_lights(w, o, by)
			if o[0] > lights_max:
				lights_max = o[0]
				by_max = by
			shadows_max = maxi(shadows_max, o[1])
			cpu_parts_max = maxi(cpu_parts_max, o[2])
			parts_max = maxi(parts_max, j.hot.count() + j.lit.count())
			nodes_max = maxi(nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			var shots := 0
			for s in w.fx_layer.get_children():
				if s is Shot:
					shots += 1
			shots_max = maxi(shots_max, shots)
			enemies_min = mini(enemies_min, w.count_enemies())
			last = Time.get_ticks_usec()   # keep the bench's own bookkeeping out of the next sample
		refill -= real / 1000.0
		if refill <= 0.0 and game:
			refill = 0.25   # a trickle, like summoners and wave rooms (a big batch would read as a spike)
			var t0 := Time.get_ticks_usec()
			var made := _bench_crowd(w, 20, 2)
			if made > 0:
				spawn_ms.append((Time.get_ticks_usec() - t0) / 1000.0 / made)
			last = Time.get_ticks_usec()
	get_tree().physics_frame.disconnect(_bench_ph_begin)
	var pr := _bench_stats(proc)
	var ph := _bench_stats(phys)
	var sp := _bench_stats(spawn_ms)
	var static_l: int = (w.room.decor.lights.size() + w.room.candles.size() + w.room._fires.size()) if game else 0
	var row := "%s: physics step avg %.2f ms p95 %.2f max %.2f | process frame avg %.2f p95 %.2f max %.2f (%d steps, %d frames; engine worst/s %.1f / %.1f) | spawn %.2f ms per foe (max %.2f) | static lights %d/%d, live lights max %d (shadowed %d) %s | particles %d (+%d cpu) shots %d nodes %d foes min %d" % [
		label, ph[0], ph[1], ph[2], pr[0], pr[1], pr[2], phys.size(), proc.size(), phys_max, proc_max, sp[0], sp[2], static_l, RoomDecor.LIGHT_BUDGET,
		lights_max, shadows_max, by_max, parts_max, cpu_parts_max, shots_max, nodes_max, enemies_min]
	_bench_rows.append(row)
	print("[bench] ", row)


func _ablate_collect(n: Node, grp: String, out: Array) -> void:
	for c in n.get_children():
		var sc: Script = c.get_script()
		var f: String = sc.resource_path.get_file().to_lower() if sc else ""
		var hit := false
		match grp:
			"Enemy": hit = c is Enemy
			"Shot": hit = c is Shot
			"Player": hit = f == "player.gd"
			"world": hit = f == "world.gd"
			"juice": hit = f.begins_with("juice") or f.begins_with("fx_") or f == "stains.gd"
			"relic": hit = f.begins_with("relic") or f.begins_with("familiar") or f.begins_with("costume")
			"room": hit = f.begins_with("room")
			"hud": hit = f == "hud.gd"
		if hit:
			out.append(c)
		_ablate_collect(c, grp, out)
