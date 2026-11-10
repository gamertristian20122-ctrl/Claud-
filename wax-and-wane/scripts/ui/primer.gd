class_name Primer
extends Control
## v2.7 onboarding (docs/streams/v27_onboarding.md): the controls primer. A save slot's first run starts with it, in
## the start room, before the first fight: five short steps, each SHOWN by an animation of the device in use
## (Controls.device, live: a thumb on the touch sticks, keycaps, a gamepad stick, the mouse; Swap sticks mirrors the
## thumbs) and finished by DOING it:
##   1 MOVE        walk a little
##   2 AIM + FIRE  three embers into the wax dummy (it pops)
##   3 WAX = TIME  the clock + wax gauge lights up; a staged hit melts 4 minutes and spills two warm drips: grab them
##   4 BOMB        drop one (a practice bomb: it comes back and its blast cannot hurt Tallow here)
##   5 the candle's special move (Flare Up for Tallow)
## Steps 4 and 5 also finish by themselves after a few seconds. Skip (top right; Enter, the pad's Back) ends it at once.
## While it runs the night has not begun: the clock stays at 12:00 AM (the wax is held), the doors stay shut and the
## run's play time does not count; at the end the clock strikes twelve and the doors open.
## It runs only on a slot's first run (Game.records "runs" 1) until done or skipped, never in Tonight's Candle, a
## typed-in seed, a floor past the first, or a test run (`--primer` forces it: the tour, the judge, the bot, which then
## plays it: bot_drive). What it taught is kept per slot (Game.records "primer", "primer_taught") and the hints that
## would say it again are spent (Game.tip), so nothing is told twice. Reduce motion: no glides, quicker hand-offs.
## It uses no seeded RNG and changes nothing in the house: a seed builds the same floor with or without it.
## Hooks: world._ready (Primer.maybe_start), autotest.drive (Primer.bot_drive). Pictures: tools/art_primer.py.

const STEPS := ["move", "aim", "wax", "bomb", "special"]
const WALK := 26.0             # px of walking that finishes MOVE
const SHOW_ONLY := 7.0         # s: BOMB and the special move finish by themselves after this
const HIT_MIN := 4.0           # minutes the staged hit melts (two drips give them back)
const DRIFT_AFTER := 6.0       # s: drips nobody walks to float over to Tallow
const START_DELAY := 0.6       # s of free play (no card, no pause) before the first step

var w: Node
var p: Player
var hud: Node
var step := -1                 # index in STEPS; -1 while it waits for the story card to close
var t := 0.0                   # this step's clock (play seconds)
var message := ""              # the step on screen, "MOVE: Walk a few steps." (the judge logs it)
var lessons: Array = []        # what the step teaches (the judge's tags)
var ended := false
var skipped := false

var _wait := START_DELAY
var _held := 0.0               # the candle's wax when it began: the clock stays there
var _cut := 0.0                # minutes shown off the gauge right now (the staged hit, a move's price)
var _elapsed := 0.0
var _done := {}
var _next_t := -1.0            # a finished step: seconds until the next
var _ok_t := 0.0               # the plate's "done" flash
var _walked := 0.0
var _last := Vector2.ZERO
var _dummy: WaxDummy
var _ember: AnimatedSprite2D
var _ember_dir := Vector2.RIGHT
var _hit_done := false
var _drops: Array = []         # {"s": Sprite2D, "t": seconds since it landed, "taken": bool}
var _bombs0 := -1
var _bombs_seen := 0
var _blasts: Array = []        # the step's clock when each practice bomb was dropped
var _move_id := ""
var _uses0 := 0
var _used_at := -1.0
var _ghosts := false
var _chalk: CanvasItem
var _chalk_a := 0.8
var _chalk_on := false
var _plate: PanelContainer
var _plate_lbl: Label
var _line: PanelContainer
var _line_lbl: Label
var _pips: Control
var _skip: Button
var _skip_key: Label


# ================================================================ when

## A save slot's first run, a real player, floor 1, not Tonight's Candle nor a typed-in seed, and the primer has not
## been done or skipped in this slot: it will run. Tests: only with --primer. (No room needed: _start_floor asks.)
static func would_run(world: Node) -> bool:
	if world == null or not is_instance_valid(world):
		return false
	var m: Node = world.get("main")
	var test: bool = m != null and m.get("autotest") != null
	if test and not (m.autotest.get("args") as Dictionary).has("primer"):
		return false
	if world.get("daily") == true or world.get_meta("seeded", false) == true or world.get("floor_num") != 1:
		return false   # (stand-in worlds of the room checks have none of these: no primer there either)
	if m == null:
		return false
	if test:
		return true
	var st := str(Game.records.get("primer", ""))
	return st != "done" and st != "skipped" and int(Game.records.get("runs", 0)) <= 1


