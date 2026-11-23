class_name UserDatabase
extends RefCounted

const DEFAULT_DB_PATH := "user://go_rank_server.sqlite"
const AuthenticationScript := preload("res://server/Authentication.gd")
const RatingSystemScript := preload("res://server/RatingSystem.gd")

const RATING_GAME_COUNT_COLUMNS := [
	"games_9x9",
	"games_13x13",
	"games_19x19",
	"games_tsume_go"
]

static func _execute_sql(db: SQLite, sql: String) -> bool:
	if not db.query(sql):
		push_error("SQL-Fehler: %s\nSQL: %s" % [db.error_message, sql.strip_edges()])
		return false

	return true

static func create_database(database_path: String = DEFAULT_DB_PATH) -> SQLite:
	var db := SQLite.new()
	db.path = database_path

	if not db.open_db():
		push_error("Failed to open SQLite database at %s" % database_path)
		return null
	
	db.query("BEGIN IMMEDIATE;")
	db.query("PRAGMA foreign_keys = ON;")
	if _initialize_tables(db):
		db.query("COMMIT;")
	else:
		db.query("ROLLBACK;")
		
	return db

static func _initialize_tables(db: SQLite) -> bool:
	if db == null:
		return false

	if not _execute_sql(db, 
		"""
		CREATE TABLE IF NOT EXISTS avatars (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			color TEXT NOT NULL
		);
		"""
	):
		return false

	if not _execute_sql(db,
		"""
		CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			password TEXT NOT NULL,
			email TEXT NOT NULL UNIQUE,
			avatar_id INTEGER,
			FOREIGN KEY (avatar_id) REFERENCES avatars(id)
		);
		"""
	):
		return false

	if not _execute_sql(db,
		"""
		CREATE TABLE IF NOT EXISTS Ratings (
			user_id INTEGER PRIMARY KEY,
			rating_9x9 REAL NOT NULL DEFAULT 525.0,
			deviation_9x9 REAL NOT NULL DEFAULT 350.0,
			volatility_9x9 REAL NOT NULL DEFAULT 0.06,
			last_played_9x9 INTEGER NOT NULL DEFAULT 0,
			rating_13x13 REAL NOT NULL DEFAULT 525.0,
			deviation_13x13 REAL NOT NULL DEFAULT 350.0,
			volatility_13x13 REAL NOT NULL DEFAULT 0.06,
			last_played_13x13 INTEGER NOT NULL DEFAULT 0,
			rating_19x19 REAL NOT NULL DEFAULT 525.0,
			deviation_19x19 REAL NOT NULL DEFAULT 350.0,
			volatility_19x19 REAL NOT NULL DEFAULT 0.06,
			last_played_19x19 INTEGER NOT NULL DEFAULT 0,
			rating_tsume_go REAL NOT NULL DEFAULT 525.0,
			deviation_tsume_go REAL NOT NULL DEFAULT 350.0,
			volatility_tsume_go REAL NOT NULL DEFAULT 0.06,
			last_played_tsume_go INTEGER NOT NULL DEFAULT 0,
			games_9x9 INTEGER NOT NULL DEFAULT 0,
			games_13x13 INTEGER NOT NULL DEFAULT 0,
			games_19x19 INTEGER NOT NULL DEFAULT 0,
			games_tsume_go INTEGER NOT NULL DEFAULT 0,
			FOREIGN KEY (user_id) REFERENCES users(id)
		);
		"""
	):
		return false

	if not _ensure_rating_game_count_columns(db):
		return false

	if not _execute_sql(db, "INSERT OR IGNORE INTO Ratings (user_id) SELECT id FROM users;"):
		return false

	if not _execute_sql(db,
		"""
		CREATE TABLE IF NOT EXISTS games (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			white_player_id INTEGER NOT NULL,
			black_player_id INTEGER NOT NULL,
			result INTEGER NOT NULL,
			FOREIGN KEY (white_player_id) REFERENCES users(id),
			FOREIGN KEY (black_player_id) REFERENCES users(id)
		);
		"""
	):
		return false
		
	if not _execute_sql(db, 
		"""
		CREATE TABLE IF NOT EXISTS sessions (
			token TEXT PRIMARY KEY,
			user_id INTEGER NOT NULL,
			created_at INTEGER NOT NULL,
			expires_at INTEGER NOT NULL,
			FOREIGN KEY (user_id) REFERENCES users(id)
			);
		"""
	):
			return false

	if not (_execute_sql(db, "CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);") 
		and _execute_sql(db, "CREATE INDEX IF NOT EXISTS idx_games_white_player ON games(white_player_id);")
		and _execute_sql(db, "CREATE INDEX IF NOT EXISTS idx_games_black_player ON games(black_player_id);")
		and _execute_sql(db, "CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);")
		):
		return false
		
	return true

