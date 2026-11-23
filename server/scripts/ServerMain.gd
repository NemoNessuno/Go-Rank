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
