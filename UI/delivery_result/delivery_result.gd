extends Control
## Shows the summary for a completed delivery route.

signal next_shift_requested
signal dashboard_requested

@onready var _orders_delivered_label: Label = %OrdersDeliveredValue
@onready var _base_pay_label: Label = %BasePayValue
@onready var _tip_total_label: Label = %TipTotalValue
@onready var _total_earned_label: Label = %TotalEarnedValue
@onready var _route_time_label: Label = %RouteTimeValue
@onready var _satisfaction_label: Label = %SatisfactionValue
@onready var _next_shift_button: Button = %NextShiftButton
@onready var _dashboard_button: Button = %DashboardButton


func _ready() -> void:
	Player.changed.connect(_on_player_changed)
	_next_shift_button.pressed.connect(_on_next_shift_pressed)
	_dashboard_button.pressed.connect(_on_dashboard_pressed)


func show_result(result: Dictionary) -> void:
	_orders_delivered_label.text = str(int(result.get("orders_delivered", 0)))
	_base_pay_label.text = _format_cash(int(result.get("base_pay_total", 0)))
	_tip_total_label.text = _format_cash(int(result.get("tip_total", 0)))
	_total_earned_label.text = _format_cash(int(result.get("total_earned", 0)))
	_route_time_label.text = "%.1f minutes" % float(result.get("route_time", 0.0))
	_satisfaction_label.text = str(result.get("customer_satisfaction", "Bad"))
	_refresh_next_shift_button()


func _format_cash(value: int) -> String:
	var sign_text := ""
	if value < 0:
		sign_text = "-"

	var digits := str(abs(value))
	var groups := ""
	while digits.length() > 3:
		groups = "," + digits.substr(digits.length() - 3, 3) + groups
		digits = digits.substr(0, digits.length() - 3)

	return "€%s%s%s" % [sign_text, digits, groups]


func _on_next_shift_pressed() -> void:
	if not Player.can_work_shift():
		return

	next_shift_requested.emit()


func _on_dashboard_pressed() -> void:
	dashboard_requested.emit()


func _on_player_changed() -> void:
	_refresh_next_shift_button()


func _refresh_next_shift_button() -> void:
	_next_shift_button.disabled = not Player.can_work_shift()
