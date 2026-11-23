class_name VariationTreeNode
extends Button

const NODE_DIAMETER := 48.0
const SELECTED_BORDER := Color("#f0c84b")
const DEFAULT_BORDER := Color("#a8a8a8")

func configure(
	label: String,
	stone_color: int,
	is_root: bool,
	is_selected: bool
) -> void:
	text = "" if is_root else label
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_NONE
	var background := Color("#858585") if is_root else (
		Color("#171717")
		if stone_color == GameBoardState.BLACK
		else Color("#f5f5f5")
	)
	var font_color := Color.WHITE if (
		is_root or stone_color == GameBoardState.BLACK
	) else Color.BLACK
	var base_style := get_theme_stylebox("normal") as StyleBoxFlat
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := base_style.duplicate() as StyleBoxFlat
		style.bg_color = background
		style.border_color = SELECTED_BORDER if is_selected else DEFAULT_BORDER
		style.set_border_width_all(3 if is_selected else 1)
		style.set_corner_radius_all(int(NODE_DIAMETER / 2.0))
		add_theme_stylebox_override(state, style)
	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color"
	]:
		add_theme_color_override(color_name, font_color)
