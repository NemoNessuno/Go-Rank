extends Node

signal user_creation_failed(message: String)
signal login_successful(user_data: Dictionary)
signal login_failed(message: String)
signal session_restored(user_data: Dictionary)
signal users_received(users: Array)
signal users_request_failed(message: String)
signal profile_ratings_received(profile: Dictionary)
signal profile_ratings_request_failed(message: String)
signal game_store_successful(response: Dictionary)
signal game_store_failed(message: String)
signal logout_successful

var current_user: UserData
var current_game: GameData
var session_token: String = ""
var current_profile_ratings: Dictionary = {}

func create_user(
	username: String,
	email: String,
	password: String,
	color: String
) -> void:
	request_create_user.rpc_id(1, username, email, password, color)

func login_user(email: String, password: String) -> void:
	request_login_user.rpc_id(1, email, password)

func request_users() -> void:
	request_user_list.rpc_id(1, session_token)

func request_profile_ratings() -> bool:
	if session_token.is_empty() or not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	request_profile_ratings_rpc.rpc_id(1, session_token)
	return true

func store_game(result: int) -> bool:
	if (
		current_game == null
		or session_token.is_empty()
		or not multiplayer.has_multiplayer_peer()
	):
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	var game_data := current_game.to_dictionary()
	game_data["result"] = result
	request_store_game_rpc.rpc_id(1, session_token, game_data)
	return true

func logout() -> bool:
	if session_token.is_empty() or not multiplayer.has_multiplayer_peer():
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	request_logout.rpc_id(1, session_token)
	return true

@rpc("any_peer", "call_remote", "reliable")
func request_create_user(
	username: String,
	email: String,
	password: String,
	color: String
) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var repository: UserRepository = get_tree().root.get_node("ServerMain/UserRepository")

	var user_data: Dictionary = repository.create_user(
		username,
		email,
		password,
		color
	)

	if user_data.is_empty():
		send_user_creation_failed.rpc_id(
			sender_id,
			"User %s with mail %s could not be created." % [username, email]
		)
	else:
		var session: Dictionary = get_tree().root \
			.get_node("ServerMain/SessionManager") \
			.create_session(int(user_data["id"]))
		send_login_successful.rpc_id(
			sender_id,
			{
				"user": user_data,
				"token": session["token"],
				"expires_at": session["expires_at"]
			}
		)

