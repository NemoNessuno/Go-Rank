class_name RatingRepository
extends RefCounted

const RatingSystemScript := preload("res://server/scripts/ratings/RatingSystem.gd")

static func get_9x9_rating(db: SQLite, user_id: int) -> Dictionary:
	if db == null or user_id <= 0:
		return {}

	db.query(
		"""
		SELECT rating_9x9 AS rating, deviation_9x9 AS deviation,
			volatility_9x9 AS volatility, last_played_9x9 AS last_played_at,
			games_9x9 AS games_played
		FROM Ratings
		WHERE user_id = %d;
		""" % user_id
	)
	var rows: Array = db.query_result
	if rows.is_empty():
		return {}
	return rows[0]

static func get_profile_ratings(db: SQLite, user_id: int) -> Dictionary:
	if db == null or user_id <= 0:
		return {}

	if not db.query(
		"""
		SELECT rating_9x9, deviation_9x9, volatility_9x9, games_9x9,
			rating_13x13, deviation_13x13, volatility_13x13, games_13x13,
			rating_19x19, deviation_19x19, volatility_19x19, games_19x19,
			rating_tsume_go, deviation_tsume_go, volatility_tsume_go, games_tsume_go
		FROM Ratings
		WHERE user_id = %d;
		""" % user_id
	):
		push_error("Could not load profile ratings for user %d." % user_id)
		return {}
	var rows: Array = db.query_result
	if rows.is_empty():
		return {}

	var row: Dictionary = rows[0]
	var categories := {
		"9x9": _category_rating(row, "9x9"),
		"13x13": _category_rating(row, "13x13"),
		"19x19": _category_rating(row, "19x19"),
		"tsume-go": _category_rating(row, "tsume_go")
	}
	var unified := RatingSystemScript.calculate_unified_rating(categories)
	if unified.is_empty():
		push_error("Could not calculate unified rating for user %d." % user_id)
		return {}

	return {
		"categories": categories,
		"unified_rating": unified["rating"],
		"games_played": unified["games_played"]
	}

static func _category_rating(row: Dictionary, category: String) -> Dictionary:
	var suffix := category.replace("-", "_")
	return {
		"rating": float(row["rating_%s" % suffix]),
		"deviation": float(row["deviation_%s" % suffix]),
		"volatility": float(row["volatility_%s" % suffix]),
		"games_played": int(row["games_%s" % suffix])
	}

static func record_9x9_game(
	db: SQLite,
	player_id: int,
	opponent_id: int,
	player_score: float,
	timestamp: int = 0
) -> bool:
	if db == null or player_id <= 0 or opponent_id <= 0 or player_id == opponent_id:
		push_error("A 9x9 rating update requires two distinct existing users.")
		return false
	if (
		is_nan(player_score) or is_inf(player_score)
		or player_score < 0.0 or player_score > 1.0
	):
		push_error("A 9x9 game score must be between 0 and 1.")
		return false

	if timestamp <= 0:
		timestamp = int(Time.get_unix_time_from_system())
	if not db.query("BEGIN IMMEDIATE;"):
		push_error("Could not begin the 9x9 rating update transaction.")
		return false

	var player := get_9x9_rating(db, player_id)
	var opponent := get_9x9_rating(db, opponent_id)
	if player.is_empty() or opponent.is_empty():
		db.query("ROLLBACK;")
		push_error("Cannot update ratings for users without rating records.")
		return false

	var updated_player: Dictionary = RatingSystemScript.update_after_game(
		player,
		opponent,
		player_score,
		timestamp
	)
	var updated_opponent: Dictionary = RatingSystemScript.update_after_game(
		opponent,
		player,
		1.0 - player_score,
		timestamp
	)
	if updated_player.is_empty() or updated_opponent.is_empty():
		db.query("ROLLBACK;")
		return false

	if not _save_9x9_rating(db, player_id, updated_player):
		db.query("ROLLBACK;")
		return false
	if not _save_9x9_rating(db, opponent_id, updated_opponent):
		db.query("ROLLBACK;")
		return false
	if not db.query("COMMIT;"):
		db.query("ROLLBACK;")
		push_error("Could not commit the 9x9 rating update.")
		return false
	return true

static func _save_9x9_rating(db: SQLite, user_id: int, rating_data: Dictionary) -> bool:
	var sql := """
		UPDATE Ratings
		SET rating_9x9 = %.15f,
			deviation_9x9 = %.15f,
			volatility_9x9 = %.15f,
			last_played_9x9 = %d,
			games_9x9 = games_9x9 + 1
		WHERE user_id = %d;
	""" % [
		float(rating_data["rating"]),
		float(rating_data["deviation"]),
		float(rating_data["volatility"]),
		int(rating_data["last_played_at"]),
		user_id
	]
	if not db.query(sql):
		push_error("Could not save 9x9 rating for user %d." % user_id)
		return false
	return true
