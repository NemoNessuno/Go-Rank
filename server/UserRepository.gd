class_name UserRepository
extends Node

var database: SQLite

func _ready() -> void:
	return

func initialize_user_database() -> void:
	database = UserDatabase.create_database()