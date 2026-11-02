class_name GameBoardVariationTree
extends RefCounted

var owner: Control
var is_updating_variation_tree := false

func attach(board_owner: Control) -> void:
	owner = board_owner

func reset_tree() -> void:
	owner.variation_nodes.clear()
	owner.next_variation_id = 0
	owner.variation_root_id = -1
	owner.active_variation_id = -1
	owner.variation_root_id = owner._create_variation_node(-1, {"root": true, "color": -1, "x": -1, "y": -1, "pass": false})
	owner.active_variation_id = owner.variation_root_id
	refresh_tree()

func record_move(move_data: Dictionary) -> void:
	var parent_id: int = owner.active_variation_id if owner.active_variation_id >= 0 else owner.variation_root_id
	if parent_id < 0:
		parent_id = owner.variation_root_id
	var existing_child_id := _find_existing_child(parent_id, move_data)
	if existing_child_id >= 0:
		owner.active_variation_id = existing_child_id
		refresh_tree()
		return
	owner.active_variation_id = owner._create_variation_node(parent_id, move_data)
	refresh_tree()

func _find_existing_child(parent_id: int, move_data: Dictionary) -> int:
	if parent_id < 0 or not owner.variation_nodes.has(parent_id):
		return -1
	for child_id in owner.variation_nodes[parent_id].get("children", []):
		if not owner.variation_nodes.has(child_id):
			continue
		var child_move: Dictionary = owner.variation_nodes[child_id].get("move", {})
		if child_move.get("pass", false) != move_data.get("pass", false):
			continue
		if child_move.get("color", -1) != move_data.get("color", -1):
			continue
		if int(child_move.get("x", -1)) != int(move_data.get("x", -1)):
			continue
		if int(child_move.get("y", -1)) != int(move_data.get("y", -1)):
			continue
		return child_id
	return -1

func refresh_tree() -> void:
	if owner.variation_tree == null:
		return
	if is_updating_variation_tree:
		return
	is_updating_variation_tree = true
	for child in owner.variation_tree.get_children():
		if child is GraphNode:
			child.queue_free()
	owner.variation_tree.clear_connections()
	if owner.variation_root_id < 0:
		is_updating_variation_tree = false
		return
	_layout_graph_nodes()
	if owner.active_variation_id >= 0 and owner.variation_nodes.has(owner.active_variation_id):
		var active_graph_node : GraphNode = owner.variation_tree.get_node_or_null("variation_node_%d" % owner.active_variation_id)
		if active_graph_node != null and active_graph_node is GraphNode:
			active_graph_node.set_selected(true)
	is_updating_variation_tree = false

func _layout_graph_nodes() -> void:
	var depth_map: Dictionary = {}
	_collect_depths(owner.variation_root_id, 0, depth_map)
	var node_positions: Dictionary = {}
	var spacing_x := 80.0
	var spacing_y := 50.0
	for depth in depth_map.keys():
		var node_ids: Array = depth_map[depth]
		for index in range(node_ids.size()):
			var node_id: int = int(node_ids[index])
			node_positions[node_id] = Vector2(index * spacing_x, depth * spacing_y)
	for node_id in owner.variation_nodes.keys():
		var node_data: Dictionary = owner.variation_nodes[node_id]
		var graph_node := VariationTreeNode.new()
		graph_node.name = "variation_node_%d" % node_id
		graph_node.title = _variation_label(node_id)
		graph_node.position_offset = node_positions.get(node_id, Vector2.ZERO)
		graph_node.custom_minimum_size = Vector2(110, 48)
		var move_data: Dictionary = node_data.get("move", {})
		var player_color := Color(0.08, 0.08, 0.08)
		if move_data.get("color", owner.BLACK) == owner.WHITE:
			player_color = Color(0.96, 0.96, 0.96)
		graph_node.modulate = player_color
		graph_node.set_meta("variation_id", node_id)
		owner.variation_tree.add_child(graph_node)
		graph_node.set_slot(0, false, 0, Color(0, 0, 0, 0), true, 0, Color(0, 0, 0, 0))
	for parent_id in owner.variation_nodes.keys():
		if not owner.variation_nodes.has(parent_id):
			continue
		var parent_graph : GraphNode = owner.variation_tree.get_node_or_null("variation_node_%d" % parent_id)
		if parent_graph == null or not parent_graph is GraphNode:
			continue
		for child_id in owner.variation_nodes[parent_id].get("children", []):
			var child_graph : GraphNode = owner.variation_tree.get_node_or_null("variation_node_%d" % child_id)
			if child_graph != null:
				owner.variation_tree.connect_node(parent_graph.name, 0, child_graph.name, 0)

func _collect_depths(node_id: int, depth: int, depth_map: Dictionary) -> void:
	if not owner.variation_nodes.has(node_id):
		return
	if not depth_map.has(depth):
		depth_map[depth] = []
	depth_map[depth].append(node_id)
	for child_id in owner.variation_nodes[node_id].get("children", []):
		_collect_depths(child_id, depth + 1, depth_map)

func _variation_label(node_id: int) -> String:
	if not owner.variation_nodes.has(node_id):
		return ""
	var node: Dictionary = owner.variation_nodes[node_id]
	if node.get("move", {}).get("root", false):
		return "Game start"
	var move_count: int = node.get("move_log", []).size()
	return str(move_count)

func on_item_selected(graph_node: Variant = null) -> void:
	if owner.variation_tree == null:
		return
	if is_updating_variation_tree:
		return
	var selected_node: Variant = graph_node
	if selected_node == null:
		selected_node = owner.variation_tree.get_selected()
	if selected_node == null:
		return
	if not selected_node.has_meta("variation_id"):
		return
	var node_id := int(selected_node.get_meta("variation_id", -1))
	if node_id < 0 or not owner.variation_nodes.has(node_id):
		return
	select_node(node_id)

func select_node(node_id: int) -> void:
	if is_updating_variation_tree:
		return
	if not owner.variation_nodes.has(node_id):
		return
	var node: Variant = owner.variation_nodes[node_id]
	owner.board.clear()
	for row in node.get("board", []):
		owner.board.append(row.duplicate())
	owner.current_player = int(node.get("current_player", owner.BLACK))
	owner.black_captures = int(node.get("black_captures", 0))
	owner.white_captures = int(node.get("white_captures", 0))
	owner.move_log = []
	for entry in node.get("move_log", []):
		owner.move_log.append(entry.duplicate())
	owner.previous_board_state.clear()
	for row in node.get("previous_board_state", []):
		owner.previous_board_state.append(row.duplicate())
	owner.active_variation_id = node_id
	owner._update_status("%s to move" % (["Black", "White"][owner.current_player - 1]))
	owner._refresh_capture_labels()
	refresh_tree()
	owner.queue_redraw()
