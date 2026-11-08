extends Node
## Trailer footage, staged by the game itself (run through scripts/autotest.gd):
##   -- --autotest --trailer=<scene>        one deterministic, real-gameplay moment per run
## Record a scene with Godot's movie writer (tools/make_trailer.sh records all of them):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##       --write-movie /abs/out/<scene>/f.png --fixed-fps 60 -- --autotest --trailer=<scene>
## The movie writer saves the game's own 384x216 picture as lossless PNGs plus the game's sound (f.wav);
## the edit scales the picture x5 with nearest-neighbour, so every pixel stays sharp. Each scene prints
## "[trailer] mark <name> <frame>" and writes <movie dir>/marks.json, so the edit cuts on the moments
## themselves rather than on guessed times. The Music bus is muted (the edit lays one of the game's own
## tracks under the whole cut); --trailermusic keeps the in-game music.
##
## Everything is the real game: real rooms, lodgers, relics, guardians, banners and sounds. The staging
## only picks the room, the cast and the moment, keeps Tallow's wax above a floor so a shot never ends
## the run, and walks Tallow to a pickup when the bot would not.

const SS := preload("res://scripts/store_shots.gd")
const SEED := 7
const SCENES := ["title", "cellar", "hook", "floors", "build", "chapel", "seance", "cards", "boss", "clutch",
	"ladder", "keeper", "dawn"]
## the fire build of the "build" scene, in pickup order (Short B counts them)
const BUILD := ["twin_wick", "ember_heart", "blue_flame", "bellows", "will_o_wisp", "hot_drip", "tinderbox"]

var at: Node
var w: Node
var marks := {}
var wax_lo := -1.0          # Tallow's wax never drops below this (a staged shot must not end the run)
var no_gutter := false      # Guttering may save Tallow again and again (the clutch)
var steer: Variant = null   # a Node2D or a point: Tallow walks there instead of where the bot would go
var _ending: Node = null


static func run(a: Node) -> void:
	var t: Node = load("res://scripts/trailer.gd").new()
	t.at = a
	a.add_child(t)
	a.set("trailer", t)
	await t.play()


func play() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene := str(at.args.get("trailer", ""))
	if not scene in SCENES:
		print("[trailer] unknown scene '%s'; scenes: %s" % [scene, ", ".join(SCENES)])
		return
	seed(SEED)
	Controls.set_device(Controls.MOUSE)   # the desktop HUD: no touch sticks over the room
	if not at.args.has("trailermusic"):
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	_mark("start")
	match scene:
		"title": await _title()
		"cellar": await _cellar()
		"hook": await _hook()
		"floors": await _floors()
		"build": await _build()
		"chapel": await _chapel()
		"seance": await _seance()
		"cards": await _cards()
		"boss": await _boss()
		"clutch": await _clutch()
		"ladder": await _ladder()
		"keeper": await _keeper()
		"dawn": await _dawn()
	_mark("end")
	_save_marks(scene)
	steer = null
	at.args.erase("drive")


# ---------------------------------------------------------------- helpers

func _mark(name: String) -> void:
	marks[name] = Engine.get_frames_drawn()
	print("[trailer] mark %s %d" % [name, marks[name]])


