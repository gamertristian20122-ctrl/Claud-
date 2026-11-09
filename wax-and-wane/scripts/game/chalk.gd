class_name Chalk
extends Node2D
## Someone chalked the controls on the floor of the very first room (floor 1's start room): how to
## walk, how to fire, the bomb, the keepsake, the special move (v2.3) and a candle = a clock ("wax =
## time"). The drawings
## follow the device in use (touch thumbs, keys, mouse, gamepad) and swap with a quick smudge when
## Controls.device changes. Art: tools/art_chalk.py -> assets/art/chalk/.
##
## Attached by Records.on_room (one line at the end of Room.build). Stains and pits draw over it
## (z -17: above the floor art and decor, below the floor layer).

## UX-06: 0.8 (was 0.5) plus a 1 px dark under-stroke, so the drawings read on a phone in the
## candle's light (median contrast to the floor about 2.8:1 before).
const ALPHA := 0.8
const INK := Color("#21141b")
## Where each drawing sits, room-local (the floor is (16, 32) .. (256, 176); Tallow starts at (136, 112)).
const SPOTS := {
	"wax_time": Vector2(136, 52),
	"move": Vector2(66, 104),
	"aim": Vector2(206, 104),
	"bomb": Vector2(86, 152),
	"keep": Vector2(136, 152),
	"special": Vector2(188, 152),   # v2.3: the candle's special move (Shift / F, LT, the big round button)
}

var room: Node2D
var _spr := {}
var _ink := {}
var _set := ""
var _tw: Tween


static func attach(r: Node2D) -> void:
	var w: Variant = r.get("world")
	if w == null or str(r.data.get("type", "")) != "start" or not Art.has("chalk/chalk_wax_time"):
		return
	var fl: Variant = w.get("floor_num")
	if fl == null or int(fl) != 1:
		return
	var c := Chalk.new()
	c.room = r
	r.add_child(c)


func _ready() -> void:
	name = "Chalk"
	z_index = -17
	modulate.a = ALPHA
	for k in SPOTS:
		var ink := Sprite2D.new()   # the under-stroke: the same drawing, 1 px lower, in ink
		ink.centered = false
		ink.modulate = INK
		add_child(ink)
		_ink[k] = ink
		var s := Sprite2D.new()
		s.centered = false
		add_child(s)
		_spr[k] = s
	_show(false)
	_clear_decals()
	Controls.device_changed.connect(_on_device)
	Game.settings_changed.connect(_on_settings)


## Device -> which drawing set ("touch", "keys", "pad"); the aim drawing also has "mouse".
static func set_for(dev: String) -> String:
	match dev:
		Controls.TOUCH: return "touch"
		Controls.PAD: return "pad"
	return "keys"


func _tex(part: String, dev_set: String) -> Texture2D:
	var k := dev_set
	if part == "aim" and dev_set == "keys" and Game.settings.get("mouse_aim", true) and OS.has_feature("pc"):
		k = "mouse"
	var path := "chalk/chalk_wax_time" if part == "wax_time" else "chalk/chalk_%s_%s" % [part, k]
	return Art.tex(path) if Art.has(path) else null


func _show(smudge: bool) -> void:
	var want := set_for(Controls.device)
	if want == _set:
		return
	if not smudge:
		_apply(want)
		return
	# a quick smudge: the old drawing fades, the new one is chalked in
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "modulate:a", 0.0, 0.15)
	_tw.tween_callback(_apply.bind(want))
	_tw.tween_property(self, "modulate:a", ALPHA, 0.3)


func _apply(dev_set: String) -> void:
	_set = dev_set
	for k in _spr:
		var s: Sprite2D = _spr[k]
		s.texture = _tex(k, dev_set)
		if s.texture:
			s.position = (spot(k, dev_set) - s.texture.get_size() / 2.0).floor()
		var ink: Sprite2D = _ink[k]
		ink.texture = s.texture
		ink.position = s.position + Vector2(0, 1)


## Where a drawing sits. With "Swap sticks" on a touch screen the thumbs trade sides, and so do the
## drawings: MOVE and AIM change places, BOMB and KEEPSAKE follow the buttons to the left (UX-08).
static func spot(part: String, dev_set: String) -> Vector2:
	var at: Vector2 = SPOTS[part]
	if dev_set == "touch" and bool(Game.settings.get("swap_sticks", false)) and part != "wax_time":
		at.x = 272.0 - at.x
	return at


func _on_settings() -> void:
	if is_inside_tree() and _set != "":
		_apply(_set)


func _on_device(_dev: String) -> void:
	if is_inside_tree():
		_show(true)


## Floor decals (straw, puddles, cracks) that would sit under a drawing are swept aside.
func _clear_decals() -> void:
	var decor: Variant = room.get("decor") if room else null
	if decor == null or not is_instance_valid(decor):
		return
	var items: Variant = decor.get("_items")
	if not (items is Array):
		return
	var rects: Array[Rect2] = []
	for k in SPOTS:
		rects.append(Rect2(SPOTS[k] - Vector2(28, 24), Vector2(56, 48)))
	var keep: Array = []
	for it in items:
		var tex: Texture2D = it[0]
		var r := Rect2(it[1], tex.get_size())
		var hit := false
		if r.position.y >= 26.0:   # floor decals only (wall pieces sit higher)
			for q in rects:
				if q.intersects(r):
					hit = true
					break
		if not hit:
			keep.append(it)
	if keep.size() != (items as Array).size():
		(items as Array).assign(keep)
		decor.queue_redraw()
