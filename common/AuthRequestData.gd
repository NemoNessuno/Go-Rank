class_name AuthRequestData
extends RefCounted

var email: String = ""
var password: String = ""

func to_dictionary() -> Dictionary:
	return {
		"email": email,
		"password": password
	}
