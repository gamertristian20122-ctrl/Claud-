extends Node
## Automated play-test bot + screenshot tour.
##   -- --autotest --playtest [--runs=N] [--speed=4] [--seed=N]   plays full runs, prints a summary
##        [--god] [--stress] [--unlockall --candle=id] [--relics=a,b] [--savecycle: Save & quit + Continue each floor]
##        [--slot=1-3: the save slot to play in] [--difficulty=1-4: that slot's level (world.LEVELS)]
##   -- --autotest --tour --slots --shots=/abs/dir                 the Slots screen, the level picker, a 2.0 save moved in
##   -- --autotest --tour --shots=/abs/dir                         screenshots of every screen
##        [--fit]: after each shot, FitCheck lists text/buttons off the screen or on other text
##   -- --autotest --audiotest                                     audio catalogue + live-mix check (audio_check.gd)
##   -- --autotest --herosheet --shots=/abs/dir                    Tallow in every juice state (pixel check)
##   -- --autotest --tour --rooms --shots=/abs/dir                 three dressed rooms on every floor
##   -- --autotest --bench [--secs=6] [--seed=N] [--ablate]        busiest rooms: CPU per physics step / frame, lights, leaks
##                                                                 (--ablate: floor 1 again with each script group switched off)
##   -- --autotest --tour --journal --shots=/abs/dir               Journal tabs, death note, chalk start room
##   -- --autotest --shots-store --shots=/abs/dir [--phone]        staged store screenshots (scripts/store_shots.gd)
##   -- --autotest --keyart --shots=/abs/dir                       the key-art scene, no HUD (tools/store_art.py)
##   -- --autotest --lightjudge --shots=/abs/dir                   light pass judge images (tools/light_judge.py)
##   -- --autotest --trailer=<scene>                               staged trailer footage (scripts/trailer.gd, tools/make_trailer.sh)
##   -- --autotest --playtest --boss=<kind> [--runs=N] [--speed=4]  one guardian's fight with its floor's kit, a line per fight
##   -- --autotest --tour --boss=<kind> --shots=/abs/dir           its versus card + two shots per phase (GuardiansV21.tour)
##   -- --autotest --tour --intros[=<kind>] --shots=/abs/dir       every guardian's entrance, two shots each (BossIntro.tour)
##   -- --autotest --movescheck                                    v2.3 special moves: numbers, frame timing (MovesTour)
##   -- --autotest --tour --moves --shots=/abs/dir                 each candle's move mid-action, the HUD button, Keys page
##        [--nomoves]: playtests without the special moves (balance comparison)
##   -- --autotest --tour --night --shots=/abs/dir [--fit]       the night length picker, a 7-floor run's HUD, banners, results
##   -- --autotest --diarycheck                                   v2.5 story: every diary page's sources proven, no repeats,
##        no reading card in a fight, the endings' rules (scripts/game/diary_tour.gd; exit 1 on a FAIL)
##   -- --autotest --ending=<id> [--shots=/abs/dir]               stage an ending: true, housekeeper, windows, whole_story
##   -- --autotest --tour --diary --shots=/abs/dir [--fit]        a page, its reading card, the Diary tab, the endings' cards
##   -- --autotest --nightdump --speed=4 [--floors=N] [--dump=/abs/file]  every floor of a few seeded nights: layouts,
##        guardians, loot, lodgers and the floor numbers (scripts/night_check.gd; the 4-floor baseline must not change)

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
var trailer: Node = null   # scripts/trailer.gd while it stages a scene (it may steer Tallow in drive())
var _intent := ""          # v2.6 feel probe: what the bot did last frame (fight / pickup / walk / special / idle)


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
	if args.has("designcheck"):   # design pass: latency, share text, floor-1 layouts (DesignCheck)
		mode = "designcheck"
	if args.has("movescheck"):    # v2.3 special moves: every move's numbers and input timing (MovesTour.check)
		mode = "movescheck"
	if args.has("feelcheck"):     # v2.6 feel pass: turns, the touch stick, pans, buffers, the magnet, Aim: Auto (FeelProbe)
		mode = "feelcheck"
	if args.has("bench"):
		mode = "bench"
	if args.has("shots-store") or args.has("keyart") or args.has("trailer"):
		mode = "tour"   # store art: the bot only plays when the staging asks it to
	if args.has("lightjudge"):
		mode = "tour"   # light pass judge images (scripts/game/light_judge.gd, tools/light_judge.py)
	if args.has("nightdump"):
		mode = "tour"   # the Long Night's determinism dump (scripts/night_check.gd): Tallow is never driven
	if args.has("diarycheck") or args.has("ending"):
		mode = "tour"   # v2.5 story: the diary's judges, a staged ending (scripts/game/diary_tour.gd)
	runs_left = int(args.get("runs", "1"))
	# save slots (v2.1): --slot=N plays in that slot, --difficulty=N (1-4) sets its level first
	if args.has("slot"):
		Game.use_slot(int(args["slot"]))
	if args.has("difficulty"):
		Game.set_level(Game.slot, int(args["difficulty"]))
	if args.has("slot") or args.has("difficulty"):
		print("[slots] slot %d, level %d (%s)" % [Game.slot, Game.level, Records.level_text(Game.level)])
	_shots_dir = str(args.get("shots", ""))
	Game.base_time_scale = float(args.get("speed", "1"))
	Engine.time_scale = Game.base_time_scale
	Game.settings["aim_assist"] = true
	await get_tree().create_timer(0.8).timeout
	if args.has("herosheet") and args.has("costumes"):
		_costume_sheet()
	elif args.has("herosheet") and args.has("ingame"):
		_ingame_hero()
	elif args.has("herosheet"):
		_hero_sheet()
	elif args.has("lightjudge"):
		await LightJudge.run(self)
		get_tree().quit()
	elif args.has("nightdump"):   # v2.2 night: every floor of a few seeded nights (determinism baseline)
		await load("res://scripts/night_check.gd").run(self)
		get_tree().quit()
	elif args.has("shots-store") or args.has("keyart"):
		await load("res://scripts/store_shots.gd").run(self)
		get_tree().quit()
	elif args.has("trailer"):
		await load("res://scripts/trailer.gd").run(self)
		get_tree().quit()
	elif args.has("diarycheck"):   # v2.5 story: every page's sources, no repeats, no reading card in a fight
		await DiaryTour.check(self)
		Audio.stop_all()
		get_tree().quit(1 if DiaryTour.fails > 0 else 0)
	elif args.has("ending"):   # v2.5 story: --ending=<id> stages that ending (cards, credits, results)
		await DiaryTour.stage_ending(self, str(args["ending"]))
		Audio.stop_all()
		get_tree().quit()
	elif args.has("artjudge"): await ArtJudge.run(self)   # fix/art: scripts/game/art_judge.gd, tools/art_judge.py
	elif args.has("shotjudge"): await ShotJudge.run(self)   # v2.1 shots: scripts/game/shot_judge.gd, tools/shot_judge.py
	elif mode == "tour" and args.has("boss"):
		GuardiansV21.tour(self, str(args["boss"]))
	elif mode == "tour" and args.has("relictour"):
		_relic_tour()
	elif mode == "tour":
		_tour()
	elif mode == "audiotest":
		add_child(load("res://scripts/audio_check.gd").new())
	elif mode == "designcheck":
		await DesignCheck.run(self)
		get_tree().quit()
	elif mode == "feelcheck":
		await FeelProbe.check(self)
		Audio.stop_all()
		get_tree().quit()
	elif mode == "movescheck":
		await MovesTour.check(self)
		Audio.stop_all()
		get_tree().quit(1 if MovesTour._fails > 0 else 0)
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
		Unlocks.force_all = true   # every relic and keepsake in the pool
	if args.has("candle"):
		params["candle"] = str(args["candle"])
		if not Candles.is_unlocked(params["candle"]):   # just this candle: the relic pool stays the profile's own
			(Game.records["unlocked"] as Array).append(params["candle"])
	if args.has("seed"):
		params["seed"] = int(args["seed"]) + results.size()
	if args.has("floors"):   # --floors=N: the night's length (4 .. Areas.max_floors())
		params["floors"] = int(args["floors"])
	_cycled = -1
	main.goto("game", params)
	if args.has("relics") or args.has("keepsake"):
		# wait for the new run (the screen fade can take longer than a fixed delay)
		var waited := 0.0
		while waited < 8.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		_grant(main.current)
	if args.has("tower") and mode == "playtest":   # --tower: start on the Clock Tower (floor 5) with a kit
		await get_tree().create_timer(0.5).timeout
		Tower.test_start(main.current)
	if args.has("boss") and mode == "playtest":   # --boss=<kind>: one guardian's fight with its floor's kit
		await get_tree().create_timer(0.5).timeout
		GuardiansV21.trial(main.current, str(args["boss"]))
	elif args.has("area") and mode == "playtest":   # --area=<id> [--areadepth=N] [--areaboss2]: a new area of the house (areas.gd)
		await get_tree().create_timer(0.5).timeout
		Areas.test_start(main.current, str(args["area"]), int(args.get("areadepth", str(Areas.TEST_DEPTH))), args.has("areaboss2"))


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
	var house_before := _house_sig(w)   # the Long Night: the same area, night length and rooms must come back
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
	var house_after := _house_sig(w)
	print("[savecycle]    house %s -> %s: %s" % [house_before, house_after, "SAME" if house_before == house_after else "DIFFERENT"])
	_cycling = false


