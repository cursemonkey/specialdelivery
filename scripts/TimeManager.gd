extends Node
## TimeManager (autoload) — single source of truth for the day phase and
## day of the week. Main drives it (start_day / set_day_progress); NPCs and
## anything else that cares about time listens to its signals.

enum Phase { DAY, SUNSET, NIGHT }

# Phase boundaries as a fraction of the day — matches Main's sky tint curve.
const SUNSET_START : float = 0.5
const NIGHT_START  : float = 0.75

signal phase_changed(new_phase: int)
signal day_started(weekday: int)

var phase        : int   = Phase.DAY
var weekday      : int   = 0     # 0 = Sunday … 5 = Friday (mirrors GameManager.DAY_NAMES)
var day_progress : float = 0.0   # 0.0 → 1.0 across the day

func start_day(day_number: int) -> void:
	weekday      = (day_number - 1) % GameManager.DAY_NAMES.size()
	day_progress = 0.0
	if phase != Phase.DAY:
		phase = Phase.DAY
		phase_changed.emit(phase)
	day_started.emit(weekday)

func set_day_progress(progress: float) -> void:
	day_progress = clampf(progress, 0.0, 1.0)
	var new_phase : int = Phase.DAY
	if day_progress >= NIGHT_START:
		new_phase = Phase.NIGHT
	elif day_progress >= SUNSET_START:
		new_phase = Phase.SUNSET
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)

func weekday_name() -> String:
	return GameManager.DAY_NAMES[weekday]
