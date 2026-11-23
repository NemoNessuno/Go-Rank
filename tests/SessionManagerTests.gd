class_name SessionManagerTests
extends GdUnitTestSuite

const SessionManagerScript := preload("res://server/scripts/session/SessionManager.gd")

func test_create_session_returns_valid_token_and_expiration() -> void:
	var manager: SessionManager = auto_free(SessionManagerScript.new())

	var created := manager.create_session(42)
	var session := manager.validate_token(created["token"])

	assert_bool(String(created["token"]).is_empty()).is_false()
	assert_int(int(created["expires_at"])).is_greater(Time.get_unix_time_from_system())
	assert_int(int(session["user_id"])).is_equal(42)

func test_empty_and_unknown_tokens_are_invalid() -> void:
	var manager: SessionManager = auto_free(SessionManagerScript.new())

	assert_that(manager.validate_token("")).is_empty()
	assert_that(manager.validate_token("unknown-token")).is_empty()

func test_expired_token_is_rejected_and_removed() -> void:
	var manager: SessionManager = auto_free(SessionManagerScript.new())
	var created := manager.create_session(42)
	manager._sessions[created["token"]]["expires_at"] = 0

	assert_that(manager.validate_token(created["token"])).is_empty()
	assert_bool(manager._sessions.has(created["token"])).is_false()

func test_revoked_token_is_invalid() -> void:
	var manager: SessionManager = auto_free(SessionManagerScript.new())
	var created := manager.create_session(42)

	manager.revoke_token(created["token"])

	assert_that(manager.validate_token(created["token"])).is_empty()

func test_revoking_unknown_token_is_safe() -> void:
	var manager: SessionManager = auto_free(SessionManagerScript.new())

	manager.revoke_token("unknown-token")

	assert_that(manager.validate_token("unknown-token")).is_empty()
