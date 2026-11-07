class_name BestiaryGallery
extends CanvasLayer
## Review sheets for the bestiary (used by the screenshot tour, never in play):
##   -- --autotest --tour --gallery --shots=DIR   every monster + every boss labelled, then each floor's
##                                                 lodgers standing in a real lit room
##   -- --autotest --tour --bosses --shots=DIR    each of the 8 guardians mid-fight (the bot plays)

const BG := Color("#2a2a3a")


static func regulars() -> Array:
	return Enemy.DEFS.keys().filter(func(k): return not Enemy.DEFS[k].get("boss", false))


static func boss_kinds() -> Array:
	return Enemy.DEFS.keys().filter(func(k): return Enemy.DEFS[k].get("boss", false))


func build(kinds: Array, cols: int, sc: int, title: String) -> void:
	layer = 60
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = vs
	add_child(bg)
	var head := UI.label(title, 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.size = Vector2(vs.x, 10)
	head.position = Vector2(0, 1)
	add_child(head)
	var rows := ceili(kinds.size() / float(cols))
	var cw := vs.x / cols
	var ch := (vs.y - 18.0) / rows
	for i in kinds.size():
		var k: String = kinds[i]
		var d: Dictionary = Enemy.DEFS[k]
		var cx := cw * (i % cols) + cw / 2.0
		var cy := 12.0 + ch * (i / cols)
		var s := AnimatedSprite2D.new()
		var sname: String = d.get("sprite", k)
		s.sprite_frames = Enemy.frames_for(sname)
		var anim := "idle" if s.sprite_frames.has_animation("idle") else "default"
		s.play(anim)
		s.centered = false
		var tex: Texture2D = s.sprite_frames.get_frame_texture(anim, 0)
		s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		s.scale = Vector2(sc, sc)
		s.position = Vector2(roundf(cx), roundf(cy + ch - (19.0 if cw < 70.0 else 13.0)))
		s.modulate = d.get("tint", Color.WHITE)
		add_child(s)
		var nm := str(d.get("name", k))
		if cw < 70.0 and nm.contains(" "):
			nm = nm.replace(" ", "\n")
		var l := UI.label(nm, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		l.size = Vector2(cw, 18)
		l.position = Vector2(cx - cw / 2.0, cy + ch - 13.0)
		l.add_theme_constant_override("line_spacing", -3)
		add_child(l)


## Every lodger of floor `n` standing in a lit room of that floor (AI frozen).
static func live(w: Node, n: int) -> void:
	w._start_floor(n)
	w.player.frozen = true
	w.freeze_t = 9999.0
	var kinds: Array = []
	for slot in ["e", "h", "f"]:
		for k in w.POOLS[n][slot]:
			if not k in kinds:
				kinds.append(k)
	var c: Vector2 = w.room.center()
	var cols := 6
	for i in kinds.size():
		var pos: Vector2 = c + Vector2(-100 + 40 * (i % cols), -40 + 34 * (i / cols))
		var e: Enemy = w.spawn_enemy(kinds[i], pos, "ember" if i == 3 else "")
		if e:
			e.set_meta("swarm_child", true)
	w.player.position = c + Vector2(0, 60)


static func tour(bot: Node) -> void:
	if bot.args.has("bosses"):
		await boss_tour(bot)
		return
	var g := BestiaryGallery.new()
	bot.add_child(g)
	g.build(regulars(), 9, 1, "THE HOUSE'S LODGERS  (%d)" % regulars().size())
	await bot._wait(0.6)
	await bot._shot("gallery_monsters")
	g.queue_free()
	var all := regulars()
	var half := ceili(all.size() / 2.0)
	for part in 2:
		var g2 := BestiaryGallery.new()
		bot.add_child(g2)
		g2.build(all.slice(part * half, (part + 1) * half), 6, 2, "LODGERS x2  (%d/2)" % (part + 1))
		await bot._wait(0.6)
		await bot._shot("gallery_monsters_x2_%d" % (part + 1))
		g2.queue_free()
	var g3 := BestiaryGallery.new()
	bot.add_child(g3)
	g3.build(boss_kinds(), 4, 2, "THE GUARDIANS (%d)" % boss_kinds().size())
	await bot._wait(0.6)
	await bot._shot("gallery_bosses")
	g3.queue_free()
	bot.main.goto("game", {"seed": 7})
	await bot._wait(1.6)
	var w: Node = bot.main.current
	for n in [1, 2, 3, 4]:
		live(w, n)
		await bot._wait(1.4)
		await bot._shot("gallery_live_%d" % n)


## Each guardian in turn, with the bot fighting it (unkillable), two shots each.
static func boss_tour(bot: Node) -> void:
	bot.args["god"] = true
	bot.args["drive"] = true
	var floors: Dictionary = load("res://scripts/game/world.gd").FLOORS
	for n in [1, 2, 3, 4]:
		for kind in floors[n]["bosses"]:
			if bot.args.has("only") and str(bot.args["only"]) != kind:
				continue
			bot.main.goto("game", {"seed": 11 + n})
			await bot._wait(1.2)
			var w: Node = bot.main.current
			w._start_floor(n)
			w.boss_kind = kind
			var bcell: Vector2i = w.layout["boss"]
			await bot._wait(0.3)
			bot._jump(w, bcell)
			await bot._wait(4.0)
			await bot._shot("boss_%s_a" % kind)
			if w.boss and is_instance_valid(w.boss):
				w.boss.hp = w.boss.max_hp * 0.3
				w.boss._damage(0.01, false)
			await bot._wait(4.5)
			await bot._shot("boss_%s_b" % kind)
