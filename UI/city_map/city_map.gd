extends Control
## Native visual city map with route-building overlays.

signal delivery_completed(result: Dictionary)

const GRID_COLUMNS := 10
const GRID_ROWS := 10
const GRID_ORIGIN := Vector2(24, 36)
const GRID_SPACING := Vector2(29, 34)
const PIZZERIA_POSITION := Vector2(52, 70)
const START_NODE_ID := "Node 2-2"
const BASE_PAY_PER_ORDER := 6
const BASE_SEGMENT_TIME := 4.0
const TRAFFIC_LOW_MULTIPLIER := 1.0
const TRAFFIC_MEDIUM_MULTIPLIER := 1.5
const TRAFFIC_HIGH_MULTIPLIER := 2.0

const TRAFFIC_LOW := Color(0.12, 0.75, 0.26, 1.0)
const TRAFFIC_MEDIUM := Color(0.95, 0.78, 0.16, 1.0)
const TRAFFIC_HIGH := Color(0.9, 0.18, 0.14, 1.0)
const NODE_NORMAL := Color.WHITE
const NODE_SELECTED := Color(0.35, 0.75, 1.0, 1.0)
const NODE_AVAILABLE := Color(0.45, 1.0, 0.55, 1.0)
const NODE_FADED := Color(0.55, 0.55, 0.55, 0.75)

const CUSTOMER_LOCATIONS := {
	"City Center": Vector2(140, 110),
	"Station": Vector2(54, 210),
	"University": Vector2(226, 176),
	"Industrial Area": Vector2(226, 310),
	"Suburbs": Vector2(82, 344),
}

@onready var _road_layer: Control = %RoadLayer
@onready var _route_line: Line2D = %RouteLine
@onready var _node_layer: Control = %NodeLayer
@onready var _order_marker_layer: Control = %OrderMarkerLayer
@onready var _route_label: Label = %RouteValue
@onready var _clear_route_button: Button = %ClearRouteButton
@onready var _confirm_route_button: Button = %ConfirmRouteButton

var _node_buttons: Dictionary = {}
var _node_positions: Dictionary = {}
var _node_adjacency: Dictionary = {}
var _node_traffic_multipliers: Dictionary = {}
var _selected_orders: Array = []
var _selected_route_nodes: Array[String] = []


func _ready() -> void:
	_build_road_network()
	_build_node_grid()
	_clear_route_button.pressed.connect(_on_clear_route_pressed)
	_confirm_route_button.pressed.connect(_on_confirm_route_pressed)
	_refresh_route_display()
	_refresh_route_controls()
	_refresh_node_highlights()


func show_orders(selected_orders: Array) -> void:
	_selected_orders = selected_orders.duplicate()
	_clear_order_markers()
	_clear_route()

	var district_counts: Dictionary = {}
	for order in selected_orders:
		if order is Dictionary:
			var order_data: Dictionary = order as Dictionary
			_add_order_marker(order_data, district_counts)


func _build_road_network() -> void:
	for y in range(GRID_ROWS):
		for x in range(GRID_COLUMNS - 1):
			if _has_horizontal_road(x, y):
				var horizontal_traffic := _traffic_color(x, y)
				_add_road_segment(_node_position(x, y), _node_position(x + 1, y), horizontal_traffic)
				_add_road_connection(_node_id(x, y), _node_id(x + 1, y), _traffic_multiplier(horizontal_traffic))

	for y in range(GRID_ROWS - 1):
		for x in range(GRID_COLUMNS):
			if _has_vertical_road(x, y):
				var vertical_traffic := _traffic_color(x, y)
				_add_road_segment(_node_position(x, y), _node_position(x, y + 1), vertical_traffic)
				_add_road_connection(_node_id(x, y), _node_id(x, y + 1), _traffic_multiplier(vertical_traffic))


func _build_node_grid() -> void:
	for y in range(GRID_ROWS):
		for x in range(GRID_COLUMNS):
			var node_id := _node_id(x, y)
			var button := Button.new()
			button.text = ""
			button.size = Vector2(18, 18)
			button.custom_minimum_size = Vector2(18, 18)
			button.position = _node_position(x, y) - Vector2(9, 9)
			button.pressed.connect(_on_intersection_pressed.bind(node_id))
			_node_layer.add_child(button)
			_node_buttons[node_id] = button
			_node_positions[node_id] = _node_position(x, y)


