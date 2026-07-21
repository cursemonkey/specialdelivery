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

# Dialogue portrait. Leave empty to use the id-based convention
# res://assets/Portraits/<id>.png; set explicitly to override.
@export var portrait_path  : String   = ""

## The portrait texture for this NPC, or null if the art file doesn't exist yet
## (so NPCs without portraits simply show no portrait slot).
func portrait_texture() -> Texture2D:
	var path : String = portrait_path
	if path.is_empty():
		if id.is_empty():
			return null
		path = "res://assets/Portraits/%s.jpg	" % id
	if ResourceLoader.exists(path):
		return load(path)
	return null
