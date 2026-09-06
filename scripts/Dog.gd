extends CharacterBody2D
## Dog NPC — lives with a human villager and pads around a territory outside
## during its own hours. Touch one and it joins the parade behind the player,
## exactly like a bird, adding to the Rizz bonus.
##
## Unlike the birds (which fly over everything) a dog is a CharacterBody2D and
## uses move_and_slide, so it walks around buildings instead of through them.
## Player contact is detected by a child Area2D rather than the body itself,
## so a dog that happens to bump the player while roaming still gets picked up.
##
## A dog is either OUT (roaming its territory, catchable) or INSIDE (off-shift,
## hidden and inert at its home door). The switch is driven by `out_start` /
## `out_end` on the 24h clock, so each dog keeps its own hours and several can
## overlap. Being picked up by the player suspends the schedule until the player
## goes indoors or the dog is released — a dog mid-parade doesn't vanish at 6pm.

const WALK_SPEED       : float = 54.0    # relaxed padding around the territory
const FOLLOW_SPEED     : float = 92.0    # relaxed follow, roughly walking pace
## Top speed while catching up. Matched to the fastest the player can ride so a
## dog is never permanently outrun — see GameManager.bike_max_speed (the scooter
## raises it) and Player.BOOST_MULT for the ramp boost.
const FOLLOW_SPRINT    : float = 270.0
const ESCAPE_DIST      : float = 60.0    # px behind its slot before it speeds up
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

## Index in the parade, assigned by DogManager: 0 is nearest the player. Drives
## how far back along the trail this dog walks, so followers form a line.
var parade_slot : int = 0

@onready var _touch : Area2D = $TouchArea

func _ready() -> void:
	add_to_group("dog")
	_touch.body_entered.connect(_on_body_entered)
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
	visible = true
	_set_active(true)
	_pick_target()

func _go_inside() -> void:
	_state  = State.INSIDE
	_player = null
	# Parked at the home door, hidden and uncatchable until its hours come round.
	global_position = territory_centre
	visible = false
	_set_active(false)

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
	velocity = dir * WALK_SPEED
	move_and_slide()
	# Wedged against a building: pick somewhere else rather than pushing at it.
	if velocity.length() > 1.0 and get_real_velocity().length() < WALK_SPEED * 0.25:
		_state = State.PAUSED
		_timer = randf_range(PAUSE_MIN, PAUSE_MAX)
	_animate(dir, delta)

func _pause_tick(delta: float) -> void:
	velocity = Vector2.ZERO
	_timer -= delta
	if _timer <= 0.0:
		_state = State.ROAMING
		_pick_target()

# ── Following ──────────────────────────────────────────────
## Walk the player's breadcrumb trail, holding station a fixed distance behind
## them based on parade_slot, so followers string out into a line rather than
## clumping. Player.TRAIL_STEP px separate consecutive trail points, so a slot
## is simply that many points further back.
##
## The line is a target, not a constraint: a dog that has fallen behind its slot
## sprints (up to FOLLOW_SPRINT, matched to the bike) to close the gap, so a
## fast player stretches the line out and it re-forms once they slow down.
## Trail points between one animal and the next in the line.
const SLOT_SPACING : int = 2
## Mirrors Player.TRAIL_STEP (px between recorded trail points). Player has no
## class_name, so the value is repeated here rather than reached through it.
const TRAIL_STEP   : float = 12.0

func _follow(delta: float) -> void:
	if _player == null:
		stop_following()
		return
	var trail : Array = _player.path_trail
	if trail.is_empty():
		return
	# The slot this dog wants to occupy: further back for later joiners.
	var back   : int = (parade_slot + 1) * SLOT_SPACING
	var wanted : int = maxi(trail.size() - 1 - back, 0)
	# Advance towards the wanted index rather than snapping, so the dog walks
	# the path the player walked instead of cutting corners.
	if _follow_index < wanted:
		var target_pt : Vector2 = trail[clampi(_follow_index, 0, trail.size() - 1)]
		if global_position.distance_to(target_pt) < REACH_THRESHOLD:
			_follow_index += 1
	elif _follow_index > wanted:
		_follow_index = wanted   # trail was trimmed or the player doubled back

	var idx       : int     = clampi(_follow_index, 0, trail.size() - 1)
	var target    : Vector2 = trail[idx]
	var to_target : Vector2 = target - global_position
	if to_target.length() <= 2.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# How far behind its slot is it? Stretched line = sprint to close up.
	var lag   : float = float(wanted - _follow_index) * TRAIL_STEP
	var gap   : float = to_target.length() + maxf(lag, 0.0)
	var speed : float = FOLLOW_SPEED
	if gap > ESCAPE_DIST:
		# Scale up towards the sprint cap the further behind it is, so the line
		# closes smoothly instead of snapping.
		var t : float = clampf((gap - ESCAPE_DIST) / 160.0, 0.0, 1.0)
		speed = lerpf(FOLLOW_SPEED, FOLLOW_SPRINT, t)
	var dir : Vector2 = to_target.normalized()
	velocity = dir * speed
	move_and_slide()
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
	# Only the player leads a parade. Dogs are CharacterBody2D too now, so
	# identify the player by the breadcrumb trail only they keep, rather than
	# by class — otherwise dogs latch onto each other.
	if body is CharacterBody2D and body.get("path_trail") != null:
		_state        = State.FOLLOWING
		_player       = body
		_follow_index = maxi(0, _player.path_trail.size() - 4)
		GameManager.show_message("\U0001F415 %s is following you!" % dog_name)

## Enable or disable the dog as a physical, touchable presence. Indoors it is
## neither: it can't be bumped into and doesn't block anyone in the street.
func _set_active(on: bool) -> void:
	_touch.monitoring = on
	set_collision_layer_value(1, on)
	set_collision_mask_value(1, on)
	velocity = Vector2.ZERO

func _animate(dir: Vector2, delta: float) -> void:
	_walk_phase += delta * 9.0
	_sprite.walk_phase = _walk_phase
	_sprite.set_facing(dir)
