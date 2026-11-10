class_name Stage
extends Node
## The screen (v2.8). Root of the main scene (scenes/boot.tscn): it owns Main and decides how the picture
## reaches the glass. Settings > Controls > Screen: Big / Classic (`Game.settings["screen"]`).
##
##  - **Classic**: the path the game always had. The root viewport is the 384x216-based picture, stretched
##    by one whole number (project.godot: viewport / expand / integer). Main is a plain child of this node
##    and nothing else exists.
##  - **Big** (default): the root is the native-resolution screen and composes two low-resolution buffers,
##    each at its own whole-number scale:
##      `world_vp`  the world (rooms, creatures, light): `kw` screen pixels per art pixel, the biggest scale
##                  that still shows the whole visible room, so the room fills the screen's height;
##      `ui_vp`     menus and the HUD: `ku` screen pixels per pixel, the same logical space as Classic
##                  (384x216 at least), now reaching the screen's edges on every device.
##    Main lives inside `ui_vp`, so every screen and Control still sees "the viewport" it always saw.
##    The two buffers share one World2D. A run's world node carries WORLD_BIT in its visibility layer;
##    `ui_vp`'s cull mask leaves that bit out and `world_vp`'s takes it, so the world is drawn once, in the
##    world buffer, under a canvas transform copied from the run's own Camera2D before every frame (shake,
##    the punch, pans and zooms follow by themselves). The UI buffer is transparent and laid over the world
##    with premultiplied alpha, which gives exactly the pixels drawing it straight over the world would.
##
## Hooks: world._ready / world._exit_tree (`attach_world` / `detach_world`), main.goto (`boundary`: a changed
## Screen setting is applied between two screens, when Main is all but empty), hud / lighting (`to_ui`,
## `to_view`, `view_size`: where a world thing is on the glass), Controls and Achievements (`main_node`,
## `ui_viewport`, `adopt_layer`), autotest (`grab`, `push_ui_input`). docs/streams/v28_screen.md.

## The picture changed: the mode, a scale or a size (the HUD lays itself out again).
signal changed

const BASE := Vector2i(384, 216)
## The world the screen must always show, in art pixels. Measured from the room art: Room is a 272x192 box, its
## walls span x 11..261 (250 px) and y 12..192 (180 px, top of the top wall to the foot of the bottom wall); only
## the arch of a top door pokes into the 12 rows above. 180 is also the height every common screen divides by
## (720, 1080, 1440, 2160), so the walls meet the screen's top and bottom edges exactly there.
const VIS := Vector2i(256, 180)
const WALLS := Rect2(11, 12, 250, 180)
## 2D rendering layer of a run's world (CanvasItem.visibility_layer bit 20).
const WORLD_BIT := 1 << 19

static var inst: Stage
static var big := false
## Screen pixels per UI pixel / per world pixel (both `1` until the first fit; equal in Classic).
static var ku := 1
static var kw := 1
static var ui_vp: SubViewport
static var world_vp: SubViewport

var main: Node
var _ui_box: SubViewportContainer
var _world_box: TextureRect
var _world: Node2D
var _tap: Node
var _force := ""          # --screen=big|classic (tests)
var _force_kw := 0        # --stagekw=N (tests: Big with the world at a given scale)
var _safe := []           # --safe=l,t,r,b (tests: a fake display safe area, in screen pixels)


func _ready() -> void:
	inst = self
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			_force = a.get_slice("=", 1)
		elif a.begins_with("--stagekw="):
			_force_kw = int(a.get_slice("=", 1))
		elif a.begins_with("--safe="):
			_safe = Array(a.get_slice("=", 1).split(",")).map(func(s): return int(s))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Main pauses with the tree, as it always did under the root; said outright because in Big its parents must
	# not (a paused container would stop handing input to the pause menu)
	main.process_mode = Node.PROCESS_MODE_PAUSABLE
	_apply(wanted())
	_fit_window()
	get_tree().root.size_changed.connect(_fit)
	RenderingServer.frame_pre_draw.connect(_sync)
	Game.settings_changed.connect(_on_settings)


func _exit_tree() -> void:
	if inst == self:
		inst = null
		big = false
		ui_vp = null
		world_vp = null


