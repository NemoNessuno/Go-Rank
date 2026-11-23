class_name SessionManager
extends Node

const SESSION_DURATION_SECONDS := 365 * 24 * 60 * 60

var _crypto := Crypto.new()
var _sessions := {}

func create_session(user_id: int) -> Dictionary:
	var token := _create_token()
	var now := Time.get_unix_time_from_system()

	_sessions[token] = {
		"user_id": user_id,
		"created_at": now,
		"expires_at": now + SESSION_DURATION_SECONDS
	}

	return {
		"token": token,
		"expires_at": now + SESSION_DURATION_SECONDS
	}

func validate_token(token: String) -> Dictionary:
	if token.is_empty() or not _sessions.has(token):
		return {}

	var session: Dictionary = _sessions[token]
	var now := Time.get_unix_time_from_system()

	if now >= int(session["expires_at"]):
		_sessions.erase(token)
		return {}

	return session


func revoke_token(token: String) -> void:
	_sessions.erase(token)

func _create_token() -> String:
	var random_bytes := _crypto.generate_random_bytes(32)
	return random_bytes.hex_encode()
