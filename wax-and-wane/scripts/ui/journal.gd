class_name Journal
extends Control
## The Journal: everything the house has shown you. Opened from the title and from the pause menu.
## Six tabs: Relics (relics, keepsakes, gifts), Lodgers, Guardians, Rooms (special rooms and their
## champions), Candles and Records (totals, Tonight's Candle, the last 20 runs).
##
## A paged grid on the left, the selected entry on the right. Unseen entries are dark silhouettes
## named "???"; new ones carry a small gold dot until you look at them.
## Touch: tap a tab or an entry, swipe the grid to turn the page. Keys / pad: arrows move, LB / RB
## (Q / E) switch tabs, left / right past the edge of the grid turns the page, B / Esc goes back.
## Data: Game.records via Records (scripts/game/records.gd) and Unlocks (scripts/game/unlocks.gd).

const TABS := ["relics", "lodgers", "guardians", "rooms", "candles", "records"]
const TAB_NAMES := ["Relics", "Lodgers", "Guardians", "Rooms", "Candles", "Records"]
## cols, rows, slot size (the left panel's inside is 158 x 142)
const LAYOUT := {
	"relics": [8, 7, Vector2(18, 18)],
	"lodgers": [7, 5, Vector2(20, 26)],
	"guardians": [3, 3, Vector2(50, 46)],
	"rooms": [4, 3, Vector2(37, 46)],
	"candles": [5, 1, Vector2(30, 64)],
	"records": [1, 7, Vector2(158, 18)],
}
const SOCKET := Color("#21141b")
const SIL := Color("#483b3a")
const LOCK := Color("#775c55")
const POOL_NAMES := {"treasure": "treasure rooms", "shop": "the shop", "boss": "guardians", "altar": "the Smoke Altar",
	"hollow": "hollows"}
const PROPS := {"seance": "specials/bell_f0", "mirror": "specials/mirror_f0", "musicbox": "specials/musicbox_f0",
	"study": "specials/lectern_f0", "font": "specials/font_6"}
const TIER_NAMES := ["Trinket", "Common", "Fine", "Rare", "Treasure"]

static var _sil_cache := {}

var tab := 0
var page := 0
var entries: Array = []        # the current tab's entries: {key, kind, id, known, new_key}
var sel := 0                   # selected entry (index into entries)
var _tab_btns: Array[Button] = []
var _glyph_l: Label
var _glyph_r: Label
var _left: PanelContainer
var _grid: GridContainer
var _gbox: VBoxContainer
var _detail: VBoxContainer
var _page_lbl: Label
var _count_lbl: Label
var _prev: Button
var _next: Button
var _slots: Array = []
var _anim: TextureRect
var _anim_sf: SpriteFrames
var _anim_name := ""
var _anim_t := 0.0
var _press_at := Vector2.INF


static func open(parent: Control, start_tab := 0) -> Journal:
	Unlocks.take_new()   # anything that moved in since the last look gets its dot
	var j := Journal.new()
	j.tab = start_tab
	parent.add_child(j)
	return j


func _ready() -> void:
	set_meta("modal", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.027, 0.035)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 3 if side in ["top", "bottom"] else 4)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	m.add_child(v)
	# ---- tabs
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 2)
	v.add_child(tabs)
	_glyph_l = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_glyph_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(_glyph_l)
	for i in TABS.size():
		var b := UI.button(TAB_NAMES[i], func(): _set_tab(i, true), 0)
		b.add_theme_stylebox_override("normal", _tab_box(false))
		b.add_theme_stylebox_override("hover", _tab_box(false))
		b.add_theme_stylebox_override("pressed", _tab_box(true))
		b.draw.connect(_draw_tab_dot.bind(b, i))
		tabs.add_child(b)
		_tab_btns.append(b)
	_glyph_r = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_glyph_r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tabs.add_child(_glyph_r)
	# ---- the grid and the entry
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	v.add_child(body)
	_left = UI.panel(Vector2(178, 0))
	body.add_child(_left)
	_gbox = VBoxContainer.new()
	_left.add_child(_gbox)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gbox.add_child(_grid)
	var right := UI.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.clip_contents = true
	body.add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 2)
	right.add_child(_detail)
	# ---- pages, counts, back
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	v.add_child(bottom)
	_prev = UI.button("<", func(): _turn(-1), 22)
	bottom.add_child(_prev)
	_page_lbl = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_page_lbl.custom_minimum_size = Vector2(30, 0)
	_page_lbl.size_flags_vertical = Control.SIZE_FILL
	_page_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_page_lbl)
	_next = UI.button(">", func(): _turn(1), 22)
	bottom.add_child(_next)
	_count_lbl = UI.label("", 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_lbl.size_flags_vertical = Control.SIZE_FILL
	_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_count_lbl)
	bottom.add_child(UI.button("Back", close, 70))
	Controls.on_modal_opened(self)   # keyboard / gamepad focus comes in, and goes back on close
	Controls.set_page_handler(self, func(d: int): _set_tab((tab + d + TABS.size()) % TABS.size(), true))
	Controls.device_changed.connect(_on_device)
	tree_exiting.connect(Game.save)
	tree_exiting.connect(func():   # silhouettes are cheap to redraw; nothing is held after the Journal closes
		_sil_cache.clear()
		_face_cache.clear())
	_on_device(Controls.device)
	Audio.play("page_flip")
	_set_tab(tab, false)


