extends Node
## TimeManager (autoload) — single source of truth for the clock, the day phase,
## the day of the week, and the calendar date. Main drives it (start_day /
## advance); NPCs and anything else that cares about time listen to its signals.
##
## Time model: 2 in-game hours pass per real minute, so a full 24-hour day takes
## 12 real minutes. Days begin at 6am (DAY_START_HOUR).

enum Phase { DAY, SUNSET, NIGHT }

const HOURS_PER_REAL_MINUTE : float = 2.0
const HOURS_PER_SECOND      : float = HOURS_PER_REAL_MINUTE / 60.0
const DAY_START_HOUR        : float = 6.0    # days begin at 6am
const SLEEP_HOURS           : float = 7.0    # a night's sleep advances the clock this much

# Light curve (hours, 24h clock).
const SUNRISE_START : float = 6.0    # dawn begins
const SUNRISE_END   : float = 8.0    # full daylight
const SUNSET_START  : float = 19.0   # 7pm, light starts to fade
const SUNSET_END    : float = 21.0   # 9pm, full night

signal phase_changed(new_phase: int)
signal day_started(weekday: int)
signal midnight_passed()
## Emitted when the clock crosses into a new whole hour — hour-based NPC
## schedules re-evaluate on this.
signal hour_changed(new_hour: int)

var phase         : int   = Phase.DAY
var weekday       : int   = 0     # 0 = Sunday … 5 = Friday (mirrors GameManager.DAY_NAMES)
var year          : int   = 1
var season        : int   = Calendar.Season.FALL
var day_of_season : int   = 1     # 1-based day within the current season
var week          : int   = 0     # 0-based week number
var week_parity   : int   = 0     # week % 2, for alternating-week schedules

var hour : float = DAY_START_HOUR   # 0.0 … 24.0, current time of day

func start_day(day_number: int, at_hour: float = DAY_START_HOUR) -> void:
	_set_calendar(day_number)
	hour = fposmod(at_hour, 24.0)
	var p : int = _phase_for_hour(hour)
	if p != phase:
		phase = p
		phase_changed.emit(phase)
	day_started.emit(weekday)

func _set_calendar(day_number: int) -> void:
	weekday     = (day_number - 1) % GameManager.DAY_NAMES.size()
	week        = (day_number - 1) / GameManager.DAY_NAMES.size()
	week_parity = week % 2
	var date : Dictionary = Calendar.date_for_day(day_number)
	year          = date.year
	season        = date.season
	day_of_season = date.day

## Advance the clock by `delta` real seconds. Emits midnight_passed when the
## clock rolls past 24:00 (the caller advances the calendar day).
func advance(delta: float) -> void:
	var before : float = hour
	hour += delta * HOURS_PER_SECOND
	var rolled : bool = hour >= 24.0
	if rolled:
		hour = fposmod(hour, 24.0)
	_update_phase()
	if int(hour) != int(before) or rolled:
		hour_changed.emit(int(hour))
	if rolled and before < 24.0:
		midnight_passed.emit()

## Jump the clock forward (sleeping). Returns true if it crossed midnight.
func skip_hours(hours: float) -> bool:
	var total  : float = hour + hours
	var rolled : bool  = total >= 24.0
	hour = fposmod(total, 24.0)
	_update_phase()
	return rolled

## True if sleeping now would carry the player past midnight.
func sleep_crosses_midnight() -> bool:
	return hour + SLEEP_HOURS >= 24.0

func advance_calendar_day(day_number: int) -> void:
	_set_calendar(day_number)
	day_started.emit(weekday)

func _update_phase() -> void:
	var p : int = _phase_for_hour(hour)
	if p != phase:
		phase = p
		phase_changed.emit(phase)

func _phase_for_hour(h: float) -> int:
	if h >= SUNSET_END or h < SUNRISE_START:
		return Phase.NIGHT
	if h >= SUNSET_START:
		return Phase.SUNSET
	return Phase.DAY

## 0.0 = full night, 1.0 = full daylight — drives the sky tint.
func daylight() -> float:
	if hour < SUNRISE_START or hour >= SUNSET_END:
		return 0.0
	if hour < SUNRISE_END:
		return (hour - SUNRISE_START) / (SUNRISE_END - SUNRISE_START)
	if hour < SUNSET_START:
		return 1.0
	return 1.0 - (hour - SUNSET_START) / (SUNSET_END - SUNSET_START)

## "6:00 AM"
func clock_label() -> String:
	var h : int = int(hour)
	var m : int = int((hour - float(h)) * 60.0)
	var suffix : String = "AM" if h < 12 else "PM"
	var h12 : int = h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]

func weekday_name() -> String:
	return GameManager.DAY_NAMES[weekday]

func season_name() -> String:
	return Calendar.season_name(season)
