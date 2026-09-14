extends CharacterBody2D
## Cat NPC — lives with a human villager and ranges over a large territory
## outside during its own hours. Touch one and it joins the parade behind the
## player, exactly like a dog or a bird, adding to the Rizz bonus.
##
## Structurally this is Dog.gd: a CharacterBody2D that walks around buildings
## instead of through them, with contact detected by a child Area2D so a cat
## that bumps the player while roaming still gets picked up, and an OUT/INSIDE
## split driven by `out_start` / `out_end` on the 24h clock.
##
## Where a cat differs from a dog:
##   * Its territory is far larger (see CatManager.TERRITORY_BONUS), so it's met
##     right across a quarter of town rather than on one street.
##   * It sits for much longer between walks, and covers ground in quick dashes
##     rather than a steady pad — so it reads as a cat at a glance.
##   * It only follows on its own terms: see JOIN_CHANCE.

const WALK_SPEED       : float = 46.0    # unhurried prowl between sitting spots
const DASH_SPEED       : float = 128.0   # short bursts across open ground
const DASH_CHANCE      : float = 0.35    # odds a given leg is taken at a dash
const FOLLOW_SPEED     : float = 92.0    # relaxed follow, matches the dogs
## Top speed while catching up. Matched to the fastest the player can ride so a
## cat is never permanently outrun — see GameManager.bike_max_speed (the scooter
## raises it) and Player.BOOST_MULT for the ramp boost.
const FOLLOW_SPRINT    : float = 270.0
const ESCAPE_DIST      : float = 60.0    # px behind its slot before it speeds up
const REACH_THRESHOLD  : float = 8.0
const PAUSE_MIN        : float = 2.0     # cats sit far longer than dogs do
const PAUSE_MAX        : float = 6.5
const WALK_MIN         : float = 0.9
const WALK_MAX         : float = 3.2
## Odds that a given touch actually recruits the cat. A cat that declines
## saunters off and can be tried again — it isn't consumed by the refusal.
const JOIN_CHANCE      : float = 0.65
## How long after a refusal before this cat can be recruited again, so one
## brush past doesn't roll the dice a dozen times in as many frames.
const SNUB_COOLDOWN    : float = 3.0

enum State { ROAMING, PAUSED, FOLLOWING, INSIDE }

# Identity, set by CatManager at spawn.
var id            : String  = ""
var cat_name      : String  = "Cat"
var owner_id      : String  = ""    # human villager this cat lives with
var home_anchor   : String  = ""    # door name it goes into when off-shift

# Territory: it stays within `territory_radius` of `territory_centre`.
var territory_centre : Vector2 = Vector2.ZERO
var territory_radius : float   = 320.0

# Hours it's outside, on the 24h clock. Wraps past midnight when end < start,
# which is how the eight night cats are expressed (e.g. 19.0 -> 5.0).
var out_start : float = 8.0
var out_end   : float = 18.0

var _state       : State   = State.INSIDE
var _target      : Vector2 = Vector2.ZERO
var _timer       : float   = 0.0
var _speed       : float   = WALK_SPEED   # this leg's pace: prowl or dash
var _player                = null
var _follow_index : int    = 0
var _walk_phase  : float   = 0.0
var _snub_timer  : float   = 0.0

@onready var _sprite : Node2D = $CatSprite

## Index in the parade, assigned by CatManager: 0 is nearest the player. Drives
## how far back along the trail this cat walks, so followers form a line.
var parade_slot : int = 0

@onready var _touch : Area2D = $TouchArea

func _ready() -> void:
	add_to_group("cat")
	_touch.body_entered.connect(_on_body_entered)
	_apply_schedule(true)

func _physics_process(delta: float) -> void:
	if _snub_timer > 0.0:
		_snub_timer -= delta
	# Following overrides the clock: a cat in the parade stays out until the
	# player goes inside, however late it gets.
	if _state != State.FOLLOWING:
		_apply_schedule(false)
	match _state:
		State.ROAMING:   _roam(delta)
		State.PAUSED:    _pause_tick(delta)
		State.FOLLOWING: _follow(delta)
		State.INSIDE:    pass