## would_run, and the run stands in floor 1's start room with its candle and HUD: start it now.
static func should_run(world: Node) -> bool:
	if not would_run(world) or world.get("player") == null or world.get("hud") == null:
		return false
	var r: Node = world.get("room")
	return r != null and str(r.get("data").get("type", "")) == "start"


## The start room's one chalk reminder (WAX = TIME, chalk.gd) is for a player the primer did not teach it: it is
## drawn under a primer (which keeps it hidden, and shows it only if Skip came before the wax lesson) and stays for
## the rest of that run. Never otherwise: the story card (no primer) or the primer said it already.
static func chalk_wanted(world: Node) -> bool:
	if would_run(world):
		return true
	return str(Game.records.get("primer", "")) == "skipped" and not taught("wax") and int(Game.records.get("runs", 0)) <= 1


## world._ready: start it if this run should have it. Safe to call again (a story scene that ends may call it).
static func maybe_start(world: Node) -> Primer:
	if active(world) or not should_run(world):
		return null
	var pr := Primer.new()
	pr.w = world
	world.set_meta("primer", pr)
	world.hud.root.add_child(pr)
	return pr


static func of(world: Node) -> Primer:
	if world == null or not is_instance_valid(world) or not world.has_meta("primer"):
		return null
	var pr: Variant = world.get_meta("primer")
	return pr as Primer if pr != null and is_instance_valid(pr) else null


## True while a primer is on (the world's other teaching stays quiet meanwhile).
static func active(world: Node) -> bool:
	var pr := of(world)
	return pr != null and not pr.ended


## Did this slot's primer teach `step` (move, aim, wax, bomb, special)?
static func taught(step_id: String) -> bool:
	return step_id in (Game.records.get("primer_taught", []) as Array)


## The play-test bot plays the primer when a run has one (--primer): [move, aim], or [] when none is on.
static func bot_drive(world: Node) -> Array:
	var pr := of(world)
	if pr == null or pr.ended:
		return []
	return pr._bot()


# ================================================================ setup

func _ready() -> void:
	name = "Primer"
	p = w.player
	hud = w.hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 10   # after the world and the candle: the melt is undone here
	set_meta("fit_group", "primer")
	_held = p.wax
	w.room.set_open(false, true)   # the doors stay shut until it is over
	_ghosts = hud.ghost_sticks
	hud.ghost_sticks = false        # its own thumbs show where the sticks are
	_chalk = w.room.get_node_or_null("Chalk")
	if _chalk:
		_chalk_a = _chalk.modulate.a
		_chalk.modulate.a = 0.0      # the floor's reminder is chalked in when the lesson it names is done
	Game.records["primer"] = "started"
	_build()
	tree_exiting.connect(func():
		if is_instance_valid(w) and w.has_meta("primer") and w.get_meta("primer") == self:
			w.remove_meta("primer"))


func _build() -> void:
	_plate = UI.panel(Vector2.ZERO, "plate")
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_lbl = UI.engraved(UI.label("", 8, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_plate.add_child(_plate_lbl)
	add_child(_plate)
	_line = UI.panel(Vector2.ZERO, "strip")
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips = Control.new()
	_pips.custom_minimum_size = Vector2(STEPS.size() * 6 - 1, 9)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	row.add_child(_pips)
	_line_lbl = UI.label("", 8, UI.CREAM)
	_line_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_line_lbl)
	_line.add_child(row)
	add_child(_line)
	_skip = UI.button(L.t("Skip"), skip, 44)
	_skip.focus_mode = Control.FOCUS_NONE   # play has no menu focus: Enter / Back skip
	add_child(_skip)
	_skip_key = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_skip_key)
	_plate.visible = false
	_line.visible = false


# ================================================================ the steps

func _blocked() -> bool:
	if get_tree().paused or w.paused or w.transitioning or p.frozen or p.dead or w.main._busy:
		return true
	for c in hud.root.get_children():
		if c != self and c.get_meta("modal", false) and not c.is_queued_for_deletion():
			return true
	return false


