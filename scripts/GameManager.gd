extends Node

# Global game state
var cash: int = 0
var packages: int = 0
var day: int = 1
var day_cash: int = 0   # earnings this day only (used for end-of-day bonus)
var total_targets: int = 0
var delivered_count: int = 0

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
	if delivered_count >= total_targets:
		all_delivered.emit()

func start_new_day(target_count: int) -> void:
	day += 1
	day_cash = 0
	delivered_count = 0
	total_targets = target_count
	set_packages(target_count)
	day_changed.emit(day)

func reset() -> void:
	cash = 0
	packages = 0
	day = 1
	day_cash = 0
	total_targets = 0
	delivered_count = 0
