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
@export var skin_color     : Color = Color("#e8c8a0")
@export var bald           : bool  = false

# Daily routine.
@export var schedule       : Array[NPCScheduleEntry] = []

# Conversation. `dialogue_lines` is the simple linear fallback used until a
# real tree exists; assign `conversation` later and have it take precedence.
@export var dialogue_lines : Array    = []
# When true, talking plays ONE randomly chosen line from dialogue_lines instead
# of stepping through all of them in order.
@export var random_dialogue : bool    = false
var conversation           : Resource = null

const PORTRAIT_DIR : String = "res://assets/Portraits/"

# Dialogue portrait. Leave empty to use the id-based convention
# res://assets/Portraits/<id>.jpg; set explicitly to override the neutral base.
@export var portrait_path  : String   = ""

# Seasonal absence: the NPC is away from town (not spawned at all) from
# away_from (season, day) through away_to (season, day), inclusive. The range
# may wrap past the end of the year. Leave away_season_from at -1 to disable.
@export var away_season_from : int = -1
@export var away_day_from    : int = 1
@export var away_season_to   : int = -1
@export var away_day_to      : int = 1

func set_away(from_season: int, from_day: int, to_season: int, to_day: int) -> void:
	away_season_from = from_season
	away_day_from    = from_day
	away_season_to   = to_season
	away_day_to      = to_day

## True if this NPC is out of town on the given absolute day.
func is_away_on(absolute_day: int) -> bool:
	if away_season_from < 0 or away_season_to < 0:
		return false
	var d     : Dictionary = Calendar.date_for_day(absolute_day)
	var today : int = _day_of_year(d.season, d.day)
	var from  : int = _day_of_year(away_season_from, away_day_from)
	var to    : int = _day_of_year(away_season_to,   away_day_to)
	if from <= to:
		return today >= from and today <= to
	# Range wraps past the end of the year (e.g. Spring 10 → Fall 20).
	return today >= from or today <= to

static func _day_of_year(season: int, day: int) -> int:
	var total : int = 0
	for i in season:
		total += Calendar.SEASON_LENGTHS[i]
	return total + day

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
	for m in [DialogueLine.CALM, DialogueLine.HAPPY, DialogueLine.SURPRISED,
			DialogueLine.MAD, DialogueLine.SAD]:
		var alt : Texture2D = _load_portrait(PORTRAIT_DIR + "%s_%s.jpg" % [id, m])
		if alt != null:
			return alt
	return null

func _load_portrait(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
