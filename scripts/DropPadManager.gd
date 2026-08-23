extends StaticBody2D

## Seconds between "bike is full" reminders while parked on a loaded pad.
const FULL_WARN_INTERVAL : float = 6.0

signal drop_arrived(pad_idx: int, count: int)
signal pad_picked_up(pad_idx: int, count: int, landing_times: Array)

@export var max_drops_per_day    : int   = 4
@export var max_packages_per_drop: int   = 3
@export var pickup_range         : float = 64.0

const MIN_DROPS_PER_DAY   : int   = 2     # always at least this many drops
const FIRST_DROP_MAX_TIME : float = 30.0  # first drop must land within this many seconds

var player_ref : CharacterBody2D = null

var _pads      : Array = []
var _centroids : Array[Vector2] = []
var _packages  : Array[int]     = []
var _landing   : Array          = []   # per pad: Array[float] of play_clock landing times

var _day_duration : float        = 0.0
var _day_elapsed  : float        = 0.0
var _drop_times   : Array[float] = []
var _drops_fired  : int          = 0
var _day_active   : bool         = false

func _ready() -> void:
	for child in get_children():
		if child is NavigationRegion2D:
			_pads.append(child)
			_packages.append(0)
			_landing.append([])
	_compute_centroids()

func _compute_centroids() -> void:
	_centroids.clear()
	for pad in _pads:
		var nav_poly : NavigationPolygon = pad.navigation_polygon
		if nav_poly == null or nav_poly.get_outline_count() == 0:
			_centroids.append(pad.global_position)
			continue
		var sum   := Vector2.ZERO
		var total := 0
		for i in nav_poly.get_outline_count():
			for pt in nav_poly.get_outline(i):
				sum   += pad.to_global(pt)
				total += 1
		_centroids.append(sum / total if total > 0 else pad.global_position)

func start_day(duration: float) -> void:
	_day_duration = duration
	_day_elapsed  = 0.0
	_drops_fired  = 0
	_drop_times.clear()
	_day_active   = true
	_compute_centroids()
	for i in _packages.size():
		_packages[i] = 0
		_landing[i]  = []
	_schedule_drops()

func end_day() -> void:
	_day_active = false

func _schedule_drops() -> void:
	_drop_times.clear()
	var drop_count : int = maxi(max_drops_per_day, MIN_DROPS_PER_DAY)

	# First drop always lands within the first 30 s so deliveries start promptly.
	_drop_times.append(randf_range(3.0, minf(12.0, FIRST_DROP_MAX_TIME)))

	# Spread the remaining drops across roughly the first two-thirds of the day.
	var window : float = maxf(_day_duration * (2.0 / 3.0), FIRST_DROP_MAX_TIME)
	for _i in drop_count - 1:
		_drop_times.append(randf_range(15.0, window))
	_drop_times.sort()

func tick(delta: float) -> void:
	if not _day_active:
		return
	_day_elapsed += delta
	while _drops_fired < _drop_times.size() and _day_elapsed >= _drop_times[_drops_fired]:
		_fire_drop()
		_drops_fired += 1
	_check_pickup()
	queue_redraw()

func _draw() -> void:
	for i in _pads.size():
		if _packages[i] <= 0:
			continue
		var local_pos : Vector2 = to_local(_centroids[i])
		var half      : Vector2 = Vector2(10, 10)
		draw_rect(Rect2(local_pos - half, half * 2.0), Color(1.0, 0.65, 0.1, 0.85))
		draw_rect(Rect2(local_pos - half, half * 2.0), Color(0.5, 0.3, 0.0, 1.0), false, 2.0)
		draw_string(ThemeDB.fallback_font, local_pos + Vector2(-5, 5),
					str(_packages[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 1))

func _fire_drop() -> void:
	if _pads.is_empty():
		return
	var idx   := randi() % _pads.size()
	var count := 1 + randi() % max_packages_per_drop
	_packages[idx] += count
	for _p in count:
		_landing[idx].append(GameManager.play_clock)
	drop_arrived.emit(idx, count)

func _check_pickup() -> void:
	if player_ref == null:
		return
	for i in _pads.size():
		if _packages[i] > 0:
			if player_ref.global_position.distance_to(_centroids[i]) <= pickup_range:
				# Only take what fits on the bike's rack; the rest stays on the
				# pad to be collected after some deliveries free up space.
				var count : int = mini(_packages[i], GameManager.package_space())
				if count <= 0:
					_warn_full()
					continue
				var landing_times : Array = _landing[i].slice(0, count)
				_packages[i] -= count
				_landing[i]   = _landing[i].slice(count)
				pad_picked_up.emit(i, count, landing_times)

func get_packages() -> Array[int]:
	return _packages

func get_centroids() -> Array[Vector2]:
	return _centroids

## Standing on a pad with a full rack: say so, but only occasionally —
## pickup is checked every frame, so an unthrottled message would spam.
var _full_warned_at : float = -100.0

func _warn_full() -> void:
	if GameManager.play_clock - _full_warned_at < FULL_WARN_INTERVAL:
		return
	_full_warned_at = GameManager.play_clock
	GameManager.show_message(
			"🚲 Bike is full (%d/%d) — deliver some before picking these up."
			% [GameManager.packages, GameManager.bike_max_packages])
