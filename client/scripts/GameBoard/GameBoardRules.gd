class_name GameBoardRules
extends RefCounted

var owner: Control

func attach(board_owner: Control) -> void:
	owner = board_owner

func play_move(x: int, y: int) -> Dictionary:
	if owner.state.game_over:
		return {}
	if x < 0 or y < 0 or x >= owner.BOARD_SIZE or y >= owner.BOARD_SIZE:
		return {}
	if owner.board[y][x] != owner.EMPTY:
		owner._update_status("That point is occupied.")
		return {}

	var board_before_move: Array = owner._snapshot_board()
	var candidate_board: Array = []
	for row in board_before_move:
		candidate_board.append(row.duplicate())

	var previous_board_reference: Array = owner.board
	owner.board = candidate_board
	owner.state.consecutive_passes = 0
	owner.state.game_over = false
	owner.board[y][x] = owner.current_player
	var captured_stones: int = owner._capture_adjacent_opponent_groups(x, y)

	if not owner._is_group_alive(x, y, owner.current_player):
		owner.board = previous_board_reference
		owner._update_status("Illegal move: suicide.")
		return {}

	var board_after_move: Array = owner._snapshot_board()
	if owner.previous_board_state.size() > 0 and owner._boards_equal(board_after_move, owner.previous_board_state):
		owner.board = previous_board_reference
		owner._update_status("Illegal move: Ko rule.")
		return {}

	if _would_repeat_known_board(board_after_move):
		owner.board = previous_board_reference
		owner._update_status("Illegal move: repeated board position.")
		return {}

	owner.board = candidate_board
	if owner.current_player == owner.BLACK:
		owner.black_captures += captured_stones
	else:
		owner.white_captures += captured_stones

	var move_data := {"color": owner.current_player, "x": x, "y": y, "pass": false}
	owner.move_log.append(move_data)
	owner.previous_board_state = board_before_move
	owner.current_player = owner._opponent(owner.current_player)
	owner._push_history_state()
	owner._update_status("%s to move" % (["Black", "White"][owner.current_player - 1]))
	owner._refresh_capture_labels()
	owner.queue_redraw()
	return move_data

func _would_repeat_known_board(candidate_board: Array) -> bool:
	if owner == null:
		return false
	var variation_nodes: Dictionary = owner.get("variation_nodes")
	var active_variation_id: int = int(owner.get("active_variation_id"))
	if variation_nodes == null:
		return false
	var node_id: int = active_variation_id
	while node_id >= 0 and variation_nodes.has(node_id):
		var previous_state: Dictionary = variation_nodes[node_id]
		var previous_board: Array = previous_state.get("board", [])
		if previous_board.size() > 0 and owner._boards_equal(candidate_board, previous_board):
			return true
		node_id = int(previous_state.get("parent", -1))
	return false

func pass_turn() -> Dictionary:
	if owner.state.game_over:
		return {}
	var move_data := {"color": owner.current_player, "x": -1, "y": -1, "pass": true}
	owner.state.consecutive_passes += 1
	owner.move_log.append(move_data)
	owner.previous_board_state = owner._snapshot_board()
	owner.current_player = owner._opponent(owner.current_player)
	owner._push_history_state()
	if owner.state.consecutive_passes >= 2:
		owner._end_game()
		return move_data
	owner._update_status("%s to move after a pass" % (["Black", "White"][owner.current_player - 1]))
	owner._refresh_capture_labels()
	owner._refresh_final_score_label()
	owner.queue_redraw()
	return move_data
