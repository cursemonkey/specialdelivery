extends Node2D
## Marks a hand-drawn building as a delivery target.
## Place this node at the building's door position in the scene.
## It will automatically register itself with the delivery system.

const EARN_MIN := 10
const EARN_MAX := 25

var is_target     := false
var is_delivered  := false
var door_position : Vector2
var package_landing_time : float = 0.0   # GameManager.play_clock when this drop landed

signal delivered(building: Node2D, cash_earned: int)

func _ready() -> void:
	door_position = global_position
	add_to_group("art_building")

func _process(_delta: float) -> void:
	if is_target and not is_delivered:
		queue_redraw()

func _draw() -> void:
	if is_delivered:
		draw_string(ThemeDB.fallback_font, Vector2(-5, -6),
					"✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#2ecc71"))
	elif is_target:
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
		var pts := PackedVector2Array([
			Vector2(0, -4),
			Vector2(-7, -14),
			Vector2(7, -14),
		])
		draw_colored_polygon(pts, Color(1.0, 0.63, 0.12, pulse))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#8b4513"), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-6, -16),
					"PKG", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#ffe8a0"))

func mark_as_target() -> void:
	is_target    = true
	is_delivered = false
	queue_redraw()

func clear_target() -> void:
	is_target    = false
	is_delivered = false
	queue_redraw()

func receive_package(_from_pos: Vector2) -> void:
	if is_delivered:
		return
	is_delivered = true
	is_target    = false
	queue_redraw()
	var base     := EARN_MIN + randi() % (EARN_MAX - EARN_MIN + 1)
	var earned   := GameManager.register_delivery(base, package_landing_time, str(name))
	GameManager.show_message("📦 Delivered! +$%d%s" \
			% [earned, GameManager.delivery_speed_tag(package_landing_time)])
	_spawn_stars()

func _spawn_stars() -> void:
	var p := CPUParticles2D.new()
	add_child(p)
	p.amount               = 12
	p.lifetime             = 0.7
	p.one_shot             = true
	p.explosiveness        = 0.95
	p.spread               = 180
	p.initial_velocity_min = 40
	p.initial_velocity_max = 80
	p.gravity              = Vector2(0, 120)
	p.scale_amount_min     = 2
	p.scale_amount_max     = 4
	p.color                = Color("#f8d080")
	p.emitting             = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
