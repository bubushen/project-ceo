extends Control
## Native visual city map with route-building overlays.

signal delivery_completed(result: Dictionary)

const GRID_COLUMNS := 8
const GRID_ROWS := 12
const GRID_ORIGIN := Vector2(24, 28)
const GRID_SPACING := Vector2(38, 31)
const PIZZERIA_POSITION := Vector2(62, 59)
const START_NODE_ID := "Node 2-2"
const BASE_PAY_PER_ORDER := 6
const BASE_SEGMENT_TIME := 4.0
const TRAFFIC_LOW_MULTIPLIER := 1.0
const TRAFFIC_MEDIUM_MULTIPLIER := 1.5
const TRAFFIC_HIGH_MULTIPLIER := 2.0

const TRAFFIC_LOW := Color(0.18, 0.62, 0.26, 0.72)
const TRAFFIC_MEDIUM := Color(0.86, 0.7, 0.18, 0.72)
const TRAFFIC_HIGH := Color(0.78, 0.2, 0.16, 0.74)
const NODE_NORMAL := Color(0.03, 0.04, 0.05, 1.0)
const NODE_SELECTED := Color(0.28, 0.88, 1.0, 1.0)
const NODE_AVAILABLE := Color(0.38, 0.86, 0.5, 1.0)
const NODE_START := Color(0.08, 0.38, 1.0, 1.0)
const NODE_OBJECTIVE := Color(1.0, 0.58, 0.02, 1.0)
const NODE_DELIVERED := Color(0.18, 1.0, 0.38, 1.0)
const NODE_FADED := Color(0.05, 0.06, 0.07, 1.0)
const NODE_OUTLINE := Color(0.86, 0.9, 0.92, 1.0)
const NODE_TEXT := Color(0.03, 0.04, 0.05, 1.0)
const NODE_START_OUTLINE := Color(0.72, 0.9, 1.0, 1.0)
const NODE_OBJECTIVE_OUTLINE := Color(1.0, 0.96, 0.45, 1.0)
const NORMAL_NODE_SIZE := Vector2(13, 13)
const AVAILABLE_NODE_SIZE := Vector2(18, 18)
const SELECTED_NODE_SIZE := Vector2(20, 20)
const START_NODE_SIZE := Vector2(28, 28)
const OBJECTIVE_NODE_SIZE := Vector2(30, 30)
const DELIVERED_NODE_SIZE := Vector2(28, 28)

