class_name TalkTour
extends RefCounted
## v2.7 dialogue: the talking scenes' judges and tour (docs/streams/v27_dialogue.md).
##   --autotest --talkcheck                      every guardian has a first-meeting scene (2-4 lines), a fall (1-2) and
##                                               later one-liners; every speaker, face and voice exists; scenes never
##                                               open with a live foe (a real meeting and a real fall, checked while
##                                               they play); the setting's three values (First time / Always / Off);
##                                               Tonight's Candle never takes more than a tap; the bot never waits on a
##                                               scene; saves remember who was met; the opening and the endings' beats.
##                                               Exit 1 on a FAIL.
##   --autotest --tour --talk --shots=/abs/dir [--fit]   the opening's panels, four guardian conversations, a later
##                                               meeting's one line, a fall with Martha's memory, the Settings row, the
##                                               Journal's Watch the beginning, an ending's closing beat
##     --talk=all                                every guardian's first two lines, then every candle's talk portrait
##     --talk=candles                            only the candles' portraits
## Every test plays on a throwaway profile in memory (Game.no_save): nothing reaches the real save slots.

static var fails := 0
static var checks := 0


static func _ok(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("[talkcheck] PASS ", what)
	else:
		fails += 1
		print("[talkcheck] FAIL ", what)


static func _fresh() -> void:
	Game.no_save = true
	Game.records = Game.RECORDS.duplicate(true)
	Game.records["seen_intro"] = true
	Game.records["unlocked"] = Candles.ORDER.duplicate()   # no "new candle" news over the shots
	Game.records["runs"] = 3
	Game.settings["talk"] = "first"


## The world, once the screen before it has finished its fade.
static func _world(bot: Node, params := {"seed": 31}) -> Node:
	var main: Node = bot.main
	while main._busy:
		await bot._wait(0.05)
	main.goto("game", params)
	var waited := 0.0
	await bot._wait(0.2)
	while waited < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await bot._wait(0.1)
		waited += 0.1
	await bot._wait(0.4)
	var w: Node = main.current
	w.player.invuln = 9999.0
	return w


## Into this guardian's room (BossIntro's staging): returns once its entrance has ended and a scene is up (or not).
static func _meet(bot: Node, w: Node, kind: String, wait_scene := true) -> Enemy:
	var item: Array = []
	for it in BossIntro.TOUR:
		if it[0] == kind:
			item = it
	var b: BossIntro = await BossIntro._tour_enter(bot, w, item)
	if b == null:
		return null
	var e := b.e
	var waited := 0.0
	while waited < 4.0 and (is_instance_valid(b) or (wait_scene and Talk.live == null)):
		await bot._wait(0.02)
		waited += 0.02
	return e


## Waits until the scene's current line has typed out (or `secs`), real time.
static func _typed(bot: Node, secs := 6.0) -> void:
	var t := 0.0
	while t < secs and Talk.live != null and Talk.live._typing():
		await bot._wait(0.05)
		t += 0.05


static func _until_closed(bot: Node, secs := 8.0) -> bool:
	var t := 0.0
	while t < secs and Talk.live != null:
		await bot._wait(0.05)
		t += 0.05
	return Talk.live == null


## A press, as a player makes it (a key: it finishes the line, then moves on).
static func _press(bot: Node, key := KEY_SPACE) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventKey.new()
	up.keycode = key
	up.physical_keycode = key
	Input.parse_input_event(up)
	await bot._wait(0.12)


# ================================================================ --tour --talk

static func tour(bot: Node) -> void:
	_fresh()
	Talk.force = true
	bot.args["nocard"] = true
	var only := str(bot.args.get("talk", "")) if bot.args.get("talk") is String else ""
	if only == "":
		await _opening_shots(bot)
	var w: Node = await _world(bot)
	if only == "all" or only == "candles":   # --talk=all: every guardian's first two lines and every candle's portrait
		for item in (BossIntro.TOUR if only == "all" else []):
			await _meet(bot, w, str(item[0]))
			if Talk.live == null:
				print("[talk] tour: no scene for ", item[0])
				continue
			await _typed(bot)
			await bot._shot("all_%s_1" % item[0])
			await bot._wait(Talk.HOLD)
			await _press(bot)
			await _typed(bot)
			await bot._shot("all_%s_2" % item[0])
			Talk.live.skip()
			await _until_closed(bot)
			BossIntro._tour_clear(w)
		# every candle of the house speaks with its own face, colours and name (the speaker "me" is the candle played);
		# opened directly here, so the HUD steps aside by hand, as Talk._hold does for a scene in a run
		w.hud.visible = false
		for cid in Candles.ORDER:
			var t := Talk.open(Talk._layer(w), [{"who": "me", "face": "brave", "text": "(the tour) Going up. Don't wait for me."},
				{"who": "martha", "face": "smile", "text": "..."}], {"candle": cid})
			await bot._wait(1.4)
			await bot._shot("candle_%s" % cid)
			t.skip()
			await _until_closed(bot)
		w.hud.visible = true
		Talk.force = false
		print("[talk] tour done")
		return
	# ---- four first meetings: a line mid-typing, the candle's answer, and the last line
	for kind in ["big_zombie", "wax_mother", "organist", "weathercock"]:
		var e: Enemy = await _meet(bot, w, kind)
		if Talk.live == null:
			print("[talk] tour: no scene for ", kind)
			continue
		await bot._wait(0.55)
		await bot._shot("meet_%s_typing" % kind)
		await _typed(bot)
		await _press(bot)
		await bot._wait(0.25)
		await _typed(bot)
		await bot._shot("meet_%s_answer" % kind)
		while Talk.live != null and Talk.live._i < Talk.live.lines.size() - 1:
			await _press(bot)
			await _typed(bot)
		if kind == "organist":
			await bot._shot("meet_%s_last" % kind)
		await _press(bot)
		await _until_closed(bot)
		await bot._wait(0.3)
		if kind == "big_zombie":
			await bot._shot("meet_big_zombie_fight_starts")
			# its fall: the last words, then Martha's memory
			w.player.position = w.free_spot_near(w.room.center() + Vector2(-64, 8), 6.0)
			e.hp = 0.0
			e._die()
			var waited := 0.0
			while Talk.live == null and waited < 5.0:
				await bot._wait(0.05)
				waited += 0.05
			await _typed(bot)
			await bot._shot("fall_big_zombie")
			await _press(bot)
			await bot._wait(0.6)
			await bot._shot("fall_big_zombie_martha_typing")
			await _typed(bot)
			await bot._shot("fall_big_zombie_martha")
			await _press(bot)
			await _until_closed(bot)
			await bot._wait(1.5)
			# a later meeting: one short line, it closes by itself
			await _meet(bot, w, "big_zombie")
			await _typed(bot)
			await bot._shot("again_big_zombie")
			await _until_closed(bot)
	# ---- the setting
	BossIntro._tour_clear(w)
	w.toggle_pause()
	await bot._wait(0.3)
	SettingsPanel.open(w.hud.root, 0)
	await bot._wait(0.5)
	await bot._shot("settings_story_scenes")
	# ---- the Journal's Diary tab: Watch the beginning (an older slot that never saw it: the gold dot)
	Talk.talks().erase("opening")
	var j := Journal.open(w.hud.root, Journal.TABS.find("diary"))
	await bot._wait(0.6)
	await bot._shot("journal_watch_the_beginning")
	j._watch.pressed.emit()
	await bot._wait(2.2)
	await bot._shot("journal_opening_replay")
	for n in j.get_children():   # the replay ends (Skip) and gives the Journal back
		if n is Opening:
			n.skip()
	await bot._wait(0.5)
	# ---- an ending's closing beat: the true ending, the candle and Martha's memory on the sill before dawn
	for c in w.hud.root.get_children():
		if c.get_meta("modal", false):
			c.queue_free()
	w.hud.pause_layer = null
	await bot._wait(0.3)
	var e := await _stage_ending(bot, w, "true")
	var waited := 0.0
	while waited < 20.0 and Talk.live == null and is_instance_valid(e):
		await bot._wait(0.1)
		waited += 0.1
	await _typed(bot)
	await bot._shot("ending_true_beat")
	await _press(bot)
	await bot._wait(0.3)
	await _typed(bot)
	await bot._shot("ending_true_beat_martha")
	while Talk.live != null:
		await _press(bot)
		await _typed(bot)
	await bot._wait(1.2)
	await bot._shot("ending_true_after_beat")
	e.queue_free()
	Talk.force = false
	bot.args.erase("nocard")
	print("[talk] tour done")


## A fresh slot's first run: main.goto("game") plays the opening first; a shot at each panel's moment.
static func _opening_shots(bot: Node) -> void:
	Game.records["runs"] = 0
	Talk.talks().erase("opening")
	var main: Node = bot.main
	while main._busy:
		await bot._wait(0.05)
	main.goto("game", {"seed": 31})
	var waited := 0.0
	while waited < 6.0 and not (main.current and main.current.name == "Opening"):
		await bot._wait(0.05)
		waited += 0.05
	var o: Opening = main.current as Opening
	if o == null:
		print("[talk] tour: NO OPENING on a fresh slot's first run")
		return
	print("[talk] opening: a fresh slot's first run starts with it")
	var t0 := Time.get_ticks_msec()
	# [panel, line in the panel, seconds into the line, shot]
	for want in [["house", 1, 1.6, "opening_1_house"], ["dial", 0, 3.0, "opening_2_clock_strikes"],
			["kitchen", 0, 1.8, "opening_3_kitchen"], ["kitchen", 2, 0.9, "opening_4_match"],
			["kitchen", 2, 1.7, "opening_5_lit"], ["cellar", 0, 2.6, "opening_6_cellar_lit"],
			["cellar", 1, 1.6, "opening_7_martha"], ["cellar", 2, 1.1, "opening_8_goes_up"]]:
		var w2 := 0.0
		while is_instance_valid(o) and w2 < 40.0 and not (o._panel == want[0] and o._state == "line" and o._i - o._first == want[1] and o._lt >= want[2]):
			await bot._wait(0.02)
			w2 += 0.02
		if not is_instance_valid(o):
			break
		await bot._shot(str(want[3]))
	while is_instance_valid(o) and main.current == o:
		await bot._wait(0.1)
	print("[talk] opening: %.1f s, then the run" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await bot._wait(1.0)
	Game.records["runs"] = 3


# ================================================================ --talkcheck

static func check(bot: Node) -> void:
	fails = 0
	checks = 0
	_fresh()
	_static_checks()
	bot.args["nocard"] = true
	var w: Node = await _opening_checks(bot)
	# ---- Story scenes: First time (the default)
	_ok(Talk.mode() == "first" and Game.RECORDS.has("talks") and str(Game.settings.get("talk")) == "first",
		"the setting defaults to First time; slots keep a \"talks\" record")
	var e: Enemy = await _meet(bot, w, "big_zombie")
	var t: Talk = Talk.live
	_ok(t != null and t.lines.size() == TalkLines.MEET["big_zombie"].size() and not t.short,
		"a first meeting: the whole scene (%d lines) after the entrance" % (t.lines.size() if t else 0))
	_held(w, e, "the first meeting")
	_ok(t != null and t._typing(), "the line types out (%.0f letters a second)" % Talk.CPS)
	await _press(bot)   # inside HOLD: ignored
	_ok(t != null and is_instance_valid(t) and t._i == 0 and t._typing(), "a press in the first %.1f s (meant for the game) is ignored" % Talk.HOLD)
	await bot._wait(Talk.HOLD)
	await _press(bot)
	_ok(is_instance_valid(t) and t._i == 0 and not t._typing(), "a press finishes the line")
	await _press(bot)
	_ok(is_instance_valid(t) and t._i == 1, "the next press moves on")
	while Talk.live != null:
		await _press(bot)
		await _typed(bot)
	await bot._wait(0.1)
	_fighting(w, e, "after the first meeting")
	_ok(int(Talk.talks().get("meet:big_zombie", 0)) == 1, "the slot remembers it met Old Rot")
	# ---- its fall: once it has faded, before the rewards, nothing else up
	var fell := await _fall(bot, w, e)
	_ok(fell.size() == TalkLines.FALL["big_zombie"].size(), "a first fall: its lines (%d)" % fell.size())
	_ok(w.room.data["cleared"], "the room's rewards come after the fall's words")
	_ok(int(Talk.talks().get("fall:big_zombie", 0)) == 1, "the slot remembers Old Rot fell")
	# ---- a later meeting: one short line that closes by itself, then no words at its fall
	e = await _meet(bot, w, "big_zombie")
	t = Talk.live
	_ok(t != null and t.short and t.lines.size() == 1, "a later meeting: one short line")
	var closed := await _until_closed(bot, 8.0)
	_ok(closed, "the short line closes by itself (no press needed)")
	_fighting(w, e, "after a later meeting's line")
	fell = await _fall(bot, w, e)
	_ok(fell.is_empty(), "a later fall says nothing (First time)")
	# ---- Always: the whole scene every time
	Game.settings["talk"] = "always"
	e = await _meet(bot, w, "big_zombie")
	t = Talk.live
	_ok(t != null and not t.short and t.lines.size() == TalkLines.MEET["big_zombie"].size(), "Always: the whole scene again")
	if t:
		await bot._wait(Talk.HOLD)
		await _press(bot, KEY_ESCAPE)
	await _until_closed(bot)
	_fighting(w, e, "after Esc (Skip)")
	fell = await _fall(bot, w, e)
	_ok(fell.size() == TalkLines.FALL["big_zombie"].size(), "Always: the fall's words again")
	# ---- Off: nothing at all
	Game.settings["talk"] = "off"
	var before: Dictionary = Talk.talks().duplicate()
	e = await _meet(bot, w, "wax_mother", false)
	await bot._wait(0.3)
	_ok(Talk.live == null and e != null and e.active and not e.intro, "Off: no scene, the fight starts after the entrance")
	fell = await _fall(bot, w, e)
	_ok(fell.is_empty() and Talk.talks() == before, "Off: no words at the fall, nothing recorded")
	Game.settings["talk"] = "first"
	# ---- Tonight's Candle: one line at most, never more than a tap; the first meeting's scene waits for a normal night
	w.daily = true
	e = await _meet(bot, w, "wax_mother")
	t = Talk.live
	_ok(t != null and t.short and t.lines.size() == 1 and str(t.lines[0]["text"]) == str(TalkLines.MEET["wax_mother"][0]["text"]),
		"Tonight's Candle: a first meeting is its first line only")
	closed = await _until_closed(bot, 8.0)
	_ok(closed and not Talk.seen("meet:wax_mother"), "it closes by itself, and the whole scene still waits for a normal night")
	BossIntro._tour_clear(w)
	e = await _meet(bot, w, "wax_mother")
	await bot._wait(Talk.HOLD + 0.05)
	await _press(bot)
	await bot._wait(0.25)
	_ok(Talk.live == null, "Tonight's Candle: one tap closes it at once")
	_fighting(w, e, "after a tap in Tonight's Candle")
	w.daily = false
	# ---- never with a live foe: another creature up in the room, no scene
	e = await _meet(bot, w, "furnace", false)
	if Talk.live:
		Talk.live.skip()
		await _until_closed(bot)
	var extra: Enemy = w.spawn_enemy("goblin", w.free_spot_near(w.room.center() + Vector2(50, 20), 6.0))
	await bot._wait(0.2)
	Talk.talks().erase("meet:furnace")
	e.active = false
	e.intro = true
	_ok(not Talk.meet(w, e) and Talk.live == null, "a scene never opens while another foe is up")
	e.intro = false
	e.active = true
	extra.hp = 0.0
	extra._die()
	# ---- Reduce motion: the whole line at once
	Game.settings["reduce_motion"] = true
	e = await _meet(bot, w, "ossuary")
	t = Talk.live
	_ok(t != null and not t._typing(), "Reduce motion: the line appears whole")
	if t:
		t.skip()
	await _until_closed(bot)
	Game.settings["reduce_motion"] = false
	# ---- the bot (and every other test) never waits on a scene
	Talk.force = false
	Talk.talks().clear()
	e = await _meet(bot, w, "sexton", false)
	await bot._wait(0.1)
	_ok(Talk.live == null and e != null and e.active and not Talk.seen("meet:sexton"),
		"the play-test bot: no scene, the guardian fights right after its entrance, nothing recorded")
	Talk.force = true
	# ---- saves remember who was met (the slot file's format)
	Talk.note("meet:organist")
	var cf := ConfigFile.new()
	for k in Game.records.keys():
		cf.set_value("records", k, Game.records[k])
	var back := ConfigFile.new()
	back.parse(cf.encode_to_text())
	var got: Dictionary = back.get_value("records", "talks", {})
	_ok(int(got.get("meet:organist", 0)) == 1, "a save slot's file keeps the talks record %s" % str(got))
	BossIntro._tour_clear(w)
	await _ending_checks(bot, w)
	Talk.force = false
	bot.args.erase("nocard")
	print("[talkcheck] %d checks, %d failed -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])


## The opening: when it plays (a fresh slot's first run only, never under a test), that it is skippable and leads
## into the same run, its length, its lines. Returns the run it led into.
static func _opening_checks(bot: Node) -> Node:
	var main: Node = bot.main
	var bad: Array = []
	var font: Font = Art.font_small
	for ln in TalkLines.OPENING:
		if not Opening.ART.has(str(ln.get("panel", ""))):
			bad.append("panel " + str(ln.get("panel", "")))
		var who := str(ln.get("who", ""))
		if who != "" and who != "me" and who != "martha":
			bad.append("speaker " + who)
		if font.get_multiline_string_size(str(ln["text"]), HORIZONTAL_ALIGNMENT_CENTER, 340.0, 8).y > font.get_height(8) * 2.0 + 0.5:
			bad.append("over two lines: " + str(ln["text"]).substr(0, 24))
	for p in Opening.ART.values() + [Ending.SKY]:   # a room is two frames (its torches), the rest one picture
		if not (Art.has(str(p)) or Art.has(str(p) + "_f0")):
			bad.append("art " + str(p))
	for k in ["stand", "match", "light"]:
		if not Art.has("talk/martha_" + k):
			bad.append("talk/martha_" + k)
	var secs := Opening.length()
	_ok(bad.is_empty() and secs >= 20.0 and secs <= 40.0, "the opening: %d lines over %d panels, %.1f s when nobody taps (20-40), its art %s" % [
		TalkLines.OPENING.size(), Opening.ART.size(), secs, str(bad)])
	# when it plays
	Game.records["runs"] = 0
	Talk.talks().erase("opening")
	Talk.force = false
	_ok(not Opening.wanted(main, {}), "under a test (the bot, the tours) the opening never plays")
	Talk.force = true
	_ok(Opening.wanted(main, {}) and not Opening.wanted(main, {"opened": true}), "a fresh slot's first run: the opening plays (once)")
	Game.records["runs"] = 2
	Records.clear_new("d:opening")
	_ok(not Opening.wanted(main, {}) and Records.is_new("d:opening"),
		"a slot with runs that never saw it: no opening, the Journal's Diary tab shows it waiting (gold dot)")
	Game.records["runs"] = 0
	# a fresh slot's Light the wick: the opening first, Skip, then the same run
	while main._busy:
		await bot._wait(0.05)
	main.goto("game", {"seed": 31})
	var waited := 0.0
	while waited < 6.0 and not (main.current and main.current.name == "Opening" and not main._busy):
		await bot._wait(0.05)
		waited += 0.05
	var o: Node = main.current
	_ok(o != null and o.name == "Opening", "main.goto(\"game\") on a fresh slot opens with the story")
	await bot._wait(Opening.TAP_HOLD + 0.2)
	await _press(bot, KEY_ESCAPE)
	waited = 0.0
	while waited < 6.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await bot._wait(0.1)
		waited += 0.1
	var w: Node = main.current
	_ok(w != null and w.name == "Game" and int(w.run_seed) == 31 and Talk.seen("opening") and not Records.is_new("d:opening"),
		"Esc skips it into the same run (seed 31), and the slot remembers it saw the opening")
	_ok(not Opening.wanted(main, {}), "it never plays again by itself (the Journal's Diary tab replays it)")
	await bot._wait(0.4)
	w.player.invuln = 9999.0
	Game.records["runs"] = 3
	# the Journal's replay: over the Journal, then back
	var back := [false]
	var r := Opening.watch(w.hud.root, func(): back[0] = true)
	await bot._wait(1.0)
	r.skip()
	await bot._wait(0.6)
	_ok(back[0] and not is_instance_valid(r), "Watch the beginning plays over the Journal and gives it back")
	return w


## The endings' closing beat: on its card, before the last one; the setting applies; Tallow's own beat only for him.
static func _ending_checks(bot: Node, w: Node) -> void:
	var bad: Array = []
	for id in Diary.ENDINGS:
		var lines: Array = TalkLines.ENDINGS.get(id, [])
		var card := int(TalkLines.ENDING_CARD.get(id, -1))
		if lines.is_empty() or card < 0 or card > 3:
			bad.append(id)
		for l in lines:
			var who := str(l.get("who", ""))
			if not who in ["me", "martha"] or (who == "me" and not TalkPortrait.FACES.has(str(l.get("face", "open")))):
				bad.append("%s: %s" % [id, who])
	_ok(bad.is_empty(), "all %d endings close with a beat (the candle and Martha's memory) on a card before the last %s" % [Diary.ENDINGS.size(), str(bad)])
	Game.settings["talk"] = "first"
	Talk.talks().erase("end:true")
	var e := await _stage_ending(bot, w, "true")
	var waited := 0.0
	while waited < 20.0 and Talk.live == null and is_instance_valid(e):
		await bot._wait(0.1)
		waited += 0.1
	_ok(Talk.live != null and is_instance_valid(e) and e._card == int(TalkLines.ENDING_CARD["true"]),
		"the true ending: the beat opens on its card %d" % int(TalkLines.ENDING_CARD["true"]))
	while Talk.live != null:
		await _press(bot)
		await _typed(bot)
	waited = 0.0
	while waited < 4.0 and is_instance_valid(e) and e._card <= int(TalkLines.ENDING_CARD["true"]):
		await bot._wait(0.1)
		waited += 0.1
	_ok(is_instance_valid(e) and e._card == int(TalkLines.ENDING_CARD["true"]) + 1, "after the beat the ending goes on to its last card")
	e.queue_free()
	await bot._wait(0.2)
	_ok(Talk.ending_lines(w, "true", int(TalkLines.ENDING_CARD["true"]), "tallow").is_empty(), "First time: the same ending in the same slot has no beat again")
	Game.settings["talk"] = "always"
	_ok(not Talk.ending_lines(w, "whole_story", int(TalkLines.ENDING_CARD["whole_story"]), "tallow").is_empty()
		and Talk.ending_lines(w, "housekeeper", int(TalkLines.ENDING_CARD["housekeeper"]), "tea_light").is_empty(),
		"Always: every time; the Housekeeper's beat is Tallow's own (not for another candle)")
	Game.settings["talk"] = "off"
	_ok(Talk.ending_lines(w, "windows", int(TalkLines.ENDING_CARD["windows"]), "tallow").is_empty(), "Off: no beat")
	Game.settings["talk"] = "first"


## An ending's cards over the world, the way Diary.win_ending starts one (its end does nothing here).
static func _stage_ending(bot: Node, w: Node, id: String) -> Ending:
	var e := Ending.new()
	e.ending = id
	e.setup(float(w.clock_minutes()), "tallow", func(): pass)
	w.add_child(e)
	await bot._wait(0.2)
	return e


## The guardian is held while its meeting plays: harmless, untouchable, its AI waiting, the house paused, no foe up.
static func _held(w: Node, e: Enemy, what: String) -> void:
	var others := 0
	for m in w.enemies:
		if is_instance_valid(m) and m.alive and m != e:
			others += 1
	_ok(e != null and is_instance_valid(e) and e.intro and not e.active and w.get_tree().paused and others == 0
		and w.enemy_shots.is_empty() and not w.hud.visible,
		"%s opens with no live foe: the guardian held (intro %s, active %s), the house paused, %d other foes, the HUD hidden" % [
			what, e.intro if e else "-", e.active if e else "-", others])


static func _fighting(w: Node, e: Enemy, what: String) -> void:
	_ok(e != null and is_instance_valid(e) and e.active and not e.intro and not w.get_tree().paused and w.hud.visible,
		"%s: the fight starts (the guardian active, the house running, the HUD back)" % what)


## Snuffs the guardian and returns the fall scene's lines ([] when none opened); checks nothing else is up meanwhile.
static func _fall(bot: Node, w: Node, e: Enemy) -> Array:
	if e == null or not is_instance_valid(e):
		return []
	w.player.position = w.free_spot_near(w.room.center() + Vector2(-64, 8), 6.0)
	e.hp = 0.0
	e._die()
	var waited := 0.0
	while Talk.live == null and waited < 3.0 and not w.room.data["cleared"]:
		await bot._wait(0.05)
		waited += 0.05
	var t: Talk = Talk.live
	if t == null:
		return []
	var lines := t.lines.duplicate()
	_ok(w.count_enemies() == 0 and w.enemy_shots.is_empty() and not w.room.data["cleared"] and w.get_tree().paused,
		"a fall's words open with nothing up, the house paused, before the rewards")
	while Talk.live != null:
		await _press(bot)
		await _typed(bot)
	var t2 := 0.0
	while not w.room.data["cleared"] and t2 < 4.0:
		await bot._wait(0.05)
		t2 += 0.05
	return lines


## The line table: every guardian has its scenes, every speaker / face / voice exists, every line fits the box.
static func _static_checks() -> void:
	var bad: Array = []
	var guardians: Array = []
	for k in Enemy.DEFS:
		if Enemy.DEFS[k].get("boss", false):
			guardians.append(k)
	for k in guardians:
		var m: Array = TalkLines.MEET.get(k, [])
		var f: Array = TalkLines.FALL.get(k, [])
		var a: Array = TalkLines.AGAIN.get(k, [])
		if m.size() < 2 or m.size() > 4:
			bad.append("%s: %d meeting lines" % [k, m.size()])
		if f.size() < 1 or f.size() > 2:
			bad.append("%s: %d fall lines" % [k, f.size()])
		if a.is_empty():
			bad.append("%s: no later line" % k)
		if not TalkLines.SPEAKERS.has(k):
			bad.append("%s: no portrait / voice" % k)
	_ok(guardians.size() == 16 and bad.is_empty(), "all %d guardians have a first meeting (2-4 lines), a fall (1-2) and later lines %s" % [guardians.size(), str(bad)])
	bad.clear()
	var font: Font = Art.font_small
	var width := 384.0 - 140.0
	var longest := 0
	var all: Array = []
	for tbl in [TalkLines.MEET, TalkLines.FALL, TalkLines.AGAIN]:
		for k in tbl:
			for l in tbl[k]:
				all.append([k, l])
	for pair in all:
		var l: Dictionary = pair[1]
		var who := str(l.get("who", pair[0]))
		var text := str(l.get("text", ""))
		if text == "":
			bad.append("%s: an empty line" % pair[0])
		if who != "me" and who != "martha" and not TalkLines.SPEAKERS.has(who):
			bad.append("%s: unknown speaker %s" % [pair[0], who])
		var face := str(l.get("face", "open"))
		if who == "me" and not TalkPortrait.FACES.has(face):
			bad.append("%s: unknown face %s" % [pair[0], face])
		if who == "martha" and not face in ["open", "smile"]:
			bad.append("%s: Martha has no face %s" % [pair[0], face])
		longest = maxi(longest, text.length())
		if text.length() > TalkLines.LONGEST:
			bad.append("%s: %d letters" % [pair[0], text.length()])
		var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 8).y
		if h > font.get_height(8) * 3.0 + 0.5:
			bad.append("%s: more than three lines on a 384 px screen: %s" % [pair[0], text.substr(0, 30)])
	_ok(bad.is_empty(), "%d lines: known speakers and faces, none longer than %d letters (longest %d), three box lines at most %s" % [
		all.size(), TalkLines.LONGEST, longest, str(bad)])
	bad.clear()
	for f in TalkPortrait.FACES:
		for i in 3:
			if not Art.has("hero/face_" + str(TalkPortrait.FACES[f][i])):
				bad.append("hero/face_" + str(TalkPortrait.FACES[f][i]))
	for k in ["f0", "f1", "blink", "smile"]:
		if not Art.has("talk/martha_" + k):
			bad.append("talk/martha_" + k)
	for who in TalkLines.SPEAKERS:
		var v: Array = TalkLines.voice(who)
		if not Audio.has_sound(str(v[0])):
			bad.append("voice of %s" % who)
		var sp: Dictionary = TalkLines.SPEAKERS[who]
		if sp.has("crop"):
			var tex := Records.portrait(who)
			var c: Array = sp["crop"]
			if tex == null or int(c[0]) < 0 or int(c[1]) < 0 or int(c[0]) + 24 > tex.get_width() or int(c[1]) + 24 > tex.get_height():
				bad.append("crop of %s" % who)
	_ok(bad.is_empty(), "every face sprite, Martha's portrait, every voice and every portrait crop exists %s" % str(bad))