## The floor as the seed built it: its area, the night's length and a hash of every cell (type, seed, grid).
func _house_sig(w: Node) -> String:
	var parts: Array = []
	for c in w.layout["cells"].keys():
		var d: Dictionary = w.layout["cells"][c]
		var g := ""
		for row in d["grid"]:
			g += "".join(row)
		parts.append("%s:%s:%d:%d" % [c, d["type"], int(d["seed"]), g.hash()])
	parts.sort()
	return "%s floor %d/%d rooms %d #%d" % [str(w.fdef().get("area", "?")), int(w.floor_num), int(w.get("night_floors") if w.get("night_floors") != null else 4),
		parts.size(), ",".join(parts).hash()]


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
	if args.has("area"):
		Areas.test_watch(self, cur)   # one line when the area's floor is done, then the run ends
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
		print("[playtest] run %d: %s floor=%d/%d (%s) clock=%s kills=%d rooms=%d time=%.0fs relics=%s" % [
			results.size(), "WIN" if p["won"] else "LOSS", p["floor"], int(p.get("floors", 4)), str(p.get("area", "")), Game.clock_text(p["clock"]),
			p["kills"], p["rooms"], p["time"], p["relics"]])
		print("[playtest]    best streak x%d, hits %d" % [p.get("streak", 0), p.get("hits", 0)])
		print("[playtest]    level %d, candle %s, seed %d, slot %d" % [int(p.get("level", 2)), p.get("candle", "?"), int(p.get("seed", 0)), Game.slot])
		print("[playtest]    %s" % MovesBot.report())   # v2.3: special move uses this run
		if Candles.blows > 0:   # a dark_hit candle (the Black Taper): how many blows landed out in the dark
			print("[playtest]    blows %d, in the dark %d (%d%%)" % [Candles.blows, Candles.dark_blows, roundi(100.0 * Candles.dark_blows / Candles.blows)])
		Candles.blows = 0
		Candles.dark_blows = 0
		if args.has("area"):
			Areas.test_result(self, p)
		var parts: Array = []
		for f in _diag.keys():
			var d: Array = _diag[f]
			parts.append("f%d %ds hits %d lost %d gained %d" % [f, d[0], d[1], d[2], d[3]])
		print("[diag]    ", " | ".join(parts))
		var src: Array = _diag_src.keys()
		src.sort_custom(func(a, b): return _diag_src[a] > _diag_src[b])
		print("[diag]    hit by ", src.slice(0, 8).map(func(k): return "%s %d" % [k, _diag_src[k]]))
		if _diag_dark[0] > 0:
			print("[diag]    shot hits %d: from beyond half the light %d, beyond the light %d, mean distance %.0f px" % [
				_diag_dark[0], _diag_dark[1], _diag_dark[2], _diag_dark[3] / _diag_dark[0]])
		_diag_dark = [0, 0, 0, 0.0]
		print("[diag]    floor-1 rooms fought: ", _diag_rooms)
		print(FeelProbe.report())   # v2.6 feel pass: fight / pickup / walk / walk-back / transitions
		FeelProbe.reset()
		_diag_rooms = []
		_diag_cell = Vector2i(-99, -99)
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
	var td: Array = trailer.drive(w) if trailer != null else []
	if not td.is_empty():
		return td
	if (mode == "tour" or mode == "audiotest" or mode == "designcheck" or mode == "movescheck" or mode == "feelcheck") and not args.has("drive"):
		return []
	if args.has("herosheet"):
		return [Vector2.ZERO, Vector2.ZERO]   # the in-game hero shot: stand still
	var p: Player = w.player
	if args.has("god") and p:
		p.wax = maxf(p.wax, 80.0)
	_diag_tick(w, p)
	if mode == "playtest":
		FeelProbe.tick(w, _intent, w.get_physics_process_delta_time())   # v2.6: where the run's time goes
	_intent = "idle"
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
		_intent = "stuck"
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
		mv += Keeper.bot_push(w, pos)   # the Keeper's hands: get behind them or past their tips
		mv += AreaGimmicks.bot_push(w, pos)   # hot stove tops, scalding broth, ink, the Dressmaker's whirling sheets
		if w.keepsake_full() and (w.count_enemies() >= 3 or (w.boss and is_instance_valid(w.boss))):
			w.use_keepsake()
		if w.boss and is_instance_valid(w.boss) and p.bombs > 0 and _bomb_cd <= 0 and pos.distance_to(w.boss.global_position) < 30:
			_bomb_cd = 3.0
			w.place_bomb()
		MovesBot.think(w, mv, tgt)   # v2.3: dash / blink from shots, slam / sparkler a crowd, flare / snuff a guardian
		_intent = "fight"
		return [mv.normalized(), to.normalized()]
	# room is clear: pick up what is worth picking up
	var pick := _best_pickup(w, p) if _room_t < 9.0 else null
	if pick == null and w.room.data["type"] == "boss" and w.room.data["cleared"] and _next_dir(w) == Vector2i.ZERO:
		for o in w.room.objects.get_children():
			if o is Pickup and o.kind == "trapdoor":
				pick = o
	if pick:
		_intent = "pickup" if pick.kind != "trapdoor" else "walk"
		return [((pick.global_position - pos).normalized() + AreaGimmicks.bot_push(w, pos)).normalized(), Vector2.ZERO]
	# special rooms: ring the Seance bell, wind the music box, feed the font (sensibly, then move on)
	var sp: Variant = Specials.bot_target(w)
	if sp != null:
		_intent = "special"
		return [((sp as Vector2) - pos).normalized(), Vector2.ZERO]
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
	_intent = "walk"
	if _room_t_total > 20.0 and Engine.get_physics_frames() % 120 == 0:
		print("   [nav] cell=%s dir=%s my=%s door=%s next=%s grid=%s" % [w.cur_cell, dir, my_cell, door_cell, _path_next(room, my_cell, door_cell), room.data["grid"]])
	if my_cell == door_cell or my_cell.x < 0 or my_cell.y < 0 or my_cell.x >= Room.COLS or my_cell.y >= Room.ROWS:
		return [((exit_pt - pos).normalized() + AreaGimmicks.bot_push(w, pos)).normalized(), Vector2.ZERO]
	var wp := _path_next(room, my_cell, door_cell)
	var goal: Vector2 = room.cell_center(wp) + Vector2(0, 2)
	return [((goal - pos).normalized() + AreaGimmicks.bot_push(w, pos)).normalized(), Vector2.ZERO]   # round hot stove tops too


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


