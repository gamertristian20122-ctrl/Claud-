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
static var _rows: Array = []   # one summary row per device


static func _ok(cond: bool, what: String) -> void:
	print("[primer] %s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


## What a text teaches: a list of lesson tags (empty = not a teaching text: story, place names, numbers).
static func lessons(text: String) -> Array:
	var t := text.strip_edges()
	var out: Array = []
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
	at.get_tree().root.push_input(e, true)


static func drag(at: Node, idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	at.get_tree().root.push_input(e, true)


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
	title._play()                                  # Light the wick: the Slots screen
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
	main.goto("game", {"candle": "tallow", "floors": 4, "seed": seed_n, "seeded": false})
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
	for dev in devs:
		await _scenario(at, dev, seed_n)
	print("[primer] ---- summary (seed %d; game seconds; texts = teaching texts in the first 3:00)" % seed_n)
	for r in _rows:
		print("[primer] %-9s first kill %5.1f s   reading ~%4.1f s (%d words)   texts %d   repeats %d   re-told lessons %d   lessons %s" % r)
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
	var pr: Variant = w.get_meta("primer") if w.has_meta("primer") else null
	if pr != null:
		await _play_primer(at, w, dev)
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
	var counted := {}
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
	_rows.append([dev, t_kill, words / READ_WPS, words, n_teach, n_repeat, n_retold, ", ".join(lesson_list)])
	_ok(t_kill > 0.0, "%s: the first kill came %.1f s after Light the wick" % [dev, t_kill])
	log.queue_free()
	Game.base_time_scale = 1.0
	Engine.time_scale = 1.0
	if is_instance_valid(w) and not w.finished:
		w.finished = true
	at.main.goto("title")
	await at._wait(1.2)


## Plays the primer the way a player would on `dev` (filled in with the primer itself).
static func _play_primer(_at: Node, _w: Node, _dev: String) -> void:
	pass