func _physics_process(dt: float) -> void:
	if ended:
		return
	p.wax = _held - _cut   # the night has not begun: no melt; only the lesson's own minutes show
	w.calm_t = 0.0         # no pickup magnet in the lesson room
	if step < 0:
		if _blocked():
			_wait = START_DELAY
			return
		_elapsed += dt   # (the world counts these seconds as play: they come off again at the end)
		_wait -= dt
		if _wait <= 0.0:
			_go(0)
		return
	if not w.transitioning and not p.frozen:
		_elapsed += dt
	t += dt
	_ok_t = maxf(0.0, _ok_t - dt)
	_watch_bombs()
	if _next_t >= 0.0:
		_next_t -= dt
		if _next_t < 0.0:
			_go(step + 1)
		return
	match STEPS[step]:
		"move": _step_move()
		"aim": _step_aim()
		"wax": _step_wax(dt)
		"bomb": _step_bomb()
		"special": _step_special()


func _go(i: int) -> void:
	if i >= STEPS.size():
		_finish(false)
		return
	step = i
	t = 0.0
	_next_t = -1.0
	match STEPS[i]:
		"move":
			_walked = 0.0
			_last = p.global_position
		"aim":
			_spawn_dummy()
		"wax":
			_hit_done = false
			_cut = 0.0
		"bomb":
			_bombs0 = p.bombs
			p.bombs = maxi(p.bombs, 1)   # a practice bomb if the candle has none
			_bombs_seen = p.bombs
			_blasts = []
		"special":
			_move_id = Moves.for_candle(p.candle_id)
			if _move_id == "" or not Moves.enabled:
				_go(i + 1)
				return
			p.move_cd = 0.0
			_uses0 = int(Moves.uses.get(_move_id, 0))
			_used_at = -1.0
	_texts()
	_plate.visible = true
	_line.visible = true
	Audio.play("ui_move", -4.0)


## The step's words: the plate names it (by the picture), the ribbon says what to do.
func _texts() -> void:
	var id: String = STEPS[step]
	var tx := Primer.texts(id, _move_id)
	_plate_lbl.text = tx[0]
	_line_lbl.text = tx[1]
	message = "%s: %s" % tx
	lessons = {"move": ["move"], "aim": ["aim"], "wax": ["wax", "spill"], "bomb": ["bomb"], "special": ["special"]}[id]
	_plate.reset_size()
	_line.reset_size()


## A step's name (the plate) and what to do (the ribbon); the replay (PrimerReel) shows the same words.
static func texts(id: String, move_id := "") -> Array:
	match id:
		"move": return [L.t("MOVE"), L.t("Walk a few steps.")]
		"aim": return [L.t("AIM + FIRE"), L.t("Fire at the wax dummy.")]
		"wax": return [L.t("WAX = TIME"), L.t("A hit melts minutes. Grab the drips back.")]
		"bomb": return [L.t("BOMB"), L.t("Drop a bomb, then step back.")]
		"special": return [Moves.name_of(move_id).to_upper(), Moves.line_of(move_id)]
	return ["", ""]


## A step is done: a soft chime, the pip lights, and the next one comes after `delay` (shorter with Reduce motion).
func _complete(delay := 0.5) -> void:
	if _next_t >= 0.0:
		return
	_done[STEPS[step]] = true
	_ok_t = 0.35
	_next_t = delay * (0.5 if UI.calm() else 1.0)
	Audio.play("tick", -4.0, 0.0, 1.7)
	_pips.queue_redraw()


func _step_move() -> void:
	if p.move_input.length() > 0.2:
		_walked += p.global_position.distance_to(_last)
	_last = p.global_position
	if _walked >= WALK:
		_complete(0.4)


func _step_aim() -> void:
	if _dummy == null or not is_instance_valid(_dummy):
		_complete(0.3)
		return
	_dummy.catch()
	if _dummy.popped:
		_complete(0.9)