func _save_marks(scene: String) -> void:
	var movie := Engine.get_write_movie_path()
	if movie == "":
		return
	var f := FileAccess.open(movie.get_base_dir() + "/marks.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"scene": scene, "fps": Engine.physics_ticks_per_second, "marks": marks}, "  "))
		f.close()


func _physics_process(_dt: float) -> void:
	if _ending and is_instance_valid(_ending):
		var sk: Variant = _ending.get("_skip_lbl")
		if sk is CanvasItem:
			(sk as CanvasItem).visible = false   # "Any key to skip" is not part of the picture
	if w == null or not is_instance_valid(w) or w.get("player") == null:
		return
	var p: Player = w.player
	if no_gutter:
		p.gutter_used = false
	if wax_lo >= 0.0 and p.wax < wax_lo and not p.dead:
		p.wax = wax_lo


## autotest.drive() asks here first: [] = leave it to the bot (or to nobody when the bot is off).
func drive(wd: Node) -> Array:
	if steer == null:
		return []
	var p: Player = wd.player
	if p == null:
		return []
	var goal := Vector2.ZERO
	if steer is Vector2:
		goal = steer
	elif steer is Node2D and is_instance_valid(steer):
		goal = (steer as Node2D).global_position
	else:
		steer = null
		return []
	var aim := Vector2.ZERO
	var tgt: Enemy = wd.nearest_enemy(p.global_position)
	if tgt:
		aim = (tgt.global_position + Vector2(0, -tgt.half_h) - (p.global_position + Vector2(0, -6))).normalized()
	var to := goal - p.global_position
	return [to.normalized() if to.length() > 1.5 else Vector2.ZERO, aim]


## A run with the fixed seed, on floor n, with no banner or hint left on screen.
func _game(n := 1) -> void:
	at.main.goto("game", {"seed": SEED})
	w = await SS._until_game(at)
	await at._wait(0.4)
	if n != 1:
		w._start_floor(n)
		await at._wait(0.2)
	_quiet()


func _quiet() -> void:
	SS._settle_text(w, false)


## Only the hint line goes (the floor or relic banner stays and fades out on its own).
func _no_hint() -> void:
	var h: Node = w.hud
	if h._hint_tw:
		h._hint_tw.kill()
	h.hint.modulate.a = 0.0


## The k-th ordinary room of this floor that is not a mini-boss's (sorted: the same room every time).
func _plain(k: int) -> Vector2i:
	var cells: Array = []
	for c in w.layout["cells"].keys():
		var d: Dictionary = w.layout["cells"][c]
		if d["type"] == "normal" and not d.has("mini"):
			cells.append(c)
	cells.sort()
	return cells[k % cells.size()] if not cells.is_empty() else w.layout["start"]


## The room's own lodgers are swapped for our cast (the room stays uncleared, so it lights up when they fall).
func _dark_room(k: int, template: String) -> Vector2:
	var c := _plain(k)
	var d: Dictionary = w.layout["cells"][c]
	var g := SS._template(template)
	if not g.is_empty():
		d["grid"] = g
	d["cleared"] = false
	at._jump(w, c)
	await at._wait(0.4)   # the room spawns its own lodgers after 0.25 s
	SS._clear_foes(w)
	for o in w.room.objects.get_children():
		if o is Pickup:
			o.queue_free()
	return w.room.center()


func _spawn(c0: Vector2, cast: Array) -> void:
	for s in cast:
		w.spawn_enemy(s[0], c0 + s[1])
	w.room_spawned = true
	w.room_t0 = w.run_time


## Sets the candle without the bells of the hours it skipped (no "1:45 AM" banner over a staged shot).
func _set_wax(v: float) -> void:
	w.player.wax = v
	for mark in [60.0, 90.0, 105.0]:
		if w.clock_minutes() >= mark:
			w._bells[mark] = true


## A real contact hit from the nearest lodger (the bot dodges too well to be hit on cue).
func _hit() -> void:
	var p: Player = w.player
	var e: Enemy = w.nearest_enemy(p.global_position)
	var dir: Vector2 = (p.global_position - e.global_position) if e else Vector2.LEFT
	p.invuln = 0.0
	p.hurt(float(Enemy.TOUCH[clampi(w.floor_num, 1, 4) - 1]) * w.enemy_dmg_mult(), dir)


## Tallow runs after its own spilled wax (the warm drops) before they cool.
func _grab_spill(secs: float) -> void:
	await at._wait(0.3)
	var t := 0.0
	while t < secs:
		var best: Node2D = null
		var bd := 9999.0
		for o in w.room.objects.get_children():
			if o is Pickup and o.kind == "wax_warm" and not o.taken:
				var dd: float = (o as Node2D).global_position.distance_to(w.player.global_position)
				if dd < bd:
					bd = dd
					best = o
		if best == null:
			break
		steer = best
		await at._wait(0.05)
		t += 0.05
	steer = null


func _until(cond: Callable, most: float) -> void:
	var t := 0.0
	while t < most and not cond.call():
		await at._wait(0.05)
		t += 0.05


func _boss_alive() -> bool:
	return w.boss != null and is_instance_valid(w.boss) and w.boss.alive


func _drop_boss() -> void:
	if w.boss and is_instance_valid(w.boss):
		w.boss.queue_free()
	w.boss = null
	w.hud.set_boss("", false)
	SS._clear_foes(w)


## The boss room of floor n with a chosen guardian (no card: the clutch and the ladder start mid-fight).
func _boss_room(n: int, kind: String, card: bool) -> void:
	if w.floor_num != n:
		w._start_floor(n)
		await at._wait(0.2)
	_quiet()
	_drop_boss()
	if Enemy.DEFS.has(kind):
		w.boss_kind = kind
	if not card:
		at.args["nocard"] = true
	at._jump(w, w.layout["boss"])
	w.player.position = w.room.center() + Vector2(-60, 40)


# ---------------------------------------------------------------- scenes

## The game as it boots: dark, the match strikes, the wick catches, the logo flickers on, the menu.
func _title() -> void:
	marks["in"] = 0   # the boot intro started before this script ran (the strike is at ~0.4 s)
	var t: Node = at.main.current
	for k in ["stats", "ver", "menu", "box"]:   # the trailer shows the logo and Tallow, not the menu
		var l: Variant = t.get(k)
		if l is CanvasItem:
			(l as CanvasItem).visible = false
	SS._hide_continue(t)
	await at._wait(1.6)
	_mark("menu")
	await at._wait(1.6)
	_mark("out")


## 12:00 AM, a full candle in a lit Cellar room full of lodgers; two hits melt it, it grabs its wax back.
func _cellar() -> void:
	await _game(1)
	SS._kit(w)
	await SS._fight_room(at, w, 1, "fireplaces", [
		["goblin", Vector2(40, -24)], ["tiny_zombie", Vector2(62, 8)], ["cinder_rat", Vector2(24, 30)],
		["wax_blob", Vector2(70, -40)], ["imp", Vector2(-10, -50)], ["tiny_slug", Vector2(90, 30)],
		["muddy", Vector2(100, -10)]], [
		["wax_blob", Vector2(-10, -6)], ["goblin", Vector2(20, -34)], ["cinder_rat", Vector2(46, 14)], ["tiny_zombie", Vector2(-40, 30)]])
	var p: Player = w.player
	p.position = w.room.center() + Vector2(-64, 14)
	p.wax = p.wax_max
	_quiet()
	wax_lo = 70.0
	at.args["drive"] = true
	_mark("in")
	await at._wait(1.8)
	_mark("hit1")
	_hit()
	await _grab_spill(1.2)
	await at._wait(1.6)
	_mark("hit2")
	_hit()
	await _grab_spill(1.2)
	await at._wait(2.4)
	_mark("out")


## 1:57 AM in a dark Crypt room: the light is tiny, the heartbeat thumps; five quick kills light a
## Kindling streak, the room clears and its candelabras catch.
func _hook() -> void:
	await _game(2)
	SS._kit(w)
	var c0: Vector2 = await _dark_room(2, "open_five")
	_drop_boss()   # (in case the floor made this a mini-boss room)
	var p: Player = w.player
	p.position = c0 + Vector2(-58, 14)
	_set_wax(3.4)
	p.damage += 3.0   # one flame, one lodger: the streak needs quick kills
	wax_lo = 1.6
	_quiet()
	_spawn(c0, [["sootling", Vector2(-4, -34)], ["cinder_rat", Vector2(18, 26)], ["tiny_zombie", Vector2(34, -6)],
		["sootling", Vector2(58, 32)], ["imp", Vector2(66, -34)]])
	at.args["drive"] = true
	_mark("in")
	await _until(func(): return w.count_enemies() == 0, 8.0)
	_mark("cleared")
	await at._wait(2.6)
	_mark("out")


## One room of every floor, mid-fight, with the floor's own banner: Cellar, Crypt, Chapel, Belfry, Tower.
func _floors() -> void:
	await _game(1)
	SS._kit(w)
	wax_lo = 60.0
	at.args["drive"] = true
	for n in [1, 2, 3, 4, 5]:
		w._start_floor(n)
		await at._wait(0.1)
		var c := _plain(2)
		w.layout["cells"][c]["cleared"] = false
		at._jump(w, c)
		w.hud.set_boss("", false)
		_no_hint()
		w.player.position = w.room.center() + Vector2(-64, 16)
		w.player.wax = maxf(w.player.wax, 70.0)
		_mark("f%d" % n)
		await at._wait(0.3)
		_no_hint()
		await at._wait(2.3)
		SS._clear_foes(w)
	_mark("out")


## A fire build, one relic at a time (each held aloft with its banner), then a full room melts.
func _build() -> void:
	await _game(4)
	var c0: Vector2 = await _dark_room(1, "open_five")
	_drop_boss()
	var p: Player = w.player
	p.position = c0 + Vector2(-40, 10)
	p.wax = 100.0
	p.damage += 1.5   # a late-run candle (each guardian felled adds to the flame)
	wax_lo = 70.0
	_quiet()
	# relic 0: one weak flame against two lodgers
	_spawn(c0, [["sootling", Vector2(60, -20)], ["tiny_zombie", Vector2(70, 26)]])
	at.args["drive"] = true
	_mark("in")
	await at._wait(2.6)
	at.args.erase("drive")
	SS._clear_foes(w)
	w.room.data["cleared"] = true
	w.room.light_candles()
	p.position = c0 + Vector2(-40, 10)
	for o in w.room.objects.get_children():
		if o is Pickup:
			o.queue_free()
	await at._wait(0.4)
	var i := 0
	for id in BUILD:
		if not Items.RELICS.has(id):
			continue
		i += 1
		_mark("r%d" % i)
		w.collect_item(id, p.global_position)
		await at._wait(1.4)
	_quiet()
	# the full room: lodgers pour in from every side
	_mark("wave")
	w.room.data["cleared"] = false
	_spawn(c0, [["sootling", Vector2(70, -40)], ["tiny_zombie", Vector2(90, 0)], ["cinder_rat", Vector2(80, 40)],
		["wax_blob", Vector2(40, -50)], ["skelet", Vector2(100, -24)], ["goblin", Vector2(50, 50)],
		["sootling", Vector2(-90, -40)], ["tiny_slug", Vector2(-100, 30)], ["imp", Vector2(0, -56)],
		["chort", Vector2(110, 30)], ["wisp", Vector2(20, 52)], ["sootling", Vector2(-60, 48)]])
	at.args["drive"] = true
	await _until(func(): return w.count_enemies() == 0, 9.0)
	_mark("cleared")
	await at._wait(1.6)
	_mark("out")


## The Chapel: stained-glass light pools on the floor, a fight in them.
func _chapel() -> void:
	await _game(3)
	SS._kit(w)
	var cells: Array = []
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] == "normal":
			cells.append(c)
	cells.sort()
	var found := false
	for c in cells:
		w.layout["cells"][c]["cleared"] = true
		at._jump(w, c)
		SS._clear_foes(w)
		await at.get_tree().process_frame
		if SS._has_window(w.room):
			found = true
			break
	if not found:
		print("[trailer] no chapel room with windows on this floor")
	var c0: Vector2 = w.room.center()
	w.room.set_open(false, true)
	w.player.position = c0 + Vector2(-60, 24)
	w.player.wax = 92.0
	wax_lo = 60.0
	await SS._splats(at, w, [["wisp", Vector2(10, -20)], ["psalter", Vector2(-20, 30)]])
	await at._wait(0.6)
	_spawn(c0, [["skelet", Vector2(60, -30)], ["wisp", Vector2(80, 20)], ["chort", Vector2(40, 40)],
		["angel", Vector2(-10, -46)], ["wogol", Vector2(96, -10)]])
	_quiet()
	at.args["drive"] = true
	_mark("in")
	await at._wait(6.0)
	_mark("out")


