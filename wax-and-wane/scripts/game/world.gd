extends Node2D
## One run: floors, rooms, the candle, enemies, drops, the clock and every effect.

const FLOORS := {
	1: {"name": "The Cellar", "theme": "cellar", "dark": Color(0.28, 0.22, 0.23), "music": "floor_1", "boss": "big_zombie"},
	2: {"name": "The Crypt", "theme": "crypt", "dark": Color(0.2, 0.22, 0.29), "music": "floor_2", "boss": "ogre"},
	3: {"name": "The Chapel", "theme": "chapel", "dark": Color(0.23, 0.19, 0.29), "music": "floor_3", "boss": "necro_boss"},
	4: {"name": "The Belfry", "theme": "belfry", "dark": Color(0.28, 0.18, 0.17), "music": "floor_4", "boss": "big_demon"},
}
const POOLS := {
	1: {"e": ["tiny_zombie", "goblin", "tiny_slug", "tiny_zombie"], "h": ["muddy", "slug", "skelet"], "f": ["imp"]},
	2: {"e": ["goblin", "skelet", "swampy", "tiny_zombie"], "h": ["pumpkin_dude", "muddy", "doc"], "f": ["imp"]},
	3: {"e": ["skelet", "chort", "swampy", "wogol"], "h": ["orc_shaman", "masked_orc", "necromancer", "pumpkin_dude"], "f": ["imp"]},
	4: {"e": ["chort", "wogol", "ice_zombie", "skelet"], "h": ["orc_shaman", "masked_orc", "necromancer", "doc"], "f": ["imp"]},
}
const LAST_FLOOR := 4
## Base melt: a full candle (120 wax) lasts ~13 minutes if you never get hit.
const DRAIN_PER_SEC := 120.0 / (11.5 * 60.0)

var main: Node
var floor_num := 1
var layout := {}
var cur_cell := Vector2i.ZERO
var room: Room
var player: Player
var hud: Hud
var cam: Camera2D
var dark: CanvasModulate
var rooms_layer: Node2D
var actors: Node2D
var fx_layer: Node2D
var enemies: Array = []
var enemy_shots: Array = []
var hazards: Array = []
var moths: Array = []
var boss: Enemy
var paused := false
var transitioning := false
var room_spawned := false
var finished := false
var rng := RandomNumberGenerator.new()
var relic_pool: Array = []
var shop_discount := 1.0
var bomb_radius := 34.0
var kills := 0
var rooms_cleared := 0
var run_time := 0.0
var _shake := 0.0
var _bells := {}
var _heartbeat := 0.0
var _fade: ColorRect
var _kb_bomb_held := false
var room_hits := 0
var room_t0 := 0.0
var _intro_root: Control


func setup(params: Dictionary) -> void:
	if params.has("seed"):
		rng.seed = int(params["seed"])
	else:
		rng.randomize()


func _ready() -> void:
	main = get_parent()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	dark = CanvasModulate.new()
	add_child(dark)
	rooms_layer = Node2D.new()
	add_child(rooms_layer)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	fx_layer = Node2D.new()
	fx_layer.z_index = 20
	add_child(fx_layer)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	hud = Hud.new(self)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var fl := CanvasLayer.new()
	fl.layer = 9
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0.035, 0.027, 0.035, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)
	relic_pool = Items.RELICS.keys()
	relic_pool.shuffle()
	player = Player.new()
	player.world = self
	actors.add_child(player)
	Game.records["runs"] += 1
	Game.save()
	_start_floor(1)
	if not Game.records["seen_intro"] and main.autotest == null:
		_intro()