## Where the dummy stands: level with Tallow, 72 px to the side with more floor (the left with Swap... any side is fine),
## on open floor.
func _spawn_dummy() -> void:
	var r: Room = w.room
	var inner := r.inner_rect().grow(-14.0)
	var c := p.global_position
	var side := 1.0 if c.x < r.position.x + Room.W / 2.0 else -1.0
	var best := Vector2.INF
	for dx in [72.0, 60.0, 84.0, 48.0]:
		for s in [side, -side]:
			for dy in [0.0, -16.0, 16.0]:
				var q := Vector2(c.x + s * dx, clampf(c.y + dy, inner.position.y + 14.0, inner.end.y))
				if inner.has_point(q) and not r.blocked(q, 7.0) and best == Vector2.INF:
					best = q
	if best == Vector2.INF:
		best = r.center() + Vector2(68, 8)
	_dummy = WaxDummy.new()
	_dummy.world = w
	_dummy.calm = UI.calm()
	_dummy.material = Art.unshaded   # its painted ring glows on the floor (the figure itself is lit by the room)
	_dummy.global_position = best.round()
	w.actors.add_child(_dummy)
	_dummy.appear()


func _step_wax(dt: float) -> void:
	var calm := UI.calm()
	if not _hit_done:
		var flight := 0.0 if calm else 0.45
		var at := 0.5 if calm else 1.0
		if _ember == null and t >= at - flight:
			if calm:
				_staged_hit()
				return
			_spawn_ember()
		if _ember:
			var target := p.global_position + Vector2(0, -8)
			var to := target - _ember.global_position
			if to.length() < 5.0:
				_ember.queue_free()
				_ember = null
				_staged_hit()
			else:
				_ember.global_position += to.normalized() * minf(to.length(), 190.0 * dt)
		return
	var left := 0
	for d in _drops:
		if d["taken"]:
			continue
		left += 1
		var s: Sprite2D = d["s"]
		d["t"] = float(d["t"]) + dt
		if float(d["t"]) < 0.0:
			continue   # still in the air
		var gap := p.global_position.distance_to(s.global_position)
		if gap < 10.0:
			_take_drop(d)
			left -= 1
		elif float(d["t"]) > DRIFT_AFTER:
			s.global_position = s.global_position.move_toward(p.global_position, 45.0 * dt)
		s.modulate = Color("#facb3e") if (calm or fmod(float(d["t"]), 0.6) < 0.3) else Color("#ee8e2e")
	if left == 0:
		_complete(0.8)


## A wax bolt flies in from the nearer wall, level with Tallow.
func _spawn_ember() -> void:
	var r: Room = w.room
	var from_left := p.global_position.x > r.position.x + Room.W / 2.0
	var x := r.position.x + (Room.IN.x + 6.0 if from_left else Room.W - Room.IN.x - 6.0)
	_ember = AnimatedSprite2D.new()
	_ember.sprite_frames = Art.anim("fx/bolt_wax", 10.0)
	_ember.material = Art.unshaded
	_ember.z_index = 5
	_ember.global_position = Vector2(x, p.global_position.y - 8.0)
	_ember_dir = Vector2.RIGHT if from_left else Vector2.LEFT
	w.fx_layer.add_child(_ember)
	_ember.play("default")
	Audio.play("enemy_shoot", -6.0)


