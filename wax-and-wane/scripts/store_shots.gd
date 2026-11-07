extends RefCounted
## Store screenshots and key art, staged by the game itself (run through scripts/autotest.gd):
##   -- --autotest --shots-store --shots=/abs/dir [--phone]   ten staged gameplay moments with the HUD
##        (--phone: the touch HUD, for Google Play; run the window at 2160x1080 for an 18:9 phone)
##   -- --autotest --keyart --shots=/abs/dir                    the key-art scene with no HUD, framed for
##        every store shape (wide, standard, tall); tools/store_art.py turns them into capsules
## Shots are saved at the game's own resolution (384x216 at 1920x1080) and scaled up by whole numbers
## later, so every pixel stays crisp. Everything is staged from a fixed seed, fixed rooms, a fixed relic
## kit and a fixed cast, so a re-run on a later build gives the same pictures (the fights are live, so a
## shot can differ by a few frames). Run them all with: python3 tools/store_art.py

const SEED := 7
## worn in every gameplay shot: a second flame and a moth that circles Tallow
const KIT := ["twin_wick", "moth_friend"]


static func run(at: Node) -> void:
	DirAccess.make_dir_recursive_absolute(at._shots_dir)
	if at.args.has("keyart"):
		await _keyart(at)
	else:
		await _store(at)


# ---------------------------------------------------------------- helpers

## Saves the screen as <dir>/<name>.png. Banners and hints are snapped fully off first (keep_banner:
## the floor / relic banner stays, fully on), so no shot ever catches text half-faded.
static func _snap(at: Node, w: Node, name: String, keep_banner := false) -> void:
	if w != null:
		_settle_text(w, keep_banner)
	await at.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := at.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [at._shots_dir, name])
	var foes: int = w.count_enemies() if w != null else 0
	print("[store] shot %s %dx%d foes=%d" % [name, img.get_width(), img.get_height(), foes])


static func _settle_text(w: Node, keep_banner: bool) -> void:
	var h: Node = w.hud
	if h == null:
		return
	if h._banner_tw:
		h._banner_tw.kill()
	for l in [h.banner, h.banner_sub, h.banner_band]:
		l.modulate.a = 1.0 if keep_banner and h.banner.text != "" else 0.0
	if h._hint_tw:
		h._hint_tw.kill()
	h.hint.modulate.a = 0.0
	if keep_banner or h.preview.modulate.a < 1.0:   # the item line under a relic: fully on or off
		h.preview.modulate.a = 0.0
		h._preview_t = 0.0
	# floating "+1 min" texts in the room: only the ones still fully on stay in the picture
	for ch in w.fx_layer.get_children():
		if ch is Label and (ch as Label).modulate.a < 0.99:
			(ch as Label).visible = false


static func _until_game(at: Node) -> Node:
	var waited := 0.0
	var m: Node = at.main
	while waited < 10.0 and not (m.current and m.current.name == "Game" and m.current.get("player") != null and not m._busy):
		await at.get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	return m.current


static func _kit(w: Node) -> void:
	var p: Player = w.player
	for id in KIT:
		if Items.RELICS.has(id) and not id in p.relics:
			Items.apply(id, p, w)
	if Items.KEEPSAKES.has("hand_bell"):
		p.keepsake = "hand_bell"
		p.charge = int(Items.KEEPSAKES["hand_bell"]["pips"]) - 1   # one pip short: the bot must not ring it mid-shot
	p.coins = 23
	p.bombs = 3
	p.wax = p.wax_max


static func _template(id: String) -> Array:
	for t in RoomTemplates.NORMAL:
		if t["id"] == id:
			return RoomTemplates.to_grid(t["rows"])
	return []


## The k-th ordinary room of this floor (sorted, so it is the same room every time).
static func _normal(w: Node, k: int) -> Vector2i:
	var cells: Array = []
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] == "normal":
			cells.append(c)
	cells.sort()
	return cells[k % cells.size()] if not cells.is_empty() else w.layout["start"]


