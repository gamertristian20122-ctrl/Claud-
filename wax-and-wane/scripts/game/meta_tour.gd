class_name MetaTour
extends RefCounted
## Screenshot tour of the meta stream (never in play):
##   -- --autotest --tour --journal --shots=DIR
## Stages a mid-progress profile (nothing is written to the real save: Game.no_save), then shoots
## the title, every Journal tab (touch and gamepad), the seed keypad, the pause menu's Journal, the
## chalk start room for touch / keyboard / mouse / gamepad, and a death-note results screen with
## a new unlock. The real records come back at the end.


static func stage() -> void:
	var r := Game.records
	r["runs"] = 23
	r["wins"] = 4
	r["kills"] = 2817
	r["best_floor"] = 4
	r["best_streak"] = 11
	r["best_finish"] = 58.3
	r["best_finish_tea_light"] = 71.0
	r["unlocked"] = ["tallow", "tea_light", "party"]
	r["seen_intro"] = true
	var ach := {}
	for a in ["first_snuff", "night_shift", "floor_crypt", "floor_chapel", "floor_belfry", "boss_cellar", "boss_crypt",
			"win", "hollow", "seance", "ks_hand_bell", "kindling_8", "smoke_pact", "customer", "tonight"]:
		ach[a] = 1700000000
	r["achievements"] = ach
	var seen := {}
	var taken := {}
	var i := 0
	for id in Items.RELICS:
		i += 1
		if i % 5 == 3 or not Unlocks.is_unlocked(id):
			continue
		seen[id] = 1
		if i % 3 != 0:
			taken[id] = 1 + i % 4
	for id in ["hand_bell", "flare_match", "winding_key", "censer", "vigil_candle"]:
		seen[id] = 1
	r["seen_relics"] = seen
	r["taken_relics"] = taken
	var met := {}
	var kills := {}
	i = 0
	for k in BestiaryGallery.regulars():
		i += 1
		if i % 4 == 0:
			continue
		met[k] = 1
		kills[k] = 7 + (i * 37) % 160
	for k in ["big_zombie", "wax_mother", "ogre", "sexton", "necro_boss", "choir", "big_demon"]:
		met[k] = 1
	met["mini:sootling"] = 1
	met["mini:chort"] = 1
	r["met"] = met
	r["kills_by_kind"] = kills
	r["bosses_beaten"] = {"big_zombie": {"n": 9, "best": 41.0}, "wax_mother": {"n": 5, "best": 63.0}, "ogre": {"n": 6, "best": 52.0},
		"sexton": {"n": 2, "best": 88.0}, "necro_boss": {"n": 4, "best": 70.0}, "big_demon": {"n": 4, "best": 121.0}}
	r["rooms_found"] = {"seance": 1, "musicbox": 1, "font": 1, "mirror": 1}
	r["minis_beaten"] = ["sootling"]
	r["wins_by_candle"] = {"tallow": 3, "tea_light": 1}
	var killers := ["e:wisp", "", "e:snuffer", "m:chort", "spikes", "e:sexton", "clock", "e:goblin", "oil", "", "e:big_demon", "bomb"]
	var hist: Array = []
	for n in 12:
		var won: bool = killers[n] == ""
		var rel: Array = []
		for k in 4 + (n * 3) % 9:
			rel.append(seen.keys()[(n * 7 + k * 5) % seen.size()])
		hist.append({"won": won, "candle": ["tallow", "tea_light", "party"][n % 3], "floor": 4 if won else 1 + (n * 5) % 4,
			"clock": 61.0 + n * 3.0 if won else 30.0 + n * 7.0, "killer": killers[n], "relics": rel, "time": 600.0 + n * 41.0,
			"kills": 60 + n * 9, "streak": 3 + n % 8, "seed": 48217730 + n * 1117, "daily": n == 2, "date": "2026-11-%02d" % (7 - n % 7),
			"n": 23 - n})
	r["run_history"] = hist
	r["daily_history"] = [{"date": "2026-11-07", "first": 6420, "best": 7010, "won": false},
		{"date": "2026-11-06", "first": 8115, "best": 8115, "won": true}, {"date": "2026-11-04", "first": 3990, "best": 5120, "won": false}]
	r["unlocks_known"] = Unlocks.unlocked_items()   # the Blowlamp moves in during the tour's run (Big Game)
	r["journal_new"] = {"r:dowsing_rod": 1, "l:wisp": 1, "g:sexton": 1, "m:chort": 1, "c:party": 1}


