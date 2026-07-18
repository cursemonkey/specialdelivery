class_name Building

extends StaticBody2D
## A placeable building. Can be flagged as a delivery target for the current day.

const TILE := 16
const EARN_MIN := 10
const EARN_MAX := 25

enum BuildingType { HOUSE, MANSION, BUILDING }

# Set by WorldGenerator
var building_type  : BuildingType = BuildingType.HOUSE
var tile_width     : int = 6
var tile_height    : int = 5
var wall_color     : Color = Color("#e8c99a")
var roof_color     : Color = Color("#c0392b")
var trim_color     : Color = Color("#f5deb3")
var door_tile_x    : int = 3   # local tile col of door
var building_id    : int = 0

# Runtime
var is_target      := false
var is_delivered   := false
var door_position  : Vector2   # world pixels, set after placement
var package_landing_time : float = 0.0   # GameManager.play_clock when this drop landed

# Thrown-package landing effect
var _flash_timer   := 0.0

signal delivered(building: StaticBody2D, cash_earned: int)

# ───────────────────────────────────────────────────────────
func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		queue_redraw()

# ── Public API ─────────────────────────────────────────────
func setup(type: BuildingType, tw: int, th: int,
		   wc: Color, rc: Color, tc: Color, bid: int) -> void:
	building_type = type
	tile_width    = tw
	tile_height   = th
	wall_color    = wc
	roof_color    = rc
	trim_color    = tc
	building_id   = bid
	door_tile_x   = tw / 2
	queue_redraw()

func mark_as_target() -> void:
	is_target    = true
	is_delivered = false
	queue_redraw()

func clear_target() -> void:
	is_target    = false
	is_delivered = false
	queue_redraw()

func receive_package(from_pos: Vector2) -> void:
	if is_delivered:
		return
	is_delivered = true
	is_target    = false
	_flash_timer = 0.6
	var base     := EARN_MIN + randi() % (EARN_MAX - EARN_MIN + 1)
	var earned   := GameManager.delivery_payout(base, package_landing_time)
	GameManager.on_delivery_complete(earned)
	GameManager.show_message("📦 Delivered! +$%d%s" \
			% [earned, GameManager.delivery_speed_tag(package_landing_time)])
	_spawn_stars()
	queue_redraw()

# ── Drawing ────────────────────────────────────────────────
func _draw() -> void:
	var w := tile_width  * TILE
	var h := tile_height * TILE

	# Shadow
	draw_rect(Rect2(3, 3, w, h), Color(0, 0, 0, 0.12))

	# Wall
	draw_rect(Rect2(0, 0, w, h), wall_color)

	# Delivered overlay
	if is_delivered:
		draw_rect(Rect2(0, 0, w, h), Color(0.3, 0.85, 0.3, 0.35))

	# Flash
	if _flash_timer > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 0.4, 0.4 * (_flash_timer / 0.6)))

	# Roof (top 40%)
	var roof_h: int = max(TILE, int(h * 0.40))
	draw_rect(Rect2(0, 0, w, roof_h), roof_color)

	# Trim strip
	draw_rect(Rect2(0, roof_h, w, 2), trim_color)

	# Building border
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.18), false, 1.0)

	# Windows
	var win_y: int = roof_h + 4
	var win_count: int = max(1, tile_width - 1)
	var spacing: float = float(w) / float(win_count + 1)
	for i in win_count:
		var wx: float = spacing * (i + 1) - 3.0
		if wx > 0 and wx + 6 < w:
			draw_rect(Rect2(wx, win_y, 6, 6), Color(0.7, 0.87, 1.0, 0.85))
			draw_rect(Rect2(wx, win_y, 6, 6), trim_color, false, 0.5)

	# Door
	var dw: int = max(6, TILE - 4)
	var dh: int = TILE - 2
	var dx: float = door_tile_x * TILE + (TILE - dw) / 2.0
	var dy := (tile_height - 1) * TILE + 2.0
	draw_rect(Rect2(dx, dy, dw, dh), Color("#5c3317"))
	draw_rect(Rect2(dx + dw - 4, dy + dh * 0.5 - 1, 2, 2), Color("#f8d080"))

	# Delivery target arrow (pulsing done via modulate on a Label/Sprite in scene)
	if is_target and not is_delivered:
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
		var ax := w / 2.0
		var ay := -14.0
		var pts := PackedVector2Array([
			Vector2(ax, ay + 10),
			Vector2(ax - 7, ay),
			Vector2(ax + 7, ay),
		])
		draw_colored_polygon(pts, Color(1.0, 0.63, 0.12, pulse))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#8b4513"), 1.0)
		# Package icon text
		draw_string(ThemeDB.fallback_font, Vector2(ax - 6, ay - 2),
					"PKG", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ffe8a0"))

	# Delivered check
	if is_delivered:
		draw_string(ThemeDB.fallback_font, Vector2(w/2.0 - 4, h/2.0 + 4),
					"✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#2ecc71"))

func _spawn_stars() -> void:
	# Spawn some CPUParticles2D as a simple burst
	var p := CPUParticles2D.new()
	add_child(p)
	p.position = Vector2(tile_width * TILE / 2.0, tile_height * TILE / 2.0)
	p.amount = 12
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180
	p.initial_velocity_min = 40
	p.initial_velocity_max = 80
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 2
	p.scale_amount_max = 4
	p.color = Color("#f8d080")
	p.emitting = true
	# Auto-free
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(p.queue_free)
