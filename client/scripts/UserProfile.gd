extends Control

const RatingSystemScript := preload("res://server/scripts/ratings/RatingSystem.gd")

@onready var avatar_panel: PanelContainer = $ProfilePanel/MarginContainer/Layout/Content/Identity/AvatarCenter/AvatarPanel
@onready var avatar_initial: Label = $ProfilePanel/MarginContainer/Layout/Content/Identity/AvatarCenter/AvatarPanel/AvatarInitial
@onready var username_label: Label = $ProfilePanel/MarginContainer/Layout/Content/Identity/UsernameLabel
@onready var status_label: Label = $ProfilePanel/MarginContainer/Layout/Content/RatingsPanel/RatingsMargin/RatingsLayout/StatusLabel
@onready var rating_labels: Dictionary = {
	"9x9": $ProfilePanel/MarginContainer/Layout/Content/RatingsPanel/RatingsMargin/RatingsLayout/RatingsContainer/Rating9x9/RatingLabel,
	"13x13": $ProfilePanel/MarginContainer/Layout/Content/RatingsPanel/RatingsMargin/RatingsLayout/RatingsContainer/Rating13x13/RatingLabel,
	"19x19": $ProfilePanel/MarginContainer/Layout/Content/RatingsPanel/RatingsMargin/RatingsLayout/RatingsContainer/Rating19x19/RatingLabel,
	"tsume-go": $ProfilePanel/MarginContainer/Layout/Content/RatingsPanel/RatingsMargin/RatingsLayout/RatingsContainer/RatingTsumeGo/RatingLabel
}

func _ready() -> void:
	$ProfilePanel/MarginContainer/Layout/Header/BackButton.pressed.connect(_on_back_pressed)
	Network.profile_ratings_received.connect(_on_profile_ratings_received)
	Network.profile_ratings_request_failed.connect(_on_profile_ratings_request_failed)

	if Network.current_user == null:
		status_label.text = "Please log in to view your profile."
		return

	_set_user_details()
	if not Network.current_profile_ratings.is_empty():
		_render_profile_ratings(Network.current_profile_ratings)
	status_label.text = "Refreshing ratings..."
	if not Network.request_profile_ratings():
		if Network.current_profile_ratings.is_empty():
			status_label.text = "Unable to load ratings while disconnected from the server."
		else:
			status_label.text = "Showing the last loaded ratings while disconnected."

func _set_user_details() -> void:
	var user: UserData = Network.current_user
	username_label.text = user.name
	avatar_initial.text = user.name.left(1).to_upper() if not user.name.is_empty() else "?"
	if user.avatar != null:
		var avatar_style := avatar_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		avatar_style.bg_color = Color(user.avatar.color)
		avatar_panel.add_theme_stylebox_override("panel", avatar_style)

func _render_profile_ratings(profile: Dictionary) -> void:
	var categories: Dictionary = profile.get("categories", {})
	if categories.is_empty():
		status_label.text = "No rating data is available."
		return

	for category_name in rating_labels:
		var category: Dictionary = categories.get(category_name, {})
		if category.is_empty():
			continue
		var rating := float(category.get("rating", RatingSystemScript.STARTING_RATING))
		var games_played := int(category.get("games_played", 0))
		rating_labels[category_name].text = "%s  (%.1f)\n%d rated games" % [
			RatingSystemScript.format_rank_label(rating),
			rating,
			games_played
		]
	status_label.text = ""

func _on_profile_ratings_received(profile: Dictionary) -> void:
	_render_profile_ratings(profile)

func _on_profile_ratings_request_failed(message: String) -> void:
	status_label.text = message

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://client/scenes/Overworld.tscn")