## Design pass: every enemy shot's origin, so a hit can say how far (and from how deep in the dark)
## the shot came. id -> [origin, last position]; _diag_dark = [shot hits, from beyond half the light
## radius, from beyond the light radius, sum of distances]. _diag_rooms: floor 1's rooms in the order
## they were fought, with who was in them.
var _shot_from := {}
var _diag_dark := [0, 0, 0, 0.0]
var _diag_rooms: Array = []
var _diag_cell := Vector2i(-99, -99)
var _diag_logged := false


func _diag_shot_origin(w: Node, p: Player) -> float:
	var at: Vector2 = p.global_position + Vector2(0, -8)
	var best := -1.0
	var bd := 18.0 * 18.0
	for id in _shot_from:
		var rec: Array = _shot_from[id]
		var o = instance_from_id(id)
		var gone: bool = o == null or not is_instance_valid(o) or o._dead
		if gone and (rec[1] as Vector2).distance_squared_to(at) < bd:
			bd = (rec[1] as Vector2).distance_squared_to(at)
			best = (rec[0] as Vector2).distance_to(p.global_position)
	return best


func _diag_track_shots(w: Node) -> void:
	var seen := {}
	for sh in w.enemy_shots:
		if not is_instance_valid(sh) or sh._dead:
			continue
		var id: int = sh.get_instance_id()
		seen[id] = true
		if _shot_from.has(id):
			_shot_from[id][1] = sh.global_position
		else:
			_shot_from[id] = [sh.global_position, sh.global_position]
	for id in _shot_from.keys():
		if not seen.has(id):
			_shot_from.erase(id)


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
			var src := _hit_source(w, p)
			if src == "shot or hazard" and w.has_meta("last_hit") and Engine.get_physics_frames() - int(w.get_meta("last_hit_frame", -99)) <= 2:
				src = "via " + str(w.get_meta("last_hit"))   # Records' blame: the shooter or the hazard
			var od := _diag_shot_origin(w, p)
			if od >= 0.0:
				var lr: float = p.light.texture_scale * 128.0 if p.light else 160.0
				_diag_dark[0] += 1
				_diag_dark[1] += 1 if od > lr * 0.5 else 0
				_diag_dark[2] += 1 if od > lr else 0
				_diag_dark[3] += od
				src = "shot(" + src.replace("via ", "") + ")"
			_diag_src[src] = int(_diag_src.get(src, 0)) + 1
		elif dw > 0.05:
			d[3] += dw
	_diag_track_shots(w)
	if f == 1 and w.cur_cell != _diag_cell:   # floor 1, room by room: who the bot met ("o" = an opening room)
		_diag_cell = w.cur_cell
		_diag_logged = false
	if f == 1 and not _diag_logged and w.room_spawned and w.count_enemies() > 0:
		_diag_logged = true
		var kinds := {}
		for e in w.enemies:
			if is_instance_valid(e) and e.alive:
				kinds[e.kind] = true
		_diag_rooms.append(("o:" if w.room.data.get("opening", false) else "") + "+".join(kinds.keys()))
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
	if args.has("fit"):   # layout judge: text off the screen or on other text (scripts/ui/fit_check.gd)
		for line in FitCheck.scan(get_tree().root, get_viewport().get_visible_rect().size):
			print("[fit] %02d_%s %s" % [_shot_i, name, line])


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
	if args.has("slots"):   # v2.1: the save slots, the level picker, a 2.0 save moved into Slot 1
		await _wait(0.5)
		await load("res://scripts/ui/slots_tour.gd").tour(self)
		Audio.stop_all()
		get_tree().quit()
		return
	if args.has("journal"):   # meta stream: the Journal, the death note, the chalk start room
		await _wait(1.0)
		await MetaTour.tour(self)
		Audio.stop_all()
		get_tree().quit()
		return
	if args.has("specials"):   # every special room, a Seance wave and a mini-boss per floor
		await _wait(1.0)
		await Specials.tour(self)
		get_tree().quit()
		return
	if args.has("tower"):   # the ladder of light, the Clock Tower, the Keeper's phases, the ending
		await _wait(1.0)
		await Tower.tour(self)
		get_tree().quit()
		return
	if args.has("moves"):   # v2.3: each candle's special move mid-action, the HUD button, the Keys page
		await _wait(0.5)
		await MovesTour.tour(self)
		get_tree().quit()
		return
	if args.has("night"):   # the Long Night: the night length picker, a 7-floor run's HUD and banners, results, Journal
		await _wait(0.5)
		await load("res://scripts/night_check.gd").tour(self)
		get_tree().quit()
		return
	if args.has("intros"):   # v2.4: each guardian's entrance mid-animation (boss_intro.gd); --intros=<kind>: one
		await _wait(0.5)
		await BossIntro.tour(self)
		get_tree().quit()
		return
	if args.has("diary"):   # v2.5 story: a page, its reading card, the Diary tab, each ending's cards, the results
		await _wait(0.5)
		await DiaryTour.tour(self)
		get_tree().quit()
		return
	if args.has("areas"):   # the Long Night's new areas: rooms, gimmicks, lodgers, guardians (areas.gd)
		await _wait(1.0)
		await Areas.tour(self)
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
	w.player.wax = 58.0   # after 1:00 AM, so the Belfry ends in the normal victory (not the Clock Tower)
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
	await _wait(3.0)   # the burn (0.9 s) + the title's opening (2.2 s): the menu and Continue are in
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
	if not (f is Button and (f as Button).text == "Journal"):   # the row under Resume: Journal | Settings
		fails += 1
		print("[platform] FAIL d-pad down focus: ", f, " ", f.get("text") if f else "")
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
	# back, back: results -> title -> "blow out the candle?" (desktop). The second Back waits for the
	# title's opening to end (a press during it only skips the opening).
	await _ui("ui_cancel")
	await _wait(3.2)
	await _ui("ui_cancel")
	await _wait(0.4)
	await _shot("quit_prompt_" + tag)
	var asked := false
	if main.current and main.current.get("root"):
		for c in (main.current.root as Control).get_children():
			if c.get_meta("quit_prompt", false):
				asked = true
	if not asked and not OS.has_feature("mobile"):
		fails += 1
		print("[platform] FAIL Back on the title did not ask 'blow out the candle?'")
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