static func create_avatar(db_ref: SQLite, color: String = "#000000") -> int:
	if db_ref == null:
		return -1
	var safe_color := color.replace("'", "''")
	db_ref.query("INSERT INTO avatars (color) VALUES ('%s');" % safe_color)
	db_ref.query("SELECT id FROM avatars WHERE color = '%s' ORDER BY id DESC LIMIT 1;" % safe_color)
	var rows: Array = db_ref.query_result
	if rows.is_empty():
		return -1
	return int(rows[0].get("id", -1))

static func _execute_statement(db_ref: SQLite, sql_statement: String) -> bool:
	if db_ref == null:
		return false
	var result = db_ref.query(sql_statement)
	if typeof(result) == TYPE_BOOL:
		return bool(result)
	return true

static func create_user(db_ref: SQLite, name: String, email: String, password: String, avatar_id: int = -1) -> Dictionary:
	if db_ref == null or name.strip_edges().is_empty() or email.strip_edges().is_empty() or password.is_empty():
		return {}

	if avatar_id < 0:
		return create_user_with_avatar_transaction(db_ref, name, email, password, "#000000")

	var safe_name := name.replace("'", "''")
	var safe_email := email.replace("'", "''")
	var password_hash := AuthenticationScript.create_password_hash(password)
	var avatar_value := str(avatar_id)

	var transaction_ok := true
	db_ref.query("BEGIN IMMEDIATE;")
	if not _execute_statement(db_ref, "INSERT INTO users (name, email, password, avatar_id) VALUES ('%s', '%s', '%s', %s);" % [
		safe_name,
		safe_email,
		password_hash["value"],
		avatar_value
	]):
		transaction_ok = false

	if transaction_ok:
		var user := get_user_by_email(db_ref, email)
		if user.is_empty():
			transaction_ok = false
		elif not _insert_initial_rating(db_ref, int(user["id"])):
			transaction_ok = false

	if transaction_ok:
		db_ref.query("COMMIT;")
		return get_user_by_email(db_ref, email)

	db_ref.query("ROLLBACK;")
	return {}

static func create_user_with_avatar_transaction(db_ref: SQLite, name: String, email: String, password: String, avatar_color: String = "#000000") -> Dictionary:
	if db_ref == null or name.strip_edges().is_empty() or email.strip_edges().is_empty() or password.is_empty():
		return {}

	var safe_name := name.replace("'", "''")
	var safe_email := email.replace("'", "''")
	var safe_color := avatar_color.replace("'", "''")
	var password_hash := AuthenticationScript.create_password_hash(password)
	var avatar_id := -1
	var created_user := {}
	var transaction_ok := true

	db_ref.query("BEGIN IMMEDIATE;")
	if not _execute_statement(db_ref, "INSERT INTO avatars (color) VALUES ('%s');" % safe_color):
		transaction_ok = false
	else:
		db_ref.query("SELECT id FROM avatars WHERE color = '%s' ORDER BY id DESC LIMIT 1;" % safe_color)
		var rows: Array = db_ref.query_result
		if rows.is_empty():
			transaction_ok = false
		else:
			avatar_id = int(rows[0].get("id", -1))

	if transaction_ok:
		if not _execute_statement(db_ref, "INSERT INTO users (name, email, password, avatar_id) VALUES ('%s', '%s', '%s', %s);" % [
			safe_name,
			safe_email,
			password_hash["value"],
			avatar_id
		]):
			transaction_ok = false
		else:
			created_user = get_user_by_email(db_ref, email)
			if created_user.is_empty():
				transaction_ok = false
			elif not _insert_initial_rating(db_ref, int(created_user["id"])):
				transaction_ok = false

	if transaction_ok:
		db_ref.query("COMMIT;")
		return created_user

	db_ref.query("ROLLBACK;")
	if avatar_id > 0:
		db_ref.query("DELETE FROM avatars WHERE id = %d;" % avatar_id)
	return {}

