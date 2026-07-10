extends Node

var _selected_career: Dictionary

@onready var _opening_screen = %OpeningScreen
@onready var _career_selection = %CareerSelection
@onready var _career_details = %CareerDetails
@onready var _pizza_delivery = %PizzaDelivery
@onready var _city_map = %CityMap
@onready var _delivery_result = %DeliveryResult
@onready var _dashboard = %Dashboard


func _ready() -> void:
	_career_selection.hide()
	_career_details.hide()
	_pizza_delivery.hide()
	_city_map.hide()
	_delivery_result.hide()
	_dashboard.hide()
	_dashboard.set_work_available(false)
	_opening_screen.completed.connect(_on_opening_screen_completed)
	_career_selection.career_selected.connect(_on_career_selected)
	_career_details.confirmed.connect(_on_career_confirmed)
	_pizza_delivery.shift_started.connect(_on_pizza_delivery_shift_started)
	_city_map.delivery_completed.connect(_on_delivery_completed)
	_delivery_result.next_shift_requested.connect(_on_next_shift_requested)
	_delivery_result.dashboard_requested.connect(_on_dashboard_requested)
	_dashboard.work_requested.connect(_on_dashboard_work_requested)


func _on_opening_screen_completed() -> void:
	_opening_screen.hide()
	_career_selection.show()


func _on_career_selected(career: Dictionary) -> void:
	_selected_career = career
	_career_selection.hide()
	_career_details.show_career(career)
	_career_details.show()


func _on_career_confirmed() -> void:
	_career_details.hide()
	_dashboard.set_work_available(not _selected_career.is_empty())
	if _selected_career.get("id", "") == "pizza_delivery":
		_pizza_delivery.prepare()
		_pizza_delivery.show()
		return

	_dashboard.show()


func _on_pizza_delivery_shift_started(selected_orders: Array) -> void:
	_pizza_delivery.hide()
	_city_map.show_orders(selected_orders)
	_city_map.show()


func _on_delivery_completed(result: Dictionary) -> void:
	_city_map.hide()
	_delivery_result.show_result(result)
	_delivery_result.show()


func _on_next_shift_requested() -> void:
	_delivery_result.hide()
	_pizza_delivery.prepare()
	_pizza_delivery.show()


func _on_dashboard_requested() -> void:
	_delivery_result.hide()
	_dashboard.set_work_available(not _selected_career.is_empty())
	_dashboard.show()


func _on_dashboard_work_requested() -> void:
	if _selected_career.get("id", "") != "pizza_delivery" or not Player.can_work_shift():
		return

	_dashboard.hide()
	_pizza_delivery.prepare()
	_pizza_delivery.show()
