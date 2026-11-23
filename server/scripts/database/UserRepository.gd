class_name UserRepository
extends Node

var database: SQLite

func _ready() -> void:
	return

func initialize_user_database() -> void:
	database = UserDatabase.create_database()

func create_user(username: String, email: String, password: String, color: String) -> Dictionary:
	return _with_unified_rating(
		UserDatabase.create_user_with_avatar_transaction(database, username, email, password, color)
	)

func login_user(email: String,password: String) -> Dictionary:
	if UserDatabase.authenticate_user(database, email, password):
		return _with_unified_rating(UserDatabase.get_user_by_email(database, email))
	
	return {}

func get_user_by_id(id: int) -> Dictionary:
	return _with_unified_rating(UserDatabase.get_user_by_id(database, id))

func get_users() -> Array:
	var users: Array = UserDatabase.get_users(database)
	for index in range(users.size()):
		users[index] = _with_unified_rating(users[index])
		if users[index].is_empty():
			return []
	return users

func get_9x9_rating(user_id: int) -> Dictionary:
	return RatingRepository.get_9x9_rating(database, user_id)

func get_profile_ratings(user_id: int) -> Dictionary:
	return RatingRepository.get_profile_ratings(database, user_id)

func record_9x9_game(player_id: int, opponent_id: int, player_score: float) -> bool:
	return RatingRepository.record_9x9_game(
		database,
		player_id,
		opponent_id,
		player_score
	)

func store_game(game_data: Dictionary) -> Dictionary:
	return GameRepository.store_game(database, game_data)

func _with_unified_rating(user: Dictionary) -> Dictionary:
	if user.is_empty():
		return {}
	var profile := RatingRepository.get_profile_ratings(database, int(user["id"]))
	if profile.is_empty():
		push_error("Could not load rating for user %d." % int(user["id"]))
		return {}
	user["unified_rating"] = float(profile["unified_rating"])
	return user
