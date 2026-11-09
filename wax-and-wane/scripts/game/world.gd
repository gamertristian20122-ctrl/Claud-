extends Node2D
## One run: floors, rooms, the candle, enemies, drops, the clock and every effect.

const FLOORS := {
	1: {"name": "The Cellar", "theme": "cellar", "dark": Color(0.32, 0.26, 0.27), "music": "floor_1", "boss": "big_zombie", "bosses": ["big_zombie", "wax_mother", "furnace"]},
	2: {"name": "The Crypt", "theme": "crypt", "dark": Color(0.25, 0.27, 0.34), "music": "floor_2", "boss": "ogre", "bosses": ["ogre", "sexton", "ossuary"]},
	3: {"name": "The Chapel", "theme": "chapel", "dark": Color(0.28, 0.24, 0.34), "music": "floor_3", "boss": "necro_boss", "bosses": ["necro_boss", "choir", "organist"]},
	# a new player's first Belfry is always The Great Pendulum (Enemy.pick_boss); the others join after a win
	4: {"name": "The Belfry", "theme": "belfry", "dark": Color(0.33, 0.23, 0.22), "music": "floor_4", "boss": "pendulum", "bosses": ["pendulum", "big_demon", "weathercock"]},
	# the secret fifth floor (scripts/game/tower.gd): beat the Belfry by 1:00 AM to climb to it
	5: {"name": "The Clock Tower", "theme": "tower", "dark": Color(0.27, 0.29, 0.40), "music": "floor_5", "boss": "keeper", "bosses": ["keeper"]},
}
## Who lives where. e = ordinary slot, h = heavy slot, f = flyer slot. Each floor has its own lodgers
## (cellar: wax, rats and slugs; crypt: graves and soot; chapel: hymns, ghosts and waxworks;
## belfry: bells, clockwork and gargoyles) and the mix gets meaner as you climb.
const POOLS := {
	1: {"e": ["tiny_zombie", "goblin", "tiny_slug", "cinder_rat", "wax_blob", "tiny_zombie", "goblin"],
		"h": ["muddy", "slug", "skelet", "wax_blob", "zombie"], "f": ["imp", "moth"]},
	2: {"e": ["goblin", "skelet", "swampy", "cinder_rat", "sootling", "tiny_zombie", "wax_blob"],
		"h": ["pumpkin_dude", "doc", "grave_hand", "snuffer", "zombie", "muddy"], "f": ["imp", "moth", "wisp"]},
	3: {"e": ["skelet", "chort", "wogol", "sootling", "wisp", "swampy"],
		"h": ["orc_shaman", "necromancer", "psalter", "waxwork", "masked_orc", "grave_hand"], "f": ["angel", "moth", "psalter", "wisp"]},
	4: {"e": ["chort", "wogol", "ice_zombie", "deathwatch", "cinder_rat", "skelet", "sootling"],
		"h": ["gutterspout", "orc_warrior", "snuffer", "waxwork", "necromancer", "doc"], "f": ["clapper_bat", "imp", "angel", "clapper_bat"]},
	5: {"e": ["cog_sentry", "deathwatch", "chort", "wogol", "cog_sentry", "sootling", "skelet"],
		"h": ["gutterspout", "orc_warrior", "waxwork", "snuffer", "cog_sentry", "necromancer"], "f": ["minute_wraith", "minute_wraith", "clapper_bat", "angel"]},
}
## The last floor of the night as it was made (4 floors). A night of N floors ends on floor N (last_floor(), the
## Belfry); the Clock Tower is the floor above it. Tables indexed "per floor" are read by depth (depth()).
const LAST_FLOOR := 4
## Omens of the Hour: floor twists that always pay you back.
const OMENS := {
	"draught": {"name": "Cold Draught", "desc": "You melt faster, but drippings are richer"},
	"tallow_moon": {"name": "Tallow Moon", "desc": "Marked foes everywhere; gold and bombs pay double"},
	"long_night": {"name": "Long Night", "desc": "A bigger floor with two treasure rooms"},
	"smoky_halls": {"name": "Smoky Halls", "desc": "Your light is shorter, but rooms give twice"},
}
## Base melt: a full 4-floor candle (120 wax) lasts 8 minutes if you never get hit; kills, clears and drips buy
## time back. Wax is minutes on every night: a longer night's candle holds more of them, it melts no faster.
const DRAIN_PER_SEC := 120.0 / (8.0 * 60.0)
## The night speeds up as you climb: the melt per floor (x DRAIN_PER_SEC; [4] = the Clock Tower), and the
## deeper floors pay fewer minutes back, so a winning run still feels the clock (C1: wins used to end at
## 12:15 AM with a full candle). The Cellar stays as gentle as it was. Tables are indexed by floor - 1.
const FLOOR_DRAIN := [1.0, 1.1, 1.3, 1.45, 1.2]
## The most minutes Kindling can pour back in one room, per floor.
const KINDLE_CAP := [4.0, 4.0, 3.0, 2.0, 2.0]
## The QUICK clear bonus in minutes, per floor (CLEAN stays +1).
const QUICK_WAX := [2.0, 2.0, 1.0, 1.0, 1.0]
## Odds of wax in a cleared room's reward, a chest, an urn and a plain kill's drop (x the Cellar's), per floor.
const WAX_ODDS := [1.0, 1.0, 0.75, 0.65, 0.65]
## A low wick steadies on reaching the Chapel or the Belfry (the night's last two floors on any night): below
## STEADY_BELOW wax it gets up to STEADY_ADD minutes back (so a run that limps out of the Crypt is not doomed on
## arrival; a strong run gets nothing).
const STEADY_FLOORS := [3, 4]
const STEADY_BELOW := 40.0
const STEADY_ADD := 15.0
## Difficulty levels: every save slot has one (the Slots screen); Tonight's Candle always plays 2.
## difficulty() is the one place a level reaches the run: the melt (_physics_process), enemy contact /
## shot damage (enemy_dmg_mult), creature and guardian health (Enemy.setup), the marked-foe chance
## (champ_chance) and the wax a drip gives (wax_bonus). Level 2 is the game as it was made (all x1).
## Names and lines are shown with the number (Records.level_text); Game.MAX_LEVEL must match.
const LEVELS := {
	1: {"name": "Gentle", "line": "For learning: you melt slower and foes hit softer.",
		"melt": 0.75, "dmg": 0.5, "hp": 0.85, "champ": 1.0, "wax": 1.25},
	2: {"name": "Midnight", "line": "The night as it was made: a fair fight.",
		"melt": 1.0, "dmg": 1.0, "hp": 1.0, "champ": 1.0, "wax": 1.0},
	3: {"name": "Witching Hour", "line": "Harder: a faster melt, harder hits, more marked foes.",
		"melt": 1.1, "dmg": 1.2, "hp": 1.15, "champ": 1.5, "wax": 1.0},
	4: {"name": "Two O'Clock", "line": "Brutal: tough foes, cruel hits and thin wax.",
		"melt": 1.15, "dmg": 1.35, "hp": 1.3, "champ": 2.0, "wax": 0.85},
}
const DEFAULT_LEVEL := 2

var main: Node
var floor_num := 1
var layout := {}
var cur_cell := Vector2i.ZERO
var room: Room
var player: Player
var hud: Hud
var cam: Camera2D
var dark: CanvasModulate
var rooms_layer: Node2D
var actors: Node2D
var fx_layer: Node2D
var enemies: Array = []
var enemy_shots: Array = []
var hazards: Array = []
var moths: Array = []
var boss: Enemy
var boss_kind := ""
var paused := false
var transitioning := false
var room_spawned := false
var finished := false
var rng := RandomNumberGenerator.new()
var relic_pool: Array = []
var shop_discount := 1.0
var bomb_radius := 34.0
var kills := 0
var rooms_cleared := 0
var run_time := 0.0
var _shake := 0.0
var _bells := {}
var _heartbeat := 0.0
var _fade: ColorRect
var _kb_bomb_held := false
var room_hits := 0
var room_t0 := 0.0
var calm_t := 0.0       # v2.6: seconds this room has been clear and quiet (the pickup magnet waits for it, pickup.gd)
var swept := 0          # v2.6: drops the magnet lifted this run (the feel probe reads it)
var _sweep_snd := -9.0
# Kindling: quick kills chain and pour minutes back into the candle
var streak := 0
var streak_t := 0.0
var best_streak := 0
var room_streak_wax := 0.0
# Smoke Altar / Vigil bookkeeping
var floor_clean := 0
var boss_hits := 0
var pact := ""
var declined_smoke := false
var altar_floor := -1
var hits_total := 0
var freeze_t := 0.0
var _intro_root: Control


var candle_id := "tallow"
var omen := ""
var run_seed := 0
var _bell_paid := {}
var daily := false
var daily_date := ""   # Tonight's Candle: the date it was lit ("" for other runs)
var unlocked_this_run: Array = []
var level := DEFAULT_LEVEL   # this run's difficulty (LEVELS): the save slot's, 2 for Tonight's Candle
## How many floors tonight (the Long Night, docs/design/LONG_NIGHT.md): 4 (the house as it was made) up to
## Areas.max_floors(); the save slot's choice (Records.night_floors), 4 for Tonight's Candle.
var night_floors := LAST_FLOOR


