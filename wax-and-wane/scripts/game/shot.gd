class_name Shot
extends Node2D
## A projectile. Position is where it is drawn (in the air); the ground point used for walls is a few
## pixels below. Player embers light the floor as they fly.
## Enemy shots (v2.1, docs/streams/v21_shots.md) are drawn self-lit at full brightness on every floor and at
## any wax (the dark, the shadows and the waning never touch them), 9 px or 11 px ("Enemy shots: Normal /
## Large" in the settings, applied live; phones start on Large), with a gentle two-frame pulse that all enemy
## shots keep in step and a short trail behind fast ones. Drawing only: the hitbox (`radius`, set by world.gd),
## the speed and the damage are the same at both sizes.

var world: Node
var vel := Vector2.ZERO
var dmg := 1.0
var life := 1.0
var friendly := true
var pierce := 0
var homing := 0.0
var burn := 0.0
var knock := 60.0
var radius := 3.0
var spr: AnimatedSprite2D
var light: PointLight2D
var _hit := {}
var _dead := false
# lobbed shots (flasks): fly to a target point in an arc, burst on landing
var lob := false
var lob_from := Vector2.ZERO
var lob_to := Vector2.ZERO
var lob_t := 0.0
var lob_dur := 0.9
## Ember lights are capped so a room never exceeds the renderer's per-item light limit.
static var _lights := 0
var _blue := false
var _tr_t := 0.0
const TRAIL := [Color("#ee8e2e"), Color("#da4e38"), Color("#8f4029")]
const TRAIL_BLUE := [Color("#72d6ce"), Color("#5698cc"), Color("#5956bd")]
## Enemy shots: the pulse rate (two frames: a full beat every 0.4 s) and the speed from which a shot leaves a
## trail (aimed fans and dashes do; the slow rings of a burst do not).
const ENEMY_FPS := 5.0
const TRAIL_MIN_SPEED := 80.0
## The trail behind an enemy shot: two pixels of its rim colour, then one darker (tools/art_fx2.py BIG_TONES).
const ENEMY_TRAIL := {
	"bullet_purple": [Color("#f78697"), Color("#9b1a0a")],
	"bullet_green": [Color("#51c43f"), Color("#3d734f")],
	"bullet_water": [Color("#72d6ce"), Color("#417089")],
	"bolt_wax": [Color("#f78697"), Color("#9b1a0a")],
}
const ENEMY_TRAIL_PALE := [Color("#d3bfa9"), Color("#aa8d7a")]   # bone, cog, page, ring and new shots
static var _has_large := {}
var _kind := ""
var _half := 4.5              # half the drawn size: the trail starts right behind the sprite
var _tr_dir := Vector2.ZERO   # an enemy shot's trail direction (zero: too slow for one)


## "Enemy shots: Large" (settings, game.gd `shot_size`): the extra-bold 11 px drawings, same hitboxes.
static func large_shots() -> bool:
	return str(Game.settings.get("shot_size", "normal")) == "large"


func setup(w: Node, pos: Vector2, v: Vector2, kind: String, is_friendly: bool) -> void:
	world = w
	position = pos
	vel = v
	friendly = is_friendly
	spr = AnimatedSprite2D.new()
	if friendly:
		spr.sprite_frames = Art.anim("fx/" + kind, 12.0)
		spr.play("default")
	else:
		_kind = kind
		_apply_size()
		Game.settings_changed.connect(_apply_size)   # the setting applies to shots already in the air
		if vel.length_squared() >= TRAIL_MIN_SPEED * TRAIL_MIN_SPEED:
			_tr_dir = vel.normalized()
	spr.material = Art.unshaded
	add_child(spr)
	z_index = 5
	_blue = kind.contains("blue")
	if not friendly:
		Records.tag_shot(w, self)   # who fired it (the death note)
	material = Art.unshaded   # self-lit: the ember's spark trail glows like it, an enemy shot's trail too
	if friendly and _lights < 6:
		_lights += 1
		tree_exiting.connect(func(): _lights -= 1)
		light = PointLight2D.new()
		light.texture = Art.light_tex
		light.texture_scale = 0.28
		light.energy = 0.7
		light.color = Color(0.6, 0.8, 1.0) if kind.contains("blue") else Color(1.0, 0.65, 0.3)
		add_child(light)


