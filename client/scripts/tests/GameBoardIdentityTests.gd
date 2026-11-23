class_name GameBoardIdentityTests
extends GdUnitTestSuite

const GameBoardScene := preload("res://client/scenes/GameBoard.tscn")

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
	_game_board = GameBoardScene.instantiate()
	add_child(_game_board)
	await get_tree().process_frame

	assert_str(_game_board.black_player_label.text).is_equal("Black Player (30 kyu)")
	assert_str(_game_board.white_player_label.text).is_equal("White Player (27 kyu)")
	assert_str(_game_board.status_label.text).is_equal("Black Player to move")
	assert_int(_game_board._get_game_result()).is_equal(GameData.RESULT_UNDECIDED)

func test_game_store_sgf_uses_timestamp_and_player_names() -> void:
	Network.current_game = _create_game()
	_game_board = GameBoardScene.instantiate()
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