# ---------------------------------------------------------------- which mode

## Tool modes that read the picture pixel by pixel at 1x (sheets, store art, judges, the trailer) keep Classic.
const CLASSIC_TOOLS := ["--herosheet", "--keyart", "--lightjudge", "--artjudge", "--shotjudge", "--designcheck"]


## The mode the player (or a test) asks for.
func wanted() -> bool:
	if _force != "":
		return _force == "big"
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a in CLASSIC_TOOLS or a.begins_with("--trailer"):
			return false
	return str(Game.settings.get("screen", "big")) != "classic"


func _on_settings() -> void:
	if wanted() == big or main == null or not main.is_inside_tree():
		return
	# on the title the change shows at once (the title lights itself again); in a run, when the night ends
	var cur: Variant = main.get("current")
	if cur == null or not is_instance_valid(cur):
		return
	if (cur as Node).name == "Title" and not bool(main.get("_busy")):
		main.call_deferred("goto", "title")
	elif (cur as Node).name == "Game" and (cur as Node).get("hud") != null:
		(cur as Node).get("hud").show_hint(L.t("The screen changes when this night ends"), 4.0)


## main.goto calls this between two screens (the old one is gone, the new one not made yet).
static func boundary() -> void:
	if inst != null and inst.wanted() != big:
		inst._apply(inst.wanted())


func _apply(want_big: bool) -> void:
	var root := get_tree().root
	if main.get_parent() != null:
		main.get_parent().remove_child(main)
	big = want_big
	if not want_big:
		Achievements.stage_changed()   # its toasts come home before the UI buffer goes
		_drop_boxes()
		root.content_scale_size = BASE
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		ku = maxi(1, mini(root.size.x / BASE.x, root.size.y / BASE.y))
		kw = ku
		add_child(main)
	else:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		_make_boxes()
		_fit()
		ui_vp.add_child(main)
		Achievements.stage_changed()
	Controls.stage_changed()
	changed.emit()
	_report()


func _report() -> void:
	var root := get_tree().root
	var view := Vector2(world_vp.size) if big and world_vp != null else ui_size()
	print("[stage] %s: screen %dx%d, ui %dx%d x%d, world %dx%d x%d" % ["big" if big else "classic", root.size.x, root.size.y,
		int(ui_size().x), int(ui_size().y), ku, int(view.x), int(view.y), kw])


func _make_boxes() -> void:
	if _ui_box != null:
		return
	world_vp = SubViewport.new()
	world_vp.name = "WorldView"
	_dress(world_vp)
	world_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world_vp.canvas_cull_mask = 1 | WORLD_BIT
	add_child(world_vp)
	_world_box = TextureRect.new()
	_world_box.name = "WorldBox"
	_world_box.texture = world_vp.get_texture()
	_world_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_world_box.stretch_mode = TextureRect.STRETCH_SCALE
	_world_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_box.visible = false
	add_child(_world_box)
	_ui_box = SubViewportContainer.new()
	_ui_box.name = "UiBox"
	_ui_box.process_mode = Node.PROCESS_MODE_ALWAYS   # it hands input on while the game is paused too
	_ui_box.stretch = true
	_ui_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_ui_box.material = mat
	add_child(_ui_box)
	ui_vp = SubViewport.new()
	ui_vp.name = "UiView"
	_dress(ui_vp)
	ui_vp.transparent_bg = true
	ui_vp.audio_listener_enable_2d = true
	ui_vp.canvas_cull_mask = 0xFFFFFFFF & ~WORLD_BIT
	ui_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ui_box.add_child(ui_vp)
	world_vp.world_2d = ui_vp.find_world_2d()   # one world, two buffers
	_tap = InputTap.new()
	_tap.name = "ControlsTap"
	ui_vp.add_child(_tap)
	ui_vp.gui_focus_changed.connect(Controls._on_focus_changed)


## What the root viewport gets from the project settings and a SubViewport does not.
func _dress(vp: SubViewport) -> void:
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS


