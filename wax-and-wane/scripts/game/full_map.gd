class_name FullMap
extends Control
## v2.6 (feel): the whole floor as far as Tallow has seen it, opened over the pause menu by tapping or clicking
## the minimap, M / Tab / the pad's Back, or the pause menu's Map. Rooms seen (dark) and walked through
## (lighter), where Tallow stands (cream), the guardian (red), treasure (gold), the shop (teal), a hollow (pink),
## special rooms (their own marks, "?" until known) and an ember dot where loose drops still lie.
## It shows nothing the minimap has not seen: only bigger, all at once.

const GAP := 3.0
const SEEN := Color("#483b3a")
const WALKED := Color("#775c55")
const HERE := Color("#fdf7ed")
const INK := Color("#21141b")
const MARKS := {"boss": Color("#da4e38"), "treasure": Color("#facb3e"), "shop": Color("#72d6ce"), "secret": Color("#dc4a7b")}
const DROPS := Color("#ee8e2e")
const LOOSE := ["coin", "bomb", "match", "wax_small", "wax_big"]

var world: Node
var _cw := 20.0
var _ch := 14.0
var _lo := Vector2i.ZERO


## The map's modal on the HUD (the world is paused by the caller). Returns its root.
static func open(w: Node) -> Control:
	var m := UI.modal(w.hud.root, str(w.floor_title()).split("\n")[0].to_upper())
	var root: Control = m[0]
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	var map := FullMap.new()
	map.world = w
	map.fit()
	map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(map)
	v.add_child(_legend())
	var resume := UI.button(L.t("Resume"), func():
		root.queue_free()
		if w.paused:
			w.toggle_pause(), 120)
	resume.set_meta("default_focus", true)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(resume)
	Audio.play("page_flip", -6.0)
	return root


## Cell size from the seen part of the floor: as big as fits 300 x 112 game px (a phone's pause screen).
func fit() -> void:
	var cells: Dictionary = world.layout["cells"]
	var lo := Vector2i(999, 999)
	var hi := Vector2i(-999, -999)
	for c in cells:
		if cells[c]["seen"]:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	if hi.x < lo.x:
		lo = world.cur_cell
		hi = world.cur_cell
	_lo = lo
	var n := hi - lo + Vector2i.ONE
	_cw = clampf(floorf((300.0 - GAP * (n.x - 1)) / n.x), 9.0, 22.0)
	_ch = clampf(floorf(_cw * 0.68), 6.0, 15.0)
	if n.y * (_ch + GAP) - GAP > 112.0:
		_ch = maxf(6.0, floorf((112.0 - GAP * (n.y - 1)) / n.y))
		_cw = maxf(9.0, floorf(_ch / 0.68))
	custom_minimum_size = Vector2(n.x * (_cw + GAP) - GAP + 4.0, n.y * (_ch + GAP) - GAP + 4.0)


func _at(c: Vector2i) -> Vector2:
	return Vector2(2, 2) + Vector2((c.x - _lo.x) * (_cw + GAP), (c.y - _lo.y) * (_ch + GAP))


func _draw() -> void:
	var cells: Dictionary = world.layout["cells"]
	# doorways between seen rooms (every two rooms side by side share a door), under the rooms
	for c in cells:
		if not cells[c]["seen"]:
			continue
		var pos := _at(c)
		for dd in [Vector2i.RIGHT, Vector2i.DOWN]:
			var nb: Vector2i = c + dd
			if not cells.has(nb) or not cells[nb]["seen"]:
				continue
			var col := WALKED if cells[c]["visited"] or cells[nb]["visited"] else SEEN
			if dd == Vector2i.RIGHT:
				draw_rect(Rect2(pos + Vector2(_cw, floorf(_ch / 2.0) - 1.0), Vector2(GAP, 3)), col)
			else:
				draw_rect(Rect2(pos + Vector2(floorf(_cw / 2.0) - 1.0, _ch), Vector2(3, GAP)), col)
	for c in cells:
		var d: Dictionary = cells[c]
		if not d["seen"]:
			continue
		var pos := _at(c)
		var col := WALKED if d["visited"] else SEEN
		if c == world.cur_cell:
			col = HERE
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(_cw + 2, _ch + 2)), INK)
		draw_rect(Rect2(pos, Vector2(_cw, _ch)), col)
		var t: String = d["type"]
		if MARKS.has(t):
			draw_rect(Rect2(pos + Vector2(floorf(_cw / 2.0) - 2.0, floorf(_ch / 2.0) - 2.0), Vector2(4, 4)), MARKS[t])
		Specials.draw_map_mark(self, world, d, pos + Vector2(floorf((_cw - 9.0) / 2.0), floorf((_ch - 6.0) / 2.0)))
		if d["visited"] and c != world.cur_cell and _drops_left(d):
			draw_rect(Rect2(pos + Vector2(_cw - 4.0, _ch - 4.0), Vector2(2, 2)), DROPS)
	# Tallow: a little flame in the room it stands in (a marked room keeps its mark)
	var me := _at(world.cur_cell) + Vector2(floorf(_cw / 2.0), floorf(_ch / 2.0))
	var here := str(cells[world.cur_cell]["type"])
	if not MARKS.has(here) and not here in Specials.TYPES:
		draw_rect(Rect2(me + Vector2(-1, -2), Vector2(2, 4)), Color("#ee8e2e"))
		draw_rect(Rect2(me + Vector2(-1, -1), Vector2(2, 2)), Color("#facb3e"))


static func _drops_left(d: Dictionary) -> bool:
	for rec in d.get("pickups", []):
		if str(rec.get("kind", "")) in LOOSE and int(rec.get("price", 0)) == 0 and int(rec.get("cost_wax", 0)) == 0:
			return true
	return false


static func _legend() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 3)
	for it in [[HERE, L.t("You")], [MARKS["boss"], L.t("Guardian")], [MARKS["treasure"], L.t("Treasure")],
			[MARKS["shop"], L.t("Shop")], [MARKS["secret"], L.t("Hollow")], [DROPS, L.t("Drops left")]]:
		var sw := ColorRect.new()
		sw.color = it[0]
		sw.custom_minimum_size = Vector2(4, 4)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var l := UI.label(it[1], 8, UI.DIM)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(4, 0)
		row.add_child(gap)
	var last := row.get_child(row.get_child_count() - 1)   # no gap after the last one
	row.remove_child(last)
	last.free()
	return row
