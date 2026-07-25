extends Node

const DAY_NAMES := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

func day_name() -> String:
	return DAY_NAMES[(day - 1) % DAY_NAMES.size()]

func weekday_abbrev() -> String:    # "Mon"
	return DAY_NAMES[(day - 1) % DAY_NAMES.size()].substr(0, 3)

# ── Calendar (derived from the absolute `day` counter) ─────
func calendar_date() -> Dictionary:
	return Calendar.date_for_day(day)

func season() -> int:
	return Calendar.date_for_day(day).season

func date_label() -> String:        # "Year 1, Fall 9"
	return Calendar.format_long(day)

func date_label_short() -> String:  # "Fall 9 · Yr 1"
	return Calendar.format_short(day)

func date_label_hud() -> String:    # "Mon, Winter 12"
	var d : Dictionary = Calendar.date_for_day(day)
	return "%s, %s %d" % [weekday_abbrev(), Calendar.SEASON_NAMES[d.season], d.day]

# Global game state
var cash: int = 0
var packages: int = 0
var day: int = 1
var day_cash: int = 0   # earnings this day only (used for end-of-day bonus)
var total_targets: int = 0
var delivered_count: int = 0
var home_id: String = ""
var mortgage: int = 0
var easy_bike             : bool = false
var snap_to_direction     : bool = true
var max_drops_per_day     : int  = 4
var max_packages_per_drop : int  = 3

const SAVE_SLOT_COUNT : int = 5
var current_slot      : int = -1   # which slot autosaves write to; -1 = none chosen yet

# Monotonic in-game seconds, advanced by Main only during active play (frozen
# while paused). Used to time deliveries from pad-landing to drop-off.
var play_clock : float = 0.0

# Delivery speed bonus: a package delivered within FAST seconds of landing pays
# the full MAX multiplier; by SLOW seconds it decays to MIN (never below base).
const DELIVERY_FAST_TIME : float = 25.0
const DELIVERY_SLOW_TIME : float = 120.0
const DELIVERY_MAX_MULT  : float = 2.0
const DELIVERY_MIN_MULT  : float = 1.0

## Scale a base payout by how fast the package got delivered after landing.
func delivery_payout(base_earned: int, landing_time: float) -> int:
	return int(round(base_earned * _delivery_mult(landing_time)))

## Short flavour tag for the delivery message, based on speed.
func delivery_speed_tag(landing_time: float) -> String:
	var mult : float = _delivery_mult(landing_time)
	if mult >= DELIVERY_MAX_MULT - 0.01:
		return " ⚡ Speedy bonus!"
	if mult > DELIVERY_MIN_MULT + 0.01:
		return " ⏱ Quick!"
	return ""

func _delivery_mult(landing_time: float) -> float:
	var elapsed : float = maxf(play_clock - landing_time, 0.0)
	var t       : float = clampf(
		(elapsed - DELIVERY_FAST_TIME) / (DELIVERY_SLOW_TIME - DELIVERY_FAST_TIME),
		0.0, 1.0)
	return lerpf(DELIVERY_MAX_MULT, DELIVERY_MIN_MULT, t)

signal cash_changed(new_cash: int)
signal packages_changed(new_packages: int)
signal day_changed(new_day: int)
signal delivery_made(cash_earned: int)
signal all_delivered()
signal message_requested(text: String, duration: float)

func show_message(text: String, duration: float = 2.5) -> void:
	message_requested.emit(text, duration)

func add_cash(amount: int) -> void:
	cash += amount
	day_cash += amount
	cash_changed.emit(cash)

func use_package() -> bool:
	if packages <= 0:
		return false
	packages -= 1
	packages_changed.emit(packages)
	return true

func set_packages(count: int) -> void:
	packages = count
	packages_changed.emit(packages)

func on_delivery_complete(earned: int) -> void:
	delivered_count += 1
	add_cash(earned)
	delivery_made.emit(earned)
	if total_targets > 0 and delivered_count >= total_targets:
		all_delivered.emit()

func start_new_day(target_count: int) -> void:
	day += 1
	day_cash = 0
	delivered_count = 0
	total_targets = target_count
	set_packages(target_count)
	day_changed.emit(day)

func add_packages(count: int) -> void:
	packages += count
	packages_changed.emit(packages)

func add_targets(count: int) -> void:
	total_targets += count

func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

## Reads a slot without loading it into live game state — used by the save
## slot picker UI to show "Slot N — Day X · $Y · <timestamp>" or "Empty".
func get_slot_info(slot: int) -> Dictionary:
	var path : String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var file : FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false}
	var parsed : Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"exists": false}
	return {
		"exists":    true,
		"slot_name": str(parsed.get("slot_name", "Slot %d" % slot)),
		"day":       int(parsed.get("day",       1)),
		"cash":      int(parsed.get("cash",      0)),
		"timestamp": int(parsed.get("timestamp", 0)),
	}

## Writes to `slot` (or current_slot if omitted) and remembers it so later
## autosaves (e.g. day rollover) keep landing in the same slot.
func save_game(slot: int = -1) -> void:
	if slot == -1:
		slot = current_slot
	if slot == -1:
		return
	current_slot = slot
	var existing   : Dictionary = get_slot_info(slot)
	var slot_name  : String     = str(existing.get("slot_name", "Slot %d" % slot)) \
			if existing.get("exists", false) else "Slot %d" % slot
	var data : Dictionary = {
		"slot_name": slot_name,
		"timestamp": Time.get_unix_time_from_system(),
		"cash":      cash,
		"day":       day,
		"home_id":   home_id,
		"mortgage":  mortgage,
	}
	var file : FileAccess = FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_game(slot: int) -> bool:
	var path : String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file : FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed : Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	current_slot = slot
	cash     = int(parsed.get("cash",     0))
	day      = int(parsed.get("day",      1))
	home_id  = str(parsed.get("home_id",  ""))
	mortgage = int(parsed.get("mortgage", 0))
	cash_changed.emit(cash)
	day_changed.emit(day)
	return true

## Settings (control scheme, drop tuning) are global user prefs, independent
## of any save slot, so they live in their own file.
func save_settings() -> void:
	var data : Dictionary = {
		"easy_bike":             easy_bike,
		"snap_to_direction":     snap_to_direction,
		"max_drops_per_day":     max_drops_per_day,
		"max_packages_per_drop": max_packages_per_drop,
	}
	var file : FileAccess = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var file : FileAccess = FileAccess.open("user://settings.json", FileAccess.READ)
	if file == null:
		return
	var parsed : Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	easy_bike             = bool(parsed.get("easy_bike",            false))
	snap_to_direction     = bool(parsed.get("snap_to_direction",    true))
	max_drops_per_day     = int(parsed.get("max_drops_per_day",     4))
	max_packages_per_drop = int(parsed.get("max_packages_per_drop", 3))

func reset() -> void:
	cash = 0
	packages = 0
	day = 1
	day_cash = 0
	total_targets = 0
	delivered_count = 0
	home_id  = ""
	mortgage = 0
	current_slot = -1