func close() -> void:
	Audio.play("ui_back")
	queue_free()


static func _tab_box(on: bool) -> StyleBox:
	var sb: StyleBox = UI._box("ui/button_9_pressed" if on else "ui/button_9", 6, Color(0.2, 0.14, 0.14, 1))
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	return sb


func _on_device(_d: String) -> void:
	var pad := Controls.device == Controls.PAD
	_glyph_l.text = ("LB" if pad else "Q") if Controls.uses_buttons() else ""
	_glyph_r.text = ("RB" if pad else "E") if Controls.uses_buttons() else ""


# ---------------------------------------------------------------- tabs and pages

func _set_tab(i: int, sound: bool) -> void:
	tab = i
	page = 0
	sel = 0
	if sound:
		Audio.play("page_flip", -4.0)
	for k in _tab_btns.size():
		var on := k == tab
		_tab_btns[k].add_theme_color_override("font_color", UI.GOLD if on else UI.DIM)
		_tab_btns[k].add_theme_stylebox_override("normal", _tab_box(on))
		_tab_btns[k].add_theme_stylebox_override("hover", _tab_box(on))
		_tab_btns[k].queue_redraw()
	entries = _entries(TABS[tab])
	_fill(true)


func _per_page() -> int:
	var L: Array = LAYOUT[TABS[tab]]
	return int(L[0]) * int(L[1])


func _pages() -> int:
	return maxi(1, ceili(entries.size() / float(_per_page())))


func _turn(d: int) -> void:
	var n := _pages()
	if n <= 1:
		return
	page = (page + d + n) % n
	Audio.play("page_flip", -6.0)
	sel = page * _per_page()
	_fill(Controls.uses_buttons())


func _fill(grab: bool) -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_slots.clear()
	var t: String = TABS[tab]
	var L: Array = LAYOUT[t]
	_grid.columns = int(L[0])
	# short shelves (candles, guardians) sit in the middle of the panel; the rest read from the top
	_gbox.alignment = BoxContainer.ALIGNMENT_CENTER if t in ["candles", "guardians"] else BoxContainer.ALIGNMENT_BEGIN
	var from := page * _per_page()
	for i in range(from, mini(entries.size(), from + _per_page())):
		var s := JSlot.new()
		s.j = self
		s.idx = i
		s.e = entries[i]
		s.custom_minimum_size = L[2]
		_grid.add_child(s)
		_slots.append(s)
	# the same minimum size as the last tab sends no change signal: re-sort the column by hand
	_grid.update_minimum_size()
	_gbox.queue_sort.call_deferred()
	_page_lbl.text = "%d / %d" % [page + 1, _pages()]
	_prev.disabled = _pages() <= 1
	_next.disabled = _pages() <= 1
	_prev.modulate.a = 0.35 if _pages() <= 1 else 1.0
	_next.modulate.a = 0.35 if _pages() <= 1 else 1.0
	_count_lbl.text = _counts(t)
	sel = clampi(sel, from, maxi(from, mini(entries.size(), from + _per_page()) - 1))
	_select(sel, false)
	var k := sel - from
	if k >= 0 and k < _slots.size():
		(_slots[k] as Control).set_meta("default_focus", true)   # Controls.focus_first lands here, not on a tab
	if grab and k >= 0 and k < _slots.size():
		(_slots[k] as Control).grab_focus(not Controls.uses_buttons())


func _select(i: int, sound := true) -> void:
	if i < 0 or i >= entries.size():
		_show_detail({})
		return
	var changed := i != sel
	sel = i
	for s in _slots:
		s.queue_redraw()
	var e: Dictionary = entries[i]
	_show_detail(e)
	if e.get("new_key", "") != "" and Records.is_new(e["new_key"]):
		Records.clear_new(e["new_key"])
		for b in _tab_btns:
			b.queue_redraw()
	if sound and changed:
		Audio.play("ui_move", -6.0)


func _draw_tab_dot(b: Button, i: int) -> void:
	var pre: Array = {"relics": ["r:"], "lodgers": ["l:"], "guardians": ["g:"], "rooms": ["s:", "m:"], "candles": ["c:"], "records": []}[TABS[i]]
	for p in pre:
		if Records.any_new(p):
			_dot(b, Vector2(b.size.x - 7, 5))
			return


