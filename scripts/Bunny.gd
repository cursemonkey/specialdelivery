extends Area2D
## Bunny — a wild animal, like the birds. It has no owner, no home and no
## territory: it wanders the whole map, and touching it adds it to the parade.
##
## Structurally this is Bird.gd (an Area2D that ignores buildings rather than a
## CharacterBody2D that walks around them), with the flight replaced by hopping:
##
##   * It moves in discrete hops with a still moment between each, instead of
##     gliding continuously.
##   * Where a bird perches on a rooftop, a bunny freezes in place — ears up,
##     not moving — which is the same idle beat played differently.
##   * It bolts a short way when it first spots the player, so it takes a
##     moment of chasing to catch one.
##
## Unlike the cats and dogs, a bunny keeps no schedule: it's out around the
## clock, exactly as the birds are.

## Peak speed within a hop. The hop is short, so the average pace over time is
## well under this. FLEE_SPEED is the bolt when startled, and the follow speeds
## are matched to the other species so one parade moves as a unit.
const HOP_SPEED           : float = 190.0
const FLEE_SPEED          : float = 250.0
## Catch-up speed while following. Matched to the fastest the player can ride so
## a follower is never permanently outrun (see GameManager.bike_max_speed).
const FOLLOW_SPRINT       : float = 270.0
const FOLLOW_NORMAL       : float = 85.0    # relaxed follow (~player walking pace)
const ESCAPE_DIST         : float = 72.0    # px — beyond this it boosts to full speed
const HOP_TIME            : float = 0.22    # how long one hop is airborne
const REST_MIN            : float = 0.35    # still moment between hops
const REST_MAX            : float = 1.30
const FREEZE_CHANCE       : float = 0.22    # odds of a long still beat instead
const FREEZE_MIN          : float = 1.8
const FREEZE_MAX          : float = 4.5
const REACH_THRESHOLD     : float = 10.0
const WORLD_MARGIN        : float = 24.0
const WORLD_RIGHT         : float = 6640 - WORLD_MARGIN
const WORLD_BOTTOM        : float = 5019 - WORLD_MARGIN
## How close the player gets before the bunny bolts, and how long it runs for.
const SPOOK_DIST          : float = 90.0
const FLEE_TIME           : float = 0.75
## A bunny only spooks once in a while — otherwise it could never be caught.
const SPOOK_CHANCE        : float = 0.5
const SPOOK_COOLDOWN      : float = 4.0

enum State { HOPPING, RESTING, FLEEING, FOLLOWING }

var _state        : State   = State.RESTING
var _hop_dir      : Vector2 = Vector2.RIGHT
var _timer        : float   = 0.0
var _speed        : float   = HOP_SPEED
var _player                 = null
var _follow_index : int     = 0
var _spook_timer  : float   = 0.0
## Place in the parade, assigned by Main: 0 is nearest the player. Followers
## hold station this many slots back along the trail so every species forms one
## shared line rather than stacking on the same point.
var parade_slot   : int     = 0

@onready var _sprite : Node2D = $BunnySprite

func _ready() -> void:
	add_to_group("bunny")
	body_entered.connect(_on_body_entered)
	_rest(randf_range(0.0, REST_MAX))

func _physics_process(delta: float) -> void:
	if _spook_timer > 0.0:
		_spook_timer -= delta
	match _state:
		State.HOPPING:   _hop(delta)
		State.RESTING:   _rest_tick(delta)
		State.FLEEING:   _flee(delta)
		State.FOLLOWING: _follow(delta)

