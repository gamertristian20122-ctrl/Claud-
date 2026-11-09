class_name ShotJudge
extends RefCounted
## v2.1 "shots" judge images: every enemy shot, held still, on every floor theme and in the Clock Tower,
## at 100 % and 20 % wax (the waning house), in the lit middle of a room and in a shadowed corner, plus
## a telegraph line and ring. Measured by tools/shot_judge.py. Never used in play.
##   xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 \
##       -- --autotest --tour --shotjudge --shots=DIR [--set=look|hit]
## Each layout is shot four times with the game paused: A0 / A1 (both pulse frames), T (shots hidden,
## telegraphs shown) and B (both hidden), so the diffs give each shot's and each mark's own pixels.
## `judge.json` lists every shot's centre on the screen per layout. Runs once per "Enemy shots" size
## (Normal, Large) when the game has that setting.
## --set=hit: shots fired at a still Tallow from 60 px at three speeds, Normal and Large: the frame and
## the distance at which each one touches him (the hitbox and the speed, which must not change).
## --set=look: fast shots with their trails and the telegraphs, to look at.

const KINDS := ["bullet_purple", "bullet_green", "bullet_water", "bolt_wax", "bolt_bone", "bolt_cog", "bolt_page", "bolt_ring"]
## room-local spots: a row across the lit floor above Tallow, a 4 x 2 block in the top-right corner
## (behind an occluder bar, in his hard shadow)
const LIT_Y := 84.0
const CORNER := Vector2(181, 46)


