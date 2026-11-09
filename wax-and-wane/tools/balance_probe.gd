extends SceneTree
## Run-rule probe (docs/streams/fix_balance.md): boots the real Main scene and checks the run rules,
## printing PASS / FAIL per check and exiting 1 on any FAIL. Give it its own profile (XDG_DATA_HOME):
##   godot --headless --path . --script res://tools/balance_probe.gd -- --check=guardians,continue,daily,gate,levels,summoner
##   godot --headless --path . --script res://tools/balance_probe.gd -- --check=keeper --keeper
## guardians: a seed is the same house whatever the win count (QA-06); a new player's first Belfry is
##   The Great Pendulum and the Hour Fiend joins after a win (C5).
## continue: Save & quit + Continue keeps a run's seeded flag and its guardians (QA-08).
## daily: Tonight's Candle is logged, scored and shared under the night it was lit (QA-15).
## gate: the ladder follows the clock the player sees and waits for a first win (QA-14, C2).
## levels: each difficulty level's multipliers on a live run; Tonight's Candle is always level 2; a
##   continued run keeps its level (v2.1, replaced the Gentle burn check of QA-16).
## summoner: two Hooded Mourners stop summoning after their budget (QA-10).
## keeper: burst damage cannot skip a Keeper phase; phase 3 lasts its minimum (QA-03).

