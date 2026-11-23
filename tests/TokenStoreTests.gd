class_name TokenStoreTests
extends GdUnitTestSuite

const TokenStoreScript := preload("res://common/scripts/logic/TokenStore.gd")

var _test_paths: Array[String] = []

func after_test() -> void:
	for path in _test_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_test_paths.clear()

func _new_store(name: String) -> TokenStore:
	var token_path := "user://gdunit_%s.session" % name
	var secret_path := "user://gdunit_%s.key" % name
	_test_paths.append(token_path)
	_test_paths.append(secret_path)
	return TokenStoreScript.new(token_path, secret_path)

func _read_secret(store: TokenStore) -> String:
	var file := FileAccess.open(store.secret_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()

func test_save_creates_random_256_bit_key_and_loads_session() -> void:
	var store := _new_store("token_round_trip")
	var expires_at := int(Time.get_unix_time_from_system()) + 3600

	assert_bool(store.save_session("session-token", "alice@example.com", expires_at)).is_true()

	var secret := _read_secret(store)
	assert_int(secret.length()).is_equal(64)
	for character in secret:
		assert_bool(character in "0123456789abcdef").is_true()
	if OS.get_name() == "Linux":
		assert_int(FileAccess.get_unix_permissions(
			ProjectSettings.globalize_path(store.secret_path)
		)).is_equal(FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)

	var reloaded_store := TokenStoreScript.new(store.token_path, store.secret_path)
	var session := reloaded_store.load_session()
	assert_str(session["token"]).is_equal("session-token")
	assert_str(session["email"]).is_equal("alice@example.com")
	assert_int(int(session["expires_at"])).is_equal(expires_at)

func test_missing_session_returns_empty_without_creating_key() -> void:
	var store := _new_store("missing_session")

	assert_that(store.load_session()).is_empty()
	store.clear_session()
	assert_bool(FileAccess.file_exists(store.secret_path)).is_false()

func test_expired_session_is_removed_but_encryption_key_is_kept() -> void:
	var store := _new_store("expired_session")
	assert_bool(store.save_session(
		"expired-token",
		"alice@example.com",
		int(Time.get_unix_time_from_system()) - 1
	)).is_true()

	assert_that(store.load_session()).is_empty()
	assert_bool(FileAccess.file_exists(store.token_path)).is_false()
	assert_bool(FileAccess.file_exists(store.secret_path)).is_true()

func test_clear_session_removes_session_and_preserves_key() -> void:
	var store := _new_store("clear_session")
	assert_bool(store.save_session(
		"session-token",
		"alice@example.com",
		int(Time.get_unix_time_from_system()) + 3600
	)).is_true()
	var secret_before_clear := _read_secret(store)

	store.clear_session()

	assert_bool(FileAccess.file_exists(store.token_path)).is_false()
	assert_str(_read_secret(store)).is_equal(secret_before_clear)
	assert_that(store.load_session()).is_empty()

func test_invalid_encryption_key_does_not_load_session() -> void:
	var store := _new_store("invalid_key")
	assert_bool(store.save_session(
		"session-token",
		"alice@example.com",
		int(Time.get_unix_time_from_system()) + 3600
	)).is_true()
	var key_file := FileAccess.open(store.secret_path, FileAccess.WRITE)
	key_file.store_string("invalid-key")
	key_file.close()

	assert_bool(store.save_session(
		"replacement-token",
		"alice@example.com",
		int(Time.get_unix_time_from_system()) + 3600
	)).is_false()
	assert_that(store.load_session()).is_empty()

func test_missing_encryption_key_does_not_load_session() -> void:
	var store := _new_store("missing_key")
	assert_bool(store.save_session(
		"session-token",
		"alice@example.com",
		int(Time.get_unix_time_from_system()) + 3600
	)).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.secret_path))

	assert_that(store.load_session()).is_empty()

func test_empty_token_is_discarded() -> void:
	var store := _new_store("empty_token")
	assert_bool(store.save_session(
		"",
		"alice@example.com",
		int(Time.get_unix_time_from_system()) + 3600
	)).is_true()

	assert_that(store.load_session()).is_empty()
	assert_bool(FileAccess.file_exists(store.token_path)).is_false()
