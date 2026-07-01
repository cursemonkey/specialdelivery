extends StaticBody2D

signal drop_arrived(pad_idx: int, count: int)
signal pad_picked_up(pad_idx: int, count: int)

@export var max_drops_per_day    : int   = 4
@export var max_packages_per_drop: int   = 3
@export var pickup_range         : float = 64.0

var player_ref : CharacterBody2D = null

var _pads      : Array = []
var _centroids : Array[Vector2] = []
var _packages  : Array[int]     = []

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
	_schedule_drops()

func end_day() -> void:
	_day_active = false

func _schedule_drops() -> void:
	var window : float = _day_duration * (2.0 / 3.0)
	_drop_times.append(randf_range(3.0, 10.0))
	for _i in max_drops_per_day - 1:
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
	drop_arrived.emit(idx, count)

func _check_pickup() -> void:
	if player_ref == null:
		return
	for i in _pads.size():
		if _packages[i] > 0:
			if player_ref.global_position.distance_to(_centroids[i]) <= pickup_range:
				var count     := _packages[i]
				_packages[i]  = 0
				pad_picked_up.emit(i, count)

func get_packages() -> Array[int]:
	return _packages

func get_centroids() -> Array[Vector2]:
	return _centroids
