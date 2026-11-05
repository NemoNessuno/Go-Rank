class_name BoardRulesTest
extends GdUnitTestSuite

const GameBoardStateScript = preload("res://client/scripts/GameBoard/GameBoardState.gd")
const GameBoardRulesScript = preload("res://client/scripts/GameBoard/GameBoardRules.gd")

class BoardHarness extends Control:
	const EMPTY := 0
	const BLACK := 1
	const WHITE := 2
	const BOARD_SIZE := 9

	var state: GameBoardStateScript
	var board: Array = []
	var current_player: int = BLACK
	var black_captures: int = 0
	var white_captures: int = 0
	var move_log: Array = []
	var previous_board_state: Array = []
	var variation_nodes: Dictionary = {}
	var active_variation_id: int = -1

	func _init() -> void:
		state = GameBoardStateScript.new()
		state.attach(self)
		state.reset_board()
		board = state.board
		current_player = state.current_player

	func _snapshot_board() -> Array:
		return state.snapshot_board()

	func _update_status(_message: String) -> void:
		pass

	func _refresh_capture_labels() -> void:
		pass

	func _refresh_final_score_label() -> void:
		pass

	func _push_history_state() -> void:
		state.push_history_state()

	func _capture_adjacent_opponent_groups(x: int, y: int) -> int:
		return state.capture_adjacent_opponent_groups(x, y)

	func _is_group_alive(x: int, y: int, color: int) -> bool:
		return state.is_group_alive(x, y, color)

	func _boards_equal(left: Array, right: Array) -> bool:
		return state.boards_equal(left, right)

	func _neighbors(x: int, y: int) -> Array:
		return state.neighbors(x, y)

	func _opponent(player: int) -> int:
		return state.opponent_for(player)

	func _end_game() -> void:
		state.game_over = true

func _create_rules() -> Array: var harness := BoardHarness.new(); var rules := GameBoardRulesScript.new(); rules.attach(harness); return [harness, rules]

func _empty_board() -> Array:
	var board: Array = []
	for y in range(9):
		var row: Array = []
		for x in range(9):
			row.append(0)
		board.append(row)
	return board

func test_legal_move_works() -> void:
	var created := _create_rules()
	var harness: BoardHarness = created[0]
	var rules = created[1]

	var move_data: Dictionary = rules.play_move(0, 0)

	assert_that(move_data.has("x")).is_true()
	assert_int(move_data["x"]).is_equal(0)
	assert_int(harness.board[0][0]).is_equal(harness.BLACK)
	assert_int(harness.current_player).is_equal(harness.WHITE)

func test_suicide_move_is_rejected() -> void:
	var created := _create_rules()
	var harness: BoardHarness = created[0]
	var rules = created[1]

	harness.board[0][0] = harness.BLACK
	harness.board[0][1] = harness.WHITE
	harness.board[1][0] = harness.WHITE
	harness.board[1][1] = harness.BLACK
	harness.current_player = harness.BLACK

	var move_data : Dictionary = rules.play_move(0, 0)
	assert_that(move_data.is_empty()).is_true()

func test_blocked_field_is_enforced() -> void:
	var created := _create_rules()
	var harness: BoardHarness = created[0]
	var rules = created[1]

	harness.board[0][0] = harness.BLACK
	harness.board[0][1] = harness.WHITE
	harness.board[1][0] = harness.WHITE
	harness.board[1][1] = harness.BLACK
	harness.current_player = harness.BLACK

	var move_data : Dictionary = rules.play_move(1, 1)
	var blocked_rejected := move_data.is_empty()

	assert_that(blocked_rejected).is_true()

func test_ko_rule_is_enforced() -> void:
	var created := _create_rules()
	var harness: BoardHarness = created[0]
	var rules = created[1]

	var previous_state: Array = _empty_board()
	previous_state[3][3] = harness.BLACK
	previous_state[3][4] = harness.WHITE
	previous_state[4][3] = harness.WHITE
	previous_state[4][4] = harness.BLACK

	var current_state: Array = _empty_board()
	current_state[3][3] = harness.BLACK
	current_state[3][4] = harness.WHITE
	current_state[4][3] = harness.WHITE
	current_state[4][2] = harness.WHITE

	harness.board = current_state
	harness.previous_board_state = previous_state
	harness.state.history = [
		{"board": previous_state},
		{"board": current_state}
	]
	harness.current_player = harness.BLACK

	var move_data: Dictionary = rules.play_move(4, 3)
	assert_that(move_data.is_empty()).is_true()

func test_actual_ko_capture_is_rejected() -> void:
	var created := _create_rules()
	var harness: BoardHarness = created[0]
	var rules = created[1]

	# This is a genuine ko-style recapture: Black is about to play the one point
	# that would restore the previous board position exactly, so the move must be rejected.
	var previous_state: Array = _empty_board()
	previous_state[3][3] = harness.BLACK
	previous_state[3][4] = harness.WHITE
	previous_state[4][3] = harness.WHITE
	previous_state[4][4] = harness.BLACK
	previous_state[5][4] = harness.WHITE

	var current_state: Array = _empty_board()
	current_state[3][3] = harness.BLACK
	current_state[3][4] = harness.WHITE
	current_state[4][3] = harness.WHITE
	current_state[4][4] = harness.EMPTY
	current_state[4][5] = harness.BLACK
	current_state[5][4] = harness.WHITE

	harness.board = current_state
	harness.previous_board_state = previous_state
	harness.state.history = [
		{"board": previous_state},
		{"board": current_state}
	]
	harness.current_player = harness.BLACK

	var move_data: Dictionary = rules.play_move(4, 4)
	assert_that(move_data.is_empty()).is_true()

func test_two_passes_end_game() -> void:
	var created := _create_rules()
	var harness: BoardHarness = created[0]
	var rules = created[1]

	rules.pass_turn()
	harness.current_player = harness.BLACK
	rules.pass_turn()
	assert_that(harness.state.game_over).is_true()
