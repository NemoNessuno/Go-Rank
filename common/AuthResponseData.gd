class_name AuthResponseData
extends RefCounted

var success: bool = false
var message: String = ""
var user: UserData

func to_dictionary() -> Dictionary:
	return {
		"success": success,
		"message": message,
		"user": user.to_dictionary() if user != null else {},
	}
