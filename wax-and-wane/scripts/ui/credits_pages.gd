extends RefCounted
## The Credits modal's extra pages (title > Credits > Licences / Privacy).
##   Licences: this game's copyright, the free asset packs with their licences, Godot's MIT licence and
##   Godot's own third-party notices, read from the running engine (Engine.get_license_text(),
##   get_copyright_info(), get_license_info()), so they always match the engine that runs the game.
##   Privacy: the same policy as PRIVACY.md (change both together).
## Pages scroll with the Up / Down buttons, LB / RB (Q / E, PgUp / PgDn), the mouse wheel or a drag.

const PRIVACY_URL := "https://github.com/gamertristian20122-ctrl/Claud-/blob/ccr-37a74654-pp10xa/wax-and-wane/PRIVACY.md"
const BOX := Vector2(340, 138)   # the text area: fits a 384x216 screen with the title and the buttons

const PRIVACY := [
	"Wax & Wane collects no personal data.",
	"- It works offline and never connects to the internet.",
	"- No ads, no analytics, no accounts, no tracking.",
	"- Your saves and settings stay on this device. Uninstalling the game on a phone deletes them.",
	"- If you turned on backup in your phone's settings, Android may copy the save to your own Google account. On Steam, Steam Cloud may keep a copy. Google and Valve handle those copies; the developer never sees them.",
	"- Share copies a short line about your run to your clipboard. Nothing is sent unless you paste it.",
]

## [pack, what the game uses from it, licence, where it comes from] (2.10: every picture but the candles, and every
## sound, comes from one of these; the per-file lists are assets/licenses/CREDITS_free_art.txt and CREDITS_audio.txt)
const ASSETS := [
	["16x16 DungeonTileset II by 0x72", "the house's walls and floors, many lodgers and guardians, chests, coins, bombs, flasks", "CC0 1.0", "0x72.itch.io/dungeontileset-ii"],
	["Ninja Adventure Asset Pack by Pixel-boy and AAA", "lodgers and guardians, relic and move pictures, effects, key and gamepad pictures, all the music, the jingles and some sounds", "CC0 1.0", "pixel-boy.itch.io/ninja-adventure-asset-pack"],
	["Roguelike Indoors, Tiny Dungeon and Cursor Pixel Pack by Kenney", "furniture and props, the pointing hand of the touch lesson", "CC0 1.0", "kenney.nl"],
	["16x16 RPG Item Pack by Alex's Assets", "relic and keepsake pictures", "CC0 1.0", "alexs-assets.itch.io/16x16-rpg-item-pack"],
	["Lucifer: Ancient Skeleton by Foozle (drawn by Baldur)", "the Ossuary", "CC0 1.0", "foozlecc.itch.io/lucifer-skeleton-ancient-boss"],
	["Gothicvania Patreon's Collection by Luis Zuno (ansimuz)", "the night town of the opening and the endings", "CC0 1.0", "opengameart.org/content/gothicvania-patreons-collection"],
	["Haunted Hotel Asset Pack by Not Jam", "the grandfather clock in the hall", "CC0 1.0", "not-jam.itch.io/haunted-hotel-asset-pack"],
	["Kenney Pixel and Kenney Mini by Kenney", "the fonts", "CC0 1.0", "kenney.nl"],
	["Kenney Foley, Impact, Interface, RPG Audio, Sci-Fi Sounds, Digital Audio and Retro Sounds 1", "most sound effects: each one a pack file, as it is", "CC0 1.0", "kenney.nl"],
]


# ---------------------------------------------------------------- pages

static func _page(parent: Node, title: String, bbcode: String, extra: Array) -> Array:
	var m := UI.modal(parent, title)
	var v: VBoxContainer = m[1]
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.scroll_active = true
	t.fit_content = false
	t.selection_enabled = false
	t.custom_minimum_size = BOX
	t.add_theme_font_override("normal_font", Art.font_small)
	t.add_theme_font_size_override("normal_font_size", 8)
	t.add_theme_color_override("default_color", UI.CREAM)
	t.add_theme_constant_override("line_separation", 1)
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.text = bbcode
	v.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var step := func(dir: int):
		var sb := t.get_v_scroll_bar()
		sb.value = clampf(sb.value + dir * (BOX.y - 18.0), 0.0, sb.max_value)
	var up := UI.button("Up", func(): step.call(-1), 60)
	var down := UI.button("Down", func(): step.call(1), 60)
	down.set_meta("default_focus", true)
	row.add_child(up)
	row.add_child(down)
	for b in extra:
		row.add_child(b)
	var back := UI.button("Back", func(): m[0].queue_free(), 60)
	row.add_child(back)
	v.add_child(row)
	Controls.set_page_handler(m[0], step)   # LB / RB, Q / E, PgUp / PgDn
	return [m[0], t]


static func _h(text: String) -> String:
	return "[color=#%s]%s[/color]\n" % [UI.GOLD.to_html(false), text]


static func _dim(text: String) -> String:
	return "[color=#%s]%s[/color]\n" % [UI.DIM.to_html(false), text]


static func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


static func licences(parent: Node) -> void:
	var b := ""
	b += _h("WAX & WANE")
	b += "Copyright (c) 2026 the Wax & Wane developer. All rights reserved.\n"
	b += "The code and the words were made for this game with Claude (AI), and so were Tallow and the other candles (drawn by scripts). Every other picture, the music, the sounds and the fonts come from the free packs below, made by people.\n\n"
	b += _h("FREE ASSETS IN THIS GAME")
	for a in ASSETS:
		b += "%s\n" % a[0]
		b += _dim("  %s. Licence: %s (public domain). %s" % [a[1], a[2], a[3]])
	b += "The licence texts and a per-file list are in the game's licenses folder.\n\n"
	b += _h("GODOT ENGINE")
	b += "This game uses Godot Engine (godotengine.org/license), available under the following license:\n\n"
	b += _esc(Engine.get_license_text().strip_edges()) + "\n\n"
	b += _h("THIRD-PARTY PARTS OF GODOT")
	b += "Godot Engine contains these components, each under its own licence:\n\n"
	for c in Engine.get_copyright_info():
		b += _esc(str(c["name"])) + "\n"
		var seen := {}
		for part in c["parts"]:
			for cr in part["copyright"]:
				var line := "  (c) %s" % str(cr)
				if not seen.has(line):
					seen[line] = true
					b += _dim(_esc(line))
			var lic := "  Licence: %s" % str(part["license"])
			if not seen.has(lic):
				seen[lic] = true
				b += _dim(_esc(lic))
	var info: Dictionary = Engine.get_license_info()
	var names := info.keys()
	names.sort()
	for n in names:
		b += "\n" + _h("LICENCE: " + _esc(str(n)))
		b += _esc(str(info[n]).strip_edges()) + "\n"
	_page(parent, "LICENCES", b, [])


static func privacy(parent: Node) -> void:
	var b := ""
	for i in PRIVACY.size():
		b += (_h(PRIVACY[i]) if i == 0 else str(PRIVACY[i]) + "\n")
	b += "\n" + _h("FULL POLICY")
	b += _esc(PRIVACY_URL) + "\n"
	b += _dim("Questions: the developer's email on the game's store page.")
	var link := UI.button("Open link", func(): OS.shell_open(PRIVACY_URL), 84)
	_page(parent, "PRIVACY", b, [link])
