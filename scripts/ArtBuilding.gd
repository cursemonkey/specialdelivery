extends Node2D
## Marks a hand-drawn building as a delivery target.
## Place this node at the building's door position in the scene.
## It will automatically register itself with the delivery system.

const EARN_MIN := 10
const EARN_MAX := 25

var is_target     := false
var is_delivered  := false
var door_position : Vector2

signal delivered(building: Node2D, cash_earned: int)

func _ready() -> void:
	door_position = global_position
	add_to_group("art_building")

func mark_as_target() -> void:
	is_target    = true
	is_delivered = false

func clear_target() -> void:
	is_target    = false
	is_delivered = false

func receive_package(_from_pos: Vector2) -> void:
	if is_delivered:
		return
	is_delivered = true
	is_target    = false
	var earned   := EARN_MIN + randi() % (EARN_MAX - EARN_MIN + 1)
	GameManager.on_delivery_complete(earned)
	GameManager.show_message("📦 Delivered! +$%d" % earned)
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