# ── Hopping ────────────────────────────────────────────────
func _hop(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_rest(_next_rest())
		return
	_advance(_hop_dir, _speed, delta)
	# Bob through the arc of the hop so it reads as leaving the ground.
	_sprite.hop_height = sin((1.0 - _timer / HOP_TIME) * PI) * 3.0

func _rest(duration: float) -> void:
	_state = State.RESTING
	_timer = duration
	_sprite.hop_height = 0.0

## Most gaps between hops are short; occasionally the bunny freezes for a long
## beat instead, which is its version of the birds' perching.
func _next_rest() -> float:
	if randf() < FREEZE_CHANCE:
		return randf_range(FREEZE_MIN, FREEZE_MAX)
	return randf_range(REST_MIN, REST_MAX)

func _rest_tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_start_hop(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized(), HOP_SPEED)

func _start_hop(dir: Vector2, speed: float) -> void:
	_state   = State.HOPPING
	_hop_dir = dir if dir.length_squared() > 0.001 else Vector2.RIGHT
	_speed   = speed
	_timer   = HOP_TIME
	_sprite.set_facing(_hop_dir)

## Move and keep inside the world bounds, turning back rather than sticking to
## the edge when it runs out of map.
func _advance(dir: Vector2, speed: float, delta: float) -> void:
	global_position += dir * speed * delta
	var clamped : Vector2 = Vector2(
		clampf(global_position.x, WORLD_MARGIN, WORLD_RIGHT),
		clampf(global_position.y, WORLD_MARGIN, WORLD_BOTTOM)
	)
	if not clamped.is_equal_approx(global_position):
		global_position = clamped
		_hop_dir = -_hop_dir
		_sprite.set_facing(_hop_dir)

# ── Fleeing ────────────────────────────────────────────────
## A short bolt directly away from whatever startled it, then straight back to
## the normal hop cycle.
func _flee(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_rest(REST_MIN)
		return
	_advance(_hop_dir, FLEE_SPEED, delta)
	_sprite.hop_height = absf(sin(_timer * 26.0)) * 2.5

## Bolt away from `from`, if this bunny isn't still calming down from the last
## time. Called by Main when the player gets close.
func spook(from: Vector2) -> void:
	if _state == State.FOLLOWING or _state == State.FLEEING:
		return
	if _spook_timer > 0.0:
		return
	if randf() > SPOOK_CHANCE:
		# Didn't startle this time — but don't re-roll every frame.
		_spook_timer = SPOOK_COOLDOWN
		return
	var away : Vector2 = (global_position - from).normalized()
	if away.length_squared() < 0.001:
		away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	_state       = State.FLEEING
	_hop_dir     = away
	_timer       = FLEE_TIME
	_spook_timer = SPOOK_COOLDOWN
	_sprite.set_facing(away)

## True while the bunny is close enough to the player to consider bolting.
func should_spook_at(player_pos: Vector2) -> bool:
	if _state == State.FOLLOWING or _state == State.FLEEING:
		return false
	return global_position.distance_to(player_pos) < SPOOK_DIST

# ── Following ──────────────────────────────────────────────
## Trail points between one animal and the next in the line. Matches Bird, Dog
## and Cat so every species queues at the same spacing.
const SLOT_SPACING : int = 2

func _follow(delta: float) -> void:
	if _player == null:
		return
	var trail : Array = _player.path_trail
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

	var target_idx : int     = clampi(_follow_index, 0, trail.size() - 1)
	var target     : Vector2 = trail[target_idx]
	var to_target  : Vector2 = target - global_position

	if to_target.length() > 2.0:
		var dist_to_player : float   = global_position.distance_to(_player.global_position)
		var speed          : float   = FOLLOW_SPRINT if dist_to_player > ESCAPE_DIST else FOLLOW_NORMAL
		var dir            : Vector2 = to_target.normalized()
		global_position += dir * speed * delta
		_sprite.set_facing(dir)
		# Keep bobbing while it follows, so it hops along rather than sliding.
		_sprite.hop_height = absf(sin(Time.get_ticks_msec() * 0.02)) * 2.2

# ── Contact ────────────────────────────────────────────────
func is_following() -> bool:
	return _state == State.FOLLOWING

## Stop following the player (they went indoors) and go back to hopping about.
func stop_following() -> void:
	if _state != State.FOLLOWING:
		return
	_player = null
	_sprite.hop_height = 0.0
	_rest(REST_MIN)

func _on_body_entered(body: Node) -> void:
	if _state == State.FOLLOWING:
		return
	if body is NPCBase:
		return
	# Only the player leads a parade. Cats and dogs are CharacterBody2D too, so
	# identify the player by the breadcrumb trail only they keep — by class
	# alone a bunny would latch onto a passing dog and then crash reading its
	# path_trail.
	if body is CharacterBody2D and body.get("path_trail") != null:
		_state        = State.FOLLOWING
		_player       = body
		_follow_index = maxi(0, _player.path_trail.size() - 4)
		GameManager.show_message("\U0001F430 A bunny is following you!")
