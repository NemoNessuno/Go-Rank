class_name GameData
extends RefCounted

var id: int = 0
var white_player: UserData
var black_player: UserData
var result: int = 0

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"white_player_id": white_player.id,
		"black_player_id": black_player.id,
		"result": result,
	}

static func from_dictionary(data: Dictionary) -> GameData:
	var game := GameData.new()
	if data.is_empty():
		return game
	game.id = int(data.get("id", 0))
	game.white_player = data.get("white_player", null)
	game.black_player_id = data.get("black_player", null)
	game.result = int(data.get("result", 0))
	return game