static func _dot(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 3)), UI.GOLD)
	ci.draw_rect(Rect2(at + Vector2(0, 1), Vector2(3, 1)), UI.GOLD)
	ci.draw_rect(Rect2(at + Vector2(1, 1), Vector2(1, 1)), UI.CREAM)


# ---------------------------------------------------------------- input: swipes, edge paging

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pos := Vector2.INF
	var pressed := false
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		pressed = event.pressed
	if pos != Vector2.INF:
		var lp := pos
		if pressed:
			_press_at = lp if _left.get_global_rect().has_point(lp) else Vector2.INF
		elif _press_at != Vector2.INF:
			var d := lp - _press_at
			_press_at = Vector2.INF
			if absf(d.x) > 26.0 and absf(d.x) > absf(d.y) * 1.5:
				_turn(-1 if d.x > 0 else 1)
		return
	# keys / pad: left / right past the edge of the grid turns the page
	var right := event.is_action_pressed("ui_right")
	var left := event.is_action_pressed("ui_left")
	if (right or left) and _pages() > 1:
		var f := get_viewport().gui_get_focus_owner()
		if f is JSlot and f.j == self:
			var cols := int(LAYOUT[TABS[tab]][0])
			var k: int = f.idx - page * _per_page()
			var on_page := mini(entries.size() - page * _per_page(), _per_page())
			if (right and (k % cols == cols - 1 or k == on_page - 1)) or (left and k % cols == 0):
				var row := k / cols
				_turn(1 if right else -1)
				var count := mini(entries.size() - page * _per_page(), _per_page())
				var nk := clampi(row * cols + (0 if right else cols - 1), 0, count - 1)
				_select(page * _per_page() + nk, false)
				if nk < _slots.size():
					(_slots[nk] as Control).grab_focus()
				get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if _anim and is_instance_valid(_anim) and _anim_sf and _anim_sf.has_animation(_anim_name):
		_anim_t += dt
		var n := _anim_sf.get_frame_count(_anim_name)
		if n > 0:
			var fi := int(_anim_t * _anim_sf.get_animation_speed(_anim_name)) % n
			var tx := _anim_sf.get_frame_texture(_anim_name, fi)
			if _anim.texture != tx:
				_anim.texture = tx


# ---------------------------------------------------------------- the entries of each tab

func _entries(t: String) -> Array:
	var out: Array = []
	match t:
		"relics":
			for id in Items.RELICS:
				out.append({"kind": "relic", "id": id, "known": Records.seen(id), "new_key": "r:" + id})
			for id in Items.KEEPSAKES:
				out.append({"kind": "keepsake", "id": id, "known": Records.seen(id), "new_key": "r:" + id})
			for id in Items.GIFTS:
				out.append({"kind": "gift", "id": id, "known": Records.seen(id), "new_key": "r:" + id})
		"lodgers":
			for k in BestiaryGallery.regulars():
				out.append({"kind": "lodger", "id": k, "known": Records.met(k), "new_key": "l:" + k})
		"guardians":
			for k in BestiaryGallery.boss_kinds():
				out.append({"kind": "guardian", "id": k, "known": Records.met(k) or not Records.boss_record(k).is_empty(), "new_key": "g:" + k})
		"rooms":
			for rt in Specials.TYPES:
				out.append({"kind": "room", "id": rt, "known": Records.room_found(rt), "new_key": "s:" + rt})
			for mk in Specials.MINIS:
				out.append({"kind": "mini", "id": mk, "known": Records.met("mini:" + mk) or Records.mini_beaten(mk), "new_key": "m:" + mk})
		"candles":
			for c in Candles.ORDER:
				out.append({"kind": "candle", "id": c, "known": Candles.is_unlocked(c), "new_key": "c:" + c})
		"records":
			out.append({"kind": "howto", "id": "", "known": true})   # UX-07: the intro's rules, any time
			out.append({"kind": "totals", "id": "", "known": true})
			out.append({"kind": "nights", "id": "", "known": true})
			var hist: Array = Game.records.get("run_history", [])
			for h in hist:
				out.append({"kind": "run", "id": "", "known": true, "run": h})
	return out


func _counts(t: String) -> String:
	var known := 0
	for e in entries:
		if e["known"]:
			known += 1
	match t:
		"relics":
			var taken := 0
			for id in Game.records.get("taken_relics", {}):
				taken += 1
			return "Seen %d / %d   Taken %d" % [known, entries.size(), taken]
		"lodgers":
			var k := 0
			for c in Game.records.get("kills_by_kind", {}).values():
				k += int(c)
			return "Met %d / %d   Snuffed %s" % [known, entries.size(), _num(k)]
		"guardians":
			return "Met %d / %d   Beaten %d" % [known, entries.size(), (Game.records.get("bosses_beaten", {}) as Dictionary).size()]
		"rooms":
			var rooms := 0
			for rt in Specials.TYPES:
				if Records.room_found(rt):
					rooms += 1
			return "Rooms %d / %d   Champions snuffed %d / %d" % [rooms, Specials.TYPES.size(), (Game.records.get("minis_beaten", []) as Array).size(), Specials.MINIS.size()]
		"candles":
			return "In the Candle Box: %d / %d" % [known, entries.size()]
		"records":
			return "Runs %d   Wins %d" % [int(Game.records.get("runs", 0)), int(Game.records.get("wins", 0))]
	return ""


