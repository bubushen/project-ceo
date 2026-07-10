extends Control
## Opening choice screen for the first life setback.

signal completed

@onready var _cash_label: Label = %CashValue
@onready var _house_label: Label = %HouseValue
@onready var _car_label: Label = %CarValue
@onready var _keep_everything_button: Button = %KeepEverythingButton
@onready var _sell_car_button: Button = %SellCarButton
@onready var _mortgage_house_button: Button = %MortgageHouseButton


func _ready() -> void:
	_refresh_player()
	_keep_everything_button.pressed.connect(_on_keep_everything_pressed)
	_sell_car_button.pressed.connect(_on_sell_car_pressed)
	_mortgage_house_button.pressed.connect(_on_mortgage_house_pressed)


func _on_keep_everything_pressed() -> void:
	completed.emit()


func _on_sell_car_pressed() -> void:
	Player.sell_car()
	completed.emit()


func _on_mortgage_house_pressed() -> void:
	Player.mortgage_house()
	completed.emit()


func _refresh_player() -> void:
	_cash_label.text = _format_cash(Player.cash)
	_house_label.text = _format_bool(Player.owns_house)
	_car_label.text = _format_bool(Player.owns_car)


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


func _format_bool(value: bool) -> String:
	if value:
		return "Yes"
	return "No"
