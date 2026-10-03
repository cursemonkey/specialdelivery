extends Node2D
## The item currently in hand, floating above the player's head. Purely a
## read-out of GameManager.held_item — it never changes what's held.
##
## Sits on a little bobbing motion so it reads as "carried". Hidden while
## riding — both hands are on the bars — but kept visible indoors, since inside
## is exactly where most villagers are met and gifted.

## How far above the player's origin the item floats, before sprite scaling.
const HOVER_Y      : float = -46.0
## Height of the bob, and how long one full up-down cycle takes.
const BOB_HEIGHT   : float = 3.0
const BOB_SECONDS  : float = 1.6
const ICON_SIZE    : int   = 20
## Radius of the soft disc drawn behind the icon, so it stays readable against
## a busy background.
const BACKING_R    : float = 13.0
## Items with sprite art turn slowly while held aloft, stepping through their
## rotation frames: one full turn takes this long.
const SPIN_SECONDS : float = 1.6
const SPRITE_SIZE  : float = 28.0

var _elapsed : float = 0.0

func _ready() -> void:
	# Item sprites are pixel art: keep them crisp when scaled down.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	GameManager.held_item_changed.connect(_on_held_changed)
	# The player node scales its art by the Sprite Scale setting; the hover
	# height has to follow, or the item drifts away from the head.
	GameManager.sprite_scale_changed.connect(func(_v: float) -> void: _apply_scale())
	_apply_scale()
	_refresh()

func _on_held_changed(_id: String) -> void:
	_refresh()

func _refresh() -> void:
	visible = GameManager.is_holding()
	queue_redraw()

func _apply_scale() -> void:
	var s : float = GameManager.sprite_scale
	scale    = Vector2(s, s)
	position = Vector2(0.0, HOVER_Y * s)

func _process(delta: float) -> void:
	if not GameManager.is_holding():
		if visible:
			visible = false
		return
	var player : Node = get_parent()
	# Hidden on the bike: both hands are on the bars.
	var hide : bool = player.on_bike
	if visible == hide:
		visible = not hide
	if not visible:
		return
	_elapsed += delta
	queue_redraw()

func _draw() -> void:
	var id : String = GameManager.held_item
	if id.is_empty():
		return
	var bob  : float = sin(_elapsed * TAU / BOB_SECONDS) * BOB_HEIGHT
	var font : Font  = ThemeDB.fallback_font
	var centre : Vector2 = Vector2(0.0, bob)

	# Soft dark disc so the emoji reads over grass, road, or building alike.
	draw_circle(centre, BACKING_R, Color(0.08, 0.08, 0.11, 0.55))
	draw_arc(centre, BACKING_R, 0.0, TAU, 24, Color(0.95, 0.80, 0.45, 0.75), 1.5, true)

	# Sprite art: spin through the rotation frames, a full turn per SPIN_SECONDS.
	var frames : Array[Texture2D] = ItemRegistry.rotation_frames(id)
	if not frames.is_empty():
		var step : int = int(_elapsed / SPIN_SECONDS * frames.size()) % frames.size()
		var half : Vector2 = Vector2(SPRITE_SIZE, SPRITE_SIZE) * 0.5
		draw_texture_rect(frames[step], Rect2(centre - half, half * 2.0), false)
		return

	# draw_string anchors at the text baseline, so shift down by roughly half
	# the glyph height to sit the icon in the middle of the disc.
	var icon : String = ItemRegistry.icon(id)
	draw_string(font, centre + Vector2(-ICON_SIZE * 0.5, ICON_SIZE * 0.36), icon,
			HORIZONTAL_ALIGNMENT_CENTER, float(ICON_SIZE), ICON_SIZE, Color(1, 1, 1))
