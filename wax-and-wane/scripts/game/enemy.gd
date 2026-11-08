class_name Enemy
extends Node2D
## Every creature of the house, driven by a data table (DEFS) + behaviour functions.
## The 0x72 creatures' behaviours live here; the house's own monsters are in enemies/house_ai.gd and
## the newer bosses in enemies/boss_ai.gd (same Enemy node, chosen by the `ai` field).
## Bosses are the same class with `boss` set.

const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, tint.rgb, flash), c.a);
}
"""
## Same flash, but the creature glows in the dark (ghost lights).
const FLASH_SHADER_GLOW := """
shader_type canvas_item;
render_mode unshaded;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, tint.rgb, flash), c.a);
}
"""

## Every creature: stats, behaviour (`ai`), and for the Journal a `name`, a one-line `lore` and the colour
## its remains `stain` the floor (Color). Optional: `fly`, `heavy`, `touch` (contact damage), `swarm` (arrives
## in a group of N), `split` ([kind, n] on death), `small_fry` (kills do not feed Kindling), `glow` (unshaded),
## `face_dir` (faces where it goes), `no_flip`,
## `sprite` (shared art), `tint`, `glow_px` (palette colours drawn unlit: eye-lights, lanterns; CreatureGlow),
## `cd` (attack cooldown). Bosses add `title`, `phase_lines`, `victory`.
const DEFS := {
	# ---- the 0x72 lodgers
	"tiny_zombie": {"hp": 4.0, "speed": 26.0, "ai": "chase", "r": 5.0, "name": "Coal-Bin Shambler",
		"lore": "Slept in the coal bin so long it forgot it was ever a boy.", "stain": Color("#3d734f")},
	"goblin": {"hp": 5.0, "speed": 40.0, "ai": "chase", "jitter": true, "r": 5.0, "name": "Larder Thief",
		"lore": "Steals candle ends to eat in the dark. Yours will do nicely.", "stain": Color("#3d734f")},
	"tiny_slug": {"hp": 3.0, "speed": 20.0, "ai": "chase", "r": 4.0, "name": "Damp Slug",
		"lore": "Follows the drip of the cellar pipes, and now the drip of you.", "stain": Color("#4ba747")},
	"slug": {"hp": 8.0, "speed": 17.0, "ai": "chase", "r": 6.0, "name": "Cistern Slug",
		"lore": "It has grown fat on the soap the maids threw down the drain.", "stain": Color("#3d734f")},
	"muddy": {"hp": 9.0, "speed": 0.0, "ai": "hop", "r": 6.0, "name": "Puddle Lump",
		"lore": "Coal dust and rainwater that decided to stand up.", "stain": Color("#483b3a")},
	"swampy": {"hp": 8.0, "speed": 0.0, "ai": "hop", "shoot4": true, "r": 6.0, "name": "Drain Hopper",
		"lore": "Each landing spits the sink's old water four ways at once.", "stain": Color("#4ba747")},
	"imp": {"hp": 4.0, "speed": 46.0, "ai": "fly", "r": 5.0, "fly": true, "name": "Flue Imp",
		"lore": "Rode the smoke down the chimney and never found the way back up.", "stain": Color("#62232f")},
	"skelet": {"hp": 6.0, "speed": 30.0, "ai": "shooter", "r": 5.0, "cd": 1.9, "name": "Bone Lodger",
		"lore": "Still pays its rent in teeth, one shot at a time.", "stain": Color("#aa8d7a")},
	"pumpkin_dude": {"hp": 10.0, "speed": 22.0, "ai": "charger", "r": 6.0, "charge": 150.0, "name": "Harvest Head",
		"lore": "Last autumn's lantern. It misses having a candle inside.", "stain": Color("#c56025")},
	"chort": {"hp": 9.0, "speed": 32.0, "ai": "charger", "r": 6.0, "charge": 175.0, "name": "Hearth Devil",
		"lore": "Lives behind the kitchen range and charges anything warmer than it.", "stain": Color("#62232f")},
	"wogol": {"hp": 10.0, "speed": 30.0, "ai": "jumper", "r": 6.0, "name": "Rafter Leaper",
		"lore": "Drops from the beams the moment your light passes under.", "stain": Color("#5f2d56")},
	"orc_shaman": {"hp": 12.0, "speed": 18.0, "ai": "caster", "r": 6.0, "cd": 2.6, "name": "Green Chanter",
		"lore": "Mutters the old house-rhymes until they turn into rings of fire.", "stain": Color("#3d734f")},
	"masked_orc": {"hp": 20.0, "speed": 24.0, "ai": "chase", "r": 7.0, "heavy": true, "name": "Masked Porter",
		"lore": "Carried coffins down the back stairs. Now it carries a grudge.", "stain": Color("#314152")},
	"necromancer": {"hp": 14.0, "speed": 20.0, "ai": "summoner", "r": 6.0, "name": "Hooded Mourner",
		"lore": "Keeps a vigil for the dead and keeps waking them for company.", "stain": Color("#5f2d56")},
	"doc": {"hp": 12.0, "speed": 22.0, "ai": "lobber", "r": 6.0, "name": "Tincture Doctor",
		"lore": "Every bottle in its coat cures one thing: being alive.", "stain": Color("#2a2a3a")},
	"ice_zombie": {"hp": 11.0, "speed": 30.0, "ai": "chase", "r": 5.0, "death_burst": true, "name": "Icebox Corpse",
		"lore": "Shut in the ice room by mistake. It bursts like a frozen pipe.", "stain": Color("#417089")},
	"mimic": {"hp": 16.0, "speed": 48.0, "ai": "chase", "r": 6.0, "sprite": "chest_mimic", "name": "Hungry Chest",
		"lore": "Packed with linens once. Now it is packed with teeth.", "stain": Color("#8a503e")},
	"angel": {"hp": 7.0, "speed": 52.0, "ai": "orbit", "r": 5.0, "fly": true, "cd": 2.2, "name": "Gilt Cherub",
		"lore": "Fell off the chapel ceiling and circles anything that shines.", "stain": Color("#facb3e")},
	"orc_warrior": {"hp": 22.0, "speed": 26.0, "ai": "brute", "r": 7.0, "heavy": true, "cd": 1.0, "name": "Belfry Brute",
		"lore": "Rang the great bell by hand for forty years. Its fists still ring.", "stain": Color("#314152")},
	"zombie": {"hp": 13.0, "speed": 16.0, "ai": "spitter", "r": 6.0, "cd": 2.4, "name": "Potted Sleeper",
		"lore": "Buried in the conservatory. Something green grew out and woke it.", "stain": Color("#3d734f")},
	# ---- the house's own
	"wax_blob": {"hp": 6.0, "speed": 18.0, "ai": "blob", "r": 6.0, "split": ["wax_bit", 2], "name": "Rose Melt",
		"lore": "A chapel candle that melted into a puddle and kept the wick.", "stain": Color("#9f294e")},
	"wax_bit": {"hp": 2.0, "speed": 40.0, "ai": "chase", "jitter": true, "r": 4.0, "touch": 4.0, "small_fry": true, "name": "Melt Drop",
		"lore": "Half a Rose Melt. It wants the other half back.", "stain": Color("#9f294e")},
	"moth": {"hp": 2.0, "speed": 48.0, "ai": "moth", "r": 4.0, "fly": true, "touch": 3.0, "swarm": 3, "small_fry": true, "name": "Lamp Moth",
		"lore": "They come for the brightest flame in the house. Tonight that is you.", "stain": Color("#aa8d7a")},
	"snuffer": {"hp": 12.0, "speed": 20.0, "ai": "snuffer", "r": 6.0, "cd": 1.6, "name": "Iron Snuffer",
		"lore": "Its whole purpose is to put candles out. It takes the job seriously.", "stain": Color("#314152")},
	"wisp": {"hp": 7.0, "speed": 20.0, "ai": "blinker", "r": 5.0, "fly": true, "glow": true, "cd": 2.4, "name": "Grave Light",
		"lore": "A cold flame that walks the graveyard. Follow it and you never come back.", "stain": Color("#49a790")},
	"sootling": {"hp": 5.0, "speed": 34.0, "ai": "sooter", "r": 5.0, "cd": 1.0, "name": "Sootling",
		"lore": "Swept out of the chimney, it leaves itself everywhere it goes.", "stain": Color("#2a2a3a")},
	"waxwork": {"hp": 16.0, "speed": 56.0, "ai": "statue", "r": 6.0, "name": "Waxwork Bride",
		"lore": "She stood in the parlour for a hundred years. She only moves when no one looks.", "stain": Color("#d3bfa9")},
	"cinder_rat": {"hp": 4.0, "speed": 92.0, "ai": "rat", "r": 4.0, "name": "Cinder Rat",
		"lore": "Nests in the ash pit. Its back never quite stops smouldering.", "stain": Color("#483b3a")},
	"psalter": {"hp": 9.0, "speed": 26.0, "ai": "fanner", "r": 6.0, "fly": true, "cd": 2.6, "name": "Restless Psalter",
		"lore": "A hymn book that lost its choir. It hurls its pages at the dark.", "stain": Color("#8f4029")},
	"clapper_bat": {"hp": 6.0, "speed": 50.0, "ai": "bellbat", "r": 5.0, "fly": true, "cd": 3.0, "name": "Clapper Bat",
		"lore": "Stole the tongue of the smallest bell and rings it to see you.", "stain": Color("#5f2d56")},
	"deathwatch": {"hp": 10.0, "speed": 64.0, "ai": "bouncer", "r": 5.0, "face_dir": true, "name": "Deathwatch Beetle",
		"lore": "The ticking in the walls at night. Wound up, it never stops.", "stain": Color("#c56025")},
	"grave_hand": {"hp": 8.0, "speed": 38.0, "ai": "burrow", "r": 5.0, "heavy": true, "name": "Grave Hand",
		"lore": "Reaches up through the crypt floor for anyone who stands still.", "stain": Color("#8a503e")},
	# ---- the Clock Tower (scripts/game/keeper.gd; floor 5 only)
	"cog_sentry": {"hp": 11.0, "speed": 16.0, "ai": "tower_cog", "r": 6.0, "cd": 2.2, "name": "Cog Sentry",
		"lore": "Wound up a hundred years ago and told to keep watch. Nobody told it to stop.", "stain": Color("#c56025")},
	"minute_wraith": {"hp": 9.0, "speed": 40.0, "ai": "tower_wraith", "r": 5.0, "fly": true, "glow": true, "cd": 2.4,
		"name": "Minute-Hand Wraith", "lore": "It was late, once. It has been hurrying ever since.", "stain": Color("#b6cbcf")},
	"gutterspout": {"hp": 18.0, "speed": 0.0, "ai": "turret", "r": 6.0, "heavy": true, "cd": 1.2, "name": "Gutterspout",
		"lore": "Spat rain off the belfry roof for centuries. It aims better now.", "stain": Color("#7b8994")},
	# ---- bosses
	"big_zombie": {"hp": 78.0, "speed": 20.0, "ai": "boss_rot", "r": 11.0, "boss": true, "heavy": true, "name": "OLD ROT",
		"title": "It sleeps under the cellar stairs", "lore": "The first lodger. It has been rotting down there since the house was built.",
		"stain": Color("#3d734f")},
	"ogre": {"hp": 104.0, "speed": 26.0, "ai": "boss_gaoler", "r": 11.0, "boss": true, "heavy": true, "name": "THE GAOLER",
		"title": "Keeper of the crypt keys", "lore": "Locked the crypt every night for a hundred years. Tonight it locks you in.",
		"stain": Color("#3d734f")},
	"necro_boss": {"hp": 148.0, "speed": 24.0, "ai": "boss_vicar", "r": 10.0, "boss": true, "heavy": true, "name": "THE HOLLOW WARDEN",
		"glow_px": ["#cae6f5", "#72d6ce", "#fdf7ed", "#49a790"], "title": "It watches the empty pews",
		"lore": "Nothing is left inside its robes but the habit of keeping watch.", "stain": Color("#5f2d56")},
	"big_demon": {"hp": 230.0, "speed": 30.0, "ai": "boss_fiend", "r": 12.0, "boss": true, "heavy": true, "name": "THE HOUR FIEND",
		"title": "It wants the clock to strike two", "victory": "THE HOUR FIEND IS SNUFFED",
		"lore": "It lives in the gap between the ticks and eats the minutes you waste.", "stain": Color("#62232f")},
	"wax_mother": {"hp": 92.0, "speed": 14.0, "ai": "boss_mother", "r": 13.0, "boss": true, "heavy": true, "name": "THE WAX MOTHER",
		"title": "Every drip in the cellar is her child",
		"phase_lines": ["", "She weeps harder...", "Her candles gutter and rage!"],
		"lore": "All the candles ever burnt in this house ran down to her. She wants you back.", "stain": Color("#9f294e")},
	"sexton": {"hp": 108.0, "speed": 26.0, "ai": "boss_sexton", "r": 10.0, "boss": true, "heavy": true, "name": "THE SEXTON",
		"title": "He digs for the house", "phase_lines": ["", "The dead hear his spade...", "He digs faster!"],
		"lore": "He dug every grave in the crypt, and he has measured you for one.", "stain": Color("#8a503e")},
	"choir": {"hp": 158.0, "speed": 14.0, "ai": "boss_choir", "r": 14.0, "boss": true, "heavy": true, "name": "THE MELTED CHOIR",
		"no_flip": true, "title": "Three voices, one hymn", "phase_lines": ["", "They sing in harmony...", "All three at once!"],
		"lore": "They sang so long by candlelight that their faces ran. They are still singing.", "stain": Color("#da4e38")},
	"pendulum": {"hp": 238.0, "speed": 0.0, "ai": "boss_pendulum", "r": 14.0, "boss": true, "heavy": true, "name": "THE GREAT PENDULUM",
		"title": "The Hour Fiend's heart swings", "phase_lines": ["", "Tick... tock... TICK!", "It is nearly two!"],
		"victory": "THE GREAT PENDULUM IS STILLED", "touch": 0.0, "no_flip": true,
		"lore": "The heart of the house clock. Every swing takes a minute from someone.", "stain": Color("#c56025")},
	"keeper": {"hp": 280.0, "speed": 0.0, "ai": "tower_keeper", "r": 14.0, "boss": true, "heavy": true, "name": "THE KEEPER OF HOURS",
		"title": "It winds the house, every night", "phase_lines": ["", "Time stands still...", "It chimes for you!"],
		"victory": "THE KEEPER OF HOURS IS STILLED", "no_flip": true, "secret": true,
		"lore": "It has wound the house clock every night for three hundred years. Tonight it wants to wind you.", "stain": Color("#5f2d56")},
}

## Health of ordinary creatures by floor: a gentle cellar, real pressure from the chapel up.
const FLOOR_HP := [1.0, 1.35, 1.85, 2.4, 2.5]
## Contact damage per floor for creatures without their own "touch" (bosses: 8). Balance: polish.md.
const TOUCH := [5, 6, 7, 7, 7]
## Extra animations our own monster art may provide (assets/art/monsters/<name>_<anim>_fN.png).
const MONSTER_ANIMS := ["idle", "run", "atk", "rise", "grab", "mound", "sing"]

var world: Node
var kind := ""
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var speed := 20.0
var radius := 5.0
var half_h := 6.0
## Marked foes: tougher, glowing, and they pay out (set by the world before _ready).
var champ := ""
const CHAMP_TINT := {
	"ember": Color(1.35, 0.65, 0.45), "gilded": Color(1.4, 1.2, 0.5),
	"sooty": Color(0.55, 0.5, 0.62), "chilled": Color(0.7, 0.95, 1.35),
}
var alive := true
var active := false
var boss := false
var flying := false
var heavy := false
## Burrowed / blinked out: no contact damage and shots pass (the AI keeps running).
var buried := false
var spr: AnimatedSprite2D
var mat: ShaderMaterial
var kvel := Vector2.ZERO
var state := "idle"
var t := 0.0
var cd := 1.0
var dir := Vector2.ZERO
var phase := 1
var minions: Array = []
var burn_t := 0.0
var _burn_tick := 0.0
var _flash := 0.0
var _wob := 0.0
var _jump_h := 0.0
var _spin := 0.0
var _pattern := 0
var target_pos := Vector2.ZERO
var _hand_base := 0.0
var shadow: Sprite2D
## Free scratch space for the house behaviours (counters, voices, volleys).
var mem := {}
var _anim_lock := 0.0
var _brain: Callable
var _ext := false
var _queue: Array = []
var _tele: Telegraph
static var _shadow_tex: Texture2D
static var _flash_shader: Shader
static var _glow_shader: Shader
static var _shadow_big: Texture2D
static var _house: HouseAI
static var _bosses: BossAI
static var _frames_cache := {}
static var _champ_lights := 0   # marked foes with a glow light; past 3 the tint alone shows it (light budget)


## A flat pixel ellipse used as a ground shadow (never scaled).
static func _blob(w: int, h: int) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := Color(0.13, 0.08, 0.1, 0.45)
	for y in h:
		var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
		var half := sqrt(maxf(0.0, 1.0 - dy * dy)) * w / 2.0
		for x in w:
			if absf(x + 0.5 - w / 2.0) <= half:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## The floor's guardian out of `opts` (world FLOORS[n]["bosses"]), picked from the run seed so
## Tonight's Candle is the same for everyone. Until a player has won once, a normal run always ends
## with the first finale (the Hour Fiend).
static func pick_boss(opts: Array, floor_num: int, run_seed: int, daily := false) -> String:
	if opts.is_empty():
		return "big_zombie"
	if floor_num >= 4 and not daily and int(Game.records.get("wins", 0)) <= 0:
		return opts[0]
	return opts[absi(hash("%d:boss:%d" % [run_seed, floor_num])) % opts.size()]


## SpriteFrames for a creature: our own art in assets/art/monsters/ first, else the 0x72 frames.
static func frames_for(sname: String) -> SpriteFrames:
	if _frames_cache.has(sname):
		return _frames_cache[sname]
	var sf: SpriteFrames
	if Art.has("monsters/%s_idle_f0" % sname):
		sf = SpriteFrames.new()
		sf.remove_animation("default")
		for a in MONSTER_ANIMS:
			if not Art.has("monsters/%s_%s_f0" % [sname, a]):
				continue
			sf.add_animation(a)
			sf.set_animation_loop(a, a in ["idle", "run", "atk", "mound"])
			sf.set_animation_speed(a, {"idle": 7.0, "run": 10.0, "atk": 8.0, "rise": 10.0, "mound": 6.0}.get(a, 8.0))
			for tx in Art.seq("monsters/%s_%s" % [sname, a]):
				sf.add_frame(a, tx)
	elif sname == "chest_mimic":
		sf = Art.anim("0x72/chest_mimic_open_anim", 8.0)
	else:
		sf = Art.creature(sname)
	_frames_cache[sname] = sf
	return sf


func setup(w: Node, k: String, pos: Vector2, floor_num: int) -> void:
	world = w
	kind = k
	def = DEFS[k]
	position = pos
	var f := float(floor_num - 1)
	max_hp = float(def["hp"]) * FLOOR_HP[clampi(floor_num, 1, FLOOR_HP.size()) - 1] if not def.get("boss", false) else float(def["hp"])
	hp = max_hp
	speed = float(def["speed"]) * (1.0 + 0.05 * f)
	radius = float(def["r"])
	boss = def.get("boss", false)
	flying = def.get("fly", false)
	heavy = def.get("heavy", false)
	cd = float(def.get("cd", 1.5)) * randf_range(0.6, 1.2)
	_wob = randf() * TAU


## The colour this creature's remains leave on the floor (for death splats).
func stain_color() -> Color:
	return def.get("stain", Color("#483b3a"))


func _ready() -> void:
	spr = AnimatedSprite2D.new()
	var sname: String = def.get("sprite", kind)
	spr.sprite_frames = frames_for(sname)
	var anim := "default" if sname == "chest_mimic" else "idle"
	spr.play(anim)
	spr.frame = randi() % maxi(1, spr.sprite_frames.get_frame_count(anim))
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(anim, 0)
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
	spr.modulate = CHAMP_TINT.get(champ, def.get("tint", Color.WHITE))
	if champ != "":
		max_hp *= 1.6 if champ == "sooty" else 2.0
		hp = max_hp
		if _champ_lights < 3:
			_champ_lights += 1
			tree_exiting.connect(func(): _champ_lights -= 1)
			var gl := PointLight2D.new()
			gl.texture = Art.light_tex
			gl.texture_scale = 0.3
			gl.energy = 0.55
			gl.color = CHAMP_TINT[champ]
			gl.position = Vector2(0, -8)
			add_child(gl)
	half_h = tex.get_height() * 0.4
	if _shadow_tex == null:
		_shadow_tex = _blob(10, 3)
		_shadow_big = _blob(22, 5)
	shadow = Sprite2D.new()
	shadow.texture = _shadow_big if radius > 7.0 else _shadow_tex
	shadow.position = Vector2(0, -1)
	add_child(shadow)
	mat = ShaderMaterial.new()
	if _flash_shader == null:
		_flash_shader = Lighting.flash_shader()   # FLASH_SHADER + the banded pixel light (lighting.gd)
		_glow_shader = Shader.new()
		_glow_shader.code = FLASH_SHADER_GLOW
	mat.shader = _glow_shader if def.get("glow", false) else _flash_shader
	spr.material = mat
	add_child(spr)
	# behaviour: our own method, or one of the house / boss behaviour sets
	var ai: String = def["ai"]
	if has_method("_ai_" + ai):
		_brain = Callable(self, "_ai_" + ai)
	else:
		if _house == null:
			_house = HouseAI.new()
			_bosses = BossAI.new()
		_ext = true
		_brain = Callable(Keeper.ai() if ai.begins_with("tower_") else (_bosses if ai.begins_with("boss_") else _house), ai)
		if _brain.get_object().has_method("init_" + ai):
			_brain.get_object().call("init_" + ai, self)
	# some arrive in a flutter of friends
	if def.get("swarm", 0) > 1:
		_spawn_swarm.call_deferred()
	# spawn-in
	active = false
	spr.modulate.a = 0.0
	if not boss:
		scale = Vector2(0.4, 1.6)
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 1.0, 0.35)
	if not boss:
		tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25 if not boss else 0.6)
	tw.tween_callback(func(): active = true)


func _spawn_swarm() -> void:
	# checked here (deferred) so the friends we spawn are already marked and never call friends of their own
	if get_meta("swarm_child", false) or not alive or world == null or world.room == null:
		return
	for i in int(def["swarm"]) - 1:
		var off := Vector2.from_angle(TAU * (i + 1) / float(def["swarm"]) + randf() * 0.5) * 10.0
		var m: Enemy = world.spawn_enemy(kind, global_position + off)
		if m:
			m.set_meta("swarm_child", true)


## A warning-mark layer (created on first use).
func tele() -> Telegraph:
	if _tele == null:
		_tele = Telegraph.new()
		add_child(_tele)
		move_child(_tele, 0)
	return _tele


## Run `fn` after `delay` seconds of enemy time (respects freezes and slows; skipped if we die).
func later(delay: float, fn: Callable) -> void:
	_queue.append([delay, fn])


## Play one of our animations for `hold` seconds before walking/idling takes over again.
func play_anim(a: String, hold := 0.5) -> void:
	if spr.sprite_frames.has_animation(a):
		spr.play(a)
		_anim_lock = hold


func _physics_process(dt: float) -> void:
	if not alive or Juice.holding(world):
		return
	_flash = maxf(0.0, _flash - dt * 6.0)
	mat.set_shader_parameter("flash", _flash)
	if burn_t > 0:
		burn_t -= dt
		_burn_tick -= dt
		spr.self_modulate = Color(1.0, 0.7, 0.5)
		if _burn_tick <= 0:
			_burn_tick = 0.5
			_damage(0.5 + world.player.damage * 0.25, false)
			if not alive:
				return
	else:
		spr.self_modulate = Color.WHITE
	if not active and not buried:
		return
	var p: Player = world.player
	var slow: float = world.time_scale_enemies()
	var ddt := dt * slow
	t -= ddt
	cd -= ddt
	if _anim_lock > 0.0:
		_anim_lock -= ddt
		if _anim_lock <= 0.0 and spr.animation != "idle" and spr.sprite_frames.has_animation("idle"):
			spr.play("idle")
	# knockback
	if kvel.length() > 1:
		_move(kvel * dt)
		kvel = kvel.move_toward(Vector2.ZERO, 500 * dt)
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	if _ext:
		_brain.call(self, ddt, to_p, dist)
	else:
		_brain.call(ddt, to_p, dist)
	if not alive:
		return
	if not _queue.is_empty() and ddt > 0.0:
		_run_queue(ddt)
	# face the player
	if def.get("no_flip", false):
		pass
	elif def.get("face_dir", false):
		if absf(dir.x) > 0.1:
			spr.flip_h = dir.x < 0
	elif absf(to_p.x) > 2 and state != "charge" and state != "still":
		spr.flip_h = to_p.x < 0
	# contact damage
	var touch: float = def.get("touch", 8.0 if boss else float(TOUCH[clampi(world.floor_num, 1, 4) - 1]))
	if touch > 0.0 and not buried and not p.dead and world.freeze_t <= 0.0 and (flying or _jump_h < 4.0) and dist < radius + 5.0:
		if champ == "chilled" and not p.dead:
			if p.chill_t <= 0.0:
				world.fx_text(p.global_position + Vector2(0, -30), "chilled", Color("#72d6ce"))
			p.chill_t = 5.0
		p.hurt(touch * world.enemy_dmg_mult(), to_p)
		if _ext and _brain.get_object().has_method("touched_" + def["ai"]):
			_brain.get_object().call("touched_" + def["ai"], self)
	# gentle separation
	if not buried:
		for e in world.enemies:
			if e == self or not is_instance_valid(e) or not e.alive or e.buried:
				continue
			var d: Vector2 = global_position - e.global_position
			var l := d.length()
			if l > 0.01 and l < radius + e.radius:
				_move(d / l * (radius + e.radius - l) * 0.3)
	spr.position.y = -_jump_h
	if shadow:
		shadow.visible = _jump_h < 18.0 and not buried


func _run_queue(ddt: float) -> void:
	var due: Array = []
	for q in _queue:
		q[0] -= ddt
		if q[0] <= 0.0:
			due.append(q)
	for q in due:
		_queue.erase(q)
		if alive:
			(q[1] as Callable).call()


## Collision is checked in world coordinates (our parent layer sits at the room's origin).
func _move(d: Vector2) -> bool:
	var room: Room = world.room
	if room == null:
		return false
	var moved := false
	var gp := global_position
	if not flying:
		d *= room.slow_at(gp)   # cobwebs
	var np := gp + Vector2(d.x, 0)
	if not room.blocked(np, radius, flying):
		gp = np
		moved = true
	np = gp + Vector2(0, d.y)
	if not room.blocked(np, radius, flying):
		gp = np
		moved = true
	global_position = gp
	return moved


func _walk(ddt: float, want: Vector2, spd: float) -> void:
	if want.length() < 0.01:
		return
	var d := want.normalized() * spd * ddt
	if not _move(d):
		# simple steering around obstacles
		for a in [0.9, -0.9, 1.6, -1.6]:
			if _move(d.rotated(a)):
				break
	if _anim_lock <= 0.0 and spr.animation != "run" and spr.sprite_frames.has_animation("run"):
		spr.play("run")


func _telegraph(color := Color(1, 1, 1)) -> void:
	mat.set_shader_parameter("tint", color)
	_flash = 0.85


## True when we are standing inside something solid (pushed there by a blast or a spawn).
func room_stuck() -> bool:
	return world.room != null and world.room.blocked(global_position, radius, flying)


## A random open floor spot between min_d and max_d from `from` (never inside rocks).
func free_spot(from: Vector2, min_d: float, max_d := 9999.0) -> Vector2:
	var room: Room = world.room
	for i in 30:
		var c := Vector2i(randi_range(1, 13), randi_range(1, 7))
		if room.char_at(c) in [".", "e", "h", "f", "T"]:
			var p: Vector2 = room.cell_center(c) + Vector2(0, 4)
			var d := p.distance_to(from)
			if d >= min_d and d <= max_d and not room.blocked(p, radius + 1.0):
				return p
	return world.free_spot_near(global_position, radius)


# ---------------------------------------------------------------- behaviours

func _ai_chase(ddt: float, to_p: Vector2, _dist: float) -> void:
	var want: Vector2 = world.room.path_dir(global_position, global_position + to_p) * to_p.length() if world.room else to_p   # round obstacles
	if def.get("jitter", false):
		_wob += ddt * 5.0
		want = want.normalized() + want.normalized().orthogonal() * sin(_wob) * 0.7
	_walk(ddt, want, speed)


func _ai_fly(ddt: float, to_p: Vector2, _dist: float) -> void:
	_wob += ddt * 4.0
	var want := to_p.normalized() + to_p.normalized().orthogonal() * sin(_wob) * 1.1
	var r: Rect2 = world.room.inner_rect().grow(-4)
	global_position = (global_position + want.normalized() * speed * ddt).clamp(r.position, r.end)
	_jump_h = 5.0 + sin(_wob * 1.7) * 2.0


func _ai_hop(ddt: float, to_p: Vector2, _dist: float) -> void:
	match state:
		"idle":
			_jump_h = 0.0
			if t <= 0:
				state = "hop"
				t = 0.42
				dir = (to_p.normalized() + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))).normalized()
		"hop":
			_walk(ddt, dir, 115.0 * (1.0 + 0.05 * world.floor_num))
			_jump_h = sin((1.0 - t / 0.42) * PI) * 9.0
			if t <= 0:
				state = "idle"
				_jump_h = 0.0
				t = randf_range(0.7, 1.1)
				if def.get("shoot4", false):
					var a := 0.0 if _pattern % 2 == 0 else PI / 4
					_pattern += 1
					world.burst(global_position + Vector2(0, -6), 4, 75.0, "bullet_water", a)
					Audio.play("splash", -6.0)


func _ai_shooter(ddt: float, to_p: Vector2, dist: float) -> void:
	var want := Vector2.ZERO
	if dist < 60:
		want = -to_p
	elif dist > 110:
		want = to_p
	else:
		_wob += ddt
		want = to_p.orthogonal() * (1.0 if sin(_wob * 0.8) > 0 else -1.0)
	_walk(ddt, want, speed)
	if cd <= 0.35 and state != "aim":
		state = "aim"
		_telegraph(Color(1, 1, 0.8))
	if cd <= 0:
		state = "idle"
		cd = float(def["cd"]) * randf_range(0.85, 1.2)
		world.enemy_shot(global_position + Vector2(0, -8), to_p.normalized() * 85.0, "bullet_green")
		Audio.play("enemy_shoot")


func _ai_charger(ddt: float, to_p: Vector2, dist: float) -> void:
	match state:
		"idle":
			if t <= 0:
				t = randf_range(1.0, 1.8)
				dir = Vector2.from_angle(randf() * TAU)
			_walk(ddt, dir + to_p.normalized() * 0.6, speed)
			var aligned := absf(to_p.x) < 9 or absf(to_p.y) < 9
			if aligned and dist < 170 and cd <= 0:
				state = "windup"
				t = 0.45
				dir = Vector2(signf(to_p.x), 0) if absf(to_p.y) < 9 else Vector2(0, signf(to_p.y))
				_telegraph(Color(1, 0.4, 0.3))
				Audio.play("charge", -4.0)
		"windup":
			spr.position.x = sin(t * 80.0) * 1.0
			if t <= 0:
				spr.position.x = 0
				state = "charge"
				t = 1.3
		"charge":
			spr.flip_h = dir.x < 0
			if not _move(dir * float(def["charge"]) * ddt) or t <= 0:
				state = "stun"
				t = 0.6
				cd = 1.4
				if world.room:
					world.shake(2.0)
		"stun":
			if t <= 0:
				state = "idle"


func _ai_jumper(ddt: float, to_p: Vector2, _dist: float) -> void:
	match state:
		"idle":
			_walk(ddt, to_p, speed * 0.5)
			if cd <= 0:
				state = "crouch"
				t = 0.3
				scale = Vector2(1.2, 0.8)
		"crouch":
			if t <= 0:
				state = "air"
				t = 0.55
				scale = Vector2.ONE
				target_pos = world.player.global_position
				dir = global_position
		"air":
			var k := 1.0 - t / 0.55
			var np: Vector2 = (dir as Vector2).lerp(target_pos, clampf(k, 0, 1))
			if not world.room.blocked(np, radius, true):
				global_position = np
			_jump_h = sin(clampf(k, 0, 1) * PI) * 22.0
			if t <= 0:
				_jump_h = 0.0
				state = "idle"
				cd = randf_range(1.4, 2.0)
				world.shake(1.5)
				if world.floor_num >= 3:
					world.burst(global_position + Vector2(0, -4), 6, 70.0, "bullet_purple", randf() * TAU)


func _ai_caster(ddt: float, to_p: Vector2, _dist: float) -> void:
	if t <= 0:
		t = randf_range(1.2, 2.0)
		dir = Vector2.from_angle(randf() * TAU)
	if state != "cast":
		_walk(ddt, dir, speed)
	if cd <= 0.6 and state != "cast":
		state = "cast"
		_telegraph(Color(0.8, 0.5, 1.0))
	if cd <= 0:
		state = "idle"
		cd = float(def["cd"]) * randf_range(0.9, 1.15)
		_pattern += 1
		world.burst(global_position + Vector2(0, -10), 8, 70.0, "bullet_purple", 0.0 if _pattern % 2 == 0 else PI / 8)
		Audio.play("enemy_shoot", 2.0, 0.05, 0.8)


func _ai_summoner(ddt: float, to_p: Vector2, dist: float) -> void:
	_walk(ddt, -to_p if dist < 70 else to_p.orthogonal(), speed)
	if dist < 36 and state != "tp":
		_teleport()
	minions = minions.filter(func(m): return is_instance_valid(m) and m.alive)
	if cd <= 0:
		cd = 4.2
		if minions.size() < 3:
			_telegraph(Color(0.5, 1.0, 0.6))
			for i in 2:
				var m: Enemy = world.spawn_enemy("tiny_zombie", global_position + Vector2.from_angle(randf() * TAU) * 14.0)
				if m:
					minions.append(m)
			Audio.play("teleport", -4.0, 0.1, 0.7)


func _teleport() -> void:
	var spot: Vector2 = world.random_free_spot(global_position, 70.0)
	world.fx_smoke(global_position + Vector2(0, -8))
	global_position = spot
	world.fx_smoke(global_position + Vector2(0, -8))
	Audio.play("teleport", -2.0)
	cd = maxf(cd, 0.8)


func _ai_lobber(ddt: float, to_p: Vector2, dist: float) -> void:
	_walk(ddt, -to_p if dist < 70 else to_p.orthogonal() * (1 if sin(_wob) > 0 else -1), speed)
	_wob += ddt * 0.7
	if cd <= 0:
		cd = randf_range(2.2, 2.8)
		_telegraph(Color(0.6, 1.0, 0.6))
		world.lob(global_position + Vector2(0, -12), world.player.global_position)


# ---------------------------------------------------------------- bosses

func _boss_phase() -> int:
	var f := hp / max_hp
	return 1 if f > 0.66 else (2 if f > 0.33 else 3)


func _ai_boss_rot(ddt: float, to_p: Vector2, _dist: float) -> void:
	phase = _boss_phase()
	match state:
		"idle":
			_walk(ddt, to_p, speed * (1.0 + 0.25 * (phase - 1)))
			if cd <= 0:
				state = "slam_wind"
				t = 0.7
				_telegraph(Color(1, 0.5, 0.4))
				scale = Vector2(1.15, 0.85)
		"slam_wind":
			if t <= 0:
				scale = Vector2.ONE
				world.shake(4.0)
				Audio.play("explosion", -4.0, 0.05, 0.6)
				_pattern += 1
				world.burst(global_position + Vector2(0, -6), 10 + phase * 2, 72.0, "bullet_green", _pattern * 0.3)
				if phase >= 2 and _pattern % 2 == 0 and world.count_enemies() < 4:
					for i in 2:
						world.spawn_enemy("tiny_zombie", global_position + Vector2.from_angle(randf() * TAU) * 18.0)
				state = "idle"
				cd = 2.2 - 0.35 * phase


func _ai_boss_gaoler(ddt: float, to_p: Vector2, dist: float) -> void:
	phase = _boss_phase()
	match state:
		"idle":
			_walk(ddt, to_p, speed)
			if cd <= 0:
				_pattern += 1
				if _pattern % 3 == 0:
					state = "throw"
					t = 0.5
					_telegraph(Color(1, 0.9, 0.6))
				else:
					state = "windup"
					t = 0.55
					dir = to_p.normalized()
					_telegraph(Color(1, 0.35, 0.3))
					Audio.play("boss_roar", -6.0, 0.05, 1.2)
		"windup":
			spr.position.x = sin(t * 90.0) * 1.5
			if t <= 0:
				spr.position.x = 0
				state = "charge"
				t = 1.5
		"charge":
			spr.flip_h = dir.x < 0
			if not _move(dir * (165.0 + 20.0 * phase) * ddt) or t <= 0:
				world.shake(5.0)
				Audio.play("explosion", -6.0, 0.05, 0.5)
				if phase >= 2:
					world.burst(global_position + Vector2(0, -8), 8, 65.0, "bullet_purple", 0.0)
				state = "stun"
				t = 0.8 - 0.15 * phase
		"stun":
			if t <= 0:
				state = "idle"
				cd = 0.6
		"throw":
			if t <= 0:
				var base := to_p.angle()
				for i in 5:
					world.enemy_shot(global_position + Vector2(0, -14), Vector2.from_angle(base + (i - 2) * 0.22) * 90.0, "bullet_purple")
				Audio.play("enemy_shoot", 2.0)
				state = "idle"
				cd = 1.0


func _ai_boss_vicar(ddt: float, to_p: Vector2, dist: float) -> void:
	phase = _boss_phase()
	match state:
		"idle":
			_walk(ddt, -to_p if dist < 80 else to_p.orthogonal(), speed)
			if dist < 34:
				_teleport()
			if cd <= 0:
				_pattern += 1
				match _pattern % 3:
					0:
						state = "summon"
						t = 0.6
						_telegraph(Color(0.5, 1.0, 0.6))
						play_anim("atk", 0.9)   # lantern raised (fix/art)
					_:
						state = "spiral"
						t = 2.2 + 0.4 * phase
						_spin = randf() * TAU
						_wob = 0.35
						_telegraph(Color(0.8, 0.5, 1.0))
						play_anim("atk", t)   # lantern raised for the whole spiral (fix/art)
		"spiral":
			_wob -= ddt
			if _wob <= 0:
				_wob = 0.11
				_spin += 0.42
				for k in phase:
					world.enemy_shot(global_position + Vector2(0, -18), Vector2.from_angle(_spin + k * TAU / phase) * 70.0, "bullet_purple")
			if t <= 0:
				state = "idle"
				cd = 1.6
				_teleport()
		"summon":
			if t <= 0:
				minions = minions.filter(func(m): return is_instance_valid(m) and m.alive)
				if minions.size() < 4:
					for i in 2:
						var m: Enemy = world.spawn_enemy("skelet", world.random_free_spot(global_position, 40.0))
						if m:
							minions.append(m)
				Audio.play("teleport", 0.0, 0.05, 0.6)
				state = "idle"
				cd = 1.4


func _ai_boss_fiend(ddt: float, to_p: Vector2, dist: float) -> void:
	var np := _boss_phase()
	if np != phase:
		phase = np
		state = "roar"
		t = 1.0
		world.on_boss_phase(phase)
	match state:
		"roar":
			_telegraph(Color(1, 0.3, 0.2))
			if t <= 0:
				state = "idle"
				cd = 0.5
		"idle":
			_walk(ddt, to_p, speed * (1.0 + 0.2 * phase))
			if cd <= 0:
				_pattern += 1
				var opts := ["fan", "dash"]
				if phase >= 2:
					opts.append("hands")
				if phase >= 3:
					opts.append("toll")
				state = opts[_pattern % opts.size()]
				match state:
					"fan":
						t = 0.45
						dir = to_p.normalized()
					"dash":
						t = 0.5
						dir = to_p.normalized()
						Audio.play("boss_roar", -6.0, 0.05, 1.1)
					"hands":
						t = 3.0
						_spin = 0.0
						_wob = 0.5
						_hand_base = to_p.angle() + PI * 0.5
					"toll":
						t = 2.4
						_wob = 0.4
				_telegraph(Color(1, 0.4, 0.3))
		"fan":
			if t <= 0:
				var base := dir.angle()
				var n := 5 + phase
				for i in n:
					world.enemy_shot(global_position + Vector2(0, -18), Vector2.from_angle(base + (i - (n - 1) / 2.0) * 0.24) * (85.0 + 5 * phase), "bullet_purple")
				Audio.play("enemy_shoot", 3.0, 0.05, 0.7)
				state = "idle"
				cd = 1.3 - 0.2 * phase
		"dash":
			if t > 0:
				spr.position.x = sin(t * 90.0) * 1.5
			else:
				spr.position.x = 0
				spr.flip_h = dir.x < 0
				if not _move(dir * 190.0 * ddt) or t < -0.9:
					world.shake(5.0)
					world.burst(global_position + Vector2(0, -10), 10, 70.0, "bullet_purple", randf() * TAU)
					state = "idle"
					cd = 0.9
		"hands":
			# two clock hands sweep the room
			_wob -= ddt
			_spin += ddt * (0.85 + 0.15 * phase)
			if _wob <= 0:
				_wob = 0.09
				for k in 2:
					var a := _hand_base + k * PI + _spin * (1.0 if k == 0 else 0.5)
					world.enemy_shot(global_position + Vector2(0, -18), Vector2.from_angle(a) * 95.0, "bullet_purple")
			if t <= 0:
				state = "idle"
				cd = 1.2
		"toll":
			_wob -= ddt
			if _wob <= 0:
				_wob = 0.8
				Audio.play("bell_toll", -4.0, 0.0, 1.0)
				world.shake(3.0)
				world.burst(global_position + Vector2(0, -12), 16, 62.0, "bullet_purple", randf() * TAU)
				if world.count_enemies() < 4:
					world.spawn_enemy("imp", world.random_free_spot(global_position, 50.0))
			if t <= 0:
				state = "idle"
				cd = 1.0


# ---------------------------------------------------------------- damage

func take_hit(dmg: float, knock: Vector2, burn := 0.0) -> void:
	if not alive or not active:
		return
	if burn > 0.0:
		burn_t = maxf(burn_t, burn)
	if not heavy:
		kvel += knock
	else:
		kvel += knock * 0.15
	mat.set_shader_parameter("tint", Color(1, 1, 1))
	_flash = 1.0
	_damage(dmg, true)


func _damage(dmg: float, sound: bool) -> void:
	hp -= dmg
	if sound:
		Audio.play("hit_enemy", 0.0, 0.1)
	if boss:
		world.on_boss_hp(self)
	if hp <= 0:
		_die()


## New bosses: a short roar, a line on the banner, then the next phase of patterns.
func on_new_phase() -> void:
	world.shake(5.0)
	Lighting.shockwave(world, global_position + Vector2(0, -12), 56.0, 2.0)
	Audio.play("boss_roar")
	var lines: Array = def.get("phase_lines", [])
	if phase < lines.size() and lines[phase] != "":
		world.hud.show_banner("", lines[phase], 1.2)
	_telegraph(Color(1, 0.35, 0.3))
	state = "roar"
	t = 0.9
	if _tele:
		_tele.clear()


func _die() -> void:
	alive = false
	if buried:
		buried = false
		spr.modulate.a = 1.0
	if _tele:
		_tele.clear()
	if champ == "sooty":
		var at2 := global_position + Vector2(0, -6)
		world.fx_smoke(at2)
		world.fx_ring(at2, Color("#7b8994"))
		var w2 := world
		get_tree().create_timer(0.4, false).timeout.connect(func():
			if is_instance_valid(w2) and not w2.finished:
				w2.burst(at2, 6, 65.0, "bullet_purple", randf() * TAU))
	if burn_t > 0.0 and "hearth" in world.player.rites:
		# Rite of the Hearth: burning foes burst into embers
		for k in 4:
			world.shoot_player(global_position + Vector2(0, -6), Vector2.from_angle(PI / 4 + k * PI / 2), world.player, world.player.damage * 0.6)
	if def.get("death_burst", false):
		var at := global_position + Vector2(0, -6)
		var off: float = (world.player.global_position - global_position).angle() + PI / 6.0
		world.fx_ring(at, Color("#72d6ce"))
		var w := world
		get_tree().create_timer(0.4, false).timeout.connect(func():
			if is_instance_valid(w) and not w.finished:
				w.burst(at, 6, 65.0, "bullet_water", off))
	if def.has("split") and world.room and not get_meta("no_split", false):
		# a Rose Melt falls apart into drops that keep coming
		var sp: Array = def["split"]
		var base := randf() * TAU
		for i in int(sp[1]):
			var m: Enemy = world.spawn_enemy(sp[0], global_position + Vector2.from_angle(base + TAU * i / float(sp[1])) * 7.0)
			if m:
				m.kvel = Vector2.from_angle(base + TAU * i / float(sp[1])) * 60.0
	world.on_enemy_killed(self)
	if boss:
		return   # the world plays the boss death sequence and frees us
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.3), 0.12)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
