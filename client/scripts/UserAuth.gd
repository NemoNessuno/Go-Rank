extends Control

var create_mode := true
var token_store: TokenStore

const SERVER_ADDRESS := "127.0.0.1"
const SERVER_PORT := 7000

const NEUTRAL_COLOR := Color(0.8, 0.8, 0.8, 1.0)
const OK_COLOR := Color(0.35, 1.0, 0.6, 1.0)
const SIGNAL_COLOR := Color(1.0, 0.7, 0.2, 1.0)
const ERROR_COLOR := Color(1.0, 0.35, 0.35, 1.0)

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var name_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/NameEdit
@onready var email_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/EmailEdit
@onready var password_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/PasswordEdit
@onready var submit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SubmitButton
@onready var toggle_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ToggleModeButton
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var remember_checkbox : CheckBox = $PanelContainer/MarginContainer/VBoxContainer/RememberMeCheckBox

func _ready() -> void:
	token_store = TokenStore.new()
	
	Network.user_creation_failed.connect(_on_user_creation_failed)
	Network.login_successful.connect(_on_login_successful)
	Network.login_failed.connect(_on_login_failed)
	Network.session_restored.connect(_on_session_restored)
	
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(SERVER_ADDRESS, SERVER_PORT)

	if error != OK:
		_set_status("Connection failed. Error code: %s" % error, ERROR_COLOR)
		return
	
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting to server …", NEUTRAL_COLOR)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(func(): _set_status("Disonnected from server.", SIGNAL_COLOR))
	
	_sync_ui_mode()

func _on_connected_to_server() -> void:
	_set_status("Connected to server.", OK_COLOR)

	var session := token_store.load_session()

	if not session.is_empty():
		Network.session_token = String(session["token"])
		Network.request_restore_session.rpc_id(
			1,
			session["token"]
		)
	else:
		_set_status("Bitte anmelden.", NEUTRAL_COLOR)

func _on_login_successful(response: Dictionary) -> void:
	var user: Dictionary = response["user"]
	var token: String = response["token"]
	var expires_at: int = int(response["expires_at"])
	Network.current_user = UserData.from_dictionary(user)
	Network.session_token = token
	Network.current_profile_ratings.clear()

	if remember_checkbox.button_pressed:
		token_store.save_session(
			token,
			String(user["email"]),
			expires_at
		)
	else:
		token_store.clear_session()

	_set_status("Login erfolgreich.", OK_COLOR)
	get_tree().change_scene_to_file("res://client/scenes/Overworld.tscn")
	
func _on_session_restored(user_data: Dictionary) -> void:
	Network.current_user = UserData.from_dictionary(user_data)
	Network.current_profile_ratings.clear()
	_set_status("Login erfolgreich.", OK_COLOR)
	get_tree().change_scene_to_file("res://client/scenes/Overworld.tscn")

func _sync_ui_mode() -> void:
	name_edit.visible = create_mode
	name_edit.editable = create_mode
	if create_mode:
		title_label.text = "Create account"
		submit_button.text = "Create account"
		toggle_button.text = "Already have an account? Log in"
	else:
		title_label.text = "Log in"
		submit_button.text = "Log in"
		toggle_button.text = "Need an account? Register"

func _set_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color

func _generate_avatar_color(user_name: String) -> String:
	var hash_value := 0
	for index in range(user_name.length()):
		hash_value = (hash_value * 131 + ord(user_name[index])) & 0xFFFFFFFF
	var hue := float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.7, 0.9).to_html()

func _on_submit_button_pressed() -> void:
	if multiplayer == null or not multiplayer.connected_to_server:
		_set_status("The server is unavailable.", ERROR_COLOR)
		return

	var email := email_edit.text.strip_edges()
	var password := password_edit.text
	if email.is_empty() or password.is_empty():
		_set_status("Please enter your email and password.", SIGNAL_COLOR)
		return

	if create_mode:
		var user_name := name_edit.text.strip_edges()
		if user_name.is_empty():
			_set_status("Please enter a display name.", SIGNAL_COLOR)
			return
		Network.create_user(
		user_name, email, password, _generate_avatar_color(user_name))
		return

	Network.login_user(email, password)

func _on_toggle_mode_button_pressed() -> void:
	create_mode = not create_mode
	_sync_ui_mode()

func _on_user_creation_failed(message: String) -> void:
	_set_status(message, ERROR_COLOR)

func _on_login_failed(message: String) -> void:
	_set_status(message, ERROR_COLOR)
