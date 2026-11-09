class_name Tower
extends Node
## THE CLOCK TOWER: the secret floor above the bells and the true ending.
## Snuff the Belfry's guardian with at least half the night left (1:00 AM on a 4-floor night, 1:45 AM on a
## 7-floor one, 2:30 AM on a 10-floor one: unlock_clock) and, instead of the normal victory, a ladder of light
## climbs past the bells to the floor above the night's last (floor_of: floor 5 of a 4-floor night): a short
## floor (6-8 rooms, one treasure room, no shop, the Keeper of Hours at the end). The wax keeps burning up there
## and the end of the night (two o'clock on a 4-floor night) still ends the run.
## Beat the Keeper for the true ending (scripts/ui/ending.gd), Moonwick and the tower achievements.
##
## Hooks (one line each): world._start_floor -> on_floor_start, world._build_room -> on_build,
## world._boss_down -> on_last_boss_down, world.save_extra/load_extra -> "tower", FloorGen.generate ->
## layout, RoomDecor.setup -> dress, results.gd -> on_results, autotest -> test_start / tour.

## The Clock Tower's entry in the 4-floor tables (its layout, FLOOR_LIKES[5], Enemy.FLOOR_HP[4] ...). It is the
## floor above the night's last floor: floor 5 of a 4-floor night, floor 8 of a 7-floor one (floor_of).
const FLOOR := 5
## On a 4-floor night the Belfry's guardian must fall at or before this clock minute (1:00 AM, as the clock
## shows it) for the ladder to appear, and only once the player has won a night before (ladder_open). Any night:
## half the night (unlock_clock).
const UNLOCK_CLOCK := 60.0
const HINT := "Something ticks above the belfry... next night, be done by one."
const MOON := Color(0.55, 0.68, 1.0)
## Minutes the ladder of light gives back on arrival (the tower is long and the wax keeps burning).
## 12 made the tower the easiest floor of the night (C2): now a small gift, the climb has to be earned.
const ARRIVAL_WAX := 5.0
## A sensible kit for a run that starts on floor 5 (--tower): what a good run carries by then.
const TEST_KIT := ["sharp_wick", "bellows", "lamp_oil", "beeswax", "split_wick", "thimble", "wax_coat", "hourglass"]

var world: Node
var belfry_clock := -1.0       # when the Belfry's guardian fell (run state, saved)
var counted := false           # that Belfry win is already in the records
var keeper_clock := -1.0
static var last_belfry := -1.0 # for the results screen of a run that died in the tower


static func of(w: Node) -> Tower:
	var t = w.get_meta("tower") if w.has_meta("tower") else null
	if t != null and is_instance_valid(t):
		return t
	var nt := Tower.new()
	nt.world = w
	nt.name = "Tower"
	w.set_meta("tower", nt)
	w.add_child(nt)
	return nt


# ---------------------------------------------------------------- the floor

## FloorGen hook: 7-9 cells (6-8 rooms + the Keeper's), one treasure room, no shop, no hollow,
## no special rooms. Uses the floor's own seeded RNG, so a seed always builds the same tower.
static func layout(rng: RandomNumberGenerator) -> Dictionary:
	var target := rng.randi_range(7, 9)
	for attempt in 200:
		var res := FloorGen._try(FLOOR, target, rng, 1)
		if not res.is_empty():
			_shopless(res, rng)
			return res
	var fb := FloorGen._try(FLOOR, 5, rng, 1)
	_shopless(fb, rng)
	return fb


static func _shopless(res: Dictionary, rng: RandomNumberGenerator) -> void:
	if res.is_empty():
		return
	for c in res["cells"].keys():
		var d: Dictionary = res["cells"][c]
		if d["type"] == "shop":
			d["type"] = "normal"
			d["cleared"] = false
			d["grid"] = RoomTemplates.to_grid(RoomTemplates.pick_normal(rng, FLOOR, int(d["dist"])))


## The tower's floor number tonight: the one above the night's last floor (5 on a 4-floor night).
static func floor_of(w: Node) -> int:
	return int(w.night_floors) + 1 if w.get("night_floors") != null else FLOOR


