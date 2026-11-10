class_name FullMap
extends Control
## v2.6 (feel): the whole floor as far as Tallow has seen it, opened over the pause menu by tapping or clicking
## the minimap, M / Tab / the pad's Back, or the pause menu's Map. Rooms seen (dark) and walked through
## (lighter), where Tallow stands (cream), the guardian (red), treasure (gold), the shop (teal), a hollow (pink),
## special rooms (their own marks, "?" until known) and an ember dot where loose drops still lie.
## It shows nothing the minimap has not seen: only bigger, all at once.
## v2.8 (pace): a room Tallow has cleared can be tapped or clicked (or picked with the arrows / stick and
## confirmed) and he goes straight there (world.warp_to): walking back through quiet rooms was a fifth of a run.
## Rooms he can go to wear a gold foot; from a room that is not quiet yet none do, and the line under the map says so.

const GAP := 3.0
const SEEN := Color("#483b3a")
const WALKED := Color("#775c55")
const HERE := Color("#fdf7ed")
const INK := Color("#21141b")
const MARKS := {"boss": Color("#da4e38"), "treasure": Color("#facb3e"), "shop": Color("#72d6ce"), "secret": Color("#dc4a7b")}
const DROPS := Color("#ee8e2e")
const LOOSE := ["coin", "bomb", "match", "wax_small", "wax_big"]
const GO := Color("#facb3e")       # a room Tallow can go to: its gold foot, and the frame of the one picked
const MAP_H := 104.0               # the map's tallest (was 112: the hop line needs a row at 216 px)
const TAP_SLACK := 5.0             # a tap this far outside a room still counts as that room (a thumb is not a pixel)