var args := {}
var main: Node
var game: Node
var fails := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1]
		elif a.begins_with("--"):
			args[a.substr(2)] = true
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func _ok(cond: bool, what: String) -> void:
	print("[probe] %s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


func _game_ready() -> bool:
	return main.current != null and main.current.name == "Game" and main.current.get("player") != null and not main._busy


func _light(params: Dictionary) -> Node:
	while main._busy:
		await process_frame
	main.goto("game", params)
	var t := 0.0
	while not _game_ready() and t < 10.0:
		await _wait(0.1)
		t += 0.1
	await _wait(0.3)
	return main.current


func _boss_at(w: Node, n: int) -> String:
	w._start_floor(n)
	await process_frame
	return str(w.boss_kind)


func _run() -> void:
	await process_frame
	game = root.get_node_or_null("Game")
	game.no_save = true
	game.records["seen_intro"] = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _wait(1.5)
	var checks: Array = str(args.get("check", "guardians")).split(",")
	for c in checks:
		await call("_check_" + c)
	print("[probe] DONE fails=%d" % fails)
	game.records["wins"] = 0
	quit(1 if fails > 0 else 0)


## Save & quit to the title, then press Continue (what the title's button does).
func _save_and_continue() -> Node:
	root.get_node("RunSave").flush()
	main.goto("title")
	await _wait(1.6)
	root.get_node("RunSave").continue_run(main)
	var t := 0.0
	while not _game_ready() and t < 10.0:
		await _wait(0.1)
		t += 0.1
	await _wait(0.3)
	return main.current


func _results_params() -> Dictionary:
	var t := 0.0
	while not (main.current and main.current.name == "Results" and not main._busy) and t < 10.0:
		await _wait(0.1)
		t += 0.1
	return main.current.get("params") if main.current else {}


# QA-08: Continue keeps an ordinary run ordinary (and a seeded run seeded, guardians and all).
func _check_continue() -> void:
	game.records["wins"] = 0
	var w: Node = await _light({})
	var s0: int = w.run_seed
	_ok(not w.get_meta("seeded", false), "random run lit: seeded=%s" % w.get_meta("seeded", false))
	w = await _save_and_continue()
	_ok(w.run_seed == s0 and not w.get_meta("seeded", false) and not load("res://scripts/game/unlocks.gd").fixed(w), "random run continued: same seed %s, seeded=%s, fixed=%s" % [w.run_seed == s0, w.get_meta("seeded", false), load("res://scripts/game/unlocks.gd").fixed(w)])
	w._start_floor(2)
	await _wait(0.2)
	w = await _save_and_continue()
	_ok(w.floor_num == 2 and not w.get_meta("seeded", false), "continued twice (floor %d): seeded=%s" % [w.floor_num, w.get_meta("seeded", false)])
	w._end_run(false)
	var p: Dictionary = await _results_params()
	_ok(not p.get("seeded", true), "results of the continued random run: seeded=%s" % p.get("seeded", "?"))
	# a typed-in seed stays seeded across a Continue, and its Belfry guardian is the seed's
	var w2: Node = await _light({"seed": 31337})
	var b0: String = await _boss_at(w2, 4)
	w2 = await _save_and_continue()
	_ok(w2.floor_num == 4 and w2.get_meta("seeded", false) and str(w2.boss_kind) == b0, "typed-in seed continued on floor %d: seeded=%s, guardian %s (was %s)" % [w2.floor_num, w2.get_meta("seeded", false), w2.boss_kind, b0])
	w2._end_run(false)
	p = await _results_params()
	_ok(p.get("seeded", false), "results of the continued seeded run: seeded=%s" % p.get("seeded", "?"))


# QA-15: Tonight's Candle keeps the date it was lit (score, history, Share), across a Continue too.
func _check_daily() -> void:
	var lit := "2026-11-07"
	var today := Time.get_date_string_from_system()
	game.records["daily_date"] = "2026-11-06"
	game.records["daily_first"] = 111
	game.records["daily_best"] = 111
	var w: Node = await _light({"seed": hash("wax&wane" + lit), "daily": true, "candle": "tallow"})
	_ok(w.daily_date == today, "a daily lit now is dated today (%s)" % w.daily_date)
	w.daily_date = lit   # as if it was lit before midnight
	w._start_floor(2)
	await _wait(0.2)
	w = await _save_and_continue()
	_ok(w.daily and w.daily_date == lit, "continued daily keeps its night: %s" % w.daily_date)
	w._end_run(false)
	var p: Dictionary = await _results_params()
	var hist: Array = game.records.get("run_history", [])
	var nights: Array = game.records.get("daily_history", [])
	_ok(str(p.get("date", "")) == lit, "results/Share date %s" % p.get("date", ""))
	_ok(not hist.is_empty() and str(hist[0].get("date", "")) == lit, "run history date %s" % (hist[0].get("date", "") if not hist.is_empty() else "-"))
	_ok(str(game.records["daily_date"]) == lit and int(game.records["daily_first"]) != 111, "first try logged under %s (records daily_date %s, first %d)" % [lit, game.records["daily_date"], int(game.records["daily_first"])])
	_ok(not nights.is_empty() and str(nights[0].get("date", "")) == lit, "nights list head %s" % (nights[0].get("date", "") if not nights.is_empty() else "-"))
	_ok(str(game.records["daily_date"]) != today or lit == today, "today's first try is still open (records %s, today %s)" % [game.records["daily_date"], today])
	# an older night finished after a newer one does not overwrite it
	game.records["daily_date"] = "2026-11-09"
	game.records["daily_first"] = 222
	var w3: Node = await _light({"seed": hash("wax&wane" + lit), "daily": true, "candle": "tallow", "date": lit})
	w3._end_run(false)
	await _results_params()
	_ok(str(game.records["daily_date"]) == "2026-11-09" and int(game.records["daily_first"]) == 222, "a late older night leaves the newer record alone (%s, %d)" % [game.records["daily_date"], int(game.records["daily_first"])])


# QA-06 + C5: a seed is the same house whatever the win count; a new player's first Belfry is the Pendulum.
func _check_guardians() -> void:
	var seen := {}
	for seed in [7, 5, 31337, 123456, 4242, 9100, 9101, 9102]:
		var picks := []
		for wins in [0, 3]:
			game.records["wins"] = wins
			var w: Node = await _light({"seed": seed})
			picks.append(await _boss_at(w, 4))
		seen[picks[0]] = true
		_ok(picks[0] == picks[1], "typed-in seed %d: Belfry guardian with 0 wins %s, with 3 wins %s" % [seed, picks[0], picks[1]])
		game.records["wins"] = 0
		var d0: Node = await _light({"seed": seed, "daily": true})
		var b0: String = await _boss_at(d0, 4)
		game.records["wins"] = 3
		var d1: Node = await _light({"seed": seed, "daily": true})
		var b1: String = await _boss_at(d1, 4)
		_ok(b0 == b1, "daily seed %d: %s / %s" % [seed, b0, b1])
	var opts: Array = load("res://scripts/game/world.gd").FLOORS[4]["bosses"]
	_ok(seen.size() == opts.size(), "seeded Belfry guardians cover all %d (%s)" % [opts.size(), seen.keys()])
	game.records["wins"] = 0
	var firsts := {}
	for i in 6:
		var w: Node = await _light({})
		firsts[await _boss_at(w, 4)] = true
	_ok(firsts.keys() == ["pendulum"], "a new player's random runs: Belfry guardian %s" % [firsts.keys()])
	game.records["wins"] = 2
	var later := {}
	for i in 14:
		var w: Node = await _light({})
		later[await _boss_at(w, 4)] = true
	_ok(later.has("big_demon") and later.has("weathercock"), "after a win the Hour Fiend and the Weathercock are in the rotation (%s)" % [later.keys()])
	game.records["wins"] = 0


## Light a run, put it in the Belfry guardian's room with the clock at `clock`, and ask the tower hook.
func _ladder_at(clock: float, wins: int) -> bool:
	game.records["wins"] = wins
	var w: Node = await _light({})
	w._start_floor(4)
	await _wait(0.2)
	w.player.wax = 120.0 - clock
	var tw: Script = load("res://scripts/game/tower.gd")
	var opened: bool = tw.on_last_boss_down(w)
	await _wait(0.2)
	return opened


# QA-14 + C2: the ladder follows the clock the player sees, and never opens on a first win.
func _check_gate() -> void:
	for c in [[59.4, 1, true], [60.0, 1, true], [60.5, 1, true], [60.99, 1, true], [61.0, 1, false], [75.0, 3, false], [40.0, 0, false], [60.5, 0, false]]:
		var got: bool = await _ladder_at(float(c[0]), int(c[1]))
		_ok(got == bool(c[2]), "Belfry down at %s (shown %s) with %d earlier wins: ladder %s (want %s)" % [c[0], game.clock_text(float(c[0])), c[1], got, c[2]])
	game.records["wins"] = 0


func _melt_rate(w: Node, secs: float) -> float:
	var w0: float = w.player.wax
	var t0: float = w.run_time
	await _wait(secs)
	return (w0 - float(w.player.wax)) / maxf(0.001, float(w.run_time) - t0)


# QA-03: burst damage (8 hits x 40 in one frame, ten times a second) must not skip a Keeper phase, and
# phase 3 must last its minimum. Run with --keeper so Tower.test_start walks into the Keeper's room.
func _check_keeper() -> void:
	var w: Node = await _light({})
	load("res://scripts/game/tower.gd").test_start(w)
	var t := 0.0
	while t < 8.0 and not (is_instance_valid(w.boss) and w.boss.alive):
		await _wait(0.1)
		t += 0.1
	var k: Node = w.boss
	if not is_instance_valid(k):
		_ok(false, "no Keeper")
		return
	Engine.time_scale = 2.0
	var last := int(k.phase)
	var last_t := 0.0
	var spans := {}
	var died_in := 0
	var game_t := 0.0
	while game_t < 90.0:
		await process_frame
		w.player.invuln = 5.0
		w.player.wax = 100.0
		if not is_instance_valid(k) or not k.alive:
			died_in = last
			spans[last] = float(k.mem.get("phase_t", last_t)) if is_instance_valid(k) else last_t
			break
		last_t = float(k.mem.get("phase_t", 0.0))
		if int(k.phase) != last:
			spans[last] = prev_t
			last = int(k.phase)
		prev_t = last_t
		burst_cd -= 1
		if burst_cd <= 0:
			burst_cd = 6
			for i in 8:
				if k.alive:
					k._damage(40.0, false)
		game_t += 1.0 / 60.0 * Engine.time_scale
	Engine.time_scale = 1.0
	print("[probe] keeper phase lengths (game s): %s, stilled in phase %d" % [spans, died_in])
	_ok(died_in == 3 and spans.has(1) and spans.has(2) and spans.has(3), "the Keeper went through all three phases (stilled in phase %d)" % died_in)
	_ok(float(spans.get(1, 0.0)) >= 5.9 and float(spans.get(2, 0.0)) >= 7.9 and float(spans.get(3, 0.0)) >= 9.9,
		"phase 1 %.1f s (>= 6), phase 2 %.1f s (>= 8), phase 3 %.1f s (>= 10)" % [spans.get(1, 0.0), spans.get(2, 0.0), spans.get(3, 0.0)])


var prev_t := 0.0
var burst_cd := 0


# QA-10: two Hooded Mourners whose Shamblers keep getting killed (a Seance wave): summons stop.
func _check_summoner() -> void:
	var w: Node = await _light({"seed": 9502})
	w._start_floor(2)
	await _wait(0.5)
	var ms := []
	for i in 2:
		ms.append(w.spawn_enemy("necromancer", w.random_free_spot(w.player.global_position, 70.0)))
	Engine.time_scale = 4.0
	var killed := 0
	var t := 0.0
	while t < 120.0:   # game seconds
		await _wait(0.5)
		t += 2.0
		w.player.invuln = 5.0
		w.player.wax = 100.0
		for e in w.enemies.duplicate():
			if is_instance_valid(e) and e.alive and e.kind == "tiny_zombie":
				e.hp = 0.0
				e._die()
				killed += 1
	Engine.time_scale = 1.0
	var alive := 0
	for m in ms:
		if is_instance_valid(m) and m.alive:
			alive += 1
	_ok(killed <= 12, "two mourners over %d game seconds, their Shamblers killed as they come: %d summoned (mourners alive %d)" % [int(t), killed, alive])


# v2.1 difficulty levels (world.LEVELS through world.difficulty(), which replaced Gentle burn): each
# level's melt, foe damage, creature health, marked-foe chance and drip wax, measured on a live run
# against level 2; Tonight's Candle plays level 2 whatever the slot's level; Save & Continue keeps the
# level a run was lit at, even if the slot's level changed in between.
func _check_levels() -> void:
	var lv: Dictionary = load("res://scripts/game/world.gd").LEVELS
	var base := {}
	for n in [2, 1, 3, 4]:
		var w: Node = await _light({"level": n, "seed": 4242})
		await _wait(1.0)
		var melt: float = await _melt_rate(w, 2.0)
		var e: Node = w.spawn_enemy("goblin", w.room.center() + Vector2(40, 0))
		var row := {"melt": melt, "dmg": float(w.enemy_dmg_mult()), "hp": float(e.max_hp), "champ": float(w.champ_chance()), "wax": float(w.wax_bonus())}
		e.queue_free()
		if n == 2:
			base = row
		var ok: bool = w.level == n
		var parts: Array = []
		for k in row:
			var ratio: float = row[k] / maxf(0.0001, float(base[k]))
			ok = ok and absf(ratio - float(lv[n][k])) < 0.03
			parts.append("%s x%.2f" % [k, ratio])
		_ok(ok, "level %d %s: %s (melt %.4f/s, goblin hp %.1f)" % [n, lv[n]["name"], ", ".join(parts), melt, row["hp"]])
	game.level = 4
	var d: Node = await _light({"seed": 99, "daily": true, "candle": "tallow"})
	_ok(d.level == 2 and absf(float(d.enemy_dmg_mult()) - float(base["dmg"])) < 0.001, "Tonight's Candle with the slot at level 4 plays level %d" % d.level)
	game.level = 3
	var w3: Node = await _light({})
	_ok(w3.level == 3, "a run takes the slot's level: %d" % w3.level)
	game.level = 1
	w3 = await _save_and_continue()
	_ok(w3.level == 3, "continued after the slot went to level 1: the run stays at level %d" % w3.level)
	game.level = 2
