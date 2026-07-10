extends Node
## Advances the in-game calendar and publishes clock events.
##
## SimulationTime is infrastructure only: it does not run gameplay logic.
## Future systems subscribe to [signal day_advanced], [signal month_advanced],
## and [signal simulation_paused]. When EventBus is added, it will relay
## these signals so domain systems never reference this autoload directly.

## Calendar length. Scenario data may override starting date via [method reset].
const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12

## Real seconds for one in-game day at x1 speed. Tune for pacing.
const SECONDS_PER_DAY_AT_X1 := 2.0

enum Speed {
	X1 = 1,
	X2 = 2,
	X5 = 5,
}

## Emitted after the calendar advances to the new in-game day.
## Payload matches ARCHITECTURE.md: day and month (year included for disambiguation).
signal day_advanced(day: int, month: int, year: int)

## Emitted when the calendar enters a new month, after [signal day_advanced] for the last day.
signal month_advanced(month: int, year: int)

## Emitted when pause state changes. Payload: true when simulation is paused.
signal simulation_paused(is_paused: bool)

var day: int = 1
var month: int = 1
var year: int = 1

var _speed: Speed = Speed.X1
var _paused: bool = true
var _running: bool = false
var _day_elapsed: float = 0.0


func _process(delta: float) -> void:
	if not _running or _paused:
		return

	_day_elapsed += delta * float(_speed)
	while _day_elapsed >= SECONDS_PER_DAY_AT_X1:
		_day_elapsed -= SECONDS_PER_DAY_AT_X1
		_advance_day()


## Sets calendar to a starting date and clears the day timer.
## Does not start or unpause the simulation — [method start] and [method set_paused] do that.
func reset(start_day: int = 1, start_month: int = 1, start_year: int = 1) -> void:
	day = start_day
	month = start_month
	year = start_year
	_day_elapsed = 0.0


## Begins processing time. The simulation remains paused until [method set_paused](false).
func start() -> void:
	_running = true


## Stops processing time. Pause state is preserved.
func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


func is_paused() -> bool:
	return _paused


func get_speed() -> Speed:
	return _speed


func set_paused(paused: bool) -> void:
	if _paused == paused:
		return
	_paused = paused
	simulation_paused.emit(_paused)


func toggle_pause() -> void:
	set_paused(not _paused)


func set_speed(speed: Speed) -> void:
	_speed = speed


## Advances the calendar by exactly one in-game day.
func advance_day() -> void:
	_day_elapsed = 0.0
	_advance_day()


func _advance_day() -> void:
	day += 1
	if day > DAYS_PER_MONTH:
		day = 1
		month += 1
		if month > MONTHS_PER_YEAR:
			month = 1
			year += 1

	day_advanced.emit(day, month, year)

	if day != 1:
		return
	month_advanced.emit(month, year)
