extends Control
## Friendship screen: every villager the player has met on one scrollable list,
## with their friendship as a row of hearts. Purely a read-out — it reflects
## GameManager.friendship and never changes it. Shown from the pause menu's
## Friends button, so it lives inside the paused tree.
##
## Each row also names what that villager is known to like, but only once the
## player has actually given them something they liked or loved. Tastes are
## discovered by gifting, not handed over up front.

const HEART_FULL  : String = "♥"
const HEART_EMPTY : String = "♡"

@onready var rows         : VBoxContainer = $Dim/FriendsPanel/VBox/Scroll/Rows
@onready var close_button : Button        = $Dim/FriendsPanel/VBox/CloseFriends
@onready var subtitle     : Label         = $Dim/FriendsPanel/VBox/Subtitle

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	# Live-update while open, so a gift given mid-conversation shows up.
	GameManager.friendship_changed.connect(func(_id: String, _p: int) -> void: _refresh_if_open())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func _refresh_if_open() -> void:
	if visible:
		refresh()

## Rebuild the list: best friends first, then everyone else alphabetically, so
## the people the player has invested in sit at the top.
func refresh() -> void:
	for c in rows.get_children():
		c.queue_free()

	var cast : Array = []
	for def in NPCRegistry.all_definitions():
		cast.append(def)
	cast.sort_custom(func(a: NPCDefinition, b: NPCDefinition) -> bool:
		var pa : int = GameManager.friendship_with(a.id)
		var pb : int = GameManager.friendship_with(b.id)
		if pa != pb:
			return pa > pb
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)

	var friends : int = 0
	for def in cast:
		if GameManager.friendship_with(def.id) > 0:
			friends += 1
		rows.add_child(_make_row(def))

	subtitle.text = "%d of %d villagers befriended" % [friends, cast.size()]

## One row: name, hearts, point count, and any tastes discovered so far.
func _make_row(def: NPCDefinition) -> Control:
	var points : int = GameManager.friendship_with(def.id)
	var hearts : int = GameManager.friendship_hearts(def.id)

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label : Label = Label.new()
	name_label.text = def.display_name
	name_label.custom_minimum_size = Vector2(150, 0)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	row.add_child(name_label)

	var heart_label : Label = Label.new()
	heart_label.text = HEART_FULL.repeat(hearts) \
			+ HEART_EMPTY.repeat(GameManager.FRIENDSHIP_HEARTS - hearts)
	heart_label.custom_minimum_size = Vector2(120, 0)
	heart_label.add_theme_color_override("font_color", Color(0.93, 0.42, 0.52))
	row.add_child(heart_label)

	var pts : Label = Label.new()
	pts.text = "%d/%d" % [points, GameManager.FRIENDSHIP_MAX]
	pts.custom_minimum_size = Vector2(52, 0)
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts.add_theme_color_override("font_color", Color(0.66, 0.66, 0.74))
	row.add_child(pts)

	var taste : Label = Label.new()
	taste.text = _taste_hint(def)
	taste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	taste.add_theme_color_override("font_color", Color(0.60, 0.66, 0.60))
	row.add_child(taste)

	return row

## What the player has worked out about this villager's tastes. Nothing is
## revealed until they've been given something they cared about, so the list
## fills in through play rather than spoiling every preference at the start.
func _taste_hint(def: NPCDefinition) -> String:
	if GameManager.friendship_with(def.id) <= 0:
		return ""
	var likes : Array = []
	for id in def.loved_gifts:
		likes.append("%s %s" % [ItemRegistry.icon(id), ItemRegistry.display_name(id)])
	if likes.is_empty():
		return ""
	return "loves " + ", ".join(likes)
