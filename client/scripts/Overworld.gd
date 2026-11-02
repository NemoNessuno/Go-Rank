extends Control

const DATA_PATH := "user://students.json"
const DEFAULT_STYLES := [
	"Stone Monk",
	"Zen Hare",
	"Temple Guard",
    "Cloud Scout"
]

@onready var map_panel: Panel = $MapPanel
@onready var sidebar: Panel = $Sidebar

var students: Array = []
var selected_index: int = -1
var avatar_buttons: Array = []
var name_input: LineEdit
var style_select: OptionButton
var color_picker: ColorPickerButton
var stat_label: Label

func _ready() -> void:
	_build_sidebar()
	_ensure_world_container()
	_load_students()
	if students.is_empty():
		_seed_sample_students()
	_render_students()
	if students.size() > 0:
		_select_student(0)

func _build_sidebar() -> void:
	var content := VBoxContainer.new()
	content.name = "SidebarContent"
	content.position = Vector2(18, 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	sidebar.add_child(content)

	var title := Label.new()
	title.text = "Go Academy"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(1.0, 0.8, 0.4)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Student Overworld"
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	var name_label := Label.new()
	name_label.text = "Student name"
	content.add_child(name_label)

	name_input = LineEdit.new()
	name_input.placeholder_text = "e.g. Hana"
	content.add_child(name_input)

	var style_label := Label.new()
	style_label.text = "Avatar style"
	content.add_child(style_label)

	style_select = OptionButton.new()
	for style in DEFAULT_STYLES:
		style_select.add_item(style)
	content.add_child(style_select)

	var color_label := Label.new()
	color_label.text = "Avatar color"
	content.add_child(color_label)

	color_picker = ColorPickerButton.new()
	color_picker.color = Color("#5ad1ff")
	content.add_child(color_picker)

	var create_button := Button.new()
	create_button.text = "Create avatar"
	create_button.pressed.connect(_on_create_student_pressed)
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(create_button)

	var board_button := Button.new()
	board_button.text = "Open 9x9 Go board"
	board_button.pressed.connect(_on_open_board_pressed)
	board_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(board_button)

	var separator := HSeparator.new()
	content.add_child(separator)

	stat_label = Label.new()
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label.custom_minimum_size = Vector2(200, 120)
	content.add_child(stat_label)

	var win_button := Button.new()
	win_button.text = "Record win"
	win_button.pressed.connect(_on_record_win_pressed)
	content.add_child(win_button)

	var loss_button := Button.new()
	loss_button.text = "Record loss"
	loss_button.pressed.connect(_on_record_loss_pressed)
	content.add_child(loss_button)

func _ensure_world_container() -> Control:
	var existing := map_panel.get_node_or_null("WorldContainer")
	if existing != null:
		return existing
	var container := Control.new()
	container.name = "WorldContainer"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	map_panel.add_child(container)
	return container

func _seed_sample_students() -> void:
	students = [
		{"name": "Aiko", "style": "Stone Monk", "color": "#52d6b7", "wins": 8, "losses": 2, "x": 70, "y": 80},
		{"name": "Milo", "style": "Cloud Scout", "color": "#ffb86b", "wins": 6, "losses": 5, "x": 250, "y": 180},
		{"name": "Sora", "style": "Zen Hare", "color": "#9d88ff", "wins": 7, "losses": 3, "x": 420, "y": 90}
	]
	_save_students()

func _load_students() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		return

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	if text.strip_edges() == "":
		return

	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("students"):
		students = parsed["students"]
	elif typeof(parsed) == TYPE_ARRAY:
		students = parsed

func _save_students() -> void:
	var data := {"students": students}
	var file := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))

func _render_students() -> void:
	var world_container := _ensure_world_container()
	for child in avatar_buttons:
		if is_instance_valid(child):
			child.queue_free()
	avatar_buttons.clear()

	for index in range(students.size()):
		var student: Dictionary = students[index]
		var button := Button.new()
		button.name = "StudentButton_%d" % index
		button.custom_minimum_size = Vector2(170, 60)
		button.position = Vector2(float(student.get("x", 20.0 + index * 40)), float(student.get("y", 40.0 + (index % 3) * 70)))
		button.size = Vector2(170, 70)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_student_button_pressed.bind(index))
		button.text = "%s\n%s wins • %s losses" % [student.get("name", "Student"), student.get("wins", 0), student.get("losses", 0)]
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color(1, 1, 1))
		button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1))

		var style := StyleBoxFlat.new()
		style.bg_color = Color(student.get("color", "#4ec9f5"))
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.corner_radius_bottom_left = 20
		style.corner_radius_bottom_right = 20
		style.border_color = Color(1, 1, 1, 0.35)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)

		if index == selected_index:
			style.border_color = Color(1, 0.88, 0.2, 1)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("hover", style)
			button.add_theme_stylebox_override("pressed", style)
			button.add_theme_stylebox_override("focus", style)

		world_container.add_child(button)
		avatar_buttons.append(button)

func _on_student_button_pressed(index: int) -> void:
	_select_student(index)

func _select_student(index: int) -> void:
	selected_index = index
	_render_students()
	_update_stat_panel()

func _update_stat_panel() -> void:
	if selected_index < 0 or selected_index >= students.size():
		stat_label.text = "No student selected."
		return

	var student: Dictionary = students[selected_index]
	stat_label.text = (
		"Name: %s\n" +
		"Style: %s\n" +
		"Record: %s wins / %s losses\n" +
		"Games: %s\n" +
        "Color: %s"
	) % [
		student.get("name", "Student"),
		student.get("style", "Unknown"),
		student.get("wins", 0),
		student.get("losses", 0),
		int(student.get("wins", 0)) + int(student.get("losses", 0)),
		student.get("color", "#5ad1ff")
	]

func _on_create_student_pressed() -> void:
	var name_text := name_input.text.strip_edges()
	if name_text == "":
		name_text = "Student %d" % (students.size() + 1)

	var new_student := {
		"name": name_text,
		"style": DEFAULT_STYLES[style_select.selected],
		"color": color_picker.color.to_html(),
		"wins": 0,
		"losses": 0,
		"x": 80 + (students.size() * 70) % 340,
		"y": 60 + (students.size() % 4) * 80
	}

	students.append(new_student)
	selected_index = students.size() - 1
	name_input.text = ""
	_save_students()
	_render_students()
	_update_stat_panel()

func _on_record_win_pressed() -> void:
	if selected_index < 0 or selected_index >= students.size():
		return

	students[selected_index]["wins"] = int(students[selected_index].get("wins", 0)) + 1
	_save_students()
	_render_students()
	_update_stat_panel()

func _on_record_loss_pressed() -> void:
	if selected_index < 0 or selected_index >= students.size():
		return

	students[selected_index]["losses"] = int(students[selected_index].get("losses", 0)) + 1
	_save_students()
	_render_students()
	_update_stat_panel()

func _on_open_board_pressed() -> void:
	get_tree().change_scene_to_file("res://client/scenes/GameBoard.tscn")