func _physics_process(dt: float) -> void:
	if _dead:
		return
	if not friendly and (world.freeze_t > 0.0 or Juice.holding(world)):
		return
	if lob:
		_lob_step(dt)
		return
	if homing > 0.0 and friendly:
		var tgt: Node2D = world.nearest_enemy(global_position, 90.0)
		if tgt:
			var want := (tgt.global_position + Vector2(0, -6) - global_position).normalized() * vel.length()
			vel = vel.lerp(want, minf(1.0, homing * dt * 6.0))
	position += vel * dt
	life -= dt
	var room: Room = world.room
	if friendly and has_meta("ghost"):
		# Pale Taper: a ghost passes through walls, urns and crates without touching them
		if room and not RelicFx.shot_wall(self):
			end()
			return
	elif room and room.shot_hits(global_position + Vector2(0, 6), dmg, friendly):
		if friendly and world.has_method("fx_sparks"):
			world.fx_sparks(global_position, -vel.normalized(), 4, _blue)
		if RelicFx.shot_wall(self): return
		end()
		Audio.play("hit_wall", -3.0)
		return
	if friendly:
		for e in world.enemies:
			if not is_instance_valid(e) or not e.alive or not e.active or _hit.has(e):
				continue
			if (e.global_position + Vector2(0, -e.half_h - e._jump_h)).distance_squared_to(global_position) < pow(e.radius + radius + 1.0, 2):
				_hit[e] = true
				e.take_hit(dmg, vel.normalized() * knock, burn)
				if world.has_method("fx_sparks"):
					world.fx_sparks(global_position, vel.normalized(), 2, _blue)
				RelicFx.shot_hit(self, e)
				if pierce <= 0:
					end()
					return
				pierce -= 1
	else:
		var p: Player = world.player
		if p and not p.dead and (p.global_position + Vector2(0, -8)).distance_squared_to(global_position) < pow(radius + 4.0, 2):
			p.hurt(5.0 * world.enemy_dmg_mult(), vel)
			end()
			return
	if life <= 0:
		end()
	if friendly:
		_tr_t += dt
		queue_redraw()
	else:
		var tr := vel.normalized() if vel.length_squared() >= TRAIL_MIN_SPEED * TRAIL_MIN_SPEED else Vector2.ZERO
		if not tr.is_equal_approx(_tr_dir):
			_tr_dir = tr
			queue_redraw()


## The current drawing's first frame as an Image (cached per texture): where the trail may start.
static var _masks := {}


## Null where the image is not readable (headless runs, a compressed texture): the trail then starts at `_half`.
func _mask() -> Image:
	var tex := spr.sprite_frames.get_frame_texture("default", 0)
	if not _masks.has(tex):
		var img: Image = tex.get_image() if tex else null
		_masks[tex] = img if img != null and not img.is_empty() and not img.is_compressed() else null
	return _masks[tex]


## Normal (9 px) or Large (11 px, when this shot has a Large drawing), keeping the pulse in step.
func _apply_size() -> void:
	if not _has_large.has(_kind):
		_has_large[_kind] = Art.has("fx/%s_lg_f0" % _kind)
	var sf := Art.anim("fx/%s%s" % [_kind, "_lg" if large_shots() and _has_large[_kind] else ""], ENEMY_FPS)
	# v2.10: the pack's shots have no bolder drawing, so Large shows the same one half as big again
	spr.scale = Vector2(1.5, 1.5) if large_shots() and not _has_large[_kind] else Vector2.ONE
	if spr.sprite_frames == sf:
		return
	spr.sprite_frames = sf
	_half = sf.get_frame_texture("default", 0).get_width() / 2.0
	# one clock for every enemy shot, so a burst or a spiral pulses as one
	var beat := Time.get_ticks_msec() / 1000.0 * ENEMY_FPS
	spr.play("default")
	spr.set_frame_and_progress(int(beat) % sf.get_frame_count("default"), fmod(beat, 1.0))
	queue_redraw()


## A short spark trail behind player embers (3 pixels, cooling as they trail off); behind a fast enemy shot,
## a steady 3 px streak of its own colour right at its back edge.
func _draw() -> void:
	if _dead:
		return
	if not friendly:
		if _tr_dir != Vector2.ZERO:
			var ec: Array = ENEMY_TRAIL.get(_kind, ENEMY_TRAIL_PALE)
			# walk out from the middle: the trail starts at the first pixel the drawing leaves empty, so it
			# always touches the outline (a 1 px line out of a round shot would leave a gap at some angles)
			var img := _mask()
			var last := Vector2(INF, INF)
			var n := 0
			var t := 0.0 if img else _half + 0.5
			while n < 3 and t < _half + 6.0:
				var p := (-_tr_dir * t).round()
				t += 0.5
				if p == last:
					continue
				last = p
				if n == 0 and img:
					var q := Vector2i(p) + Vector2i(img.get_width() / 2, img.get_height() / 2)
					if Rect2i(Vector2i.ZERO, img.get_size()).has_point(q) and img.get_pixelv(q).a > 0.5:
						continue
				draw_rect(Rect2(p, Vector2.ONE), ec[0] if n < 2 else ec[1])
				n += 1
		return
	if vel.length_squared() < 100.0:
		return
	var back := -vel.normalized()
	var cols: Array = TRAIL_BLUE if _blue else TRAIL
	var flick := int(_tr_t * 30.0) % 2
	for i in 3:
		if i == 2 and flick == 1:
			continue
		var p := (back * (4.0 + 3.0 * i)).round()
		draw_rect(Rect2(p, Vector2.ONE), cols[i])


func _lob_step(dt: float) -> void:
	lob_t += dt
	var k := clampf(lob_t / lob_dur, 0.0, 1.0)
	position = lob_from.lerp(lob_to, k) + Vector2(0, -sin(k * PI) * 40.0)
	spr.rotation += dt * 9.0
	if k >= 1.0:
		_dead = true
		world.burst(lob_to, 6, 70.0, "bullet_green", randf() * TAU)
		Audio.play("splash")
		queue_free()


func end() -> void:
	if _dead:
		return
	_dead = true
	world.fx_poof(global_position, friendly)
	queue_free()
