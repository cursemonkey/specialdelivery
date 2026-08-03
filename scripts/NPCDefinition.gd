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

const PORTRAIT_DIR : String = "res://assets/Portraits/"

# Dialogue portrait. Leave empty to use the id-based convention
# res://assets/Portraits/<id>.jpg; set explicitly to override the neutral base.
@export var portrait_path  : String   = ""

## The portrait texture for this NPC in the given mood (see DialogueLine mood
## constants). Falls back to the neutral base portrait when the mood-specific
## art is missing, and to null when there's no art at all — so NPCs without
## portraits simply show no portrait slot.
func portrait_texture(mood: String = "") -> Texture2D:
	if not mood.is_empty() and not id.is_empty():
		var moody : Texture2D = _load_portrait(PORTRAIT_DIR + "%s_%s.jpg" % [id, mood])
		if moody != null:
			return moody
	if not portrait_path.is_empty():
		return _load_portrait(portrait_path)
	if id.is_empty():
		return null
	var base : Texture2D = _load_portrait(PORTRAIT_DIR + "%s.jpg" % id)
	if base != null:
		return base
	# No neutral base authored yet — fall back to any mood art that does exist
	# so the portrait slot still fills in.
	for m in [DialogueLine.CALM, DialogueLine.HAPPY, DialogueLine.SURPRISED, DialogueLine.MAD]:
		var alt : Texture2D = _load_portrait(PORTRAIT_DIR + "%s_%s.jpg" % [id, m])
		if alt != null:
			return alt
	return null

func _load_portrait(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
