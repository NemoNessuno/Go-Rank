class_name TokenStore
extends RefCounted

const TOKEN_PATH := "user://session.cfg"
const ENCRYPTION_PASSWORD := "change-this-to-a-long-random-secret"

const SECTION := "session"
const KEY_TOKEN := "token"
const KEY_EMAIL := "email"
const KEY_EXPIRES_AT := "expires_at"

func save_session(
	token: String,
	email: String,
	expires_at: int
) -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY_TOKEN, token)
	config.set_value(SECTION, KEY_EMAIL, email)
	config.set_value(SECTION, KEY_EXPIRES_AT, expires_at)

	var error := config.save_encrypted_pass(
		TOKEN_PATH,
		ENCRYPTION_PASSWORD
	)

	if error != OK:
		push_error("Session konnte nicht gespeichert werden: %s" % error)
		return false

	return true

func load_session() -> Dictionary:
	var config := ConfigFile.new()

	if not FileAccess.file_exists(TOKEN_PATH):
		return {}

	var error := config.load_encrypted_pass(
		TOKEN_PATH,
		ENCRYPTION_PASSWORD
	)

	if error != OK:
		push_warning("Gespeicherte Session konnte nicht gelesen werden.")
		return {}

	var token := String(config.get_value(SECTION, KEY_TOKEN, ""))
	var email := String(config.get_value(SECTION, KEY_EMAIL, ""))
	var expires_at := int(config.get_value(SECTION, KEY_EXPIRES_AT, 0))

	if token.is_empty() or expires_at <= Time.get_unix_time_from_system():
		clear_session()
		return {}

	return {
		"token": token,
		"email": email,
		"expires_at": expires_at
	}

func clear_session() -> void:
	if FileAccess.file_exists(TOKEN_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(TOKEN_PATH)
		)
