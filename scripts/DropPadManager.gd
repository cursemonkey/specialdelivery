extends StaticBody2D

## Seconds between "bike is full" reminders while parked on a loaded pad.
const FULL_WARN_INTERVAL : float = 6.0

signal drop_arrived(pad_idx: int, count: int)
signal pad_picked_up(pad_idx: int, count: int, landing_times: Array)
## Packages nobody fetched in time were taken away again.
signal package_expired(pad_idx: int, count: int)

@export var max_drops_per_day    : int   = 4
@export var max_packages_per_drop: int   = 3
@export var pickup_range         : float = 64.0

const MIN_DROPS_PER_DAY   : int   = 2     # legacy floor, kept for the settings UI
const FIRST_DROP_MAX_TIME : float = 30.0  # first drop must land within this many seconds

## Drops now arrive continuously rather than all being scheduled at midnight,
## and packages left on a pad go stale and are collected by someone else.
##
## Tuning values below are written in GAME HOURS because they read naturally
## against the day/night cycle, but GameManager.play_clock counts REAL SECONDS.
## Everything that touches play_clock must go through _hours_to_clock() — a full
## day is 24 game hours = 12 real minutes, so one game hour is 30 real seconds.
## How long a package waits before someone else collects it, in game hours.
## Player-tunable from the settings panel — see GameManager.package_expiry_hours.
const EXPIRY_WARN_FRACTION : float = 0.25  # warn with this share of the wait left
const EXPIRY_WARN_MAX      : float = 0.6   # … but never more than this many hours

## GameManager.play_clock counts REAL SECONDS, but every tuning value here is
## expressed in game hours (which read more naturally against the day/night
## cycle). This converts: one game hour is 1 / HOURS_PER_SECOND real seconds,
## i.e. 30s at the standard 2 game-hours-per-real-minute rate.
func _hours_to_clock(game_hours: float) -> float:
	return game_hours / TimeManager.HOURS_PER_SECOND

## The live expiry window, in play_clock seconds, read from settings so a
## change applies immediately.
func package_lifetime() -> float:
	return _hours_to_clock(GameManager.package_expiry_hours)

## How long before expiry to nudge the player. Scales with the window so a short
## setting still gets a usable warning rather than one that fires instantly.
func expiry_warn_at() -> float:
	return minf(package_lifetime() * EXPIRY_WARN_FRACTION, _hours_to_clock(EXPIRY_WARN_MAX))
## Drops are now spread across the whole 24-hour day rather than the old
## midnight-planned burst, so `max_drops_per_day` (the Settings slider) sets the
## RATE: the average gap is a day divided by that many drops, jittered by
## ±DROP_GAP_JITTER so arrivals stay irregular.
const HOURS_PER_DAY      : float = 24.0
const DROP_GAP_JITTER    : float = 0.35  # ±35% around the average gap
const DROP_GAP_FLOOR     : float = 0.75  # game hours; never busier than this

var player_ref : CharacterBody2D = null

var _pads      : Array = []
var _centroids : Array[Vector2] = []
var _packages  : Array[int]     = []
var _landing   : Array          = []   # per pad: Array[float] of play_clock landing times

var _day_duration : float        = 0.0
var _day_elapsed  : float        = 0.0
var _day_active   : bool         = false
## Game-clock time of the next drop, and of the last expiry warning per pad.
var _next_drop_at : float        = 0.0
var _warned       : Array        = []   # per pad: bool, reset when it empties

func _ready() -> void:
	for child in get_children():
		if child is NavigationRegion2D:
			_pads.append(child)
			_packages.append(0)
			_landing.append([])
			_warned.append(false)
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

## Begin (or resume) delivering drops. Pads are cleared and the first drop is
## scheduled promptly so there's something to fetch straight away.
func start_day(duration: float) -> void:
	_day_duration = duration
	_day_elapsed  = 0.0
	_day_active   = true
	_compute_centroids()
	for i in _packages.size():
		_packages[i] = 0
		_landing[i]  = []
		_warned[i]   = false
	# First drop lands within the opening moments, then drops keep coming.
	# First drop lands a few real seconds in, so there's work straight away.
	_next_drop_at = GameManager.play_clock + randf_range(3.0, 12.0)

func end_day() -> void:
	_day_active = false

func tick(delta: float) -> void:
	if not _day_active:
		return
	_day_elapsed += delta
	# Drops arrive all day long rather than on a midnight-planned schedule.
	if GameManager.play_clock >= _next_drop_at:
		_fire_drop()
		_next_drop_at = GameManager.play_clock + _next_gap()
	_expire_stale()
	_check_pickup()
	queue_redraw()

## Game hours until the next drop: the day split evenly by max_drops_per_day,
## jittered so the rhythm isn't metronomic. The floor stops a high setting from
## flooding the pads faster than packages can be fetched.
func _next_gap() -> float:
	var drops : int   = maxi(max_drops_per_day, 1)
	var avg   : float = maxf(HOURS_PER_DAY / float(drops), DROP_GAP_FLOOR)
	return _hours_to_clock(avg * randf_range(1.0 - DROP_GAP_JITTER, 1.0 + DROP_GAP_JITTER))

## Packages nobody collected are taken away again, oldest first. Each package
## carries its own landing time, so a pad topped up by a later drop keeps the
## newer ones after the older ones lapse.
func _expire_stale() -> void:
	var now : float = GameManager.play_clock
	for i in _pads.size():
		if _packages[i] <= 0:
			_warned[i] = false
			continue
		var lifetime : float = package_lifetime()
		var kept : Array = []
		for t in _landing[i]:
			if now - float(t) < lifetime:
				kept.append(t)
		var lost : int = _landing[i].size() - kept.size()
		if lost > 0:
			_landing[i]   = kept
			_packages[i]  = maxi(_packages[i] - lost, 0)
			if _packages[i] <= 0:
				_warned[i] = false
			GameManager.show_message(
					"📦 %d package%s at Pad %d went stale and was collected."
					% [lost, "s" if lost > 1 else "", i + 1])
			package_expired.emit(i, lost)
			continue
		# Still fresh, but about to lapse: nudge the player once per pad.
		if not _warned[i] and not _landing[i].is_empty():
			var oldest : float = float(_landing[i][0])
			if package_lifetime() - (now - oldest) <= expiry_warn_at():
				_warned[i] = true
				GameManager.show_message(
						"⏳ Packages at Pad %d won't wait much longer!" % [i + 1])

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
	# Prefer an empty pad so drops spread around the map instead of stacking on
	# one; fall back to any pad when they're all holding something.
	var empty : Array[int] = []
	for i in _pads.size():
		if _packages[i] <= 0:
			empty.append(i)
	var idx : int = empty[randi() % empty.size()] if not empty.is_empty() 			else randi() % _pads.size()
	var count : int = 1 + randi() % max_packages_per_drop
	_packages[idx] += count
	for _p in count:
		_landing[idx].append(GameManager.play_clock)
	# A fresh delivery re-arms the "about to lapse" nudge for this pad.
	_warned[idx] = false
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