static func _insert_initial_rating(db_ref: SQLite, user_id: int) -> bool:
	var initial := RatingSystemScript.create_initial_rating()
	var rating_value := "%.15f" % float(initial["rating"])
	var deviation_value := "%.15f" % float(initial["deviation"])
	var volatility_value := "%.15f" % float(initial["volatility"])
	var sql := """
		INSERT INTO Ratings (
			user_id,
			rating_9x9, deviation_9x9, volatility_9x9, last_played_9x9,
			rating_13x13, deviation_13x13, volatility_13x13, last_played_13x13,
			rating_19x19, deviation_19x19, volatility_19x19, last_played_19x19,
			rating_tsume_go, deviation_tsume_go, volatility_tsume_go, last_played_tsume_go,
			games_9x9, games_13x13, games_19x19, games_tsume_go
		) VALUES (
			%d,
			%s, %s, %s, 0,
			%s, %s, %s, 0,
			%s, %s, %s, 0,
			%s, %s, %s, 0,
			0, 0, 0, 0
		);
	""" % [
		user_id,
		rating_value, deviation_value, volatility_value,
		rating_value, deviation_value, volatility_value,
		rating_value, deviation_value, volatility_value,
		rating_value, deviation_value, volatility_value
	]
	return _execute_statement(db_ref, sql)

static func _ensure_rating_game_count_columns(db: SQLite) -> bool:
	db.query("PRAGMA table_info(Ratings);")
	var existing_columns: Dictionary = {}
	for column in db.query_result:
		existing_columns[String(column.get("name", ""))] = true

	for column_name in RATING_GAME_COUNT_COLUMNS:
		if existing_columns.has(column_name):
			continue
		if not _execute_sql(
			db,
			"ALTER TABLE Ratings ADD COLUMN %s INTEGER NOT NULL DEFAULT 0;" % column_name
		):
			return false
	return true

static func get_user_by_email(db_ref: SQLite, email: String) -> Dictionary:
	if db_ref == null or email.strip_edges().is_empty():
		return {}

	var safe_email := email.replace("'", "''")
	db_ref.query("SELECT id, name, email, password, avatar_id FROM users WHERE email = '%s';" % safe_email)
	var rows: Array = db_ref.query_result
	if rows.is_empty():
		return {}
	return rows[0]
	
static func get_user_by_id(db_ref: SQLite, id: int) -> Dictionary:
	if db_ref == null or id < 0:
		return {}

	db_ref.query("SELECT id, name, email, password, avatar_id FROM users WHERE id = '%d';" % id)
	var rows: Array = db_ref.query_result
	if rows.is_empty():
		return {}
	return rows[0]

static func get_users(db_ref: SQLite) -> Array:
	if db_ref == null:
		return []

	db_ref.query(
		"""
		SELECT users.id, users.name, users.email, users.avatar_id,
			avatars.color AS avatar_color
		FROM users
		LEFT JOIN avatars ON avatars.id = users.avatar_id
		ORDER BY users.name;
		"""
	)
	return db_ref.query_result

static func authenticate_user(db_ref: SQLite, email: String, password: String) -> bool:
	if db_ref == null:
		return false

	var user: Dictionary = get_user_by_email(db_ref, email)
	if user.is_empty():
		return false
	var stored_hash := String(user.get("password", ""))
	return AuthenticationScript.verify_password(password, stored_hash)

static func get_user_data(db: SQLite, username: String) -> Dictionary:
	if username.is_empty() or db == null:
		return {}

	var safe_username := username.replace("'", "''")
	db.query("SELECT id, name, email, avatar_id FROM users WHERE name = '%s';" % safe_username)
	var rows: Array = db.query_result
	if rows.is_empty():
		return {}
	return rows[0]

static func get_user_count(db_ref: SQLite) -> int:
	if db_ref == null:
		return 0
	db_ref.query("SELECT COUNT(*) AS count FROM users;")
	var rows: Array = db_ref.query_result
	if rows.is_empty():
		return 0
	return int(rows[0].get("count", 0))

static func get_avatar_count(db_ref: SQLite) -> int:
	if db_ref == null:
		return 0
	db_ref.query("SELECT COUNT(*) AS count FROM avatars;")
	var rows: Array = db_ref.query_result
	if rows.is_empty():
		return 0
	return int(rows[0].get("count", 0))

static func close_database(db: SQLite) -> void:
	if db != null:
		db.close_db()
		db = null
