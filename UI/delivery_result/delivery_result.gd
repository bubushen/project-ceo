extends Control
## Shows the summary for a completed delivery route.

@onready var _orders_delivered_label: Label = %OrdersDeliveredValue
@onready var _base_pay_label: Label = %BasePayValue
@onready var _tip_total_label: Label = %TipTotalValue
@onready var _total_earned_label: Label = %TotalEarnedValue
@onready var _route_time_label: Label = %RouteTimeValue
@onready var _satisfaction_label: Label = %SatisfactionValue


func show_result(result: Dictionary) -> void:
	_orders_delivered_label.text = str(int(result.get("orders_delivered", 0)))
	_base_pay_label.text = _format_cash(int(result.get("base_pay_total", 0)))
	_tip_total_label.text = _format_cash(int(result.get("tip_total", 0)))
	_total_earned_label.text = _format_cash(int(result.get("total_earned", 0)))
	_route_time_label.text = "%.1f minutes" % float(result.get("route_time", 0.0))
	_satisfaction_label.text = str(result.get("customer_satisfaction", "Bad"))


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