func _add_road_segment(start: Vector2, end: Vector2, color: Color) -> void:
	var road := Line2D.new()
	road.points = PackedVector2Array([start, end])
	road.width = 5.0
	road.default_color = color
	_road_layer.add_child(road)


func _add_road_connection(from_node: String, to_node: String, traffic_multiplier: float) -> void:
	if not _node_adjacency.has(from_node):
		_node_adjacency[from_node] = []
	if not _node_adjacency.has(to_node):
		_node_adjacency[to_node] = []

	_node_adjacency[from_node].append(to_node)
	_node_adjacency[to_node].append(from_node)
	_node_traffic_multipliers[_connection_key(from_node, to_node)] = traffic_multiplier


func _has_horizontal_road(x: int, y: int) -> bool:
	if y in [0, 3, 5, 8]:
		return true
	return x in [1, 4, 7] and not (y in [2, 7])


func _has_vertical_road(x: int, y: int) -> bool:
	if x in [1, 4, 7, 9]:
		return true
	return y in [1, 4, 6] and not (x in [0, 8])


func _traffic_color(x: int, y: int) -> Color:
	if x in [7, 8] or y == 5:
		return TRAFFIC_HIGH
	if x in [1, 4] or y in [0, 3]:
		return TRAFFIC_MEDIUM
	return TRAFFIC_LOW


func _traffic_multiplier(traffic_color: Color) -> float:
	if traffic_color == TRAFFIC_HIGH:
		return TRAFFIC_HIGH_MULTIPLIER
	if traffic_color == TRAFFIC_MEDIUM:
		return TRAFFIC_MEDIUM_MULTIPLIER
	return TRAFFIC_LOW_MULTIPLIER


func _connection_key(from_node: String, to_node: String) -> String:
	if from_node < to_node:
		return "%s|%s" % [from_node, to_node]
	return "%s|%s" % [to_node, from_node]


func _node_position(x: int, y: int) -> Vector2:
	return GRID_ORIGIN + Vector2(float(x) * GRID_SPACING.x, float(y) * GRID_SPACING.y)


func _node_id(x: int, y: int) -> String:
	return "Node %d-%d" % [x + 1, y + 1]


func _clear_order_markers() -> void:
	for child in _order_marker_layer.get_children():
		child.queue_free()


func _add_order_marker(order: Dictionary, district_counts: Dictionary) -> void:
	var district := str(order.get("district", ""))
	if not CUSTOMER_LOCATIONS.has(district):
		return

	var marker_count := int(district_counts.get(district, 0))
	district_counts[district] = marker_count + 1

	var marker := Label.new()
	marker.text = "Order %d" % int(order.get("number", 0))
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_font_size_override("font_size", 12)
	marker.custom_minimum_size = Vector2(66, 26)
	var base_position: Vector2 = CUSTOMER_LOCATIONS[district]
	marker.position = base_position + Vector2(marker_count * 18, 0)
	_order_marker_layer.add_child(marker)


func _on_intersection_pressed(node_id: String) -> void:
	if _selected_route_nodes.has(node_id):
		return
	if not _can_select_node(node_id):
		return

	_selected_route_nodes.append(node_id)
	_refresh_node_highlights()
	_refresh_route_display()
	_refresh_route_line()
	_refresh_route_controls()


func _can_select_node(node_id: String) -> bool:
	if _selected_route_nodes.is_empty():
		return node_id == START_NODE_ID

	var previous_node: String = _selected_route_nodes.back()
	var connected_nodes: Array = _node_adjacency.get(previous_node, [])
	return connected_nodes.has(node_id)


func _on_clear_route_pressed() -> void:
	_clear_route()


func _on_confirm_route_pressed() -> void:
	if not _can_confirm_route():
		return

	var result: Dictionary = _calculate_delivery_result()
	Player.add_cash(int(result["total_earned"]))
	Player.consume_shift_energy()
	delivery_completed.emit(result)


func _clear_route() -> void:
	_selected_route_nodes.clear()
	_route_line.clear_points()
	_refresh_route_display()
	_refresh_route_controls()
	_refresh_node_highlights()