const CUSTOMER_DELIVERY_NODES := {
	"City Center": "Node 4-4",
	"Station": "Node 2-7",
	"University": "Node 6-6",
	"Industrial Area": "Node 5-10",
	"Suburbs": "Node 2-11",
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
			button.flat = true
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_apply_node_visual(button, _node_position(x, y), NORMAL_NODE_SIZE, NODE_NORMAL, 0)
			button.pressed.connect(_on_intersection_pressed.bind(node_id))
			_node_layer.add_child(button)
			_node_buttons[node_id] = button
			_node_positions[node_id] = _node_position(x, y)


func _add_road_segment(start: Vector2, end: Vector2, color: Color) -> void:
	var road := Line2D.new()
	road.points = PackedVector2Array([start, end])
	road.width = 4.0
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
	if y in [0, 3, 5, 8, 10]:
		return true
	return x in [1, 4, 6] and not (y in [2, 7, 11])


func _has_vertical_road(x: int, y: int) -> bool:
	if x in [1, 4, 7]:
		return true
	return y in [1, 4, 6, 9] and x != 0


func _traffic_color(x: int, y: int) -> Color:
	if x == 7 or y in [5, 8]:
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
		_order_marker_layer.remove_child(child)
		child.queue_free()


func _refresh_order_markers() -> void:
	_clear_order_markers()


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


func _set_node_state(
	node_id: String,
	state_color: Color,
	node_size: Vector2,
	z_index: int,
	label_text := "",
	border_width := 2,
	border_color := NODE_OUTLINE
) -> void:
	var button := _node_buttons[node_id] as Button
	button.text = label_text
	_apply_node_visual(button, _node_positions[node_id], node_size, state_color, z_index, border_width, border_color)


func _apply_node_visual(
	button: Button,
	center_position: Vector2,
	node_size: Vector2,
	fill_color: Color,
	node_z_index: int,
	border_width := 2,
	border_color := NODE_OUTLINE
) -> void:
	button.size = node_size
	button.custom_minimum_size = node_size
	button.position = center_position - node_size * 0.5
	button.z_index = node_z_index

	var node_style := StyleBoxFlat.new()
	node_style.bg_color = fill_color
	node_style.border_color = border_color
	node_style.border_width_left = border_width
	node_style.border_width_top = border_width
	node_style.border_width_right = border_width
	node_style.border_width_bottom = border_width
	var corner_radius := int(node_size.x * 0.5)
	node_style.corner_radius_top_left = corner_radius
	node_style.corner_radius_top_right = corner_radius
	node_style.corner_radius_bottom_right = corner_radius
	node_style.corner_radius_bottom_left = corner_radius
	button.add_theme_stylebox_override("normal", node_style)
	button.add_theme_stylebox_override("hover", node_style)
	button.add_theme_stylebox_override("pressed", node_style)
	button.add_theme_stylebox_override("disabled", node_style)
	button.add_theme_color_override("font_color", NODE_TEXT)
	button.add_theme_color_override("font_hover_color", NODE_TEXT)
	button.add_theme_color_override("font_pressed_color", NODE_TEXT)
	var node_font_size := 8 if button.text.is_empty() else int(max(12.0, node_size.x * 0.42))
	button.add_theme_font_size_override("font_size", node_font_size)
	button.modulate = Color.WHITE


func _refresh_node_highlights() -> void:
	var valid_next_nodes: Array = _valid_next_nodes()
	for node_id in _node_buttons:
		var node_id_string: String = str(node_id)
		if _is_delivered_node(node_id_string):
			_set_node_state(node_id_string, NODE_DELIVERED, DELIVERED_NODE_SIZE, 80, "OK", 3, NODE_OUTLINE)
		elif node_id_string == START_NODE_ID:
			_set_node_state(node_id_string, NODE_START, START_NODE_SIZE, 70, "S", 3, NODE_START_OUTLINE)
		elif _selected_route_nodes.has(node_id_string):
			_set_node_state(node_id_string, NODE_SELECTED, SELECTED_NODE_SIZE, 50, "", 2, NODE_START_OUTLINE)
		elif _is_delivery_objective_node(node_id_string):
			_set_node_state(node_id_string, NODE_OBJECTIVE, OBJECTIVE_NODE_SIZE, 100, "!", 4, NODE_OBJECTIVE_OUTLINE)
		elif valid_next_nodes.has(node_id_string):
			_set_node_state(node_id_string, NODE_AVAILABLE, AVAILABLE_NODE_SIZE, 40, "", 3, NODE_OUTLINE)
		elif _selected_route_nodes.is_empty():
			_set_node_state(node_id_string, NODE_NORMAL, NORMAL_NODE_SIZE, 0)
		else:
			_set_node_state(node_id_string, NODE_FADED, NORMAL_NODE_SIZE, 0)
	_refresh_order_markers()


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

	_route_label.text = "%s -> Customer\nEstimated time: %.1f minutes\n%s" % [
		route_text,
		_calculate_route_time(),
		_objective_status_text(),
	]
	_route_label.text += "\nDelivered districts: %d/%d" % [
		_delivered_district_count(),
		_required_delivery_districts().size(),
	]


func _refresh_route_controls() -> void:
	_confirm_route_button.disabled = not _can_confirm_route()


func _can_confirm_route() -> bool:
	return (
		_selected_route_nodes.size() >= 2
		and not _selected_orders.is_empty()
		and Player.can_work_shift()
		and _route_reaches_all_delivery_nodes()
	)


func _route_reaches_all_delivery_nodes() -> bool:
	var required_districts: Array = _required_delivery_districts()
	if required_districts.is_empty():
		return false

	for district in required_districts:
		var district_name: String = str(district)
		var delivery_node: String = str(CUSTOMER_DELIVERY_NODES[district_name])
		if not _selected_route_nodes.has(delivery_node):
			return false

	return true


func _delivered_district_count() -> int:
	return _delivered_districts().size()


func _delivered_districts() -> Array:
	var delivered_districts: Array = []
	for district in _required_delivery_districts():
		var district_name: String = str(district)
		var delivery_node: String = str(CUSTOMER_DELIVERY_NODES[district_name])
		if _selected_route_nodes.has(delivery_node):
			delivered_districts.append(district_name)

	return delivered_districts


func _remaining_districts() -> Array:
	var remaining_districts: Array = []
	for district in _required_delivery_districts():
		var district_name: String = str(district)
		var delivery_node: String = str(CUSTOMER_DELIVERY_NODES[district_name])
		if not _selected_route_nodes.has(delivery_node):
			remaining_districts.append(district_name)

	return remaining_districts


func _required_delivery_districts() -> Array:
	var required_districts: Array = []
	for order in _selected_orders:
		if order is Dictionary:
			var order_data: Dictionary = order as Dictionary
			var district_name: String = str(order_data.get("district", ""))
			if CUSTOMER_DELIVERY_NODES.has(district_name) and not required_districts.has(district_name):
				required_districts.append(district_name)

	return required_districts


func _is_delivery_objective_node(node_id: String) -> bool:
	for district in _required_delivery_districts():
		var district_name: String = str(district)
		if str(CUSTOMER_DELIVERY_NODES[district_name]) == node_id:
			return true

	return false


func _is_delivered_node(node_id: String) -> bool:
	return _is_delivery_objective_node(node_id) and _selected_route_nodes.has(node_id)


func _objective_status_text() -> String:
	var remaining_districts: Array = _remaining_districts()
	if remaining_districts.is_empty():
		return "Reach: None"

	return "Reach: %s" % _join_district_names(remaining_districts)


func _join_district_names(districts: Array) -> String:
	var district_names: Array[String] = []
	for district in districts:
		district_names.append(str(district))

	return ", ".join(district_names)


func _calculate_delivery_result() -> Dictionary:
	var route_time := _calculate_route_time()
	var valid_orders: Array = _valid_selected_orders()
	var orders_delivered := valid_orders.size()
	var base_pay_total := orders_delivered * BASE_PAY_PER_ORDER
	var tip_total := 0

	for order in valid_orders:
		var order_data: Dictionary = order as Dictionary
		tip_total += _calculate_tip(order_data, route_time)

	var total_earned := base_pay_total + tip_total
	return {
		"orders_delivered": orders_delivered,
		"base_pay_total": base_pay_total,
		"tip_total": tip_total,
		"total_earned": total_earned,
		"route_time": route_time,
		"customer_satisfaction": _customer_satisfaction(route_time),
	}


func _valid_selected_orders() -> Array:
	var valid_orders: Array = []
	for order in _selected_orders:
		if order is Dictionary:
			var order_data: Dictionary = order as Dictionary
			var district_name: String = str(order_data.get("district", ""))
			if CUSTOMER_DELIVERY_NODES.has(district_name):
				valid_orders.append(order_data)

	return valid_orders


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
	var valid_orders: Array = _valid_selected_orders()
	if valid_orders.is_empty():
		return "Bad"

	var on_time_orders := 0
	var late_orders := 0
	for order in valid_orders:
		var order_data: Dictionary = order as Dictionary
		var max_delivery_time := float(order_data.get("max_delivery_time", 0))
		if route_time <= max_delivery_time:
			on_time_orders += 1
		elif route_time <= max_delivery_time * 1.25:
			late_orders += 1

	if on_time_orders == valid_orders.size():
		return "Great"
	if on_time_orders + late_orders > 0:
		return "Good"
	return "Bad"
