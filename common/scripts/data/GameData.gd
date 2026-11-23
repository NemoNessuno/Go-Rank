class_name GameData
extends RefCounted

const RESULT_UNDECIDED := -1
const RESULT_DRAW := 0

var id: int = 0
var white_player: UserData
var black_player: UserData
var result: int = RESULT_UNDECIDED

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"white_player_id": white_player.id if white_player != null else 0,
		"black_player_id": black_player.id if black_player != null else 0,
		"result": result,
	}

static func from_dictionary(data: Dictionary) -> GameData:
	var game := GameData.new()
	if data.is_empty():
		return game
	game.id = int(data.get("id", 0))
	var white_player_data: Variant = data.get("white_player", {})
	if typeof(white_player_data) == TYPE_DICTIONARY:
		game.white_player = UserData.from_dictionary(white_player_data)
	var black_player_data: Variant = data.get("black_player", {})
	if typeof(black_player_data) == TYPE_DICTIONARY:
		game.black_player = UserData.from_dictionary(black_player_data)
	game.result = int(data.get("result", RESULT_UNDECIDED))
	return game