static func tour(at: Node) -> void:
	var main: Node = at.main
	var saved: Dictionary = Game.records.duplicate(true)
	Game.no_save = true
	stage()
	Controls.set_device(Controls.TOUCH)
	main.goto("title")
	await at._wait(3.4)
	await at._shot("meta_title")
	var title: Node = main.current
	# ---- the Journal, every tab (touch)
	var j := Journal.open(title.root)
	await at._wait(0.5)
	for i in Journal.TABS.size():
		j._set_tab(i, false)
		await at._wait(0.3)
		await at._shot("journal_%s" % Journal.TABS[i])
	# a few chosen entries
	j._set_tab(0, false)
	j._select(Items.RELICS.keys().find("blowlamp"))
	await at._wait(0.2)
	await at._shot("journal_relic_locked")
	j._turn(1)
	await at._wait(0.2)
	j._select(j.entries.size() - 6)
	await at._wait(0.2)
	await at._shot("journal_relics_p2")
	j._set_tab(1, false)
	j._select(BestiaryGallery.regulars().find("wisp"))
	await at._wait(0.3)
	await at._shot("journal_lodger_wisp")
	j._set_tab(2, false)
	j._select(BestiaryGallery.boss_kinds().find("choir"))
	await at._wait(0.3)
	await at._shot("journal_guardian_choir")
	j._set_tab(3, false)
	j._select(Specials.TYPES.size() + 2)
	await at._wait(0.3)
	await at._shot("journal_rooms_mini")
	j._set_tab(5, false)
	j._select(2)
	await at._wait(0.3)
	await at._shot("journal_record_run")
	j._select(1)
	await at._wait(0.3)
	await at._shot("journal_record_nights")
	# ---- gamepad: glyphs on the tabs, the focus frame
	Controls.set_device(Controls.PAD)
	j._set_tab(1, true)
	await at._wait(0.3)
	await at._shot("journal_pad")
	Controls.set_device(Controls.TOUCH)
	j.queue_free()
	await at._wait(0.3)
	if title.has_method("open_seed_pad"):
		title.open_seed_pad()
		await at._wait(0.4)
		await at._shot("seed_pad")
		var top: Node = title.root.get_child(title.root.get_child_count() - 1)
		if top.get_meta("modal", false):
			top.queue_free()
	await at._wait(0.3)
	await at._shot("meta_title_credits_closed")
	if title.has_method("_credits"):
		title._credits()
		await at._wait(0.4)
		await at._shot("credits")
		var cm: Node = title.root.get_child(title.root.get_child_count() - 1)
		if cm.get_meta("modal", false):
			cm.queue_free()
		await at._wait(0.2)
	# ---- the chalk start room, for each device
	main.goto("game", {"seed": 4242})
	await at._wait(3.2)
	var w: Node = main.current
	w.player.position = w.room.center() + Vector2(0, 8)
	for dev in [Controls.TOUCH, Controls.KEYS, Controls.MOUSE, Controls.PAD]:
		Controls.set_device(dev)
		await at._wait(0.6)
		await at._shot("chalk_%s" % dev)
	Controls.set_device(Controls.TOUCH)
	# ---- the pause menu's Journal
	w.toggle_pause()
	await at._wait(0.4)
	await at._shot("pause_menu")
	var pj := Journal.open(w.hud.root, 2)
	await at._wait(0.4)
	await at._shot("journal_from_pause")
	pj.queue_free()
	await at._wait(0.2)
	w.toggle_pause()
	await at._wait(0.3)
	# ---- a death note: snuffed by a Grave Light, holding a few relics, the Blowlamp moves in
	for id in ["bellows", "moth_friend", "split_wick", "cold_wax", "hourglass", "lace_fan", "paper_lantern"]:
		w.collect_item(id, w.player.global_position)
	await at._wait(3.2)   # the relic banner clears first (the toast waits for it)
	Achievements.unlock("mini_boss")   # Big Game: the toast says the Blowlamp moved in
	await at._wait(0.6)
	await at._shot("toast_unlock")
	await at._wait(2.2)
	var e: Node = w.spawn_enemy("wisp", w.room.center() + Vector2(30, -10))
	w.player.wax = 0.9   # under a minute: no Guttering to cling on with
	w.player.invuln = 0.0
	w.player.wax_coat = false
	w.player.revives = 0
	Records.blame(e)
	w.player.hurt(6.0, Vector2.LEFT)
	await at._wait(4.0)
	await at._shot("results_death")
	Game.records = saved
	Game.no_save = false