## The latest clock minute the Belfry may fall at for the ladder: half the night (UNLOCK_CLOCK = 1:00 AM on a
## 4-floor night, 1:45 AM on a 7-floor one, 2:30 AM on a 10-floor one).
static func unlock_clock(w: Node) -> float:
	return float(w.night_minutes()) / 2.0 if w.has_method("night_minutes") else UNLOCK_CLOCK


## The results' hint after a win while the tower is still a secret ("... next night, be done by one.").
static func hint_for(floors: int) -> String:
	if floors <= 4:
		return HINT
	return "Something ticks above the belfry... next night, be done by %s." % Records.hour_words(Game.night_minutes(floors) / 2.0)


## "Two o'clock" / "Half past three": the end of the night, for the tower's own lines.
static func end_words(w: Node) -> String:
	var end: float = float(w.night_minutes()) if w.has_method("night_minutes") else Game.END_MINUTES
	return Records.hour_words(end, true) + (" o'clock" if roundi(end) % 60 == 0 else "")


## world._start_floor hook (after the floor banner).
static func on_floor_start(w: Node) -> void:
	if int(w.floor_num) != floor_of(w):
		return
	# the ladder's light runs down the wick: a reward for being done by one (saved in the floor snapshot)
	w.player.heal(ARRIVAL_WAX)
	w.hud.show_banner("THE CLOCK TOWER", "Above the bells   -   %s" % Game.clock_text(w.clock_minutes()), 3.0)
	w.hud.show_hint("The ladder's light ran down your wick: +%d min. %s still comes." % [int(ARRIVAL_WAX), end_words(w)], 5.0)
	Game.records["tower_seen"] = true
	Game.save()
	Achievements.unlock("tower")


## world._build_room hook: the ladder of light, the Keeper's floor dial, the ladder's top in the first room.
static func on_build(w: Node, r: Room) -> void:
	for o in r.objects.get_children():
		if o is Pickup and o.record and o.record.get("ladder", false):
			_dress_ladder(o)
	if int(w.floor_num) != floor_of(w):
		return
	if r.data["type"] == "boss" and Art.has("tower/room_keeper"):
		for ch in r.get_children():
			if ch is Sprite2D and ch.z_index == -20:
				ch.texture = Art.tex("tower/room_keeper")
				break
	elif r.data["type"] == "start":
		# the ladder you came up by, already fading
		var lad := _ladder_sprite()
		lad.position = Vector2(136, 70)
		lad.modulate = Color(0.75, 0.8, 1.0, 0.55)
		r.add_child(lad)
		lad.z_index = -13


static func _ladder_sprite() -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("tower/ladder", 7.0)
	a.centered = false
	a.offset = Vector2(-9, -72)
	a.material = Art.unshaded
	a.play("default")
	return a


static func _dress_ladder(p: Pickup) -> void:
	if p.get_meta("ladder_dressed", false):
		return
	p.set_meta("ladder_dressed", true)
	if p.spr:
		p.spr.visible = false
	var a := _ladder_sprite()
	a.position = Vector2(0, 3)
	p.add_child(a)
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(1.0, 0.92, 0.7)
	l.energy = 1.1
	l.texture_scale = 0.75
	l.position = Vector2(0, -24)
	p.add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "energy", 0.85, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "energy", 1.15, 0.9).set_trans(Tween.TRANS_SINE)
	var motes := CPUParticles2D.new()
	motes.amount = 10
	motes.lifetime = 1.6
	motes.position = Vector2(0, -4)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(9, 2)
	motes.direction = Vector2(0, -1)
	motes.spread = 8.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 18.0
	motes.initial_velocity_max = 34.0
	motes.color = Color("#ffcc68")
	motes.material = Art.unshaded
	p.add_child(motes)


