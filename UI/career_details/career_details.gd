extends Control
## Displays static career information before returning to the playable dashboard.

signal confirmed

@onready var _title_label: Label = %Title
@onready var _category_label: Label = %CategoryValue
@onready var _capital_label: Label = %CapitalValue
@onready var _skills_label: Label = %SkillsValue
@onready var _time_label: Label = %TimeValue
@onready var _pros_label: Label = %ProsValue
@onready var _cons_label: Label = %ConsValue
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)


func show_career(career: Dictionary) -> void:
	_title_label.text = str(career["title"])
	_category_label.text = str(career["category"])
	_capital_label.text = str(career["required_capital"])
	_skills_label.text = str(career["required_skills"])
	_time_label.text = str(career["time_commitment"])
	_pros_label.text = str(career["pros"])
	_cons_label.text = str(career["cons"])


func _on_confirm_pressed() -> void:
	confirmed.emit()