## A Seance: Tallow rings the bell in the chalk ring and a wave of pale lodgers comes through the walls.
func _seance() -> void:
	await _game(2)
	SS._kit(w)
	var c: Vector2i = Specials._cell_of_type(w, "seance")
	if c == Vector2i(-99, -99):
		c = Specials._make_special(w, "seance")
	if c == Vector2i(-99, -99):
		print("[trailer] no room for a seance")
		return
	w.layout["cells"][c]["rung"] = false
	at._jump(w, c)
	SS._clear_foes(w)
	w.player.position = w.room.center() + Vector2(-30, 40)
	w.player.wax = 88.0
	wax_lo = 60.0
	await at._wait(0.6)
	_quiet()
	_mark("in")
	Specials.of(w)._ring()
	at.args["drive"] = true
	await at._wait(7.0)
	_mark("out")


## Four guardians' versus cards, one per floor.
func _cards() -> void:
	await _game(1)
	SS._kit(w)
	wax_lo = 60.0
	at.args["drive"] = true
	var kinds := {1: "big_zombie", 2: "sexton", 3: "choir", 4: "pendulum"}
	for n in [1, 2, 3, 4]:
		await _boss_room(n, kinds[n], true)
		_mark("card%d" % n)
		await at._wait(2.7)
	_drop_boss()
	_mark("out")


