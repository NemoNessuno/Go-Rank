extends Control

const RatingSystemScript := preload("res://server/RatingSystem.gd")

var avatar_panel: PanelContainer
var avatar_initial: Label
var username_label: Label
var ratings_container: VBoxContainer
var status_label: Label

func _ready() -> void:
	_build_ui()
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

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#1c2e47")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_top = -330
	panel.offset_right = 560
	panel.offset_bottom = 330
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#263b57")
	panel_style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Player profile"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(1.0, 0.8, 0.4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 48)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content)

	var identity := VBoxContainer.new()
	identity.custom_minimum_size = Vector2(300, 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 18)
	content.add_child(identity)

	var avatar_center := CenterContainer.new()
	identity.add_child(avatar_center)
	avatar_panel = PanelContainer.new()
	avatar_panel.custom_minimum_size = Vector2(220, 220)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = Color("#4ec9f5")
	avatar_style.set_corner_radius_all(110)
	avatar_panel.add_theme_stylebox_override("panel", avatar_style)
	avatar_center.add_child(avatar_panel)

	avatar_initial = Label.new()
	avatar_initial.text = "?"
	avatar_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_initial.add_theme_font_size_override("font_size", 88)
	avatar_panel.add_child(avatar_initial)

	username_label = Label.new()
	username_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	username_label.add_theme_font_size_override("font_size", 24)
	identity.add_child(username_label)

	var ratings_panel := PanelContainer.new()
	ratings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ratings_style := StyleBoxFlat.new()
	ratings_style.bg_color = Color("#1c2e47")
	ratings_style.set_corner_radius_all(10)
	ratings_panel.add_theme_stylebox_override("panel", ratings_style)
	content.add_child(ratings_panel)

	var ratings_margin := MarginContainer.new()
	ratings_margin.add_theme_constant_override("margin_left", 22)
	ratings_margin.add_theme_constant_override("margin_top", 20)
	ratings_margin.add_theme_constant_override("margin_right", 22)
	ratings_margin.add_theme_constant_override("margin_bottom", 20)
	ratings_panel.add_child(ratings_margin)

	var ratings_layout := VBoxContainer.new()
	ratings_layout.add_theme_constant_override("separation", 12)
	ratings_margin.add_child(ratings_layout)

	var ratings_title := Label.new()
	ratings_title.text = "Current ratings"
	ratings_title.add_theme_font_size_override("font_size", 22)
	ratings_layout.add_child(ratings_title)

	var weighting_note := Label.new()
	weighting_note.text = "Unified rating weights each category by rated games played."
	weighting_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ratings_layout.add_child(weighting_note)

	ratings_container = VBoxContainer.new()
	ratings_container.add_theme_constant_override("separation", 10)
	ratings_layout.add_child(ratings_container)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.modulate = Color("#f0c674")
	ratings_layout.add_child(status_label)

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

	for child in ratings_container.get_children():
		child.queue_free()

	for category_name in ["9x9", "13x13", "19x19", "tsume-go"]:
		var category: Dictionary = categories.get(category_name, {})
		if category.is_empty():
			continue
		_add_rating_row(category_name, category)
	status_label.text = ""

func _add_rating_row(category_name: String, category: Dictionary) -> void:
	var rating := float(category.get("rating", RatingSystemScript.STARTING_RATING))
	var games_played := int(category.get("games_played", 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	ratings_container.add_child(row)

	var category_label := Label.new()
	category_label.text = category_name
	category_label.add_theme_font_size_override("font_size", 18)
	category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(category_label)

	var rating_label := Label.new()
	rating_label.text = "%s  (%.1f)\n%d rated games" % [
		RatingSystemScript.format_rank_label(rating),
		rating,
		games_played
	]
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(rating_label)

func _on_profile_ratings_received(profile: Dictionary) -> void:
	_render_profile_ratings(profile)

func _on_profile_ratings_request_failed(message: String) -> void:
	status_label.text = message

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://client/scenes/Overworld.tscn")
