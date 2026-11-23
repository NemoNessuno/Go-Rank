class_name UserData
extends RefCounted

var id: int = 0
var name: String = ""
var email: String = ""
var avatar: AvatarData
var game_id: int = -1
var unified_rating: float = 525.0

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"email": email,
		"avatar_id": avatar.id if avatar != null else 0,
		"game_id": game_id,
		"unified_rating": unified_rating,
	}

static func from_dictionary(data: Dictionary) -> UserData:
	var user := UserData.new()
	if data.is_empty():
		return user
	user.id = int(data.get("id", 0))
	user.name = String(data.get("name", ""))
	user.email = String(data.get("email", ""))
	var avatar_data: Dictionary = data.get("avatar", {})
	if not avatar_data.is_empty():
		user.avatar = AvatarData.from_dictionary(avatar_data)
	elif data.has("avatar_id"):
		user.avatar = AvatarData.new()
		user.avatar.id = int(data.get("avatar_id", 0))
		user.avatar.color = String(data.get("avatar_color", "#000000"))
	user.game_id = int(data.get("game_id", -1))
	user.unified_rating = float(data.get("unified_rating", 525.0))
	return user