## RoomDecor hook (floor 5 rooms): slatted windows with moonlight falling through them and big wall
## gears turning. Returns how many static lights it used.
static func dress(d: RoomDecor, free_top: Array, budget: int) -> int:
	var used := 0
	var r: Room = d.room
	if budget >= 4:
		var a: int = [2, 3, 4][d.rng.randi() % 3]
		for t in [a, 14 - a]:
			var pos := Vector2(16 + 16 * t, 16)
			d._add(Art.tex("tower/window_slats"), pos)
			var g := Sprite2D.new()
			g.texture = Art.tex("tower/window_slats_glow")
			g.centered = false
			g.position = pos
			g.material = Art.unshaded
			g.z_index = -18
			r.add_child(g)
			var pool := Art.tex("tower/light/moon_slats") if Art.has("tower/light/moon_slats") else null
			var l := d._light(pos + Vector2(18, 50), MOON, 1.1, 0.85, 0.03, pool)
			if pool == null:
				l.texture_scale = 0.35
			free_top.erase(t)
			used += 1
	# one or two great wheels set into the wall, turning slowly
	var n := 2 if r.data["type"] == "boss" else (1 if d.rng.randf() < 0.7 else 0)
	var spots: Array = []
	for t in [1, 2, 3, 4, 9, 10, 11, 12]:
		if t in free_top and (t + 1) in free_top:
			spots.append(t)
	FloorGen.shuffle(spots, d.rng)
	var placed: Array = []
	for t in spots:
		if placed.size() >= n:
			break
		var clash := false
		for q in placed:
			if absi(q - t) < 3:
				clash = true
		if clash:
			continue
		placed.append(t)
		var gear := AnimatedSprite2D.new()
		gear.sprite_frames = Art.anim("tower/gear", 5.0)
		gear.centered = false
		gear.position = Vector2(16 + 16 * t - 1, 0)
		gear.flip_h = t > 7
		gear.z_index = -11
		gear.play("default")
		gear.frame = d.rng.randi() % 6
		r.add_child(gear)
		free_top.erase(t)
		free_top.erase(t + 1)
	return used


# ---------------------------------------------------------------- the ladder and the true ending

## world._boss_down hook, last floor(s): true when the tower handles it (ladder or true ending).
static func on_last_boss_down(w: Node) -> bool:
	if int(w.floor_num) == floor_of(w):
		of(w).true_end()
		return true
	if int(w.floor_num) == floor_of(w) - 1 and ladder_open(w):
		of(w).open_ladder()
		return true
	return false


## The ladder rises for a Belfry win done with half the night left as the clock shows it (1:00 AM on a
## 4-floor night; "1:00 AM" counts: QA-14), and only for a player who has already won a night: the first win
## always ends with the normal victory, so the credits never roll on a first night (C2).
static func ladder_open(w: Node) -> bool:
	return int(Game.records.get("wins", 0)) >= 1 and Game.shown_minute(w.clock_minutes()) <= int(unlock_clock(w))


## The Belfry fell before one: the bells are not done with you.
func open_ladder() -> void:
	var w := world
	belfry_clock = w.clock_minutes()
	last_belfry = belfry_clock
	if w.main and w.main.autotest:   # the play-test log: when the Belfry fell (the balance judge reads it)
		print("[tower] ladder of light at %s (wax %.1f)" % [Game.clock_text(belfry_clock), float(w.player.wax)])
	_count_belfry_win()
	w.player.frozen = false
	w._clear_room()
	var c: Vector2 = w.room.center()
	w.add_pickup("relic", c + Vector2(-40, -6), w._next_relic())
	w.add_pickup("wax_big", c + Vector2(40, -2))
	for i in 4:
		w.add_pickup("coin", c + Vector2(0, 30), "", 0, Vector2.from_angle(w.rng.randf() * TAU) * 50.0)
	var p: Pickup = w.add_pickup("trapdoor", w.free_spot_near(c + Vector2(0, 14), 8.0))
	p.record["ladder"] = true
	_dress_ladder(p)
	w.player.damage += 0.15
	Audio.music(w.FLOORS[FLOOR]["music"], 2.0)
	Audio.play("bell_toll", 0.0, 0.0, 0.8)
	Audio.play("unlock", -2.0)
	w.shake(3.0)
	w.fx_ring(p.global_position + Vector2(0, -30), Color("#ffcc68"))
	w.hud.show_banner("A LADDER OF LIGHT", "The bells are not done with you", 3.2)
	w.hud.show_hint("Done by %s. Climb, if your wick can take it." % Game.clock_text(belfry_clock), 5.0)
	Game.records["tower_seen"] = true
	Game.save()


