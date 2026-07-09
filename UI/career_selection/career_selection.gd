extends Control
## Lets the player inspect restart paths without starting gameplay systems.

signal career_selected(career: Dictionary)

const CAREERS := {
	"pizza_delivery": {
		"id": "pizza_delivery",
		"title": "Pizza Delivery",
		"category": "Jobs",
		"required_capital": "€0",
		"required_skills": "Basic driving and punctuality",
		"time_commitment": "Evenings and weekends",
		"pros": "Fast start, flexible shifts, low risk",
		"cons": "Limited growth, fuel costs, weather exposure",
	},
	"supermarket": {
		"id": "supermarket",
		"title": "Supermarket",
		"category": "Jobs",
		"required_capital": "€0",
		"required_skills": "Customer service and reliability",
		"time_commitment": "Fixed daily shifts",
		"pros": "Stable routine, predictable work, low risk",
		"cons": "Low upside, repetitive tasks, fixed schedule",
	},
	"garbage_collector": {
		"id": "garbage_collector",
		"title": "Garbage Collector",
		"category": "Jobs",
		"required_capital": "€0",
		"required_skills": "Physical stamina and consistency",
		"time_commitment": "Early mornings",
		"pros": "Reliable work, clear schedule, no capital needed",
		"cons": "Physically demanding, limited flexibility, early starts",
	},
	"lemonade_stand": {
		"id": "lemonade_stand",
		"title": "Lemonade Stand",
		"category": "Businesses",
		"required_capital": "€500",
		"required_skills": "Basic sales and simple operations",
		"time_commitment": "Part-time setup and daily selling",
		"pros": "Low entry cost, simple operation, room to learn",
		"cons": "Small scale, weather dependent, inconsistent demand",
	},
	"pizzeria": {
		"id": "pizzeria",
		"title": "Pizzeria",
		"category": "Businesses",
		"required_capital": "€10,000",
		"required_skills": "Food service, hiring, and operations",
		"time_commitment": "Full-time management",
		"pros": "High growth potential, strong local demand, scalable",
		"cons": "High capital risk, complex operations, long hours",
	},
}

@onready var _pizza_delivery_button: Button = %PizzaDeliveryButton
@onready var _supermarket_button: Button = %SupermarketButton
@onready var _garbage_collector_button: Button = %GarbageCollectorButton
@onready var _lemonade_stand_button: Button = %LemonadeStandButton
@onready var _pizzeria_button: Button = %PizzeriaButton


func _ready() -> void:
	_pizza_delivery_button.pressed.connect(_on_career_pressed.bind("pizza_delivery"))
	_supermarket_button.pressed.connect(_on_career_pressed.bind("supermarket"))
	_garbage_collector_button.pressed.connect(_on_career_pressed.bind("garbage_collector"))
	_lemonade_stand_button.pressed.connect(_on_career_pressed.bind("lemonade_stand"))
	_pizzeria_button.pressed.connect(_on_career_pressed.bind("pizzeria"))


func _on_career_pressed(career_id: String) -> void:
	var career: Dictionary = CAREERS[career_id].duplicate()
	career["id"] = career_id
	career_selected.emit(career)
