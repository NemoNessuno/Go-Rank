class_name UserData
extends RefCounted

var id: int = 0
var name: String = ""
var email: String = ""
var avatar: AvatarData
var game_id: int = -1

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"email": email,
		"avatar_id": avatar.id,
		"game_id": game_id,
	}

static func from_dictionary(data: Dictionary) -> UserData:
	var user := UserData.new()
	if data.is_empty():
		return user
	user.id = int(data.get("id", 0))
	user.name = String(data.get("name", ""))
	user.email = String(data.get("email", ""))
	user.avatar = data.get("avatar", null)
	user.game = data.get("game", null)
	return user
