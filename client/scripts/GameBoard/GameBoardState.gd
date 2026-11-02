class_name GameBoardState
extends RefCounted

const BOARD_SIZE := 9
const EMPTY := 0
const BLACK := 1
const WHITE := 2

var owner: Control
var board: Array = []
var current_player := BLACK
var previous_board_state: Array = []
var history: Array = []
var history_index: int = -1
var move_log: Array = []
var black_captures: int = 0
var white_captures: int = 0
var consecutive_passes: int = 0
var game_over: bool = false
var board_origin := Vector2.ZERO
var board_step := 0.0
var board_rect := Rect2()
var variation_nodes: Dictionary = {}
var variation_root_id: int = -1
var active_variation_id: int = -1
var next_variation_id: int = 0
var is_updating_variation_tree := false

func attach(board_owner: Control) -> void:
	owner = board_owner

func reset_board() -> void:
	board.clear()
	for y in range(BOARD_SIZE):
		var row: Array = []
		for x in range(BOARD_SIZE):
			row.append(EMPTY)
		board.append(row)

	black_captures = 0
	white_captures = 0
	consecutive_passes = 0
	game_over = false
	current_player = BLACK
	previous_board_state.clear()
	move_log.clear()
	history.clear()
	history_index = -1
	reset_variation_tree()
	push_history_state()

func snapshot_board() -> Array:
	var snapshot: Array = []
	for row in board:
		snapshot.append(row.duplicate())
	return snapshot

func boards_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for y in range(left.size()):
		if left[y].size() != right[y].size():
			return false
		for x in range(left[y].size()):
			if left[y][x] != right[y][x]:
				return false
	return true

func reset_variation_tree() -> void:
	variation_nodes.clear()
	next_variation_id = 0
	variation_root_id = -1
	active_variation_id = -1
	variation_root_id = create_variation_node(-1, {"root": true, "color": -1, "x": -1, "y": -1, "pass": false})
	active_variation_id = variation_root_id

func create_variation_node(parent_id: int, move: Dictionary) -> int:
	var parent_history: Array = []
	if parent_id >= 0 and variation_nodes.has(parent_id):
		parent_history = variation_nodes[parent_id].get("move_log", []).duplicate()

	var node_id := next_variation_id
	next_variation_id += 1
	var node := {
		"id": node_id,
		"parent": parent_id,
		"children": [],
		"move": move.duplicate(),
		"move_log": parent_history.duplicate(),
		"board": snapshot_board(),
		"current_player": current_player,
		"black_captures": black_captures,
		"white_captures": white_captures,
		"previous_board_state": previous_board_state.duplicate()
	}
	if not move.get("root", false):
		node["move_log"].append(move.duplicate())
	if parent_id >= 0 and variation_nodes.has(parent_id):
		variation_nodes[parent_id]["children"].append(node_id)
	else:
		variation_root_id = node_id
	variation_nodes[node_id] = node
	return node_id

func push_history_state() -> void:
	var state := {
		"board": snapshot_board(),
		"current_player": current_player,
		"black_captures": black_captures,
		"white_captures": white_captures,
		"consecutive_passes": consecutive_passes,
		"game_over": game_over,
		"previous_board_state": previous_board_state.duplicate(),
		"move_log": move_log.duplicate()
	}

	if history_index >= 0 and boards_equal(history[history_index]["board"], state["board"]) and history[history_index]["current_player"] == state["current_player"] and history[history_index]["black_captures"] == state["black_captures"] and history[history_index]["white_captures"] == state["white_captures"] and history[history_index].get("consecutive_passes", 0) == state["consecutive_passes"] and history[history_index].get("game_over", false) == state["game_over"] and boards_equal(history[history_index].get("previous_board_state", []), state["previous_board_state"]) and history[history_index].get("move_log", []).size() == state["move_log"].size():
		return

	if history_index < history.size() - 1:
		history = history.slice(0, history_index + 1)

	history.append(state)
	history_index = history.size() - 1

func restore_state(state_data: Dictionary) -> void:
	board.clear()
	for row in state_data["board"]:
		board.append(row.duplicate())
	current_player = int(state_data.get("current_player", BLACK))
	black_captures = int(state_data.get("black_captures", 0))
	white_captures = int(state_data.get("white_captures", 0))
	consecutive_passes = int(state_data.get("consecutive_passes", 0))
	game_over = bool(state_data.get("game_over", false))
	move_log = []
	if state_data.has("move_log"):
		for entry in state_data["move_log"]:
			move_log.append(entry.duplicate())
	previous_board_state = []
	if state_data.has("previous_board_state"):
		for row in state_data["previous_board_state"]:
			previous_board_state.append(row.duplicate())

func capture_adjacent_opponent_groups(x: int, y: int) -> int:
	var opponent := opponent_for(current_player)
	var captured_total := 0
	var processed: Dictionary = {}

	for neighbor in neighbors(x, y):
		var nx: int = neighbor.x
		var ny: int = neighbor.y
		if board[ny][nx] != opponent:
			continue
		var group_key := Vector2i(nx, ny)
		if group_key in processed:
			continue

		var group := collect_group(nx, ny, opponent)
		if not group_has_liberties(group):
			for stone in group:
				board[stone.y][stone.x] = EMPTY
				captured_total += 1
				processed[stone] = true

	return captured_total

func collect_group(start_x: int, start_y: int, color: int) -> Array:
	var result: Array = []
	var queue: Array = [Vector2i(start_x, start_y)]
	var visited: Dictionary = {}

	while queue.size() > 0:
		var position: Vector2i = queue.pop_back()
		if position in visited:
			continue
		visited[position] = true
		result.append(position)

		for neighbor in neighbors(position.x, position.y):
			var nx: int = neighbor.x
			var ny: int = neighbor.y
			if board[ny][nx] == color and not (Vector2i(nx, ny) in visited):
				queue.push_back(Vector2i(nx, ny))

	return result

func group_has_liberties(group: Array) -> bool:
	var liberties: Dictionary = {}
	for stone in group:
		for neighbor in neighbors(stone.x, stone.y):
			if board[neighbor.y][neighbor.x] == EMPTY:
				liberties[Vector2i(neighbor.x, neighbor.y)] = true
	return liberties.size() > 0

func is_group_alive(x: int, y: int, color: int) -> bool:
	var group := collect_group(x, y, color)
	return group_has_liberties(group)

func neighbors(x: int, y: int) -> Array:
	var result: Array = []
	var candidates := [
		Vector2i(x + 1, y),
		Vector2i(x - 1, y),
		Vector2i(x, y + 1),
		Vector2i(x, y - 1)
	]

	for candidate in candidates:
		if candidate.x < 0 or candidate.x >= BOARD_SIZE or candidate.y < 0 or candidate.y >= BOARD_SIZE:
			continue
		result.append(candidate)
	return result

func opponent_for(player: int) -> int:
	return WHITE if player == BLACK else BLACK
