class_name RatingSystemTests
extends GdUnitTestSuite

const RatingSystemScript := preload("res://server/scripts/ratings/RatingSystem.gd")

func test_30_kyu_uses_ogs_logarithmic_rating_scale() -> void:
	var rating := RatingSystemScript.rank_to_rating(0.0)

	assert_float(rating).is_equal_approx(525.0, 0.000001)
	assert_float(RatingSystemScript.rating_to_rank(rating)).is_equal_approx(0.0, 0.000001)
	assert_str(RatingSystemScript.format_rank_label(rating)).is_equal("30 kyu")
	assert_float(RatingSystemScript.rank_to_rating(30.0)).is_equal_approx(
		1918.4917143969326,
		0.000001
	)

func test_new_rating_has_initial_deviation_and_volatility() -> void:
	var rating := RatingSystemScript.create_initial_rating()

	assert_float(float(rating["rating"])).is_equal_approx(525.0, 0.000001)
	assert_float(float(rating["deviation"])).is_equal(100.0)
	assert_float(float(rating["volatility"])).is_equal(0.06)
	assert_int(int(rating["last_played_at"])).is_equal(0)

func test_single_game_update_matches_glicko2_reference_case() -> void:
	var player := {
		"rating": 2400.0,
		"deviation": 200.0,
		"volatility": 0.06
	}
	var opponent := {
		"rating": 2400.0,
		"deviation": 200.0,
		"volatility": 0.06
	}

	var updated := RatingSystemScript.update_after_game(player, opponent, 1.0, 12345)

	assert_float(float(updated["rating"])).is_equal_approx(2478.8017167, 0.001)
	assert_float(float(updated["deviation"])).is_equal_approx(180.0782908, 0.001)
	assert_int(int(updated["last_played_at"])).is_equal(12345)

func test_30_kyu_player_cannot_lose_rating_below_floor() -> void:
	var initial := RatingSystemScript.create_initial_rating()
	var updated := RatingSystemScript.update_after_game(
		initial,
		initial,
		0.0,
		12345
	)

	assert_float(float(updated["rating"])).is_equal(
		RatingSystemScript.STARTING_RATING
	)
	assert_float(float(updated["deviation"])).is_less(
		float(initial["deviation"])
	)

func test_winning_increases_rating_and_invalid_score_is_rejected() -> void:
	var initial := RatingSystemScript.create_initial_rating()
	var won := RatingSystemScript.update_after_game(initial, initial, 1.0)

	assert_float(float(won["rating"])).is_greater(RatingSystemScript.STARTING_RATING)
	assert_that(RatingSystemScript.update_after_game(initial, initial, 1.1)).is_empty()

func test_equal_30_kyu_win_does_not_jump_to_24_kyu() -> void:
	var initial := RatingSystemScript.create_initial_rating()
	var winner := RatingSystemScript.update_after_game(initial, initial, 1.0)

	assert_str(RatingSystemScript.format_rank_label(float(winner["rating"]))).is_equal(
		"29 kyu"
	)

func test_unified_rating_weights_category_ratings_by_games_played() -> void:
	var unified := RatingSystemScript.calculate_unified_rating({
		"9x9": {"rating": 600.0, "games_played": 9},
		"13x13": {"rating": 900.0, "games_played": 1},
		"19x19": {"rating": 1200.0, "games_played": 0}
	})

	assert_float(float(unified["rating"])).is_equal_approx(630.0, 0.000001)
	assert_int(int(unified["games_played"])).is_equal(10)

func test_unified_rating_uses_starting_rating_when_no_games_were_played() -> void:
	var unified := RatingSystemScript.calculate_unified_rating({
		"9x9": {"rating": 600.0, "games_played": 0},
		"13x13": {"rating": 900.0, "games_played": 0}
	})

	assert_float(float(unified["rating"])).is_equal(RatingSystemScript.STARTING_RATING)
	assert_int(int(unified["games_played"])).is_equal(0)
