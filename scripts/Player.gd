extends CharacterBody2D

# ── Constants ──────────────────────────────────────────────
const TILE_SIZE       := 16
const FOOT_SPEED      := 80.0
const BIKE_MAX_SPEED  := 148.0
const BIKE_ACCEL      := 5.0
const BIKE_FRICTION   := 0.90
const BIKE_TURN_SPEED := 2.8   # radians/sec (speed-scaled)
const STRAIGHTEN_TOLERANCE := PI / 12.0   # 10 degrees
const STRAIGHTEN_DELAY     := 0.1         # seconds within tolerance before easing starts
const STRAIGHTEN_SPEED     := 4.0         # lerp_angle weight/sec once easing starts
const BOOST_MULT      := 1.8
const SLOW_MULT       := 0.4
const BOOST_DURATION  := 1.5
const SLOW_DURATION   := 1.0
const THROW_RANGE      := 5 * TILE_SIZE   # pixel range for toss
const BIKE_MOUNT_RANGE := 3 * TILE_SIZE   # how close player must be to mount
const TRAIL_STEP       := 12.0            # px between recorded trail positions

# 8-direction bike textures ordered E, SE, S, SW, W, NW, N, NE
# (index = int(fposmod(deg + 22.5, 360) / 45))
const BIKE_TEXTURES : Array = [
	preload("res://assets/Hero/Hero_Bike_E.png"),
	preload("res://assets/Hero/Hero_bike_SE.png"),
	preload("res://assets/Hero/Hero_Bike_S.png"),
	preload("res://assets/Hero/Hero_Bike_SW.png"),
	preload("res://assets/Hero/Hero_Bike_W.png"),
	preload("res://assets/Hero/hero_bike_NW.png"),
	preload("res://assets/Hero/Hero_Bike_N.png"),
	preload("res://assets/Hero/Hero_Bike_NE.png"),
]

# ── State ──────────────────────────────────────────────────
var on_bike       := false
var bike_speed    := 0.0
var bike_angle    := -PI / 2.0   # facing up
var bike_frame    := 0
var bike_timer    := 0.0
var _bike_dir_index    := -1
var _visual_bike_angle := -PI / 2.0   # for sprite selection only, turns at full speed
var _straighten_timer  := 0.0   # time spent near a cardinal heading without steering


var boost_timer   := 0.0
var slow_timer    := 0.0

var facing        := Vector2.DOWN
var walk_frame    := 0
var walk_timer    := 0.0

# ── References ─────────────────────────────────────────────
@onready var foot_sprite  : Sprite2D = $FootSprite
#@onready var bike_sprite  : Node2D = $BikeSprite
@onready var bike_sprite  : Sprite2D = $BikeSprite2

@onready var anim_player  : AnimationPlayer = $AnimationPlayer
@onready var boost_aura   : Node2D = $BoostAura
@onready var slow_aura    : Node2D = $SlowAura
@onready var throw_marker : Node2D = $ThrowMarker

# References set from Main
var delivery_targets : Array = []
var world_bike       : Node2D = null

# Path trail for bird following
var path_trail       : Array[Vector2] = []
var _last_trail_pos  : Vector2 = Vector2.ZERO

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
	_record_trail()

func _record_trail() -> void:
	if global_position.distance_to(_last_trail_pos) >= TRAIL_STEP:
		path_trail.append(global_position)
		_last_trail_pos = global_position

func reset_trail() -> void:
	path_trail.clear()
	_last_trail_pos = global_position

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mount_bike"):
		_toggle_bike()
	if event.is_action_pressed("throw_package"):
		_try_throw()

# ── Mode switching ─────────────────────────────────────────
func _toggle_bike() -> void:
	if on_bike:
		_dismount()
	else:
		_try_mount()

func _try_mount() -> void:
	if world_bike == null or not world_bike.visible:
		GameManager.show_message("No bike nearby!")
		return
	if global_position.distance_to(world_bike.global_position) > BIKE_MOUNT_RANGE:
		GameManager.show_message("🚲 Get closer to the bike first!")
		return
	on_bike = true
	bike_speed = 0.0
	bike_angle = velocity.angle() if velocity.length() > 10 else -PI / 2.0
	_visual_bike_angle = bike_angle
	_straighten_timer = 0.0
	world_bike.visible = false
	_set_mode(true)
	mounted_bike.emit()
	GameManager.show_message("🚲 Hopped on the bicycle!")

func _dismount() -> void:
	on_bike = false
	bike_speed = 0.0
	if world_bike != null:
		world_bike.global_position = global_position + Vector2(TILE_SIZE, 0)
		world_bike.visible = true
	_set_mode(false)
	dismounted_bike.emit()
	GameManager.show_message("🚶 Back on foot!")

func force_dismount() -> void:
	if on_bike:
		on_bike = false
		bike_speed = 0.0
		_set_mode(false)

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
			walk_frame = (walk_frame + 1) % 6
	else:
		walk_timer = 0.0
		walk_frame = 0

	foot_sprite.flip_h = facing.x < 0
	foot_sprite.region_rect = Rect2(walk_frame * 68, 0, 68, 60) 
	#width?, height start, width, height

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
		var turn_factor: float = clamp(abs(bike_speed) / BIKE_MAX_SPEED, 0.3, 1.0)
		bike_angle += turn_input * BIKE_TURN_SPEED * turn_factor * sign(bike_speed) * delta

	# Auto-straighten: if riding nearly N/E/S/W without steering input, hold
	# that for a bit then ease the heading onto the exact cardinal direction.
	if turn_input == 0.0 and abs(bike_speed) > 2.0:
		var nearest_cardinal: float = round(bike_angle / (PI / 2.0)) * (PI / 2.0)
		if abs(angle_difference(bike_angle, nearest_cardinal)) <= STRAIGHTEN_TOLERANCE:
			_straighten_timer += delta
			if _straighten_timer >= STRAIGHTEN_DELAY:
				bike_angle = lerp_angle(bike_angle, nearest_cardinal, STRAIGHTEN_SPEED * delta)
		else:
			_straighten_timer = 0.0
	else:
		_straighten_timer = 0.0

	velocity = Vector2(cos(bike_angle), sin(bike_angle)) * bike_speed

	# Visual angle turns at full BIKE_TURN_SPEED on input so the sprite reacts immediately,
	# independent of the physics turn_factor. Snaps back to bike_angle when not turning.
	if turn_input != 0.0:
		_visual_bike_angle += turn_input * BIKE_TURN_SPEED * delta
	else:
		_visual_bike_angle = bike_angle

	# Direction: 8-way lookup. Angle 0=East, clockwise. Offset +22.5 centres each 45° sector.
	var dir_index := int(fposmod(rad_to_deg(_visual_bike_angle) + 22.5, 360.0) / 45.0)
	if dir_index != _bike_dir_index:
		_bike_dir_index = dir_index
		bike_sprite.texture = BIKE_TEXTURES[dir_index]

	# Frame animation — runs in reverse when backing up
	if bike_speed != 0.0:
		bike_timer += delta
		if bike_timer >= 0.15:
			bike_timer = 0.0
			bike_frame = (bike_frame + 5 + int(sign(bike_speed))) % 5
	else:
		bike_timer = 0.0
		bike_frame = 0
	bike_sprite.frame = bike_frame



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
