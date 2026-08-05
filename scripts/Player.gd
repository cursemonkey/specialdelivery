extends CharacterBody2D

# ── Constants ──────────────────────────────────────────────
const TILE_SIZE       := 16
const FOOT_SPEED      := 80.0
const BIKE_MAX_SPEED  := 148.0
const BIKE_ACCEL      := 5.0
const BIKE_FRICTION   := 0.90
const BIKE_TURN_SPEED := 2.8   # radians/sec (speed-scaled)
const STRAIGHTEN_DELAY     := 0.1         # seconds without steering before easing starts
const STRAIGHTEN_SPEED     := 4.0         # lerp_angle weight/sec once easing starts
const BOOST_MULT      := 1.8
const SLOW_MULT       := 0.4
const BOOST_DURATION  := 1.5
const SLOW_DURATION   := 1.0
const THROW_RANGE      := 5 * TILE_SIZE   # pixel range for toss
const BIKE_MOUNT_RANGE := 3 * TILE_SIZE   # how close player must be to mount
const DOOR_INTERACT_RANGE := 4 * TILE_SIZE   # how close player must be to talk at a door
const NPC_INTERACT_RANGE  := 2.25 * TILE_SIZE # how close player must be to talk to an NPC
const TRAIL_STEP       := 12.0            # px between recorded trail positions
const NPC_RUNOVER_SPEED := 40.0           # min bike speed for a spin-out crash
const SPIN_DURATION     := 0.8            # seconds of lost control after hitting an NPC
const SPIN_VISUAL_SPEED := 2.0 * TAU / 0.8   # two full sprite rotations per spin-out
const EASY_TURN_SPEED    := 6.0           # rad/sec the easy-mode bike can re-aim itself

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
var snap_to_direction  := true
var _easy_bike_angle   := -PI / 2.0   # current facing used only by easy-mode bike movement


var _hopping      := false

var boost_timer   := 0.0
var slow_timer    := 0.0
var _spin_timer   := 0.0   # > 0 while spun out after running into an NPC

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
var pause_menu       : Node   = null
var dialogue_box     : Node   = null
var doors            : Array  = []
var road_regions      : Array[NavigationRegion2D] = []
var dirt_road_regions : Array[NavigationRegion2D] = []
var grass_regions     : Array[NavigationRegion2D] = []
var drop_pad_manager : Node               = null
var home_door_node   : Node2D             = null
var input_locked     : bool               = false
var interior_manager : Node               = null
var in_interior      : bool               = false

# Path trail for bird following
var path_trail       : Array[Vector2] = []
var _last_trail_pos  : Vector2 = Vector2.ZERO

# ── Signals ────────────────────────────────────────────────
signal mounted_bike()
signal dismounted_bike()
signal home_door_activated()

# ───────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_mode(false)
	boost_aura.visible = false
	slow_aura.visible  = false

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_tick_effects(delta)
	if on_bike:
		_process_bike(delta)
	else:
		_process_foot(delta)
	move_and_slide()
	_handle_npc_collisions()
	_record_trail()

func _record_trail() -> void:
	if global_position.distance_to(_last_trail_pos) >= TRAIL_STEP:
		path_trail.append(global_position)
		_last_trail_pos = global_position

func reset_trail() -> void:
	path_trail.clear()
	_last_trail_pos = global_position

func _input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		_toggle_pause()
		return
	# E (talk to a nearby NPC / advance dialogue) works inside and outside.
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_try_dialogue()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if dialogue_box != null and dialogue_box.visible:
			dialogue_box.advance()
			return
	if dialogue_box != null and dialogue_box.visible:
		if event.is_action_pressed("mount_bike") or event.is_action_pressed("throw_package"):
			dialogue_box.close()
		return
	# Inside a building: movement still polls in _physics_process, but bike /
	# throw / hop are suppressed. The Interior handles E at the bed (sleep).
	if in_interior:
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("mount_bike"):
		_toggle_bike()
	if event.is_action_pressed("throw_package"):
		_try_throw()
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_hop()

func _toggle_pause() -> void:
	if pause_menu == null:
		return
	if get_tree().paused:
		pause_menu._on_close_button_pressed()
	else:
		pause_menu._on_pause_button_pressed()

