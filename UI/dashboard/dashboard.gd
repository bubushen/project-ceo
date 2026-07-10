extends Control
## Minimal player dashboard for the first playable slice.

@onready var _day_label: Label = %DayValue
@onready var _month_label: Label = %MonthValue
@onready var _year_label: Label = %YearValue
@onready var _cash_label: Label = %CashValue
@onready var _house_label: Label = %HouseValue
@onready var _car_label: Label = %CarValue
@onready var _next_day_button: Button = %NextDayButton


func _ready() -> void:
	_connect_signals()
	_refresh_date()
	_refresh_player()


func _connect_signals() -> void:
	SimulationTime.day_advanced.connect(_on_day_advanced)
	SimulationTime.month_advanced.connect(_on_month_advanced)
	Player.changed.connect(_on_player_changed)
	_next_day_button.pressed.connect(_on_next_day_pressed)


func _on_day_advanced(_day: int, _month: int, _year: int) -> void:
	# Deferred so labels read the calendar after SimulationTime increments.
	call_deferred("_refresh_date")


func _on_month_advanced(_month: int, _year: int) -> void:
	call_deferred("_refresh_date")


func _on_player_changed() -> void:
	_refresh_player()


func _on_next_day_pressed() -> void:
	SimulationTime.advance_day()


func _refresh_date() -> void:
	_day_label.text = str(SimulationTime.day)
	_month_label.text = str(SimulationTime.month)
	_year_label.text = str(SimulationTime.year)


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