## Tallow in every state side by side, in 32x34 cells with the feet at (15, 33) like the concept sheet
## (art_source/hero_reborn/draw.py). Row A = the concept sheet in order: idle x4, run x4, shoot, hurt,
## victory, wax 100 / 60 / 25 %. Row B = the other juice states. Rows C..E = the six candles at
## 100 / 60 / 25 % wax. Writes hero_sheet_1x.png, hero_states.png (rows A+B x6), hero_candles.png (x6).
func _hero_sheet() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#3b3332")   # the concept sheet's cell colour
	bg.size = Vector2(480, 216)
	layer.add_child(bg)
	var cells: Array = []   # [player, row, index]
	for i in 14:
		cells.append([_hs_add(layer, i * 32, 4, "tallow"), 0, i])
	for i in 15:
		cells.append([_hs_add(layer, i * 32, 44, "tallow"), 1, i])
	for row in 3:
		for i in Candles.ORDER.size():
			cells.append([_hs_add(layer, i * 32, 106 + row * 35, Candles.ORDER[i]), 2 + row, i])
	# hold every state still: re-apply it each frame (the timers count down in _process; slow time
	# down so a slow software renderer cannot run a blink out between two frames)
	Engine.time_scale = 0.01
	for k in 40:
		for c in cells:
			var p: Player = c[0]
			p._blink = 9.0
			p._breath = 0.0
			_hs_state(p, c[1], c[2])
			p.face.visible = true
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir + "/hero_sheet_1x.png")
	var top := img.get_region(Rect2i(0, 0, 480, 80))
	top.resize(top.get_width() * 6, top.get_height() * 6, Image.INTERPOLATE_NEAREST)
	top.save_png(_shots_dir + "/hero_states.png")
	var cand := img.get_region(Rect2i(0, 106, 192, 105))
	cand.resize(cand.get_width() * 6, cand.get_height() * 6, Image.INTERPOLATE_NEAREST)
	cand.save_png(_shots_dir + "/hero_candles.png")
	print("[tour] hero sheet")
	get_tree().quit()


