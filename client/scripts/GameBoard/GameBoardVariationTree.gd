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
	owner.variation_root_id = owner._create_variation_node(
		-1,
		{"root": true, "color": -1, "x": -1, "y": -1, "pass": false}
	)
	owner.active_variation_id = owner.variation_root_id
	refresh_tree()

func record_move(move_data: Dictionary) -> void:
	var parent_id: int = (
		owner.active_variation_id
		if owner.active_variation_id >= 0
		else owner.variation_root_id
	)
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
		return int(child_id)
	return -1

func refresh_tree() -> void:
	if owner.variation_tree == null or is_updating_variation_tree:
		return
	is_updating_variation_tree = true
	owner.variation_tree.display_variations(
		owner.variation_nodes,
		owner.variation_root_id,
		owner.active_variation_id
	)
	is_updating_variation_tree = false

func on_item_selected(node_id: int) -> void:
	if (
		is_updating_variation_tree
		or node_id < 0
		or not owner.variation_nodes.has(node_id)
	):
		return
	select_node(node_id)

func select_node(node_id: int) -> void:
	if is_updating_variation_tree or not owner.variation_nodes.has(node_id):
		return
	var node: Dictionary = owner.variation_nodes[node_id]
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
	var player_name := "Black" if owner.current_player == owner.BLACK else "White"
	if owner.has_method("_player_name"):
		player_name = owner._player_name(owner.current_player)
	owner._update_status("%s to move" % player_name)
	owner._refresh_capture_labels()
	refresh_tree()
	owner.queue_redraw()
