class_name GameRepository
extends RefCounted

const GameDataScript := preload("res://common/scripts/data/GameData.gd")
const RatingRepositoryScript := preload("res://server/scripts/ratings/RatingRepository.gd")

static func store_game(db: SQLite, game_data: Dictionary) -> Dictionary:
	if db == null:
		push_error("A database is required to store a game.")
		return {}

	var game_id := int(game_data.get("id", 0))
	var black_player_id := int(game_data.get("black_player_id", 0))
	var white_player_id := int(game_data.get("white_player_id", 0))
	var result := int(game_data.get("result", GameDataScript.RESULT_UNDECIDED))
	if (
		black_player_id <= 0
		or white_player_id <= 0
		or black_player_id == white_player_id
		or (
			result != GameDataScript.RESULT_UNDECIDED
			and result != GameDataScript.RESULT_DRAW
			and result != black_player_id
			and result != white_player_id
		)
	):
		push_error("Game players or result are invalid.")
		return {}

	if not db.query("BEGIN IMMEDIATE;"):
		push_error("Could not begin the game storage transaction.")
		return {}

	var should_update_ratings := false
	if game_id <= 0:
		if not db.query(
			"""
			INSERT INTO games (white_player_id, black_player_id, result)
			VALUES (%d, %d, %d);
			""" % [white_player_id, black_player_id, result]
		):
			db.query("ROLLBACK;")
			push_error("Could not insert the game record.")
			return {}
		if not db.query("SELECT last_insert_rowid() AS id;"):
			db.query("ROLLBACK;")
			push_error("Could not read the stored game identifier.")
			return {}
		var inserted_rows: Array = db.query_result
		if inserted_rows.is_empty():
			db.query("ROLLBACK;")
			push_error("The game record was inserted without an identifier.")
			return {}
		game_id = int(inserted_rows[0]["id"])
		should_update_ratings = result != GameDataScript.RESULT_UNDECIDED
	else:
		if not db.query(
			"""
			SELECT black_player_id, white_player_id, result
			FROM games
			WHERE id = %d;
			""" % game_id
		):
			db.query("ROLLBACK;")
			push_error("Could not load stored game %d." % game_id)
			return {}
		var existing_rows: Array = db.query_result
		if existing_rows.is_empty():
			db.query("ROLLBACK;")
			push_error("Stored game %d does not exist." % game_id)
			return {}
		var existing: Dictionary = existing_rows[0]
		if (
			int(existing["black_player_id"]) != black_player_id
			or int(existing["white_player_id"]) != white_player_id
		):
			db.query("ROLLBACK;")
			push_error("Stored game participants cannot be changed.")
			return {}

		var existing_result := int(existing["result"])
		if (
			existing_result == GameDataScript.RESULT_UNDECIDED
			and result != GameDataScript.RESULT_UNDECIDED
		):
			if not db.query(
				"UPDATE games SET result = %d WHERE id = %d;" % [result, game_id]
			):
				db.query("ROLLBACK;")
				push_error("Could not update the stored game result.")
				return {}
			should_update_ratings = true
		elif existing_result != result:
			db.query("ROLLBACK;")
			push_error("A decided game result cannot be changed.")
			return {}

	if should_update_ratings:
		var black_score := 0.5
		if result == black_player_id:
			black_score = 1.0
		elif result == white_player_id:
			black_score = 0.0
		if not RatingRepositoryScript.update_9x9_ratings_in_transaction(
			db,
			black_player_id,
			white_player_id,
			black_score,
			int(Time.get_unix_time_from_system())
		):
			db.query("ROLLBACK;")
			return {}

	var black_profile: Dictionary = RatingRepositoryScript.get_profile_ratings(
		db,
		black_player_id
	)
	var white_profile: Dictionary = RatingRepositoryScript.get_profile_ratings(
		db,
		white_player_id
	)
	if black_profile.is_empty() or white_profile.is_empty():
		db.query("ROLLBACK;")
		push_error("Could not load player ratings for stored game %d." % game_id)
		return {}

	if not db.query("COMMIT;"):
		db.query("ROLLBACK;")
		push_error("Could not commit stored game %d." % game_id)
		return {}

	return {
		"game_id": game_id,
		"result": result,
		"rated": should_update_ratings,
		"black_profile": black_profile,
		"white_profile": white_profile
	}
