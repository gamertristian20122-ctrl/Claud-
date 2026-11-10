class_name PrimerCheck
extends RefCounted
## v2.7 onboarding judge (docs/streams/v27_onboarding.md): a brand-new player's first three minutes, simulated.
##   -- --autotest --primercheck [--device=touch|keyboard|gamepad] [--seed=N]
## Give it its own profile (XDG_DATA_HOME=/tmp/x ...); it never writes the save (Game.no_save).
## For each device (all three unless --device): a fresh save slot, the title's Light the wick -> New candle ->
## Midnight -> 4 floors -> the run (seed 2701 by default, so every device and every build sees the same house),
## the story card (Begin as soon as it takes a press), the primer with simulated input (thumbs on the screen, keys,
## a gamepad) when there is one, then the play-test bot to the first room's first kill, and on to minute three.
## Measured: game seconds from Light the wick to the first kill (simulated input: no reading), the words a player
## reads before it, and every teaching text shown in the three minutes (hints, card lines, chalk drawings, the
## primer's steps), each tagged with what it teaches; a repeat is a text that teaches nothing new.
## Then (when the game has a primer): Skip, the bot through a forced primer, Swap sticks and Reduce motion.
## Prints "[primer] ..." lines and "[primer] DONE fails=N" (exit 1 on a FAIL).

const SEED := 2701
const WINDOW := 180.0          # the first three minutes, from Light the wick
const READ_WPS := 3.3          # reading speed for the estimate (about 200 words a minute)

static var fails := 0
static var fast_starts := 0   # v2.8: runs lit straight from Light the wick (a first launch skips the three choosers)
static var _rows: Array = []   # one summary row per device


