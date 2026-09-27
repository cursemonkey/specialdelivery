extends CanvasLayer
## The workbench menu, opened with E at the bench in a home's garage or back
## yard. Lists every recipe in ItemRegistry.RECIPES with what it needs against
## what's in the bag, and makes one on request.
##
## Built in code, like SleepPrompt, so Main can add it without scene wiring.

const PANEL_BG     : Color = Color(0.12, 0.12, 0.16, 0.96)
const PANEL_BORDER : Color = Color(0.55, 0.60, 0.75)
const TEXT_DIM     : Color = Color(0.72, 0.72, 0.78)
const TEXT_OK      : Color = Color(0.60, 0.88, 0.60)
const TEXT_SHORT   : Color = Color(0.95, 0.55, 0.50)

var _dim     : ColorRect
var _panel   : PanelContainer
var _list    : VBoxContainer
var _status  : Label
var _close_btn : Button
var _open    : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 90
	visible      = false
	_build()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_border_width_all(2)
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var title : Label = Label.new()
	title.text = "🔧 Workbench"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	vbox.add_child(_list)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(_status)

	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(_close)
	vbox.add_child(_close_btn)

	var hint : Label = Label.new()
	hint.text = "Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(hint)

## One row per recipe: what it makes, each input as have/need, and a Craft
## button that's only live when the bag holds enough. Rebuilt after every
## craft so the counts stay true.
func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var first_live : Button = null
	for recipe in ItemRegistry.RECIPES:
		var out_id : String = str(recipe.get("output", ""))
		var row    : HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_list.add_child(row)

		var info : VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_lbl : Label = Label.new()
		name_lbl.text = "%s %s" % [ItemRegistry.icon(out_id), ItemRegistry.display_name(out_id)]
		info.add_child(name_lbl)
		var inputs : Dictionary = recipe.get("inputs", {})
		for in_id in inputs:
			var need : int = int(inputs[in_id])
			var have : int = GameManager.count_of(str(in_id))
			var need_lbl : Label = Label.new()
			need_lbl.text = "   %s %s  %d / %d" % [ItemRegistry.icon(str(in_id)),
					ItemRegistry.display_name(str(in_id)), have, need]
			need_lbl.add_theme_font_size_override("font_size", 12)
			need_lbl.add_theme_color_override("font_color", TEXT_OK if have >= need else TEXT_SHORT)
			info.add_child(need_lbl)
		var note : String = _recipe_note(out_id)
		if not note.is_empty():
			var note_lbl : Label = Label.new()
			note_lbl.text = "   " + note
			note_lbl.add_theme_font_size_override("font_size", 11)
			note_lbl.add_theme_color_override("font_color", TEXT_DIM)
			info.add_child(note_lbl)

		var btn : Button = Button.new()
		btn.text = "Craft"
		btn.custom_minimum_size = Vector2(80, 34)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.disabled = not GameManager.can_craft(recipe)
		btn.pressed.connect(_craft.bind(recipe))
		row.add_child(btn)
		if first_live == null and not btn.disabled:
			first_live = btn
	if first_live != null:
		first_live.grab_focus()
	else:
		_close_btn.grab_focus()

## Extra line under a recipe explaining what the thing is for.
func _recipe_note(out_id: String) -> String:
	if out_id == "storage_bucket":
		return "+%d package on the rack. Hold it, press E to fit (%d / %d on the bike)." \
				% [GameManager.BUCKET_SLOTS, GameManager.storage_buckets, GameManager.MAX_STORAGE_BUCKETS]
	return ""

func _craft(recipe: Dictionary) -> void:
	var out_id : String = str(recipe.get("output", ""))
	var why    : String = GameManager.craft(recipe)
	if why.is_empty():
		_status.text = "Made a %s %s — it's in your bag." % [ItemRegistry.icon(out_id), ItemRegistry.display_name(out_id)]
	else:
		_status.text = "Couldn't make it: %s." % why
	_refresh()

func open() -> void:
	visible = true
	_open   = true
	_status.text = ""
	get_tree().paused = true
	_refresh()

func _close() -> void:
	if not _open:
		return
	_open             = false
	visible           = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