static func _cell_of(w: Node, t: String) -> Vector2i:
	var cells: Array = w.layout["cells"].keys()
	cells.sort()
	for c in cells:
		if w.layout["cells"][c]["type"] == t:
			return c
	return Vector2i(-99, -99)


static func _clear_foes(w: Node) -> void:
	for e in w.enemies:
		if is_instance_valid(e):
			e.queue_free()
	w.enemies.clear()
	w._clear_shots()


static func _floor(at: Node, w: Node, n: int) -> void:
	if w.floor_num != n:
		w._start_floor(n)
		await at._wait(0.3)


## An ordinary room set up for a fight: a chosen layout, doors shut, our own cast of lodgers.
## `stains`: lodgers killed first, so their splats are already on the floor.
static func _fight_room(at: Node, w: Node, k: int, template: String, cast: Array, stains: Array) -> void:
	var c := _normal(w, k)
	var d: Dictionary = w.layout["cells"][c]
	var g := _template(template)
	if not g.is_empty():
		d["grid"] = g
	d["cleared"] = true   # lit candelabras and no random spawns: the cast below is the fight
	at._jump(w, c)
	_clear_foes(w)
	w.room.set_open(false, true)
	w.player.position = w.room.center() + Vector2(-40, 30)
	await at._wait(0.4)
	var c0: Vector2 = w.room.center()
	await _splats(at, w, stains)
	await at._wait(0.6)
	for s in cast:
		w.spawn_enemy(s[0], c0 + s[1])
	w.room_spawned = true


## Lodgers snuffed on the spot, so their stains (and drippings) are already on the floor.
static func _splats(at: Node, w: Node, list: Array) -> void:
	var c0: Vector2 = w.room.center()
	for s in list:
		var e: Enemy = w.spawn_enemy(s[0], c0 + s[1])
		await at.get_tree().process_frame
		e.active = true
		e.take_hit(999.0, Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 60.0)


# ---------------------------------------------------------------- store screenshots

static func _store(at: Node) -> void:
	seed(SEED)
	var phone: bool = at.args.has("phone")
	Controls.set_device(Controls.TOUCH if phone else Controls.MOUSE)
	var main: Node = at.main
	# 1. the title (the intro lights the wick first); the records line and version stay out of it
	await at._wait(2.2)
	var title: Node = main.current
	for k in ["stats", "ver"]:
		var l: Variant = title.get(k)
		if l is CanvasItem:
			(l as CanvasItem).visible = false
	_hide_continue(title)   # a saved run from an earlier test would add a Continue button
	await at._wait(0.1)
	await _snap(at, null, "title")
	main.goto("game", {"seed": SEED})
	var w: Node = await _until_game(at)
	await at._wait(1.0)
	_kit(w)
	at.args["god"] = true   # the bot fights, but never melts below 80 wax in a shot
	# 2. a busy Cellar fight: stains, sparks, drippings, the clock running
	await _fight_room(at, w, 1, "fireplaces", [
		["goblin", Vector2(40, -24)], ["tiny_zombie", Vector2(62, 8)], ["cinder_rat", Vector2(24, 30)],
		["wax_blob", Vector2(70, -40)], ["imp", Vector2(-10, -50)], ["tiny_slug", Vector2(90, 30)],
		["muddy", Vector2(100, -10)]], [
		["wax_blob", Vector2(-10, -6)], ["goblin", Vector2(20, -34)], ["cinder_rat", Vector2(46, 14)], ["tiny_zombie", Vector2(-40, 30)]])
	w.player.position = w.room.center() + Vector2(-56, 14)
	w.player.wax = 104.0
	at.args["drive"] = true
	await at._wait(0.9)
	await _snap(at, w, "cellar_fight")
	await at._wait(0.6)
	await _snap(at, w, "cellar_fight_b")
	at.args.erase("drive")
	# 3. treasure: a choice of two relics, Tallow reading one
	var tc := _cell_of(w, "treasure")
	if tc.x > -99:
		at._jump(w, tc)
		_clear_foes(w)
		w.player.position = w.room.center() + Vector2(-26, 22)
		await at._wait(1.2)
		await _snap(at, w, "treasure")
	# 4. the shop and its merchant
	var sc := _cell_of(w, "shop")
	if sc.x > -99:
		at._jump(w, sc)
		_clear_foes(w)
		w.player.position = w.room.center() + Vector2(0, 16)
		await at._wait(1.2)
		await _snap(at, w, "shop")
	# 6. the Chapel: stained-glass light pools on the floor and a fight in them
	await _floor(at, w, 3)
	await _chapel(at, w)
	# 7. a Seance (special room): the chalk ring, the bell and a wave of pale lodgers
	await _floor(at, w, 2)
	await _seance(at, w)
	# 8. low wax: Tallow short, the light circle small, lodgers closing in, nearly two
	await _low_wax(at, w)
	# 9 + 10. the Hour Fiend: the versus card, then the clock hands sweeping the room
	await _boss(at, w)
	# 11. a relic held aloft (last: the relic changes how Tallow looks)
	at.args.erase("drive")
	await _relic_aloft(at, w)
	Audio.stop_all()
	at.args.erase("drive")