func _drop_boxes() -> void:
	if _ui_box == null:
		return
	for n in [_ui_box, _world_box, world_vp]:
		remove_child(n)
		n.queue_free()
	_ui_box = null
	_world_box = null
	_tap = null
	ui_vp = null
	world_vp = null
	_world = null


## A desktop window. The project's 1536x864 window is 384x216 x4, where Big can do no better than Classic (the
## room needs 180 rows per step of scale: 864 holds four). On a screen with room for it Big opens 1600x900
## instead: the room at x5, wall to wall in height, the menus at x4. A window the player sized, a fullscreen
## window, a --resolution on the command line and the browser's canvas are left alone.
func _fit_window() -> void:
	if not big or DisplayServer.get_name() == "headless" or not OS.has_feature("pc") or OS.has_feature("web"):
		return
	if "--resolution" in OS.get_cmdline_args() or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	if DisplayServer.window_get_size() != Vector2i(1536, 864):
		return
	var want := Vector2i(1600, 900)
	var scr := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr)
	if usable.size.x < want.x or usable.size.y - 40 < want.y:
		return
	DisplayServer.window_set_size(want)
	DisplayServer.window_set_position(usable.position + (usable.size - want) / 2)


## Big: the two scales and buffer sizes for the screen as it is now.
func _fit() -> void:
	var root := get_tree().root
	var win := root.size
	if not big:
		ku = maxi(1, mini(win.x / BASE.x, win.y / BASE.y))
		kw = ku
		return
	if win.x <= 0 or win.y <= 0:
		return
	ku = maxi(1, mini(win.x / BASE.x, win.y / BASE.y))
	kw = maxi(ku, mini(win.x / VIS.x, win.y / VIS.y))
	if _force_kw > 0:
		kw = _force_kw
	# a window smaller than the game (a headless test's dummy display) still gets the whole 384x216 picture, as Classic
	var ui := Vector2i(maxi(BASE.x, ceili(win.x / float(ku))), maxi(BASE.y, ceili(win.y / float(ku))))
	var view := ui
	if kw != ku:
		view = Vector2i(maxi(VIS.x, ceili(win.x / float(kw))), maxi(VIS.y, ceili(win.y / float(kw))))
	_ui_box.stretch_shrink = ku
	_ui_box.position = Vector2.ZERO
	_ui_box.size = Vector2(ui * ku)        # the container sizes ui_vp to size / shrink: exactly `ui`
	if world_vp.size != view:
		world_vp.size = view
	_world_box.position = Vector2.ZERO
	_world_box.size = Vector2(view * kw)
	changed.emit()


# ---------------------------------------------------------------- the world

static func attach_world(w: Node2D) -> void:
	if inst == null or not big:
		return
	inst._world = w
	w.visibility_layer = WORLD_BIT
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	inst._world_box.visible = true
	inst._sync()


static func detach_world(w: Node2D) -> void:
	if inst == null or not big or inst._world != w:
		return
	inst._world = null
	world_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	inst._world_box.visible = false


## World -> world-buffer pixels, from the run's camera as it stands now.
func _view_xform() -> Transform2D:
	var half := Vector2(world_vp.size) * 0.5
	var cam: Camera2D = _world.get("cam") if _world != null and is_instance_valid(_world) else null
	if cam == null:
		return Transform2D(0.0, half)
	var z := cam.zoom
	var centre := cam.get_screen_center_position() + _shift()
	return Transform2D(Vector2(z.x, 0.0), Vector2(0.0, z.y), half - centre * z)


## A view shorter than the room's box keeps the bottom wall on the bottom edge (the dark rows above the top wall
## go first): the camera's centre moves down by half the rows that do not fit.
func _shift() -> Vector2:
	return Vector2(0.0, maxf(0.0, (Room.H - world_vp.size.y) * 0.5))


func _sync() -> void:
	if big and _world != null and is_instance_valid(_world):
		world_vp.canvas_transform = _view_xform()


# ---------------------------------------------------------------- where things are

## Main (the node that owns the current screen), wherever the mode put it.
static func main_node() -> Node:
	return inst.main if inst != null else null


## The viewport menus and the HUD live in.
static func ui_viewport(n: Node) -> Viewport:
	return ui_vp if big and ui_vp != null else n.get_tree().root


