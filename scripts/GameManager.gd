extends Node

const DAY_NAMES := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

func day_name() -> String:
	return DAY_NAMES[(day - 1) % DAY_NAMES.size()]

# Global game state
var cash: int = 0
var packages: int = 0
var day: int = 1
var day_cash: int = 0   # earnings this day only (used for end-of-day bonus)
var total_targets: int = 0
var delivered_count: int = 0
var home_id: String = ""
var mortgage: int = 0
var easy_bike: bool = false

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

func save_game() -> void:
	var data : Dictionary = {
		"cash":     cash,
		"day":      day,
		"home_id":  home_id,
		"mortgage": mortgage,
	}
	var file : FileAccess = FileAccess.open("user://save.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_game() -> bool:
	if not FileAccess.file_exists("user://save.json"):
		return false
	var file : FileAccess = FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		return false
	var text : String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		return false
	cash     = int(parsed.get("cash",     0))
	day      = int(parsed.get("day",      1))
	home_id  = str(parsed.get("home_id",  ""))
	mortgage = int(parsed.get("mortgage", 0))
	cash_changed.emit(cash)
	day_changed.emit(day)
	return true

func reset() -> void:
	cash = 0
	packages = 0
	day = 1
	day_cash = 0
	total_targets = 0
	delivered_count = 0
	home_id  = ""
	mortgage = 0
