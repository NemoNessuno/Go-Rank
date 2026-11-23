extends Control

const RatingSystemScript := preload("res://server/scripts/ratings/RatingSystem.gd")
const UserButtonScene := preload("res://client/scenes/UserButton.tscn")

@onready var world_container: GridContainer = $MapPanel/WorldContainer
@onready var status_label: Label = $Sidebar/SidebarContent/StatusLabel
@onready var selected_user_label: Label = $Sidebar/SidebarContent/SelectedUserLabel
@onready var unified_rating_label: Label = $Sidebar/SidebarContent/UnifiedRatingLabel
@onready var start_game_button: Button = $Sidebar/SidebarContent/StartGameButton
@onready var profile_button: Button = $Sidebar/SidebarContent/ProfileButton
@onready var logout_button: Button = $Sidebar/SidebarContent/LogoutButton

var users: Array[UserData] = []
var selected_user: UserData
var user_buttons: Array[Button] = []

func _ready() -> void:
	profile_button.pressed.connect(_on_profile_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	Network.users_received.connect(_on_users_received)
	Network.users_request_failed.connect(_on_users_request_failed)
	Network.profile_ratings_received.connect(_on_profile_ratings_received)
	Network.profile_ratings_request_failed.connect(_on_profile_ratings_request_failed)
	Network.logout_successful.connect(_on_logout_successful)

	if Network.current_user == null:
		status_label.text = "Please log in to view available players."
		logout_button.disabled = true
		profile_button.disabled = true
		return

	_update_unified_rating_label(Network.current_profile_ratings)
	if not Network.request_profile_ratings() and Network.current_profile_ratings.is_empty():
		unified_rating_label.text = "Unified rating unavailable."

	status_label.text = "Loading players..."
	Network.request_users()

func _on_users_request_failed(message: String) -> void:
	status_label.text = message

func _on_profile_ratings_received(profile: Dictionary) -> void:
	_update_unified_rating_label(profile)

func _on_profile_ratings_request_failed(message: String) -> void:
	unified_rating_label.text = message

func _update_unified_rating_label(profile: Dictionary) -> void:
	if profile.is_empty() or not profile.has("unified_rating"):
		unified_rating_label.text = "Unified rating: Loading..."
		return
	var rating := float(profile["unified_rating"])
	unified_rating_label.text = "Unified rating: %s (%.1f)" % [
		RatingSystemScript.format_rank_label(rating),
		rating
	]

func _on_profile_pressed() -> void:
	get_tree().change_scene_to_file("res://client/scenes/UserProfile.tscn")

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
	for button in user_buttons:
		if is_instance_valid(button):
			button.queue_free()
	user_buttons.clear()

	for index in range(users.size()):
		var user := users[index]
		var button := UserButtonScene.instantiate() as Button
		button.name = "UserButton_%d" % user.id
		button.text = user.name
		button.pressed.connect(_on_user_button_pressed.bind(index))
		_apply_user_button_style(button, user == selected_user, user)
		world_container.add_child(button)
		user_buttons.append(button)

func _apply_user_button_style(button: Button, is_selected: bool, user: UserData) -> void:
	var style := button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	style.bg_color = Color(user.avatar.color) if user.avatar != null else Color("#4ec9f5")
	style.border_color = Color(1, 0.88, 0.2, 1) if is_selected else Color(1, 1, 1, 0.35)
	style.set_border_width_all(3 if is_selected else 2)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)

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

	var game := GameData.new()
	game.black_player = Network.current_user
	game.white_player = selected_user
	Network.current_game = game
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
	Network.current_profile_ratings.clear()
	get_tree().change_scene_to_file("res://client/scenes/UserAuth.tscn")