static func _relic_aloft(at: Node, w: Node) -> void:
	# a cleared, candle-lit Belfry room, Tallow in the middle of it with nothing above its head
	var c := _normal(w, 3)
	w.layout["cells"][c]["cleared"] = true
	_clear_foes(w)
	w.hud.set_boss("", false)   # the guardian's bar from the fight before
	at._jump(w, c)
	_clear_foes(w)
	w.player.position = w.room.center() + Vector2(-8, 30)
	w.player.wax = 96.0
	await at._wait(0.4)
	# the fight that just ended: splats round the room, a few drippings
	await _splats(at, w, [["chort", Vector2(-62, -24)], ["clapper_bat", Vector2(52, -36)], ["deathwatch", Vector2(66, 22)],
		["sootling", Vector2(-56, 40)], ["wax_blob", Vector2(30, 8)]])
	await at._wait(1.4)
	_clear_foes(w)   # (the wax bits a blob splits into)
	var id := "both_ends" if Items.RELICS.has("both_ends") else "beeswax"
	w.collect_item(id, w.player.global_position)
	await at._wait(0.4)
	# no banner: at 16:9 its band runs under the wax bar and the minimap (see docs/streams/storeart.md)
	await _snap(at, w, "relic_aloft")


static func _chapel(at: Node, w: Node) -> void:
	# the first ordinary room whose decor hung a pair of stained-glass windows
	var cells: Array = []
	for c in w.layout["cells"].keys():
		if w.layout["cells"][c]["type"] == "normal":
			cells.append(c)
	cells.sort()
	var pick := -1
	for i in cells.size():
		var d: Dictionary = w.layout["cells"][cells[i]]
		d["cleared"] = true
		at._jump(w, cells[i])
		_clear_foes(w)
		await at.get_tree().process_frame
		if _has_window(w.room):
			pick = i
			break
	if pick < 0:
		print("[store] no chapel room with windows on this floor")
		return
	var c0: Vector2 = w.room.center()
	w.room.set_open(false, true)
	w.player.position = c0 + Vector2(-50, 24)
	await at._wait(0.4)
	for s in [["wisp", Vector2(10, -20)], ["psalter", Vector2(-20, 30)]]:
		var e: Enemy = w.spawn_enemy(s[0], c0 + s[1])
		await at.get_tree().process_frame
		e.active = true
		e.take_hit(999.0, Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 60.0)
	await at._wait(0.6)
	for s in [["skelet", Vector2(60, -30)], ["wisp", Vector2(80, 20)], ["chort", Vector2(40, 40)], ["angel", Vector2(-10, -46)], ["wogol", Vector2(96, -10)]]:
		w.spawn_enemy(s[0], c0 + s[1])
	w.room_spawned = true
	w.player.wax = 92.0
	at.args["drive"] = true
	await at._wait(1.3)
	await _snap(at, w, "chapel_light")
	at.args.erase("drive")


