class_name NPCDefinition
extends Resource
## All data for one named villager, keyed by `id` in NPCRegistry. This is the
## single place to flesh an NPC out over time: appearance, weekly routine, and
## (eventually) a branching conversation tree.

@export var id             : String = ""
@export var display_name   : String = "Villager"

# Home: a door node name + offset. Also the fallback location when no schedule
# entry matches the current weekday/phase.
@export var home_anchor    : String  = ""
@export var home_offset    : Vector2 = Vector2(0, 20)

# Appearance (procedural — see NPCSprite.gd).
@export var shirt_color    : Color = Color("#c46a5a")
@export var pants_color    : Color = Color("#4a4a5e")
@export var hair_color     : Color = Color("#3a2a1a")

# Daily routine.
@export var schedule       : Array[NPCScheduleEntry] = []

# Conversation. `dialogue_lines` is the simple linear fallback used until a
# real tree exists; assign `conversation` later and have it take precedence.
@export var dialogue_lines : Array    = []
var conversation           : Resource = null
