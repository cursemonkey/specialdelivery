extends Area2D
## Bird NPC — wanders freely (ignores buildings), perches on rooftops,
## and follows the player's path when touched.

const BIRD_SPEED          := 160.0   # wander / catch-up speed
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
func _follow(delta: float) -> void:
	if _player == null:
		return
	var trail: Array = _player.path_trail
	if trail.is_empty():
		return

	var target_idx : int     = clamp(_follow_index, 0, trail.size() - 1)
	var target     : Vector2 = trail[target_idx]
	var to_target  : Vector2 = target - global_position

	if to_target.length() < REACH_THRESHOLD and _follow_index < trail.size() - 1:
		_follow_index += 1

	if to_target.length() > 2.0:
		var dist_to_player := global_position.distance_to(_player.global_position)
		var speed := BIRD_SPEED if dist_to_player > BIRD_ESCAPE_DIST else BIRD_FOLLOW_NORMAL
		var dir := to_target.normalized()
		global_position  += dir * speed * delta
		_sprite.rotation  = dir.angle()

# ── Contact ────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if _state == State.FOLLOWING:
		return
	if body is NPCBase:
		return
	if body is CharacterBody2D:
		_state        = State.FOLLOWING
		_player       = body
		_follow_index = max(0, _player.path_trail.size() - 4)
		GameManager.show_message("🐦 A bird is following you!")