## The staged hit: the clock jumps four minutes (the gauge shows it, red trail and all), Tallow flinches the way a
## real blow makes him, and two warm drips spill out to be picked up again. Nothing real is hurt or rolled.
func _staged_hit() -> void:
	_hit_done = true
	_cut = HIT_MIN
	Audio.play("player_hurt")
	Game.vibrate(60)
	p._hurt_fx()
	p.set("_hit_dir", _ember_dir.normalized())
	p.set("_hit_t", Player.HIT_MARK)
	var hm: Variant = p.get("_hitmark")
	if hm is CanvasItem:
		(hm as CanvasItem).queue_redraw()   # the chevron on the side the blow came from
	hud.on_hurt()
	w.shake(3.0)
	w.fx_text(p.global_position + Vector2(0, -26), L.t("-{n} min", {"n": int(HIT_MIN)}), UI.RED)
	var r: Room = w.room
	var inner := r.inner_rect().grow(-12.0)
	var outs := [Vector2(-26, -8), Vector2(24, 10)] if _ember_dir.x > 0.0 else [Vector2(26, -8), Vector2(-24, 10)]
	for i in 2:
		var s := Sprite2D.new()
		s.texture = Art.tex("pickups/wax_small")
		s.offset = Vector2(0, -5)
		s.material = Art.unshaded   # warm: it glows until picked up
		s.modulate = Color("#ee8e2e")
		s.z_index = 4
		var from := p.global_position
		var to := from + (outs[i] as Vector2)
		to = Vector2(clampf(to.x, inner.position.x, inner.end.x), clampf(to.y, inner.position.y + 8.0, inner.end.y)).round()
		if r.blocked(to, 4.0):
			to = from + Vector2(0, 14 if i == 0 else -14)
		s.global_position = from
		w.fx_layer.add_child(s)
		var d := {"s": s, "t": -0.35, "taken": false}
		_drops.append(d)
		var tw := s.create_tween()
		tw.tween_property(s, "global_position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "offset:y", -13.0, 0.17).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(s, "offset:y", -5.0, 0.18).set_ease(Tween.EASE_IN)


func _take_drop(d: Dictionary) -> void:
	d["taken"] = true
	var s: Sprite2D = d["s"]
	_cut = maxf(0.0, _cut - HIT_MIN / 2.0)
	Audio.play("wax_pickup")
	w.fx_text(s.global_position + Vector2(0, -14), L.t("+{n} min", {"n": int(HIT_MIN / 2.0)}), UI.WAX)
	s.queue_free()


func _reveal_chalk() -> void:
	if _chalk_on or _chalk == null or not is_instance_valid(_chalk):
		return
	_chalk_on = true
	if UI.calm():
		_chalk.modulate.a = _chalk_a
		return
	var tw := _chalk.create_tween()
	tw.tween_property(_chalk, "modulate:a", _chalk_a, 0.6)


func _step_bomb() -> void:
	if not _blasts.is_empty() and t - float(_blasts[0]) >= 1.8:
		_complete(0.3)
	elif _blasts.is_empty() and t >= SHOW_ONLY:
		_complete(0.2)


## Practice bombs: each one dropped comes straight back, and the blast cannot hurt Tallow while it lasts.
func _watch_bombs() -> void:
	if step < 0 or STEPS[step] != "bomb":
		return
	if p.bombs < _bombs_seen:
		p.bombs = _bombs_seen
		_blasts.append(t)
	for b in _blasts:
		var since := t - float(b)
		if since > 1.15 and since < 1.75:
			p.invuln = maxf(p.invuln, 0.14)   # 0.07-0.16 s left: the body does not blink


func _step_special() -> void:
	var used := int(Moves.uses.get(_move_id, 0)) > _uses0
	if used and _used_at < 0.0:
		_used_at = t
		_cut += float(Moves.def(_move_id).get("cost", 0.0))   # Flare Up's price shows on the gauge
	if _used_at >= 0.0 and t - _used_at > 1.4:
		_complete(0.3)
	elif _used_at < 0.0 and t >= SHOW_ONLY:
		_complete(0.2)


# ================================================================ the end

## Skip: everything stops here, the doors open; it never asks twice in this slot.
func skip() -> void:
	if ended:
		return
	Audio.play("ui_back")
	_finish(true)


func _finish(skip_it: bool) -> void:
	if ended:
		return
	ended = true
	skipped = skip_it
	message = ""
	if _dummy and is_instance_valid(_dummy):
		_dummy.vanish()
	if _ember and is_instance_valid(_ember):
		_ember.queue_free()
	for d in _drops:
		if not d["taken"] and is_instance_valid(d["s"]):
			(d["s"] as Node).queue_free()
	_cut = 0.0
	p.wax = _held
	if _bombs0 >= 0:
		p.bombs = _bombs0
	p.move_cd = 0.0
	w.run_time = maxf(0.0, float(w.run_time) - _elapsed)   # the night starts now
	hud.ghost_sticks = _ghosts
	if skip_it and not _done.has("wax"):
		_reveal_chalk()   # skipped before the wax lesson: the floor keeps its one reminder, WAX = TIME
	elif _chalk and is_instance_valid(_chalk):
		_chalk.visible = false   # taught: the floor stays clean
	w.room.set_open(true)
	Audio.play("bell_toll", -3.0)   # the clock strikes twelve
	var taught_now: Array = _done.keys()
	Game.records["primer"] = "skipped" if skip_it else "done"
	Game.records["primer_taught"] = taught_now
	# the hints that would tell it again are spent (each hint shows once per slot: Game.tip)
	if "move" in taught_now or "aim" in taught_now:
		_spend("controls")
	if "wax" in taught_now:
		_spend("spill")
	if "special" in taught_now and _move_id != "":
		_spend("move_" + _move_id)
	if skip_it and not ("move" in taught_now and "aim" in taught_now) and Game.tip("controls", 1):
		hud.show_hint(Controls.controls_hint(), 7.0)   # skipped before the sticks: the one-line reminder, once
	if not (hud.get("_held_tips") as Array).is_empty():
		hud._flush_tips()   # a hint that came up during the lesson (a practice bomb opened a hollow...) shows now
	Game.save()
	_plate.visible = false
	_skip.visible = false
	_skip_key.visible = false
	if skip_it:
		queue_free()
		return
	_line_lbl.text = L.t("Ready.")
	_line.reset_size()
	_pips.queue_redraw()
	var tw := create_tween()
	tw.tween_interval(0.25 if UI.calm() else 0.9)
	tw.tween_property(self, "modulate:a", 0.0, 0.01 if UI.calm() else 0.3)
	tw.tween_callback(queue_free)


static func _spend(key: String) -> void:
	var tips: Dictionary = Game.records.get("tips", {})
	tips[key] = maxi(int(tips.get(key, 0)), 9)
	Game.records["tips"] = tips


# ================================================================ input, drawing

func _input(event: InputEvent) -> void:
	if ended or not _skip.visible:
		return
	var hit := false
	if event is InputEventScreenTouch and event.pressed and _skip_rect().has_point(event.position):
		hit = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION and _skip_rect().has_point(event.position):
		hit = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER):
		hit = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK:
		hit = true
	if hit:
		get_viewport().set_input_as_handled()
		skip()


