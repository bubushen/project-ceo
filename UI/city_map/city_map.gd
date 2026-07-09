extends Control
## Native visual city map with route-building overlays.

const GRID_COLUMNS := 10
const GRID_ROWS := 10
const GRID_ORIGIN := Vector2(24, 36)
const GRID_SPACING := Vector2(29, 34)
const PIZZERIA_POSITION := Vector2(52, 70)

const TRAFFIC_LOW := Color(0.12, 0.75, 0.26, 1.0)
const TRAFFIC_MEDIUM := Color(0.95, 0.78, 0.16, 1.0)
const TRAFFIC_HIGH := Color(0.9, 0.18, 0.14, 1.0)
const NODE_NORMAL := Color.WHITE
const NODE_SELECTED := Color(0.35, 0.75, 1.0, 1.0)

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

var _node_buttons: Dictionary = {}
var _node_positions: Dictionary = {}
var _selected_route_nodes: Array[String] = []
var _active_customer_position := Vector2.ZERO


func _ready() -> void:
	_active_customer_position = CUSTOMER_LOCATIONS["City Center"]
	_build_road_network()
	_build_node_grid()
	_clear_route_button.pressed.connect(_on_clear_route_pressed)
	_refresh_route_display()


func show_orders(selected_orders: Array) -> void:
	_clear_order_markers()
	_clear_route()

	var district_counts: Dictionary = {}
	for order in selected_orders:
		if order is Dictionary:
			_add_order_marker(order, district_counts)


func _build_road_network() -> void:
	for y in range(GRID_ROWS):
		for x in range(GRID_COLUMNS - 1):
			if _has_horizontal_road(x, y):
				_add_road_segment(_node_position(x, y), _node_position(x + 1, y), _traffic_color(x, y))

	for y in range(GRID_ROWS - 1):
		for x in range(GRID_COLUMNS):
			if _has_vertical_road(x, y):
				_add_road_segment(_node_position(x, y), _node_position(x, y + 1), _traffic_color(x, y))


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
	if district_counts.size() == 1 and marker_count == 0:
		_active_customer_position = CUSTOMER_LOCATIONS[district]

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

	_selected_route_nodes.append(node_id)
	_highlight_node(node_id, true)
	_refresh_route_display()
	_refresh_route_line()


func _on_clear_route_pressed() -> void:
	_clear_route()


func _clear_route() -> void:
	_selected_route_nodes.clear()
	for node_id in _node_buttons:
		_highlight_node(node_id, false)

	_route_line.clear_points()
	_refresh_route_display()


func _highlight_node(node_id: String, is_selected: bool) -> void:
	var button := _node_buttons[node_id] as Button
	if is_selected:
		button.modulate = NODE_SELECTED
	else:
		button.modulate = NODE_NORMAL


func _refresh_route_line() -> void:
	if _selected_route_nodes.is_empty():
		_route_line.clear_points()
		return

	var points := PackedVector2Array([PIZZERIA_POSITION])
	for node_id in _selected_route_nodes:
		var node_position: Vector2 = _node_positions[node_id]
		points.append(node_position)
	points.append(_active_customer_position)
	_route_line.points = points


func _refresh_route_display() -> void:
	var route_text := "Route: Pizzeria"
	for node_id in _selected_route_nodes:
		route_text += " -> " + node_id

	_route_label.text = route_text + " -> Customer"
