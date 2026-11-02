extends Control

const USER_DATABASE := preload("res://server/UserDatabase.gd")

var database: SQLite
var create_mode := true

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var name_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/NameEdit
@onready var email_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/EmailEdit
@onready var password_edit: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/PasswordEdit
@onready var submit_button: Button = $PanelContainer/MarginContainer/VBoxContainer/SubmitButton
@onready var toggle_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ToggleModeButton
@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	database = USER_DATABASE.create_database()
	if database == null:
		_set_status("Could not open the user database.", Color(1.0, 0.35, 0.35, 1.0))
	_submit_button_disabled()
	_sync_ui_mode()

func _submit_button_disabled() -> void:
	submit_button.disabled = database == null

func _sync_ui_mode() -> void:
	name_edit.visible = create_mode
	name_edit.editable = create_mode
	if create_mode:
		title_label.text = "Create account"
		submit_button.text = "Create account"
		toggle_button.text = "Already have an account? Log in"
		_set_status("Create a new account to play.", Color(0.8, 0.8, 0.8, 1.0))
	else:
		title_label.text = "Log in"
		submit_button.text = "Log in"
		toggle_button.text = "Need an account? Register"
		_set_status("Use your email and password to sign in.", Color(0.8, 0.8, 0.8, 1.0))

func _set_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color

func _generate_avatar_color(name: String) -> String:
	var hash_value := 0
	for index in range(name.length()):
		hash_value = (hash_value * 131 + ord(name[index])) & 0xFFFFFFFF
	var hue := float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.7, 0.9).to_html()

func _on_submit_button_pressed() -> void:
	if database == null:
		_set_status("The database is unavailable.", Color(1.0, 0.35, 0.35, 1.0))
		return

	var email := email_edit.text.strip_edges()
	var password := password_edit.text
	if email.is_empty() or password.is_empty():
		_set_status("Please enter your email and password.", Color(1.0, 0.7, 0.2, 1.0))
		return

	if create_mode:
		var name := name_edit.text.strip_edges()
		if name.is_empty():
			_set_status("Please enter a display name.", Color(1.0, 0.7, 0.2, 1.0))
			return
		var user := USER_DATABASE.create_user_with_avatar_transaction(database, name, email, password, _generate_avatar_color(name))
		if user.is_empty():
			_set_status("User creation failed. The email may already be in use.", Color(1.0, 0.35, 0.35, 1.0))
			return
		_set_status("Account created for %s." % user.get("name", ""), Color(0.35, 1.0, 0.6, 1.0))
		name_edit.clear()
		email_edit.clear()
		password_edit.clear()
		return

	if USER_DATABASE.authenticate_user(database, email, password):
		var user := USER_DATABASE.get_user_by_email(database, email)
		if user.is_empty():
			_set_status("Login succeeded but the user record could not be loaded.", Color(1.0, 0.7, 0.2, 1.0))
			return
		_set_status("Logged in as %s." % user.get("name", ""), Color(0.35, 1.0, 0.6, 1.0))
		return

	_set_status("Invalid email or password.", Color(1.0, 0.35, 0.35, 1.0))

func _on_toggle_mode_button_pressed() -> void:
	create_mode = not create_mode
	_sync_ui_mode()