func _try_dialogue() -> void:
	if dialogue_box == null:
		return
	if dialogue_box.visible:
		dialogue_box.advance()
		return
	if get_tree().paused:
		return
	# Talking to a nearby villager takes priority over entering a building.
	var nearest_npc : RegularNPC = null
	var nearest_d   : float      = NPC_INTERACT_RANGE
	var npcs        : Array      = get_tree().get_nodes_in_group("interactable_npc")
	for npc in npcs:
		var d : float = global_position.distance_to(npc.global_position)
		if d <= nearest_d:
			nearest_d   = d
			nearest_npc = npc
	if nearest_npc != null:
		nearest_npc.begin_interaction(self)
		dialogue_box.open_blocks(nearest_npc.get_dialogue_blocks())
		return
	# Otherwise, enter the building whose door we're standing at — but only on
	# foot. On the bike, prompt the player to dismount first.
	if interior_manager != null:
		if on_bike:
			if interior_manager.has_door_near(global_position):
				GameManager.show_message("🚲 Hop off your bike to go inside!")
				return
		elif interior_manager.try_enter_nearest(global_position):
			return

func _hop() -> void:
	if on_bike or _hopping:
		return
	_hopping = true
	var tween := create_tween()
	tween.tween_property(foot_sprite, "position:y", -18.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(foot_sprite, "position:y",   0.0, 0.20).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _hopping = false)

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
	_easy_bike_angle   = bike_angle
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
	var spd := FOOT_SPEED * _speed_mult(false)
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
	if GameManager.easy_bike:
		_process_bike_easy(delta)
		return
	# Spin-out: controls dead, speed bleeds off fast, sprite whirls.
	var spinning := _spin_timer > 0.0
	if spinning:
		_spin_timer -= delta
		bike_speed *= 0.92

	var turn_input := 0.0
	if not spinning:
		if Input.is_action_pressed("move_left"):  turn_input = -1.0
		if Input.is_action_pressed("move_right"): turn_input =  1.0

	var accel   := not spinning and Input.is_action_pressed("move_up")
	var braking := not spinning and Input.is_action_pressed("move_down")
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
			
	if bike_speed > 2.0:
		var turn_factor: float = clamp(bike_speed / BIKE_MAX_SPEED, 0.3, 1.0)
		bike_angle += turn_input * BIKE_TURN_SPEED * turn_factor * delta

	# Auto-straighten: when riding without steering input, hold briefly then
	# ease the heading onto the nearest of the 8 directions. No tolerance gate:
	# the nearest octant is at most 22.5° away, so snapping always engages.
	if snap_to_direction and turn_input == 0.0 and abs(bike_speed) > 2.0:
		_straighten_timer += delta
		if _straighten_timer >= STRAIGHTEN_DELAY:
			var nearest_octant: float = round(bike_angle / (PI / 4.0)) * (PI / 4.0)
			bike_angle = lerp_angle(bike_angle, nearest_octant, STRAIGHTEN_SPEED * delta)
	else:
		_straighten_timer = 0.0

	velocity = Vector2(cos(bike_angle), sin(bike_angle)) * bike_speed

	# Visual angle turns at full BIKE_TURN_SPEED on input so the sprite reacts immediately,
	# independent of the physics turn_factor. Snaps back to bike_angle when not turning.
	if spinning:
		_visual_bike_angle += SPIN_VISUAL_SPEED * delta
	elif turn_input != 0.0 and bike_speed > 0.0:
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



# ── NPC collisions ─────────────────────────────────────────
## After move_and_slide(): on foot we gently shove the NPC along in our
## direction of travel (herding); on the bike at speed the NPC is knocked
## toward whichever side of the bike it's on and the player spins out.
func _handle_npc_collisions() -> void:
	for i in get_slide_collision_count():
		var collider : Object = get_slide_collision(i).get_collider()
		if collider is NPCBase:
			var npc        : NPCBase = collider
			var cur_speed  : float   = velocity.length() if GameManager.easy_bike else absf(bike_speed)
			var travel     : Vector2 = velocity.normalized() if GameManager.easy_bike else Vector2(cos(bike_angle), sin(bike_angle)) * signf(bike_speed)
			if on_bike and cur_speed > NPC_RUNOVER_SPEED:
				var side : float = signf(travel.cross(npc.global_position - global_position))
				if side == 0.0:
					side = 1.0
				npc.knock_back((travel.orthogonal() * side + travel * 0.3).normalized())
				_spin_out()
			elif not on_bike:
				npc.push(velocity)

