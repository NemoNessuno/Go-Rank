class_name TokenStore
extends RefCounted

const TOKEN_PATH := "user://session.cfg"
const SECRET_PATH := "user://token_store.key"
const SECRET_SIZE_BYTES := 32

const SECTION := "session"
const KEY_TOKEN := "token"
const KEY_EMAIL := "email"
const KEY_EXPIRES_AT := "expires_at"

var token_path: String
var secret_path: String

func _init(
	session_path: String = TOKEN_PATH,
	encryption_secret_path: String = SECRET_PATH
) -> void:
	token_path = session_path
	secret_path = encryption_secret_path

func save_session(
	token: String,
	email: String,
	expires_at: int
) -> bool:
	var encryption_password := _load_or_create_secret()
	if encryption_password.is_empty():
		return false

	var config := ConfigFile.new()
	config.set_value(SECTION, KEY_TOKEN, token)
	config.set_value(SECTION, KEY_EMAIL, email)
	config.set_value(SECTION, KEY_EXPIRES_AT, expires_at)

	var error := config.save_encrypted_pass(
		token_path,
		encryption_password
	)

	if error != OK:
		push_error("Session konnte nicht gespeichert werden: %s" % error)
		return false

	return true

func load_session() -> Dictionary:
	if not FileAccess.file_exists(token_path):
		return {}

	var encryption_password := _load_secret()
	if encryption_password.is_empty():
		push_warning("Der Schlüssel für die gespeicherte Session fehlt oder ist ungültig.")
		return {}

	var config := ConfigFile.new()
	var error := config.load_encrypted_pass(token_path, encryption_password)

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
	if FileAccess.file_exists(token_path):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(token_path)
		)

func _load_or_create_secret() -> String:
	if FileAccess.file_exists(secret_path):
		return _load_secret()

	var random_bytes := Crypto.new().generate_random_bytes(SECRET_SIZE_BYTES)
	if random_bytes.size() != SECRET_SIZE_BYTES:
		push_error("Could not generate the TokenStore encryption key.")
		return ""

	var secret := random_bytes.hex_encode()
	var file := FileAccess.open(secret_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the TokenStore encryption key.")
		return ""
	file.store_string(secret)
	file.close()
	if not _restrict_secret_permissions():
		return ""
	return secret

func _load_secret() -> String:
	if not FileAccess.file_exists(secret_path):
		return ""

	var file := FileAccess.open(secret_path, FileAccess.READ)
	if file == null:
		push_error("Could not read the TokenStore encryption key.")
		return ""

	var secret := file.get_as_text().strip_edges()
	if secret.length() != SECRET_SIZE_BYTES * 2:
		return ""
	for character in secret:
		if not character in "0123456789abcdef":
			return ""
	if not _restrict_secret_permissions():
		return ""
	return secret

func _restrict_secret_permissions() -> bool:
	var permissions := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
	var error := FileAccess.set_unix_permissions(
		ProjectSettings.globalize_path(secret_path),
		permissions
	)
	if error == ERR_UNAVAILABLE:
		return true
	if error != OK:
		push_error("Could not restrict TokenStore key file permissions.")
		return false
	return true