static func _ok(cond: bool, what: String) -> void:
	print("[primer] %s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


## What a text teaches: a list of lesson tags (empty = not a teaching text: story, place names, numbers).
static func lessons(text: String) -> Array:
	var t := text.strip_edges()
	var out: Array = []
	if t.begins_with("Keep firing"):
		return ["relic: keep firing to charge"]   # a relic's own lesson (Stove Door, Blowlamp), not aiming
	var rules := [
		["move", "(?i)(left thumb|wasd|left stick|^move\\b|walk a few)"],
		["aim", "(?i)(right thumb|arrow|right stick|\\baim|fire at)"],
		["bomb", "(?i)\\bbombs?\\b(?! might)"],
		["wax", "(?i)(wax is your|your wax is|wax = |melts you|melts minutes|drippings mend|= health = time)"],
		["spill", "(?i)(spill|warm drops|grab the drips)"],
		["keepsake", "(?i)(keepsake|is ready$)"],
		["kindling", "(?i)kindling"],
		["marked", "(?i)marked foe"],
		["treasure", "(?i)choose one"],
		["hollow", "(?i)(cracked|a hollow)"],
	]
	var names: Array = ["big round button", "special"]
	for id in Moves.LIST:
		names.append(str(Moves.LIST[id]["name"]).to_lower())
	var sp := "(?i)(" + "|".join(names.map(func(n): return "\\b" + n + "\\b")) + ")"
	rules.insert(3, ["special", sp])
	for r in rules:
		var re := RegEx.create_from_string(r[1])
		if re.search(t):
			out.append(r[0])
	# the special move's own line names its cost in wax: that is the move, not the wax lesson
	if "special" in out and "wax" in out and not t.to_lower().contains("melts"):
		out.erase("wax")
	return out


## Logs every teaching text while a run is on screen (polls the HUD: works on any build, primer or not).
class TeachLog extends Node:
	var at: Node
	var t := 0.0
	var on := false
	var msgs: Array = []      # [t, kind, text, lessons]
	var _hint := ""
	var _cards := {}
	var _chalk := {}
	var _primer := ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	## `tags`: what it teaches when the caller knows (a chalk drawing, a card); else read from the words. A hint
	## always teaches something: one the table does not know is its own lesson ("other: ...").
	func add(kind: String, text: String, tags: Variant = null) -> void:
		var ls: Array = tags if tags is Array else PrimerCheck.lessons(text)
		if ls.is_empty() and kind == "hint":
			ls = ["other: " + text.substr(0, 24)]
		msgs.append([t, kind, text, ls])

	func _process(dt: float) -> void:
		if not on:
			return
		t += dt
		var w: Node = at.main.current
		if w == null or w.name != "Game" or w.get("hud") == null or w.hud.root == null:
			return
		var hud: Node = w.hud
		var hl: Label = hud.hint
		if hl.modulate.a < 0.05:
			_hint = ""   # the same hint shown again later is a second showing
		elif hl.text != "" and hl.modulate.a > 0.3 and hl.text != _hint:
			_hint = hl.text
			add("hint", hl.text)
		for c in hud.root.get_children():
			if c.get_meta("modal", false) and not _cards.has(c.get_instance_id()) and not c.is_queued_for_deletion():
				_cards[c.get_instance_id()] = true
				# one card is one moment: its teaching lines are one text (story lines teach nothing)
				var lines: Array = []
				var tags: Array = []
				for l in c.find_children("*", "Label", true, false):
					var lt := (l as Label).text.strip_edges()
					var ls: Array = PrimerCheck.lessons(lt)
					if lt != "" and not ls.is_empty():
						lines.append(lt)
						for x in ls:
							if not x in tags:
								tags.append(x)
				if not lines.is_empty():
					add("card", " / ".join(lines), tags)
		var rm: Node = w.get("room")
		if rm and is_instance_valid(rm):
			var ch: Node = rm.get_node_or_null("Chalk")
			if ch and (ch as CanvasItem).is_visible_in_tree() and (ch as CanvasItem).modulate.a > 0.3:
				var spr: Variant = ch.get("_spr")
				if spr is Dictionary:
					for part in spr:
						var s: Sprite2D = spr[part]
						# a drawing counts once a run (walking back through the start room shows the same chalk)
						if s.texture and s.visible and not _chalk.has(part):
							_chalk[part] = true
							var info: Array = {"wax_time": ["WAX = TIME", ["wax"]], "move": ["MOVE", ["move"]], "aim": ["AIM + FIRE", ["aim"]],
								"bomb": ["BOMB", ["bomb"]], "keep": ["KEEPSAKE", ["keepsake"]], "special": ["SPECIAL", ["special"]]}.get(part, [part, [part]])
							add("chalk", "(chalk) " + str(info[0]), info[1])
		var pr: Variant = w.get_meta("primer") if w.has_meta("primer") else null
		if pr != null and is_instance_valid(pr):
			var m := str((pr as Node).get("message"))
			if m != "" and m != _primer:
				_primer = m
				add("primer", m, (pr as Node).get("lessons"))


# ---------------------------------------------------------------- input (what a player's hands do)

static func touch(at: Node, idx: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = down
	Stage.push_ui_input(at, e)   # v2.8: `pos` is in the UI's pixels; the glass may be finer (Screen: Big)


static func drag(at: Node, idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	Stage.push_ui_input(at, e)


static func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


static func axis(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = 0
	Input.parse_input_event(e)


static func button(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.device = 0
	Input.parse_input_event(e)


## Game-time wait (follows --speed).
static func gwait(at: Node, s: float) -> void:
	await at.get_tree().create_timer(s, true, false, false).timeout


static func _release_all() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_E, KEY_SHIFT, KEY_ENTER]:
		key(k, false)
	for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		axis(a, 0.0)
	for b in [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK]:
		button(b, false)


# ---------------------------------------------------------------- the run

## A fresh save slot, as on a phone that never played: settings at their defaults, nothing on disk.
static func _fresh(dev: String) -> void:
	Game.no_save = true
	Game.slot_live = false
	Game.slot = 1
	Game.level = Game.DEFAULT_LEVEL
	Game.records = Game.RECORDS.duplicate(true)
	Game.settings["swap_sticks"] = false
	Game.settings["reduce_motion"] = false
	Game.settings["touch_controls"] = "auto"
	Game.settings["aim"] = "assist"
	Game.settings["aim_assist"] = true
	Controls.set_device(dev)


## From the title's Light the wick to a lit run, the way a new player gets there. Returns the world.
static func _light(at: Node, seed_n: int) -> Node:
	var main: Node = at.main
	main.goto("title")
	var waited := 0.0
	while waited < 10.0 and not (main.current and main.current.name == "Title" and not main._busy):
		await at._wait(0.1)
		waited += 0.1
	await at._wait(0.4)
	var title: Node = main.current
	if Game.first_night():
		# v2.8: a first launch goes straight from Light the wick to the first night (Title._first_night): no slot,
		# difficulty or length chooser. The check lights it the same way, plus the fixed seed so every device and
		# build sees one house, and "opened" (the story's opening has just played, as before a real first run)
		fast_starts += 1
		main.autotest = null   # the world starts as it does for a real player (the story card, no test-only hints)
		title._first_night({"seed": seed_n, "seeded": false, "opened": true})
		waited = 0.0
		while waited < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null):
			await at._wait(0.05)
			waited += 0.05
		main.autotest = at
		return main.current
	title._play()                                  # Light the wick: the Slots screen (a device with a slot already)
	await gwait(at, 0.4)
	var slots: Node = null
	for c in (title.root as Control).get_children():
		if c is Slots:
			slots = c
	slots._new(1)                                  # New candle in slot 1 -> pick a difficulty
	await gwait(at, 0.4)
	_press_text(title.root, "Midnight")           # -> how long a night? (4 floors, the slider's default)
	await gwait(at, 0.4)
	# "Light it" does exactly this (Slots._new), plus the fixed seed so every device and build sees one house;
	# the run stays an ordinary one (not marked as a typed-in seed)
	for c in (title.root as Control).get_children():
		if c.get_meta("modal", false) or c is Slots:
			c.queue_free()
	Game.start_slot(1, 2)
	Records.set_night_floors(4)
	main.autotest = null   # the world starts as it does for a real player (the story card, no test-only hints)
	# v2.7 merge: "opened" = the story's opening (opening.gd) has just played, as it does before a real first run
	main.goto("game", {"candle": "tallow", "floors": 4, "seed": seed_n, "seeded": false, "opened": true})
	waited = 0.0
	while waited < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null):
		await at._wait(0.05)
		waited += 0.05
	main.autotest = at
	return main.current


static func _press_text(root: Node, text: String) -> bool:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
			return true
	return false


## The story card: wait until Begin takes a press (UI.hold_presses), then press it. Returns its words.
static func _begin(at: Node, w: Node) -> int:
	var words := 0
	for i in 40:
		var card: Node = null
		for c in w.hud.root.get_children():
			if c.get_meta("modal", false) and not c.is_queued_for_deletion():
				card = c
		if card == null:
			if i > 4:
				return words
			await at._wait(0.05)
			continue
		if words == 0:
			for l in card.find_children("*", "Label", true, false):
				words += (l as Label).text.split(" ", false).size()
		for b in card.find_children("*", "Button", true, false):
			if (b as Button).mouse_filter != Control.MOUSE_FILTER_IGNORE and (b as Button).is_visible_in_tree():
				(b as Button).pressed.emit()
				await at._wait(0.1)
				return words
		await at._wait(0.1)
	return words


static func check(at: Node) -> void:
	fails = 0
	_rows = []
	var devs: Array = [Controls.TOUCH, Controls.KEYS, Controls.PAD]
	if at.args.has("device"):
		devs = [str(at.args["device"])]
	var seed_n := int(at.args.get("seed", str(SEED)))
	if Game.slot_exists(1) or Game.slot_exists(2) or Game.slot_exists(3):
		print("[primer] note: this profile has save slots; the judge plays in memory only (Game.no_save)")
	if at.args.has("skiponly"):   # --skiponly: just Skip on the three devices (quick)
		await _skip_checks(at, seed_n)
		print("[primer] DONE fails=%d" % fails)
		return
	for dev in devs:
		await _scenario(at, dev, seed_n)
	if not at.args.has("device"):
		await _skip_checks(at, seed_n)
		await _never_checks(at, seed_n)
		await _variant_checks(at, seed_n)
		await _bot_check(at, seed_n)
	print("[primer] ---- summary (seed %d; game seconds; texts = teaching texts in the first 3:00)" % seed_n)
	for r in _rows:
		print("[primer] %-9s first kill %5.1f s   primer %5.1f s   reading ~%4.1f s (%d words)   texts %d   repeats %d   re-told lessons %d   lessons %s" % r)
	print("[primer] first launches lit straight from Light the wick (no choosers): %d" % fast_starts)
	print("[primer] DONE fails=%d" % fails)


static func _scenario(at: Node, dev: String, seed_n: int) -> void:
	_fresh(dev)
	Game.base_time_scale = 1.0
	Engine.time_scale = 1.0
	at.args.erase("drive")
	var log := TeachLog.new()
	log.at = at
	at.add_child(log)
	log.on = true                          # t = 0: Light the wick
	var w: Node = await _light(at, seed_n)
	_ok(w != null and w.name == "Game", "%s: Light the wick -> a run (seed %d)" % [dev, seed_n])
	if w == null:
		log.queue_free()
		return
	var story_words := await _begin(at, w)
	var primer_secs := 0.0
	if w.has_meta("primer"):
		primer_secs = await _play_primer(at, w, dev)
		var taught: Array = Game.records.get("primer_taught", [])
		_ok(str(Game.records.get("primer", "")) == "done" and taught.size() == Primer.STEPS.size(),
			"%s: the primer completes with simulated input in %.1f s (taught: %s)" % [dev, primer_secs, ", ".join(taught)])
		_ok(w.room.is_open and absf(w.player.wax - w.player.wax_max) < 0.01 and w.clock_minutes() <= 0.01,
			"%s: at its end the doors are open and the clock still reads %s" % [dev, Game.clock_text(w.clock_minutes())])
	else:
		print("[primer] %s: (no primer in this build)" % dev)
	at.args["drive"] = true                # the bot walks on to the first room and fights
	var t_kill := -1.0
	while log.t < WINDOW and is_instance_valid(w) and not w.finished:
		if t_kill < 0.0 and int(w.kills) >= 1:
			t_kill = log.t
			Game.base_time_scale = 4.0      # measured: the rest of the three minutes at 4x
			Engine.time_scale = 4.0
		await at._wait(0.05)
	log.on = false
	at.args.erase("drive")
	_release_all()
	# the words read before the first kill: the story card, then every teaching text up to that moment
	var words := story_words
	var told := {}
	var n_teach := 0
	var n_repeat := 0
	var n_retold := 0
	print("[primer] %s: every teaching text in the first 3:00 (t = game seconds from Light the wick)" % dev)
	for m in log.msgs:
		var ls: Array = m[3]
		if ls.is_empty():
			print("[primer]    t=%5.1f %-6s (not teaching) \"%s\"" % [m[0], m[1], str(m[2]).replace("\n", " / ")])
			continue
		n_teach += 1
		var fresh := ls.filter(func(x): return not told.has(x))
		var again := ls.filter(func(x): return told.has(x))
		n_retold += again.size()
		var rep := fresh.is_empty()
		if rep:
			n_repeat += 1
		for x in ls:
			told[x] = true
		if t_kill < 0.0 or float(m[0]) <= t_kill:
			if m[1] != "card":
				words += str(m[2]).trim_prefix("(chalk) ").split(" ", false).size()
		print("[primer]    t=%5.1f %-6s %s \"%s\" %s" % [m[0], m[1], "REPEAT" if rep else "      ", str(m[2]).replace("\n", " / "),
			str(ls) + ("  (again: %s)" % str(again) if not again.is_empty() and not rep else "")])
	var lesson_list: Array = told.keys()
	lesson_list.sort()
	_rows.append([dev, t_kill, primer_secs, words / READ_WPS, words, n_teach, n_repeat, n_retold, ", ".join(lesson_list)])
	_ok(t_kill > 0.0, "%s: the first kill came %.1f s after Light the wick" % [dev, t_kill])
	_ok(n_repeat == 0, "%s: no teaching text repeats a lesson in the first 3:00 (%d repeats)" % [dev, n_repeat])
	log.queue_free()
	await _leave(at, w)


static func _leave(at: Node, w: Node) -> void:
	Game.base_time_scale = 1.0
	Engine.time_scale = 1.0
	at.args.erase("drive")
	_release_all()
	if is_instance_valid(w) and not w.finished:
		w.finished = true
	at.main.goto("title")
	await at._wait(1.2)


## A run lit with `params` the way the game lights it for a real player (no test-only paths in world._ready).
static func _run(at: Node, params: Dictionary) -> Node:
	var main: Node = at.main
	main.autotest = null
	if not params.has("opened"):
		params["opened"] = true   # v2.7 merge: as after the story's opening, which a real first run plays first
	main.goto("game", params)
	var waited := 0.0
	while waited < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await at._wait(0.05)
		waited += 0.05
	main.autotest = at
	return main.current


## Skip, on each device: one tap / Enter / Back ends it at once; the doors open; it is never asked again in the slot.
static func _skip_checks(at: Node, seed_n: int) -> void:
	for dev in [Controls.TOUCH, Controls.KEYS, Controls.PAD]:
		_fresh(dev)
		var w: Node = await _light(at, seed_n)
		await _begin(at, w)
		var pr: Primer = Primer.of(w)
		if pr == null:
			_ok(false, "%s: a new slot's first run has the primer" % dev)
			continue
		while pr.step < 0 or pr.t < 0.4:
			await gwait(at, 0.05)
		var f0 := Engine.get_process_frames()
		match dev:
			Controls.TOUCH:
				var c: Vector2 = pr._skip.position + pr._skip.size / 2.0
				touch(at, 4, c, true)
				touch(at, 4, c, false)
			Controls.KEYS:
				key(KEY_ENTER, true)
				key(KEY_ENTER, false)
			Controls.PAD:
				button(JOY_BUTTON_BACK, true)
				button(JOY_BUTTON_BACK, false)
		var gone := false
		for i in 12:   # a skipped primer frees itself at once: read it while it is there (or the slot's record after)
			if not is_instance_valid(pr):
				gone = str(Game.records.get("primer", "")) == "skipped"
				break
			if pr.ended:
				gone = pr.skipped
				break
			await at.get_tree().process_frame
		var frames := Engine.get_process_frames() - f0
		_ok(gone and w.room.is_open and str(Game.records.get("primer", "")) == "skipped",
			"%s: Skip (%s) ends it within %d frames, the doors open, the slot remembers it" % [dev,
			{Controls.TOUCH: "a tap", Controls.KEYS: "Enter", Controls.PAD: "Back"}[dev], frames])
		if dev == Controls.TOUCH:
			_ok(w.hud.hint.text == Controls.controls_hint(), "touch: skipped before the sticks: the one-line controls reminder shows once (\"%s\")" % w.hud.hint.text)
			await _leave(at, w)
			var w2: Node = await _run(at, {"candle": "tallow", "floors": 4})
			_ok(not w2.has_meta("primer"), "touch: the next run in that slot has no primer (runs %d)" % int(Game.records["runs"]))
			await _leave(at, w2)
		else:
			await _leave(at, w)


## It never runs for a returning player, in Tonight's Candle or for a typed-in seed.
static func _never_checks(at: Node, _seed_n: int) -> void:
	_fresh(Controls.TOUCH)
	Game.slot_live = true
	Game.records["runs"] = 3          # a slot with runs from 2.6 (no primer record)
	Game.records["seen_intro"] = true
	var w: Node = await _run(at, {"candle": "tallow", "floors": 4})
	_ok(not w.has_meta("primer"), "a returning slot (3 runs before 2.7) gets no primer")
	await _leave(at, w)
	for params in [{"seed": 4242, "daily": true, "candle": "tallow"}, {"seed": 4242, "seeded": true, "candle": "tallow", "floors": 4}]:
		_fresh(Controls.TOUCH)
		var w2: Node = await _run(at, params)
		_ok(not w2.has_meta("primer"), "%s on a fresh slot: no primer" % ("Tonight's Candle" if params.has("daily") else "a typed-in seed"))
		await _leave(at, w2)


## Swap sticks mirrors the thumbs and still plays through; Reduce motion is shorter.
static func _variant_checks(at: Node, seed_n: int) -> void:
	for v in ["swap", "calm"]:
		_fresh(Controls.TOUCH)
		Game.settings["swap_sticks"] = v == "swap"
		Game.settings["reduce_motion"] = v == "calm"
		var w: Node = await _light(at, seed_n)
		await _begin(at, w)
		var pr: Primer = Primer.of(w)
		while pr != null and pr.step < 0:
			await gwait(at, 0.05)
		var vs: Vector2 = w.hud.view_size()
		var mirrored: bool = pr != null and pr._spot(false).x > vs.x / 2.0 and pr._spot(true).x < vs.x / 2.0
		var secs := await _play_primer(at, w, Controls.TOUCH)
		if v == "swap":
			_ok(mirrored and str(Game.records.get("primer", "")) == "done", "Swap sticks: the move thumb is drawn on the right, the aim thumb on the left; it plays through (%.1f s)" % secs)
		else:
			var normal := 0.0
			for r in _rows:
				if r[0] == Controls.TOUCH:
					normal = float(r[2])
			_ok(str(Game.records.get("primer", "")) == "done" and (normal <= 0.0 or secs < normal),
				"Reduce motion: it plays through in %.1f s (%.1f s with motion)" % [secs, normal])
		Game.settings["swap_sticks"] = false
		Game.settings["reduce_motion"] = false
		await _leave(at, w)


## The play-test bot through a forced primer (--primer): it plays every step, then goes on to its first kill.
static func _bot_check(at: Node, seed_n: int) -> void:
	_fresh(Controls.TOUCH)
	Game.base_time_scale = 2.0
	at.args["primer"] = true
	at.args["drive"] = true
	at.main.goto("game", {"candle": "tallow", "floors": 4, "seed": seed_n, "seeded": false})
	var t := 0.0
	var w: Node = null
	while t < 120.0:
		w = at.main.current
		if w and w.name == "Game" and w.get("player") != null and not w.has_meta("primer") and int(w.kills) >= 1:
			break
		await gwait(at, 0.1)
		t += 0.1
	at.args.erase("primer")
	_ok(w != null and str(Game.records.get("primer", "")) == "done" and int(w.kills) >= 1,
		"the bot plays a forced primer through and reaches its first kill (%.0f game s; primer %s)" % [t, Game.records.get("primer", "-")])
	await _leave(at, w)


const REACT := 0.8   # s a player takes to see a step's picture and start doing it


## Plays the primer the way a player would on `dev`: real input events (fingers on the screen through the HUD and
## the primer, keys, a gamepad's sticks and buttons), a reaction time on every step. Returns its play seconds.
static func _play_primer(at: Node, w: Node, dev: String) -> float:
	var pr: Node = w.get_meta("primer")
	var held := {}
	var last := -2
	var tapped := false
	var t0 := -1.0
	var clock := 0.0
	while is_instance_valid(pr) and not pr.get("ended") and clock < 150.0:
		var s := int(pr.get("step"))
		if s >= 0 and t0 < 0.0:
			t0 = clock
		if s != last:
			_lift(at, dev, held)   # a new step: hands off, look at it first
			last = s
			tapped = false
		if s >= 0 and float(pr.get("t")) >= REACT and float(pr.get("_next_t")) < 0.0:
			var me: Vector2 = w.player.global_position
			match Primer.STEPS[s]:
				"move":
					_hold_move(at, dev, held, pr, Vector2.RIGHT)
				"aim":
					var d: Node = pr.get("_dummy")
					if d and is_instance_valid(d) and not d.get("popped"):
						_hold_aim(at, dev, held, pr, ((d as WaxDummy).target() - (me + Vector2(0, -6))).normalized())
				"wax":
					var goal := Vector2.INF
					for dr in pr.get("_drops"):
						if not dr["taken"] and float(dr["t"]) >= 0.0:
							goal = (dr["s"] as Node2D).global_position
							break
					if goal != Vector2.INF:
						_hold_move(at, dev, held, pr, (goal - me).normalized())
					else:
						_lift(at, dev, held)
				"bomb":
					if not tapped:
						tapped = true
						await _tap(at, dev, w, "bomb")
					else:
						_hold_move(at, dev, held, pr, Vector2.LEFT if me.x > w.room.center().x else Vector2.RIGHT)
				"special":
					if not tapped:
						tapped = true
						await _tap(at, dev, w, "special")
		await gwait(at, 1.0 / 30.0)
		clock += 1.0 / 30.0
	_lift(at, dev, held)
	return clock - maxf(t0, 0.0)


## Walk toward `dir` (a unit vector) on `dev`, holding it until _lift.
static func _hold_move(at: Node, dev: String, held: Dictionary, pr: Node, dir: Vector2) -> void:
	match dev:
		Controls.TOUCH:
			var c: Vector2 = pr._spot(false)
			if not held.has("f0"):
				touch(at, 0, c, true)
				held["f0"] = c
			var to := c + dir * 16.0
			drag(at, 0, to, to - (held["f0"] as Vector2))
			held["f0p"] = to
		Controls.PAD:
			axis(JOY_AXIS_LEFT_X, dir.x)
			axis(JOY_AXIS_LEFT_Y, dir.y)
			held["ls"] = true
		_:
			var want := {KEY_D: dir.x > 0.38, KEY_A: dir.x < -0.38, KEY_S: dir.y > 0.38, KEY_W: dir.y < -0.38}
			for k in want:
				if want[k] != bool(held.get(k, false)):
					key(k, want[k])
					held[k] = want[k]


## Aim and fire toward `dir`, holding it until _lift.
static func _hold_aim(at: Node, dev: String, held: Dictionary, pr: Node, dir: Vector2) -> void:
	match dev:
		Controls.TOUCH:
			var c: Vector2 = pr._spot(true)
			if not held.has("f1"):
				touch(at, 1, c, true)
				held["f1"] = c
			var to := c + dir * 12.0
			drag(at, 1, to, to - (held["f1"] as Vector2))
		Controls.PAD:
			axis(JOY_AXIS_RIGHT_X, dir.x)
			axis(JOY_AXIS_RIGHT_Y, dir.y)
			held["rs"] = true
		_:
			var k: Key = (KEY_RIGHT if dir.x > 0.0 else KEY_LEFT) if absf(dir.x) >= absf(dir.y) else (KEY_DOWN if dir.y > 0.0 else KEY_UP)
			for a in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				var on: bool = a == k
				if on != bool(held.get(a, false)):
					key(a, on)
					held[a] = on


## Press the bomb or the special move once: the HUD's round button on touch, E / F, RB / LT.
static func _tap(at: Node, dev: String, w: Node, what: String) -> void:
	match dev:
		Controls.TOUCH:
			var b: Control = w.hud.bomb_btn if what == "bomb" else w.hud.move_btn
			var c := b.position + b.size / 2.0
			touch(at, 2, c, true)
			await gwait(at, 0.1)
			touch(at, 2, c, false)
		Controls.PAD:
			if what == "bomb":
				button(JOY_BUTTON_RIGHT_SHOULDER, true)
				await gwait(at, 0.1)
				button(JOY_BUTTON_RIGHT_SHOULDER, false)
			else:
				axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				await gwait(at, 0.1)
				axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
		_:
			var k := KEY_E if what == "bomb" else KEY_F
			key(k, true)
			await gwait(at, 0.1)
			key(k, false)


static func _lift(at: Node, dev: String, held: Dictionary) -> void:
	if held.has("f0"):
		touch(at, 0, held.get("f0p", held["f0"]), false)
	if held.has("f1"):
		touch(at, 1, held["f1"], false)
	if dev == Controls.PAD:
		for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			axis(a, 0.0)
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		if bool(held.get(k, false)):
			key(k, false)
	held.clear()


# ---------------------------------------------------------------- the tour (--tour --primer)

## A run with the primer forced (--primer), its steps on one device. The bot plays each step once its picture is taken.
static func _staged_run(at: Node, dev: String) -> Node:
	_fresh(dev)
	at.args["primer"] = true
	at.args.erase("drive")
	at.main.goto("game", {"candle": "tallow", "floors": 4, "seed": SEED, "seeded": false})
	var waited := 0.0
	while waited < 10.0 and not (at.main.current and at.main.current.name == "Game" and at.main.current.get("player") != null and not at.main._busy):
		await at._wait(0.05)
		waited += 0.05
	return at.main.current


## Waits (game time) until the primer is on step `id` and its clock has passed `t0`; null if it ended first.
static func _at_step(at: Node, w: Node, id: String, t0: float) -> Node:
	for i in 400:
		var pr: Node = w.get_meta("primer") if w.has_meta("primer") else null
		if pr == null or not is_instance_valid(pr) or pr.get("ended"):
			return null
		var s := int(pr.get("step"))
		if s >= 0 and Primer.STEPS[s] == id and float(pr.get("t")) >= t0 and float(pr.get("_next_t")) < 0.0:
			return pr
		await gwait(at, 0.05)
	return null


static func tour(at: Node) -> void:
	var tag: String = at._vs()
	for dev in [Controls.TOUCH, Controls.KEYS, Controls.PAD]:
		var w: Node = await _staged_run(at, dev)
		var short: String = {Controls.TOUCH: "touch", Controls.KEYS: "keys", Controls.PAD: "pad"}[dev]
		for st in [["move", 0.3], ["aim", 0.55], ["wax", 2.2], ["bomb", 0.3], ["special", 0.3]]:
			var pr: Node = await _at_step(at, w, st[0], st[1])
			if pr == null:
				print("[primer] tour: no step %s on %s" % [st[0], dev])
				break
			await at._shot("primer_%s_%d_%s_%s" % [short, Primer.STEPS.find(st[0]) + 1, st[0], tag])
			at.args["drive"] = true
			while is_instance_valid(pr) and not pr.get("ended") and int(pr.get("step")) == Primer.STEPS.find(st[0]):
				await gwait(at, 0.05)
			at.args.erase("drive")
		await gwait(at, 0.3)
		await at._shot("primer_%s_6_ready_%s" % [short, tag])
	# Swap sticks (touch) and Reduce motion
	Game.settings["swap_sticks"] = true
	var w2: Node = await _staged_run(at, Controls.TOUCH)
	Game.settings["swap_sticks"] = true
	w2.hud._layout()
	var pr2: Node = await _at_step(at, w2, "move", 0.3)
	if pr2:
		await at._shot("primer_touch_swap_move_" + tag)
		at.args["drive"] = true
		await _at_step(at, w2, "aim", 0.55)
		at.args.erase("drive")
		await at._shot("primer_touch_swap_aim_" + tag)
	Game.settings["swap_sticks"] = false
	Game.settings["reduce_motion"] = true
	var w3: Node = await _staged_run(at, Controls.TOUCH)
	Game.settings["reduce_motion"] = true
	at.args["drive"] = true
	await _at_step(at, w3, "wax", 1.0)
	at.args.erase("drive")
	await at._shot("primer_calm_wax_" + tag)
	Game.settings["reduce_motion"] = false
	at.args.erase("primer")
	await _reel_tour(at, tag)


static func _find_reel(n: Node) -> PrimerReel:
	for c in n.find_children("*", "Control", true, false):   # (a script class: find_children's type sees Control)
		if c is PrimerReel:
			return c as PrimerReel
	return null


## How to play: the pause menu's button, the reel on every step (touch) and on keys / pad, the Journal's entry.
static func _reel_tour(at: Node, tag: String) -> void:
	_fresh(Controls.TOUCH)
	Game.records["runs"] = 4   # a returning player: no primer
	at.main.goto("game", {"candle": "tallow", "floors": 4, "seed": SEED, "seeded": false})
	await at._wait(2.0)
	var w: Node = at.main.current
	w.toggle_pause()
	await at._wait(0.4)
	await at._shot("howto_pause_menu_" + tag)
	_press_text(w.hud.pause_layer, L.t("How to play"))
	await at._wait(0.4)
	var reel := _find_reel(w.hud.root)
	if reel == null:
		print("[primer] tour: no reel")
		return
	for dev in [Controls.TOUCH, Controls.KEYS, Controls.PAD]:
		Controls.set_device(dev)
		var short: String = {Controls.TOUCH: "touch", Controls.KEYS: "keys", Controls.PAD: "pad"}[dev]
		var steps: Array = range(Primer.STEPS.size()) if dev == Controls.TOUCH else [0, 1, 3, 4]
		for i in steps:
			reel.step = i
			reel._texts()
			reel.t = [0.3, 0.42, 1.0, 0.9, 0.75][i]
			reel.set_process(false)   # hold the moment for the picture
			reel.queue_redraw()
			await at._wait(0.1)
			await at._shot("howto_reel_%s_%d_%s_%s" % [short, i + 1, Primer.STEPS[i], tag])
		reel.set_process(true)
	Controls.set_device(Controls.TOUCH)
	var top: Node = w.hud.root.get_child(w.hud.root.get_child_count() - 1)
	if top.get_meta("modal", false):
		top.queue_free()
	await at._wait(0.3)
	# the Journal's Records page: How to play (Show me opens the same reel)
	var j := Journal.open(w.hud.root, Journal.TABS.find("records"))
	await at._wait(0.5)
	j._select(0, false)
	await at._wait(0.3)
	await at._shot("howto_journal_" + tag)
	_press_text(j, L.t("Show me"))
	await at._wait(0.5)
	await at._shot("howto_journal_reel_" + tag)
