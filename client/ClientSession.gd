class_name ClientSession
extends RefCounted

var connected: bool = false
var current_user: UserData
var user_ids: Array[int]

func connect_to_server(server_address: String, port: int) -> bool:
	# Placeholder for a future client connection implementation.
	# This will later connect to the server using a socket or HTTP layer.
	connected = true
	return connected

func login(email: String) -> AuthResponseData:
	var response := AuthResponseData.new()
	response.success = false
	response.message = "Client login is not implemented yet."
	return response