# ── Schedule ───────────────────────────────────────────────
## True when `hour` falls inside this cat's outdoor window, handling windows
## that wrap past midnight.
func is_out_at(hour: float) -> bool:
	if is_equal_approx(out_start, out_end):
		return true                      # out around the clock
	if out_start < out_end:
		return hour >= out_start and hour < out_end
	return hour >= out_start or hour < out_end   # wraps midnight

## Move between OUT and INSIDE as the clock crosses this cat's window.
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

## True while the cat is indoors for the day (or night).
func is_inside() -> bool:
	return _state == State.INSIDE

## Which building this cat is currently in, or "" when it's out.
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
	# Some legs are taken at a dash, which is what makes a cat read differently
	# from a dog covering the same ground.
	_speed  = DASH_SPEED if randf() < DASH_CHANCE else WALK_SPEED

func _roam(delta: float) -> void:
	_timer -= delta
	var to_target : Vector2 = _target - global_position
	if to_target.length() < REACH_THRESHOLD or _timer <= 0.0:
		_sit()
		return
	var dir : Vector2 = to_target.normalized()
	velocity = dir * _speed
	move_and_slide()
	# Wedged against a building: pick somewhere else rather than pushing at it.
	if velocity.length() > 1.0 and get_real_velocity().length() < _speed * 0.25:
		_sit()
	_animate(dir, delta)

func _sit() -> void:
	_state = State.PAUSED
	_timer = randf_range(PAUSE_MIN, PAUSE_MAX)

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
## The line is a target, not a constraint: a cat that has fallen behind its slot
## sprints (up to FOLLOW_SPRINT, matched to the bike) to close the gap, so a
## fast player stretches the line out and it re-forms once they slow down.
## Trail points between one animal and the next in the line. Matches Dog and
## Bird so all three species queue at the same spacing.
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
	# The slot this cat wants to occupy: further back for later joiners.
	var back   : int = (parade_slot + 1) * SLOT_SPACING
	var wanted : int = maxi(trail.size() - 1 - back, 0)
	# Advance towards the wanted index rather than snapping, so the cat walks
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
	if _snub_timer > 0.0:
		return   # already turned this offer down a moment ago
	if body is NPCBase:
		return   # cats ignore villagers walking past
	# Only the player leads a parade. Cats and dogs are CharacterBody2D too, so
	# identify the player by the breadcrumb trail only they keep, rather than by
	# class — otherwise animals latch onto each other.
	if not (body is CharacterBody2D and body.get("path_trail") != null):
		return
	# A cat comes when it feels like it. On a refusal it wanders off and can be
	# tried again after SNUB_COOLDOWN.
	if randf() > JOIN_CHANCE:
		_snub_timer = SNUB_COOLDOWN
		_sit()
		GameManager.show_message("\U0001F408 %s isn't interested right now." % cat_name)
		return
	_state        = State.FOLLOWING
	_player       = body
	_follow_index = maxi(0, _player.path_trail.size() - 4)
	GameManager.show_message("\U0001F408 %s is following you!" % cat_name)

## Enable or disable the cat as a physical, touchable presence. Indoors it is
## neither: it can't be bumped into and doesn't block anyone in the street.
func _set_active(on: bool) -> void:
	_touch.monitoring = on
	set_collision_layer_value(1, on)
	set_collision_mask_value(1, on)
	velocity = Vector2.ZERO

func _animate(dir: Vector2, delta: float) -> void:
	# Dashing animates faster than prowling, so the gait matches the pace.
	var rate : float = 9.0 if _speed > WALK_SPEED else 6.5
	_walk_phase += delta * rate
	_sprite.walk_phase = _walk_phase
	_sprite.set_facing(dir)
