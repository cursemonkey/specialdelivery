extends CharacterBody2D

# ── Constants ──────────────────────────────────────────────
const TILE_SIZE       := 16
const FOOT_SPEED      := 80.0
const BIKE_MAX_SPEED  := 160.0
const BIKE_ACCEL      := 5.0
const BIKE_FRICTION   := 0.90
const BIKE_TURN_SPEED := 1.8   # radians/sec (speed-scaled)
const BOOST_MULT      := 1.8
const SLOW_MULT       := 0.4
const BOOST_DURATION  := 1.5
const SLOW_DURATION   := 1.0
const THROW_RANGE     := 5 * TILE_SIZE   # pixel range for toss

# ── State ──────────────────────────────────────────────────
var on_bike       := false
var bike_speed    := 0.0
var bike_angle    := -PI / 2.0   # facing up

var boost_timer   := 0.0
var slow_timer    := 0.0

var facing        := Vector2.DOWN
var walk_frame    := 0
var walk_timer    := 0.0

# ── References ─────────────────────────────────────────────
@onready var foot_sprite  : Node2D = $FootSprite
@onready var bike_sprite  : Node2D = $BikeSprite
@onready var anim_player  : AnimationPlayer = $AnimationPlayer
@onready var boost_aura   : Node2D = $BoostAura
@onready var slow_aura    : Node2D = $SlowAura
@onready var throw_marker : Node2D = $ThrowMarker

# Reference set from World
var delivery_targets : Array = []

# ── Signals ────────────────────────────────────────────────
signal mounted_bike()
signal dismounted_bike()

# ───────────────────────────────────────────────────────────
func _ready() -> void:
	_set_mode(false)
	boost_aura.visible = false
	slow_aura.visible  = false

func _physics_process(delta: float) -> void:
	_tick_effects(delta)
	if on_bike:
		_process_bike(delta)
	else:
		_process_foot(delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mount_bike"):
		_toggle_bike()
	if event.is_action_pressed("throw_package"):
		_try_throw()

# ── Mode switching ─────────────────────────────────────────
func _toggle_bike() -> void:
	on_bike = !on_bike
	if on_bike:
		bike_speed = 0.0
		bike_angle = velocity.angle() if velocity.length() > 10 else -PI / 2.0
		mounted_bike.emit()
		GameManager.show_message("🚲 Hopped on the bicycle!")
	else:
		bike_speed = 0.0
		dismounted_bike.emit()
		GameManager.show_message("🚶 Back on foot!")
	_set_mode(on_bike)

func _set_mode(biking: bool) -> void:
	foot_sprite.visible = !biking
	bike_sprite.visible =  biking

# ── Foot movement ──────────────────────────────────────────
func _process_foot(delta: float) -> void:
	var dir := _get_dir()
	var spd := FOOT_SPEED * _speed_mult()
	velocity = dir * spd

	if dir != Vector2.ZERO:
		facing = dir.normalized()
		walk_timer += delta
		if walk_timer >= 0.15:
			walk_timer = 0.0
			walk_frame = (walk_frame + 1) % 4
	else:
		walk_timer = 0.0
		walk_frame = 0

	foot_sprite.rotation = 0.0
	_update_foot_visual()

# ── Bike movement ──────────────────────────────────────────
func _process_bike(delta: float) -> void:
	var turn_input := 0.0
	if Input.is_action_pressed("move_left"):  turn_input = -1.0
	if Input.is_action_pressed("move_right"): turn_input =  1.0

	var accel  := Input.is_action_pressed("move_up")
	var braking := Input.is_action_pressed("move_down")
	var mult   := _speed_mult()

	if accel:
		bike_speed = move_toward(bike_speed, BIKE_MAX_SPEED * mult, BIKE_ACCEL * mult)
	elif braking:
		if bike_speed > 1.0:
			bike_speed = move_toward(bike_speed, 0.0, BIKE_ACCEL * 2.0)
		else:
			bike_speed = move_toward(bike_speed, -BIKE_MAX_SPEED * 0.35, BIKE_ACCEL)
	else:
		bike_speed *= BIKE_FRICTION
		if abs(bike_speed) < 0.5:
			bike_speed = 0.0

	if abs(bike_speed) > 2.0:
		var turn_factor: int = clamp(abs(bike_speed) / BIKE_MAX_SPEED, 0.3, 1.0)
		bike_angle += turn_input * BIKE_TURN_SPEED * turn_factor * sign(bike_speed) * delta

	velocity = Vector2(cos(bike_angle), sin(bike_angle)) * bike_speed
	bike_sprite.rotation = bike_angle + PI / 2.0

# ── Throwing ───────────────────────────────────────────────
func _try_throw() -> void:
	if GameManager.packages <= 0:
		GameManager.show_message("No packages left!")
		return

	var best_target  = null
	var best_dist    := THROW_RANGE

	for target in delivery_targets:
		if target.is_delivered:
			continue
		var d := global_position.distance_to(target.door_position)
		if d < best_dist:
			best_dist   = d
			best_target = target

	if best_target == null:
		GameManager.show_message("No delivery nearby! Get closer.")
		return

	if GameManager.use_package():
		best_target.receive_package(global_position)

# ── Effects ────────────────────────────────────────────────
func apply_boost() -> void:
	boost_timer = BOOST_DURATION
	boost_aura.visible = true
	GameManager.show_message("💨 Speed Boost!")

func apply_slow() -> void:
	slow_timer = SLOW_DURATION
	slow_aura.visible = true
	GameManager.show_message("😵 Slowed down!")

func _tick_effects(delta: float) -> void:
	if boost_timer > 0.0:
		boost_timer -= delta
		if boost_timer <= 0.0:
			boost_aura.visible = false
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_aura.visible = false

func _speed_mult() -> float:
	if boost_timer > 0.0: return BOOST_MULT
	if slow_timer  > 0.0: return SLOW_MULT
	return 1.0

# ── Helpers ────────────────────────────────────────────────
func _get_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    d.y -= 1
	if Input.is_action_pressed("move_down"):  d.y += 1
	if Input.is_action_pressed("move_left"):  d.x -= 1
	if Input.is_action_pressed("move_right"): d.x += 1
	return d.normalized()

func _update_foot_visual() -> void:
	# Flip / frame index passed to custom draw on FootSprite
	if foot_sprite.has_method("set_facing"):
		foot_sprite.set_facing(facing, walk_frame)