static func run(bot: Node) -> void:
	var dir: String = bot._shots_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var which := str(bot.args.get("set", "all"))
	bot.main.goto("game", {"seed": 5})
	await bot._wait(1.5)
	var w: Node = bot.main.current
	if which == "hit":
		await _hit(bot, w)
		bot.get_tree().quit()
		return
	var sizes: Array = ["normal", "large"] if Game.settings.has("shot_size") else ["2.0"]
	var out := {"layouts": [], "sizes": sizes}
	for n in [1, 2, 3, 4, 5]:
		w._start_floor(n)
		await bot._wait(3.0)   # the floor banner clears
		var cells: Array = bot._normal_cells(w)
		var c: Vector2i = cells[0]
		w.layout["cells"][c]["cleared"] = true
		w.layout["cells"][c]["grid"] = ArtJudge._open_grid(w.layout["cells"][c]["grid"])   # no pits, no obstacles
		bot._jump(w, c)
		await bot._wait(0.5)
		ArtJudge._clear(w)
		w.player.frozen = true
		w.freeze_t = 9999.0
		w.player.position = w.room.center() + Vector2(0, 22)
		var occ := _occluder(w)
		if which == "look":
			await _look(bot, w, n)
			occ.queue_free()
			continue
		for size in sizes:
			if size != "2.0":
				Game.settings["shot_size"] = size
			for wax in [1.0, 0.2]:
				out["layouts"].append(await _layout(bot, w, n, wax, str(size)))
		occ.queue_free()
	if which != "look":
		var f := FileAccess.open(dir + "/judge.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
		print("[shotjudge] done: ", out["layouts"].size(), " layouts")
	if Game.settings.has("shot_size"):
		Game.settings["shot_size"] = "normal"
	bot.get_tree().quit()


## A bar between Tallow's flame and the top-right corner: the corner block sits in his hard shadow.
static func _occluder(w: Node) -> LightOccluder2D:
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var o: Vector2 = w.room.position
	poly.polygon = PackedVector2Array([o + Vector2(168, 70), o + Vector2(256, 70), o + Vector2(256, 76), o + Vector2(168, 76)])
	occ.occluder = poly
	w.room.add_child(occ)
	occ.global_position = Vector2.ZERO
	return occ


static func _spots(w: Node) -> Array:
	var o: Vector2 = w.room.position
	var out := []
	for i in KINDS.size():
		out.append(["lit", KINDS[i], o + Vector2(66 + 20 * i, LIT_Y)])
	for i in KINDS.size():
		out.append(["corner", KINDS[i], o + CORNER + Vector2(18 * (i % 4), 18 * (i / 4))])
	return out


static func _shot(w: Node, kind: String, at: Vector2, v: Vector2) -> Shot:
	var s := Shot.new()
	s.setup(w, at, v, kind, false)
	s.life = 999.0
	w.fx_layer.add_child(s)
	return s


static func _tele(w: Node) -> Telegraph:
	var t := Telegraph.new()
	w.actors.add_child(t)
	var o: Vector2 = w.room.position
	t.line(o + Vector2(40, 124), o + Vector2(118, 124), 999.0, Color("#da4e38"))    # across the bright floor
	t.ring(o + Vector2(60, 150), 16.0, 999.0, Color("#f78697"))                     # where a hand bursts up
	t.line(o + Vector2(252, 40), o + Vector2(252, 110), 999.0, Color("#cae6f5"))   # down the shadowed wall
	return t


static func _layout(bot: Node, w: Node, n: int, wax: float, size: String) -> Dictionary:
	w.player.wax = w.player.wax_max * wax
	var shots: Array = []
	var recs: Array = []
	for sp in _spots(w):
		# slow (no trail) and pointing at Tallow, as they would be in play
		var to_p: Vector2 = (w.player.global_position + Vector2(0, -8) - sp[2]).normalized()
		shots.append(_shot(w, sp[1], sp[2], to_p * 60.0))
	var tele := _tele(w)
	await bot._wait(2.8)   # the waning caught up with the wax
	w.player.wax = w.player.wax_max * wax
	var tree: SceneTree = bot.get_tree()
	tree.paused = true
	tele.set("_t", 0.05)   # a lit phase of the blink
	tele.queue_redraw()
	var tag := "f%d_%s_%d" % [n, size, int(wax * 100)]
	var files := {}
	for fr in [0, 1]:
		for s in shots:
			(s as Shot).spr.frame = fr
			(s as Shot).queue_redraw()
		await tree.process_frame
		await tree.process_frame
		await bot._shot("%s_A%d" % [tag, fr])
		files["a%d" % fr] = "%02d_%s_A%d.png" % [bot._shot_i, tag, fr]
	for s in shots:
		(s as Node2D).visible = false
	await tree.process_frame
	await bot._shot(tag + "_T")
	files["t"] = "%02d_%s_T.png" % [bot._shot_i, tag]
	tele.visible = false
	await tree.process_frame
	await bot._shot(tag + "_B")
	files["b"] = "%02d_%s_B.png" % [bot._shot_i, tag]
	var sp_list := _spots(w)
	for i in shots.size():
		var s: Shot = shots[i]
		var p: Vector2 = s.get_global_transform_with_canvas().origin
		recs.append({"kind": sp_list[i][1], "place": sp_list[i][0], "x": p.x, "y": p.y})
	var o: Vector2 = w.room.get_global_transform_with_canvas().origin
	var lit := {"floor": n, "wax": wax, "size": size, "tag": tag, "files": files, "shots": recs,
		"room": [o.x, o.y], "player": [w.player.get_global_transform_with_canvas().origin.x, w.player.get_global_transform_with_canvas().origin.y],
		"wane": _wane(w)}
	tree.paused = false
	for s in shots:
		s.queue_free()
	tele.queue_free()
	await tree.process_frame
	return lit


static func _wane(w: Node) -> float:
	for c in w.get_children():
		if c is Lighting:
			return (c as Lighting).wane_level()
	return -1.0


## --set=look: on each floor, a fan of fast shots (with trails if the build draws them) and the telegraphs.
static func _look(bot: Node, w: Node, n: int) -> void:
	var sizes: Array = ["normal", "large"] if Game.settings.has("shot_size") else ["2.0"]
	for size in sizes:
		if size != "2.0":
			Game.settings["shot_size"] = size
		var shots: Array = []
		var c: Vector2 = w.player.global_position + Vector2(0, -8)
		for i in KINDS.size():
			var a := -PI * 0.9 + PI * 0.8 * i / (KINDS.size() - 1)
			var at := c + Vector2.from_angle(a) * 46.0
			shots.append(_shot(w, KINDS[i], at, -Vector2.from_angle(a) * (96.0 if i % 2 == 0 else 60.0)))
		var tele := _tele(w)
		await bot._wait(0.4)
		var tree: SceneTree = bot.get_tree()
		tree.paused = true
		tele.set("_t", 0.05)
		tele.queue_redraw()
		for s in shots:
			(s as Shot).queue_redraw()
		await tree.process_frame
		await bot._shot("look_f%d_%s" % [n, size])
		tree.paused = false
		for s in shots:
			s.queue_free()
		tele.queue_free()


## --set=hit: the frame and distance at which a shot touches a still Tallow (Normal and Large).
static func _hit(bot: Node, w: Node) -> void:
	w._start_floor(1)
	await bot._wait(3.0)
	var c: Vector2i = bot._normal_cells(w)[0]
	w.layout["cells"][c]["cleared"] = true
	w.layout["cells"][c]["grid"] = ArtJudge._open_grid(w.layout["cells"][c]["grid"])
	bot._jump(w, c)
	await bot._wait(0.5)
	ArtJudge._clear(w)
	w.freeze_t = 0.0
	w.player.frozen = true   # still, and a touch does no harm (the shot still ends on him)
	w.player.position = w.room.center() + Vector2(0, 22)
	Engine.time_scale = 1.0
	var sizes: Array = ["normal", "large"] if Game.settings.has("shot_size") else ["2.0"]
	for size in sizes:
		if size != "2.0":
			Game.settings["shot_size"] = size
		var line := []
		for spd in [52.0, 80.0, 108.0]:
			for k in [0, 3, 5]:
				var hp: Vector2 = w.player.global_position + Vector2(0, -8)
				var d := Vector2.from_angle(-PI / 2 + k * 0.5)
				var s := _shot(w, KINDS[k], hp + d * 60.0, -d * spd)
				var st := {"f": -1, "pos": Vector2.ZERO}
				var f0 := Engine.get_physics_frames()
				s.tree_exiting.connect(func():
					st["f"] = Engine.get_physics_frames() - f0
					st["pos"] = s.global_position)
				while st["f"] < 0 and Engine.get_physics_frames() - f0 < 600:
					await bot.get_tree().physics_frame
				var dist: float = (st["pos"] as Vector2).distance_to(w.player.global_position + Vector2(0, -8))
				line.append("%s@%d:%df/%.2fpx" % [KINDS[k], int(spd), st["f"], dist])
				await bot._wait(0.1)
		print("[shotjudge] hit %s %s" % [size, " ".join(line)])
	if Game.settings.has("shot_size"):
		Game.settings["shot_size"] = "normal"
