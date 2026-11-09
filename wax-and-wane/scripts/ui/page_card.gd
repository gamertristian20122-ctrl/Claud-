class_name PageCard
extends Control
## The reading card (v2.5 story): one page of Martha's diary on a torn sheet of paper, over everything.
## Opened by the Diary when a page is picked up and the room is calm (never during a fight: Diary._calm_now),
## by the results screen for pages found as a run ended, and from the Journal's Diary tab. Any key, pad
## button, click or tap closes it once HOLD seconds have passed (a press meant for the game cannot skip it
## unread); Back closes it too (Diary.on_back). Paper and ink are 0x72 palette colours; text through L.t.

const HOLD := 0.6
const PAPER := Color("#fdf7ed")
const PAPER_SH := Color("#d3bfa9")
const EDGE := Color("#222222")
const INK := Color("#21141b")
const INK_SOFT := Color("#775c55")
const TITLE := Color("#8f4029")
const TEXT_W := 268.0
## The torn top and bottom edges: how far each column of the paper reaches (0-2 px), repeating.
const TEAR := [0, 1, 2, 2, 1, 0, 1, 1, 2, 0, 0, 1, 2, 1, 0, 2, 1, 1, 0, 1, 2, 2, 0, 1]

var page_id := ""
var done: Callable
var auto_close := -1.0   # tests: close by itself after this many seconds (play-tests never wait on a card)
var _t := 0.0
var _closing := false
var _sheet: PanelContainer
var _hint: Label


static func open(parent: Node, id: String, on_done := Callable()) -> PageCard:
	var c := PageCard.new()
	c.page_id = id
	c.done = on_done
	parent.add_child(c)
	return c


func _ready() -> void:
	set_meta("modal", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.02, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_sheet = PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 13
	sb.content_margin_right = 13
	sb.content_margin_top = 8
	sb.content_margin_bottom = 7
	_sheet.add_theme_stylebox_override("panel", sb)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.draw.connect(_draw_sheet)
	center.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(v)
	var pg := Diary.page(page_id)
	var head := _ink(L.t("Diary page {n} of {total}", {"n": Diary.number(page_id), "total": Diary.TOTAL}).to_upper(), 8, INK_SOFT)
	v.add_child(head)
	var title := _ink(L.t(str(pg.get("title", "???"))), 16, TITLE)
	v.add_child(title)
	var body := _ink(L.t(str(pg.get("text", ""))), 8, INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(TEXT_W, 0)
	v.add_child(body)
	_hint = _ink(_close_text(), 8, INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.modulate.a = 0.0
	v.add_child(_hint)
	Controls.on_modal_opened(self)
	Audio.play("page_flip", -2.0, 0.04, 0.95)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


## A label in ink on the paper: no drop shadow (the UI's shadow muddies dark text on cream).
func _ink(text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UI.label(text, size, col, align)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


func _close_text() -> String:
	match Controls.device:
		"touch": return L.t("Tap to close")
		"gamepad": return L.t("Any button to close")
	return L.t("Any key to close")


## The sheet: cream paper with torn top and bottom edges, a 1 px dark outline and a shaded right edge.
func _draw_sheet() -> void:
	var w := int(_sheet.size.x)
	var h := int(_sheet.size.y)
	var top := 3
	var bot := h - 3
	_sheet.draw_rect(Rect2(1, top, w - 2, bot - top), PAPER)
	_sheet.draw_rect(Rect2(w - 3, top, 2, bot - top), PAPER_SH)
	_sheet.draw_rect(Rect2(0, top, 1, bot - top), EDGE)
	_sheet.draw_rect(Rect2(w - 1, top, 1, bot - top), EDGE)
	for x in range(1, w - 1):
		var up: int = TEAR[x % TEAR.size()]
		var dn: int = TEAR[(x * 7 + 5) % TEAR.size()]
		var col := PAPER_SH if x >= w - 3 else PAPER
		_sheet.draw_rect(Rect2(x, top - up, 1, up), col)
		_sheet.draw_rect(Rect2(x, top - up - 1, 1, 1), EDGE)
		_sheet.draw_rect(Rect2(x, bot, 1, dn), col)
		_sheet.draw_rect(Rect2(x, bot + dn, 1, 1), EDGE)
	# a fold across the middle, where it was folded to fit a pocket
	var fy := top + int((bot - top) * 0.52)
	for x in range(1, w - 3):
		if x % 2 == 0:
			_sheet.draw_rect(Rect2(x, fy, 1, 1), PAPER_SH)


func _process(dt: float) -> void:
	_t += dt
	if _t >= HOLD and _hint and _hint.modulate.a < 1.0:
		_hint.modulate.a = minf(1.0, _hint.modulate.a + dt * 4.0)
	if auto_close >= 0.0 and _t >= auto_close:
		close()


func _input(ev: InputEvent) -> void:
	if _closing:
		return
	var press: bool = (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventMouseButton and ev.pressed) \
			or (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventJoypadButton and ev.pressed)
	if not press:
		return
	get_viewport().set_input_as_handled()   # the game and the menus under the card never see it
	if _t >= HOLD:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Audio.play("page_flip", -6.0, 0.04, 1.15)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		if done.is_valid():
			done.call()
		queue_free())
