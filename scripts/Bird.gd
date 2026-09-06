extends Area2D
## Bird NPC — wanders freely (ignores buildings), perches on rooftops,
## and follows the player's path when touched.

## Wander / catch-up speed. Matched to the fastest the player can ride so a
## follower is never permanently outrun (see GameManager.bike_max_speed).
const BIRD_SPEED          := 270.0
const BIRD_FOLLOW_NORMAL  := 85.0    # relaxed follow speed (~player walking pace)
const BIRD_ESCAPE_DIST    := 72.0    # px — beyond this the bird boosts to full speed
const WANDER_MIN          := 0.6
const WANDER_MAX          := 2.2
const REACH_THRESHOLD     := 10.0
const PERCH_CHANCE        := 0.30
const WORLD_MARGIN        := 24.0
const WORLD_RIGHT         := 6640 - WORLD_MARGIN
const WORLD_BOTTOM        := 5019 - WORLD_MARGIN

enum State { WANDERING, FLYING_TO_PERCH, PERCHED, FOLLOWING }

var _state        : State  = State.WANDERING
var _wander_dir   : Vector2 = Vector2.RIGHT
var _wander_timer : float   = 0.0
var _perch_target : Vector2 = Vector2.ZERO
var _perch_timer  : float   = 0.0
var _player                 = null
var _follow_index : int     = 0
## Place in the parade, assigned by Main: 0 is nearest the player. Followers
## hold station this many slots back along the trail so birds and dogs form one
## shared line rather than stacking on the same point.
var parade_slot   : int     = 0

var perch_positions : Array[Vector2] = []

@onready var _sprite : Node2D = $BirdSprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_pick_wander_direction()

func _physics_process(delta: float) -> void:
	match _state:
		State.WANDERING:       _wander(delta)
		State.FLYING_TO_PERCH: _fly_to_perch(delta)
		State.PERCHED:         _perch_tick(delta)
		State.FOLLOWING:       _follow(delta)

# ── Wandering ──────────────────────────────────────────────
func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_direction()
		return

	global_position += _wander_dir * BIRD_SPEED * delta
	global_position.x = clamp(global_position.x, WORLD_MARGIN, WORLD_RIGHT)
	global_position.y = clamp(global_position.y, WORLD_MARGIN, WORLD_BOTTOM)
	_sprite.rotation = _wander_dir.angle()

func _pick_wander_direction() -> void:
	if not perch_positions.is_empty() and randf() < PERCH_CHANCE:
		_perch_target = perch_positions[randi() % perch_positions.size()]
		_state = State.FLYING_TO_PERCH
		return
	_wander_timer = randf_range(WANDER_MIN, WANDER_MAX)
	_wander_dir   = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

# ── Flying to perch ────────────────────────────────────────
func _fly_to_perch(delta: float) -> void:
	var to_target := _perch_target - global_position
	if to_target.length() < REACH_THRESHOLD:
		global_position  = _perch_target
		_perch_timer     = randf_range(5.0, 10.0)
		_state           = State.PERCHED
		_sprite.rotation = 0.0
		return
	var dir := to_target.normalized()
	global_position  += dir * BIRD_SPEED * delta
	_sprite.rotation  = dir.angle()

# ── Perched ────────────────────────────────────────────────
func _perch_tick(delta: float) -> void:
	_perch_timer -= delta
	if _perch_timer <= 0.0:
		_state = State.WANDERING
		_pick_wander_direction()

# ── Following ──────────────────────────────────────────────
## Trail points between one animal and the next in the line. Matches Dog's
## SLOT_SPACING so the two species queue at the same spacing.
const SLOT_SPACING : int = 2

func _follow(delta: float) -> void:
	if _player == null:
		return
	var trail: Array = _player.path_trail
	if trail.is_empty():
		return

	# Hold station parade_slot places back down the trail, so followers line up.
	var back   : int     = (parade_slot + 1) * SLOT_SPACING
	var wanted : int     = maxi(trail.size() - 1 - back, 0)
	var here   : Vector2 = trail[clampi(_follow_index, 0, trail.size() - 1)]
	if _follow_index < wanted:
		if global_position.distance_to(here) < REACH_THRESHOLD:
			_follow_index += 1
	elif _follow_index > wanted:
		_follow_index = wanted

	var target_idx : int     = clamp(_follow_index, 0, trail.size() - 1)
	var target     : Vector2 = trail[target_idx]
	var to_target  : Vector2 = target - global_position

	if to_target.length() > 2.0:
		var dist_to_player := global_position.distance_to(_player.global_position)
		var speed := BIRD_SPEED if dist_to_player > BIRD_ESCAPE_DIST else BIRD_FOLLOW_NORMAL
		var dir := to_target.normalized()
		global_position  += dir * speed * delta
		_sprite.rotation  = dir.angle()

# ── Contact ────────────────────────────────────────────────
func is_following() -> bool:
	return _state == State.FOLLOWING

## Stop following the player (they went indoors) and go back to wandering.
func stop_following() -> void:
	if _state != State.FOLLOWING:
		return
	_player = null
	_state  = State.WANDERING
	_pick_wander_direction()

func _on_body_entered(body: Node) -> void:
	if _state == State.FOLLOWING:
		return
	if body is NPCBase:
		return
	# Only the player leads a parade. Dogs are CharacterBody2D too, so identify
	# the player by the breadcrumb trail only they keep — by class alone a bird
	# would latch onto a passing dog and then crash reading its path_trail.
	if body is CharacterBody2D and body.get("path_trail") != null:
		_state        = State.FOLLOWING
		_player       = body
		_follow_index = max(0, _player.path_trail.size() - 4)
		GameManager.show_message("🐦 A bird is following you!")