static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


static func _mmss(secs: float) -> String:
	var s := int(secs)
	return "%d:%02d" % [s / 60, s % 60]


## The small picture of an entry (grid slot): [texture, silhouette?]
func icon_of(e: Dictionary) -> Texture2D:
	var tex: Texture2D = null
	match e["kind"]:
		"relic", "keepsake", "gift":
			tex = Art.tex(Items.icon(e["id"]))
		"lodger", "guardian":
			tex = Records.portrait(e["id"])
		"room":
			tex = Art.tex(PROPS[e["id"]]) if Art.has(PROPS[e["id"]]) else null
		"mini":
			var p := "specials/mini_%s_idle_f0" % e["id"]
			tex = Art.tex(p) if Art.has(p) else Records.portrait(e["id"])
		"run":
			var r: Dictionary = e["run"]
			tex = Art.tex("ui/icon_medal") if r.get("won", false) else Records.killer_icon(str(r.get("killer", "")), false)
		"howto":
			tex = Art.tex("hero/hero_preview")
		"totals":
			tex = Art.tex("ui/icon_medal")
		"nights":
			tex = Art.tex("items/hourglass") if Art.has("items/hourglass") else null
	if tex and not e["known"]:
		return silhouette(tex)
	return tex


## The 16x16 part of a big portrait that shows the face: centred on the figure, from its top row.
static var _face_cache := {}


static func face_region(tex: Texture2D) -> Rect2:
	if _face_cache.has(tex):
		return _face_cache[tex]
	var r := Rect2(floorf((tex.get_width() - 16.0) / 2.0), 0, 16, 16)
	var img := tex.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		if used.size.x > 0:
			r = Rect2(floorf(used.position.x + (used.size.x - 16.0) / 2.0), used.position.y, 16, 16)
	_face_cache[tex] = r
	return r


