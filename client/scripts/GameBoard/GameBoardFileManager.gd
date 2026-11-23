class_name GameBoardFileManager
extends RefCounted

const RatingSystemScript := preload("res://server/scripts/ratings/RatingSystem.gd")

var owner: Control
var last_saved_path := ""

func attach(board_owner: Control) -> void:
	owner = board_owner

func load_sgf() -> void:
	if owner.load_dialog == null:
		_load_sgf_from_path("user://game.sgf")
		return
	owner.load_dialog.popup_centered()

func write_game_sgf() -> String:
	var black := _player_name(GameBoardState.BLACK)
	var white := _player_name(GameBoardState.WHITE)
	if last_saved_path.is_empty():
		var timestamp := "%d_%d" % [
			int(Time.get_unix_time_from_system()),
			Time.get_ticks_usec()
		]
		last_saved_path = "user://%s_%s_%s.sgf" % [
			timestamp,
			_sanitize_filename_component(black),
			_sanitize_filename_component(white)
		]

	var output := "(;GM[1]FF[4]SZ[9]PB[%s]PW[%s]" % [
		_escape_sgf_value(black),
		_escape_sgf_value(white)
	]
	var black_player: UserData = owner._player_data(GameBoardState.BLACK)
	var white_player: UserData = owner._player_data(GameBoardState.WHITE)
	if black_player != null:
		output += "BR[%s]" % RatingSystemScript.format_rank_label(
			black_player.unified_rating
		)
	if white_player != null:
		output += "WR[%s]" % RatingSystemScript.format_rank_label(
			white_player.unified_rating
		)
	if owner.state.game_over:
		var result: int = owner._get_game_result()
		if result == GameData.RESULT_DRAW:
			output += "RE[0]"
		elif result == GameData.RESULT_UNDECIDED:
			output += "RE[?]"
		elif (
			black_player != null
			and result == black_player.id
		):
			var score: Dictionary = owner._calculate_final_score()
			output += "RE[B+%s]" % owner._format_score_value(
				abs(score["black"] - score["white"])
			)
		elif white_player != null and result == white_player.id:
			var score: Dictionary = owner._calculate_final_score()
			output += "RE[W+%s]" % owner._format_score_value(
				abs(score["black"] - score["white"])
			)
		else:
			output += "RE[?]"
	else:
		output += "RE[?]"
	output += "\n"
	for move in owner.move_log:
		var color_prefix := "B" if move["color"] == owner.BLACK else "W"
		var coordinate := ""
		if move.get("pass", false):
			coordinate = ""
		else:
			coordinate = _board_to_sgf(move["x"], move["y"])
		output += ";%s[%s]\n" % [color_prefix, coordinate]
	output += ")\n"

	var file := FileAccess.open(last_saved_path, FileAccess.WRITE)
	if file == null:
		owner._update_status("Could not save SGF file to %s." % last_saved_path)
		return ""
	file.store_string(output)
	return last_saved_path

func _player_name(color: int) -> String:
	return owner._player_name(color)

func _sanitize_filename_component(value: String) -> String:
	var safe_value := value.strip_edges().to_ascii_buffer().get_string_from_ascii()
	var pattern := RegEx.new()
	pattern.compile("[^A-Za-z0-9_-]+")
	safe_value = pattern.sub(safe_value, "_", true).strip_edges()
	while safe_value.begins_with("_"):
		safe_value = safe_value.substr(1)
	while safe_value.ends_with("_"):
		safe_value = safe_value.substr(0, safe_value.length() - 1)
	return safe_value if not safe_value.is_empty() else "player"

func _escape_sgf_value(value: String) -> String:
	return value.replace("\\", "\\\\").replace("]", "\\]").replace("\r", " ").replace("\n", " ")

func _on_load_dialog_file_selected(path: String) -> void:
	_load_sgf_from_path(path)

func _load_sgf_from_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		owner._update_status("SGF file not found.")
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		owner._update_status("Could not open SGF file.")
		return

	var contents := file.get_as_text()
	var parsed_moves := _parse_sgf_moves(contents)
	if parsed_moves.is_empty():
		owner._update_status("No moves found in SGF.")
		return

	owner._reset_board()
	for move in parsed_moves:
		if move["pass"]:
			owner._on_pass_pressed()
		else:
			owner._play_move(move["x"], move["y"]) 
	if Network.current_game != null:
		Network.current_game.id = 0
		Network.current_game.result = GameData.RESULT_UNDECIDED

	owner._update_status("Loaded SGF game.")

func _parse_sgf_moves(contents: String) -> Array:
	var result: Array = []
	var text := contents.strip_edges()
	if text == "":
		return result
	var start := text.find("(")
	if start >= 0:
		text = text.substr(start + 1)
	var end := text.rfind(")")
	if end >= 0:
		text = text.substr(0, end)

	var token_pattern := RegEx.new()
	token_pattern.compile("[;]([BW])\\[([^\\]]*)\\]")
	var matches := token_pattern.search_all(text)
	for match in matches:
		var color_token := match.get_string(1)
		var value := match.get_string(2)
		var move_color : Color = owner.BLACK if color_token == "B" else owner.WHITE
		var move_x := -1
		var move_y := -1
		var is_pass := value == ""
		if not is_pass:
			move_x = _sgf_to_board_x(value)
			move_y = _sgf_to_board_y(value)
		result.append({"color": move_color, "x": move_x, "y": move_y, "pass": is_pass})
	return result

func _board_to_sgf(x: int, y: int) -> String:
	var first := char(97 + x)
	var second := char(97 + y)
	return "%s%s" % [first, second]

func _sgf_to_board_x(value: String) -> int:
	if value.length() < 2:
		return -1
	return int(value.substr(0, 1).to_ascii_buffer()[0]) - 97

func _sgf_to_board_y(value: String) -> int:
	if value.length() < 2:
		return -1
	return int(value.substr(1, 1).to_ascii_buffer()[0]) - 97