static func _lights(n: Node, out: Array) -> Array:
	for ch in n.get_children():
		if ch is PointLight2D:
			out.append(ch)
		_lights(ch, out)
	return out


static func _hide_continue(n: Node) -> void:
	for ch in n.get_children():
		if ch is Label and (ch as Label).text == "Continue" and ch.get_parent() is Button:
			(ch.get_parent() as Button).visible = false
		_hide_continue(ch)


static func _has_window(n: Node) -> bool:
	for ch in n.get_children():
		if ch is Sprite2D and (ch as Sprite2D).texture and "window" in (ch as Sprite2D).texture.resource_path:
			return true
		if _has_window(ch):
			return true
	return false


static func _seance(at: Node, w: Node) -> void:
	var c := Specials._cell_of_type(w, "seance")
	if c == Vector2i(-99, -99):
		c = Specials._make_special(w, "seance")
	if c == Vector2i(-99, -99):
		print("[store] no room for a seance")
		return
	w.layout["cells"][c]["rung"] = false
	at._jump(w, c)
	_clear_foes(w)
	w.player.position = w.room.center() + Vector2(-30, 40)
	w.player.wax = 88.0
	await at._wait(0.8)
	Specials.of(w)._ring()
	at.args["drive"] = true
	await at._wait(2.4)
	await _snap(at, w, "seance")
	at.args.erase("drive")


static func _low_wax(at: Node, w: Node) -> void:
	await _floor(at, w, 4)
	at.args.erase("god")
	await _fight_room(at, w, 2, "long_pews", [
		["clapper_bat", Vector2(-70, -40)], ["deathwatch", Vector2(60, -20)], ["chort", Vector2(70, 30)],
		["clapper_bat", Vector2(30, -50)], ["ice_zombie", Vector2(-90, 30)]], [
		["chort", Vector2(-20, -20)], ["sootling", Vector2(30, 10)]])
	var p: Player = w.player
	p.position = w.room.center() + Vector2(-6, 10)
	p.wax = 15.0
	p.frozen = true   # stands its ground: the lodgers close in
	await at._wait(1.1)
	p.wax = 15.0
	await _snap(at, w, "low_wax")
	p.frozen = false
	p.wax = 100.0


static func _boss(at: Node, w: Node) -> void:
	await _floor(at, w, 4)
	at.args["god"] = true
	w.boss_kind = "big_demon" if Enemy.DEFS.has("big_demon") else w.boss_kind
	_clear_foes(w)
	w.player.wax = 74.0
	at._jump(w, w.layout["boss"])
	await at._wait(0.75)
	await _snap(at, w, "boss_card")
	at.args["drive"] = true
	await at._wait(3.6)
	var b: Enemy = w.boss
	if b and is_instance_valid(b):
		b.hp = b.max_hp * 0.6   # phase 2: the clock hands
		await at._wait(1.3)
		if is_instance_valid(b) and b.alive:
			b.state = "hands"
			b.t = 3.0
			b.set("_spin", 0.0)
			b.set("_wob", 0.1)
			b.set("_hand_base", (w.player.global_position - b.global_position).angle() + PI * 0.5)
	await at._wait(1.2)
	await _snap(at, w, "boss_fight")
	await at._wait(0.5)
	await _snap(at, w, "boss_fight_b")


# ---------------------------------------------------------------- key art

