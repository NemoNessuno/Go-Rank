class_name RatingSystem
extends RefCounted

const RATING_TO_RANK_SCALE := 23.15
const RATING_TO_RANK_BASE := 525.0
const STARTING_RATING := 525.0
const LEGACY_STARTING_RATING := 1918.4917143969326

const GLICKO2_SCALE := 173.7178
const TAU := 0.5
const INITIAL_DEVIATION := 350.0
const INITIAL_VOLATILITY := 0.06
const MIN_DEVIATION := 30.0
const MAX_DEVIATION := 500.0
const MIN_VOLATILITY := 0.01
const MAX_VOLATILITY := 0.15
const MAX_RATING := 6000.0
const MIN_RATING := STARTING_RATING
const EPSILON := 0.000001

static func rank_to_rating(rank: float) -> float:
	return RATING_TO_RANK_BASE * exp(rank / RATING_TO_RANK_SCALE)

static func rating_to_rank(rating: float) -> float:
	if rating <= 0.0:
		push_error("A rating must be positive to convert it to a rank.")
		return 0.0
	var bounded_rating := clampf(rating, 100.0, MAX_RATING)
	return RATING_TO_RANK_SCALE * log(bounded_rating / RATING_TO_RANK_BASE)

static func format_rank_label(rating: float) -> String:
	var rank := rating_to_rank(rating)
	if rank < 30.0:
		return "%d kyu" % int(ceil(30.0 - rank))
	return "%d dan" % int(floor(rank - 29.0))

static func calculate_unified_rating(categories: Dictionary) -> Dictionary:
	var weighted_rating := 0.0
	var games_played := 0
	for category_name in categories:
		var category: Variant = categories[category_name]
		if (
			typeof(category) != TYPE_DICTIONARY
			or not category.has("rating")
			or not category.has("games_played")
		):
			push_error("Every rating category must include rating and games_played.")
			return {}

		var category_games := int(category["games_played"])
		var category_rating := float(category["rating"])
		if (
			category_games < 0
			or is_nan(category_rating)
			or is_inf(category_rating)
			or category_rating <= 0.0
		):
			push_error("Category ratings must be positive and game counts cannot be negative.")
			return {}
		if category_games == 0:
			continue

		weighted_rating += category_rating * category_games
		games_played += category_games

	return {
		"rating": (
			STARTING_RATING
			if games_played == 0
			else weighted_rating / games_played
		),
		"games_played": games_played
	}

static func create_initial_rating() -> Dictionary:
	return {
		"rating": STARTING_RATING,
		"deviation": INITIAL_DEVIATION,
		"volatility": INITIAL_VOLATILITY,
		"last_played_at": 0
	}

static func update_after_game(
	player: Dictionary,
	opponent: Dictionary,
	score: float,
	timestamp: int = 0
) -> Dictionary:
	if is_nan(score) or is_inf(score) or score < 0.0 or score > 1.0:
		push_error("A game score must be between 0 and 1.")
		return {}

	if player.is_empty() or opponent.is_empty():
		push_error("Player and opponent rating data are required.")
		return {}

	var rating := float(player.get("rating", STARTING_RATING))
	var deviation := float(player.get("deviation", INITIAL_DEVIATION))
	var volatility := float(player.get("volatility", INITIAL_VOLATILITY))
	var opponent_rating := float(opponent.get("rating", STARTING_RATING))
	var opponent_deviation := float(opponent.get("deviation", INITIAL_DEVIATION))
	if (
		is_nan(rating) or is_inf(rating) or rating <= 0.0
		or is_nan(deviation) or is_inf(deviation) or deviation <= 0.0
		or is_nan(volatility) or is_inf(volatility) or volatility <= 0.0
		or is_nan(opponent_rating) or is_inf(opponent_rating) or opponent_rating <= 0.0
		or is_nan(opponent_deviation) or is_inf(opponent_deviation)
		or opponent_deviation <= 0.0
	):
		push_error("Glicko-2 rating, deviation, and volatility values must be finite and positive.")
		return {}

	var mu := (rating - 1500.0) / GLICKO2_SCALE
	var phi := deviation / GLICKO2_SCALE
	var opponent_mu := (opponent_rating - 1500.0) / GLICKO2_SCALE
	var opponent_phi := opponent_deviation / GLICKO2_SCALE
	var g := 1.0 / sqrt(1.0 + 3.0 * pow(opponent_phi, 2.0) / pow(PI, 2.0))
	var expected := 1.0 / (1.0 + exp(-g * (mu - opponent_mu)))
	var variance_inverse := pow(g, 2.0) * expected * (1.0 - expected)
	if variance_inverse <= 0.0:
		push_error("Could not calculate a valid Glicko-2 variance.")
		return {}
	var variance := 1.0 / variance_inverse
	var delta_sum := g * (score - expected)
	var delta := variance * delta_sum

	var log_volatility_squared := log(pow(volatility, 2.0))
	var lower_bound := log_volatility_squared
	var upper_bound: float
	if pow(delta, 2.0) > pow(phi, 2.0) + variance:
		upper_bound = log(pow(delta, 2.0) - pow(phi, 2.0) - variance)
	else:
		var step := 1
		while _volatility_function(
			log_volatility_squared - step * TAU,
			log_volatility_squared,
			delta,
			phi,
			variance
		) < 0.0 and step < 100:
			step += 1
		upper_bound = log_volatility_squared - step * TAU

	var lower_value := _volatility_function(
		lower_bound,
		log_volatility_squared,
		delta,
		phi,
		variance
	)
	var upper_value := _volatility_function(
		upper_bound,
		log_volatility_squared,
		delta,
		phi,
		variance
	)
	var iterations := 0
	while abs(upper_bound - lower_bound) > EPSILON and iterations < 100:
		var denominator := upper_value - lower_value
		if is_zero_approx(denominator):
			break
		var candidate := lower_bound + (
			(lower_bound - upper_bound) * lower_value / denominator
		)
		var candidate_value := _volatility_function(
			candidate,
			log_volatility_squared,
			delta,
			phi,
			variance
		)
		if candidate_value * upper_value <= 0.0:
			lower_bound = upper_bound
			lower_value = upper_value
		else:
			lower_value /= 2.0
		upper_bound = candidate
		upper_value = candidate_value
		iterations += 1

	var new_volatility := exp(lower_bound / 2.0)
	var phi_star := sqrt(pow(phi, 2.0) + pow(new_volatility, 2.0))
	var new_phi := 1.0 / sqrt(1.0 / pow(phi_star, 2.0) + 1.0 / variance)
	var new_mu := mu + pow(new_phi, 2.0) * delta_sum
	var updated_rating := clampf(
		GLICKO2_SCALE * new_mu + 1500.0,
		MIN_RATING,
		MAX_RATING
	)

	return {
		"rating": updated_rating,
		"deviation": clampf(GLICKO2_SCALE * new_phi, MIN_DEVIATION, MAX_DEVIATION),
		"volatility": clampf(new_volatility, MIN_VOLATILITY, MAX_VOLATILITY),
		"last_played_at": timestamp
	}

static func _volatility_function(
	value: float,
	log_volatility_squared: float,
	delta: float,
	phi: float,
	variance: float
) -> float:
	var exponential := exp(value)
	var denominator := 2.0 * pow(pow(phi, 2.0) + variance + exponential, 2.0)
	return (
		exponential * (pow(delta, 2.0) - pow(phi, 2.0) - variance - exponential)
		/ denominator
		- (value - log_volatility_squared) / pow(TAU, 2.0)
	)
