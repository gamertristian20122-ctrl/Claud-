class_name CreatureGlow
extends Node2D
## What keeps a creature readable in the dark house, drawn over its sprite (fix/art: C5, C6, UX-03):
##  - glow pixels: the palette colours listed in `Enemy.DEFS[kind]["glow_px"]` (eyes, the Hollow Warden's
##    eye-lights and lantern, a cinder rat's embers) give off their own light, so they shine in the dark;
##  - a rim: guardians, special-room champions and marked foes get a 1 px rim just outside their dark
##    outline on the side that faces Tallow's candle (candle-light catching the edge), so they never
##    melt into the floor;
##  - guardians also carry a soft pale light pool that follows them round the arena.
## One instance per creature that needs it, added by `Enemy._ready` (`CreatureGlow.attach(self)`).
## The rim/glow pass is one unshaded draw of the current frame (creature_glow.gdshader).

const SHADER := preload("res://scripts/game/creature_glow.gdshader")
## Rim colours: guardians and champions catch the candle (warm wax light); marked foes rim in their aura.
const RIM_BOSS := Color("#fccba3")
const RIM_CHAMP := {"ember": Color("#ee8e2e"), "gilded": Color("#facb3e"), "sooty": Color("#b6cbcf"),
	"chilled": Color("#72d6ce")}
## The guardian's light pool: pale and cool, so it never reads as Tallow's own warm light.
const POOL_COLOR := Color(0.74, 0.8, 0.96)
const POOL_ENERGY := 0.55
const POOL_SCALE := 0.42
## How much light a lodger's glowing eyes add (a guardian's own lights add their full colour).
const GLOW_EYES := 0.8

var e: Enemy
var pool: PointLight2D
var _mat: ShaderMaterial
var _last := []


## Adds the glow pass to `en` if it needs one (a guardian, a marked foe, or `glow_px` art).
static func attach(en: Enemy) -> CreatureGlow:
	var glow_px: Array = en.def.get("glow_px", [])
	var mini: bool = en.get_meta("mini", false)   # a special room's champion (specials.gd)
	if not en.boss and not mini and en.champ == "" and glow_px.is_empty():
		return null
	if en.def.get("glow", false):
		return null   # already unshaded
	var g := CreatureGlow.new()
	g.name = "CreatureGlow"
	g.e = en
	g._mat = ShaderMaterial.new()
	g._mat.shader = SHADER
	g.material = g._mat   # before add_child, so the lighting pass leaves it alone
	var cols := PackedColorArray()
	for c in glow_px:
		cols.append(Color(c))
	while cols.size() < 4:
		cols.append(Color(0, 0, 0, 0))
	g._mat.set_shader_parameter("glow_cols", cols)
	g._mat.set_shader_parameter("glow_n", mini(glow_px.size(), 4))
	g._mat.set_shader_parameter("glow", 1.0 if en.boss else GLOW_EYES)
	var rim := Color(0, 0, 0, 0)
	if en.boss or mini:
		rim = RIM_BOSS
	elif en.champ != "":
		rim = RIM_CHAMP.get(en.champ, RIM_BOSS)
	g._mat.set_shader_parameter("rim_col", rim)
	en.add_child(g)
	if en.boss and not en.def.get("secret", false):
		g.pool = PointLight2D.new()
		g.pool.texture = Art.light_tex
		g.pool.texture_scale = POOL_SCALE
		g.pool.energy = POOL_ENERGY
		g.pool.color = POOL_COLOR
		g.pool.position = Vector2(0, -6)
		en.add_child(g.pool)
	return g


func _process(_dt: float) -> void:
	var s: AnimatedSprite2D = e.spr if is_instance_valid(e) else null
	if s == null:
		return
	visible = e.alive and not e.buried and s.visible
	if not visible:
		return
	var p: Node2D = e.world.get("player") if e.world else null
	var ld := Vector2(-0.6, -0.8)
	if is_instance_valid(p):
		var to := p.global_position + Vector2(0, -8) - (e.global_position + Vector2(0, -e.half_h))
		if to.length() > 1.0:
			ld = to.normalized()
	var key := [s.animation, s.frame, s.flip_h, s.position, s.offset, ld.snapped(Vector2(0.1, 0.1)), s.modulate.a]
	if key != _last:
		_last = key
		_mat.set_shader_parameter("light_dir", ld)
		_mat.set_shader_parameter("flip", s.flip_h)
		modulate.a = s.modulate.a
		queue_redraw()


func _draw() -> void:
	var s: AnimatedSprite2D = e.spr
	var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	if tex == null:
		return
	draw_set_transform(s.position, s.rotation, s.scale)
	draw_texture_rect(tex, Rect2(s.offset - Vector2.ONE, tex.get_size() + Vector2(2, 2)), false)
