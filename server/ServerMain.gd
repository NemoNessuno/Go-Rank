extends Node

const DEFAULT_PORT := 7000
const MAX_CLIENTS := 32

func _ready() -> void:
	var user_repository: UserRepository = $UserRepository
	user_repository.initialize_user_database()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(DEFAULT_PORT, MAX_CLIENTS)

	if error != OK:
		push_error("Server couldn't be started. Error code: %s" % error)
		get_tree().quit(error)
		return

	multiplayer.multiplayer_peer = peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("Server is running on port %d." % DEFAULT_PORT)


func _on_peer_connected(peer_id: int) -> void:
	print("Client connected: %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Client disconnected: %d" % peer_id)

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