@rpc("any_peer", "call_remote", "reliable")
func request_login_user(email: String, password: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var repository: UserRepository = get_tree().root \
		.get_node("ServerMain/UserRepository")
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")

	var login_response := _create_login_response(
		email,
		password,
		repository,
		session_manager
	)
	if login_response.is_empty():
		send_login_failed.rpc_id(
			sender_id,
            "E-Mail oder Passwort ist ungültig."
		)
		return

	send_login_successful.rpc_id(sender_id, login_response)

func _create_login_response(
	email: String,
	password: String,
	repository: UserRepository,
	session_manager: SessionManager
) -> Dictionary:
	var user: Dictionary = repository.login_user(email, password)
	if user.is_empty():
		return {}

	var session := session_manager.create_session(int(user["id"]))
	return {
		"user": user,
		"token": session["token"],
		"expires_at": session["expires_at"]
	}

@rpc("any_peer", "call_remote", "reliable")
func request_user_list(token: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")
	if session_manager.validate_token(token).is_empty():
		send_users_request_failed.rpc_id(
			sender_id,
			"Your session is no longer valid. Please log in again."
		)
		return

	var repository: UserRepository = get_tree().root \
		.get_node("ServerMain/UserRepository")
	send_users.rpc_id(sender_id, repository.get_users())

@rpc("any_peer", "call_remote", "reliable")
func request_profile_ratings_rpc(token: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")
	var repository: UserRepository = get_tree().root \
		.get_node("ServerMain/UserRepository")
	var profile := _get_profile_ratings(token, session_manager, repository)
	if profile.is_empty():
		send_profile_ratings_request_failed.rpc_id(
			sender_id,
			"Could not load profile ratings. Please log in again."
		)
		return
	send_profile_ratings.rpc_id(sender_id, profile)

@rpc("any_peer", "call_remote", "reliable")
func request_store_game_rpc(token: String, game_data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")
	var repository: UserRepository = get_tree().root \
		.get_node("ServerMain/UserRepository")
	var response := _store_game(token, game_data, session_manager, repository)
	if response.is_empty():
		send_game_store_failed.rpc_id(
			sender_id,
			"Could not store this game. Ensure you are a participant and try again."
		)
		return
	send_game_store_successful.rpc_id(sender_id, response)

func _store_game(
	token: String,
	game_data: Dictionary,
	session_manager: SessionManager,
	repository: UserRepository
) -> Dictionary:
	var session := session_manager.validate_token(token)
	if session.is_empty():
		return {}
	var authenticated_user_id := int(session["user_id"])
	if (
		authenticated_user_id != int(game_data.get("black_player_id", 0))
		and authenticated_user_id != int(game_data.get("white_player_id", 0))
	):
		return {}
	return repository.store_game(game_data)

func _get_profile_ratings(
	token: String,
	session_manager: SessionManager,
	repository: UserRepository
) -> Dictionary:
	var session := session_manager.validate_token(token)
	if session.is_empty():
		return {}
	return repository.get_profile_ratings(int(session["user_id"]))

@rpc("any_peer", "call_remote", "reliable")
func request_restore_session(token: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")
	var repository: UserRepository = get_tree().root \
		.get_node("ServerMain/UserRepository")
	var user_data := _get_restored_user(token, session_manager, repository)
	if user_data.is_empty():
		send_login_failed.rpc_id(
			sender_id,
            "Session nicht gültig. Bitte erneut anmelden!"
		)
		return

	send_session_restored.rpc_id(sender_id, user_data)

func _get_restored_user(
	token: String,
	session_manager: SessionManager,
	repository: UserRepository
) -> Dictionary:
	var session := session_manager.validate_token(token)
	if session.is_empty():
		return {}
	return repository.get_user_by_id(int(session["user_id"]))

@rpc("any_peer", "call_remote", "reliable")
func request_logout(token: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")

	session_manager.revoke_token(token)

	send_logout_successful.rpc_id(sender_id)

@rpc("authority", "call_remote", "reliable")
func send_logout_successful() -> void:
	logout_successful.emit()

@rpc("authority", "call_remote", "reliable")
func send_login_successful(session_data: Dictionary) -> void:
	current_profile_ratings.clear()
	login_successful.emit(session_data)

@rpc("authority", "call_remote", "reliable")
func send_session_restored(user_data: Dictionary) -> void:
	current_profile_ratings.clear()
	session_restored.emit(user_data)

@rpc("authority", "call_remote", "reliable")
func send_users(users: Array) -> void:
	users_received.emit(users)

@rpc("authority", "call_remote", "reliable")
func send_users_request_failed(message: String) -> void:
	users_request_failed.emit(message)

@rpc("authority", "call_remote", "reliable")
func send_profile_ratings(profile: Dictionary) -> void:
	current_profile_ratings = profile
	profile_ratings_received.emit(profile)

@rpc("authority", "call_remote", "reliable")
func send_game_store_successful(response: Dictionary) -> void:
	if current_game != null:
		current_game.id = int(response.get("game_id", current_game.id))
		current_game.result = int(response.get("result", current_game.result))
		var black_profile: Dictionary = response.get("black_profile", {})
		var white_profile: Dictionary = response.get("white_profile", {})
		if current_game.black_player != null and black_profile.has("unified_rating"):
			current_game.black_player.unified_rating = float(
				black_profile["unified_rating"]
			)
		if current_game.white_player != null and white_profile.has("unified_rating"):
			current_game.white_player.unified_rating = float(
				white_profile["unified_rating"]
			)
	game_store_successful.emit(response)

@rpc("authority", "call_remote", "reliable")
func send_game_store_failed(message: String) -> void:
	game_store_failed.emit(message)

@rpc("authority", "call_remote", "reliable")
func send_profile_ratings_request_failed(message: String) -> void:
	profile_ratings_request_failed.emit(message)

@rpc("authority", "call_remote", "reliable")
func send_user_creation_failed(message: String) -> void:
	user_creation_failed.emit(message)

@rpc("authority", "call_remote", "reliable")
func send_login_failed(message: String) -> void:
	login_failed.emit(message)
	
