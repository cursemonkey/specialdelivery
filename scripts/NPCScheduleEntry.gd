class_name NPCScheduleEntry
extends Resource
## One rule in a RegularNPC's weekly schedule:
## "on these weekdays, during this phase, be at this position."

@export var weekdays : Array[int] = []           # empty = every day; 0 = Sunday … 5 = Friday
@export var phase    : int        = 0            # TimeManager.Phase value
@export var target   : Vector2    = Vector2.ZERO

static func make(days: Array[int], entry_phase: int, pos: Vector2) -> NPCScheduleEntry:
	var entry : NPCScheduleEntry = NPCScheduleEntry.new()
	entry.weekdays = days
	entry.phase    = entry_phase
	entry.target   = pos
	return entry

func matches(day: int, current_phase: int) -> bool:
	if phase != current_phase:
		return false
	return weekdays.is_empty() or weekdays.has(day)