func _spin_out() -> void:
	if _spin_timer > 0.0:
		return
	_spin_timer = SPIN_DURATION
	GameManager.add_hp(-1)      # spinouts cost health …
	GameManager.add_rizz(-1)    # … and a point of rizz
	GameManager.show_message("💫 Crash! You spun out!")

func _process_bike_easy(delta: float) -> void:
	var spinning := _spin_timer > 0.0
	if spinning:
		_spin_timer -= delta
		velocity   *= 0.85
		_visual_bike_angle += SPIN_VISUAL_SPEED * delta
		var dir_index := int(fposmod(rad_to_deg(_visual_bike_angle) + 22.5, 360.0) / 45.0)
		if dir_index != _bike_dir_index:
			_bike_dir_index = dir_index
			bike_sprite.texture = BIKE_TEXTURES[dir_index]
		bike_timer += delta
		if bike_timer >= 0.15:
			bike_timer = 0.0
			bike_frame = (bike_frame + 1) % 5
		bike_sprite.frame = bike_frame
		return

	var dir  := _get_dir()
	var mult := _speed_mult()

	if dir != Vector2.ZERO:
		# Turn the bike's facing toward the pressed direction at a fixed rate
		# instead of snapping instantly — a 180° reversal takes twice as long
		# to come about as a 90° turn.
		var target_angle : float = dir.angle()
		_easy_bike_angle = rotate_toward(_easy_bike_angle, target_angle, EASY_TURN_SPEED * delta)
		velocity = Vector2(cos(_easy_bike_angle), sin(_easy_bike_angle)) * BIKE_MAX_SPEED * mult

		var dir_index := int(fposmod(rad_to_deg(_easy_bike_angle) + 22.5, 360.0) / 45.0)
		if dir_index != _bike_dir_index:
			_bike_dir_index = dir_index
			bike_sprite.texture = BIKE_TEXTURES[dir_index]
		bike_timer += delta
		if bike_timer >= 0.15:
			bike_timer = 0.0
			bike_frame = (bike_frame + 1) % 5
	else:
		velocity   = Vector2.ZERO
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
	GameManager.add_rizz(1)     # grabbing a speed-up looks cool: +1 rizz
	GameManager.show_message("💨 Speed Boost!")

func apply_slow() -> void:
	slow_timer = SLOW_DURATION
	slow_aura.visible = true
	GameManager.add_rizz(-1)    # a slowdown is a bad look: -1 rizz
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

func _is_in_region(region: NavigationRegion2D) -> bool:
	if region == null:
		return false
	var nav_poly := region.navigation_polygon
	if nav_poly == null:
		return false
	var local_pos := region.to_local(global_position)
	for i in nav_poly.get_outline_count():
		if Geometry2D.is_point_in_polygon(local_pos, nav_poly.get_outline(i)):
			return true
	return false

func _is_in_any_region(regions: Array[NavigationRegion2D]) -> bool:
	for region in regions:
		if _is_in_region(region):
			return true
	return false

## Surface zones can overlap on the map (e.g. a grass patch under a road).
## Resolution is best-surface-wins, checked in this fixed priority order:
## Road (fastest) > Dirt Road (neutral) > Grass (slowest).
func _speed_mult(apply_surface: bool = true) -> float:
	var m := 1.0
	if boost_timer > 0.0:
		m = BOOST_MULT
	elif slow_timer > 0.0:
		m = SLOW_MULT
	elif apply_surface:
		if _is_in_any_region(road_regions):        m = 1.2
		elif _is_in_any_region(dirt_road_regions): m = 1.0
		elif _is_in_any_region(grass_regions):     m = 0.8
	# Out of energy: move at 70% speed.
	if GameManager.energy <= 0:
		m *= 0.7
	return m

# ── Helpers ────────────────────────────────────────────────
func _get_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    d.y -= 1
	if Input.is_action_pressed("move_down"):  d.y += 1
	if Input.is_action_pressed("move_left"):  d.x -= 1
	if Input.is_action_pressed("move_right"): d.x += 1
	return d.normalized()