## The Hour Fiend: its card, the fight, then the clock hands sweeping the room while Tallow weaves.
func _boss() -> void:
	await _game(1)
	SS._kit(w)
	wax_lo = 50.0
	w.player.wax = 80.0
	await _boss_room(4, "big_demon", true)
	_mark("card")
	await at._wait(1.0)
	at.args["drive"] = true
	await at._wait(1.2)
	_mark("fight")
	await at._wait(2.4)
	var b: Enemy = w.boss
	if b and is_instance_valid(b):
		b.hp = b.max_hp * 0.6   # phase 2: the clock hands
		w.on_boss_hp(b)
		await at._wait(1.0)
		if is_instance_valid(b) and b.alive:
			b.state = "hands"
			b.t = 3.0
			b.set("_spin", 0.0)
			b.set("_wob", 0.1)
			b.set("_hand_base", (w.player.global_position - b.global_position).angle() + PI * 0.5)
	_mark("hands")
	await at._wait(4.0)
	_mark("out")


## 1:58 AM, the heartbeat, the Hour Fiend at half health: the last flames land, the bells answer.
func _clutch() -> void:
	await _game(1)
	SS._kit(w)
	for id in ["sharp_wick", "bellows", "spare_wick"]:
		if Items.RELICS.has(id):
			Items.apply(id, w.player, w)
	w.player.damage += 1.2
	await _boss_room(4, "big_demon", false)
	await at._wait(1.0)   # the guardian steps in
	var b: Enemy = w.boss
	if b and is_instance_valid(b):
		b.hp = b.max_hp * 0.5
		w.on_boss_hp(b)
	_set_wax(2.4)
	wax_lo = 1.3
	no_gutter = true
	_quiet()
	at.args["drive"] = true
	_mark("in")
	await _until(func(): return not _boss_alive(), 16.0)
	_mark("kill")
	await at._wait(3.2)
	_mark("out")


