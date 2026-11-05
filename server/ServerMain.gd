extends Node

const DEFAULT_PORT := 7000
const MAX_CLIENTS := 32

var _peer : ENetMultiplayerPeer

func _ready() -> void:
	
	var user_repository: UserRepository = $UserRepository
	user_repository.initialize_user_database()

	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(DEFAULT_PORT, MAX_CLIENTS)

	if error != OK:
		push_error("Server couldn't be started. Error code: %s" % error)
		get_tree().quit(error)
		return

	multiplayer.multiplayer_peer = _peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("Server is running on port %d." % DEFAULT_PORT)

func _on_peer_connected(peer_id: int) -> void:
	print("Client connected: %d" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Client disconnected: %d" % peer_id)
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_shutdown_server()
		NOTIFICATION_EXIT_TREE:
			_shutdown_server()
		
func _shutdown_server() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
		
	multiplayer.multiplayer_peer = null

@rpc("any_peer", "call_remote", "reliable")
func request_create_user(username: String, email: String, password: String, color: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var user_data : Dictionary = $UserRepository.create_user(username, email, password, color)
	
	if user_data.is_empty():
		send_user_creation_failed.rpc_id(
			sender_id,
			"User %s with mail: %s could not be created", username, email
		)
	else:
		send_user_data.rpc_id(sender_id, user_data)

@rpc("authority", "call_remote", "reliable")
func send_user_creation_failed(message: String) -> void:
	pass
	
@rpc("any_peer", "call_remote", "reliable")
func request_login_user(email: String, password: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var user_data : Dictionary = $UserRepository.login_user(email, password)
	
	if user_data.is_empty():
		send_user_authentication_failed.rpc_id(
			sender_id,
			"User %s could not be logged in", email
		)
	else:
		send_user_data.rpc_id(sender_id, user_data)

@rpc("authority", "call_remote", "reliable")
func send_user_authentication_failed(message: String) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func request_user_data(username: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var repository: UserRepository = $UserRepository

	var user_data : UserData = repository.get_user_data(username)

	if user_data.is_empty():
		send_user_not_found.rpc_id(sender_id, username)
	else:
		send_user_data.rpc_id(sender_id, user_data)

@rpc("authority", "call_remote", "reliable")
func send_user_data(user_data: Dictionary) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func send_user_not_found(username: String) -> void:
	pass
