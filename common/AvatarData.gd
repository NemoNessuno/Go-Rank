class_name AvatarData
extends RefCounted

var id: int = 0
var color: String = "#000000"

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"color": color,
	}

static func from_dictionary(data: Dictionary) -> AvatarData:
	var avatar := AvatarData.new()
	if data.is_empty():
		return avatar
	avatar.id = int(data.get("id", 0))
	avatar.color = String(data.get("color", "#000000"))
	return avatar
