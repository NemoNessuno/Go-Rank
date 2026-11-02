extends Control

const GameBoardStateScript = preload("res://client/scripts/GameBoard/GameBoardState.gd")
const GameBoardLayoutScript = preload("res://client/scripts/GameBoard/GameBoardLayout.gd")
const GameBoardRulesScript = preload("res://client/scripts/GameBoard/GameBoardRules.gd")
const GameBoardFileManagerScript = preload("res://client/scripts/GameBoard/GameBoardFileManager.gd")
const GameBoardVariationTreeScript = preload("res://client/scripts/GameBoard/GameBoardVariationTree.gd")
const GameBoardScoringScript = preload("res://client/scripts/GameBoard/GameBoardScoring.gd")

const BOARD_SIZE := GameBoardStateScript.BOARD_SIZE
const EMPTY := GameBoardStateScript.EMPTY
const BLACK := GameBoardStateScript.BLACK
const WHITE := GameBoardStateScript.WHITE

var board: Array:
	get:
		return state.board
	set(value):
		state.board = value
var current_player: int:
	get:
		return state.current_player
	set(value):
		state.current_player = value
var previous_board_state: Array:
	get:
		return state.previous_board_state
	set(value):
		state.previous_board_state = value
var history: Array:
	get:
		return state.history
	set(value):
		state.history = value
var history_index: int:
	get:
		return state.history_index
	set(value):
		state.history_index = value
var move_log: Array:
	get:
		return state.move_log
	set(value):
		state.move_log = value
var black_captures: int:
	get:
		return state.black_captures
	set(value):
		state.black_captures = value
var white_captures: int:
	get:
		return state.white_captures
	set(value):
		state.white_captures = value
var board_origin: Vector2:
	get:
		return state.board_origin
	set(value):
		state.board_origin = value
var board_step: float:
	get:
		return state.board_step
	set(value):
		state.board_step = value
var board_rect: Rect2:
	get:
		return state.board_rect
	set(value):
		state.board_rect = value
var status_label: Label
var black_captures_label: Label
var white_captures_label: Label
var final_score_label: Label
var komi_input: LineEdit
var komi_value: float = 6.0
var pass_button: Button
var save_sgf_button: Button
var load_sgf_button: Button
var save_dialog: FileDialog
var load_dialog: FileDialog
var back_button: Button
var restart_button: Button
var board_surface: Control
var variation_tree: GraphEdit
var territory_dots: Array = []
var variation_nodes: Dictionary:
	get:
		return state.variation_nodes
	set(value):
		state.variation_nodes = value
var variation_root_id: int:
	get:
		return state.variation_root_id
	set(value):
		state.variation_root_id = value
var active_variation_id: int:
	get:
		return state.active_variation_id
	set(value):
		state.active_variation_id = value
var next_variation_id: int:
	get:
		return state.next_variation_id
	set(value):
		state.next_variation_id = value
var is_updating_variation_tree: bool:
	get:
		return state.is_updating_variation_tree
	set(value):
		state.is_updating_variation_tree = value
var layout_manager: GameBoardLayoutScript
var rules_manager: GameBoardRulesScript
var file_manager: GameBoardFileManagerScript
var variation_manager: GameBoardVariationTreeScript
var scoring_manager: GameBoardScoringScript
var state: GameBoardStateScript

func _ready() -> void:
	state = GameBoardStateScript.new()
	state.attach(self)
	layout_manager = GameBoardLayoutScript.new()
	layout_manager.attach(self)
	rules_manager = GameBoardRulesScript.new()
	rules_manager.attach(self)
	file_manager = GameBoardFileManagerScript.new()
	file_manager.attach(self)
	variation_manager = GameBoardVariationTreeScript.new()
	variation_manager.attach(self)
	scoring_manager = GameBoardScoringScript.new()
	_build_ui()
	if board_surface != null and board_surface.has_method("set"):
		board_surface.set("board_owner", self)
	_reset_board()

func _build_ui() -> void:
	layout_manager.build_ui()
	layout_manager.attach(self, board_surface)
	if not komi_input.text_changed.is_connected(_on_komi_input_changed):
		komi_input.text_changed.connect(_on_komi_input_changed)

func _build_file_dialogs() -> void:
	layout_manager._build_file_dialogs(self)

func _reset_board() -> void:
	territory_dots.clear()
	state.reset_board()
	_update_status("Black to move")
	_refresh_capture_labels()
	_refresh_final_score_label()
	if board_surface != null:
		board_surface.queue_redraw()

func _draw() -> void:
	if board_surface != null:
		board_surface.queue_redraw()

func _on_board_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if board_surface == null:
		return

	var board_position := board_surface.get_local_mouse_position()
	var cell := _screen_to_cell(board_position)
	if cell == Vector2i(-1, -1):
		return
	_play_move(cell.x, cell.y)