func _set_node_state(node_id: String, state_color: Color) -> void:
	var button := _node_buttons[node_id] as Button
	button.modulate = state_color


func _refresh_node_highlights() -> void:
	var valid_next_nodes: Array = _valid_next_nodes()
	for node_id in _node_buttons:
		var node_id_string: String = str(node_id)
		if _selected_route_nodes.has(node_id_string):
			_set_node_state(node_id_string, NODE_SELECTED)
		elif valid_next_nodes.has(node_id_string):
			_set_node_state(node_id_string, NODE_AVAILABLE)
		elif _selected_route_nodes.is_empty():
			_set_node_state(node_id_string, NODE_NORMAL)
		else:
			_set_node_state(node_id_string, NODE_FADED)


func _valid_next_nodes() -> Array:
	if _selected_route_nodes.is_empty():
		return [START_NODE_ID]

	var previous_node: String = _selected_route_nodes.back()
	var connected_nodes: Array = _node_adjacency.get(previous_node, [])
	return connected_nodes


func _refresh_route_line() -> void:
	if _selected_route_nodes.is_empty():
		_route_line.clear_points()
		return

	var points := PackedVector2Array([PIZZERIA_POSITION])
	for node_id in _selected_route_nodes:
		var node_position: Vector2 = _node_positions[node_id]
		points.append(node_position)
	_route_line.points = points


func _refresh_route_display() -> void:
	var route_text := "Route: Pizzeria"
	for node_id in _selected_route_nodes:
		route_text += " -> " + node_id

	_route_label.text = "%s -> Customer\nEstimated time: %.1f minutes" % [
		route_text,
		_calculate_route_time(),
	]


func _refresh_route_controls() -> void:
	_confirm_route_button.disabled = not _can_confirm_route()


func _can_confirm_route() -> bool:
	return _selected_route_nodes.size() >= 2 and not _selected_orders.is_empty() and Player.can_work_shift()


func _calculate_delivery_result() -> Dictionary:
	var route_time := _calculate_route_time()
	var base_pay_total := _selected_orders.size() * BASE_PAY_PER_ORDER
	var tip_total := 0

	for order in _selected_orders:
		if order is Dictionary:
			var order_data: Dictionary = order as Dictionary
			tip_total += _calculate_tip(order_data, route_time)

	var total_earned := base_pay_total + tip_total
	return {
		"orders_delivered": _selected_orders.size(),
		"base_pay_total": base_pay_total,
		"tip_total": tip_total,
		"total_earned": total_earned,
		"route_time": route_time,
		"customer_satisfaction": _customer_satisfaction(route_time),
	}


func _calculate_route_time() -> float:
	var route_time := 0.0
	if _selected_route_nodes.size() <= 1:
		return route_time

	for index in range(_selected_route_nodes.size() - 1):
		var from_node: String = _selected_route_nodes[index]
		var to_node: String = _selected_route_nodes[index + 1]
		var traffic_multiplier := float(_node_traffic_multipliers.get(_connection_key(from_node, to_node), TRAFFIC_LOW_MULTIPLIER))
		route_time += BASE_SEGMENT_TIME * traffic_multiplier

	return route_time


func _calculate_tip(order: Dictionary, route_time: float) -> int:
	var potential_tip := int(order.get("potential_tip", 0))
	var max_delivery_time := float(order.get("max_delivery_time", 0))
	if route_time <= max_delivery_time:
		return potential_tip
	if route_time <= max_delivery_time * 1.25:
		return int(potential_tip / 2)
	return 0


func _customer_satisfaction(route_time: float) -> String:
	if _selected_orders.is_empty():
		return "Bad"

	var on_time_orders := 0
	var late_orders := 0
	for order in _selected_orders:
		if order is Dictionary:
			var order_data: Dictionary = order as Dictionary
			var max_delivery_time := float(order_data.get("max_delivery_time", 0))
			if route_time <= max_delivery_time:
				on_time_orders += 1
			elif route_time <= max_delivery_time * 1.25:
				late_orders += 1

	if on_time_orders == _selected_orders.size():
		return "Great"
	if on_time_orders + late_orders > 0:
		return "Good"
	return "Bad"
