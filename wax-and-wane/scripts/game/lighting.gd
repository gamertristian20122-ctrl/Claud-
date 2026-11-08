class_name Lighting
extends Node
## Pixel-art light pass. One node per world (and on the title), from `Lighting.attach(host)`.
##  - Banded light: every lit canvas item under the host that has no material of its own gets one of two
##    shared materials (`lit.gdshader`): Godot's smooth light falloff becomes flat bands with a 4x4 Bayer
##    seam on the game-pixel grid. Palette colours are untouched; only the light factor is stepped.
##    Room pieces (floor, walls, decor, obstacles, stains) get the room material, which also wanes;
##    Tallow, creatures and pickups get the actor material, which keeps their colour for readability.
##    Shadowed lights get hard (unfiltered) shadow edges so shadows are pixel-crisp too.
##  - Waning world: below 40 % wax the room material loses colour step by step and a dithered dark
##    vignette closes in (fire, embers, the flame, shots and the wax bar keep full colour).
##  - Heat haze over Tallow's flame, lit hearths and the Blowlamp; a shockwave ring on bomb blasts and
##    guardian phase changes (screen-reading, small patches, whole-pixel offsets only).
##  - Settings: "effects" = "full" / "lite" (Lite: no haze, no shockwaves, no vignette; banding and the
##    colour loss stay, they cost nothing extra).
## Hooks: world._ready / title._ready `Lighting.attach(self)`; enemy.gd uses `Lighting.flash_shader()`;
## room._light_hearth and relic_fx._ready call `Lighting.haze(...)`; world._explode and
## world.on_boss_phase call `Lighting.shockwave(...)`; hud.gd puts `Lighting.dither_material()` on its
## low-wax glow.

const LIT := preload("res://scripts/game/lit.gdshader")
const LIT_FLASH := preload("res://scripts/game/lit_flash.gdshader")
const HAZE := preload("res://scripts/game/heat_haze.gdshader")
const SHOCK := preload("res://scripts/game/shockwave.gdshader")
const VIGNETTE := preload("res://scripts/game/wane_vignette.gdshader")
const DITHER := preload("res://scripts/game/dither_alpha.gdshader")

## Wax fraction where the waning starts, the most colour lost at an empty candle, and the steps.
const WANE_FROM := 0.4
const WANE_MAX := 0.85
const WANE_STEPS := 8.0
## Draw order of the screen-reading patches: above everything else in the world canvas.
const FX_Z := 60

static var _room_mat: ShaderMaterial
static var _actor_mat: ShaderMaterial
static var _dither_mat: ShaderMaterial
static var _blank := {}

var host: Node
var _rooms: Node
var _vig_layer: CanvasLayer
var _vig: ColorRect
var _vig_mat: ShaderMaterial
var _wane := 0.0
var _wane_q := -1.0
var _flame_haze: Node2D
var _player: Node2D


# ---------------------------------------------------------------- shared materials

static func lit_material() -> ShaderMaterial:
	if _actor_mat == null:
		_actor_mat = ShaderMaterial.new()
		_actor_mat.shader = LIT
	return _actor_mat


static func room_material() -> ShaderMaterial:
	if _room_mat == null:
		_room_mat = ShaderMaterial.new()
		_room_mat.shader = LIT
	return _room_mat


## enemy.gd's hit-flash with the banded light (same `flash` / `tint` uniforms).
static func flash_shader() -> Shader:
	return LIT_FLASH


## A material that turns a smooth alpha ramp into dithered steps (the HUD's low-wax glow).
static func dither_material() -> ShaderMaterial:
	if _dither_mat == null:
		_dither_mat = ShaderMaterial.new()
		_dither_mat.shader = DITHER
	return _dither_mat


static func full() -> bool:
	return str(Game.settings.get("effects", "full")) != "lite"


# ---------------------------------------------------------------- setup

static func attach(h: Node) -> Lighting:
	var l := Lighting.new()
	l.name = "Lighting"
	l.host = h
	h.add_child(l)
	return l


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rooms = host.get("rooms_layer")
	get_tree().node_added.connect(_on_node_added)
	_walk(host)
	Game.settings_changed.connect(_on_settings)
	# the dark closing in: a full-screen dithered overlay above the world, under the HUD (layer 10)
	_vig_layer = CanvasLayer.new()
	_vig_layer.layer = 8
	add_child(_vig_layer)
	_vig = ColorRect.new()
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = VIGNETTE
	_vig.material = _vig_mat
	_vig.visible = false
	_vig_layer.add_child(_vig)
	room_material().set_shader_parameter("wane", 0.0)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	room_material().set_shader_parameter("wane", 0.0)