## The Belfry's guardian falls before 1 AM: a ladder of light, and Tallow climbs into the Clock Tower.
func _ladder() -> void:
	await _game(1)
	SS._kit(w)
	w.player.damage += 1.0
	await _boss_room(4, "big_demon", false)
	await at._wait(1.0)
	var b: Enemy = w.boss
	if b and is_instance_valid(b):
		b.hp = b.max_hp * 0.07
		w.on_boss_hp(b)
	w.player.wax = 74.0   # 12:46 AM
	wax_lo = 60.0
	_quiet()
	at.args["drive"] = true
	_mark("in")
	await _until(func(): return not _boss_alive(), 8.0)
	_mark("kill")
	var lad: Node2D = null
	var t := 0.0
	while t < 4.0 and lad == null:
		for o in w.room.objects.get_children():
			if o is Pickup and o.kind == "trapdoor":
				lad = o
		await at._wait(0.05)
		t += 0.05
	_mark("ladder")
	at.args.erase("drive")
	await at._wait(1.8)
	if lad:
		steer = lad
	await _until(func(): return int(w.floor_num) == Tower.FLOOR, 5.0)
	steer = null
	_mark("tower")
	await at._wait(3.0)
	_mark("out")


## The Keeper of Hours: its card, the fight, then time stops (the house goes grey, Tallow's shots hang).
func _keeper() -> void:
	await _game(1)
	Tower.test_start(w)
	await at._wait(0.4)
	_quiet()
	_drop_boss()
	at._jump(w, w.layout["boss"])
	w.player.position = w.room.center() + Vector2(0, 56)
	w.player.wax = 76.0
	wax_lo = 40.0
	_mark("card")
	await at._wait(1.2)
	at.args["drive"] = true
	await at._wait(3.0)
	_mark("fight")
	var k: Enemy = w.boss
	if k and is_instance_valid(k):
		k.hp = k.max_hp * 0.6
		w.on_boss_hp(k)
		await at._wait(2.0)
		if is_instance_valid(k) and k.alive:
			Keeper.ai().force(k, "stop")
	_mark("stop")
	await at._wait(5.0)
	_mark("out")


## The true ending's last cards: the clock stops, the flame settles, dawn comes for the little candle.
func _dawn() -> void:
	var e: Node = Ending.new()
	e.setup(72.0, "tallow", func(): pass)
	e.set("_card", 0)   # start at the stopped clock
	_ending = e
	at.get_tree().root.add_child(e)
	_mark("card1")
	await at._wait(Ending.CARD)
	_mark("card2")
	await at._wait(Ending.CARD)
	_mark("card3")
	await at._wait(Ending.CARD + 0.4)
	_mark("out")