func _intro() -> void:
	paused = true
	get_tree().paused = true
	var m := UI.modal(hud.root, "12:00 AM")
	var root: Control = m[0]
	_intro_root = root
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	for line in ["The old house wakes when the clock strikes twelve.",
			"You are Tallow, the last candle in the cellar.",
			"Burn down through four floors and snuff the Hour Fiend",
			"before the clock strikes two.",
			"",
			"Your wax is your life - and your time.",
			"Every hit melts you. Wax drippings mend you."]:
		v.add_child(UI.label(line, 8, UI.CREAM if line != "" else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.button("Light the wick", func():
		Game.records["seen_intro"] = true
		Game.save()
		root.queue_free()
		paused = false
		get_tree().paused = false, 120))


# ---------------------------------------------------------------- floors & rooms

func floor_title() -> String:
	return "%s  -  %d/%d" % [FLOORS[floor_num]["name"], floor_num, LAST_FLOOR]


func _start_floor(n: int) -> void:
	floor_num = n
	layout = FloorGen.generate(n, rng)
	dark.color = FLOORS[n]["dark"]
	for c in layout["cells"].keys():
		layout["cells"][c]["seen"] = false
	cur_cell = layout["start"]
	if room:
		room.dispose()
		room = null
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_clear_shots()
	room = _build_room(cur_cell)
	player.position = room.center() + Vector2(0, 8)
	player.vel = Vector2.ZERO
	cam.position = _cam_target(room)
	_on_enter_room()
	Audio.music(FLOORS[n]["music"])
	hud.show_banner(FLOORS[n]["name"].to_upper(), "Floor %d of %d   -   %s" % [n, LAST_FLOOR, Game.clock_text(clock_minutes())], 2.2)
	if n == 1:
		hud.show_hint("Left thumb: move    Right thumb: shoot    Wax = health = time", 7.0)


func _cam_target(r: Room) -> Vector2:
	return r.position + Vector2(Room.W / 2.0, Room.H / 2.0)


func _build_room(c: Vector2i) -> Room:
	var r := Room.new()
	var neighbours := {}
	for d in FloorGen.DIRS:
		if layout["cells"].has(c + d):
			neighbours[d] = layout["cells"][c + d]["type"]
	rooms_layer.add_child(r)
	r.build(self, c, layout["cells"][c], FLOORS[floor_num]["theme"], neighbours)
	# restore persistent pickups
	for rec in layout["cells"][c]["pickups"]:
		_spawn_pickup_node(r, rec)
	return r


func _on_enter_room() -> void:
	var d: Dictionary = room.data
	d["visited"] = true
	d["seen"] = true
	for dd in FloorGen.DIRS:
		if layout["cells"].has(cur_cell + dd):
			layout["cells"][cur_cell + dd]["seen"] = true
	player.coat_ready = true
	room_spawned = false
	room_hits = 0
	match d["type"]:
		"treasure":
			if not d.get("stocked", false):
				d["stocked"] = true
				# a choice of two: take one, the other crumbles
				var a := add_pickup("relic", room.center() + Vector2(-26, 2), _next_relic())
				var b := add_pickup("relic", room.center() + Vector2(26, 2), _next_relic())
				a.record["group"] = "treasure"
				b.record["group"] = "treasure"
				hud.show_hint("Choose one relic. The other will crumble.", 3.0)
		"shop":
			if not d.get("stocked", false):
				d["stocked"] = true
				_stock_shop()
			_spawn_keeper()
			if not d.get("greeted", false):
				d["greeted"] = true
				hud.show_banner("THE TALLOW MERCHANT", "Coins for wax and wonders", 1.6)
		"boss":
			if not d["cleared"]:
				_start_boss()
				return
	if not d["cleared"]:
		room.set_open(false, true)
		Audio.play("door_close", -3.0)
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(_spawn_room_enemies)


func _spawn_room_enemies() -> void:
	var pool: Dictionary = POOLS[floor_num]
	var depth: int = room.data["dist"]
	for slot in room.spawn_slots():
		var letter: String = slot[0]
		var pos: Vector2 = slot[1]
		if letter == "T":
			if floor_num >= 2 and rng.randf() < 0.18:
				spawn_enemy("mimic", pos)
			else:
				add_pickup("chest", pos)
			continue
		if pos.distance_to(player.global_position) < 56.0:
			pos = random_free_spot(player.global_position, 72.0)
		var list: Array = pool[letter]
		spawn_enemy(list[rng.randi() % list.size()], pos)
	# deeper rooms get one extra guest
	if depth >= 4 and rng.randf() < 0.5:
		var list2: Array = pool["e"]
		spawn_enemy(list2[rng.randi() % list2.size()], random_free_spot(player.global_position, 80.0))
	room_spawned = true
	room_t0 = run_time
	if count_enemies() == 0:
		_clear_room()


func _start_boss() -> void:
	room.set_open(false, true)
	player.frozen = true
	var kind: String = FLOORS[floor_num]["boss"]
	var name: String = Enemy.DEFS[kind]["name"]
	Audio.music("final_boss" if floor_num == LAST_FLOOR else "boss")
	Audio.play("boss_roar")
	hud.show_banner(name, "Floor %d guardian" % floor_num, 1.6)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func():
		boss = spawn_enemy(kind, room.center() + Vector2(0, -24))
		hud.set_boss(name, true)
		player.frozen = false
		room_spawned = true
		shake(4.0))


