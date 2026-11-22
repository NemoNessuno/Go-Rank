extends Node

signal user_creation_failed(message: String)
signal login_successful(user_data: Dictionary)
signal login_failed(message: String)

func create_user(
	username: String,
	email: String,
	password: String,
	color: String
) -> void:
	request_create_user.rpc_id(1, username, email, password, color)

func login_user(email: String, password: String) -> void:
	request_login_user.rpc_id(1, email, password)

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
		send_login_successful.rpc_id(sender_id, user_data)

@rpc("any_peer", "call_remote", "reliable")
func request_login_user(email: String, password: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var repository: UserRepository = get_tree().root \
		.get_node("ServerMain/UserRepository")

	var user: Dictionary = repository.authenticate_user(email, password)

	if user.is_empty():
		send_login_failed.rpc_id(
			sender_id,
            "E-Mail oder Passwort ist ungültig."
		)
		return

	var session: Dictionary = get_tree().root \
		.get_node("ServerMain/SessionManager") \
		.create_session(int(user["id"]))

	send_login_successful.rpc_id(
		sender_id,
		{
			"user": user,
			"token": session["token"],
			"expires_at": session["expires_at"]
		}
	)

@rpc("any_peer", "call_remote", "reliable")
func request_protected_data(token: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")

	var session: Dictionary = session_manager.validate_token(token)

	if session.is_empty():
		send_authentication_required.rpc_id(sender_id)
		return

	var repository: UserRepository = get_tree().root \
		.get_node("ServerMain/UserRepository")

	var user_data: Dictionary = repository.get_user_by_id(
		int(session["user_id"])
	)

	send_protected_data.rpc_id(sender_id, user_data)

@rpc("any_peer", "call_remote", "reliable")
func request_logout(token: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var session_manager: SessionManager = get_tree().root \
		.get_node("ServerMain/SessionManager")

	session_manager.revoke_token(token)

	send_logout_successful.rpc_id(sender_id)

@rpc("authority", "call_remote", "reliable")
func send_logout_successful() -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func send_authentication_required() -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func send_protected_data(user_data: Dictionary) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func send_login_successful(user_data: Dictionary) -> void:
	login_successful.emit(user_data)

@rpc("authority", "call_remote", "reliable")
func send_user_creation_failed(message: String) -> void:
	user_creation_failed.emit(message)

@rpc("authority", "call_remote", "reliable")
func send_login_failed(message: String) -> void:
	login_failed.emit(message)