func setup(params: Dictionary) -> void:
	candle_id = params.get("candle", Game.records.get("candle", "tallow"))
	if not Candles.is_unlocked(candle_id):
		candle_id = "tallow"
	daily = params.get("daily", false)
	# the slot's level (a continued run keeps the level it was lit at); Tonight's Candle is the same for all
	level = DEFAULT_LEVEL if daily else clampi(int(params.get("level", Game.level)), 1, LEVELS.size())
	# the night's length: the slot's (a continued run keeps its own); Tonight's Candle is the same for all
	night_floors = LAST_FLOOR if daily else clampi(int(params.get("floors", Records.night_floors())), Areas.MIN_FLOORS, Areas.max_floors())
	floor_areas = night_areas(night_floors)
	if params.has("seed"):
		run_seed = int(params["seed"])
	else:
		run_seed = randi()
	rng.seed = run_seed
	# a typed-in seed: fixed relic pool and guardians (Unlocks.fixed). A continued run says what it was.
	set_meta("seeded", bool(params["seeded"]) if params.has("seeded") else (params.has("seed") and not daily))
	# Tonight's Candle belongs to the night it was lit, even if it ends after midnight (QA-15)
	daily_date = str(params.get("date", "")) if daily else ""
	if daily and daily_date == "":
		daily_date = Time.get_date_string_from_system()


func _ready() -> void:
	main = get_parent()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	dark = CanvasModulate.new()
	add_child(dark)
	rooms_layer = Node2D.new()
	add_child(rooms_layer)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	fx_layer = Node2D.new()
	fx_layer.z_index = 20
	add_child(fx_layer)
	Lighting.attach(self)   # banded pixel light, the waning house, heat haze (lighting.gd)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	hud = Hud.new(self)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var fl := CanvasLayer.new()
	fl.layer = 9
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color(0.035, 0.027, 0.035, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)
	relic_pool = Unlocks.pool(self)   # relics that are in the house yet (the fixed pool for seeded runs)
	FloorGen.shuffle(relic_pool, rng)
	player = Player.new()
	player.world = self
	player.apply_candle(candle_id)   # the level's melt is read live in _physics_process (difficulty)
	# a longer night: every candle holds the extra half hours (it is lit at the same time on any night)
	player.wax += night_minutes() - Game.END_MINUTES
	player.wax_max += night_minutes() - Game.END_MINUTES
	actors.add_child(player)
	var cd: Dictionary = Candles.def_of(candle_id)
	if cd.has("start_relic"):
		Items.apply(cd["start_relic"], player, self)
	if cd.has("start_keepsake"):
		player.keepsake = cd["start_keepsake"]
		player.charge = int(Items.KEEPSAKES[player.keepsake]["pips"])
	Game.unlocked_now.connect(_on_unlock)
	Game.records["runs"] += 1
	Game.light_slot()   # an empty save slot gets its file with the first candle lit in it
	Game.save()
	_start_floor(RunSave.begin(self))   # floor 1, or the saved floor when continuing
	Primer.maybe_start(self)   # v2.7: a slot's first run is shown the controls first (scripts/ui/primer.gd)
	if not Game.records["seen_intro"] and main.autotest == null:
		_intro()


func _on_unlock(key: String) -> void:
	unlocked_this_run.append(key)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(func():
		hud.show_banner("NEW CANDLE: %s" % Candles.def_of(key)["name"].to_upper(), "Find it in the Candle Box on the title screen", 2.6)
		Audio.play("victory", -4.0))


func _exit_tree() -> void:
	if Game.unlocked_now.is_connected(_on_unlock):
		Game.unlocked_now.disconnect(_on_unlock)


