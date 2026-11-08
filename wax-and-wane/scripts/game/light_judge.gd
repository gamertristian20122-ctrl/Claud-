class_name LightJudge
extends RefCounted
## Outside judge for the light pass (`-- --autotest --lightjudge --shots=/abs/dir`, needs a real renderer):
## writes the images `tools/light_judge.py` measures.
##   panel.png        one flat 0x72 colour lit by Tallow's full-wax light (bands along a ray)
##   room_lit.png     the seed-7 start room, frozen
##   room_albedo.png  the same frame with every light off and no darkness (= the raw palette colours)
##   room_dark.png    the same frame with every light off (= what an unlit pixel must look like)
##   wane_100.png / wane_20.png   one fixed room at full wax and at 20 % wax
##   haze_on.png / haze_off.png   Tallow's flame with and without the heat haze
##   shock_on.png / shock_off.png a bomb shockwave ring mid-flight and the frame without it
## Each run also prints `[judge] key=value` lines (light position, render counters).

const PANEL_COL := Color("#aa8d7a")


static func run(t: Node) -> void:
	var dir: String = t._shots_dir
	DirAccess.make_dir_recursive_absolute(dir)
	var lighting: Script = load("res://scripts/game/lighting.gd") if ResourceLoader.exists("res://scripts/game/lighting.gd") else null
	# ---- B: the start room, frozen
	t.main.goto("game", {"seed": 7})
	await t._wait(2.4)
	var w: Node = t.main.current
	w.hud.visible = false
	t.get_tree().paused = true
	await t._wait(0.2)
	var lp: Vector2 = w.player.light.get_global_transform_with_canvas().origin
	print("[judge] room_light=%d,%d" % [roundi(lp.x), roundi(lp.y)])
	await _save(t, dir, "room_lit")
	var lights: Array = []
	_collect_lights(w, lights)
	for x in lights:
		x.visible = false
	await _save(t, dir, "room_dark")
	var dark_col: Color = w.dark.color
	w.dark.color = Color.WHITE
	await _save(t, dir, "room_albedo")
	w.dark.color = dark_col
	for x in lights:
		x.visible = true
	_render_counters(t, "room_lit")
	# ---- A: a flat panel over the frozen room: one 0x72 colour, the floor's darkness, one light like
	# Tallow's at full wax (no shadows, every other light hidden)
	var cam_tf: Transform2D = w.get_viewport().get_canvas_transform()
	var vis: Vector2 = t.get_viewport().get_visible_rect().size
	var img := Image.create(int(vis.x) + 8, int(vis.y) + 8, false, Image.FORMAT_RGBA8)
	img.fill(PANEL_COL)
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	spr.position = cam_tf.affine_inverse() * Vector2(-4, -4)
	if lighting:
		spr.material = lighting.lit_material()
	w.add_child(spr)
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(1.0, 0.74, 0.44)
	l.energy = 1.15
	l.texture_scale = 1.5
	l.range_z_max = RenderingServer.CANVAS_ITEM_Z_MAX
	var mid: Vector2 = (vis / 2.0).floor()
	l.position = cam_tf.affine_inverse() * mid
	w.add_child(l)
	for x in lights:
		x.visible = false
	await t._wait(0.2)
	print("[judge] panel_light=%d,%d" % [mid.x, mid.y])
	await _save(t, dir, "panel")
	spr.queue_free()
	l.queue_free()
	for x in lights:
		x.visible = true
	await t._wait(0.1)
	# ---- C: the same room at full wax and at 20 % wax
	t.get_tree().paused = false
	w.player.wax = w.player.wax_max
	await t._wait(1.6)
	t.get_tree().paused = true
	await t._wait(0.15)
	await _save(t, dir, "wane_100")
	_render_counters(t, "wane_100")
	t.get_tree().paused = false
	w.player.wax = w.player.wax_max * 0.2
	await t._wait(2.5)
	t.get_tree().paused = true
	await t._wait(0.15)
	await _save(t, dir, "wane_20")
	_render_counters(t, "wane_20")
	t.get_tree().paused = false
	w.player.wax = w.player.wax_max
	await t._wait(1.6)
	# ---- D: heat haze on / off, shockwave on / off (only once the light pass exists)
	if lighting:
		t.get_tree().paused = true
		await t._wait(0.1)
		Game.settings["effects"] = "full"
		Game.settings_changed.emit()
		await t._wait(0.1)
		await _save(t, dir, "haze_on")
		Game.settings["effects"] = "lite"
		Game.settings_changed.emit()
		await t._wait(0.1)
		await _save(t, dir, "haze_off")
		Game.settings["effects"] = "full"
		Game.settings_changed.emit()
		var fp: Vector2 = w.player.flame.get_global_transform_with_canvas().origin
		print("[judge] flame=%d,%d" % [roundi(fp.x), roundi(fp.y)])
		var at: Vector2 = w.room.center() + Vector2(-60, 10)
		var sp: Vector2 = w.get_viewport().get_canvas_transform() * at
		print("[judge] shock=%d,%d" % [roundi(sp.x), roundi(sp.y)])
		await _save(t, dir, "shock_off")
		var ring: Node = lighting.shockwave(w, at, 34.0, 2.0)
		ring.set("t", 0.45)   # hold it mid-flight
		ring.process_mode = Node.PROCESS_MODE_DISABLED
		ring.call("_apply")
		await t._wait(0.1)
		await _save(t, dir, "shock_on")
		_render_counters(t, "shock_on")
		ring.queue_free()
		t.get_tree().paused = false
	print("[judge] done")


static func _save(t: Node, dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := t.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, name])
	print("[judge] shot ", name, " ", img.get_size())


static func _collect_lights(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Light2D and c.visible:
			out.append(c)
		_collect_lights(c, out)


static func _render_counters(t: Node, label: String) -> void:
	var vp: Viewport = t.get_viewport()
	var dc := vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var ob := vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
	print("[judge] %s canvas_draw_calls=%d canvas_objects=%d total_draw_calls=%d" % [label, dc, ob,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
