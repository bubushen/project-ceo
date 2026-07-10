extends Control
## Handles simple paid shifts for jobs that do not have a minigame yet.

signal dashboard_requested

const JOB_VALUES := {
	"supermarket": {
		"pay": 55,
		"energy_cost": 20,
	},
	"garbage_collector": {
		"pay": 70,
		"energy_cost": 35,
	},
}

@onready var _job_name_label: Label = %JobNameValue
@onready var _energy_label: Label = %EnergyValue
@onready var _pay_label: Label = %PayValue
@onready var _energy_cost_label: Label = %EnergyCostValue
@onready var _result_label: Label = %ResultLabel
@onready var _start_shift_button: Button = %StartShiftButton
@onready var _dashboard_button: Button = %DashboardButton

var _job_id := ""
var _job_name := ""
var _pay := 0
var _energy_cost := 0


func _ready() -> void:
	Player.changed.connect(_on_player_changed)
	_start_shift_button.pressed.connect(_on_start_shift_pressed)
	_dashboard_button.pressed.connect(_on_dashboard_pressed)


func show_job(career: Dictionary) -> void:
	_job_id = str(career.get("id", ""))
	_job_name = str(career.get("title", "Job"))
	var job_values: Dictionary = JOB_VALUES.get(_job_id, {}) as Dictionary
	_pay = int(job_values.get("pay", 0))
	_energy_cost = int(job_values.get("energy_cost", 0))
	_result_label.text = ""
	_refresh()


func _on_start_shift_pressed() -> void:
	if not _has_enough_energy():
		_result_label.text = "Not enough energy"
		_refresh()
		return

	Player.add_cash(_pay)
	Player.consume_energy(_energy_cost)
	_result_label.text = "Shift completed\nEarned: %s" % _format_cash(_pay)
	_refresh()


func _on_dashboard_pressed() -> void:
	dashboard_requested.emit()


func _on_player_changed() -> void:
	_refresh()


func _refresh() -> void:
	_job_name_label.text = _job_name
	_energy_label.text = "%d / %d" % [Player.energy, Player.max_energy]
	_pay_label.text = _format_cash(_pay)
	_energy_cost_label.text = str(_energy_cost)
	_start_shift_button.disabled = not _has_enough_energy()
	if not _has_enough_energy() and _result_label.text == "":
		_result_label.text = "Not enough energy"


func _has_enough_energy() -> bool:
	return Player.energy >= _energy_cost


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
