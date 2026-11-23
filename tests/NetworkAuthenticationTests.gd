class_name NetworkAuthenticationTests
extends GdUnitTestSuite

const NetworkScript := preload("res://common/Network.gd")
const SessionManagerScript := preload("res://server/SessionManager.gd")
const UserDatabaseScript := preload("res://server/UserDatabase.gd")
const UserRepositoryScript := preload("res://server/UserRepository.gd")

func _new_network() -> Node:
	var network: Node = NetworkScript.new()
	add_child(network)
	return auto_free(network)

func _create_repository_fixture(db_name: String) -> Dictionary:
	var db_path := "user://%s.sqlite" % db_name
	var absolute_path := ProjectSettings.globalize_path(db_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var db := UserDatabaseScript.create_database(db_path)
	UserDatabaseScript.create_user_with_avatar_transaction(
		db,
		"Alice",
		"alice@example.com",
		"correct-password",
		"#00FF00"
	)
	var repository: UserRepository = UserRepositoryScript.new()
	repository.database = db
	return {"database": db, "repository": repository}

func _close_repository_fixture(fixture: Dictionary) -> void:
	fixture["repository"].free()
	UserDatabaseScript.close_database(fixture["database"])

func test_login_response_creates_session_for_valid_credentials() -> void:
	var network := _new_network()
	var fixture := _create_repository_fixture("gdunit_network_login")
	var manager: SessionManager = auto_free(SessionManagerScript.new())

	var response: Dictionary = network._create_login_response(
		"alice@example.com",
		"correct-password",
		fixture["repository"],
		manager
	)

	assert_str(response["user"]["name"]).is_equal("Alice")
	assert_bool(String(response["token"]).is_empty()).is_false()
	assert_int(int(manager.validate_token(response["token"])["user_id"])).is_equal(
		int(response["user"]["id"])
	)
	_close_repository_fixture(fixture)

func test_login_response_rejects_bad_password_and_unknown_email() -> void:
	var network := _new_network()
	var fixture := _create_repository_fixture("gdunit_network_login_failure")
	var manager: SessionManager = auto_free(SessionManagerScript.new())

	assert_that(network._create_login_response(
		"alice@example.com",
		"wrong-password",
		fixture["repository"],
		manager
	)).is_empty()
	assert_that(network._create_login_response(
		"missing@example.com",
		"correct-password",
		fixture["repository"],
		manager
	)).is_empty()
	assert_int(manager._sessions.size()).is_equal(0)
	_close_repository_fixture(fixture)

func test_session_restore_returns_user_for_valid_token() -> void:
	var network := _new_network()
	var fixture := _create_repository_fixture("gdunit_network_restore")
	var manager: SessionManager = auto_free(SessionManagerScript.new())
	var user: Dictionary = fixture["repository"].login_user(
		"alice@example.com",
		"correct-password"
	)
	var session := manager.create_session(int(user["id"]))

	var restored_user: Dictionary = network._get_restored_user(
		session["token"],
		manager,
		fixture["repository"]
	)

	assert_int(int(restored_user["id"])).is_equal(int(user["id"]))
	_close_repository_fixture(fixture)

func test_session_restore_rejects_unknown_and_expired_tokens() -> void:
	var network := _new_network()
	var fixture := _create_repository_fixture("gdunit_network_restore_failure")
	var manager: SessionManager = auto_free(SessionManagerScript.new())
	var session := manager.create_session(1)
	var missing_user_session := manager.create_session(999)
	manager._sessions[session["token"]]["expires_at"] = 0

	assert_that(network._get_restored_user(
		"unknown-token",
		manager,
		fixture["repository"]
	)).is_empty()
	assert_that(network._get_restored_user(
		session["token"],
		manager,
		fixture["repository"]
	)).is_empty()
	assert_that(network._get_restored_user(
		missing_user_session["token"],
		manager,
		fixture["repository"]
	)).is_empty()
	_close_repository_fixture(fixture)

func test_profile_ratings_are_returned_only_for_a_valid_session() -> void:
	var network := _new_network()
	var fixture := _create_repository_fixture("gdunit_network_profile_ratings")
	var manager: SessionManager = auto_free(SessionManagerScript.new())
	var user: Dictionary = fixture["repository"].login_user(
		"alice@example.com",
		"correct-password"
	)
	var session := manager.create_session(int(user["id"]))

	var profile: Dictionary = network._get_profile_ratings(
		session["token"],
		manager,
		fixture["repository"]
	)

	assert_float(float(profile["unified_rating"])).is_equal_approx(525.0, 0.000001)
	assert_int(int(profile["games_played"])).is_equal(0)
	assert_that(network._get_profile_ratings(
		"invalid-token",
		manager,
		fixture["repository"]
	)).is_empty()
	_close_repository_fixture(fixture)

func test_profile_rating_response_updates_cache_and_emits_signal() -> void:
	var network := _new_network()
	var profile := {
		"categories": {"9x9": {"rating": 525.0, "games_played": 0}},
		"unified_rating": 525.0,
		"games_played": 0
	}
	var received: Array[Dictionary] = []
	network.profile_ratings_received.connect(
		func(data: Dictionary) -> void: received.append(data)
	)

	network.send_profile_ratings(profile)

	assert_dict(network.current_profile_ratings).is_equal(profile)
	assert_array(received).contains([profile])

func test_login_success_response_is_forwarded_to_client_signal() -> void:
	var network := _new_network()
	var received: Array[Dictionary] = []
	var response := {
		"user": {"id": 7, "name": "Alice"},
		"token": "session-token",
		"expires_at": 1234
	}
	network.login_successful.connect(func(data: Dictionary) -> void: received.append(data))

	network.send_login_successful(response)

	assert_int(received.size()).is_equal(1)
	assert_dict(received[0]).is_equal(response)

func test_login_failure_response_is_forwarded_to_client_signal() -> void:
	var network := _new_network()
	var received: Array[String] = []
	network.login_failed.connect(func(message: String) -> void: received.append(message))

	network.send_login_failed("Invalid credentials.")

	assert_array(received).contains(["Invalid credentials."])

func test_session_restore_response_is_forwarded_to_client_signal() -> void:
	var network := _new_network()
	var received: Array[Dictionary] = []
	var user_data := {"id": 7, "name": "Alice"}
	network.session_restored.connect(func(data: Dictionary) -> void: received.append(data))

	network.send_session_restored(user_data)

	assert_int(received.size()).is_equal(1)
	assert_dict(received[0]).is_equal(user_data)

func test_logout_confirmation_is_forwarded_to_client_signal() -> void:
	var network := _new_network()
	var received: Array[bool] = []
	network.logout_successful.connect(func() -> void: received.append(true))

	network.send_logout_successful()

	assert_array(received).contains([true])

func test_logout_without_session_token_is_rejected() -> void:
	var network := _new_network()
	network.session_token = ""

	assert_bool(network.logout()).is_false()

func test_logout_without_connected_peer_is_rejected() -> void:
	var network := _new_network()
	var previous_peer := network.multiplayer.multiplayer_peer
	network.session_token = "session-token"
	network.multiplayer.multiplayer_peer = null

	var logout_started: bool = network.logout()

	network.multiplayer.multiplayer_peer = previous_peer
	assert_bool(logout_started).is_false()
