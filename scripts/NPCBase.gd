class_name NPCBase
extends CharacterBody2D
## Base villager. Walks in a straight line toward a schedule target (sliding
## around obstacles), idles on arrival, and reacts to the player:
##  - walked into on foot → gently shoved along, so the player can herd it (push)
##  - hit by the bike     → knocked aside, then dazed briefly (knock_back)
## Subclasses override _retarget() to decide where to go; it is called on
## every phase change and at the start of each day via TimeManager signals.

const WALK_SPEED          := 42.0
const ARRIVE_THRESHOLD    := 10.0
const PUSH_SPEED          := 34.0   # shove speed when the player walks into us (< WALK_SPEED)
const PUSH_FRICTION       := 220.0  # px/sec² decay of the shove
const KNOCK_HALT_DURATION := 2.5    # dazed time after a bike hit
const KNOCKBACK_SPEED     := 240.0
const KNOCKBACK_FRICTION  := 480.0  # px/sec² decay of knockback velocity
const WALK_FRAME_TIME     := 0.18
const STUCK_TIME          := 1.2    # secs of no progress before detouring
const DETOUR_TIME         := 0.7

var id            : String  = ""   # stable identifier; see NPCRegistry
var facing        : Vector2 = Vector2.DOWN

var _move_target  : Vector2 = Vector2.ZERO
var _has_target   : bool    = false
var _halt_timer   : float   = 0.0
var _knock_vel    : Vector2 = Vector2.ZERO
var _push_vel     : Vector2 = Vector2.ZERO
var _walk_frame   : int     = 0
var _walk_timer   : float   = 0.0
var _stuck_timer  : float   = 0.0
var _detour_timer : float   = 0.0
var _detour_dir   : Vector2 = Vector2.ZERO
var _last_pos     : Vector2 = Vector2.ZERO
var _arrived      : bool    = true   # true once the current move target is reached

@onready var _sprite : NPCSprite = $NPCSprite

func _ready() -> void:
	add_to_group("npc")
	_last_pos    = global_position
	_move_target = global_position
	# Phase changes let NPCs walk to the new spot; a new day (and spawn) places
	# them immediately at their morning location.
	TimeManager.phase_changed.connect(func(_phase: int) -> void: _retarget(false))
	TimeManager.day_started.connect(func(_weekday: int) -> void: _retarget(true))
	_retarget(true)

func _physics_process(delta: float) -> void:
	# Knockback overrides everything until it decays.
	if _knock_vel.length_squared() > 4.0:
		velocity   = _knock_vel
		_knock_vel = _knock_vel.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		move_and_slide()
		_last_pos = global_position
		return

	# A gentle shove from the player on foot; decays over a fraction of a second.
	_push_vel = _push_vel.move_toward(Vector2.ZERO, PUSH_FRICTION * delta)
	var pushed : bool = _push_vel.length_squared() > 1.0

	if _halt_timer > 0.0:
		_halt_timer -= delta
		velocity = _push_vel
		if pushed:
			move_and_slide()
		_animate(false, delta)
		return

	var to_target : Vector2 = _move_target - global_position
	if not _has_target or to_target.length() <= ARRIVE_THRESHOLD:
		# Idle, but still shovable so the player can nudge a stopped NPC.
		velocity = _push_vel
		if pushed:
			move_and_slide()
		_animate(false, delta)
		if not _arrived:
			_arrived = true
			_on_arrived()
		return

	var dir : Vector2 = to_target.normalized()
	if _detour_timer > 0.0:
		_detour_timer -= delta
		dir = _detour_dir
	velocity = dir * WALK_SPEED + _push_vel
	move_and_slide()
	_update_stuck(delta)
	_animate(true, delta)

# ── Public API ─────────────────────────────────────────────
func set_move_target(pos: Vector2) -> void:
	if pos.distance_to(_move_target) > 1.0:
		_arrived = false
	_move_target = pos
	_has_target  = true

## Overridable: called once when the NPC reaches its move target.
func _on_arrived() -> void:
	pass

## Player walked into us on foot: a gentle shove in `dir` (slower than walking
## pace) so they can slowly herd the NPC forward. Re-applied each frame of
## contact, so continuous walking = continuous pushing.
func push(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_push_vel = dir.normalized() * PUSH_SPEED

## Player rode into us: get shoved in `dir`, then stand dazed.
func knock_back(dir: Vector2) -> void:
	_knock_vel  = dir.normalized() * KNOCKBACK_SPEED
	_halt_timer = KNOCK_HALT_DURATION

func face_toward(pos: Vector2) -> void:
	facing = _dominant_axis(pos - global_position)
	_walk_frame = 0
	_sprite.set_facing(facing, 0)

# ── Overridables ───────────────────────────────────────────
## Decide where to walk for the current TimeManager weekday/phase. `immediate`
## means place at the destination now (spawn / new day) rather than walk there.
func _retarget(_immediate: bool = false) -> void:
	pass

# ── Internals ──────────────────────────────────────────────
func _update_stuck(delta: float) -> void:
	var moved : float = global_position.distance_to(_last_pos)
	_last_pos = global_position
	if moved < WALK_SPEED * delta * 0.3:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME:
			_stuck_timer  = 0.0
			_detour_timer = DETOUR_TIME
			var side : float = 1.0 if randf() < 0.5 else -1.0
			_detour_dir = (_move_target - global_position).normalized().orthogonal() * side
	else:
		_stuck_timer = 0.0

func _animate(walking: bool, delta: float) -> void:
	if walking:
		facing = _dominant_axis(velocity)
		_walk_timer += delta
		if _walk_timer >= WALK_FRAME_TIME:
			_walk_timer = 0.0
			_walk_frame = (_walk_frame + 1) % 4
	else:
		_walk_timer = 0.0
		_walk_frame = 0
	_sprite.set_facing(facing, _walk_frame)

func _dominant_axis(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return facing
	if absf(v.x) >= absf(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP
