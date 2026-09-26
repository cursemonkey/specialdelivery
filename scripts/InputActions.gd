extends Node
## InputActions (autoload) — the list of rebindable controls, plus loading,
## saving and applying the player's own key choices.
##
## project.godot stays the source of truth for the DEFAULT binding of each
## action: this snapshots whatever the InputMap holds at startup, before any
## override is applied, so "Reset to defaults" always returns to the shipped
## scheme and there is no second copy of the defaults to keep in step.
##
## Overrides live in their own file rather than in settings.json, because they
## are a different kind of preference and GameManager rewrites that file
## wholesale.
##
## Only keyboard events are handled. Adding a gamepad later means storing a
## type tag alongside each binding and widening _event_to_dict / _dict_to_event.

const SAVE_PATH : String = "user://keybinds.json"

## Rows on the controls page, in display order. `action` must exist in the
## InputMap (see project.godot); `label` is what the player reads.
const ROWS : Array[Dictionary] = [
	{"heading": "Movement"},
	{"action": "move_up",     "label": "Walk / Pedal Forward"},
	{"action": "move_down",   "label": "Walk Back / Brake"},
	{"action": "move_left",   "label": "Turn Left"},
	{"action": "move_right",  "label": "Turn Right"},
	{"heading": "Actions"},
	{"action": "mount_bike",    "label": "Get On / Off Bike"},
	{"action": "throw_package", "label": "Throw Package"},
	{"action": "interact",      "label": "Talk / Interact"},
	{"action": "stow_item",     "label": "Put Item Away"},
	{"action": "hop",           "label": "Hop"},
	{"heading": "Menus"},
	{"action": "pause_game",       "label": "Pause Menu"},
	{"action": "advance_dialogue", "label": "Advance Dialogue"},
]

## Emitted whenever a binding changes, so open UI can refresh.
signal bindings_changed()

## action -> Array of InputEvent, as shipped in project.godot.
var _defaults : Dictionary = {}
var _loaded   : bool = false

func _ready() -> void:
	_snapshot_defaults()
	load_bindings()

## Remember the shipped binding of every listed action before anything is
## overridden. Called once, first thing.
func _snapshot_defaults() -> void:
	for row in ROWS:
		if not row.has("action"):
			continue
		var action : String = str(row["action"])
		if not InputMap.has_action(action):
			push_warning("InputActions: action '%s' is listed but not in the InputMap." % action)
			continue
		var events : Array = []
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				events.append(e.duplicate())
		_defaults[action] = events

## Every rebindable action id, in display order.
func action_ids() -> Array[String]:
	var out : Array[String] = []
	for row in ROWS:
		if row.has("action"):
			out.append(str(row["action"]))
	return out

func label_for(action: String) -> String:
	for row in ROWS:
		if row.has("action") and str(row["action"]) == action:
			return str(row["label"])
	return action

# ── Reading the current binding ────────────────────────────
## The key events currently bound to `action`.
func events_for(action: String) -> Array:
	if not InputMap.has_action(action):
		return []
	var out : Array = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append(e)
	return out

## A readable list of the keys bound to `action`, e.g. "W, Up". Returns
## "Unbound" when nothing is set, so the page never shows an empty cell.
func display_for(action: String) -> String:
	var parts : Array[String] = []
	for e in events_for(action):
		var name : String = key_name(e)
		if name != "" and not parts.has(name):
			parts.append(name)
	if parts.is_empty():
		return "Unbound"
	return ", ".join(parts)

## A single key event as the player would name it. Physical keycodes are
## translated through the active layout, so a French keyboard shows "Z" where
## a US one shows "W" for the same physical key.
func key_name(event: InputEventKey) -> String:
	if event == null:
		return ""
	var code : int = event.physical_keycode
	if code != 0:
		code = DisplayServer.keyboard_get_keycode_from_physical(code)
	else:
		code = event.keycode
	if code == 0:
		return ""
	var text : String = OS.get_keycode_string(code)
	# Spell out keys whose own name is a blank or a symbol nobody reads aloud.
	match code:
		KEY_SPACE:  return "Space"
		KEY_ENTER:  return "Enter"
		KEY_ESCAPE: return "Esc"
	return text

# ── Changing a binding ─────────────────────────────────────
## Replace every key bound to `action` with `event`. Returns false when the
## event is unusable.
func set_binding(action: String, event: InputEventKey) -> bool:
	if event == null or not InputMap.has_action(action):
		return false
	var clean : InputEventKey = _normalise(event)
	if clean == null:
		return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, clean)
	save_bindings()
	bindings_changed.emit()
	return true

## Which other listed action already uses `event`, or "" when it is free.
## Checked before binding so the page can warn instead of silently creating a
## key that does two things.
func conflict_for(action: String, event: InputEventKey) -> String:
	var clean : InputEventKey = _normalise(event)
	if clean == null:
		return ""
	for other in action_ids():
		if other == action:
			continue
		for e in events_for(other):
			if _same_key(e, clean):
				return other
	return ""

## Strip an event down to the key itself: no echo, no pressed state, physical
## code preferred so bindings survive a layout change.
func _normalise(event: InputEventKey) -> InputEventKey:
	var out : InputEventKey = InputEventKey.new()
	var phys : int = event.physical_keycode
	if phys == 0 and event.keycode != 0:
		phys = DisplayServer.keyboard_get_keycode_from_physical(event.keycode)
		if phys == 0:
			phys = event.keycode
	if phys == 0:
		return null
	out.physical_keycode = phys
	# Modifiers are carried so Shift+E and E stay distinct.
	out.shift_pressed = event.shift_pressed
	out.ctrl_pressed  = event.ctrl_pressed
	out.alt_pressed   = event.alt_pressed
	out.meta_pressed  = event.meta_pressed
	return out

func _same_key(a: InputEventKey, b: InputEventKey) -> bool:
	if a == null or b == null:
		return false
	var ac : int = a.physical_keycode if a.physical_keycode != 0 else a.keycode
	var bc : int = b.physical_keycode if b.physical_keycode != 0 else b.keycode
	return ac == bc \
		and a.shift_pressed == b.shift_pressed \
		and a.ctrl_pressed  == b.ctrl_pressed \
		and a.alt_pressed   == b.alt_pressed \
		and a.meta_pressed  == b.meta_pressed

# ── Defaults ───────────────────────────────────────────────
## Put one action back to the binding it shipped with.
func reset_action(action: String) -> void:
	if not _defaults.has(action) or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for e in _defaults[action]:
		InputMap.action_add_event(action, e.duplicate())
	save_bindings()
	bindings_changed.emit()

## Put every action back to the shipped scheme.
func reset_all() -> void:
	for action in action_ids():
		if not _defaults.has(action) or not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for e in _defaults[action]:
			InputMap.action_add_event(action, e.duplicate())
	save_bindings()
	bindings_changed.emit()

## True when `action` still matches what it shipped with.
func is_default(action: String) -> bool:
	if not _defaults.has(action):
		return true
	var now : Array = events_for(action)
	var def : Array = _defaults[action]
	if now.size() != def.size():
		return false
	for i in now.size():
		if not _same_key(now[i], def[i]):
			return false
	return true

# ── Persistence ────────────────────────────────────────────
func save_bindings() -> void:
	var data : Dictionary = {}
	for action in action_ids():
		# Only actions the player actually changed are written, so a later
		# change to the shipped defaults reaches anyone who never rebound.
		if is_default(action):
			continue
		var list : Array = []
		for e in events_for(action):
			list.append(_event_to_dict(e))
		data[action] = list
	var file : FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_bindings() -> void:
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file : FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed : Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	for action in parsed.keys():
		var id : String = str(action)
		if not InputMap.has_action(id):
			continue   # a stale binding for an action that no longer exists
		var list : Variant = parsed[action]
		if not list is Array or list.is_empty():
			continue
		var events : Array = []
		for entry in list:
			var e : InputEventKey = _dict_to_event(entry)
			if e != null:
				events.append(e)
		if events.is_empty():
			continue
		InputMap.action_erase_events(id)
		for e in events:
			InputMap.action_add_event(id, e)
	bindings_changed.emit()

func _event_to_dict(e: InputEventKey) -> Dictionary:
	return {
		"physical_keycode": e.physical_keycode,
		"keycode":          e.keycode,
		"shift":            e.shift_pressed,
		"ctrl":             e.ctrl_pressed,
		"alt":              e.alt_pressed,
		"meta":             e.meta_pressed,
	}

func _dict_to_event(entry: Variant) -> InputEventKey:
	if not entry is Dictionary:
		return null
	var e : InputEventKey = InputEventKey.new()
	e.physical_keycode = int(entry.get("physical_keycode", 0))
	e.keycode          = int(entry.get("keycode", 0))
	if e.physical_keycode == 0 and e.keycode == 0:
		return null
	e.shift_pressed = bool(entry.get("shift", false))
	e.ctrl_pressed  = bool(entry.get("ctrl",  false))
	e.alt_pressed   = bool(entry.get("alt",   false))
	e.meta_pressed  = bool(entry.get("meta",  false))
	return e