## Every costume piece (relics you can see on Tallow) on Tallow at 100 and 30 % wax, the thin Party
## Candle and the wide Altar Pillar: hero_costumes.png (x5) and hero_costumes_1x.png.
func _costume_sheet() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#3b3332")
	bg.size = Vector2(480, 216)
	layer.add_child(bg)
	var looks := [["glass_chimney"], ["tin_sconce"], ["old_pipe"], ["wax_coat"], ["lace_fan"], ["bell_wire"],
		["scalding_wax"], ["pale_taper"], ["stopped_clock"], ["love_letter"], ["jet_brooch"], ["nightshade"],
		["phoenix_feather"], ["both_ends"], ["household", "seance"]]
	var setups := [["tallow", 1.0], ["tallow", 0.3], ["party", 1.0], ["pillar", 1.0], ["tea_light", 0.55]]
	var ps: Array = []
	for row in setups.size():
		for i in looks.size():
			var p := _hs_add(layer, i * 32, 2 + row * 42, setups[row][0])
			p.revives = 1
			p.set_meta("show_all", true)
			for r in looks[i]:
				if r in ["household", "seance"]:
					p.rites.append(r)
				else:
					p.relics.append(r)
			ps.append([p, float(setups[row][1])])
	Engine.time_scale = 0.01
	for k in 40:
		for e in ps:
			var p: Player = e[0]
			p.wax = p.wax_max * float(e[1])
			p._blink = 9.0
			p._breath = 0.0
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir + "/hero_costumes_1x.png")
	img.resize(img.get_width() * 5, img.get_height() * 5, Image.INTERPOLATE_NEAREST)
	img.save_png(_shots_dir + "/hero_costumes.png")
	print("[tour] costume sheet")
	get_tree().quit()