## The cast, around the room centre (room-local pixels; the interior is +-120 x +-72), in two layouts:
## "wide" for the landscape capsules (Tallow centre-left in a strong light, the lodgers come at it from
## the right, the guardian looms at the back in a cold light) and "tall" for the portrait ones (the
## same cast stacked: guardian at the back wall, lodgers between, Tallow in front). --keylayout=tall
const KEY_FLOOR := 2
const KEY_LAYOUTS := {
	"wide": {"tallow": Vector2(-44, 20), "guardian": ["sexton", Vector2(50, -26)],
		"lodgers": [["sootling", Vector2(10, 4)], ["wax_blob", Vector2(26, 38)], ["snuffer", Vector2(-2, 44)], ["wisp", Vector2(40, 2)]],
		# lodgers killed first, so their splats are on the floor
		"stains": [["wax_blob", Vector2(-14, 30)], ["sootling", Vector2(20, 22)], ["tiny_zombie", Vector2(64, 14)], ["cinder_rat", Vector2(48, 30)]]},
	"tall": {"tallow": Vector2(-14, 42), "guardian": ["sexton", Vector2(16, -38)],
		"lodgers": [["sootling", Vector2(10, 10)], ["wax_blob", Vector2(36, 30)], ["snuffer", Vector2(-38, 10)], ["wisp", Vector2(40, -8)]],
		"stains": [["wax_blob", Vector2(-4, 30)], ["sootling", Vector2(20, 22)], ["tiny_zombie", Vector2(-30, -4)], ["cinder_rat", Vector2(44, 12)]]},
}
## framings: name -> [size, centre offset from the room centre]. "full" holds the whole room with a
## margin (tools/store_art.py crops every capsule from it); the others are ready-made shapes.
const FRAMINGS := {
	"full": [Vector2i(320, 240), Vector2(0, 0)],
	"wide": [Vector2i(256, 83), Vector2(0, 8)],
	"standard": [Vector2i(256, 144), Vector2(0, 6)],
	"tall": [Vector2i(200, 240), Vector2(-4, 0)],
}


