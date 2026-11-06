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
		send_user_data.rpc_id(sender_id, user_data)

@rpc("any_peer", "call_remote", "reliable")
func request_login_user(email: String, password: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var repository: UserRepository = get_tree().root.get_node("ServerMain/UserRepository")

	var user_data: Dictionary = repository.login_user(email, password)

	if user_data.is_empty():
		send_user_authentication_failed.rpc_id(
			sender_id,
			"User %s could not be logged in." % email
		)
	else:
		send_user_data.rpc_id(sender_id, user_data)

@rpc("authority", "call_remote", "reliable")
func send_user_data(user_data: Dictionary) -> void:
	login_successful.emit(user_data)

@rpc("authority", "call_remote", "reliable")
func send_user_creation_failed(message: String) -> void:
	user_creation_failed.emit(message)

@rpc("authority", "call_remote", "reliable")
func send_user_authentication_failed(message: String) -> void:
	login_failed.emit(message)
