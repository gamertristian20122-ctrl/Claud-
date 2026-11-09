extends RefCounted
## The v2.6 GUI tour (docs/streams/v26_gui.md): every screen the UI kit dresses, quickly, never in play:
##   -- --autotest --tour --gui --shots=DIR [--fit] [--device=keyboard|gamepad|touch]
## Title (with focus), the seed pad, Credits, the Slots screen (empty and used), Settings (each page), the
## Journal, the HUD (start, a relic banner + hint, a shop preview, the ghost cost, low wax, a guardian's bar),
## the pause menu, a reading card, the results (a win with news, a death) and Reduce motion on. Give it its
## own profile (XDG_DATA_HOME). Prints "[gui] DONE".


static func tour(at: Node) -> void:
	var main: Node = at.main
	var dev := str(at.args.get("device", "touch"))
	Controls.set_device(dev)
	await at._wait(2.8)
	await at._shot("gui_title")
	var title: Node = main.current
	title.open_seed_pad()
	await at._wait(0.4)
	await at._shot("gui_seed")
	title.on_back()
	title._credits()
	await at._wait(0.4)
	await at._shot("gui_credits")
	title.on_back()
	Slots.open(title.root, main)
	await at._wait(0.5)
	await at._shot("gui_slots_empty")
	Game.start_slot(2, 3)   # a used slot next to the empty ones
	Game.records["runs"] = 14
	Game.records["wins"] = 3
	Game.records["best_finish"] = 66.0
	Game.save()
	for c in (title.root as Control).get_children():
		if c is Slots:
			(c as Slots)._refresh(2)
	await at._wait(0.4)
	await at._shot("gui_slots_used")
	title.on_back()
	await at._wait(0.2)
	SettingsPanel.open(title.root)
	await at._wait(0.4)
	await at._shot("gui_settings_game")
	await at._ui("ui_page_next")
	await at._wait(0.3)
	await at._shot("gui_settings_controls")
	title.on_back()
	Journal.open(title.root)
	await at._wait(0.5)
	await at._shot("gui_journal")
	title.on_back()
	await at._wait(0.2)
	# ---- the HUD
	main.goto("game", {"seed": 7})
	var w: Node = await _game(at)
	await at._shot("gui_hud_start")
	var p: Player = w.player
	for id in ["blue_flame", "moth_friend", "twin_wick"]:
		w.collect_item(id, p.global_position)
	p.coins = 23
	p.bombs = 3
	p.keepsake = "hand_bell"
	p.charge = 2
	w.streak = 4
	w.streak_t = 1.5
	await at._wait(0.5)
	await at._shot("gui_hud_banner")
	w.hud.preview_item("Tin Sconce", "Shots glance off the walls   -   12 coins")
	w.hud.preview_cost(14.0)
	await at._wait(0.1)
	await at._shot("gui_hud_preview")
	p.wax = 14.0
	w.hud.set_boss("THE HOUR FIEND", true)
	w.hud.set_boss_frac(0.62)
	await at._wait(0.9)
	await at._shot("gui_hud_boss")
	w.hud.set_boss("", false)
	p.wax = 70.0
	w.toggle_pause()
	await at._wait(0.4)
	await at._shot("gui_pause")
	w.toggle_pause()
	await at._wait(0.2)
	var card := PageCard.open(w.hud.root, "p01")
	await at._wait(0.5)
	await at._shot("gui_reading_card")
	card.close()
	await at._wait(0.3)
	# ---- the results
	main.goto("results", {"won": true, "floor": 4, "clock": 66.0, "kills": 87, "rooms": 31, "time": 1270.0,
		"streak": 9, "hits": 6, "candle": "tallow", "relics": ["blue_flame", "moth_friend", "twin_wick", "candelabra",
		"sharp_wick", "matchbook", "tin_sconce"], "new_unlocks": ["dust_bunny", "bell_rope"], "unlocked": ["tea_light"],
		"level": 2, "floors": 4, "seed": 48217730, "killer": "clock", "diary_new": ["p01", "p02"]})
	await _screen(at, "Results")
	await at._wait(0.6)
	await at._shot("gui_results_won")
	main.goto("results", {"won": false, "floor": 2, "clock": 120.0, "kills": 23, "rooms": 9, "time": 431.0,
		"streak": 4, "hits": 14, "candle": "tallow", "relics": ["blue_flame", "moth_friend"], "level": 2, "floors": 4,
		"seed": 1234567, "killer": "e:skeleton"})
	await _screen(at, "Results")
	await at._wait(0.6)
	await at._shot("gui_results_dead")
	# ---- Reduce motion: the title and a modal appear at once
	Game.settings["reduce_motion"] = true
	main.goto("title")
	await _screen(at, "Title")
	await at._wait(2.8)
	SettingsPanel.open(main.current.root)
	await at._wait(0.05)
	await at._shot("gui_calm_settings")
	Game.settings["reduce_motion"] = false
	print("[gui] DONE")


static func _game(at: Node) -> Node:
	var main: Node = at.main
	var t := 0.0
	while t < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await at._wait(0.1)
		t += 0.1
	await at._wait(1.2)
	return main.current


static func _screen(at: Node, nm: String) -> void:
	var main: Node = at.main
	var t := 0.0
	while t < 10.0 and not (main.current and main.current.name == nm and not main._busy):
		await at._wait(0.1)
		t += 0.1