static func _keyart(at: Node) -> void:
	seed(SEED)   # splats and knock-backs roll the same way every time
	Controls.set_device(Controls.MOUSE)
	var main: Node = at.main
	main.goto("game", {"seed": SEED})
	var w: Node = await _until_game(at)
	await at._wait(0.6)
	await _floor(at, w, int(at.args.get("keyfloor", str(KEY_FLOOR))))
	var lay: Dictionary = KEY_LAYOUTS.get(str(at.args.get("keylayout", "wide")), KEY_LAYOUTS["wide"])
	# the picture is the world only: hide every screen-space layer (HUD, fades, vignettes)
	for ch in w.get_children():
		if ch is CanvasLayer:
			(ch as CanvasLayer).visible = false
	var c := _normal(w, int(at.args.get("keyroom", "3")))
	var d: Dictionary = w.layout["cells"][c]
	var g := _template("open_five")
	if not g.is_empty():
		d["grid"] = g
	d["cleared"] = true
	at._jump(w, c)
	_clear_foes(w)
	for o in w.room.objects.get_children():
		if o is Pickup:
			o.queue_free()
	var p: Player = w.player
	var c0: Vector2 = w.room.center()
	p.frozen = true   # nothing can hurt it while the stage is set (no blinking)
	p.position = c0 + lay["tallow"]
	p.wax = p.wax_max
	await at._wait(0.5)
	for s in lay["stains"]:
		var e: Enemy = w.spawn_enemy(s[0], c0 + s[1])
		await at.get_tree().process_frame
		e.active = true
		e.take_hit(999.0, Vector2(randf_range(-1, 1), randf_range(-0.3, 0.3)) * 40.0)
	await at._wait(2.0)   # gibs settle, the drippings land
	for o in w.room.objects.get_children():
		if o is Pickup:
			o.queue_free()   # no coins or drops lying about: stains only
	_clear_foes(w)   # (and no wax bits split off the blobs)
	Juice.of(w).gibs.clear()   # loose bones and teeth land anywhere: keep the floor to its stains
	w.freeze_t = 9999.0   # the cast holds still (idle animations keep playing, everyone faces Tallow)
	var guard: Enemy = w.spawn_enemy(str(at.args.get("keyguard", lay["guardian"][0])), c0 + lay["guardian"][1])
	for s in lay["lodgers"]:
		w.spawn_enemy(s[0], c0 + s[1])
	p.position = c0 + lay["tallow"]
	p.invuln = 0.0
	# night: the floor's own darkness, deeper and bluer (--keytint=r,g,b to try others)
	var tint: PackedStringArray = str(at.args.get("keytint", "0.13,0.135,0.22")).split(",")
	w.dark.color = Color(float(tint[0]), float(tint[1]), float(tint[2])) if tint.size() == 3 else w.dark.color.darkened(0.6)
	await at._wait(1.4)
	# two flames in flight at the nearest lodger, a muzzle flash at the wick
	var aim: Vector2 = (c0 + lay["lodgers"][0][1] + Vector2(0, -6) - p.global_position).normalized()
	p._fire(aim)
	await at._wait(float(at.args.get("keygap", "0.13")))
	p._fire(aim)
	await at._wait(float(at.args.get("keyhit", "0.04")))
	at.get_tree().paused = true
	# a strong flame: bright, but a pool of light rather than a lit room (set after the pause, so the
	# flicker code does not put it back)
	p.light.energy = float(at.args.get("keyenergy", "1.55"))
	p.light.texture_scale = float(at.args.get("keyradius", "1.0"))
	# Tallow is the brightest thing: every other light in the room burns lower (set after the pause, so
	# no flicker code puts it back)
	var dim := float(at.args.get("keydim", "0.65"))
	for l in _lights(w.room, []):
		(l as PointLight2D).energy *= dim
	# a cold light from above the guardian (moonlight through the ceiling), so it looms out of the dark
	var moon := float(at.args.get("keymoon", "0.6"))
	if moon > 0.0 and guard:
		var ml := PointLight2D.new()
		ml.texture = Art.light_tex
		ml.color = Color(0.55, 0.66, 1.0)
		ml.energy = moon
		ml.texture_scale = float(at.args.get("keymoonr", "0.55"))
		ml.position = guard.position + Vector2(8, -34)
		w.room.objects.add_child(ml)
	if guard:
		print("[keyart] guardian ", guard.kind, " at ", guard.global_position - w.room.position)
	# frame and capture every shape from the same frozen moment
	var win := at.get_window()
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	w.cam.process_mode = Node.PROCESS_MODE_ALWAYS
	w.cam.offset = Vector2.ZERO
	for fname in FRAMINGS:
		var size: Vector2i = FRAMINGS[fname][0]
		win.content_scale_size = size
		w.cam.position = c0 + FRAMINGS[fname][1]
		w.cam.force_update_scroll()
		for i in 3:
			await at.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := at.get_viewport().get_texture().get_image()
		img.save_png("%s/keyart_%s.png" % [at._shots_dir, fname])
		print("[keyart] %s %dx%d" % [fname, img.get_width(), img.get_height()])
	# where things are in keyart_full.png, for tools/store_art.py's crops
	var full: Vector2i = FRAMINGS["full"][0]
	var o: Vector2 = c0 + FRAMINGS["full"][1] - Vector2(full) / 2.0
	var info := {"size": [full.x, full.y], "room": [w.room.position.x - o.x, w.room.position.y - o.y, Room.W, Room.H],
		"tallow": [p.global_position.x - o.x, p.global_position.y - o.y], "lodgers": []}
	if guard:
		info["guardian"] = [guard.global_position.x - o.x, guard.global_position.y - o.y]
	for e in w.enemies:
		if is_instance_valid(e) and e != guard:
			info["lodgers"].append([e.global_position.x - o.x, e.global_position.y - o.y])
	var f := FileAccess.open(at._shots_dir + "/keyart.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "  "))
	f.close()
	at.get_tree().paused = false