func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var target_rect: Rect2 = board_rect
	if board_surface != null and board_surface.has_method("get_board_geometry"):
		target_rect = board_surface.get_board_geometry().get("rect", board_rect)
	if target_rect.size == Vector2.ZERO:
		if board_surface != null and board_surface.has_method("get_board_geometry"):
			var geometry : Dictionary = board_surface.get_board_geometry()
			target_rect = geometry.get("rect", Rect2())
	if target_rect.size == Vector2.ZERO:
		return Vector2i(-1, -1)
	if not target_rect.has_point(screen_position):
		return Vector2i(-1, -1)

	var step := board_step
	if board_surface != null and board_surface.has_method("get_board_geometry"):
		step = float(board_surface.get_board_geometry().get("step", board_step))
	if step <= 0.0:
		return Vector2i(-1, -1)

	var local := screen_position - target_rect.position
	var x := int(round(local.x / step))
	var y := int(round(local.y / step))

	if x < 0 or x >= BOARD_SIZE or y < 0 or y >= BOARD_SIZE:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func _cell_center(x: int, y: int) -> Vector2:
	return Vector2(board_origin.x + x * board_step, board_origin.y + y * board_step)

func _on_variation_tree_item_selected(node: GraphNode = null) -> void:
	variation_manager.on_item_selected(node)

func _play_move(x: int, y: int) -> void:
	var move_data : Dictionary = rules_manager.play_move(x, y)
	if move_data.is_empty():
		return
	variation_manager.record_move(move_data)

func _on_pass_pressed() -> void:
	var move_data : Dictionary = rules_manager.pass_turn()
	if move_data.is_empty():
		return
	variation_manager.record_move(move_data)

func _on_restart_pressed() -> void:
	_reset_board()

func _on_back_to_overworld_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Overworld.tscn")

func _push_history_state() -> void:
	state.push_history_state()

func _restore_state(state_data: Dictionary) -> void:
	state.restore_state(state_data)
	if state.game_over:
		_refresh_territory_markers()
		_update_status("Game over")
	else:
		territory_dots.clear()
		_update_status("%s to move" % (["Black", "White"][current_player - 1]))

	_refresh_capture_labels()
	_refresh_final_score_label()
	queue_redraw()

func _update_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func _refresh_capture_labels() -> void:
	if black_captures_label != null:
		black_captures_label.text = "Black captures: %d" % black_captures
	if white_captures_label != null:
		white_captures_label.text = "White captures: %d" % white_captures

func _refresh_final_score_label() -> void:
	if final_score_label == null:
		return
	if not state.game_over:
		final_score_label.visible = false
		final_score_label.text = ""
		return
	var score := _calculate_final_score()
	final_score_label.text = "Final score: Black %s - White %s" % [_format_score_value(score["black"]), _format_score_value(score["white"])]
	final_score_label.visible = true

func _format_score_value(value: float) -> String:
	if abs(value - round(value)) < 0.0001:
		return "%d.0" % int(round(value))
	return str(value)

func _format_komi_value(value: float) -> String:
	var rounded : Variant = snapped(value, 0.5)
	if abs(rounded - round(rounded)) < 0.0001:
		return "%d.0" % int(round(rounded))
	return str(rounded)

func _on_komi_input_changed(new_text: String) -> void:
	if new_text.strip_edges() == "":
		return
	if not _is_valid_komi_text(new_text):
		if komi_input != null:
			komi_input.text = _format_komi_value(komi_value)
		return
	var parsed_value := float(new_text)
	komi_value = parsed_value
	if state.game_over:
		_refresh_final_score_label()

func _is_valid_komi_text(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return false
	var regex := RegEx.new()
	regex.compile(r"^-?\d+(\.0|\.5)?$")
	return regex.search(trimmed) != null

func _end_game() -> void:
	state.game_over = true
	_refresh_territory_markers()
	_push_history_state()
	var score := _calculate_final_score()
	var black_total: int = score["black"]
	var white_total: int = score["white"]
	if black_total > white_total:
		_update_status("Game over: Black wins by %d" % (black_total - white_total))
	elif white_total > black_total:
		_update_status("Game over: White wins by %d" % (white_total - black_total))
	else:
		_update_status("Game over: Draw")
	_refresh_capture_labels()
	_refresh_final_score_label()
	queue_redraw()

func _refresh_territory_markers() -> void:
	territory_dots = scoring_manager.calculate_territory_dots(board)

func _calculate_final_score() -> Dictionary:
	return scoring_manager.calculate_final_score(board, black_captures, white_captures, komi_value, territory_dots)

func _save_sgf() -> void:
	file_manager.save_sgf()

func _on_save_dialog_file_selected(path: String) -> void:
	file_manager._on_save_dialog_file_selected(path)

func _load_sgf() -> void:
	file_manager.load_sgf()

func _on_load_dialog_file_selected(path: String) -> void:
	file_manager._on_load_dialog_file_selected(path)

func _snapshot_board() -> Array:
	return state.snapshot_board()

func _create_variation_node(parent_id: int, move_data: Dictionary) -> int:
	return state.create_variation_node(parent_id, move_data)

func _board_to_sgf(x: int, y: int) -> String:
	return file_manager._board_to_sgf(x, y)

func _boards_equal(left: Array, right: Array) -> bool:
	return state.boards_equal(left, right)

func _capture_adjacent_opponent_groups(x: int, y: int) -> int:
	return state.capture_adjacent_opponent_groups(x, y)

func _collect_group(start_x: int, start_y: int, color: int) -> Array:
	return state.collect_group(start_x, start_y, color)

func _group_has_liberties(group: Array) -> bool:
	return state.group_has_liberties(group)

func _is_group_alive(x: int, y: int, color: int) -> bool:
	return state.is_group_alive(x, y, color)

func _neighbors(x: int, y: int) -> Array:
	return state.neighbors(x, y)

func _opponent(player: int) -> int:
	return state.opponent_for(player)
