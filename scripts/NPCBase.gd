class_name NPCBase
extends CharacterBody2D
## Base villager. Walks in a straight line toward a schedule target (sliding
## around obstacles), idles on arrival, and reacts to the player:
##  - bumped on foot  → comes to a complete halt for a moment (bump_halt)
##  - hit by the bike → knocked aside, then dazed briefly (knock_back)
## Subclasses override _retarget() to decide where to go; it is called on
## every phase change and at the start of each day via TimeManager signals.

const WALK_SPEED          := 42.0
const ARRIVE_THRESHOLD    := 10.0
const BUMP_HALT_DURATION  := 2.0    # halt after a on-foot bump
const KNOCK_HALT_DURATION := 2.5    # dazed time after a bike hit
const KNOCKBACK_SPEED     := 240.0
const KNOCKBACK_FRICTION  := 480.0  # px/sec² decay of knockback velocity
const WALK_FRAME_TIME     := 0.18
const STUCK_TIME          := 1.2    # secs of no progress before detouring
const DETOUR_TIME         := 0.7

var facing        : Vector2 = Vector2.DOWN

var _move_target  : Vector2 = Vector2.ZERO
var _has_target   : bool    = false
var _halt_timer   : float   = 0.0
var _knock_vel    : Vector2 = Vector2.ZERO
var _walk_frame   : int     = 0
var _walk_timer   : float   = 0.0
var _stuck_timer  : float   = 0.0
var _detour_timer : float   = 0.0
var _detour_dir   : Vector2 = Vector2.ZERO
var _last_pos     : Vector2 = Vector2.ZERO

@onready var _sprite : NPCSprite = $NPCSprite

func _ready() -> void:
	add_to_group("npc")
	_last_pos    = global_position
	_move_target = global_position
	TimeManager.phase_changed.connect(func(_phase: int) -> void: _retarget())
	TimeManager.day_started.connect(func(_weekday: int) -> void: _retarget())
	_retarget()

func _physics_process(delta: float) -> void:
	# Knockback overrides everything until it decays.
	if _knock_vel.length_squared() > 4.0:
		velocity   = _knock_vel
		_knock_vel = _knock_vel.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		move_and_slide()
		_last_pos = global_position
		return

	if _halt_timer > 0.0:
		_halt_timer -= delta
		velocity = Vector2.ZERO
		_animate(false, delta)
		return

	var to_target : Vector2 = _move_target - global_position
	if not _has_target or to_target.length() <= ARRIVE_THRESHOLD:
		velocity = Vector2.ZERO
		_animate(false, delta)
		return

	var dir : Vector2 = to_target.normalized()
	if _detour_timer > 0.0:
		_detour_timer -= delta
		dir = _detour_dir
	velocity = dir * WALK_SPEED
	move_and_slide()
	_update_stuck(delta)
	_animate(true, delta)

# ── Public API ─────────────────────────────────────────────
func set_move_target(pos: Vector2) -> void:
	_move_target = pos
	_has_target  = true

## Player walked into us: freeze in place for a moment.
func bump_halt() -> void:
	_halt_timer = maxf(_halt_timer, BUMP_HALT_DURATION)

## Player rode into us: get shoved in `dir`, then stand dazed.
func knock_back(dir: Vector2) -> void:
	_knock_vel  = dir.normalized() * KNOCKBACK_SPEED
	_halt_timer = KNOCK_HALT_DURATION

func face_toward(pos: Vector2) -> void:
	facing = _dominant_axis(pos - global_position)
	_walk_frame = 0
	_sprite.set_facing(facing, 0)

# ── Overridables ───────────────────────────────────────────
## Decide where to walk for the current TimeManager weekday/phase.
func _retarget() -> void:
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