## The real game, the cellar's first room, Tallow standing at full wax: a 240x135 crop round him with
## him at (104, 86) like art_source/hero_reborn/ingame.png. Writes hero_ingame_1x.png and hero_ingame.png (x4).
func _ingame_hero() -> void:
	DirAccess.make_dir_recursive_absolute(_shots_dir)
	main.goto("game", {"seed": 11})
	await _wait(1.6)
	var w: Node = main.current
	var p: Player = w.player
	p.wax = 120.0
	p.frozen = true
	p.move_input = Vector2.ZERO
	p.aim_input = Vector2.ZERO
	p.position = w.room.center() + Vector2(0, 26)
	w.hud.visible = false
	await _wait(1.0)
	p._blink = 9.0
	p._breath = 0.0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var at := p.get_global_transform_with_canvas().origin
	var crop := img.get_region(Rect2i(int(at.x) - 104, int(at.y) - 86, 240, 135))
	crop.save_png(_shots_dir + "/hero_ingame_1x.png")
	crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
	crop.save_png(_shots_dir + "/hero_ingame.png")
	print("[tour] in-game hero")
	get_tree().quit()


func _hs_add(layer: Node, x: float, y: float, cid: String) -> Player:
	var p := Player.new()
	p.world = null
	p.position = Vector2(x + 15, y + 33)
	layer.add_child(p)
	p.set_physics_process(false)
	p.light.enabled = false
	p.glow.enabled = false
	if cid != "tallow":
		p.apply_candle(cid)
	p.flame.speed_scale = 0.0
	return p


func _hs_run(p: Player, bob: float, dir := 1.0) -> void:
	p.move_input = Vector2(dir, 0)
	p.vel = Vector2(dir * p.speed, 0)
	p.facing = Vector2(dir, 0)
	p._was_moving = true
	p._bob = bob
	p._drip_spawn = 99.0


func _hs_melt(p: Player, m: float) -> void:
	if not p.dead:
		p.dead = true
		p._melt_from = p.body_height()
	p._melt = m


func _hs_state(p: Player, row: int, i: int) -> void:
	if row >= 2:
		p.wax = p.wax_max * [1.0, 0.6, 0.25][row - 2]
		return
	if row == 0:
		match i:
			0, 1, 2, 3:
				p.flame.frame = i
				if i >= 2:
					p._breath = 0.6
				if i == 3:
					p._blink = 0.05
			4, 5, 6, 7:
				_hs_run(p, [0.0, 0.5, PI / 2.0, 2.6][i - 4])
				p.flame.frame = i % 2
			8:
				p.facing = Vector2.RIGHT
				p.aim_input = Vector2.RIGHT
				p._recoil = 9.0
				p._recoil_off = Vector2(-1, 0)
			9:
				p._hurt_face = 9.0
				p._sq = -0.4
				p._sq_v = 0.0
			10:
				p._happy_face = 9.0
			11:
				p.wax = 120.0
			12:
				p.wax = 72.0
			13:
				p.wax = 30.0
		return
	match i:
		0:
			p._sq = -1.0
			p._sq_v = 0.0
		1:
			p._sq = 0.7
			p._sq_v = 0.0
		2:
			p._white = 1.0
		3:
			p._drips = [[-1, 0.3, 0.0], [1, 0.75, 0.0]]
		4:
			p.wax = 20.0
			p._sput = 0.1
		5:
			_hs_melt(p, 0.3)
		6:
			_hs_melt(p, 0.6)
		7:
			_hs_melt(p, 0.95)
		8:
			if not p.blue:
				p.set_blue(true)
		9:
			if not "wick" in p.rites:
				p.rites.append("wick")
				p.refresh_rite_look()
		10:
			if not "clock" in p.rites:
				p.rites.append("clock")
		11:
			_hs_run(p, PI / 2.0, -1.0)
		12:
			p.wax = 45.0
			_hs_run(p, 0.0)
		13:
			p.wax = 30.0
			p._hurt_face = 9.0
		14:
			if p._hold_t <= 0.0:
				p.hold_aloft(Art.tex("items/blue_flame"))
			p._hold_t = maxf(p._hold_t, 0.5)

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
	var draws: Array[float] = []   # canvas draw calls per frame (0 headless: only a real renderer counts)
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
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
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
	if DisplayServer.get_name() != "headless":
		var dc := _bench_stats(draws)
		row += " | render: draw calls avg %.0f max %.0f, %.0f fps" % [dc[0], dc[2], (phys.size() + proc.size()) / maxf(secs, 0.001)]
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
