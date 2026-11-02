class_name UserDatabaseTests
extends GdUnitTestSuite

const UserDatabaseScript := preload("res://server/UserDatabase.gd")

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
	db.query("SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('avatars', 'users', 'games');")
	var tables: Array = db.query_result
	assert_int(tables.size()).is_equal(3)
	UserDatabaseScript.close_database()

func test_user_creation() -> void:
	var db := _reset_test_db("gdunit_users_db_create_user")
	var avatar_id := UserDatabaseScript.create_avatar(db, "#FF0000")
	assert_int(avatar_id).is_greater(0)

	var user := UserDatabaseScript.create_user(db, "Alice", "alice@example.com", "secret123", avatar_id)
	assert_that(user).is_not_empty()
	assert_str(user.get("email", "")).is_equal("alice@example.com")
	assert_str(user.get("name", "")).is_equal("Alice")
	UserDatabaseScript.close_database()

func test_user_authentication() -> void:
	var db := _reset_test_db("gdunit_users_db_auth")
	var avatar_id := UserDatabaseScript.create_avatar(db, "#00FF00")
	UserDatabaseScript.create_user(db, "Bob", "bob@example.com", "supersecure", avatar_id)

	assert_bool(UserDatabaseScript.authenticate_user(db, "bob@example.com", "supersecure")).is_true()
	assert_bool(UserDatabaseScript.authenticate_user(db, "bob@example.com", "wrong-password")).is_false()
	UserDatabaseScript.close_database()

func test_transaction_rollback_removes_avatar_on_failed_user_creation() -> void:
	var db := _reset_test_db("gdunit_users_db_txn")

	var first_user := UserDatabaseScript.create_user_with_avatar_transaction(db, "Charlie", "charlie@example.com", "password123", "#112233")
	assert_that(first_user).is_not_empty()
	assert_int(UserDatabaseScript.get_user_count(db)).is_equal(1)
	assert_int(UserDatabaseScript.get_avatar_count(db)).is_equal(1)

	var second_user := UserDatabaseScript.create_user_with_avatar_transaction(db, "Charlie", "charlie@example.com", "otherpass", "#445566")
	assert_that(second_user).is_empty()
	assert_int(UserDatabaseScript.get_user_count(db)).is_equal(1)
	assert_int(UserDatabaseScript.get_avatar_count(db)).is_equal(1)
	UserDatabaseScript.close_database()
