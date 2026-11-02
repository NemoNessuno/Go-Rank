class_name GameBoardFileManager
extends RefCounted

var owner: Control

func attach(board_owner: Control) -> void:
	owner = board_owner

func save_sgf() -> void:
	if owner.save_dialog == null:
		_save_sgf_to_path("user://game.sgf")
		return
	owner.save_dialog.popup_centered()

func load_sgf() -> void:
	if owner.load_dialog == null:
		_load_sgf_from_path("user://game.sgf")
		return
	owner.load_dialog.popup_centered()

func _on_save_dialog_file_selected(path: String) -> void:
	_save_sgf_to_path(path)

func _save_sgf_to_path(path: String) -> void:
	var output := "(;GM[1]FF[4]SZ[9]\n"
	for move in owner.move_log:
		var color_prefix := "B" if move["color"] == owner.BLACK else "W"
		var coordinate := ""
		if move.get("pass", false):
			coordinate = ""
		else:
			coordinate = _board_to_sgf(move["x"], move["y"])
		output += ";%s[%s]\n" % [color_prefix, coordinate]
	output += ")\n"

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		owner._update_status("Could not save SGF file.")
		return
	file.store_string(output)
	owner._update_status("Game saved to SGF.")

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