var world: Node
var _cw := 20.0
var _ch := 14.0
var _lo := Vector2i.ZERO
var _pick := Vector2i(-99, -99)    # the room under the cursor (keys, pad, mouse hover)
var _root: Control                 # the modal this map sits in


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
	map._root = root
	v.add_child(map)
	v.add_child(_legend())
	var hop := UI.label(map.hop_line(), 8, GO if map.can_hop() else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hop.name = "HopLine"
	v.add_child(hop)
	var resume := UI.button(L.t("Resume"), func():
		root.queue_free()
		if w.paused:
			w.toggle_pause(), 120)
	resume.set_meta("default_focus", true)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(resume)
	if map.can_hop():   # keys and pad: up from Resume is the map, down from the map is Resume
		map.focus_mode = Control.FOCUS_ALL
		map.mouse_filter = Control.MOUSE_FILTER_STOP
		resume.focus_neighbor_top = resume.get_path_to(map)
		map.focus_neighbor_bottom = map.get_path_to(resume)
		map.focus_entered.connect(map._focus_in)
		map.focus_exited.connect(map._focus_out)
		map.mouse_exited.connect(map._focus_out)
	Audio.play("page_flip", -6.0)
	return root


## Cell size from the seen part of the floor: as big as fits 300 x MAP_H game px (a phone's pause screen).
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
	if n.y * (_ch + GAP) - GAP > MAP_H:
		_ch = maxf(6.0, floorf((MAP_H - GAP * (n.y - 1)) / n.y))
		_cw = maxf(9.0, floorf(_ch / 0.68))
	custom_minimum_size = Vector2(n.x * (_cw + GAP) - GAP + 4.0, n.y * (_ch + GAP) - GAP + 4.0)


func _at(c: Vector2i) -> Vector2:
	return Vector2(2, 2) + Vector2((c.x - _lo.x) * (_cw + GAP), (c.y - _lo.y) * (_ch + GAP))


# ---------------------------------------------------------------- v2.8: hop to a cleared room

## The rooms Tallow can go to right now (none from a room that is not quiet).
func hops() -> Array:
	var out: Array = []
	for c in world.layout["cells"]:
		if world.can_warp(c):
			out.append(c)
	return out


func can_hop() -> bool:
	return not hops().is_empty()


## The line under the legend: how to hop, or why not.
func hop_line() -> String:
	if can_hop():
		match Controls.device:
			Controls.TOUCH: return L.t("Tap a room you have cleared to go there")
			Controls.MOUSE: return L.t("Click a room you have cleared to go there")
			_: return L.t("Up to the map: pick a cleared room to go there")
	if not world.hurry_ok():
		return L.t("Clear this room first: then the map takes you back")
	return L.t("Rooms you clear light up here")


## The room at `p` (this control's own pixels), a little slack around each; (-99, -99) = none.
func room_at(p: Vector2) -> Vector2i:
	var best := Vector2i(-99, -99)
	var best_d := 1e9
	for c in world.layout["cells"]:
		if not world.layout["cells"][c]["seen"]:
			continue
		var r := Rect2(_at(c), Vector2(_cw, _ch)).grow(TAP_SLACK)
		if r.has_point(p):
			var d := p.distance_squared_to(_at(c) + Vector2(_cw, _ch) / 2.0)
			if d < best_d:
				best_d = d
				best = c
	return best


## Go there: the map closes, the house wakes, Tallow hops. False (and a dull click) if he cannot.
func go(c: Vector2i) -> bool:
	if not world.can_warp(c):
		Audio.play("ui_back", -4.0)
		return false
	var w := world
	if is_instance_valid(_root):
		_root.queue_free()
	if w.paused:
		w.toggle_pause()
	return w.warp_to(c)


func _focus_in() -> void:
	if _pick == Vector2i(-99, -99):
		_pick = _nearest_hop(world.cur_cell)
	queue_redraw()


func _focus_out() -> void:
	if not has_focus():
		_pick = Vector2i(-99, -99)
		queue_redraw()


func _nearest_hop(from: Vector2i) -> Vector2i:
	var best := Vector2i(-99, -99)
	var best_d := 1e9
	for c in hops():
		var d := float((c - from).length_squared())
		if d < best_d:
			best_d = d
			best = c
	return best


## The next room to go to from `from` towards `dir` (a 90-degree cone, the nearest first); `from` if there is none.
func _step(from: Vector2i, dir: Vector2i) -> Vector2i:
	var best := from
	var best_d := 1e9
	for c in hops():
		var rel: Vector2i = c - from
		var along := rel.x * dir.x + rel.y * dir.y
		var across := absi(rel.x * dir.y) + absi(rel.y * dir.x)
		if along <= 0 or across > along:
			continue
		var d := float(along) + across * 1.5
		if d < best_d:
			best_d = d
			best = c
	return best


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and not (e as InputEventMouseMotion).button_mask:
		var over := room_at((e as InputEventMouseMotion).position)
		var np := over if world.can_warp(over) else Vector2i(-99, -99)
		if np != _pick and not has_focus():
			_pick = np
			queue_redraw()
		return
	if e is InputEventMouseButton:   # a tap arrives as a click too (emulate_mouse_from_touch)
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var c := room_at(mb.position)
			if c != Vector2i(-99, -99) and c != world.cur_cell:
				accept_event()
				go(c)
		return
	if not has_focus():
		return
	for act in [["ui_left", Vector2i.LEFT], ["ui_right", Vector2i.RIGHT], ["ui_up", Vector2i.UP], ["ui_down", Vector2i.DOWN]]:
		if e.is_action_pressed(act[0], true):
			var nxt := _step(_pick, act[1])
			if nxt != _pick:
				_pick = nxt
				Audio.play("ui_move", -6.0)
				queue_redraw()
				accept_event()
			elif act[1] != Vector2i.DOWN:
				accept_event()   # stay on the map; only "down" past the last room leaves it (to Resume)
			return
	if e.is_action_pressed("ui_accept"):
		accept_event()
		if _pick != Vector2i(-99, -99):
			go(_pick)


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
		if world.can_warp(c):   # v2.8: a room to go to wears a gold foot; the one picked a gold frame
			draw_rect(Rect2(pos + Vector2(1, _ch - 1.0), Vector2(_cw - 2.0, 1)), GO)
			if c == _pick:
				draw_rect(Rect2(pos - Vector2(2, 2), Vector2(_cw + 4, _ch + 4)), GO, false, 1.0)
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