func _intro() -> void:
	paused = true
	get_tree().paused = true
	var m := UI.modal(hud.root, "12:00 AM")
	var root: Control = m[0]
	_intro_root = root
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var v: VBoxContainer = m[1]
	for line in ["The old house wakes when the clock strikes twelve.",
			"You are Tallow, the last candle in the cellar.",
			"Burn down through %s floors to the belfry" % Records.number_word(night_floors),
			"and still the clock %s." % Records.night_end_phrase(night_floors),
			"",
			"Your wax is your life - and your time.",
			"Every hit melts you. Wax drippings mend you.",
			"",
			Controls.intro_line()]:
		v.add_child(UI.label(line, 8, UI.CREAM if line != "" else UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.button("Begin", func():   # UX-07: not the title button's name, and it waits 0.8 s
		Game.records["seen_intro"] = true
		Game.save()
		root.queue_free()
		paused = false
		get_tree().paused = false
		hud.show_hint(Controls.controls_hint(false), 8.0), 120))
	UI.hold_presses(v.get_child(v.get_child_count() - 1), 0.8)


# ---------------------------------------------------------------- floors & rooms

## The area each floor is built from (scripts/game/areas.gd): floor number -> area id, filled from
## Areas.sequence(night_floors) at setup (the Clock Tower on the floor above the last). `--area=<id>` puts an
## area on one floor for a test run.
var floor_areas := {}


## Floor number -> area id for a night of `n` floors: Areas.sequence(n), then the Clock Tower above the Belfry.
static func night_areas(n: int) -> Dictionary:
	var out := {}
	var seq := Areas.sequence(n)
	for i in seq.size():
		out[i + 1] = seq[i]
	out[seq.size() + 1] = "tower"
	return out


## This floor's entry (name, theme, dark, music, boss, bosses, space, area): its area's, or FLOORS[n].
func fdef(n := floor_num) -> Dictionary:
	return Areas.floor_def(floor_areas[n]) if floor_areas.has(n) else FLOORS[clampi(n, 1, FLOORS.size())]


## Who lives on this floor: its area's lodgers, or POOLS[n].
func fpool(n := floor_num) -> Dictionary:
	return Areas.pool(floor_areas[n]) if floor_areas.has(n) else POOLS[clampi(n, 1, POOLS.size())]


## The night's last floor (the Belfry): its guardian ends the night.
func last_floor() -> int:
	return night_floors


## The secret floor above the bells (the Clock Tower): the one above the night's last floor.
func is_tower(n := floor_num) -> bool:
	return n > night_floors


## The Long Night's depth curve (its own numbers, tuned with the bot; the 4-floor night never reads them): the
## Cellar and the Crypt are floors 1 and 2 of every night and keep their depths (the start of the night plays as
## it was made); the floors above stretch from the Crypt's depth (2) to the Belfry's (4), bent by NIGHT_CURVE
## (1 = evenly; below 1 the middle floors sit nearer the top).
const NIGHT_CURVE := 0.5
## "Your flame grows" after each guardian but the last: +FLAME_GROWTH damage, spread over a longer night so the
## whole night grows the flame as much as the 4-floor night's three guardians do (flame_growth()).
const FLAME_GROWTH := 0.15


## The floor's place in the night on the 4-floor scale: floor 1 = 1.0, floor 2 (the Crypt) = 2.0, the last floor
## (the Belfry) = 4.0, the Clock Tower = 5.0, the floors between stretched (NIGHT_CURVE 0.5; a 7-floor night: 1, 2,
## 2.89, 3.26, 3.55, 3.79, 4). On a 4-floor night it is the floor number, so every per-floor table reads exactly as it
## was made.
func depth(n := floor_num) -> float:
	if n > night_floors:
		return float(LAST_FLOOR + 1)
	if night_floors <= LAST_FLOOR or n <= 2:
		return float(n)
	var t := float(n - 2) / float(night_floors - 2)
	return 2.0 + float(LAST_FLOOR - 2) * pow(t, NIGHT_CURVE)


## The damage a guardian's fall adds ("Your flame grows"): 0.15 on a 4-floor night; a longer night has more
## guardians before the last, each adds less, the night as a whole the same +0.45.
func flame_growth() -> float:
	if night_floors <= LAST_FLOOR:
		return FLAME_GROWTH
	return FLAME_GROWTH * float(LAST_FLOOR - 1) / float(night_floors - 1)


## What FloorGen needs to build floor n of this night: its depth (floor size, the hard layouts' gate), its
## area (the tower, the crypt's skull piles) and the room layouts that area likes, which floor of the 4-floor
## house it stands in for (`key`: special rooms, house champions), the area's own champions and whether it is a
## wild floor (no treasure room, no shop).
func gen_night(n: int) -> Dictionary:
	var id := str(floor_areas.get(n, ""))
	var d := depth(n)
	var key := LAST_FLOOR + 1 if is_tower(n) else (1 if n == 1 else (LAST_FLOOR if n == night_floors else clampi(roundi(d), 2, LAST_FLOOR)))
	var ad := Areas.def(id)
	return {"depth": d, "area": id, "likes": ad.get("likes", RoomTemplates.FLOOR_LIKES.get(key, {})), "key": key,
		"minis": ad.get("minis", []), "wild": wild_floor(n)}


## A longer night's new areas are wild (the Long Night's own rule, so a longer night is not simply a richer one):
## no treasure room, no shop, and their guardian leaves wax and coins but no relic. The house's own four floors
## (Areas.HOUSE) keep theirs; every floor of a 4-floor night is the house's own.
func wild_floor(n := floor_num) -> bool:
	return night_floors > LAST_FLOOR and not is_tower(n) and not Areas.is_house(str(floor_areas.get(n, "")))


func floor_title() -> String:
	var t := "%s  -  %d/%d" % [fdef()["name"], floor_num, last_floor()]
	if is_tower():
		t = "%s  -  above the bells" % fdef()["name"]
	if omen != "":
		t += "\n" + OMENS[omen]["name"]
	return t


func recompute_discount() -> void:
	shop_discount = (0.6 if player.relics.has("wax_seal") else 1.0) * (0.75 if omen == "smoky_halls" else 1.0)


## Wax pickups give more under the Cold Draught (and with the level's wax income).
func wax_bonus() -> float:
	return (1.5 if omen == "draught" else 1.0) * float(difficulty()["wax"])


## This run's difficulty: the LEVELS entry of its level (melt, dmg, hp, champ, wax multipliers).
func difficulty() -> Dictionary:
	return LEVELS.get(level, LEVELS[DEFAULT_LEVEL])


## This floor's entry of a per-floor table (FLOOR_DRAIN, KINDLE_CAP, QUICK_WAX, WAX_ODDS, the marked-foe odds):
## read at the floor's depth (a longer night's middle floors sit between two entries; Areas.at_depth).
func floor_k(tbl: Array) -> float:
	return Areas.at_depth(tbl, depth())


## Contact damage of this floor's creatures (Enemy.TOUCH at its depth; guardians and champions have their own).
func touch_damage() -> float:
	return Enemy.touch_at(self)


func _start_floor(n: int) -> void:
	floor_num = n
	floor_clean = 0
	if n == 2:
		Game.unlock("tea_light")
	player.gutter_used = false
	# each floor has its own seeded generator, so a seed always builds the same house
	var frng := RandomNumberGenerator.new()
	frng.seed = hash("%d:%d" % [run_seed, n])
	rng.seed = hash("%d:loot:%d" % [run_seed, n])
	var last := omen
	omen = ""
	if n >= 2 and n <= last_floor() and frng.randf() < 0.4:   # no omens above the bells
		var keys: Array = OMENS.keys().filter(func(k): return k != last)
		omen = keys[frng.randi() % keys.size()]
	if omen == "long_night":
		layout = FloorGen.generate(n, frng, 3, 2, gen_night(n))
		player.heal(8.0)
	else:
		layout = FloorGen.generate(n, frng, 0, 1, gen_night(n))
	recompute_discount()
	boss_kind = Enemy.pick_boss(fdef(n)["bosses"], n, run_seed, Unlocks.fixed(self), last_floor())   # seeded / daily: the seed alone
	dark.color = fdef(n)["dark"]
	for c in layout["cells"].keys():
		layout["cells"][c]["seen"] = false
	cur_cell = layout["start"]
	if room:
		room.dispose()
		room = null
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	_clear_shots()
	room = _build_room(cur_cell)
	player.position = room.center() + Vector2(0, 8)
	player.vel = Vector2.ZERO
	cam.position = _cam_target(room)
	_on_enter_room()
	Audio.music(fdef(n)["music"])
	Audio.set_space(int(fdef(n).get("space", n)))
	var steady := 0.0
	if not is_tower(n) and n >= night_floors - (STEADY_FLOORS.size() - 1) and player.wax < STEADY_BELOW:   # the night's last two floors
		steady = minf(STEADY_ADD, STEADY_BELOW - player.wax)
		player.heal(steady)
		fx_text(player.global_position + Vector2(0, -30), "YOUR WICK STEADIES  +%d min" % int(steady), UI.GOLD)
	var omen_txt := ("   -   Omen: %s" % OMENS[omen]["name"]) if omen != "" else ""
	hud.show_banner(fdef(n)["name"].to_upper(), "Floor %d of %d   -   %s%s" % [n, last_floor(), Game.clock_text(clock_minutes()), omen_txt], 2.6)
	if steady > 0.0 and Game.tip("steady", 1):
		hud.show_hint("A new floor steadies a low wick: +%d min" % int(steady), 4.0)
	elif omen != "":
		hud.show_hint("%s: %s" % [OMENS[omen]["name"], OMENS[omen]["desc"]], 5.0)
	elif n >= 2 and n <= last_floor() and floor_k(FLOOR_DRAIN) > 1.0 and Game.tip("night_speeds", 1):   # say it once (FLOOR_DRAIN)
		hud.show_hint("The night speeds up: up here your wick burns faster", 4.0)
	if n == 1 and (Game.records["seen_intro"] or main.autotest != null) and int(Game.records["runs"]) <= 3:   # later: the chalk on the floor
		hud.show_hint(Controls.controls_hint(), 7.0)
	Tower.on_floor_start(self)   # the Clock Tower's own banner on the floor above the last
	Diary.on_floor_start(self)   # v2.5: where this floor keeps its diary pages (scripts/game/diary.gd)
	RunSave.on_floor_start(self)   # Save & Continue: snapshot the start of this floor


func _cam_target(r: Room) -> Vector2:
	return r.position + Vector2(Room.W / 2.0, Room.H / 2.0)


func _build_room(c: Vector2i) -> Room:
	var r := Room.new()
	var neighbours := {}
	for d in FloorGen.DIRS:
		if layout["cells"].has(c + d):
			var nc: Dictionary = layout["cells"][c + d]
			neighbours[d] = nc["type"]
			if nc["type"] == "secret" and not nc.get("revealed", false):
				neighbours[d] = "hidden"
			if layout["cells"][c]["type"] == "secret" and not layout["cells"][c].get("revealed", false):
				pass
	rooms_layer.add_child(r)
	r.build(self, c, layout["cells"][c], fdef()["theme"], neighbours)
	Juice.of(self).attach_stains(r)
	# restore persistent pickups
	for rec in layout["cells"][c]["pickups"]:
		_spawn_pickup_node(r, rec)
	if layout["cells"][c].get("altar", false):
		_spawn_altar_visual(r)
	Specials.on_build(self, r)   # special rooms: props, toll marks
	Tower.on_build(self, r)      # the ladder of light, the Keeper's floor dial
	return r


func _on_enter_room() -> void:
	var d: Dictionary = room.data
	Audio.enter_room(d["type"], d["cleared"])
	d["visited"] = true
	d["seen"] = true
	for dd in FloorGen.DIRS:
		if layout["cells"].has(cur_cell + dd):
			var nb: Dictionary = layout["cells"][cur_cell + dd]
			if nb["type"] != "secret" or nb.get("revealed", false):
				nb["seen"] = true
	player.coat_ready = true
	RelicFx.on_enter_room(self)
	room_spawned = false
	calm_t = 0.0
	room_hits = 0
	room_streak_wax = 0.0
	if Specials.on_enter_room(self):   # a mini-boss room handles its own entry
		return
	match d["type"]:
		"treasure":
			if not d.get("stocked", false):
				d["stocked"] = true
				# a choice of two: take one, the other crumbles
				var a := add_pickup("relic", room.center() + Vector2(-26, 2), _next_relic())
				var b: Pickup
				if floor_num == 1 and player.keepsake == "":
					b = add_pickup("keepsake", room.center() + Vector2(26, 2), Unlocks.pick_keepsake(self))
				else:
					b = add_pickup("relic", room.center() + Vector2(26, 2), _next_relic())
				a.record["group"] = "treasure"
				b.record["group"] = "treasure"
				hud.show_hint("Choose one relic. The other will crumble.", 3.0)
		"shop":
			if not d.get("stocked", false):
				d["stocked"] = true
				_stock_shop()
			_spawn_keeper()
			if not d.get("greeted", false):
				d["greeted"] = true
				hud.show_banner("THE TALLOW MERCHANT", "Coins for wax and wonders", 1.6)
		"boss":
			if not d["cleared"]:
				_start_boss()
				return
		"secret":
			if not d.get("stocked", false):
				d["stocked"] = true
				_stock_hollow()
	if not d["cleared"]:
		room.set_open(false, true)
		Audio.play("door_close", -3.0)
		if "clock" in player.rites:
			freeze_t = 1.5
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(_spawn_room_enemies)


## Marked foes per floor (by depth; [4] = the Clock Tower), times the level's.
const CHAMP_ODDS := [0.03, 0.06, 0.09, 0.12, 0.14]


func champ_chance() -> float:
	return floor_k(CHAMP_ODDS) * float(difficulty()["champ"])


func _spawn_room_enemies() -> void:
	var champs_left := 2 if omen == "tallow_moon" else 1
	var pool: Dictionary = fpool()
	var depth: int = room.data["dist"]
	var opening := FloorGen.opening_now(layout, room.data)   # floor 1: the first two rooms call slow lodgers, no marked foes
	for slot in room.spawn_slots():
		var letter: String = slot[0]
		var pos: Vector2 = slot[1]
		if letter == "T":
			if floor_num >= 2 and rng.randf() < 0.18:
				spawn_enemy("mimic", pos)
			else:
				add_pickup("chest", pos)
			continue
		if pos.distance_to(player.global_position) < 56.0:
			pos = random_free_spot(player.global_position, 72.0)
		var list: Array = FloorGen.OPENING_POOL[letter] if opening else pool[letter]
		var champ := ""
		if champs_left > 0 and not opening and rng.randf() < champ_chance() * (2.0 if omen == "tallow_moon" else 1.0):
			champs_left -= 1
			champ = ["ember", "gilded", "sooty", "chilled"][rng.randi() % 4]
			if Game.tip("marked"):
				hud.show_hint("A marked foe glows: tougher, but it pays out", 2.5)
		spawn_enemy(list[rng.randi() % list.size()], pos, champ)
	# deeper rooms get one extra guest
	if depth >= 4 and rng.randf() < 0.5:
		var list2: Array = pool["e"]
		spawn_enemy(list2[rng.randi() % list2.size()], random_free_spot(player.global_position, 80.0))
	room_spawned = true
	room_t0 = run_time
	if count_enemies() == 0:
		_clear_room()


func _start_boss() -> void:
	room.set_open(false, true)
	player.frozen = true
	var kind: String = boss_kind if boss_kind != "" else fdef()["boss"]
	var name: String = Enemy.DEFS[kind]["name"]
	Audio.music("final_boss" if floor_num >= last_floor() else "boss")
	Audio.play("boss_roar")
	Juice.of(self).boss_card(kind, name)
	var tw := create_tween()
	tw.tween_interval(0.5)   # v2.4: was 0.9; the guardian's entrance (BossIntro) is the rest of the reveal
	tw.tween_callback(func():
		boss = spawn_enemy(kind, room.center() + Vector2(0, -24))
		hud.set_boss(name, true)
		player.frozen = false
		room_spawned = true
		BossIntro.play(self, boss))   # its entrance (1.4-2.0 s, any tap skips); it shakes on its own beats


## v2.6 (feel): how long a room change and a trapdoor take without control (were 0.34 s and 0.45 + 0.5 s fades).
const PAN_TIME := 0.27
const DROP_OUT := 0.32
const DROP_IN := 0.4


func go_through(dir: Vector2i) -> void:
	if transitioning:
		return
	var next := cur_cell + dir
	if not layout["cells"].has(next):
		return
	transitioning = true
	player.frozen = true
	_clear_shots()
	var old := room
	var nr := _build_room(next)
	cur_cell = next
	room = nr
	player.position = nr.entry_point(-dir)
	player.vel = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(cam, "position", _cam_target(nr), PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		old.dispose()
		transitioning = false
		player.frozen = false
		_on_enter_room())


func descend() -> void:
	if transitioning or Tower.on_descend(self):   # the ladder of light climbs instead
		return
	if altar_floor == floor_num and pact != "smoke":
		declined_smoke = true
	transitioning = true
	player.frozen = true
	Audio.play("trapdoor")
	Juice.of(self).descended()
	var tw := create_tween()
	tw.tween_property(player, "scale", Vector2(0.2, 0.2), DROP_OUT - 0.04)
	tw.parallel().tween_property(_fade, "color:a", 1.0, DROP_OUT)
	tw.tween_callback(func():
		player.scale = Vector2.ONE
		_start_floor(floor_num + 1)
		player.frozen = false
		transitioning = false)
	tw.tween_property(_fade, "color:a", 0.0, DROP_IN)


func _clear_room() -> void:
	var d: Dictionary = room.data
	if d["cleared"]:
		return
	d["cleared"] = true
	rooms_cleared += 1
	RelicFx.on_clear(self)
	if d["type"] == "normal":
		charge_keepsake(2 if run_time - room_t0 <= 8.0 + 2.5 * depth() else 1)
	room.set_open(true)
	room.light_candles()
	Juice.of(self).room_cleared()
	Audio.play("room_clear")
	Audio.set_intensity(0.5)
	if player.hourglass > 0:
		player.heal(player.hourglass)
		fx_text(player.global_position + Vector2(0, -26), "+%d min" % int(player.hourglass), UI.GOLD)
	if d["type"] == "normal":
		_room_reward(room.center() + Vector2(0, 4))
		if omen == "smoky_halls":
			_room_reward(room.center() + Vector2(14, 4))
		if room_hits == 0:
			floor_clean += 1
			player.heal(1.0)
			fx_text(player.global_position + Vector2(0, -34), "CLEAN  +1 min", UI.GOLD)
		var par := 8.0 + 2.5 * depth()
		var quick := floorf(floor_k(QUICK_WAX))   # whole minutes, as the text says (a longer night's middle floors)
		if run_time - room_t0 <= par and quick > 0.0:
			player.heal(quick)
			fx_text(player.global_position + Vector2(0, -44), "QUICK  +%d min" % int(quick), UI.EMBER)
	Specials.on_clear(self)   # a finished Seance or a beaten mini-boss pays out
	Diary.on_clear(self)      # the Kitchen's, Library's and Attic's page lies in one of their rooms


func _room_reward(pos: Vector2) -> void:
	if player.keepsake != "" and rng.randf() < 0.08:
		add_pickup("match", pos + Vector2(10, 0))
	if rng.randf() > 0.6 + player.luck * 0.3:
		return
	var roll := rng.randf()
	var wk := floor_k(WAX_ODDS)   # deeper floors: the wax share of the reward goes to coins
	if roll < 0.32 * wk:
		add_pickup("wax_small", pos)
	elif roll < 0.40 * wk:
		add_pickup("wax_big", pos)
	elif roll < 0.72:
		for i in rng.randi_range(2, 4):
			add_pickup("coin", pos, "", 0, Vector2.from_angle(rng.randf() * TAU) * 40.0)
	elif roll < 0.88:
		add_pickup("bomb", pos)
	else:
		add_pickup("chest", pos)


func _next_relic() -> String:
	return RelicFx.next_relic(self)
	for i in relic_pool.size():
		var id: String = relic_pool[i]
		if not id in player.relics:
			relic_pool.remove_at(i)
			return id
	return "flask_red"


func _stock_shop() -> void:
	var c := room.center()
	add_pickup("relic", c + Vector2(-40, -4), _next_relic(), 10 + roundi(2.0 * depth()))
	var tonics := Items.TONICS.keys()
	add_pickup("tonic", c + Vector2(0, -4), tonics[rng.randi() % tonics.size()], 5)
	if floor_num >= 2 and rng.randf() < 0.35:
		var ks: Array = Unlocks.keepsakes(self).filter(func(k): return k != player.keepsake)
		add_pickup("keepsake", c + Vector2(40, -4), ks[rng.randi() % ks.size()], 8)
	else:
		add_pickup("wax_big", c + Vector2(40, 0), "", 4)


func _stock_hollow() -> void:
	var c := room.center()
	hud.show_banner("A HOLLOW", "Someone hid this from the dark", 1.6)
	var roll := rng.randf()
	if roll < 0.45:
		add_pickup("wax_big", c + Vector2(-16, 0))
		add_pickup("wax_big", c + Vector2(16, 0))
		for i in 3:
			add_pickup("coin", c + Vector2(0, 14), "", 0, Vector2.from_angle(rng.randf() * TAU) * 40.0)
	elif roll < 0.8:
		add_pickup("relic", c, _next_relic())
	else:
		for i in 2:
			add_pickup("bomb", c + Vector2(-12 + 24 * i, 0))
		add_pickup("match", c + Vector2(0, 16))
		add_pickup("chest", c + Vector2(0, -20))
	Diary.on_hollow(self, c)   # someone hid a diary page here too, sometimes


func _spawn_keeper() -> void:
	var c := room.center()
	var keeper := AnimatedSprite2D.new()
	keeper.sprite_frames = Art.creature("dwarf_m")
	keeper.play("idle")
	keeper.centered = false
	keeper.offset = Vector2(-8, -28)
	keeper.position = c + Vector2(0, -44) - room.position
	keeper.flip_h = true
	room.objects.add_child(keeper)


# ---------------------------------------------------------------- pickups

func add_pickup(kind: String, pos: Vector2, item := "", price := 0, pop_vel := Vector2.ZERO) -> Pickup:
	var rec := {"kind": kind, "pos": pos, "item": item, "price": price}
	room.data["pickups"].append(rec)
	var p := _spawn_pickup_node(room, rec)
	if pop_vel != Vector2.ZERO:
		p.pop(pop_vel)
	return p


func _spawn_pickup_node(r: Room, rec: Dictionary) -> Pickup:
	var p: Pickup = Specials.new_pickup(rec)   # offers in special rooms are Pickups with their own look
	p.setup(self, rec["kind"], rec["pos"] - r.position, rec["item"], rec["price"])
	p.record = rec
	r.objects.add_child(p)
	return p


## A pickup that is never saved with the room (spilled wax).
func add_loose(kind: String, pos: Vector2, value: float, pop_vel: Vector2) -> Pickup:
	var p := Pickup.new()
	p.setup(self, kind, pos - room.position, "", 0)
	p.value = value
	p.record = {}
	room.objects.add_child(p)
	p.pop(pop_vel)
	return p


## v2.6: the pickup magnet lifted a drop (pickup.gd): one soft whoosh for a room's sweep, not one per coin.
func on_sweep() -> void:
	swept += 1
	if run_time - _sweep_snd > 1.2:
		_sweep_snd = run_time
		Audio.play("dodge", -6.0, 0.05, 1.35)


func forget_pickup(rec: Dictionary) -> void:
	if room:
		room.data["pickups"].erase(rec)


func collect_item(id: String, pos: Vector2, rec := {}) -> void:
	var group: String = rec.get("group", "")
	if group != "" and room:
		for o in room.objects.get_children():
			if o is Pickup and not o.taken and o.record and o.record.get("group", "") == group and o.record != rec:
				o.taken = true
				forget_pickup(o.record)
				fx_smoke(o.global_position + Vector2(0, -14))
				var tw := o.create_tween()
				tw.tween_property(o, "modulate:a", 0.0, 0.4)
				tw.tween_callback(o.queue_free)
	if id == "":
		return
	var was_done := Items.rite_of(id) in player.rites
	Records.take(self, id)   # the Journal: taken / seen
	Items.apply(id, player, self)
	Juice.of(self).relic_taken(id)
	Audio.play("item_get")
	var rite := Items.check_rite(id, player, self)
	if rite == "":
		hud.show_banner(Items.display_name(id).to_upper(), Items.desc(id), 2.0)
	elif was_done or not Items.rite_of(id) in player.rites:
		hud.show_banner(Items.display_name(id).to_upper(), "%s   (%s)" % [Items.desc(id), rite], 2.0)
	fx_ring(pos + Vector2(0, -16), Color(1.0, 0.8, 0.4))
	player._happy_face = 1.5


func open_chest(pos: Vector2) -> void:
	var n := rng.randi_range(2, 4)
	var wk := floor_k(WAX_ODDS)   # deeper floors: fewer drips in the chests (the rest are coins)
	for i in n:
		var roll := rng.randf()
		var k := "coin"
		if roll < 0.25 * wk:
			k = "wax_small"
		elif roll >= 0.25 and roll < 0.35:
			k = "bomb"
		elif roll >= 0.35 and roll < 0.35 + 0.07 * wk:
			k = "wax_big"
		add_pickup(k, pos + Vector2(0, 4), "", 0, Vector2.from_angle(rng.randf() * TAU) * 60.0)
	if rng.randf() < 0.22:
		var tonics := Items.TONICS.keys()
		add_pickup("tonic", pos + Vector2(0, 14), tonics[rng.randi() % tonics.size()])


func roll_obstacle_drop(pos: Vector2) -> void:
	var r := rng.randf()
	if r < 0.16 + player.luck * 0.1:
		add_pickup("coin", pos, "", 0, Vector2.from_angle(rng.randf() * TAU) * 30.0)
	elif r < 0.25 - 0.09 * (1.0 - floor_k(WAX_ODDS)):   # deeper floors: fewer drips in the urns
		add_pickup("wax_small", pos)
	elif r >= 0.25 and r < 0.28:
		add_pickup("bomb", pos)


# ---------------------------------------------------------------- enemies

func spawn_enemy(kind: String, pos: Vector2, champ := "") -> Enemy:
	if room == null:
		return null
	var r: float = Enemy.DEFS[kind]["r"]
	if not Enemy.DEFS[kind].get("fly", false) and room.blocked(pos, r):
		pos = free_spot_near(pos, r)
	var e := Enemy.new()
	e.setup(self, kind, pos - room.position, floor_num)
	e.champ = champ
	room.objects.add_child(e)
	enemies.append(e)
	return e


func count_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			n += 1
	return n


func on_enemy_killed(e: Enemy) -> void:
	kills += 1
	Records.on_kill(self, e)   # the Journal: lodgers snuffed, guardians beaten
	Diary.on_kill(self, e)     # a diary page: a guardian's first fall, a champion, a marked foe
	RelicFx.on_kill(self, e)
	Audio.play("enemy_die")
	fx_poof(e.global_position + Vector2(0, -6), false, 1.4)
	if not e.def.get("small_fry", false):   # swarm moths and melt drops do not feed Kindling
		_kindle(e.global_position)
	Juice.of(self).enemy_killed(e)
	if e.boss:
		_boss_down(e)
		return
	for rep in (2 if omen == "tallow_moon" and e.champ in ["gilded", "sooty"] else 1):
		_champ_drop(e)
	if e.champ != "":
		return
	_plain_drop(e)


func _champ_drop(e: Enemy) -> void:
	match e.champ:
		"ember":
			for i in 1:
				add_pickup("wax_small", e.global_position, "", 0, Vector2.from_angle(rng.randf() * TAU) * 30.0)
		"gilded":
			for i in 5:
				add_pickup("coin", e.global_position, "", 0, Vector2.from_angle(rng.randf() * TAU) * 45.0)
		"sooty":
			add_pickup("bomb", e.global_position)
		"chilled":
			add_pickup("wax_small", e.global_position)


func _plain_drop(e: Enemy) -> void:
	var r := rng.randf()
	var luck := player.luck
	var need := 0.08 if player.wax < 25.0 else 0.0   # a nearly spent candle still finds drips
	if r < (0.04 + luck * 0.04) * floor_k(WAX_ODDS) + need:
		add_pickup("wax_small", e.global_position)
	elif r < 0.19 + luck * 0.1:
		add_pickup("coin", e.global_position, "", 0, Vector2.from_angle(rng.randf() * TAU) * 25.0)
	elif r < 0.215 + luck * 0.1:   # was `r < 0.165`, below the coin band: plain kills never dropped a bomb
		add_pickup("bomb", e.global_position)


## Kindling streak: kills within 2.2 s of each other pour minutes back into the candle.
func _kindle(pos: Vector2) -> void:
	streak = streak + 1 if streak_t > 0.0 else 1
	streak_t = 2.2
	best_streak = maxi(best_streak, streak)
	if streak >= 2:
		Audio.play("tick", -2.0, 0.0, 1.0 + 0.08 * mini(streak, 10))
	var gain := 0.0
	if streak == 3:
		gain = 1.0
	elif streak == 5:
		gain = 2.0
	elif streak >= 6:
		gain = 1.0
	var cap := floor_k(KINDLE_CAP)
	if gain > 0.0 and room_streak_wax < cap:
		gain = minf(gain, cap - room_streak_wax)
		room_streak_wax += gain
		player.heal(gain)
		if Game.tip("kindling"):
			hud.show_hint("Kill quickly to keep the streak: Kindling pours minutes back in", 3.0)
		var word := "KINDLING" if streak < 5 else ("BLAZE" if streak < 8 else "INFERNO")
		fx_text(player.global_position + Vector2(0, -40), "%s x%d  +%d min" % [word, streak, int(gain)], UI.EMBER)
	if streak >= 8 and Game.has_method("unlock"):
		Game.unlock("party")


func on_boss_hp(e: Enemy) -> void:
	hud.set_boss_frac(e.hp / e.max_hp)


## After a floor boss: sometimes a Smoke Altar (relics for minutes), else a Vigil for struggling runs.
func _offer_altar() -> void:
	var chance := 0.2 + (0.3 if boss_hits == 0 else 0.0) + 0.05 * floor_clean
	chance = minf(chance, 0.85 if chance < 1.0 else 1.0)
	var c := room.center()
	if pact != "smoke" and (declined_smoke or player.wax < 48.0):
		if rng.randf() < 0.6:
			var a := add_pickup("relic", c + Vector2(-44, -34), _next_relic())
			var gift := "vigil_candle" if rng.randf() < 0.65 or player.relics.has("wax_seal") else "wax_seal"
			var b := add_pickup("relic", c + Vector2(44, -34), gift)
			a.record["group"] = "vigil"
			b.record["group"] = "vigil"
			hud.show_banner("A VIGIL", "Take one gift. The other will crumble.", 2.0)
		return
	if rng.randf() < chance:
		altar_floor = floor_num
		var strong := ["twin_wick", "candelabra", "will_o_wisp", "blue_flame", "phoenix_feather"]
		room.data["altar"] = true
		for side in [-1, 1]:
			var id := _next_relic()
			var tries := 0
			while id in ["beeswax", "tallow_heart"] and tries < 6:
				relic_pool.append(id)
				id = _next_relic()
				tries += 1
			var p := add_pickup("relic", c + Vector2(48 * side, -34), id)
			p.record["cost_wax"] = 25 if id in strong else 15
			p.queue_free()
			_spawn_pickup_node(room, p.record)
		_spawn_altar_visual(room)
		hud.show_banner("THE SMOKE ALTAR", "Pay in minutes. They never come back.", 2.4)


func _spawn_altar_visual(r: Room) -> void:
	var altar := Sprite2D.new()
	altar.texture = Art.tex("rooms/candelabra_unlit")
	altar.offset = Vector2(0, -12)
	altar.position = r.center() + Vector2(0, -32) - r.position
	r.objects.add_child(altar)
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(0.8, 0.3, 0.45)
	l.energy = 0.9
	l.texture_scale = 0.6
	l.position = Vector2(0, -16)
	altar.add_child(l)
	var tw := altar.create_tween().set_loops()
	tw.tween_callback(func(): fx_smoke(altar.global_position + Vector2(0, -26)))
	tw.tween_interval(0.6)


func on_boss_phase(ph: int) -> void:
	shake(5.0)
	if is_instance_valid(boss):
		Lighting.shockwave(self, boss.global_position + Vector2(0, -12), 56.0, 2.0)
	Audio.play("boss_roar")
	hud.show_banner("", "The bell answers..." if ph == 2 else "It is nearly two!", 1.2)


func _boss_down(e: Enemy) -> void:
	hud.set_boss_frac(0)
	Juice.of(self).boss_finale(e)
	Audio.play("boss_die")
	shake(7.0)
	hitstop(0.35, 0.15)
	_clear_shots()
	for m in enemies:
		if is_instance_valid(m) and m != e and m.alive:
			m.hp = 0
			m.alive = false
			fx_poof(m.global_position + Vector2(0, -6), false)
			m.queue_free()
	var pos := e.global_position
	boss_hits = room_hits
	charge_keepsake(99)
	if floor_num >= last_floor():
		player.frozen = true
	var tw := create_tween()
	tw.tween_property(e, "modulate", Color(3, 2, 1.5, 0.0), 1.2)
	tw.tween_callback(e.queue_free)
	tw.tween_callback(func():
		hud.set_boss("", false)
		if floor_num >= last_floor():
			if Tower.on_last_boss_down(self):   # a ladder of light (before 1:00 AM) or the true ending
				return
			_victory()
			return
		_clear_room()
		if not wild_floor():   # a wild area's guardian leaves no relic (a longer night's new areas)
			add_pickup("relic", room.center() + Vector2(-24, 0), _next_relic())
		add_pickup("wax_big", room.center() + Vector2(24, 4))
		add_pickup("trapdoor", free_spot_near(room.center() + Vector2(0, 36), 8.0))
		for i in 4:
			add_pickup("coin", room.center() + Vector2(0, 14), "", 0, Vector2.from_angle(rng.randf() * TAU) * 50.0)
		player.damage += flame_growth()
		fx_text(room.center() + Vector2(0, -30), "Your flame grows", UI.GOLD)
		if str(fdef().get("area", "")) == "chapel":   # the Altar Pillar: snuff the Chapel's guardian
			Game.unlock("pillar")
		_offer_altar()
		Audio.music(fdef()["music"]))
	for i in 6:
		var t2 := create_tween()
		t2.tween_interval(i * 0.15)
		t2.tween_callback(func(): fx_poof(pos + Vector2(randf_range(-14, 14), randf_range(-26, 0)), false, 2.0))


# ---------------------------------------------------------------- shots

func shoot_player(pos: Vector2, dir: Vector2, p: Player, dmg: float) -> void:
	var s := Shot.new()
	var kind := "ember_blue" if p.blue else "ember"
	if p.shot_scale > 1.0 and Art.has("fx/ember_big_f0"):
		kind = "ember_big"
	s.setup(self, pos, dir * p.shot_speed + p.vel * 0.25, kind, true)
	s.dmg = dmg
	s.life = p.shot_range / p.shot_speed
	s.pierce = p.pierce
	s.homing = p.homing
	s.burn = p.burn
	s.knock = p.knockback
	s.radius = 3.0 * p.shot_scale
	RelicFx.on_shot_made(s, p)
	Moves.on_shot_made(s, p)   # v2.3: Flare Up's fire, the Black Taper's black flame
	fx_layer.add_child(s)


func enemy_shot(pos: Vector2, v: Vector2, kind := "bullet_purple") -> void:
	if finished:
		return
	var s := Shot.new()
	s.setup(self, pos, v, kind, false)
	s.life = 4.0
	s.radius = 3.0
	fx_layer.add_child(s)
	enemy_shots.append(s)


func burst(pos: Vector2, n: int, spd: float, kind: String, offset := 0.0) -> void:
	for i in n:
		enemy_shot(pos, Vector2.from_angle(offset + TAU * i / n) * spd, kind)


func lob(from: Vector2, to: Vector2) -> void:
	var s := Shot.new()
	s.setup(self, from, Vector2.ZERO, "bullet_green", false)
	s.lob = true
	s.lob_from = from
	s.lob_to = to + Vector2(0, -6)
	fx_layer.add_child(s)


func _clear_shots() -> void:
	for s in fx_layer.get_children():
		if s is Shot:
			s.queue_free()
	enemy_shots.clear()


func nearest_enemy(pos: Vector2, max_d := 9999.0) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.active:
			var d: float = e.global_position.distance_squared_to(pos)
			if d < bd:
				bd = d
				best = e
	return best


func assist_aim(pos: Vector2, dir: Vector2) -> Vector2:
	if not Game.settings["aim_assist"]:
		return dir
	var best := dir
	var best_a := deg_to_rad(20.0)
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or not e.active:
			continue
		var to: Vector2 = e.global_position + Vector2(0, -e.half_h - e._jump_h) - pos
		if to.length() > player.shot_range * 1.3:
			continue
		var a := absf(dir.angle_to(to))
		if a < best_a:
			best_a = a
			best = to.normalized()
	return best


## v2.6 Aim: Auto (touch, Settings > Controls > Aim): where the right thumb fires while it rests on the screen -
## the nearest foe (in the embers' reach first), the one in front of Tallow first, one in the open before one behind cover; it keeps
## its target unless another is clearly better (no flicking between two). No foe: straight ahead. Only the
## direction changes: the fire rate and the damage are the player's own.
var _auto_tgt: Enemy
func auto_aim(p: Player) -> Vector2:
	var from := p.global_position + Vector2(0, -6)
	var front := p.vel.normalized() if p.vel.length() > 20.0 else p.facing
	var best: Enemy = null
	var best_s := INF
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or not e.active or e.intro or not e.visible:
			continue
		var to: Vector2 = e.global_position + Vector2(0, -e.half_h - e._jump_h) - from
		var d := to.length()
		if d < 0.5:
			continue
		var s := d * (1.35 - 0.35 * front.dot(to / d))   # in front x1.0, beside x1.35, behind x1.7
		if not room._clear_line(from, e.global_position):
			s *= 1.5
		if d > p.shot_range * 1.3:
			s *= 2.0   # out of the embers' reach: only when nothing nearer is up
		if e == _auto_tgt:
			s *= 0.75
		if s < best_s:
			best_s = s
			best = e
	_auto_tgt = best
	if best == null:
		return p.facing
	return (best.global_position + Vector2(0, -best.half_h - best._jump_h) - from).normalized()


func enemy_dmg_mult() -> float:
	# by depth (the Clock Tower hits as hard as the Belfry); the level scales every blow a foe lands
	return (1.0 + 0.12 * (minf(depth(), float(LAST_FLOOR)) - 1.0)) * float(difficulty()["dmg"])


func time_scale_enemies() -> float:
	if freeze_t > 0.0:
		return 0.0
	return 1.0 - player.slow_aura


# ---------------------------------------------------------------- keepsakes & rites

func keepsake_full() -> bool:
	return player.keepsake != "" and player.charge >= int(Items.KEEPSAKES[player.keepsake]["pips"])


func use_keepsake() -> void:
	if paused or player.dead or transitioning or finished or not keepsake_full():
		return
	player.charge = 0
	Items.use_keepsake(player.keepsake, player, self)
	Game.vibrate(40)


func charge_keepsake(n: int) -> void:
	if player.keepsake == "":
		return
	var full := int(Items.KEEPSAKES[player.keepsake]["pips"])
	var was_full := player.charge >= full
	player.charge = mini(player.charge + n, full)
	if not was_full and player.charge >= full:
		Audio.play("tick", 0.0, 0.0, 1.8)
		hud.show_hint("%s is ready" % Items.display_name(player.keepsake), 1.6)


func on_keepsake_taken(id: String, pos: Vector2, rec: Dictionary) -> void:
	Records.take(self, id)   # the Journal: taken / seen
	Audio.play("item_get")
	Juice.of(self).relic_taken(id)
	if Game.tip("keepsake"):
		hud.show_hint(Controls.keepsake_hint(), 3.5)
	hud.show_banner(Items.display_name(id).to_upper(), Items.desc(id), 2.0)
	fx_ring(pos + Vector2(0, -16), UI.GOLD)
	var group: String = rec.get("group", "")
	if group != "":
		collect_item("", pos, rec)   # crumble the other choice


func on_rite(r: String) -> void:
	hud.show_banner(Items.RITES[r]["name"].to_upper(), Items.RITES[r]["desc"], 2.6)
	fx_ring(player.global_position + Vector2(0, -12), UI.EMBER)
	Audio.play("victory", -6.0)


## The nearest walkable point to `pos` (spawns must never land inside rocks or columns).
func free_spot_near(pos: Vector2, r := 6.0) -> Vector2:
	var best := room.center()
	var bd := 1e9
	for y in Room.ROWS:
		for x in Room.COLS:
			var c := Vector2i(x, y)
			if room.char_at(c) in Room.SOLID or room.char_at(c) == "S":
				continue
			var p := room.cell_center(c) + Vector2(0, 4)
			if room.blocked(p, r):
				continue
			var d := p.distance_squared_to(pos)
			if d < bd:
				bd = d
				best = p
	return best


func random_free_spot(away_from: Vector2, min_d: float) -> Vector2:
	for i in 40:
		var c := Vector2i(rng.randi_range(1, 13), rng.randi_range(1, 7))
		if room.char_at(c) in [".", "e", "h", "f", "T"]:
			var p := room.cell_center(c) + Vector2(0, 4)
			if p.distance_to(away_from) >= min_d and not room.blocked(p, 7.0):
				return p
	return room.center()


# ---------------------------------------------------------------- bombs, drips, moths

func place_bomb() -> void:
	if paused or player.dead or player.bombs <= 0 or transitioning:
		return
	player.bombs -= 1
	Audio.play("bomb_place")
	var b := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	for t in Art.seq("0x72/bomb"):
		sf.add_frame("default", t)
	sf.set_animation_speed("default", 6.0)
	b.sprite_frames = sf
	b.play("default")
	b.offset = Vector2(0, -6)
	b.position = player.position - room.position + Vector2(0, 1)
	room.objects.add_child(b)
	var r := room
	var tw := b.create_tween()
	tw.tween_property(b, "speed_scale", 4.0, 1.4)
	tw.tween_callback(func(): _explode(b.global_position, r); b.queue_free())


func _explode(pos: Vector2, r: Room) -> void:
	if r != room:
		return
	Audio.play("explosion")
	shake(6.0)
	Game.vibrate(80)
	var ex := AnimatedSprite2D.new()
	ex.sprite_frames = Art.anim("fx/explosion", 16.0, false)
	ex.position = pos + Vector2(0, -12)
	ex.material = Art.unshaded
	fx_layer.add_child(ex)
	ex.play("default")
	ex.animation_finished.connect(ex.queue_free)
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.color = Color(1, 0.6, 0.3)
	l.energy = 1.6
	l.texture_scale = 0.9
	ex.add_child(l)
	var lt := l.create_tween()
	lt.tween_property(l, "energy", 0.0, 0.5)
	fx_scorch(pos)
	Lighting.shockwave(self, pos + Vector2(0, -6), bomb_radius, 2.0)
	r.blast(pos, bomb_radius)
	RelicFx.on_blast(self, pos)
	var hd := r.reveal_near(pos, bomb_radius)
	if hd != Vector2i.ZERO and layout["cells"].has(r.cell + hd):
		layout["cells"][r.cell + hd]["revealed"] = true
		layout["cells"][r.cell + hd]["seen"] = true
		r.add_door(hd)
		for i in 3:
			fx_debris(pos + Vector2(randf_range(-8, 8), randf_range(-8, 4)), "R")
		Audio.play("door_open")
		hud.show_hint("A hollow in the wall!", 2.0)
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.global_position.distance_to(pos) < bomb_radius + e.radius:
			e.active = true
			e.take_hit(10.0 + 2.0 * depth(), (e.global_position - pos).normalized() * 150.0)
	if player.global_position.distance_to(pos) < bomb_radius * 0.8:
		Records.blame("bomb")
		player.hurt(10.0, player.global_position - pos)


func spawn_hot_drip(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex("rooms/decal_wax_puddle") if Art.has("rooms/decal_wax_puddle") else Art.tex("pickups/wax_small")
	s.position = pos
	s.modulate = Color(1.0, 0.6, 0.3, 0.9)
	s.z_index = -5
	fx_layer.add_child(s)
	hazards.append([s, 2.5, 0.0])


func add_moth() -> void:
	var m := Sprite2D.new()
	m.texture = Art.tex("items/moth_friend")
	m.z_index = 6
	fx_layer.add_child(m)
	moths.append(m)


# ---------------------------------------------------------------- player events

func on_player_hurt(amount: float) -> void:
	room_hits += 1
	Records.on_hurt(self)   # who landed the blow (the death note)
	hits_total += 1
	if streak >= 3:
		fx_text(player.global_position + Vector2(0, -40), "doused", UI.DIM)
	streak = 0
	streak_t = 0.0
	# Spilled Wax: half the melted wax splashes out; grab it back before it cools
	if amount >= 2.0 and room:
		if Game.tip("spill"):
			hud.show_hint("Your wax spilled! Grab the warm drops before they cool", 2.5)
		var k := 3 if amount >= 8.0 else 2
		for i in k:
			add_loose("wax_warm", player.global_position, amount * 0.3 / k, Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(70.0, 95.0))
	shake(3.0)
	hitstop(0.06, 0.05)
	hud.on_hurt()
	fx_text(player.global_position + Vector2(0, -26), "-%d min" % int(round(amount)), UI.RED)
	for i in 5:
		fx_drop(player.global_position + Vector2(0, -10), Vector2.from_angle(randf_range(-PI, 0)) * randf_range(30, 70))


func on_player_died() -> void:
	if finished:
		return
	finished = true
	Records.on_died(self)   # what put the flame out
	hud.release_sticks()
	Audio.music("death_jingle", 0.3)
	Audio.play("snuff_out")
	Audio.play("bell_toll", 0.0, 0.0, 0.9)
	_clear_shots()
	Juice.of(self).player_died()
	Engine.time_scale = 0.35 * Game.base_time_scale
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(1.0)
	tw.tween_callback(func(): Engine.time_scale = Game.base_time_scale)
	tw.tween_interval(1.4)
	tw.tween_callback(func(): _end_run(false))


func _victory() -> void:
	if finished:
		return
	finished = true
	Game.unlock("black_taper")
	player.frozen = true
	hud.release_sticks()
	Audio.music("victory_jingle", 0.3)
	Audio.play("victory")
	hud.show_banner(Enemy.DEFS.get(boss_kind, {}).get("victory", "THE HOUR FIEND IS SNUFFED"), "Done by %s" % Game.clock_text(clock_minutes()), 3.0)
	var tw := create_tween()
	tw.tween_interval(3.4)
	tw.tween_callback(func(): Diary.win_ending(self, func(): _end_run(true)))   # an ending's cards first, if the night earned one


func _end_run(won: bool, again := {}) -> void:
	Game.records["kills"] += kills
	Game.records["best_floor"] = maxi(int(Game.records["best_floor"]), floor_num)
	if won:
		Game.records["wins"] += 1
		Records.note_finish(candle_id, night_floors, clock_minutes())   # kept per night length (a 7-floor finish is its own record)
	Game.save()
	var res := Records.end_run(self, won, {"won": won, "floor": floor_num, "clock": clock_minutes(), "kills": kills,
		"rooms": rooms_cleared, "relics": player.relics.duplicate(), "time": run_time, "streak": best_streak, "hits": hits_total, "candle": candle_id, "unlocked": unlocked_this_run.duplicate(), "daily": daily, "coins": player.coins,
		"level": level, "floors": night_floors})
	if not again.is_empty():
		main.goto("game", again)   # v2.6 Quick restart: the run is recorded, the next candle is lit at once
		return
	main.goto("results", res)


func give_up() -> void:
	if not paused:
		return
	toggle_pause()
	player.dead = true
	on_player_died()


## v2.6 Quick restart (the pause menu's Restart): the night is recorded as given up and the next is lit at once.
func quick_restart() -> void:
	if finished:
		return
	var again := restart_params()
	if paused:
		toggle_pause()
	finished = true
	player.dead = true
	Records.on_died(self)   # "gave_up": blown out with wax to spare
	hud.release_sticks()
	_clear_shots()
	Audio.play("snuff_out")
	_end_run(false, again)


## The same kind of night again: this candle and night length in this slot; a typed-in seed or Tonight's Candle
## replays that same house, any other run lights a new one.
func restart_params() -> Dictionary:
	if daily:
		return {"seed": run_seed, "daily": true, "candle": candle_id, "date": daily_date}
	var p := {"candle": candle_id, "floors": night_floors}
	if get_meta("seeded", false):
		p["seed"] = run_seed
		p["seeded"] = true
	return p


## v2.6: the full map of this floor over the pause menu (FullMap): the minimap tapped or clicked, M / Tab / Back.
func open_map() -> void:
	if finished or transitioning or player.dead or Juice.holding(self) or is_instance_valid(_intro_root):
		return
	if not paused:
		toggle_pause()
	hud.open_map()


## Minutes in tonight's night: 120 (2:00 AM) for 4 floors, 30 more per floor past four (Game.night_minutes).
func night_minutes() -> float:
	return Game.night_minutes(night_floors)


## Clock minutes past midnight: a full candle (the whole night of wax) = 12:00 AM, an empty one = the end of
## the night (2:00 AM on a 4-floor night, 3:30 AM on a 7-floor one).
func clock_minutes() -> float:
	return night_minutes() - player.wax


# ---------------------------------------------------------------- loop

func _physics_process(dt: float) -> void:
	if player == null:
		return
	# input: the HUD merges touch sticks, keyboard, mouse and gamepad (and handles bomb / keepsake)
	var mv := hud.move_vec
	var aim := hud.aim_vec
	if main.autotest and main.autotest.has_method("drive"):
		var drv: Array = main.autotest.drive(self)
		if not drv.is_empty():
			mv = drv[0]
			aim = drv[1]
	player.move_input = mv
	player.aim_input = aim
	if finished:
		return
	if not transitioning and not player.dead and not player.frozen:
		run_time += dt
		var melt := DRAIN_PER_SEC * floor_k(FLOOR_DRAIN) * player.drain_mult * float(difficulty()["melt"]) * (1.15 if omen == "draught" else 1.0)
		if player.wax < 8.0:
			melt *= 0.6       # the flame clings on when it is nearly out
		if player.chill_t > 0.0:
			melt *= 2.5
		player.wax -= melt * dt
		streak_t -= dt
		if streak_t <= 0.0:
			streak = 0
		player.chill_t = maxf(0.0, player.chill_t - dt)
		freeze_t = maxf(0.0, freeze_t - dt)
		if player.wax <= 0.0:
			player.wax = 0.0
			player.die()
		_clock_events()
		var exit := room.door_exit(player.global_position)
		if exit != Vector2i.ZERO:
			go_through(exit)
	if room_spawned and not room.data["cleared"] and count_enemies() == 0 and not transitioning and room.data["type"] != "boss":
		_clear_room()
	calm_t = calm_t + dt if room.data["cleared"] and not transitioning and count_enemies() == 0 else 0.0
	# prune in place: no new array every physics frame
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		if not (is_instance_valid(e) and (e.alive or e.boss)):
			enemies.remove_at(i)
		i -= 1
	_update_hazards(dt)
	_update_moths(dt)


## The bells of the night: every hour it strikes before the last half hour, then half an hour before the end
## ("Half past one. Hurry." on a 4-floor night) and a quarter before ("Your wick is nearly gone").
var _marks: Array = []


func bell_marks() -> Array:
	if not _marks.is_empty():
		return _marks
	var end := night_minutes()
	var h := 60.0
	while h < end - 30.0:
		_marks.append(h)
		h += 60.0
	_marks.append(end - 30.0)
	_marks.append(end - 15.0)
	return _marks


func _clock_events() -> void:
	var m := clock_minutes()
	var end := night_minutes()
	for mark in bell_marks():
		if m >= mark and not _bells.has(mark):
			_bells[mark] = true
			Audio.play("bell_toll")
			if "clock" in player.rites and not _bell_paid.has(mark):
				_bell_paid[mark] = true
				player.heal(4.0)
				fx_text(player.global_position + Vector2(0, -34), "+4 min", UI.GOLD)
			var at := Game.clock_text(mark, false)
			if is_equal_approx(mark, end - 15.0):
				hud.show_banner(at, "Your wick is nearly gone", 1.6)
			elif is_equal_approx(mark, end - 30.0):
				var words := Records.hour_words(mark, true) + (" o'clock" if roundi(mark) % 60 == 0 else "")
				hud.show_banner(at, "%s. Hurry." % words, 1.6)
			else:
				hud.show_banner(at, "The clock strikes %s" % Records.hour_words(mark), 1.8)
		elif m < mark - 10.0 and _bells.has(mark):
			_bells.erase(mark)
	Audio.set_low_wax(player.wax < 15.0 and not player.dead, player.wax / 15.0)
	if player.wax < 15.0 and not player.dead:
		_heartbeat -= get_physics_process_delta_time()
		if _heartbeat <= 0:
			_heartbeat = 1.1
			Audio.play("low_wax")


func _update_hazards(dt: float) -> void:
	for h in hazards.duplicate():
		var s: Sprite2D = h[0]
		h[1] -= dt
		h[2] -= dt
		if h[1] <= 0 or not is_instance_valid(s):
			hazards.erase(h)
			if is_instance_valid(s):
				s.queue_free()
			continue
		s.modulate.a = clampf(h[1], 0.0, 0.9)
		if h[2] <= 0:
			h[2] = 0.4
			for e in enemies:
				if is_instance_valid(e) and e.alive and e.active and e.global_position.distance_to(s.global_position) < 9 + e.radius:
					e.take_hit(0.5, Vector2.ZERO, 0.0)


func _update_moths(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in moths.size():
		var m: Sprite2D = moths[i]
		var ang := t * 3.0 + i * PI
		m.global_position = player.global_position + Vector2(0, -10) + Vector2.from_angle(ang) * 18.0
		m.flip_h = cos(ang) < 0
		for s in enemy_shots:
			if is_instance_valid(s) and s.global_position.distance_to(m.global_position) < 7:
				s.end()
		for e in enemies:
			if is_instance_valid(e) and e.alive and e.active and (e.global_position + Vector2(0, -6)).distance_to(m.global_position) < 6 + e.radius:
				if fmod(t, 0.3) < dt:
					e.take_hit(0.6, Vector2.ZERO)
		if "moth" in player.rites and fmod(t + i * 0.5, 1.0) < dt:
			var tgt := nearest_enemy(m.global_position, 90.0)
			if tgt:
				shoot_player(m.global_position, (tgt.global_position + Vector2(0, -6) - m.global_position).normalized(), player, player.damage * 0.5)
	var j := enemy_shots.size() - 1
	while j >= 0:
		if not is_instance_valid(enemy_shots[j]):
			enemy_shots.remove_at(j)
		j -= 1


func _process(dt: float) -> void:
	if _shake > 0 and Game.settings["shake"]:
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
		_shake = move_toward(_shake, 0.0, dt * 22.0)
	else:
		cam.offset = Vector2.ZERO


# ---------------------------------------------------------------- pause / lifecycle

func toggle_pause() -> void:
	if finished:
		return
	paused = not paused
	get_tree().paused = paused
	Audio.set_paused(paused)
	if paused:
		hud.open_pause()
	else:
		hud.close_pause()
		Audio.play("ui_back")


func on_back() -> void:
	if is_instance_valid(_intro_root) or Diary.on_back(self):   # Back closes a diary page's reading card first
		return
	# close a settings panel first, if one is open over the pause menu
	var top: Node = hud.root.get_child(hud.root.get_child_count() - 1)
	if paused and top != hud.pause_layer and top.get_meta("modal", false):
		top.queue_free()
		return
	toggle_pause()


func on_focus_lost() -> void:
	if not paused and not finished:
		toggle_pause()


# ---------------------------------------------------------------- effects

## Screen shake in pixels (Juice turns it into smooth noise: small hits subtle, big moments strong,
## scaled by the Screen shake setting).
func shake(amount: float) -> void:
	Juice.of(self).shake(amount)


func hitstop(dur: float, scale_ := 0.05) -> void:
	if finished:
		return
	Engine.time_scale = scale_ * Game.base_time_scale
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(dur)
	tw.tween_callback(func():
		if not finished:
			Engine.time_scale = Game.base_time_scale)


func fx_poof(pos: Vector2, warm := true, sc := 1.0) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("fx/poof", 18.0, false)
	a.position = pos
	a.scale = Vector2(sc, sc)
	if warm:
		a.modulate = Color(1.0, 0.8, 0.55)
	a.material = Art.unshaded
	fx_layer.add_child(a)
	a.play("default")
	a.animation_finished.connect(a.queue_free)


func fx_smoke(pos: Vector2) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Art.anim("fx/smoke", 8.0, false)
	a.position = pos
	fx_layer.add_child(a)
	a.play("default")
	var tw := a.create_tween()
	tw.tween_property(a, "position:y", pos.y - 10, 0.6)
	tw.parallel().tween_property(a, "modulate:a", 0.0, 0.6)
	tw.tween_callback(a.queue_free)


func fx_debris(pos: Vector2, ch: String) -> void:
	var col := Color("#8a503e") if ch == "C" else (Color("#c56025") if ch == "U" else Color("#775c55"))
	for i in 6:
		var r := ColorRect.new()
		r.color = col if i % 2 == 0 else col.darkened(0.3)
		r.size = Vector2(2, 2)
		r.position = pos + Vector2(randf_range(-4, 4), randf_range(-8, 0))
		fx_layer.add_child(r)
		var v := Vector2.from_angle(randf_range(-PI, 0)) * randf_range(20, 45)
		var tw := r.create_tween()
		tw.tween_property(r, "position", r.position + v * 0.35 + Vector2(0, 10), 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "modulate:a", 0.0, 0.3)
		tw.tween_callback(r.queue_free)


## A splash of melted wax: it arcs out and leaves a dot on the floor where it lands.
func fx_drop(pos: Vector2, v: Vector2) -> void:
	Juice.of(self).lit.emit(pos, v + Vector2(0, -20), randf_range(0.32, 0.45), FxParts.WAX, 260.0, 0.0, 2 if randf() < 0.4 else 1)


var _texts: Array = []   # live fx_text labels: a new one stacks clear of them instead of overlapping


## C10: minute rewards that land in the same frame near the same spot (a room clear's QUICK, CLEAN and
## hourglass, the last kill's Kindling) read as one line, "+4 min  KINDLING x3  CLEAN  QUICK".
var _merge := {"frame": -1, "label": null, "min": 0, "words": [], "x": 0.0}
var _min_re := RegEx.create_from_string("^(.*?)\\s*\\+(\\d+) min$")


func _merged_text(pos: Vector2, text: String) -> bool:
	var m := _min_re.search(text)
	if m == null:
		return false
	var frame := Engine.get_process_frames()
	var last: Variant = _merge["label"]
	if frame == int(_merge["frame"]) and last != null and is_instance_valid(last) and absf(pos.x - float(_merge["x"])) < 24.0:
		_merge["min"] = int(_merge["min"]) + int(m.get_string(2))
		if m.get_string(1) != "":
			(_merge["words"] as Array).append(m.get_string(1).strip_edges())
		var l: Label = last
		l.text = ("+%d min  %s" % [_merge["min"], "  ".join(_merge["words"])]).strip_edges()
		var w := Art.font_small.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
		if w > l.size.x:
			l.position.x -= (w - l.size.x) / 2.0
			l.size.x = w
		return true
	_merge = {"frame": frame, "label": null, "min": int(m.get_string(2)), "words": [] if m.get_string(1) == "" else [m.get_string(1).strip_edges()], "x": pos.x}
	return false


## A Kindling chain (KINDLING x3, BLAZE x5, BLAZE x6...) is one line that counts up, not a stack.
var _streak := {"label": null, "min": 0, "ms": 0}
var _streak_re := RegEx.create_from_string("^((?:KINDLING|BLAZE|INFERNO) x\\d+)\\s+\\+(\\d+) min$")


func fx_text(pos: Vector2, text: String, col: Color) -> void:
	var sm := _streak_re.search(text)
	if sm:
		var prev: Variant = _streak["label"]
		var total := int(sm.get_string(2))
		if prev != null and is_instance_valid(prev) and Time.get_ticks_msec() - int(_streak["ms"]) < 1500:
			total += int(_streak["min"])
			_texts.erase(prev)
			(prev as Node).queue_free()
		text = "%s  +%d min" % [sm.get_string(1), total]
		_streak["min"] = total
		_streak["ms"] = Time.get_ticks_msec()
	if _merged_text(pos, text):
		return
	var l := UI.outlined(UI.label(text, 8, col, HORIZONTAL_ALIGNMENT_CENTER))
	if sm:
		_streak["label"] = l
	if int(_merge["frame"]) == Engine.get_process_frames() and _merge["label"] == null and _min_re.search(text):
		_merge["label"] = l
	l.material = Art.unshaded
	l.size = Vector2(60, 10)
	l.position = Vector2(pos.x - 30, _free_text_y(pos))
	_texts.append(l)
	l.z_index = 30
	fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 12, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.tween_callback(l.queue_free)


## The y for a new floating text at `pos`: stacked 10 px above any live text it would overlap
## (Kindling + Clean + Quick fire together), or below them when that would leave the room.
func _free_text_y(pos: Vector2) -> float:
	_texts = _texts.filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion())
	var top := (room.position.y + 2.0) if room else -INF
	for step in [-10.0, 10.0]:
		var y := pos.y
		var moved := true
		var n := 0
		while moved and n < 8:
			moved = false
			n += 1
			for o in _texts:
				var ol: Label = o
				if absf(ol.position.x + 30.0 - pos.x) < 70.0 and absf(ol.position.y - y) < 10.0:
					y = ol.position.y + step
					moved = true
		if step > 0.0 or y >= top:
			return y
	return pos.y


func fx_ring(pos: Vector2, col: Color) -> void:
	var n := Node2D.new()
	n.position = pos
	fx_layer.add_child(n)
	var st := {"r": 2.0}
	n.draw.connect(func(): n.draw_arc(Vector2.ZERO, st["r"], 0, TAU, 24, col, 1.0))
	var tw := n.create_tween()
	tw.tween_method(func(v): st["r"] = v; n.queue_redraw(), 2.0, 26.0, 0.4)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.4)
	tw.tween_callback(n.queue_free)


## Bomb scorch, baked into the floor stains (it stays for the floor).
func fx_scorch(pos: Vector2) -> void:
	Juice.of(self).scorch(pos)


## Sparks thrown back off a wall (dir = which way they fly).
func fx_sparks(pos: Vector2, dir: Vector2, n := 4, blue := false) -> void:
	Juice.of(self).sparks(pos, dir, n, blue)


## A tiny puff where Tallow's shot leaves.
func fx_muzzle(pos: Vector2, dir: Vector2, blue := false) -> void:
	Juice.of(self).muzzle(pos, dir, blue)


## A drip falling off the candle: it leaves a wax dot on the floor.
func fx_wax_drop(pos: Vector2, v := Vector2.ZERO) -> void:
	Juice.of(self).wax_drop(pos, v)


## A thread of smoke from a guttering wick.
func fx_wisp(pos: Vector2) -> void:
	Juice.of(self).wisp(pos)


## Gold sparkles (a relic is put away).
func fx_glint(pos: Vector2) -> void:
	Juice.of(self).glint(pos)


## A persistent splat on this room's floor ("goo", "ash", "blood", "red", "wax", "soot", ...).
func fx_stain(pos: Vector2, mat := "wax", big := false) -> void:
	Juice.of(self).splat(pos, mat, big)


## Save & Continue: run state that lives outside the player (relic knowledge, fog, charges).
func save_extra() -> Dictionary:
	return {"relic_fx": RelicFx.of(self).to_dict(), "specials": Specials.of(self).to_dict(), "records": Records.to_dict(self), "tower": Tower.of(self).to_dict()}


func load_extra(d: Dictionary) -> void:
	RelicFx.of(self).from_dict(d.get("relic_fx", {}))
	Specials.of(self).from_dict(d.get("specials", {}))
	Records.from_dict(self, d.get("records", {}))
	Tower.of(self).from_dict(d.get("tower", {}))
