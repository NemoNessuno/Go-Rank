class_name RatingRepositoryTests
extends GdUnitTestSuite

const UserDatabaseScript := preload("res://server/UserDatabase.gd")
const RatingRepositoryScript := preload("res://server/RatingRepository.gd")
const RatingSystemScript := preload("res://server/RatingSystem.gd")

var _db: SQLite

func after_test() -> void:
	UserDatabaseScript.close_database(_db)
	_db = null

func _create_users() -> Array[int]:
	var db_path := "user://gdunit_rating_repository.sqlite"
	var absolute_path := ProjectSettings.globalize_path(db_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	_db = UserDatabaseScript.create_database(db_path)
	var first := UserDatabaseScript.create_user_with_avatar_transaction(
		_db, "Player One", "one@example.com", "password123", "#112233"
	)
	var second := UserDatabaseScript.create_user_with_avatar_transaction(
		_db, "Player Two", "two@example.com", "password123", "#445566"
	)
	return [int(first["id"]), int(second["id"])]

func test_recording_9x9_game_updates_both_players_only_in_9x9_category() -> void:
	var user_ids := _create_users()
	var first_before := RatingRepositoryScript.get_9x9_rating(_db, user_ids[0])
	var second_before := RatingRepositoryScript.get_9x9_rating(_db, user_ids[1])

	assert_bool(RatingRepositoryScript.record_9x9_game(
		_db, user_ids[0], user_ids[1], 1.0, 12345
	)).is_true()

	var first_after := RatingRepositoryScript.get_9x9_rating(_db, user_ids[0])
	var second_after := RatingRepositoryScript.get_9x9_rating(_db, user_ids[1])
	assert_float(float(first_after["rating"])).is_greater(float(first_before["rating"]))
	assert_float(float(second_after["rating"])).is_greater_equal(
		RatingSystemScript.STARTING_RATING
	)
	assert_int(int(first_after["last_played_at"])).is_equal(12345)
	assert_int(int(second_after["last_played_at"])).is_equal(12345)
	assert_int(int(first_after["games_played"])).is_equal(1)
	assert_int(int(second_after["games_played"])).is_equal(1)
	_db.query(
		"""
		SELECT rating_13x13, rating_19x19, rating_tsume_go,
			games_13x13, games_19x19, games_tsume_go
		FROM Ratings
		WHERE user_id = %d;
		""" % user_ids[0]
	)
	var other_categories: Dictionary = _db.query_result[0]
	assert_float(float(other_categories["rating_13x13"])).is_equal_approx(
		RatingSystemScript.STARTING_RATING, 0.000001
	)
	assert_float(float(other_categories["rating_19x19"])).is_equal_approx(
		RatingSystemScript.STARTING_RATING, 0.000001
	)
	assert_float(float(other_categories["rating_tsume_go"])).is_equal_approx(
		RatingSystemScript.STARTING_RATING, 0.000001
	)
	assert_int(int(other_categories["games_13x13"])).is_equal(0)
	assert_int(int(other_categories["games_19x19"])).is_equal(0)
	assert_int(int(other_categories["games_tsume_go"])).is_equal(0)

	var profile := RatingRepositoryScript.get_profile_ratings(_db, user_ids[0])
	assert_float(float(profile["unified_rating"])).is_equal_approx(
		float(first_after["rating"]),
		0.000001
	)
	assert_int(int(profile["games_played"])).is_equal(1)
	assert_int(int(profile["categories"]["9x9"]["games_played"])).is_equal(1)

func test_player_at_30_kyu_cannot_lose_rating_points() -> void:
	var user_ids := _create_users()

	assert_bool(RatingRepositoryScript.record_9x9_game(
		_db, user_ids[0], user_ids[1], 0.0, 12345
	)).is_true()

	var losing_player := RatingRepositoryScript.get_9x9_rating(_db, user_ids[0])
	var winner := RatingRepositoryScript.get_9x9_rating(_db, user_ids[1])
	assert_float(float(losing_player["rating"])).is_equal_approx(
		RatingSystemScript.STARTING_RATING, 0.000001
	)
	assert_float(float(winner["rating"])).is_greater(
		RatingSystemScript.STARTING_RATING
	)

func test_invalid_or_missing_players_do_not_change_ratings() -> void:
	var user_ids := _create_users()
	var rating_before := RatingRepositoryScript.get_9x9_rating(_db, user_ids[0])

	assert_bool(RatingRepositoryScript.record_9x9_game(
		_db, user_ids[0], user_ids[0], 1.0
	)).is_false()
	assert_bool(RatingRepositoryScript.record_9x9_game(
		_db, user_ids[0], 9999, 1.0
	)).is_false()
	assert_bool(RatingRepositoryScript.record_9x9_game(
		_db, user_ids[0], user_ids[1], 1.1
	)).is_false()

	var rating_after := RatingRepositoryScript.get_9x9_rating(_db, user_ids[0])
	assert_dict(rating_after).is_equal(rating_before)
