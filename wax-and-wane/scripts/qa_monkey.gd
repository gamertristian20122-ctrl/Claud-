extends RefCounted
## v2.7 QA (docs/streams/v27_qa.md): --monkey on a --playtest. While the bot plays, presses a person makes at any
## moment land on top of it every 0.3-1.4 s (real time): Android's Back, Esc / Start, M / the pad's Back (the map),
## the special move, a bomb, the keepsake, a tap on II / the minimap / anywhere, the app losing focus, and in the
## pause menu Resume, Map, Settings or the Journal. A watchdog prints a [monkey] PROBLEM line when the game stays
## paused (nothing closes it), the tree stays paused with nothing holding it, or time stays slowed:
##   godot --headless --path . -- --autotest --playtest --speed=4 --monkey [--seed=N] [--floors=N]
## (autotest._process calls step(); every run ends with a "[monkey] run: ..." line.)

static var _next := 0
static var _world_id := 0
static var _paused_ms := 0
static var _tree_ms := 0
static var _slow_ms := 0
static var _last_ms := 0
static var _release: Array = []    # events to send on the next step (key / pad releases, touch ups)
static var presses := {}
static var problems := 0


static func step(at: Node, w: Node) -> void:
	var now := Time.get_ticks_msec()
	var real := clampi(now - _last_ms, 0, 250) if _last_ms > 0 else 0
	_last_ms = now
	for ev in _release:
		Input.parse_input_event(ev)
	_release.clear()
	if w == null or w.name != "Game" or w.get("player") == null or at.main._busy:
		return
	if w.get_instance_id() != _world_id:
		_world_id = w.get_instance_id()
		presses = {}
		_paused_ms = 0
		_tree_ms = 0
		_slow_ms = 0
		_next = now + 1500
	if w.finished:
		if presses.has("_reported"):
			return
		presses["_reported"] = 1
		var shown := presses.duplicate()
		shown.erase("_reported")
		print("[monkey] run: %d problems so far, presses %s" % [problems, shown])
		return
	var tree: SceneTree = at.get_tree()
	_watch(at, w, tree, real)
	if now < _next or w.transitioning:
		return
	_next = now + randi_range(300, 1400)
	# a closing press (Back, Esc, B) in a menu must close something or resume: three in a row that change
	# nothing are a trap a person cannot get out of
	if _closing != "":
		var same: bool = w.paused and _layers(w) == _closing_layers
		_dead_presses = _dead_presses + 1 if same else 0
		if _dead_presses >= 3:
			_problem(w, "three closing presses in a row (%s) changed nothing (top %s)" % [_closing, _top(w)])
			_dead_presses = 0
		_closing = ""
	if w.paused:
		_in_menu(at, w)
	else:
		_in_play(at, w)


static var _closing := ""          # the closing press sent last step ("" = none)
static var _closing_layers := ""   # what was open when it was sent
static var _dead_presses := 0


## What is open on the HUD now: the paused flag and every modal layer, by instance.
static func _layers(w: Node) -> String:
	var ids: Array = []
	for c in w.hud.root.get_children():
		if c.get_meta("modal", false) and not c.is_queued_for_deletion():
			ids.append(c.get_instance_id())
	return "%s %s" % [w.paused, ids]


static func _closing_press(w: Node, what: String) -> void:
	_closing = what
	_closing_layers = _layers(w)


static func _watch(at: Node, w: Node, tree: SceneTree, real: int) -> void:
	_paused_ms = _paused_ms + real if w.paused else 0
	var held: bool = Juice.holding(w)   # the guardian's versus card pauses the house on purpose
	_tree_ms = _tree_ms + real if tree.paused and not w.paused and not held else 0
	_slow_ms = _slow_ms + real if Engine.time_scale < Game.base_time_scale * 0.99 and not w.paused else 0
	if _paused_ms > 20000:
		_problem(w, "paused for 20 s and nothing closed it (top %s)" % _top(w))
		_paused_ms = 0
		for i in 4:
			_back(at)
		if w.paused and w.hud.pause_layer != null:
			w.toggle_pause()
	if _tree_ms > 4000:
		_problem(w, "the tree has been paused for 4 s with no menu, card or entrance (top %s)" % _top(w))
		_tree_ms = 0
		tree.paused = false
	if _slow_ms > 3000:
		_problem(w, "time has run at x%.2f for 3 s" % (Engine.time_scale / Game.base_time_scale))
		_slow_ms = 0
		Engine.time_scale = Game.base_time_scale