func _skip_rect() -> Rect2:
	return Rect2(_skip.position, _skip.size).grow(4.0)


func _process(_dt: float) -> void:
	if ended and not _line.visible:
		return
	_layout()
	queue_redraw()
	if _chalk and is_instance_valid(_chalk) and not _chalk_on:
		_chalk.modulate.a = 0.0   # (a device change re-chalks the floor: keep it hidden until its lesson)


## The touch thumbs' spots (the HUD's ghost sticks): the move thumb's on the left, the aim thumb's on the right
## (Swap sticks trades them on a touch screen); keys and a pad keep left = move, right = aim.
func _spot(aim: bool) -> Vector2:
	var vs: Vector2 = hud.view_size()
	var right := aim
	if Controls.device == Controls.TOUCH and bool(Game.settings.get("swap_sticks", false)):
		right = not right
	return Vector2(vs.x - 64.0 if right else 64.0, vs.y - 52.0)


## The clock and the wax bar, one gauge.
func _gauge() -> Rect2:
	var a := Rect2((hud.clock_face as Control).position, (hud.clock_face as Control).size)
	return a.merge(Rect2((hud.bar as Control).position, (hud.bar as Control).size))


## How far the step's picture reaches above its spot (the plate sits on top of it).
func _top(dev: String, id: String) -> float:
	if id in ["bomb", "special"]:   # keys, mouse and pad (touch points at the HUD's own buttons)
		return PrimerGlyphs.key_h(_key_text(id), dev == Controls.PAD) / 2.0 + 1.0
	match dev:
		Controls.TOUCH: return 22.0
		Controls.PAD: return PrimerGlyphs.PAD_SIZE.y / 2.0 + PrimerGlyphs.PAD_REACH + 1.0
		Controls.MOUSE: return 11.0
	return 15.0


## The HUD button a step points at (the bomb's, the move's).
func _button(id: String) -> Control:
	return hud.bomb_btn if id == "bomb" else hud.move_btn


## The key or pad button bound to the step's action now (rebinds included): "E", "SHIFT", "RB", "LT".
func _key_text(id: String) -> String:
	return Controls.bound_glyph("bomb" if id == "bomb" else "special", Controls.device == Controls.PAD)


