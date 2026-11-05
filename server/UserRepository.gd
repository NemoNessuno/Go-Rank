class_name UserRepository
extends Node

var database: SQLite

func _ready() -> void:
	return

func initialize_user_database() -> void:
	database = UserDatabase.create_database()

func create_user(username: String, email: String, password: String, color: String) -> Dictionary:
	return UserDatabase.create_user_with_avatar_transaction(database, username, email, password, color)

func login_user(email: String,password: String) -> Dictionary:
	if UserDatabase.authenticate_user(database, email, password):
		return UserDatabase.get_user_by_email(database, email)
	
	return {}