func _walk(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_walk(c)


func _on_node_added(n: Node) -> void:
	if n is Light2D:
		if (n as Light2D).shadow_enabled:
			(n as Light2D).shadow_filter = Light2D.SHADOW_FILTER_NONE
		return
	if not (n is CanvasItem) or n is Control:
		return
	var ci := n as CanvasItem
	if ci.material != null or not is_instance_valid(host) or not host.is_ancestor_of(ci) or ci.get_canvas_layer_node() != null:
		return
	ci.material = room_material() if _is_room_piece(ci) else lit_material()


## Floor, walls, decor, obstacles and stains: anything under the rooms layer that is not a creature,
## a pickup or Tallow. (The title has no rooms layer: its backdrop counts as a room piece.)
func _is_room_piece(n: Node) -> bool:
	var p: Node = n
	while p != null and p != host:
		if p is Enemy or p is Pickup or p is Player:
			return false
		p = p.get_parent()
	return _rooms == null or _rooms.is_ancestor_of(n)


func _on_settings() -> void:
	for h in get_tree().get_nodes_in_group("lighting_fx"):
		if h is HazeSpot:
			h.refresh()


# ---------------------------------------------------------------- per frame: waning + Tallow's haze

func _process(dt: float) -> void:
	var p: Node2D = host.get("player") if host.get("player") != null else host.get("hero")
	if p != _player:
		_player = p
		if p and p.get("flame") is Node2D:
			_flame_haze = haze(p.get("flame"), Vector2(-5, -23), Vector2(11, 14), null, 0.0)   # overlaps the tip
	var want := 0.0
	if p and p.get("wax_max") != null and float(p.get("wax_max")) > 0.0:
		var frac: float = float(p.get("wax")) / float(p.get("wax_max"))
		want = clampf((WANE_FROM - frac) / WANE_FROM, 0.0, 1.0)
	_wane = move_toward(_wane, want, dt * 0.5)
	var q := floorf(_wane * WANE_STEPS + 0.5) / WANE_STEPS
	if q != _wane_q:
		_wane_q = q
		room_material().set_shader_parameter("wane", pow(q, 0.75) * WANE_MAX)
	var vis := _wane > 0.01 and full()
	_vig.visible = vis
	if vis:
		_vig_mat.set_shader_parameter("amount", floorf(_wane * 16.0 + 0.5) / 16.0)
		var vp := get_viewport()
		var sz := vp.get_visible_rect().size
		var focus := Vector2(0.5, 0.5)
		if p:
			focus = focus.lerp((p.get_global_transform_with_canvas().origin + Vector2(0, -12)) / sz, 0.5)
		_vig_mat.set_shader_parameter("focus", focus)


## How far the house has waned (0..1), for tests.
func wane_level() -> float:
	return _wane_q


# ---------------------------------------------------------------- heat haze

## A small shimmer patch: `offset` / `size` in the parent's pixels (bottom edge = the heat source).
## `watch` (a Light2D or any CanvasItem) hides the patch while it is off or gone. `fade` > 0 hides it
## when the watched light's energy is below that.
static func haze(parent: Node2D, offset: Vector2, size: Vector2, watch: Node = null, fade := 0.3) -> HazeSpot:
	var h := HazeSpot.new()
	h.texture = _blank_tex(Vector2i(size))
	h.centered = false
	h.position = offset
	h.z_index = FX_Z
	h.z_as_relative = false
	h.watch = watch
	h.fade = fade
	var m := ShaderMaterial.new()
	m.shader = HAZE
	m.set_shader_parameter("seed", randf() * 6.28)
	h.material = m
	parent.add_child(h)
	return h


static func _blank_tex(s: Vector2i) -> Texture2D:
	if not _blank.has(s):
		var img := Image.create(maxi(1, s.x), maxi(1, s.y), false, Image.FORMAT_RGBA8)
		_blank[s] = ImageTexture.create_from_image(img)
	return _blank[s]


class HazeSpot extends Sprite2D:
	var watch: Node
	var fade := 0.3

	func _ready() -> void:
		add_to_group("lighting_fx")
		refresh()

	func refresh() -> void:
		visible = Lighting.full() and _source_on()

	func _source_on() -> bool:
		if watch == null:
			return true
		if not is_instance_valid(watch):
			return false
		if watch is Light2D:
			return (watch as Light2D).enabled and (watch as Light2D).energy >= fade
		return (watch as CanvasItem).visible

	func _process(_dt: float) -> void:
		if watch != null:
			refresh()


# ---------------------------------------------------------------- shockwave ring

## An expanding ring that pushes the pixels it crosses outward by `amp` px (1-2) for ~0.3 s.
## `at` is in the world's (global) coordinates. Returns null in Lite.
static func shockwave(world: Node, at: Vector2, radius := 32.0, amp := 2.0) -> ShockRing:
	if not full() or world == null or not world.is_inside_tree():
		return null
	var s := ShockRing.new()
	var side := int(ceil(radius * 2.0 + 12.0))
	s.texture = _blank_tex(Vector2i(side, side))
	s.centered = true
	s.z_index = FX_Z
	s.z_as_relative = false
	s.max_r = radius
	s.amp = amp
	var m := ShaderMaterial.new()
	m.shader = SHOCK
	m.set_shader_parameter("size", Vector2(side, side))
	s.material = m
	world.add_child(s)
	s.global_position = at.round()
	s._apply()
	return s


class ShockRing extends Sprite2D:
	const LIFE := 0.32
	var t := 0.0
	var max_r := 32.0
	var amp := 2.0

	func _process(dt: float) -> void:
		t += dt / LIFE
		if t >= 1.0:
			queue_free()
			return
		_apply()

	func _apply() -> void:
		var e := 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 2.0)   # fast out, slow end
		var m := material as ShaderMaterial
		m.set_shader_parameter("radius", lerpf(4.0, max_r, e))
		m.set_shader_parameter("width", lerpf(3.0, 5.0, e))
		m.set_shader_parameter("amp", roundf(amp * (1.0 - e * 0.6)) if t < 0.85 else 1.0)
