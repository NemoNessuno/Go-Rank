class_name GameBoardIdentityTests
extends GdUnitTestSuite

const GameViewScene := preload("res://client/scenes/GameView.tscn")

var _game_board: Control
var _saved_sgf_path := ""

func after_test() -> void:
	if is_instance_valid(_game_board):
		_game_board.queue_free()
	Network.current_game = null
	if not _saved_sgf_path.is_empty():
		var absolute_path := ProjectSettings.globalize_path(_saved_sgf_path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)

func _create_game() -> GameData:
	var black := UserData.new()
	black.id = 1
	black.name = "Black Player"
	black.unified_rating = 525.0
	var white := UserData.new()
	white.id = 2
	white.name = "White Player"
	white.unified_rating = 600.0
	var game := GameData.new()
	game.black_player = black
	game.white_player = white
	return game

func test_board_displays_names_ranks_and_undecided_result() -> void:
	Network.current_game = _create_game()
	_game_board = GameViewScene.instantiate()
	add_child(_game_board)
	await get_tree().process_frame

	assert_str(_game_board.name).is_equal("GameView")
	assert_str(
		_game_board.get_node("RootVBox/MainHBox/BoardPanel/GoBoard").scene_file_path
	).is_equal("res://client/scenes/GoBoard.tscn")
	assert_str(
		_game_board.get_node("RootVBox/MainHBox/VariationTree").scene_file_path
	).is_equal("res://client/scenes/VariationTree.tscn")
	assert_str(_game_board.black_player_label.text).is_equal("Black Player (30 kyu)")
	assert_str(_game_board.white_player_label.text).is_equal("White Player (27 kyu)")
	assert_str(_game_board.status_label.text).is_equal("Black Player to move")
	assert_int(_game_board._get_game_result()).is_equal(GameData.RESULT_UNDECIDED)

func test_game_store_sgf_uses_timestamp_and_player_names() -> void:
	Network.current_game = _create_game()
	_game_board = GameViewScene.instantiate()
	add_child(_game_board)
	await get_tree().process_frame

	_game_board.state.game_over = true
	assert_bool(_game_board.state.game_over).is_true()
	assert_int(_game_board._get_game_result()).is_equal(2)

	_saved_sgf_path = _game_board.file_manager.write_game_sgf()
	assert_str(_saved_sgf_path).contains("_Black_Player_White_Player.sgf")
	assert_bool(FileAccess.file_exists(_saved_sgf_path)).is_true()
	var file := FileAccess.open(_saved_sgf_path, FileAccess.READ)
	var contents := file.get_as_text()
	assert_str(contents).contains("PB[Black Player]")
	assert_str(contents).contains("PW[White Player]")
	assert_str(contents).contains("RE[W+6.0]")

func test_variation_nodes_are_styled_and_edges_connect_centers() -> void:
	Network.current_game = _create_game()
	_game_board = GameViewScene.instantiate()
	add_child(_game_board)
	await get_tree().process_frame

	_game_board._play_move(4, 4)
	await get_tree().process_frame
	_game_board._play_move(4, 3)
	await get_tree().process_frame

	var root_node: VariationTreeNode = _game_board.variation_tree.get_node(
		"variation_node_0"
	)
	var black_node: VariationTreeNode = _game_board.variation_tree.get_node(
		"variation_node_1"
	)
	var white_node: VariationTreeNode = _game_board.variation_tree.get_node(
		"variation_node_2"
	)

	assert_bool(root_node.text.is_empty()).is_true()
	assert_str(black_node.text).is_equal("1")
	assert_str(white_node.text).is_equal("2")
	assert_bool(black_node.alignment == HORIZONTAL_ALIGNMENT_CENTER).is_true()
	assert_bool(black_node is Button).is_true()
	assert_bool(black_node.get_theme_color("font_color") == Color.WHITE).is_true()
	assert_bool(white_node.get_theme_color("font_color") == Color.BLACK).is_true()
	var root_style := root_node.get_theme_stylebox("normal") as StyleBoxFlat
	var black_style := black_node.get_theme_stylebox("normal") as StyleBoxFlat
	var white_style := white_node.get_theme_stylebox("normal") as StyleBoxFlat
	assert_bool(root_style.bg_color == Color("#858585")).is_true()
	assert_bool(black_style.bg_color == Color("#171717")).is_true()
	assert_bool(white_style.bg_color == Color("#f5f5f5")).is_true()
	assert_int(black_style.corner_radius_top_left).is_equal(24)
	assert_bool(
		_game_board.variation_tree.EDGE_COLOR == Color("#d0d0d0")
	).is_true()
	var edge_points: Dictionary = _game_board.variation_tree.get_edge_points(0, 1)
	assert_bool(
		edge_points["from"] == root_node.position + Vector2(24, 48)
	).is_true()
	assert_bool(
		edge_points["to"] == black_node.position + Vector2(24, 0)
	).is_true()

	black_node.emit_signal("pressed")
	assert_int(_game_board.active_variation_id).is_equal(1)
	assert_int(_game_board.move_log.size()).is_equal(1)