func go_through(dir: Vector2i) -> void:
	if transitioning:
		return
	var next := cur_cell + dir
	if not layout["cells"].has(next):
		return
	transitioning = true
	player.frozen = true
	_clear_shots()
	var old := room
	var nr := _build_room(next)
	cur_cell = next
	room = nr
	player.position = nr.entry_point(-dir)
	player.vel = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(cam, "position", _cam_target(nr), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		old.dispose()
		transitioning = false
		player.frozen = false
		_on_enter_room())


func descend() -> void:
	if transitioning:
		return
	transitioning = true
	player.frozen = true
	Audio.play("trapdoor")
	var tw := create_tween()
	tw.tween_property(player, "scale", Vector2(0.2, 0.2), 0.35)
	tw.parallel().tween_property(_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func():
		player.scale = Vector2.ONE
		_start_floor(floor_num + 1)
		player.frozen = false
		transitioning = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func _clear_room() -> void:
	var d: Dictionary = room.data
	if d["cleared"]:
		return
	d["cleared"] = true
	rooms_cleared += 1
	room.set_open(true)
	room.light_candles()
	Audio.play("room_clear")
	if player.hourglass > 0:
		player.heal(player.hourglass)
		fx_text(player.global_position + Vector2(0, -26), "+%d min" % int(player.hourglass), UI.GOLD)
	if d["type"] == "normal":
		_room_reward(room.center() + Vector2(0, 4))
		if room_hits == 0:
			player.heal(2.0)
			fx_text(player.global_position + Vector2(0, -34), "CLEAN  +2 min", UI.GOLD)
		var par := 8.0 + 2.5 * floor_num
		if run_time - room_t0 <= par:
			player.heal(3.0)
			fx_text(player.global_position + Vector2(0, -44), "QUICK  +3 min", UI.EMBER)


func _room_reward(pos: Vector2) -> void:
	if rng.randf() > 0.6 + player.luck * 0.3:
		return
	var roll := rng.randf()
	if roll < 0.32:
		add_pickup("wax_small", pos)
	elif roll < 0.45:
		add_pickup("wax_big", pos)
	elif roll < 0.72:
		for i in rng.randi_range(2, 4):
			add_pickup("coin", pos, "", 0, Vector2.from_angle(rng.randf() * TAU) * 40.0)
	elif roll < 0.88:
		add_pickup("bomb", pos)
	else:
		add_pickup("chest", pos)


func _next_relic() -> String:
	for i in relic_pool.size():
		var id: String = relic_pool[i]
		if not id in player.relics:
			relic_pool.remove_at(i)
			return id
	return "flask_red"


func _stock_shop() -> void:
	var c := room.center()
	add_pickup("relic", c + Vector2(-40, -4), _next_relic(), 10 + 2 * floor_num)
	var tonics := Items.TONICS.keys()
	add_pickup("tonic", c + Vector2(0, -4), tonics[rng.randi() % tonics.size()], 5)
	add_pickup("wax_big", c + Vector2(40, 0), "", 4)


func _spawn_keeper() -> void:
	var c := room.center()
	var keeper := AnimatedSprite2D.new()
	keeper.sprite_frames = Art.creature("dwarf_m")
	keeper.play("idle")
	keeper.centered = false
	keeper.offset = Vector2(-8, -28)
	keeper.position = c + Vector2(0, -44) - room.position
	keeper.flip_h = true
	room.objects.add_child(keeper)


# ---------------------------------------------------------------- pickups

func add_pickup(kind: String, pos: Vector2, item := "", price := 0, pop_vel := Vector2.ZERO) -> Pickup:
	var rec := {"kind": kind, "pos": pos, "item": item, "price": price}
	room.data["pickups"].append(rec)
	var p := _spawn_pickup_node(room, rec)
	if pop_vel != Vector2.ZERO:
		p.pop(pop_vel)
	return p


func _spawn_pickup_node(r: Room, rec: Dictionary) -> Pickup:
	var p := Pickup.new()
	p.setup(self, rec["kind"], rec["pos"] - r.position, rec["item"], rec["price"])
	p.record = rec
	r.objects.add_child(p)
	return p


func forget_pickup(rec: Dictionary) -> void:
	if room:
		room.data["pickups"].erase(rec)


func collect_item(id: String, pos: Vector2, rec := {}) -> void:
	var group: String = rec.get("group", "")
	if group != "" and room:
		for o in room.objects.get_children():
			if o is Pickup and not o.taken and o.record and o.record.get("group", "") == group and o.record != rec:
				o.taken = true
				forget_pickup(o.record)
				fx_smoke(o.global_position + Vector2(0, -14))
				var tw := o.create_tween()
				tw.tween_property(o, "modulate:a", 0.0, 0.4)
				tw.tween_callback(o.queue_free)
	Items.apply(id, player, self)
	Audio.play("item_get")
	hud.show_banner(Items.display_name(id).to_upper(), Items.desc(id), 2.0)
	fx_ring(pos + Vector2(0, -16), Color(1.0, 0.8, 0.4))
	player._happy_face = 1.5


func open_chest(pos: Vector2) -> void:
	var n := rng.randi_range(2, 4)
	for i in n:
		var roll := rng.randf()
		var k := "coin"
		if roll < 0.25:
			k = "wax_small"
		elif roll < 0.35:
			k = "bomb"
		elif roll < 0.42:
			k = "wax_big"
		add_pickup(k, pos + Vector2(0, 4), "", 0, Vector2.from_angle(rng.randf() * TAU) * 60.0)
	if rng.randf() < 0.22:
		var tonics := Items.TONICS.keys()
		add_pickup("tonic", pos + Vector2(0, 14), tonics[rng.randi() % tonics.size()])


func roll_obstacle_drop(pos: Vector2) -> void:
	var r := rng.randf()
	if r < 0.16 + player.luck * 0.1:
		add_pickup("coin", pos, "", 0, Vector2.from_angle(rng.randf() * TAU) * 30.0)
	elif r < 0.25:
		add_pickup("wax_small", pos)
	elif r < 0.28:
		add_pickup("bomb", pos)


# ---------------------------------------------------------------- enemies

func spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	if room == null:
		return null
	var r: float = Enemy.DEFS[kind]["r"]
	if not Enemy.DEFS[kind].get("fly", false) and room.blocked(pos, r):
		pos = free_spot_near(pos, r)
	var e := Enemy.new()
	e.setup(self, kind, pos - room.position, floor_num)
	room.objects.add_child(e)
	enemies.append(e)
	return e


func count_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			n += 1
	return n


func on_enemy_killed(e: Enemy) -> void:
	kills += 1
	Audio.play("enemy_die")
	fx_poof(e.global_position + Vector2(0, -6), false, 1.4)
	if e.boss:
		_boss_down(e)
		return
	var r := rng.randf()
	var luck := player.luck
	if r < 0.06 + luck * 0.04:
		add_pickup("wax_small", e.global_position)
	elif r < 0.19 + luck * 0.1:
		add_pickup("coin", e.global_position, "", 0, Vector2.from_angle(rng.randf() * TAU) * 25.0)
	elif r < 0.165:
		add_pickup("bomb", e.global_position)


func on_boss_hp(e: Enemy) -> void:
	hud.set_boss_frac(e.hp / e.max_hp)


func on_boss_phase(ph: int) -> void:
	shake(5.0)
	Audio.play("boss_roar")
	hud.show_banner("", "The bell answers..." if ph == 2 else "It is nearly two!", 1.2)


func _boss_down(e: Enemy) -> void:
	hud.set_boss_frac(0)
	Audio.play("boss_die")
	shake(7.0)
	hitstop(0.35, 0.15)
	_clear_shots()
	for m in enemies:
		if is_instance_valid(m) and m != e and m.alive:
			m.hp = 0
			m.alive = false
			fx_poof(m.global_position + Vector2(0, -6), false)
			m.queue_free()
	var pos := e.global_position
	if floor_num >= LAST_FLOOR:
		player.frozen = true
	var tw := create_tween()
	tw.tween_property(e, "modulate", Color(3, 2, 1.5, 0.0), 1.2)
	tw.tween_callback(e.queue_free)
	tw.tween_callback(func():
		hud.set_boss("", false)
		if floor_num >= LAST_FLOOR:
			_victory()
			return
		_clear_room()
		add_pickup("relic", room.center() + Vector2(-24, 0), _next_relic())
		add_pickup("wax_big", room.center() + Vector2(24, 4))
		add_pickup("trapdoor", room.center() + Vector2(0, 36))
		for i in 4:
			add_pickup("coin", room.center() + Vector2(0, 14), "", 0, Vector2.from_angle(rng.randf() * TAU) * 50.0)
		player.damage += 0.15
		fx_text(room.center() + Vector2(0, -30), "Your flame grows", UI.GOLD)
		Audio.music(FLOORS[floor_num]["music"]))
	for i in 6:
		var t2 := create_tween()
		t2.tween_interval(i * 0.15)
		t2.tween_callback(func(): fx_poof(pos + Vector2(randf_range(-14, 14), randf_range(-26, 0)), false, 2.0))


# ---------------------------------------------------------------- shots

func shoot_player(pos: Vector2, dir: Vector2, p: Player, dmg: float) -> void:
	var s := Shot.new()
	s.setup(self, pos, dir * p.shot_speed + p.vel * 0.25, "ember_blue" if p.blue else "ember", true)
	s.dmg = dmg
	s.life = p.shot_range / p.shot_speed
	s.pierce = p.pierce
	s.homing = p.homing
	s.burn = p.burn
	s.knock = p.knockback
	s.radius = 3.0 * p.shot_scale
	s.scale = Vector2(p.shot_scale, p.shot_scale)
	fx_layer.add_child(s)


func enemy_shot(pos: Vector2, v: Vector2, kind := "bullet_purple") -> void:
	if finished:
		return
	var s := Shot.new()
	s.setup(self, pos, v, kind, false)
	s.life = 4.0
	s.radius = 3.0
	fx_layer.add_child(s)
	enemy_shots.append(s)


func burst(pos: Vector2, n: int, spd: float, kind: String, offset := 0.0) -> void:
	for i in n:
		enemy_shot(pos, Vector2.from_angle(offset + TAU * i / n) * spd, kind)


func lob(from: Vector2, to: Vector2) -> void:
	var s := Shot.new()
	s.setup(self, from, Vector2.ZERO, "bullet_green", false)
	s.lob = true
	s.lob_from = from
	s.lob_to = to + Vector2(0, -6)
	fx_layer.add_child(s)


func _clear_shots() -> void:
	for s in fx_layer.get_children():
		if s is Shot:
			s.queue_free()
	enemy_shots.clear()


func nearest_enemy(pos: Vector2, max_d := 9999.0) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.active:
			var d: float = e.global_position.distance_squared_to(pos)
			if d < bd:
				bd = d
				best = e
	return best


func assist_aim(pos: Vector2, dir: Vector2) -> Vector2:
	if not Game.settings["aim_assist"]:
		return dir
	var best := dir
	var best_a := deg_to_rad(20.0)
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or not e.active:
			continue
		var to: Vector2 = e.global_position + Vector2(0, -e.half_h - e._jump_h) - pos
		if to.length() > player.shot_range * 1.3:
			continue
		var a := absf(dir.angle_to(to))
		if a < best_a:
			best_a = a
			best = to.normalized()
	return best


func enemy_dmg_mult() -> float:
	return 1.0 + 0.12 * (floor_num - 1)


func time_scale_enemies() -> float:
	return 1.0 - player.slow_aura


## The nearest walkable point to `pos` (spawns must never land inside rocks or columns).
func free_spot_near(pos: Vector2, r := 6.0) -> Vector2:
	var best := room.center()
	var bd := 1e9
	for y in Room.ROWS:
		for x in Room.COLS:
			var c := Vector2i(x, y)
			if room.char_at(c) in Room.SOLID or room.char_at(c) == "S":
				continue
			var p := room.cell_center(c) + Vector2(0, 4)
			if room.blocked(p, r):
				continue
			var d := p.distance_squared_to(pos)
			if d < bd:
				bd = d
				best = p
	return best


func random_free_spot(away_from: Vector2, min_d: float) -> Vector2:
	for i in 40:
		var c := Vector2i(rng.randi_range(1, 13), rng.randi_range(1, 7))
		if room.char_at(c) in [".", "e", "h", "f", "T"]:
			var p := room.cell_center(c) + Vector2(0, 4)
			if p.distance_to(away_from) >= min_d and not room.blocked(p, 7.0):
				return p
	return room.center()


# ---------------------------------------------------------------- bombs, drips, moths

func place_bomb() -> void:
	if paused or player.dead or player.bombs <= 0 or transitioning:
		return
	player.bombs -= 1
	Audio.play("bomb_place")
	var b := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	for t in Art.seq("0x72/bomb"):
		sf.add_frame("default", t)
	sf.set_animation_speed("default", 6.0)
	b.sprite_frames = sf
	b.play("default")
	b.offset = Vector2(0, -6)
	b.position = player.position - room.position + Vector2(0, 1)
	room.objects.add_child(b)
	var r := room
	var tw := b.create_tween()
	tw.tween_property(b, "speed_scale", 4.0, 1.4)
	tw.tween_callback(func(): _explode(b.global_position, r); b.queue_free())


func _explode(pos: Vector2, r: Room) -> void:
	if r != room:
		return
	Audio.play("explosion")
	shake(6.0)
	Game.vibrate(80)
	var ex := AnimatedSprite2D.new()
	ex.sprite_frames = Art.anim("fx/explosion", 16.0, false)
	ex.position = pos + Vector2(0, -12)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ex.material = mat
	fx_layer.add_child(ex)
	ex.play("default")
	ex.animation_finished.connect(ex.queue_free)
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(1, 0.6, 0.3)
	l.energy = 1.6
	l.texture_scale = 0.9
	ex.add_child(l)
	var lt := l.create_tween()
	lt.tween_property(l, "energy", 0.0, 0.5)
	if Art.has("fx/scorch"):
		var sc := Sprite2D.new()
		sc.texture = Art.tex("fx/scorch")
		sc.position = pos - r.position
		sc.modulate.a = 0.8
		r.floor_layer.add_child(sc)
	r.blast(pos, bomb_radius)
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.global_position.distance_to(pos) < bomb_radius + e.radius:
			e.active = true
			e.take_hit(10.0 + 2.0 * floor_num, (e.global_position - pos).normalized() * 150.0)
	if player.global_position.distance_to(pos) < bomb_radius * 0.8:
		player.hurt(10.0, player.global_position - pos)


func spawn_hot_drip(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex("rooms/decal_wax_puddle") if Art.has("rooms/decal_wax_puddle") else Art.tex("pickups/wax_small")
	s.position = pos
	s.modulate = Color(1.0, 0.6, 0.3, 0.9)
	s.z_index = -5
	fx_layer.add_child(s)
	hazards.append([s, 2.5, 0.0])


func add_moth() -> void:
	var m := Sprite2D.new()
	m.texture = Art.tex("items/moth_friend")
	m.z_index = 6
	fx_layer.add_child(m)
	moths.append(m)


# ---------------------------------------------------------------- player events

func on_player_hurt(amount: float) -> void:
	room_hits += 1
	shake(3.0)
	hitstop(0.06, 0.05)
	hud.on_hurt()
	fx_text(player.global_position + Vector2(0, -26), "-%d min" % int(round(amount)), UI.RED)
	for i in 5:
		fx_drop(player.global_position + Vector2(0, -10), Vector2.from_angle(randf_range(-PI, 0)) * randf_range(30, 70))


func on_player_died() -> void:
	if finished:
		return
	finished = true
	hud.release_sticks()
	Audio.music("death_jingle", 0.3)
	Audio.play("snuff_out")
	Audio.play("bell_toll", 0.0, 0.0, 0.9)
	_clear_shots()
	fx_smoke(player.global_position + Vector2(0, -18))
	Engine.time_scale = 0.35 * Game.base_time_scale
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(1.0)
	tw.tween_callback(func(): Engine.time_scale = Game.base_time_scale)
	tw.tween_interval(1.4)
	tw.tween_callback(func(): _end_run(false))


func _victory() -> void:
	if finished:
		return
	finished = true
	player.frozen = true
	hud.release_sticks()
	Audio.music("victory_jingle", 0.3)
	Audio.play("victory")
	hud.show_banner("THE HOUR FIEND IS SNUFFED", "Done by %s" % Game.clock_text(clock_minutes()), 3.0)
	var tw := create_tween()
	tw.tween_interval(3.4)
	tw.tween_callback(func(): _end_run(true))


func _end_run(won: bool) -> void:
	Game.records["kills"] += kills
	Game.records["best_floor"] = maxi(int(Game.records["best_floor"]), floor_num)
	if won:
		Game.records["wins"] += 1
		var t := clock_minutes()
		if float(Game.records["best_finish"]) <= 0.0 or t < float(Game.records["best_finish"]):
			Game.records["best_finish"] = maxf(t, 0.01)
	Game.save()
	main.goto("results", {"won": won, "floor": floor_num, "clock": clock_minutes(), "kills": kills,
		"rooms": rooms_cleared, "relics": player.relics.duplicate(), "time": run_time})


func give_up() -> void:
	toggle_pause()
	player.dead = true
	on_player_died()


## Clock minutes past midnight: a full 120-wax candle = 12:00 AM, an empty one = 2:00 AM.
func clock_minutes() -> float:
	return 120.0 - player.wax


# ---------------------------------------------------------------- loop

func _physics_process(dt: float) -> void:
	if player == null:
		return
	# input: touch sticks + keyboard (WASD move, arrows shoot, space/E bomb)
	var mv := hud.move_vec
	var aim := hud.aim_vec
	var k := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if k != Vector2.ZERO:
		mv = k.normalized()
	var a := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	if a != Vector2.ZERO:
		aim = a.normalized()
	var bomb_key := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E)
	if bomb_key and not _kb_bomb_held:
		place_bomb()
	_kb_bomb_held = bomb_key
	if main.autotest and main.autotest.has_method("drive"):
		var drv: Array = main.autotest.drive(self)
		if not drv.is_empty():
			mv = drv[0]
			aim = drv[1]
	player.move_input = mv
	player.aim_input = aim
	if finished:
		return
	if not transitioning and not player.dead and not player.frozen:
		run_time += dt
		player.wax -= DRAIN_PER_SEC * player.drain_mult * dt
		if player.wax <= 0.0:
			player.wax = 0.0
			player.die()
		_clock_events()
		var exit := room.door_exit(player.global_position)
		if exit != Vector2i.ZERO:
			go_through(exit)
	if room_spawned and not room.data["cleared"] and count_enemies() == 0 and not transitioning and room.data["type"] != "boss":
		_clear_room()
	enemies = enemies.filter(func(e): return is_instance_valid(e) and (e.alive or e.boss))
	_update_hazards(dt)
	_update_moths(dt)


func _clock_events() -> void:
	var m := clock_minutes()
	for mark in [60.0, 90.0, 105.0]:
		if m >= mark and not _bells.has(mark):
			_bells[mark] = true
			Audio.play("bell_toll")
			match int(mark):
				60: hud.show_banner("1:00 AM", "The clock strikes one", 1.8)
				90: hud.show_banner("1:30 AM", "Half past one. Hurry.", 1.6)
				105: hud.show_banner("1:45 AM", "Your wick is nearly gone", 1.6)
		elif m < mark - 4.0 and _bells.has(mark):
			_bells.erase(mark)
	if player.wax < 15.0 and not player.dead:
		_heartbeat -= get_physics_process_delta_time()
		if _heartbeat <= 0:
			_heartbeat = 1.1
			Audio.play("low_wax")


func _update_hazards(dt: float) -> void:
	for h in hazards.duplicate():
		var s: Sprite2D = h[0]
		h[1] -= dt
		h[2] -= dt
		if h[1] <= 0 or not is_instance_valid(s):
			hazards.erase(h)
			if is_instance_valid(s):
				s.queue_free()
			continue
		s.modulate.a = clampf(h[1], 0.0, 0.9)
		if h[2] <= 0:
			h[2] = 0.4
			for e in enemies:
				if is_instance_valid(e) and e.alive and e.active and e.global_position.distance_to(s.global_position) < 9 + e.radius:
					e.take_hit(0.5, Vector2.ZERO, 0.0)


func _update_moths(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in moths.size():
		var m: Sprite2D = moths[i]
		var ang := t * 3.0 + i * PI
		m.global_position = player.global_position + Vector2(0, -10) + Vector2.from_angle(ang) * 18.0
		m.flip_h = cos(ang) < 0
		for s in enemy_shots:
			if is_instance_valid(s) and s.global_position.distance_to(m.global_position) < 7:
				s.end()
		for e in enemies:
			if is_instance_valid(e) and e.alive and e.active and (e.global_position + Vector2(0, -6)).distance_to(m.global_position) < 6 + e.radius:
				if fmod(t, 0.3) < dt:
					e.take_hit(0.6, Vector2.ZERO)
	enemy_shots = enemy_shots.filter(func(s): return is_instance_valid(s))


func _process(dt: float) -> void:
	if _shake > 0 and Game.settings["shake"]:
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
		_shake = move_toward(_shake, 0.0, dt * 22.0)
	else:
		cam.offset = Vector2.ZERO


# ---------------------------------------------------------------- pause / lifecycle

func toggle_pause() -> void:
	if finished:
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		hud.open_pause()
	else:
		hud.close_pause()
		Audio.play("ui_back")


func on_back() -> void:
	if is_instance_valid(_intro_root):
		return
	# close a settings panel first, if one is open over the pause menu
	var top: Node = hud.root.get_child(hud.root.get_child_count() - 1)
	if paused and top != hud.pause_layer and top.get_meta("modal", false):
		top.queue_free()
		return
	toggle_pause()


func on_focus_lost() -> void:
	if not paused and not finished:
		toggle_pause()


# ---------------------------------------------------------------- effects

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func hitstop(dur: float, scale_ := 0.05) -> void:
	if finished:
		return
	Engine.time_scale = scale_ * Game.base_time_scale
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(dur)
	tw.tween_callback(func():
		if not finished:
			Engine.time_scale = Game.base_time_scale)


func fx_poof(pos: Vector2, warm := true, sc := 1.0) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("fx/poof", 18.0, false)
	a.position = pos
	a.scale = Vector2(sc, sc)
	if warm:
		a.modulate = Color(1.0, 0.8, 0.55)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	a.material = mat
	fx_layer.add_child(a)
	a.play("default")
	a.animation_finished.connect(a.queue_free)


func fx_smoke(pos: Vector2) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("fx/smoke", 8.0, false)
	a.position = pos
	fx_layer.add_child(a)
	a.play("default")
	var tw := a.create_tween()
	tw.tween_property(a, "position:y", pos.y - 10, 0.6)
	tw.parallel().tween_property(a, "modulate:a", 0.0, 0.6)
	tw.tween_callback(a.queue_free)


func fx_debris(pos: Vector2, ch: String) -> void:
	var col := Color("#8a503e") if ch == "C" else (Color("#c56025") if ch == "U" else Color("#775c55"))
	for i in 6:
		var r := ColorRect.new()
		r.color = col if i % 2 == 0 else col.darkened(0.3)
		r.size = Vector2(2, 2)
		r.position = pos + Vector2(randf_range(-4, 4), randf_range(-8, 0))
		fx_layer.add_child(r)
		var v := Vector2.from_angle(randf_range(-PI, 0)) * randf_range(20, 45)
		var tw := r.create_tween()
		tw.tween_property(r, "position", r.position + v * 0.35 + Vector2(0, 10), 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "modulate:a", 0.0, 0.3)
		tw.tween_callback(r.queue_free)


func fx_drop(pos: Vector2, v: Vector2) -> void:
	var r := ColorRect.new()
	r.color = Color("#fdf7ed") if randf() < 0.5 else Color("#d3bfa9")
	r.size = Vector2(2, 2)
	r.position = pos
	fx_layer.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "position", pos + v * 0.3 + Vector2(0, 14), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(r, "modulate:a", 0.0, 0.4)
	tw.tween_callback(r.queue_free)


func fx_text(pos: Vector2, text: String, col: Color) -> void:
	var l := UI.label(text, 8, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(60, 10)
	l.position = pos - Vector2(30, 0)
	l.z_index = 30
	fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 12, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.tween_callback(l.queue_free)


func fx_ring(pos: Vector2, col: Color) -> void:
	var n := Node2D.new()
	n.position = pos
	fx_layer.add_child(n)
	var st := {"r": 2.0}
	n.draw.connect(func(): n.draw_arc(Vector2.ZERO, st["r"], 0, TAU, 24, col, 1.0))
	var tw := n.create_tween()
	tw.tween_method(func(v): st["r"] = v; n.queue_redraw(), 2.0, 26.0, 0.4)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.4)
	tw.tween_callback(n.queue_free)