func _layout() -> void:
	var vs: Vector2 = hud.view_size()
	var mm: Control = hud.minimap
	var keep: Control = hud.keep_btn
	var sw := _skip.get_combined_minimum_size()
	_skip.size = sw
	var sx := mm.position.x + mm.size.x - sw.x
	if keep.visible:
		sx = minf(sx, keep.position.x - sw.x - 3.0)
	_skip.position = Vector2(floorf(sx), mm.position.y + mm.size.y + 3.0)
	var kt := ""
	match Controls.device:
		Controls.KEYS: kt = "ENTER"
		Controls.PAD: kt = "BACK"
	_skip_key.text = kt
	_skip_key.size = Vector2(sw.x, 10)
	_skip_key.position = _skip.position + Vector2(0, sw.y)
	var ls := _line.get_combined_minimum_size()
	_line.size = ls
	_line.position = Vector2(floorf((vs.x - ls.x) / 2.0), vs.y - ls.y - 2.0)
	if step < 0 or ended:
		return
	var ps := _plate.get_combined_minimum_size()
	_plate.size = ps
	var dev := Controls.device
	var id: String = STEPS[step]
	var at := Vector2.ZERO
	if id == "wax":
		var g := _gauge()
		at = Vector2(g.end.x + 8.0, g.position.y + 1.0)
	elif id in ["bomb", "special"] and dev == Controls.TOUCH:
		# beside the HUD button the thumb taps, on the screen's inner side
		var b := _button(id)
		var c := b.position + b.size / 2.0
		var reach := b.size.x / 2.0 + 8.0
		at = Vector2(c.x - reach - ps.x if c.x > vs.x / 2.0 else c.x + reach, c.y - ps.y / 2.0)
	else:
		# over the picture at a thumb's spot: move on the left, aim (and the keys / pad buttons) on the right
		var c := _spot(id != "move")
		at = Vector2(c.x - ps.x / 2.0, c.y - _top(dev, id) - 5.0 - ps.y)
	_plate.position = at.floor()


func _draw() -> void:
	if ended or step < 0:
		return
	var calm := UI.calm()
	var dev := Controls.device
	var id: String = STEPS[step]
	match id:
		"move":
			PrimerGlyphs.move(self, dev, _spot(false), t, calm)
		"aim":
			if _dummy and is_instance_valid(_dummy) and not _dummy.popped:
				var dir := (_dummy.target() - (p.global_position + Vector2(0, -6))).normalized()
				PrimerGlyphs.aim(self, dev, _spot(true), dir, t, calm)
		"wax":
			PrimerGlyphs.frame(self, _gauge(), t, calm)
		"bomb", "special":
			var b := _button(id)
			var c := b.position + b.size / 2.0
			var r := int(b.size.x / 2.0) + 3
			if dev == Controls.TOUCH:
				PrimerGlyphs.tap(self, c, r, t, calm)
			else:
				# keys / mouse / pad: the key (or the pad's lit bumper / trigger) at the aim thumb's spot; the move's
				# own HUD button (its icon and cooldown) gets a ring too
				PrimerGlyphs.press(self, dev, _spot(true), _key_text(id), t, calm)
				if id == "special" and b.visible:
					PrimerGlyphs.ring(self, c, r, t, calm)
	if _ok_t > 0.0:
		var pr := Rect2(_plate.position, _plate.size)
		PrimerGlyphs.frame(self, pr.grow(-2.0), 0.0, true)


## One pip per step: done gold, this one cream, ahead dark (the HUD's floor pips).
func _draw_pips() -> void:
	for i in STEPS.size():
		var x := float(i * 6)
		var col := Color("#483b3a")
		if _done.has(STEPS[i]) or (ended and not skipped):
			col = UI.GOLD
		elif i == step:
			col = UI.CREAM
		_pips.draw_rect(Rect2(x, 2, 5, 5), UI.INK)
		_pips.draw_rect(Rect2(x + 1, 3, 3, 3), col)


# ================================================================ the bot

func _bot() -> Array:
	if step < 0 or _next_t >= 0.0:
		return [Vector2.ZERO, Vector2.ZERO]
	var me := p.global_position
	match STEPS[step]:
		"move":
			return [Vector2.RIGHT if fmod(t, 2.0) < 1.0 else Vector2.LEFT, Vector2.ZERO]
		"aim":
			if _dummy and is_instance_valid(_dummy) and not _dummy.popped:
				return [Vector2.ZERO, (_dummy.target() - (me + Vector2(0, -6))).normalized()]
		"wax":
			for d in _drops:
				if not d["taken"] and float(d["t"]) >= 0.0:
					return [((d["s"] as Node2D).global_position - me).normalized(), Vector2.ZERO]
		"bomb":
			if _blasts.is_empty() and t > 0.6:
				w.place_bomb()
			if not _blasts.is_empty():
				return [Vector2.LEFT if me.x > w.room.center().x else Vector2.RIGHT, Vector2.ZERO]
		"special":
			if _used_at < 0.0 and t > 0.6:
				p.use_move()
	return [Vector2.ZERO, Vector2.ZERO]