## A flat dark shape of a picture (unseen entries).
static func silhouette(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _sil_cache.has(tex):
		return _sil_cache[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, SIL)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_sil_cache[tex] = out
	return out


# ---------------------------------------------------------------- the entry on the right

func _clear_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	_anim = null
	_anim_sf = null


## Picture box + name + sub-lines across the top of the entry.
func _head(pic: Control, title: String, subs: Array, title_col := UI.GOLD) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_detail.add_child(row)
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(52, 50)
	row.add_child(box)
	if pic:
		box.add_child(pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var nm := UI.label(title, 16, title_col)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(110, 0)
	col.add_child(nm)
	for s in subs:
		if s is Control:
			col.add_child(s)
		else:
			var l := UI.label(str(s[0]), 8, s[1])
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(110, 0)
			col.add_child(l)


func _text(s: String, col := UI.CREAM) -> Label:
	var l := UI.label(s, 8, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(150, 0)
	_detail.add_child(l)
	return l


func _pic(tex: Texture2D, k := 1, tint := Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tex:
		tr.custom_minimum_size = tex.get_size() * k
	tr.modulate = tint
	return tr


## An animated portrait (idle loop) at 2x for small creatures.
func _creature_pic(kind: String, known: bool, sprite_override := "") -> Control:
	var d: Dictionary = Enemy.DEFS.get(kind, {})
	var sname := sprite_override if sprite_override != "" else str(d.get("sprite", kind))
	var sf: SpriteFrames
	var anim := "idle"
	if sprite_override.begins_with("specials/"):
		sf = Art.anim(sprite_override, 6.0)
		anim = "default"
	else:
		sf = Enemy.frames_for(sname)
		anim = "idle" if sf.has_animation("idle") else "default"
	var tex := sf.get_frame_texture(anim, 0) if sf.get_frame_count(anim) > 0 else null
	var k := 1
	if tex and tex.get_width() <= 16 and tex.get_height() <= 16:
		k = 3
	elif tex and tex.get_width() <= 24 and tex.get_height() <= 24:
		k = 2
	if not known:
		return _pic(silhouette(tex), k)
	var tr := _pic(tex, k, d.get("tint", Color.WHITE) if sprite_override == "" else Color.WHITE)
	_anim = tr
	_anim_sf = sf
	_anim_name = anim
	_anim_t = 0.0
	return tr


func _show_detail(e: Dictionary) -> void:
	_clear_detail()
	if e.is_empty():
		_text("Nothing here yet.", UI.DIM)
		return
	match e["kind"]:
		"relic", "keepsake", "gift": _d_relic(e)
		"lodger": _d_lodger(e)
		"guardian": _d_guardian(e)
		"room": _d_room(e)
		"mini": _d_mini(e)
		"candle": _d_candle(e)
		"howto": _d_howto()
		"totals": _d_totals()
		"nights": _d_nights()
		"run": _d_run(e["run"])


func _d_relic(e: Dictionary) -> void:
	var id: String = e["id"]
	var known: bool = e["known"]
	var unlocked := Unlocks.is_unlocked(id)
	var tex := Art.tex(Items.icon(id))
	var subs: Array = []
	if e["kind"] == "relic":
		subs.append(Pips.new(Items.tier(id), TIER_NAMES[clampi(Items.tier(id), 0, 4)]))
		var r := Items.rite_of(id)
		if r != "" and known:
			subs.append([Items.RITES[r]["name"], UI.EMBER])
	elif e["kind"] == "keepsake":
		subs.append(["Keepsake  -  %d pips" % int(Items.KEEPSAKES[id]["pips"]), UI.EMBER])
	else:
		subs.append(["A gift of the Vigil", UI.EMBER])
	_head(_pic(tex if known else silhouette(tex), 2), Items.display_name(id) if known else "???", subs, UI.GOLD if known else UI.DIM)
	if not unlocked:
		_text("Not in the house yet.", UI.DIM)
		_text(Unlocks.goal_line(id), UI.EMBER)
		return
	if not known:
		_text("Somewhere in the house. Not found yet.", UI.DIM)
	else:
		var desc: String = Items.KEEPSAKES[id]["desc"] if e["kind"] == "keepsake" else Items.desc(id)
		_text(desc + ".", UI.CREAM)
	if e["kind"] == "relic":
		var where: Array = []
		for p in Items.RELICS[id].get("pools", []):
			where.append(POOL_NAMES.get(p, p))
		_text("Found in " + ", ".join(where), UI.DIM)
	if known:
		var n := Records.taken(id)
		_text("Taken %d time%s" % [n, "" if n == 1 else "s"] if n > 0 else "Seen, never taken", UI.WAX)
	if Unlocks.is_locked_item(id):
		_text(Unlocks.goal_line(id), LOCK)


func _haunts(kind: String) -> String:
	var fl: Array = []
	var pools: Dictionary = preload("res://scripts/game/world.gd").POOLS
	var ns: Array = pools.keys()
	ns.sort()
	for n in ns:
		for slot in pools[n].values():
			if kind in slot and not Records.floor_name(n, true) in fl:
				fl.append(Records.floor_name(n, true))
	if fl.is_empty():
		return ""
	if fl.size() == 1:
		return "Haunts " + fl[0]
	return "Haunts " + ", ".join(fl.slice(0, fl.size() - 1)) + " and " + fl[fl.size() - 1]


func _d_lodger(e: Dictionary) -> void:
	var kind: String = e["id"]
	var d: Dictionary = Enemy.DEFS[kind]
	var known: bool = e["known"]
	var subs: Array = []
	var h := _haunts(kind)
	if kind == "wax_bit":
		h = "Drips off a Rose Melt"
	elif kind == "mimic":
		h = "Waits where a chest should be"
	_head(_creature_pic(kind, known), str(d.get("name", kind)) if known else "???", [[h, UI.EMBER]] if h != "" else subs, UI.GOLD if known else UI.DIM)
	if not known:
		_text("Not met yet.", UI.DIM)
		return
	_text(str(d.get("lore", "")), UI.CREAM)
	var k := Records.kills_of(kind)
	_text("Snuffed %s" % _num(k) if k > 0 else "Met, never snuffed", UI.WAX)


func _d_guardian(e: Dictionary) -> void:
	var kind: String = e["id"]
	var d: Dictionary = Enemy.DEFS[kind]
	var known: bool = e["known"]
	var fl := ""
	var floors: Dictionary = preload("res://scripts/game/world.gd").FLOORS
	for n in floors:
		if kind in floors[n]["bosses"]:
			fl = Records.floor_name(n, true)
	var subs: Array = [["Guardian of " + fl, UI.EMBER]]
	_head(_creature_pic(kind, known), Records.title_case(str(d.get("name", kind))) if known else "???", subs, UI.GOLD if known else UI.DIM)
	if not known:
		_text("It waits at the end of %s." % fl, UI.DIM)
		if kind == "big_demon" and int(Game.records.get("wins", 0)) <= 0:
			_text("Some say the Pendulum has a master. Win once to meet it.", LOCK)
		return
	_text("\"%s\"" % str(d.get("title", "")), UI.EMBER)
	_text(str(d.get("lore", "")), UI.CREAM)
	var rec := Records.boss_record(kind)
	if rec.is_empty():
		_text("Not beaten yet", UI.WAX)
	else:
		var n := int(rec.get("n", 0))
		_text("Beaten %d time%s   Fastest %s" % [n, "" if n == 1 else "s", _mmss(float(rec.get("best", 0.0)))], UI.WAX)


func _d_room(e: Dictionary) -> void:
	var rt: String = e["id"]
	var info: Dictionary = Specials.INFO[rt]
	var known: bool = e["known"]
	var tex: Texture2D = Art.tex(PROPS[rt]) if Art.has(PROPS[rt]) else null
	var fl: Array = info.get("floors", [])
	var where := "Turns up on floors %d-%d" % [fl[0], fl[fl.size() - 1]] if fl.size() > 1 else "Floor %d" % fl[0]
	_head(_pic(tex if known else silhouette(tex)), Records.title_case(str(info["name"])) if known else "???", [[where, UI.EMBER]], UI.GOLD if known else UI.DIM)
	if not known:
		_text("A room behind an odd door. Not found yet.", UI.DIM)
		return
	_text(str(info["sub"]) + ".", UI.CREAM)
	_text(str(info["hint"]), UI.DIM)


func _d_mini(e: Dictionary) -> void:
	var mk: String = e["id"]
	var info: Dictionary = Specials.MINIS[mk]
	var known: bool = e["known"]
	var pic: Control
	if Art.has("specials/mini_%s_idle_f0" % mk):
		pic = _creature_pic(mk, known, "specials/mini_%s_idle" % mk)
	else:
		pic = _creature_pic(mk, known)
	var from := str(Enemy.DEFS.get(mk, {}).get("name", mk))
	_head(pic, Records.title_case(str(info["name"])) if known else "???", [["A house champion of " + Records.floor_name(int(info["floor"]), true), UI.EMBER]], UI.GOLD if known else UI.DIM)
	if not known:
		_text("Twice the size of any %s. Not met yet." % from, UI.DIM)
		return
	_text(str(info["sub"]) + ".", UI.CREAM)
	_text("A %s grown twice as big." % from, UI.DIM)
	_text("Snuffed" if Records.mini_beaten(mk) else "Still at large", UI.WAX)


func _d_candle(e: Dictionary) -> void:
	var c: String = e["id"]
	var d: Dictionary = Candles.def_of(c)
	var known: bool = e["known"]
	var art := CandleArt.new()
	art.id = c
	art.sil = not known
	art.custom_minimum_size = Vector2(28, 48)
	_head(art, str(d["name"]) if known else "???", [["%d minutes of wax" % int(d["wax"]), UI.EMBER]] if known else [], UI.GOLD if known else UI.DIM)
	if not known:
		_text("Locked: " + str(d["unlock_text"]), UI.EMBER)
		return
	_text(str(d["line"]), UI.CREAM)
	if d.has("blurb"):
		_text(str(d["blurb"]), UI.DIM)
	var bits: Array = []
	if float(d["speed"]) != 1.0:
		bits.append("speed x%s" % str(snappedf(float(d["speed"]), 0.01)))
	if float(d["damage"]) != 1.0:
		bits.append("damage x%s" % str(snappedf(float(d["damage"]), 0.01)))
	if float(d["drain"]) != 1.0:
		bits.append("melts x%s" % str(snappedf(float(d["drain"]), 0.01)))
	if int(d["shots"]) > 1:
		bits.append("%d flames" % int(d["shots"]))
	if not bits.is_empty():
		var line := ", ".join(bits)
		_text(line.substr(0, 1).to_upper() + line.substr(1), UI.DIM)
	if d.has("start_relic"):
		_text("Starts with " + Items.display_name(d["start_relic"]), UI.DIM)
	if d.has("start_keepsake"):
		_text("Starts with the " + Items.display_name(d["start_keepsake"]), UI.DIM)
	var key := "best_finish" if c == "tallow" else "best_finish_" + c
	var best := float(Game.records.get(key, 0.0))
	var wins := int((Game.records.get("wins_by_candle", {}) as Dictionary).get(c, 0))
	if best > 0.0:
		_text("Best: done by %s%s" % [Game.clock_text(best), ("   Wins %d" % wins) if wins > 0 else ""], UI.WAX)
	else:
		_text("Not won with yet", UI.WAX)


## The rules from the one-time intro (world._intro), for anyone who skipped it.
func _d_howto() -> void:
	# short enough for the 384-wide Journal (the detail panel must not push the Back row off the screen)
	_head(_pic(Art.tex("hero/hero_preview"), 2), "How to play", [["Midnight to two", UI.EMBER]])
	_text("Burn down four floors and snuff the Belfry's guardian before the clock strikes two.")
	_text("Your wax is your life and your time: hits melt it, drippings mend it.", UI.WAX)
	_text(Controls.intro_line(), UI.DIM)


func _d_totals() -> void:
	var rec := Game.records
	_head(_pic(Art.tex("ui/icon_medal"), 2), "The Ledger", [["Everything you have burnt through", UI.EMBER]])
	_text("Slot %d  -  %s" % [Game.slot, Records.level_text(Game.level)], UI.WAX)   # this save slot and its level
	var bf := int(rec.get("best_floor", 0))
	_text("Runs %d   Wins %d   Deepest: %s" % [int(rec.get("runs", 0)), int(rec.get("wins", 0)), Records.floor_name(bf) if bf > 0 else "-"], UI.CREAM)
	_text("Creatures snuffed %s   Best Kindling x%d" % [_num(int(rec.get("kills", 0))), int(rec.get("best_streak", 0))], UI.CREAM)
	_text("Achievements %d / %d" % [Achievements.count(), Achievements.LIST.size()], UI.CREAM)
	_text("Best finish, by candle", UI.EMBER)
	var lines: Array = []
	for c in Candles.ORDER:
		if not Candles.is_unlocked(c):
			continue
		var key: String = "best_finish" if c == "tallow" else "best_finish_" + c
		var best := float(rec.get(key, 0.0))
		lines.append("%s %s" % [Candles.def_of(c)["name"], Game.clock_text(best) if best > 0.0 else "-"])
	_text("   ".join(lines), UI.WAX)


func _d_nights() -> void:
	_head(_pic(Art.tex("items/hourglass") if Art.has("items/hourglass") else null, 2), "Tonight's Candle", [["One house a night, the same for all", UI.EMBER]])
	var nights: Array = Game.records.get("daily_history", [])
	if nights.is_empty():
		_text("No nights yet. Light Tonight's Candle from the title.", UI.DIM)
		return
	for n in nights.slice(0, 8):
		var date: String = n.get("date", "")
		_text("%s   first %s   best %s%s" % [date.substr(5), _num(int(n.get("first", 0))), _num(int(n.get("best", 0))), "   won" if n.get("won", false) else ""], UI.CREAM if n == nights[0] else UI.WAX)


func _d_run(r: Dictionary) -> void:
	var won: bool = r.get("won", false)
	var killer := str(r.get("killer", ""))
	var tex: Texture2D = Art.tex("ui/icon_medal") if won else Records.killer_icon(killer)
	var k := 2 if tex and tex.get_width() <= 24 and tex.get_height() <= 24 else 1
	var fl := maxi(1, int(r.get("floor", 1)))
	var title := "Run %d" % int(r.get("n", 0))
	var sub := ("Done by %s" % Game.clock_text(float(r.get("clock", 0.0)))) if won else Records.death_line(killer)
	_head(_pic(tex, k), title, [[sub, UI.GOLD if won else UI.RED]], UI.GOLD)
	var where := "%s - %s (%s)" % [Candles.def_of(str(r.get("candle", "tallow")))["name"], Records.floor_name(fl),
		"above the bells" if fl > Records.floor_count() else "%d/%d" % [fl, Records.floor_count()]]
	if won:
		where += " - " + Game.clock_text(float(r.get("clock", 0.0)))
	_text(where, UI.CREAM)
	_text("Played %s   Kills %d   Kindling x%d" % [_mmss(float(r.get("time", 0.0))), int(r.get("kills", 0)), int(r.get("streak", 0))], UI.WAX)
	# the run's difficulty level (runs from before 2.1 have none to show)
	var lv := ("  -  Level %d" % int(r["level"])) if r.has("level") else ""
	_text(("Tonight's Candle  -  " if r.get("daily", false) else "") + "Seed " + Records.seed_text(int(r.get("seed", 0))) + lv, UI.DIM)
	var relics: Array = r.get("relics", [])
	if not relics.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 1)
		flow.add_theme_constant_override("v_separation", 1)
		flow.custom_minimum_size = Vector2(150, 0)
		for id in relics.slice(0, 30):
			var tr := TextureRect.new()
			tr.texture = Art.tex(Items.icon(id))
			flow.add_child(tr)
		_detail.add_child(flow)


# ---------------------------------------------------------------- pieces

## One cell of the grid: a dark socket, the picture (or its silhouette), the selection frame, a
## new-dot. A Button, so menus can focus it.
class JSlot extends Button:
	var j: Journal
	var idx := 0
	var e: Dictionary
	var _tex: Texture2D

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		flat = true
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		_tex = j.icon_of(e)
		pressed.connect(func(): j._select(idx))
		focus_entered.connect(func(): j._select(idx))
		mouse_entered.connect(func():
			if Controls.device == Controls.MOUSE:
				j._select(idx))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Journal.SOCKET)
		var kind: String = e["kind"]
		if kind == "candle":
			CandleArt.paint(self, str(e["id"]), Vector2(size.x / 2.0, size.y - 6.0).floor(), not e["known"], 0)
		elif kind == "run" or kind == "totals" or kind == "nights" or kind == "howto":
			_draw_row()
		elif _tex:
			var p := ((size - _tex.get_size()) / 2.0).floor()
			var tint := Color.WHITE
			if kind in ["lodger", "guardian", "mini"]:
				p.y = size.y - _tex.get_height() - 2.0   # creatures stand on the bottom of the cell
				if p.y < 1.0:
					p.y = 1.0   # a tall one shows from its head down; the cell clips its feet
				if e["known"] and kind != "mini":
					tint = Enemy.DEFS.get(e["id"], {}).get("tint", Color.WHITE)
			# QA-12: only the part inside the cell is drawn (a tall portrait never spills over its
			# neighbour); the selection ring may still sit 1 px outside
			var vis := Rect2(p, _tex.get_size()).intersection(Rect2(Vector2.ZERO, size))
			if vis.size.x > 0.0 and vis.size.y > 0.0:
				draw_texture_rect_region(_tex, vis, Rect2(vis.position - p, vis.size), tint)
		if j.sel == idx:
			draw_style_box(UI.focus_box(), r)
		if e.get("new_key", "") != "" and Records.is_new(e["new_key"]):
			Journal._dot(self, Vector2(size.x - 4, 1))

	func _draw_row() -> void:
		var f: Font = Art.font_small
		var line1 := ""
		var line2 := ""
		var c2 := UI.DIM
		match str(e["kind"]):
			"howto":
				line1 = "How to play"
				line2 = "Wax, time and the rules"
			"totals":
				line1 = "The Ledger"
				line2 = "Totals and best times"
			"nights":
				line1 = "Tonight's Candle"
				line2 = "%d night%s" % [(Game.records.get("daily_history", []) as Array).size(), "" if (Game.records.get("daily_history", []) as Array).size() == 1 else "s"]
			"run":
				var r: Dictionary = e["run"]
				line1 = "Run %d  %s" % [int(r.get("n", 0)), Records.floor_name(maxi(1, int(r.get("floor", 1))))]
				if r.get("won", false):
					line2 = "Done by " + Game.clock_text(float(r.get("clock", 0.0)))
					c2 = UI.GOLD
				else:
					line2 = Records.short_killer(str(r.get("killer", "")))
					c2 = UI.RED
		if _tex:
			var s := _tex.get_size()
			if s.x <= 16 and s.y <= 16:
				draw_texture(_tex, Vector2(1, 1) + ((Vector2(16, 16) - s) / 2.0).floor())
			else:
				# a tall portrait: show 16x16 of it from the top of the figure (the face)
				draw_texture_rect_region(_tex, Rect2(1, 1, 16, 16), Journal.face_region(_tex))
		for k in 2:
			var txt: String = line1 if k == 0 else line2
			var col: Color = UI.CREAM if k == 0 else c2
			var y := 8.0 if k == 0 else 16.0
			draw_string(f, Vector2(21, y + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.INK)
			draw_string(f, Vector2(20, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## Tier pips: five small gems, the first q+1 lit, and a word.
class Pips extends Control:
	var q := 0
	var word := ""

	func _init(tier: int, w: String) -> void:
		q = tier
		word = w
		custom_minimum_size = Vector2(80, 9)

	func _draw() -> void:
		for i in 5:
			var x := 1 + i * 5
			var on := i <= q
			draw_rect(Rect2(x, 3, 4, 4), UI.INK)
			draw_rect(Rect2(x, 2, 3, 3), UI.GOLD if on else Journal.SIL)
			if on:
				draw_rect(Rect2(x, 2, 1, 1), UI.CREAM)
		draw_string(Art.font_small, Vector2(29, 8), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.INK)
		draw_string(Art.font_small, Vector2(28, 7), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI.DIM)


## A candle from the Candle Box, drawn like Tallow (body, rim, drips, face, flame, brass dish).
class CandleArt extends Control:
	var id := "tallow"
	var sil := false
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		CandleArt.paint(self, id, Vector2(size.x / 2.0, size.y - 4.0).floor(), sil, int(_t * 10.0) % 6)

	## base = the bottom centre of the wax (the dish sits under it).
	static func paint(ci: CanvasItem, cid: String, base: Vector2, dark: bool, frame: int) -> void:
		# the same painter as the in-game Tallow (Player.paint_preview); feet = 4 px under the wax's bottom
		var opts := {"frame": frame}
		if dark:
			opts["sil"] = Journal.SIL
			opts["tex"] = func(t: Texture2D) -> Texture2D: return Journal.silhouette(t)
		Player.paint_preview(ci, base + Vector2(0, 4), cid, opts)
