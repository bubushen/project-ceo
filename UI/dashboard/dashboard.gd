extends Control
## Minimal clock dashboard. Communicates only with SimulationTime.

@onready var _day_label: Label = %DayValue
@onready var _month_label: Label = %MonthValue
@onready var _year_label: Label = %YearValue
@onready var _play_button: Button = %PlayButton
@onready var _pause_button: Button = %PauseButton
@onready var _speed_x1_button: Button = %SpeedX1
@onready var _speed_x2_button: Button = %SpeedX2
@onready var _speed_x5_button: Button = %SpeedX5


func _ready() -> void:
	_connect_simulation_time()
	_refresh_date()
	_refresh_controls()


func _connect_simulation_time() -> void:
	SimulationTime.day_advanced.connect(_on_day_advanced)
	SimulationTime.month_advanced.connect(_on_month_advanced)
	SimulationTime.simulation_paused.connect(_on_pause_changed)

	_play_button.pressed.connect(_on_play_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_speed_x1_button.pressed.connect(_on_speed_pressed.bind(SimulationTime.Speed.X1))
	_speed_x2_button.pressed.connect(_on_speed_pressed.bind(SimulationTime.Speed.X2))
	_speed_x5_button.pressed.connect(_on_speed_pressed.bind(SimulationTime.Speed.X5))


func _on_day_advanced(_day: int, _month: int, _year: int) -> void:
	# Deferred so labels read the calendar after SimulationTime increments.
	call_deferred("_refresh_date")


func _on_month_advanced(_month: int, _year: int) -> void:
	call_deferred("_refresh_date")


func _on_pause_changed(_is_paused: bool) -> void:
	_refresh_controls()


func _on_play_pressed() -> void:
	if not SimulationTime.is_running():
		SimulationTime.start()
	SimulationTime.set_paused(false)


func _on_pause_pressed() -> void:
	SimulationTime.set_paused(true)


func _on_speed_pressed(speed: SimulationTime.Speed) -> void:
	SimulationTime.set_speed(speed)
	_refresh_controls()


func _refresh_date() -> void:
	_day_label.text = str(SimulationTime.day)
	_month_label.text = str(SimulationTime.month)
	_year_label.text = str(SimulationTime.year)


func _refresh_controls() -> void:
	var is_paused := SimulationTime.is_paused()
	_play_button.disabled = not is_paused
	_pause_button.disabled = is_paused

	var speed := SimulationTime.get_speed()
	_speed_x1_button.disabled = speed == SimulationTime.Speed.X1
	_speed_x2_button.disabled = speed == SimulationTime.Speed.X2
	_speed_x5_button.disabled = speed == SimulationTime.Speed.X5