## world.descend hook: the ladder of light is climbed, not fallen down (true = handled here).
static func on_descend(w: Node) -> bool:
	if int(w.floor_num) != floor_of(w) - 1 or of(w).belfry_clock < 0.0 or w.room == null or w.room.data["type"] != "boss":
		return false
	if w.altar_floor == w.floor_num and w.pact != "smoke":
		w.declined_smoke = true
	w.transitioning = true
	w.player.frozen = true
	Audio.play("unlock", -2.0)
	Audio.play("bell_small", -4.0, 0.0, 1.3)
	Juice.of(w).descended()
	var fade: ColorRect = w._fade
	fade.color = Color(0.79, 0.9, 0.96, 0.0)     # the moonlight at the top of the ladder
	var tw: Tween = w.create_tween()
	tw.tween_property(w.player, "position:y", w.player.position.y - 30.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(w.player, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		w.player.modulate.a = 1.0
		w._start_floor(floor_of(w))
		w.player.frozen = false
		w.transitioning = false)
	tw.tween_property(fade, "color:a", 0.0, 0.9)
	tw.tween_callback(func(): fade.color = Color(0.035, 0.027, 0.035, 0.0))
	return true


## The Belfry win counts as a win (records, the Black Taper, the win achievements) even if the tower
## then snuffs you out. The true ending's own _end_run(true) takes that one back so it is never doubled.
func _count_belfry_win() -> void:
	if counted:
		return
	counted = true
	var w := world
	var t: float = w.clock_minutes()
	Game.unlock("black_taper")
	Game.records["wins"] = int(Game.records["wins"]) + 1
	Records.note_finish(str(w.candle_id), int(w.night_floors), t)   # kept per night length
	Game.save()
	Achievements.on_win(w, t)   # Before Two, Early to Bed, The Small Hours ... (true to their words on any night)
	if w.candle_id != "tallow":
		Achievements.unlock("win_" + str(w.candle_id))
	if w.daily:
		Achievements.unlock("tonight_win")
	if (w.player.relics as Array).size() <= 4:
		Achievements.unlock("win_plain")


## The Keeper is stilled: the house goes quiet, then the ending cards and the credits, then results.
func true_end() -> void:
	var w := world
	if w.finished:
		return
	w.finished = true
	keeper_clock = w.clock_minutes()
	if w.main and w.main.autotest and w.boss and is_instance_valid(w.boss):
		print("[keeper] stilled after %.0f s at %s (hand hits %d)" % [w.boss.mem.get("fight_t", 0.0), Game.clock_text(keeper_clock), w.boss.mem.get("hand_hits", 0)])
	w.player.frozen = true
	w.hud.release_sticks()
	w._clear_shots()
	Audio.music("ending", 1.5)
	Audio.play("bell_toll", 0.0, 0.0, 0.7)
	w.hud.show_banner(Enemy.DEFS["keeper"]["victory"], "Done by %s" % Game.clock_text(keeper_clock), 3.0)
	Game.unlock("moonwick")
	Achievements.unlock("keeper")
	Achievements.unlock("keeper_" + str(w.candle_id))
	if keeper_clock < 90.0:
		Achievements.unlock("true_early")
	Game.records["true_endings"] = int(Game.records.get("true_endings", 0)) + 1
	Records.note_true_end(int(w.night_floors), keeper_clock)   # true_best per night length
	Game.save()
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_callback(func():
		var e := Ending.new()
		e.ending = Diary.keeper_ending(w)   # every diary page found: The Whole Story, else the true ending
		e.setup(keeper_clock, str(w.candle_id), _ending_done)
		w.add_child(e))


func _ending_done() -> void:
	var w := world
	if counted:   # the Belfry already counted this run's win
		Game.records["wins"] = maxi(0, int(Game.records["wins"]) - 1)
	w._end_run(true)


# ---------------------------------------------------------------- results screen

## results.gd hook: the tower's floor name and room, "TRUE ENDING", the hint after a first win.
static func on_results(res: Control, v: Container, params: Dictionary) -> void:
	var f := int(params.get("floor", 1))
	var won: bool = params.get("won", false)
	var labels: Array = []
	_labels(v, labels)
	var top := int(params.get("floors", 4)) + 1   # the tower: the floor above the night's last
	if f == top:
		for ch in res.get_children():
			if ch is TextureRect and ch.texture and str(ch.texture.resource_path).contains("rooms/room_"):
				ch.texture = Art.tex("rooms/room_tower")
				break
		for l in labels:
			l.text = l.text.replace("The Belfry", "The Clock Tower")
	if won and f == top:
		for l in labels:
			if l.text.begins_with("DONE BY"):
				var at := v.get_children().find(l)
				l.text = "TRUE ENDING"
				var done := UI.label("Done by %s. The clock has stopped." % Game.clock_text(float(params.get("clock", 0.0))), 8, Color("#cae6f5"), HORIZONTAL_ALIGNMENT_CENTER)
				v.add_child(done)
				v.move_child(done, at + 1)
			elif l.text.begins_with("The house is quiet"):
				l.text = "The bells are done with you. Sleep well."
	elif not won and f == top:
		for l in labels:
			if l.text.begins_with("Your flame went out") or l.text.begins_with("The clock struck"):
				l.text += "  The Keeper kept you."
	elif won and not Game.records.get("tower_seen", false):
		for l in labels:
			if l.text.begins_with("The house is quiet"):
				var hint := UI.label(hint_for(int(params.get("floors", 4))), 8, Color("#b6cbcf"), HORIZONTAL_ALIGNMENT_CENTER)
				v.add_child(hint)
				v.move_child(hint, v.get_children().find(l) + 1)
				break


static func _labels(n: Node, out: Array) -> void:
	for ch in n.get_children():
		if ch is Label:
			out.append(ch)
		elif ch is Container:
			_labels(ch, out)


# ---------------------------------------------------------------- save & continue

func to_dict() -> Dictionary:
	return {"belfry": belfry_clock, "counted": counted}


func from_dict(d: Dictionary) -> void:
	belfry_clock = float(d.get("belfry", -1.0))
	counted = bool(d.get("counted", false))
	last_belfry = belfry_clock


# ---------------------------------------------------------------- tests

## --tower: start this run on floor 5 at 12:48 AM with a kit like a good run's.
static func test_start(w: Node) -> void:
	if w == null or w.get("player") == null:
		return
	for id in TEST_KIT:
		if Items.RELICS.has(id) and not id in w.player.relics:
			Items.apply(id, w.player, w)
	w.player.damage += 0.6     # four guardians' "your flame grows"
	w.player.wax = 72.0
	w.player.bombs = 3
	w.player.coins = 12
	of(w).belfry_clock = 48.0
	w._start_floor(floor_of(w))
	print("[tower] test start: floor %d, %s, relics %s" % [w.floor_num, Game.clock_text(w.clock_minutes()), w.player.relics])
	if "--keeper" in OS.get_cmdline_user_args():   # --tower --keeper: straight to the Keeper (boss balance)
		var wax := 60.0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--keeperwax="):
				wax = float(a.split("=")[1])
		w.get_tree().create_timer(1.0).timeout.connect(func():
			if not is_instance_valid(w) or w.finished:
				return
			var c: Vector2i = w.layout["boss"]
			w.cur_cell = c
			w.room.dispose()
			w.room = w._build_room(c)
			w.player.position = w.room.center() + Vector2(0, 56)
			w.player.wax = wax
			w.cam.position = w._cam_target(w.room)
			w._on_enter_room())


## --tour --tower: the ladder, the tower's rooms, the Keeper's three phases and the ending cards.
static func tour(at: Node) -> void:
	var main: Node = at.main
	main.goto("game", {"seed": 23})
	await at._wait(1.6)
	var w: Node = main.current
	# the ladder of light in the Belfry's guardian room
	w._start_floor(4)
	await at._wait(2.9)
	var bc: Vector2i = w.layout["boss"]
	w.layout["cells"][bc]["cleared"] = true
	at._jump(w, bc)
	w.player.wax = 80.0
	of(w).open_ladder()
	w.player.position = w.room.center() + Vector2(-30, 40)
	await at._wait(1.4)
	await at._shot("tower_ladder")
	# the tower: the first room, a few dressed rooms
	test_start(w)
	await at._wait(1.2)
	await at._shot("tower_start")
	await at._wait(2.2)
	var n := 0
	for c in at._normal_cells(w):
		if n >= 3:
			break
		w.layout["cells"][c]["cleared"] = n != 1
		at._jump(w, c)
		w.player.position = w.free_spot_near(w.room.center() + Vector2(0, 30), 6.0)
		w.player.wax = 80.0
		await at._wait(1.6 if n != 1 else 2.4)
		await at._shot("tower_room_%d" % n)
		n += 1
	for e in w.enemies:
		if is_instance_valid(e) and e.alive:
			e.queue_free()
	w.enemies.clear()
	# the Keeper
	at._jump(w, bc if w.layout["cells"].has(bc) and w.layout["cells"][bc]["type"] == "boss" else w.layout["boss"])
	await at._wait(0.7)
	await at._shot("keeper_card")
	await at._wait(2.6)
	w.player.wax = 100.0
	w.player.position = w.room.center() + Vector2(-70, 44)
	await at._wait(3.2)
	await at._shot("keeper_phase1")
	await at._wait(1.6)
	await at._shot("keeper_phase1_b")
	var k: Enemy = w.boss
	if k and is_instance_valid(k):
		k.hp = k.max_hp * 0.6
		w.on_boss_hp(k)
		w.player.wax = 100.0
		await at._wait(3.0)
		Keeper.ai().force(k, "stop")
		await at._wait(1.3)
		await at._shot("keeper_stop")
		await at._wait(1.0)
		await at._shot("keeper_stop_count")
		await at._wait(1.0)
		await at._shot("keeper_resume")
		k.hp = k.max_hp * 0.25
		w.on_boss_hp(k)
		for i in 40:   # each phase lasts at least Keeper.MIN_PHASE seconds
			if k.phase >= 3:
				break
			w.player.wax = 100.0
			await at._wait(0.5)
		await at._wait(3.5)
		await at._shot("keeper_phase3")
		w.player.wax = 100.0
		await at._wait(2.5)
		await at._shot("keeper_phase3_b")
		k.hp = 0.0
		k._die()
	await at._wait(2.0)
	await at._shot("keeper_down")
	# the ending starts ~4.4 s after the killing blow; each card lasts Ending.CARD seconds
	await at._wait(5.2)
	for i in 4:
		await at._shot("ending_card_%d" % (i + 1))
		if i == 3:   # the dawn, and the little flame going out
			await at._wait(3.0)
			await at._shot("ending_dawn")
			await at._wait(Ending.CARD - 3.0)
		else:
			await at._wait(Ending.CARD)
	await at._wait(3.0)
	await at._shot("ending_credits")
	await at._wait(10.0)
	await at._shot("ending_credits_b")
	for i in 80:
		if main.current and main.current.name == "Results" and not main._busy:
			break
		await at._wait(0.5)
	await at._wait(0.6)
	await at._shot("results_true_ending")
	# a run that died in the tower, and the hint a first win leaves on the results screen
	main.goto("results", {"won": false, "floor": FLOOR, "clock": 101.0, "kills": 120, "rooms": 30, "relics": ["sharp_wick"], "time": 1900.0})
	await at._wait(1.4)
	await at._shot("results_tower_death")
	var seen: bool = Game.records.get("tower_seen", false)
	Game.records["tower_seen"] = false
	main.goto("results", {"won": true, "floor": 4, "clock": 74.0, "kills": 150, "rooms": 36, "relics": ["sharp_wick", "bellows"], "time": 2400.0})
	await at._wait(1.4)
	await at._shot("results_tower_hint")
	Game.records["tower_seen"] = seen
	# Moonwick in the Candle Box (unlocked by the true ending above)
	main.goto("title")
	await at._wait(3.5)
	var t: Node = main.current
	if t and t.get("sel") != null and t.has_method("_show_candle"):
		t.sel = "moonwick"
		t._show_candle()
		await at._wait(0.8)
		await at._shot("title_moonwick")