## The UI's logical size (what a HUD or menu calls the screen).
static func ui_size() -> Vector2:
	if big and ui_vp != null:
		return Vector2(ui_vp.size)
	return inst.get_tree().root.get_visible_rect().size if inst != null else Vector2(BASE)


## The buffer a run's world is drawn in, in world pixels (the UI's own size while no run is on, and in Classic).
static func view_size() -> Vector2:
	if big and world_vp != null and inst != null and inst._world != null:
		return Vector2(world_vp.size)
	return ui_size()


## A world thing's place in the world buffer (pixels from its top-left corner).
static func to_view(n: CanvasItem) -> Vector2:
	if big and inst != null and inst._world != null:
		return inst._view_xform() * n.get_global_transform().origin
	return n.get_global_transform_with_canvas().origin


## A world thing's place on the UI's canvas (where the HUD would draw a mark on it).
static func to_ui(n: CanvasItem) -> Vector2:
	if big and inst != null and inst._world != null:
		return to_view(n) * float(kw) / float(ku)
	return n.get_global_transform_with_canvas().origin


## The room's walls (WALLS, with the camera at rest on the room) on the UI's canvas: what the HUD lays out around.
static func room_rect_ui() -> Rect2:
	var view := view_size()
	var k := float(kw) / float(ku)
	var shift := inst._shift().y if big and inst != null and world_vp != null else 0.0
	var origin := Vector2(view.x * 0.5 - Room.W * 0.5, view.y * 0.5 - Room.H * 0.5 - shift)   # the room box's corner
	return Rect2((origin + WALLS.position) * k, WALLS.size * k)


## The display's safe area as insets in UI pixels: [left, top, right, bottom] (notches, rounded corners).
static func safe_insets() -> Array:
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if inst != null and inst._safe.size() == 4:
		safe = Rect2(inst._safe[0], inst._safe[1], win.x - inst._safe[0] - inst._safe[2], win.y - inst._safe[1] - inst._safe[3])
	if win.x <= 0.0 or safe.size.x <= 0.0:
		return [0.0, 0.0, 0.0, 0.0]
	var k := ui_size().x / win.x if not big else 1.0 / float(ku)
	return [floorf(maxf(0.0, safe.position.x * k)), floorf(maxf(0.0, safe.position.y * k)),
		floorf(maxf(0.0, (win.x - safe.end.x) * k)), floorf(maxf(0.0, (win.y - safe.end.y) * k))]


# ---------------------------------------------------------------- helpers for layers and tests

## A CanvasLayer that lives outside Main (an autoload's toasts) is drawn with the UI: in Big it moves into the UI
## buffer, in Classic it goes back to `home`.
static func adopt_layer(layer: CanvasLayer, home: Node) -> void:
	var want: Node = ui_vp if big and ui_vp != null else home
	if layer.get_parent() == want:
		return
	if layer.get_parent() != null:
		layer.get_parent().remove_child(layer)
	want.add_child(layer)


## The whole picture as the player sees it (Big: the composed screen at native size).
static func grab(n: Node) -> Image:
	if big:
		return n.get_tree().root.get_texture().get_image()
	return n.get_viewport().get_texture().get_image()


## The world alone at one pixel per art pixel (Classic: the whole picture, as before).
static func grab_world(n: Node) -> Image:
	if big and world_vp != null:
		return world_vp.get_texture().get_image()
	return n.get_viewport().get_texture().get_image()


## Tests: push an event whose position is in UI pixels, as a finger or a mouse on the glass would send it.
static func push_ui_input(n: Node, e: InputEvent) -> void:
	if big:
		e = e.xformed_by(Transform2D().scaled(Vector2(ku, ku)))
	n.get_tree().root.push_input(e, true)


## Big: Controls' own input handlers must run where they always ran: after the screen's nodes, before its
## Controls (a SubViewportContainer hands an event to the buffer before the root's autoloads see it). This
## node is the UI buffer's first child, so it is the last to be asked.
class InputTap extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		Controls.stage_input(event)

	func _unhandled_input(event: InputEvent) -> void:
		Controls.stage_unhandled_input(event)