static func _problem(w: Node, what: String) -> void:
	problems += 1
	print("[monkey] PROBLEM floor %d room %s (%s): %s" % [w.floor_num, w.cur_cell, w.room.data.get("type", "?"), what])
	var r: Node = w.hud.root
	var kids: Array = []
	for i in range(maxi(0, r.get_child_count() - 5), r.get_child_count()):
		var c: Node = r.get_child(i)
		kids.append("%s%s%s" % [c.name, " modal" if c.get_meta("modal", false) else "", "" if not (c is CanvasItem) or (c as CanvasItem).visible else " hidden"])
	var d := Diary.of(w)
	print("[monkey]    paused %s, tree %s, card %s, entrance %s, pause menu %s, map %s, page card %s, time x%.2f" % [w.paused,
		w.get_tree().paused, Juice.holding(w), BossIntro.live != null, w.hud.pause_layer != null, is_instance_valid(w.hud.map_layer),
		d.card != null and is_instance_valid(d.card), Engine.time_scale / Game.base_time_scale])
	print("[monkey]    hud top: %s" % ", ".join(kids))
	print("[monkey]    last presses: %s" % ", ".join(_log))


static func _top(w: Node) -> String:
	var r: Node = w.hud.root
	var top: Node = r.get_child(r.get_child_count() - 1)
	return "%s%s" % [top.name, " (modal)" if top.get_meta("modal", false) else ""]


static var _log: Array = []   # the last presses, for a PROBLEM line


static func _count(what: String) -> void:
	presses[what] = int(presses.get(what, 0)) + 1
	_log.append(what)
	if _log.size() > 14:
		_log.pop_front()


static func _back(at: Node) -> void:
	at.main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


static func _key(action: String) -> void:
	var down := DesignCheck._key_event(action, true)
	if down == null:
		return
	Input.parse_input_event(down)
	_release.append(DesignCheck._key_event(action, false))


static func _pad(button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	_release.append(up)


static func _tap(w: Node, vp_pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 7
	t.pressed = true
	t.position = DesignCheck._screen(w, vp_pos)
	Input.parse_input_event(t)
	var up := InputEventScreenTouch.new()
	up.index = 7
	up.position = t.position
	_release.append(up)


static func _in_play(at: Node, w: Node) -> void:
	var hud: Node = w.hud
	match randi() % 12:
		0, 1:
			_count("back")
			_back(at)
		2:
			_count("esc")
			_key("pause")
		3:
			_count("map_key")
			_key("map")
		4:
			_count("pad_back")
			_pad(JOY_BUTTON_BACK)
		5:
			_count("pad_start")
			_pad(JOY_BUTTON_START)
		6:
			_count("special")
			_key("special")
		7:
			_count("bomb")
			_key("bomb")
		8:
			_count("keepsake")
			_key("keepsake")
		9:
			_count("tap_ii")
			_tap(w, hud.pause_btn.position + hud.pause_btn.size / 2.0)
		10:
			_count("tap_minimap")
			_tap(w, hud.minimap.position + hud.minimap.size / 2.0)
		11:
			_count("focus_out")
			at.main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)


## In a menu (pause menu, map, Settings, Journal, a confirm, a reading card): mostly find the way back to the game.
static func _in_menu(at: Node, w: Node) -> void:
	var hud: Node = w.hud
	var r := randi() % 10
	if r <= 1 and hud.pause_layer != null and _top(w) == hud.pause_layer.name + " (modal)":
		var pick: String = ["Map", "Settings", "Journal"][randi() % 3]
		var b := _button(hud.pause_layer, L.t(pick))
		if b:
			_count("menu_" + pick.to_lower())
			b.pressed.emit()
			return
	match r:
		2, 3, 4:
			_count("back")
			_closing_press(w, "back")
			_back(at)
		5:
			_count("esc")
			_closing_press(w, "esc")
			_key("pause")
		6:
			_count("pad_b")
			_closing_press(w, "pad_b")
			_pad(JOY_BUTTON_B)
		7:
			_count("map_key")
			_key("map")
		_:
			# only a button a person can reach: the top menu's own (a modal's dim covers the ones under it)
			var top: Node = hud.root.get_child(hud.root.get_child_count() - 1)
			var res := _button(top, L.t("Resume")) if top.get_meta("modal", false) else null
			if res:
				_count("resume")
				res.pressed.emit()
			else:
				_count("back")
				_back(at)


## The last visible button with this text under `n` (the top modal's, when a menu is stacked).
static func _button(n: Node, text: String) -> Button:
	var found: Button = null
	for c in n.get_children():
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if c is Button and (c as Button).text == text and not (c as Button).disabled:
			found = c
		var deeper := _button(c, text)
		if deeper:
			found = deeper
	return found
