class_name NPCScheduleEntry
extends Resource
## One rule in a weekly schedule: "on these weekdays (optionally only on even or
## odd weeks), during this time, be at `anchor` + `offset`." Anchors are door
## node names resolved to world positions at spawn time (see NPCManager), so
## schedules survive the map being moved around.
##
## Timing can be expressed two ways:
##   * by day phase  — make(...)      : DAY / SUNSET / NIGHT
##   * by clock hours — make_hours(...): e.g. 8:00–18:00, or 18:00–4:00 overnight
## Hour-based entries are matched against TimeManager.hour and win over phase
## entries when both could apply (first match in the list still wins overall).

@export var weekdays    : Array[int] = []            # empty = every day; 0 = Sunday … 6 = Saturday
@export var phase       : int        = 0             # TimeManager.Phase value (phase entries only)
@export var anchor      : String     = ""            # door node name to anchor to
@export var offset      : Vector2    = Vector2.ZERO  # offset from that anchor
@export var week_parity : int        = -1            # -1 = any week; 0 / 1 = only even / odd weeks
@export var interior    : bool       = false         # true = inside the anchor building, not at its door
@export var use_hours   : bool       = false         # true = match on start_hour/end_hour, not phase
@export var start_hour  : float      = 0.0           # inclusive
@export var end_hour    : float      = 0.0           # exclusive; may wrap past midnight (e.g. 18 → 4)
@export var seasons     : Array[int] = []            # empty = all seasons; else Calendar.Season values
## Wander radius in px around the anchor spot. 0 = stand still; >0 makes the NPC
## drift to random points within this radius (outdoor entries only).
@export var wander      : float      = 0.0

static func make(days: Array[int], entry_phase: int, anchor_name: String, pos_offset: Vector2 = Vector2.ZERO, parity: int = -1, is_interior: bool = false) -> NPCScheduleEntry:
	var entry : NPCScheduleEntry = NPCScheduleEntry.new()
	entry.weekdays    = days
	entry.phase       = entry_phase
	entry.anchor      = anchor_name
	entry.offset      = pos_offset
	entry.week_parity = parity
	entry.interior    = is_interior
	return entry

## Clock-based variant: active from `from_hour` until `to_hour` (24h clock).
## A `to_hour` earlier than `from_hour` wraps past midnight (18 → 4 = 6pm–4am).
static func make_hours(days: Array[int], from_hour: float, to_hour: float, anchor_name: String, pos_offset: Vector2 = Vector2.ZERO, parity: int = -1, is_interior: bool = false) -> NPCScheduleEntry:
	var entry : NPCScheduleEntry = NPCScheduleEntry.new()
	entry.weekdays    = days
	entry.use_hours   = true
	entry.start_hour  = from_hour
	entry.end_hour    = to_hour
	entry.anchor      = anchor_name
	entry.offset      = pos_offset
	entry.week_parity = parity
	entry.interior    = is_interior
	return entry

func matches(day: int, current_phase: int, current_week_parity: int = -1, current_hour: float = -1.0, current_season: int = -1) -> bool:
	if week_parity != -1 and week_parity != current_week_parity:
		return false
	if not (weekdays.is_empty() or weekdays.has(day)):
		return false
	if not seasons.is_empty() and current_season >= 0 and not seasons.has(current_season):
		return false
	if use_hours:
		if current_hour < 0.0:
			return false
		return _hour_in_range(current_hour)
	return phase == current_phase

## Chainable tweaks, so callers don't need ever-longer positional arg lists:
##   NPCScheduleEntry.make_hours(...).in_seasons([...]).wandering(120.0)
func in_seasons(season_list: Array[int]) -> NPCScheduleEntry:
	seasons = season_list
	return self

func wandering(radius: float) -> NPCScheduleEntry:
	wander = radius
	return self

func _hour_in_range(h: float) -> bool:
	if is_equal_approx(start_hour, end_hour):
		return false
	if start_hour < end_hour:
		return h >= start_hour and h < end_hour
	# Wraps past midnight, e.g. 18:00 → 04:00.
	return h >= start_hour or h < end_hour
