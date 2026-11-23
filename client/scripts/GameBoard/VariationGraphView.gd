class_name VariationGraphView
extends Control

signal node_selected(node_id: int)

const VariationNodeScene := preload("res://client/scenes/VariationTreeNode.tscn")
const NODE_DIAMETER := 24.0
const NODE_RADIUS := NODE_DIAMETER / 2.0
const HORIZONTAL_SPACING := 42.0
const VERTICAL_SPACING := 41.0
const PADDING := 9.0
const MINIMUM_WIDTH := 240.0
const EDGE_COLOR := Color("#d0d0d0")
const EDGE_WIDTH := 2.0

var _variations: Dictionary = {}
var _node_centers: Dictionary = {}
var _root_id := -1
var _next_leaf_index := 0
var _max_depth := 0

func display_variations(
	variations: Dictionary,
	root_id: int,
	active_id: int
) -> void:
	_variations = variations
	_root_id = root_id
	_node_centers.clear()
	_next_leaf_index = 0
	_max_depth = 0
	for index in range(get_child_count()):
		var child := get_child(index)
		child.name = "queued_variation_node_%d" % index
		child.queue_free()
	if root_id < 0 or not _variations.has(root_id):
		custom_minimum_size = Vector2(MINIMUM_WIDTH, 0.0)
		queue_redraw()
		return

	_layout_node(root_id, 0)
	var required_width := (
		PADDING * 2.0
		+ NODE_DIAMETER
		+ maxf(0.0, float(_next_leaf_index - 1) * HORIZONTAL_SPACING)
	)
	var required_height := (
		PADDING * 2.0
		+ NODE_DIAMETER
		+ float(_max_depth) * VERTICAL_SPACING
	)
	custom_minimum_size = Vector2(maxf(MINIMUM_WIDTH, required_width), required_height)

	for node_id in _variations:
		if not _node_centers.has(node_id):
			continue
		var node_data: Dictionary = _variations[node_id]
		var move_data: Dictionary = node_data.get("move", {})
		var is_root := bool(move_data.get("root", false))
		var stone_color := int(move_data.get("color", -1))
		var node := VariationNodeScene.instantiate() as VariationTreeNode
		node.name = "variation_node_%d" % int(node_id)
		node.configure(
			_variation_label(node_data),
			stone_color,
			is_root,
			int(node_id) == active_id
		)
		node.pressed.connect(_on_node_pressed.bind(int(node_id)))
		node.position = _node_centers[node_id] - Vector2(NODE_RADIUS, NODE_RADIUS)
		add_child(node)
	queue_redraw()

func get_edge_points(parent_id: int, child_id: int) -> Dictionary:
	if not _node_centers.has(parent_id) or not _node_centers.has(child_id):
		return {}
	var parent_center: Vector2 = _node_centers[parent_id]
	var child_center: Vector2 = _node_centers[child_id]
	return {
		"from": Vector2(parent_center.x, parent_center.y + NODE_RADIUS),
		"to": Vector2(child_center.x, child_center.y - NODE_RADIUS)
	}

func _draw() -> void:
	for parent_id in _variations:
		var parent_data: Dictionary = _variations[parent_id]
		for child_id in parent_data.get("children", []):
			var edge := get_edge_points(int(parent_id), int(child_id))
			if edge.is_empty():
				continue
			draw_line(edge["from"], edge["to"], EDGE_COLOR, EDGE_WIDTH)

func _layout_node(node_id: int, depth: int) -> float:
	var node_data: Dictionary = _variations[node_id]
	var child_positions: Array[float] = []
	for child_value in node_data.get("children", []):
		var child_id := int(child_value)
		if _variations.has(child_id):
			child_positions.append(_layout_node(child_id, depth + 1))

	var x_position: float
	if child_positions.is_empty():
		x_position = PADDING + NODE_RADIUS + _next_leaf_index * HORIZONTAL_SPACING
		_next_leaf_index += 1
	else:
		var child_position_sum := 0.0
		for child_position in child_positions:
			child_position_sum += child_position
		x_position = child_position_sum / child_positions.size()

	_max_depth = maxi(_max_depth, depth)
	_node_centers[node_id] = Vector2(
		x_position,
		PADDING + NODE_RADIUS + depth * VERTICAL_SPACING
	)
	return x_position

func _variation_label(node_data: Dictionary) -> String:
	var move: Dictionary = node_data.get("move", {})
	if move.get("root", false):
		return ""
	return str(node_data.get("move_log", []).size())

func _on_node_pressed(node_id: int) -> void:
	node_selected.emit(node_id)
