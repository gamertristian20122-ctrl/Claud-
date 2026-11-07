extends Control
## End of a run: snuffed out, or done before two.

var main: Node
var params := {}


func setup(p: Dictionary) -> void:
	params = p


func _ready() -> void:
	main = get_parent()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.027, 0.035)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var won: bool = params.get("won", false)
	var themes := ["", "cellar", "crypt", "chapel", "belfry"]
	var room := TextureRect.new()
	room.texture = Art.tex("rooms/room_" + themes[clampi(int(params.get("floor", 1)), 1, 4)])
	room.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.modulate = Color(0.32, 0.26, 0.28)
	add_child(room)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var pnl := UI.panel()
	center.add_child(pnl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pnl.add_child(v)
	var hero := TextureRect.new()
	hero.texture = Art.tex("hero/hero_preview")
	hero.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hero.custom_minimum_size = Vector2(0, 36)
	if not won:
		hero.modulate = Color(0.45, 0.4, 0.42)
	v.add_child(hero)
	var clock := Game.clock_text(float(params.get("clock", 120.0)))
	var title := "DONE BY %s" % clock if won else "SNUFFED OUT"
	v.add_child(UI.label(title, 16, UI.GOLD if won else UI.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := "The house is quiet. You can finally rest." if won else ("The clock struck two." if float(params.get("clock", 0)) >= 119.5 else "Your flame went out at %s." % clock)
	v.add_child(UI.label(sub, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var floors := ["", "The Cellar", "The Crypt", "The Chapel", "The Belfry"]
	var f: int = params.get("floor", 1)
	var t: float = params.get("time", 0.0)
	var stats := "%s   Rooms %d   Foes %d   %d:%02d played" % [floors[clampi(f, 1, 4)], params.get("rooms", 0), params.get("kills", 0), int(t) / 60, int(t) % 60]
	v.add_child(UI.label(stats, 8, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var relics: Array = params.get("relics", [])
	if not relics.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for r in relics:
			var tr := TextureRect.new()
			tr.texture = Art.tex(Items.icon(r))
			row.add_child(tr)
		v.add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	v.add_child(spacer)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 6)
	row2.add_child(UI.button("Light another", func(): main.goto("game")))
	row2.add_child(UI.button("Title", func(): main.goto("title")))
	v.add_child(row2)


func on_back() -> void:
	main.goto("title")
