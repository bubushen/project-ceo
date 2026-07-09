extends Node
## Owns player state and applies daily living costs.

signal changed

const FOOD_COST_PER_DAY := 8
const UTILITIES_COST_PER_DAY := 4
const FUEL_COST_PER_DAY := 6

var cash: int = 20000
var owns_house: bool = true
var owns_car: bool = true


func _ready() -> void:
	SimulationTime.day_advanced.connect(_on_day_advanced)


func sell_car() -> void:
	if not owns_car:
		return

	owns_car = false
	cash += 15000
	changed.emit()


func mortgage_house() -> void:
	if not owns_house:
		return

	owns_house = false
	cash += 50000
	changed.emit()


func add_cash(amount: int) -> void:
	cash += amount
	changed.emit()


func _on_day_advanced(_day: int, _month: int, _year: int) -> void:
	var daily_cost := FOOD_COST_PER_DAY + UTILITIES_COST_PER_DAY
	if owns_car:
		daily_cost += FUEL_COST_PER_DAY

	cash -= daily_cost
	changed.emit()
