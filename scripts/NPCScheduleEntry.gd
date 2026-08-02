class_name NPCScheduleEntry
extends Resource
## One rule in a weekly schedule: "on these weekdays (optionally only on even or
## odd weeks), during this phase, be at `anchor` + `offset`." Anchors are door
## node names resolved to world positions at spawn time (see NPCManager), so
## schedules survive the map being moved around.

@export var weekdays    : Array[int] = []            # empty = every day; 0 = Sunday … 5 = Friday
@export var phase       : int        = 0             # TimeManager.Phase value
@export var anchor      : String     = ""            # door node name to anchor to
@export var offset      : Vector2    = Vector2.ZERO  # offset from that anchor
@export var week_parity : int        = -1            # -1 = any week; 0 / 1 = only even / odd weeks
@export var interior    : bool       = false         # true = inside the anchor building, not at its door

static func make(days: Array[int], entry_phase: int, anchor_name: String, pos_offset: Vector2 = Vector2.ZERO, parity: int = -1, is_interior: bool = false) -> NPCScheduleEntry:
	var entry : NPCScheduleEntry = NPCScheduleEntry.new()
	entry.weekdays    = days
	entry.phase       = entry_phase
	entry.anchor      = anchor_name
	entry.offset      = pos_offset
	entry.week_parity = parity
	entry.interior    = is_interior
	return entry

func matches(day: int, current_phase: int, current_week_parity: int = -1) -> bool:
	if phase != current_phase:
		return false
	if week_parity != -1 and week_parity != current_week_parity:
		return false
	return weekdays.is_empty() or weekdays.has(day)
