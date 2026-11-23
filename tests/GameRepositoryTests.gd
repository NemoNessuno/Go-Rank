class_name GameRepositoryTests
extends GdUnitTestSuite

const UserDatabaseScript := preload("res://server/scripts/database/UserDatabase.gd")
const GameRepositoryScript := preload("res://server/scripts/database/GameRepository.gd")
const RatingRepositoryScript := preload("res://server/scripts/ratings/RatingRepository.gd")
const GameDataScript := preload("res://common/scripts/data/GameData.gd")

var _db: SQLite

func after_test() -> void:
	UserDatabaseScript.close_database(_db)
	_db = null

func _create_users() -> Array[int]:
	var db_path := "user://gdunit_game_repository.sqlite"
	var absolute_path := ProjectSettings.globalize_path(db_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	_db = UserDatabaseScript.create_database(db_path)
	var black := UserDatabaseScript.create_user_with_avatar_transaction(
		_db, "Black Player", "black@example.com", "password123", "#112233"
	)
	var white := UserDatabaseScript.create_user_with_avatar_transaction(
		_db, "White Player", "white@example.com", "password123", "#445566"
	)
	return [int(black["id"]), int(white["id"])]

func _game_data(black_id: int, white_id: int, result: int) -> Dictionary:
	return {
		"black_player_id": black_id,
		"white_player_id": white_id,
		"result": result
	}

func test_undecided_game_is_stored_without_rating_updates() -> void:
	var users := _create_users()

	var response: Dictionary = GameRepositoryScript.store_game(
		_db,
		_game_data(users[0], users[1], GameDataScript.RESULT_UNDECIDED)
	)

	assert_bool(response.is_empty()).is_false()
	assert_int(int(response["result"])).is_equal(GameDataScript.RESULT_UNDECIDED)
	assert_bool(bool(response["rated"])).is_false()
	_db.query(
		"SELECT result FROM games WHERE id = %d;" % int(response["game_id"])
	)
	assert_int(int(_db.query_result[0]["result"])).is_equal(
		GameDataScript.RESULT_UNDECIDED
	)
	var black_rating := RatingRepositoryScript.get_9x9_rating(_db, users[0])
	var white_rating := RatingRepositoryScript.get_9x9_rating(_db, users[1])
	assert_int(int(black_rating["games_played"])).is_equal(0)
	assert_int(int(white_rating["games_played"])).is_equal(0)

func test_draw_is_a_decided_game_and_updates_both_ratings() -> void:
	var users := _create_users()

	var response: Dictionary = GameRepositoryScript.store_game(
		_db,
		_game_data(users[0], users[1], GameDataScript.RESULT_DRAW)
	)

	assert_bool(bool(response["rated"])).is_true()
	assert_int(int(response["result"])).is_equal(GameDataScript.RESULT_DRAW)
	assert_int(
		int(RatingRepositoryScript.get_9x9_rating(_db, users[0])["games_played"])
	).is_equal(1)
	assert_int(
		int(RatingRepositoryScript.get_9x9_rating(_db, users[1])["games_played"])
	).is_equal(1)

func test_decided_game_updates_both_ratings_once() -> void:
	var users := _create_users()
	var pending := GameRepositoryScript.store_game(
		_db,
		_game_data(users[0], users[1], GameDataScript.RESULT_UNDECIDED)
	)
	var game_id := int(pending["game_id"])

	var completed := _game_data(users[0], users[1], users[0])
	completed["id"] = game_id
	var response: Dictionary = GameRepositoryScript.store_game(_db, completed)
	assert_bool(bool(response["rated"])).is_true()
	assert_int(int(response["result"])).is_equal(users[0])

	var black_after_first_store := RatingRepositoryScript.get_9x9_rating(_db, users[0])
	var white_after_first_store := RatingRepositoryScript.get_9x9_rating(_db, users[1])
	assert_int(int(black_after_first_store["games_played"])).is_equal(1)
	assert_int(int(white_after_first_store["games_played"])).is_equal(1)

	var repeated_response: Dictionary = GameRepositoryScript.store_game(_db, completed)
	var black_after_repeat := RatingRepositoryScript.get_9x9_rating(_db, users[0])
	var white_after_repeat := RatingRepositoryScript.get_9x9_rating(_db, users[1])
	assert_bool(bool(repeated_response["rated"])).is_false()
	assert_dict(black_after_repeat).is_equal(black_after_first_store)
	assert_dict(white_after_repeat).is_equal(white_after_first_store)

func test_invalid_result_or_changed_decided_game_is_rejected() -> void:
	var users := _create_users()
	assert_that(GameRepositoryScript.store_game(
		_db,
		_game_data(users[0], users[1], 999)
	)).is_empty()
	assert_that(GameRepositoryScript.store_game(
		_db,
		_game_data(users[0], users[0], GameDataScript.RESULT_UNDECIDED)
	)).is_empty()

	var decided := GameRepositoryScript.store_game(
		_db,
		_game_data(users[0], users[1], users[0])
	)
	var changed := _game_data(users[0], users[1], users[1])
	changed["id"] = int(decided["game_id"])
	assert_that(GameRepositoryScript.store_game(_db, changed)).is_empty()
