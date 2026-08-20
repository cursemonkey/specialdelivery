class_name NPCSprite
extends Node2D
## Draws a villager sprite procedurally (same approach as FootSprite.gd).
## Palette is exported so every NPC can look distinct without new art.
## NPCBase calls set_facing() whenever facing or walk frame changes.

@export var shirt_color : Color = Color("#c46a5a")
@export var pants_color : Color = Color("#4a4a5e")
@export var hair_color  : Color = Color("#3a2a1a")
@export var skin_color  : Color = Color("#e8c8a0")
@export var bald        : bool  = false
# Background villagers set this: a blank, expressionless "NPC-meme" face
# (dead dot eyes + a flat straight mouth) instead of the direction-aware eyes.
@export var meme_style  : bool  = false

# ── Sprite sheet (optional) ────────────────────────────────
# Set `sheet` and the drawing above is replaced by real art. The sheet is a grid
# of frames: one ROW per facing (order given by ROW_ORDER) and one COLUMN per
# walk frame. Leave `sheet` null to keep the procedural villager.
@export var sheet        : Texture2D = null
@export var frame_size	: Vector2i  = Vector2i(48, 48)   # size of one frame in px
@export var frame_count  : int       = 4                  # walk frames per row
@export var sheet_offset : Vector2   = Vector2(0, -8)     # nudge art onto the feet
@export var sheet_scale  : float     = 1.0                # shrink/grow large source art

# ── Idle animation ─────────────────────────────────────────
# Optional separate idle art. Leave `idle_sheet` null and set `idle_reuses_walk`
# to animate idle from the walk frames (handy while placeholder art is the only
# art). With both unset, idle simply rests on frame 0 as before.
@export var idle_sheet       : Texture2D = null
@export var idle_frame_count : int       = 0      # 0 = use frame_count
@export var idle_frame_time  : float     = 0.28   # seconds per idle frame
@export var idle_reuses_walk : bool      = false  # animate idle from the walk frames

var _walking : bool = false

func _ready() -> void:
	# The global Sprite Scale setting scales the whole cast uniformly, on top of
	# each NPC's own sheet_scale (procedural NPCs use it directly).
	GameManager.sprite_scale_changed.connect(_on_global_scale_changed)
	_on_global_scale_changed(GameManager.sprite_scale)

func _on_global_scale_changed(value: float) -> void:
	scale = Vector2(value, value)
	queue_redraw()

## Which sheet is on screen right now.
func _active_sheet() -> Texture2D:
	if not _walking and idle_sheet != null:
		return idle_sheet
	return sheet

## How many frames the current state animates through. Returns 1 for a static
## idle so the frame counter stays parked on 0.
func frames_for_state(walking: bool) -> int:
	if walking:
		return maxi(1, frame_count)
	if idle_sheet != null:
		return maxi(1, idle_frame_count if idle_frame_count > 0 else frame_count)
	if idle_reuses_walk and sheet != null:
		return maxi(1, idle_frame_count if idle_frame_count > 0 else frame_count)
	return 1   # no idle animation: hold frame 0

func set_state(walking: bool) -> void:
	if _walking != walking:
		_walking = walking
		queue_redraw()

## Row index per facing. A sheet with fewer rows falls back to row 0.
const ROW_DOWN  : int = 0
const ROW_LEFT  : int = 1
const ROW_RIGHT : int = 2
const ROW_UP    : int = 3

var _facing     : Vector2 = Vector2.DOWN
var _walk_frame : int     = 0

func set_facing(f: Vector2, frame: int) -> void:
	_facing     = f
	_walk_frame = frame
	queue_redraw()

func _draw() -> void:
	if _active_sheet() != null:
		_draw_sheet()
		return
	_draw_procedural()

## Blit the frame matching the current facing and walk step.
func _draw_sheet() -> void:
	var sheet : Texture2D = _active_sheet()
	var rows : int = maxi(1, int(sheet.get_height() / maxi(1, frame_size.y)))
	var row  : int = _row_for_facing()
	if row >= rows:
		row = 0
	var col : int = _walk_frame % maxi(1, frame_count)
	var src : Rect2 = Rect2(
		Vector2(col * frame_size.x, row * frame_size.y),
		Vector2(frame_size))
	# Scale the frame, anchored on the NPC's feet rather than its centre.
	var draw_size : Vector2 = Vector2(frame_size) * sheet_scale
	var dst : Rect2 = Rect2(
		sheet_offset - Vector2(draw_size.x * 0.5, draw_size.y),
		draw_size)
	# Flip horizontally for LEFT when the sheet has no dedicated left row.
	if _facing == Vector2.LEFT and rows <= ROW_LEFT:
		draw_texture_rect_region(sheet, Rect2(dst.position + Vector2(dst.size.x, 0),
				Vector2(-dst.size.x, dst.size.y)), src)
	else:
		draw_texture_rect_region(sheet, dst, src)

func _row_for_facing() -> int:
	if _facing == Vector2.UP:    return ROW_UP
	if _facing == Vector2.LEFT:  return ROW_LEFT
	if _facing == Vector2.RIGHT: return ROW_RIGHT
	return ROW_DOWN

func _draw_procedural() -> void:
	var leg_bob : int = [0, 3, 0, -3][_walk_frame % 4]

	# Shadow
	_draw_ellipse(Vector2(0, 10), Vector2(7, 3), Color(0, 0, 0, 0.18))

	# Shoes
	draw_rect(Rect2(-5, 14 + leg_bob, 4, 3), Color("#2c1a0e"))
	draw_rect(Rect2( 1, 14 - leg_bob, 4, 3), Color("#2c1a0e"))

	# Legs
	draw_rect(Rect2(-5, 9,  4, 6 + leg_bob), pants_color)
	draw_rect(Rect2( 1, 9,  4, 6 - leg_bob), pants_color)

	# Shirt / body
	draw_rect(Rect2(-5, -2, 10, 11), shirt_color)

	# Head
	draw_rect(Rect2(-5, -13, 10, 11), skin_color)

	# Hair — bald characters get a rounded scalp in skin tone instead.
	if bald:
		draw_rect(Rect2(-4, -15, 8, 3), skin_color)
	else:
		draw_rect(Rect2(-5, -16, 10, 4), hair_color)

	if meme_style:
		_draw_meme_face()
	elif _facing != Vector2.UP:
		# Direction-aware eyes (hidden when facing away).
		var eye_offset : Vector2 = Vector2.ZERO
		if   _facing == Vector2.DOWN: eye_offset = Vector2(0, 1)
		elif _facing.x > 0:           eye_offset = Vector2(1, 0)
		elif _facing.x < 0:           eye_offset = Vector2(-1, 0)
		draw_rect(Rect2(-3 + eye_offset.x, -9 + eye_offset.y, 2, 2), Color("#2c1a0e"))
		draw_rect(Rect2( 1 + eye_offset.x, -9 + eye_offset.y, 2, 2), Color("#2c1a0e"))

# Blank, staring "NPC meme" face — always front-facing regardless of heading:
# two small dead eyes and a flat, straight mouth.
func _draw_meme_face() -> void:
	var feature : Color = Color("#3a3a3a")
	draw_rect(Rect2(-3, -9, 2, 2), feature)   # left eye
	draw_rect(Rect2( 1, -9, 2, 2), feature)   # right eye
	draw_rect(Rect2(-2, -5, 4, 1), feature)   # flat straight mouth

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts : PackedVector2Array = PackedVector2Array()
	for i in 32:
		var a : float = TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
