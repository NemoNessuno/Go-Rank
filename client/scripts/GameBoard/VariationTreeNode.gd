class_name VariationTreeNode
extends GraphNode

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	title = ""

	var invisible_style := StyleBoxFlat.new()
	invisible_style.bg_color = Color(0, 0, 0, 0)
	invisible_style.set_border_width_all(0)
	invisible_style.set_corner_radius_all(0)
	
	var round_style := StyleBoxFlat.new()
	round_style.set_border_width_all(2)
	round_style.set_corner_radius_all(40)
	
	add_theme_stylebox_override("titlebar", round_style)
	add_theme_stylebox_override("titlebar_selected", round_style)
	add_theme_stylebox_override("panel", invisible_style)
	add_theme_stylebox_override("panel_selected", invisible_style)
		
	custom_minimum_size = Vector2(28, 6)
	size = Vector2(28, 6)
