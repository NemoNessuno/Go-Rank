extends Control

@onready var map_panel: Panel = $MapPanel
@onready var sidebar: Panel = $Sidebar

var users: Array[UserData] = []
var selected_user: UserData
var user_buttons: Array[Button] = []
var status_label: Label
var selected_user_label: Label
var start_game_button: Button
var logout_button: Button

func _ready() -> void:
	_build_sidebar()
	_ensure_world_container()
	Network.users_received.connect(_on_users_received)
	Network.users_request_failed.connect(_on_users_request_failed)
	Network.logout_successful.connect(_on_logout_successful)

	if Network.current_user == null:
		status_label.text = "Please log in to view available players."
		logout_button.disabled = true
		return

	status_label.text = "Loading players..."
	Network.request_users()

func _on_users_request_failed(message: String) -> void:
	status_label.text = message

func _build_sidebar() -> void:
	var content := VBoxContainer.new()
	content.name = "SidebarContent"
	content.position = Vector2(18, 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	sidebar.add_child(content)

	var title := Label.new()
	title.text = "Go Academy"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(1.0, 0.8, 0.4)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose an opponent"
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

	selected_user_label = Label.new()
	selected_user_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_user_label.custom_minimum_size = Vector2(200, 80)
	selected_user_label.text = "Select a player to start a game."
	content.add_child(selected_user_label)

	start_game_button = Button.new()
	start_game_button.text = "Open 9x9 Go board"
	start_game_button.disabled = true
	start_game_button.pressed.connect(_on_start_game_pressed)
	start_game_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(start_game_button)

	logout_button = Button.new()
	logout_button.text = "Log out"
	logout_button.pressed.connect(_on_logout_pressed)
	logout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(logout_button)

func _ensure_world_container() -> Control:
	var existing := map_panel.get_node_or_null("WorldContainer")
	if existing != null:
		return existing

	var container := Control.new()
	container.name = "WorldContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	map_panel.add_child(container)
	return container

func _on_users_received(user_data_list: Array) -> void:
	users.clear()
	for user_data in user_data_list:
		if typeof(user_data) != TYPE_DICTIONARY:
			continue
		var user := UserData.from_dictionary(user_data)
		if user.id != Network.current_user.id:
			users.append(user)

	selected_user = null
	_render_users()
	if users.is_empty():
		status_label.text = "No other players are available."
	else:
		status_label.text = "Select another player to start a game."
	_update_selected_user()

func _render_users() -> void:
	var world_container := _ensure_world_container()
	for button in user_buttons:
		if is_instance_valid(button):
			button.queue_free()
	user_buttons.clear()

	for index in range(users.size()):
		var user := users[index]
		var button := Button.new()
		button.name = "UserButton_%d" % user.id
		button.custom_minimum_size = Vector2(170, 60)
		button.position = Vector2(30 + (index % 3) * 190, 30 + (index / 3) * 90)
		button.size = Vector2(170, 70)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.text = user.name
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_user_button_pressed.bind(index))

		var style := StyleBoxFlat.new()
		style.bg_color = Color(user.avatar.color) if user.avatar != null else Color("#4ec9f5")
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.corner_radius_bottom_left = 20
		style.corner_radius_bottom_right = 20
		style.border_color = Color(1, 1, 1, 0.35)
		style.set_border_width_all(2)
		if user == selected_user:
			style.border_color = Color(1, 0.88, 0.2, 1)
			style.set_border_width_all(3)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)

		world_container.add_child(button)
		user_buttons.append(button)

func _on_user_button_pressed(index: int) -> void:
	if index < 0 or index >= users.size():
		return
	selected_user = users[index]
	_render_users()
	_update_selected_user()

func _update_selected_user() -> void:
	if selected_user == null:
		selected_user_label.text = "Select a player to start a game."
		start_game_button.disabled = true
		return

	selected_user_label.text = "Opponent: %s\nEmail: %s" % [
		selected_user.name,
		selected_user.email
	]
	start_game_button.disabled = selected_user.id == Network.current_user.id

func _on_start_game_pressed() -> void:
	if Network.current_user == null or selected_user == null:
		return
	if selected_user.id == Network.current_user.id:
		status_label.text = "You cannot start a game against yourself."
		start_game_button.disabled = true
		return

	get_tree().change_scene_to_file("res://client/scenes/GameBoard.tscn")

func _on_logout_pressed() -> void:
	if not Network.logout():
		status_label.text = "Unable to log out while disconnected from the server."
		return

	logout_button.disabled = true
	status_label.text = "Logging out..."

func _on_logout_successful() -> void:
	TokenStore.new().clear_session()
	Network.current_user = null
	Network.session_token = ""
	get_tree().change_scene_to_file("res://client/scenes/UserAuth.tscn")
