class_name UserDatabaseTests
extends GdUnitTestSuite

const UserDatabaseScript := preload("res://server/UserDatabase.gd")
const UserRepositoryScript := preload("res://server/UserRepository.gd")

func _test_db_path(db_name: String) -> String:
	return "user://%s.sqlite" % db_name

func _reset_test_db(db_name: String) -> SQLite:
	var db_path := _test_db_path(db_name)
	var absolute_path := ProjectSettings.globalize_path(db_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var db := UserDatabaseScript.create_database(db_path)
	assert_that(db).is_not_null()
	return db

func test_database_creation() -> void:
	var db := _reset_test_db("gdunit_users_db_creation")
	db.query("SELECT name FROM sqlite_master WHERE type = 'table' AND lower(name) IN ('avatars', 'users', 'games', 'ratings');")
	var tables: Array = db.query_result
	assert_int(tables.size()).is_equal(4)
	UserDatabaseScript.close_database(db)

func test_user_creation() -> void:
	var db := _reset_test_db("gdunit_users_db_create_user")
	var avatar_id := UserDatabaseScript.create_avatar(db, "#FF0000")
	assert_int(avatar_id).is_greater(0)

	var user := UserDatabaseScript.create_user(db, "Alice", "alice@example.com", "secret123", avatar_id)
	assert_that(user).is_not_empty()
	assert_str(user.get("email", "")).is_equal("alice@example.com")
	assert_str(user.get("name", "")).is_equal("Alice")
	db.query("SELECT * FROM Ratings WHERE user_id = %d;" % int(user["id"]))
	var ratings: Array = db.query_result
	assert_int(ratings.size()).is_equal(1)
	assert_float(float(ratings[0]["rating_9x9"])).is_equal_approx(525.0, 0.000001)
	assert_float(float(ratings[0]["rating_13x13"])).is_equal_approx(525.0, 0.000001)
	assert_float(float(ratings[0]["rating_19x19"])).is_equal_approx(525.0, 0.000001)
	assert_float(float(ratings[0]["rating_tsume_go"])).is_equal_approx(525.0, 0.000001)
	assert_float(float(ratings[0]["deviation_9x9"])).is_equal(350.0)
	assert_float(float(ratings[0]["volatility_9x9"])).is_equal(0.06)
	UserDatabaseScript.close_database(db)

func test_user_authentication() -> void:
	var db := _reset_test_db("gdunit_users_db_auth")
	var avatar_id := UserDatabaseScript.create_avatar(db, "#00FF00")
	UserDatabaseScript.create_user(db, "Bob", "bob@example.com", "supersecure", avatar_id)

	assert_bool(UserDatabaseScript.authenticate_user(db, "bob@example.com", "supersecure")).is_true()
	assert_bool(UserDatabaseScript.authenticate_user(db, "bob@example.com", "wrong-password")).is_false()
	assert_bool(UserDatabaseScript.authenticate_user(db, "missing@example.com", "supersecure")).is_false()
	UserDatabaseScript.close_database(db)

func test_user_repository_login_success_and_failure_paths() -> void:
	var db := _reset_test_db("gdunit_users_repository_login")
	var avatar_id := UserDatabaseScript.create_avatar(db, "#00FF00")
	UserDatabaseScript.create_user(db, "Bob", "bob@example.com", "supersecure", avatar_id)
	var repository: UserRepository = UserRepositoryScript.new()
	repository.database = db

	var user := repository.login_user("bob@example.com", "supersecure")
	assert_str(user.get("name", "")).is_equal("Bob")
	assert_that(repository.login_user("bob@example.com", "wrong-password")).is_empty()
	assert_that(repository.login_user("missing@example.com", "supersecure")).is_empty()

	repository.free()
	UserDatabaseScript.close_database(db)

func test_get_users_returns_public_user_data_and_avatar_color() -> void:
	var db := _reset_test_db("gdunit_users_db_list")
	var avatar_id := UserDatabaseScript.create_avatar(db, "#00FF00")
	UserDatabaseScript.create_user(db, "Bob", "bob@example.com", "supersecure", avatar_id)

	var users: Array = UserDatabaseScript.get_users(db)
	assert_int(users.size()).is_equal(1)
	assert_int(int(users[0]["id"])).is_greater(0)
	assert_str(users[0]["name"]).is_equal("Bob")
	assert_str(users[0]["avatar_color"]).is_equal("#00FF00")
	assert_bool(users[0].has("password")).is_false()
	UserDatabaseScript.close_database(db)

func test_transaction_rollback_removes_avatar_on_failed_user_creation() -> void:
	var db := _reset_test_db("gdunit_users_db_txn")

	var first_user := UserDatabaseScript.create_user_with_avatar_transaction(db, "Charlie", "charlie@example.com", "password123", "#112233")
	assert_that(first_user).is_not_empty()
	assert_int(UserDatabaseScript.get_user_count(db)).is_equal(1)
	assert_int(UserDatabaseScript.get_avatar_count(db)).is_equal(1)
	db.query("SELECT COUNT(*) AS count FROM Ratings;")
	assert_int(int(db.query_result[0]["count"])).is_equal(1)

	var second_user := UserDatabaseScript.create_user_with_avatar_transaction(db, "Charlie", "charlie@example.com", "otherpass", "#445566")
	assert_that(second_user).is_empty()
	assert_int(UserDatabaseScript.get_user_count(db)).is_equal(1)
	assert_int(UserDatabaseScript.get_avatar_count(db)).is_equal(1)
	db.query("SELECT COUNT(*) AS count FROM Ratings;")
	assert_int(int(db.query_result[0]["count"])).is_equal(1)
	UserDatabaseScript.close_database(db)

func test_database_initialization_backfills_ratings_for_existing_users() -> void:
	var db := _reset_test_db("gdunit_users_db_rating_migration")
	UserDatabaseScript.create_user_with_avatar_transaction(
		db,
		"Legacy",
		"legacy@example.com",
		"password123",
		"#112233"
	)
	db.query("DELETE FROM Ratings;")

	assert_bool(UserDatabaseScript._initialize_tables(db)).is_true()

	db.query("SELECT rating_9x9, rating_tsume_go FROM Ratings;")
	var rows: Array = db.query_result
	assert_int(rows.size()).is_equal(1)
	assert_float(float(rows[0]["rating_9x9"])).is_equal_approx(525.0, 0.000001)
	assert_float(float(rows[0]["rating_tsume_go"])).is_equal_approx(525.0, 0.000001)
	UserDatabaseScript.close_database(db)

func test_database_initialization_migrates_old_start_rating_and_adds_game_counts() -> void:
	var db := _reset_test_db("gdunit_users_db_rating_count_migration")
	UserDatabaseScript.create_user_with_avatar_transaction(
		db,
		"Legacy",
		"legacy-counts@example.com",
		"password123",
		"#112233"
	)
	db.query(
		"""
		UPDATE Ratings
		SET rating_9x9 = 1918.4917143969326,
			rating_13x13 = 1918.4917143969326,
			rating_19x19 = 1918.4917143969326,
			rating_tsume_go = 1918.4917143969326;
		"""
	)
	for count_column in ["games_9x9", "games_13x13", "games_19x19", "games_tsume_go"]:
		db.query("ALTER TABLE Ratings DROP COLUMN %s;" % count_column)

	assert_bool(UserDatabaseScript._initialize_tables(db)).is_true()

	db.query("SELECT * FROM Ratings;")
	var rows: Array = db.query_result
	assert_int(rows.size()).is_equal(1)
	for rating_column in [
		"rating_9x9",
		"rating_13x13",
		"rating_19x19",
		"rating_tsume_go"
	]:
		assert_float(float(rows[0][rating_column])).is_equal_approx(525.0, 0.000001)
	for count_column in ["games_9x9", "games_13x13", "games_19x19", "games_tsume_go"]:
		assert_int(int(rows[0][count_column])).is_equal(0)
	UserDatabaseScript.close_database(db)
