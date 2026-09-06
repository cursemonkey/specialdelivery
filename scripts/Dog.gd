extends Area2D
## Dog NPC — lives with a human villager and pads around a small territory
## outside during its own hours. Touch one and it joins the parade behind the
## player, exactly like a bird, adding to the Rizz bonus.
##
## A dog is either OUT (roaming its territory, catchable) or INSIDE (off-shift,
## hidden and inert at its home door). The switch is driven by `out_start` /
## `out_end` on the 24h clock, so each dog keeps its own hours and several can
## overlap. Being picked up by the player suspends the schedule until the player
## goes indoors or the dog is released — a dog mid-parade doesn't vanish at 6pm.

const WALK_SPEED       : float = 54.0    # relaxed padding around the territory
const FOLLOW_SPEED     : float = 92.0    # keeping up with the player
const FOLLOW_SPRINT    : float = 168.0   # catching up when left behind
const ESCAPE_DIST      : float = 80.0    # px before it breaks into a sprint
const REACH_THRESHOLD  : float = 8.0
const PAUSE_MIN        : float = 0.8     # sniffing stops between walks
const PAUSE_MAX        : float = 3.0
const WALK_MIN         : float = 0.7
const WALK_MAX         : float = 2.4

enum State { ROAMING, PAUSED, FOLLOWING, INSIDE }

# Identity, set by DogManager at spawn.
var id            : String  = ""
var dog_name      : String  = "Dog"
var owner_id      : String  = ""    # human villager this dog lives with
var home_anchor   : String  = ""    # door name it goes into when off-shift

# Territory: it stays within `territory_radius` of `territory_centre`.
var territory_centre : Vector2 = Vector2.ZERO
var territory_radius : float   = 150.0

# Hours it's outside, on the 24h clock. Wraps past midnight when end < start,
# which is how the night dogs are expressed (e.g. 19.0 -> 5.0).
var out_start : float = 8.0
var out_end   : float = 18.0

var _state       : State   = State.INSIDE
var _target      : Vector2 = Vector2.ZERO
var _timer       : float   = 0.0
var _player                = null
var _follow_index : int    = 0
var _walk_phase  : float   = 0.0

@onready var _sprite : Node2D = $DogSprite

func _ready() -> void:
	add_to_group("dog")
	body_entered.connect(_on_body_entered)
	_apply_schedule(true)

func _physics_process(delta: float) -> void:
	# Following overrides the clock: a dog in the parade stays out until the
	# player goes inside, however late it gets.
	if _state != State.FOLLOWING:
		_apply_schedule(false)
	match _state:
		State.ROAMING:   _roam(delta)
		State.PAUSED:    _pause_tick(delta)
		State.FOLLOWING: _follow(delta)
		State.INSIDE:    pass

# ── Schedule ───────────────────────────────────────────────
## True when `hour` falls inside this dog's outdoor window, handling windows
## that wrap past midnight.
func is_out_at(hour: float) -> bool:
	if is_equal_approx(out_start, out_end):
		return true                      # out around the clock
	if out_start < out_end:
		return hour >= out_start and hour < out_end
	return hour >= out_start or hour < out_end   # wraps midnight

## Move between OUT and INSIDE as the clock crosses this dog's window.
func _apply_schedule(force: bool) -> void:
	var should_be_out : bool = is_out_at(TimeManager.hour)
	var currently_out : bool = _state != State.INSIDE
	if should_be_out == currently_out and not force:
		return
	if should_be_out:
		_go_outside()
	else:
		_go_inside()

func _go_outside() -> void:
	_state = State.ROAMING
	# Reappear somewhere in the territory rather than exactly on the door.
	global_position = _random_point_in_territory()
	visible    = true
	monitoring = true
	_pick_target()

func _go_inside() -> void:
	_state  = State.INSIDE
	_player = null
	# Parked at the home door, hidden and uncatchable until its hours come round.
	global_position = territory_centre
	visible    = false
	monitoring = false

## True while the dog is indoors for the night (or day).
func is_inside() -> bool:
	return _state == State.INSIDE

## Which building this dog is currently in, or "" when it's out.
func inside_building() -> String:
	return home_anchor if _state == State.INSIDE else ""

# ── Roaming ────────────────────────────────────────────────
func _random_point_in_territory() -> Vector2:
	var a : float = randf() * TAU
	var r : float = sqrt(randf()) * territory_radius   # uniform over the disc
	return territory_centre + Vector2(cos(a), sin(a)) * r

func _pick_target() -> void:
	_target = _random_point_in_territory()
	_timer  = randf_range(WALK_MIN, WALK_MAX)

func _roam(delta: float) -> void:
	_timer -= delta
	var to_target : Vector2 = _target - global_position
	if to_target.length() < REACH_THRESHOLD or _timer <= 0.0:
		_state = State.PAUSED
		_timer = randf_range(PAUSE_MIN, PAUSE_MAX)
		return
	var dir : Vector2 = to_target.normalized()
	global_position += dir * WALK_SPEED * delta
	_animate(dir, delta)

func _pause_tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_state = State.ROAMING
		_pick_target()

# ── Following ──────────────────────────────────────────────
## Walk the player's breadcrumb trail, same as the birds, so the parade forms a
## line rather than a clump on top of the player.
func _follow(delta: float) -> void:
	if _player == null:
		stop_following()
		return
	var trail : Array = _player.path_trail
	if trail.is_empty():
		return
	var idx       : int     = clampi(_follow_index, 0, trail.size() - 1)
	var target    : Vector2 = trail[idx]
	var to_target : Vector2 = target - global_position
	if to_target.length() < REACH_THRESHOLD and _follow_index < trail.size() - 1:
		_follow_index += 1
	if to_target.length() > 2.0:
		var far   : bool  = global_position.distance_to(_player.global_position) > ESCAPE_DIST
		var speed : float = FOLLOW_SPRINT if far else FOLLOW_SPEED
		var dir   : Vector2 = to_target.normalized()
		global_position += dir * speed * delta
		_animate(dir, delta)

func is_following() -> bool:
	return _state == State.FOLLOWING

## Stop following (the player went indoors) and get back to the territory.
func stop_following() -> void:
	if _state != State.FOLLOWING:
		return
	_player = null
	# Off-shift by now? Go straight in; otherwise resume roaming.
	if is_out_at(TimeManager.hour):
		_state = State.ROAMING
		_pick_target()
	else:
		_go_inside()

func _on_body_entered(body: Node) -> void:
	if _state == State.FOLLOWING or _state == State.INSIDE:
		return
	if body is NPCBase:
		return   # dogs ignore villagers walking past
	if body is CharacterBody2D:
		_state        = State.FOLLOWING
		_player       = body
		_follow_index = maxi(0, _player.path_trail.size() - 4)
		GameManager.show_message("\U0001F415 %s is following you!" % dog_name)

func _animate(dir: Vector2, delta: float) -> void:
	_walk_phase += delta * 9.0
	_sprite.walk_phase = _walk_phase
	_sprite.set_facing(dir)
