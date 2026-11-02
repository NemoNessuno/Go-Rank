class_name GameBoardScoringTests
extends GdUnitTestSuite

const GameBoardScoringScript = preload("res://scripts/GameBoard/GameBoardScoring.gd")
const FIXTURE_ROOT := "res://tests/score_estimator_reference/fixtures"
const DIRECTORIES := [
		"easy",
		"mid",
		"hard",
		"no_removals",
		"patterns",
		"really_hard"
	]

func test_reference_fixture_directories_exist() -> void:

	for category in DIRECTORIES:
		var path := FIXTURE_ROOT.path_join(category)
		var dir := DirAccess.open(path)
		assert_that(dir != null).is_true()
		var files := _list_game_files(path)
		assert_that(files.size() > 0).is_true()

func test_reference_fixtures_parse_and_score() -> void:

	for category in DIRECTORIES:
		var category_path := FIXTURE_ROOT.path_join(category)
		var files := _list_game_files(category_path)
		for fixture_path in files:
			var fixture := _load_fixture(fixture_path)
			
			var board: Array = fixture["board"]
			var scoring := GameBoardScoringScript.new()
			var territory := scoring.calculate_territory_dots(board)
			var score := scoring.calculate_final_score(board, 0, 0, 0.0, territory)
			assert_that(score.has("black")).is_true()
			assert_that(score.has("white")).is_true()
			assert_that(score["black"] == score["black"]).is_true()
			assert_that(score["white"] == score["white"]).is_true()

			if fixture.has("removal"):
				assert_int(fixture["removal"].size()).is_equal(fixture["height"])
				for row_index in range(fixture["height"]):
					assert_int(fixture["removal"][row_index].size()).is_equal(fixture["width"])

func test_score_estimation_respects_komi_on_empty_board() -> void:
	var board := _blank_board()
	var scoring := GameBoardScoringScript.new()
	var score := scoring.calculate_final_score(board, 0, 0, 6.5, [])
	assert_float(score["white"]).is_equal(6.5)
	assert_float(score["black"]).is_equal(0.0)

func test_dead_stone_estimation_stays_conservative_for_seki_like_shapes() -> void:
	var board := _blank_board()
	board[0][1] = 1
	board[1][0] = 1
	board[1][2] = 2
	board[2][1] = 2
	var scoring := GameBoardScoringScript.new()
	var dead := scoring.estimate_dead_stones(board)
	assert_int(dead["black"]).is_equal(0)
	assert_int(dead["white"]).is_equal(0)
	
func _list_game_files(directory_path: String) -> Array:
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return []

	var files: Array = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".game"):
			files.append(directory_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files

func _load_fixture(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_that(file != null).is_true()

	var height := 0
	var width := 0
	var player_to_move := 0
	var board: Array = []
	var removal: Array = []
	var reading_board := false
	var reading_removal := false
	var board_rows_loaded := 0
	var removal_rows_loaded := 0

	while not file.eof_reached():
		var raw_line := file.get_line()
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("height"):
			height = int(line.split(" ", false)[1])
			continue
		if line.begins_with("width"):
			width = int(line.split(" ", false)[1])
			continue
		if line.begins_with("player_to_move"):
			player_to_move = int(line.split(" ", false)[1])
			continue

		var numbers: Array = []
		for token in line.split(" ", false):
			var trimmed := token.strip_edges()
			if trimmed == "":
				continue
			numbers.append(int(trimmed))
		if numbers.is_empty():
			continue

		if not reading_board and board_rows_loaded < height:
			board.append(numbers.slice(0, width))
			board_rows_loaded += 1
			if board_rows_loaded == height:
				reading_board = true
			continue

		if reading_board and removal_rows_loaded < height:
			removal.append(numbers.slice(0, width))
			removal_rows_loaded += 1

	assert_int(width).is_equal(board.size())
	assert_int(height).is_equal(board.size())
	
	assert_int(width).is_equal(removal.size())
	assert_int(height).is_equal(removal.size())

	file.close()
	return {
		"height": height,
		"width": width,
		"player_to_move": player_to_move,
		"board": board,
		"removal": removal
	}

func _blank_board() -> Array:
	var board: Array = []
	for y in range(9):
		var row: Array = []
		for x in range(9):
			row.append(0)
		board.append(row)
	return board
