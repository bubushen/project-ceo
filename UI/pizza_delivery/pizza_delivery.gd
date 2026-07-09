extends Control
## Preparation screen for Pizza Delivery. Generates display-only orders.

signal shift_started(selected_orders: Array)

const DISTRICTS := [
	"City Center",
	"Station",
	"University",
	"Industrial Area",
	"Suburbs",
]
const MAX_SELECTED_ORDERS := 3

@onready var _day_label: Label = %DayValue
@onready var _cash_label: Label = %CashValue
@onready var _energy_label: Label = %EnergyValue
@onready var _skill_label: Label = %SkillValue
@onready var _selected_orders_label: Label = %SelectedOrdersValue
@onready var _orders_list: VBoxContainer = %OrdersList
@onready var _start_shift_button: Button = %StartShiftButton

var _random := RandomNumberGenerator.new()
var _selected_order_count := 0


func _ready() -> void:
	_random.randomize()
	_start_shift_button.disabled = true
	_start_shift_button.pressed.connect(_on_start_shift_pressed)


func prepare() -> void:
	_selected_order_count = 0
	_refresh_status()
	_generate_orders()
	_refresh_selection_state()


func _refresh_status() -> void:
	_day_label.text = str(SimulationTime.day)
	_cash_label.text = _format_cash(Player.cash)
	_energy_label.text = "100%"
	_skill_label.text = "Beginner"


func _generate_orders() -> void:
	for child in _orders_list.get_children():
		child.queue_free()

	var order_count := _random.randi_range(3, 5)
	for index in range(order_count):
		_orders_list.add_child(_create_order_row(index + 1))


func _create_order_row(order_number: int) -> VBoxContainer:
	var order_row := VBoxContainer.new()
	order_row.add_theme_constant_override("separation", 4)

	var selector := CheckBox.new()
	selector.text = "Order %d" % order_number
	selector.add_theme_font_size_override("font_size", 18)
	selector.toggled.connect(_on_order_toggled.bind(selector))
	order_row.add_child(selector)

	var district := _random_district()
	var potential_tip := _random.randi_range(2, 12)
	var max_delivery_time := _random.randi_range(15, 35)
	var order := {
		"number": order_number,
		"district": district,
		"potential_tip": potential_tip,
		"max_delivery_time": max_delivery_time,
	}

	var details := Label.new()
	details.text = "District: %s\nPotential tip: %s\nMaximum delivery time: %d minutes" % [
		district,
		_format_cash(potential_tip),
		max_delivery_time,
	]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_row.add_child(details)
	selector.set_meta("order", order)

	return order_row


func _on_order_toggled(is_selected: bool, selector: CheckBox) -> void:
	if is_selected and _selected_order_count >= MAX_SELECTED_ORDERS:
		selector.set_pressed_no_signal(false)
		return

	if is_selected:
		_selected_order_count += 1
	else:
		_selected_order_count -= 1

	_refresh_selection_state()


func _refresh_selection_state() -> void:
	_selected_orders_label.text = "Selected orders: %d / %d" % [
		_selected_order_count,
		MAX_SELECTED_ORDERS,
	]
	_start_shift_button.disabled = _selected_order_count == 0


func _on_start_shift_pressed() -> void:
	if _selected_order_count == 0:
		return

	shift_started.emit(_get_selected_orders())


func _get_selected_orders() -> Array:
	var selected_orders := []
	for order_row in _orders_list.get_children():
		var selector := order_row.get_child(0) as CheckBox
		if selector != null and selector.button_pressed:
			selected_orders.append(selector.get_meta("order"))

	return selected_orders


func _random_district() -> String:
	var district_index := _random.randi_range(0, DISTRICTS.size() - 1)
	return str(DISTRICTS[district_index])


func _format_cash(value: int) -> String:
	var sign := ""
	if value < 0:
		sign = "-"

	var digits := str(abs(value))
	var groups := ""
	while digits.length() > 3:
		groups = "," + digits.substr(digits.length() - 3, 3) + groups
		digits = digits.substr(0, digits.length() - 3)

	return "€%s%s%s" % [sign, digits, groups]
