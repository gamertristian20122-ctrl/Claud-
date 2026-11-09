class_name FitCheck
extends RefCounted
## Layout judge for the screenshot tours (`--tour ... --fit`, called from autotest._shot): lists text
## and buttons that leave the visible screen, and text that lands on other text from another layer
## or another part of the HUD (a toast on a banner, a subtitle on the coin counter).
##   [fit] 36_results OFF 'Light another' (180,209 96x24)
##   [fit] 27_floor_2 OVER 'SMOKE PACT' x 'THE CRYPT'
## Things under an open modal's dim, inside a scrolling list or a clipping cell are not judged, and
## text sliding in or out (alpha < 0.5) is skipped.

const MIN_ALPHA := 0.5


static func scan(tree_root: Node, vs: Vector2) -> Array[String]:
	var items: Array = []   # [rect, text, owner, node]
	_collect(tree_root, items, vs)
	var out: Array[String] = []
	var screen := Rect2(Vector2.ZERO, vs).grow(0.5)
	for it in items:
		var r: Rect2 = it[0]
		if not screen.encloses(r) and not _rolling(it[3]):
			out.append("OFF '%s' (%d,%d %dx%d)" % [_short(it[1]), r.position.x, r.position.y, r.size.x, r.size.y])
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Array = items[i]
			var b: Array = items[j]
			if a[2] == b[2]:
				continue
			var x: Rect2 = (a[0] as Rect2).intersection(b[0])
			if x.size.x >= 2.0 and x.size.y >= 2.0:
				out.append("OVER '%s' x '%s'" % [_short(a[1]), _short(b[1])])
	return out


## The ending's credits roll scrolls in from below the screen on purpose.
static func _rolling(n: Node) -> bool:
	var p := n
	while p:
		var sc: Variant = p.get_script()
		if sc is Script and str((sc as Script).get_global_name()) == "Ending":   # by name: no compile-time tie to ending.gd
			return true
		p = p.get_parent()
	return false


static func _short(t: String) -> String:
	t = t.replace("\n", " / ")
	return t if t.length() <= 32 else t.substr(0, 30) + ".."


## The group a piece of text belongs to: the top modal / toast / banner / hint it is part of, or its
## CanvasLayer. Text in the same group was laid out together and is not compared.
static func _owner(n: Node) -> String:
	var p := n
	var group := ""
	while p:
		if group == "" and p.has_meta("fit_group"):
			group = str(p.get_meta("fit_group"))
		if group == "" and p.get_meta("modal", false):
			return "modal#%d" % p.get_instance_id()
		if p is CanvasLayer:
			return "%s@layer#%d" % [group, p.get_instance_id()]
		p = p.get_parent()
	return group + "@root"


## True for things drawn in the world (floating text over the room), not on the screen's UI.
static func _in_world(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is CanvasLayer:
			return false
		if p is Node2D:
			return true
		p = p.get_parent()
	return false


static func _alpha(ci: CanvasItem) -> float:
	var a := 1.0
	var p: Node = ci
	while p and p is CanvasItem:
		a *= (p as CanvasItem).modulate.a
		p = p.get_parent()
	return a * ci.self_modulate.a


static func _collect(n: Node, items: Array, vs: Vector2) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n.get_meta("fit_skip", false):   # in motion on purpose (a toast sliding in)
		return
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	# under an open modal only the modal itself counts (the dim covers the rest of its layer)
	var kids := n.get_children()
	var top_modal := -1
	for i in kids.size():
		if kids[i] is Control and kids[i].get_meta("modal", false) and (kids[i] as Control).visible:
			top_modal = i
	for i in kids.size():
		if top_modal >= 0 and i < top_modal and kids[i] is CanvasItem:
			continue
		var c: Node = kids[i]
		if c is ScrollContainer or (c is Control and (c as Control).clip_contents):
			_add(c as Control, "[list]", items)   # its inside scrolls / is clipped on purpose
			continue
		if c is Label:
			_add_label(c as Label, items)
		elif c is BaseButton and c is Control:
			var t := str((c as Button).text) if c is Button else ""
			_add(c as Control, t if t != "" else "[button]", items)
		_collect(c, items, vs)


static func _add_label(l: Label, items: Array) -> void:
	if l.text.strip_edges() == "" or l.visible_characters == 0 or _alpha(l) < MIN_ALPHA or _in_world(l):
		return
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var r := Rect2(Vector2.ZERO, l.size)
	if font and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var lines := l.text.split("\n")
		var tw := 0.0
		for line in lines:
			tw = maxf(tw, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var x0 := 0.0
		match l.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER: x0 = floorf((l.size.x - tw) / 2.0)
			HORIZONTAL_ALIGNMENT_RIGHT: x0 = l.size.x - tw
		var th := minf(l.size.y, float(lines.size()) * font.get_height(fs))
		var y0 := 0.0
		match l.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER: y0 = floorf((l.size.y - th) / 2.0)
			VERTICAL_ALIGNMENT_BOTTOM: y0 = l.size.y - th
		r = Rect2(x0, y0 + 1.0, tw, maxf(1.0, th - 2.0))
	var xf := l.get_global_transform_with_canvas()
	items.append([Rect2(xf * r.position, xf.basis_xform(r.size)).abs(), l.text, _owner(l), l])


static func _add(c: Control, text: String, items: Array) -> void:
	if _alpha(c) < MIN_ALPHA or _in_world(c):
		return
	var xf := c.get_global_transform_with_canvas()
	items.append([Rect2(xf.origin, xf.basis_xform(c.size)).abs(), text, _owner(c), c])
