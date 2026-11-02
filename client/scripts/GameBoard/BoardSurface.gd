extends Control

var board_owner: Node
var hovered_cell: Vector2i = Vector2i(-1, -1)

const BOARD_SIZE := 9

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP

func _has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	return target.get(property_name) != null

func get_board_geometry() -> Dictionary:
	var usable_size : float = min(size.x, size.y)
	usable_size = clamp(usable_size, 280.0, 520.0)
	var offset := (size - Vector2(usable_size, usable_size)) * 0.5
	var rect := Rect2(offset, Vector2(usable_size, usable_size))
	var origin := rect.position
	var step := rect.size.x / float(BOARD_SIZE - 1)
	return {
		"rect": rect,
		"origin": origin,
		"step": step
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_draw_board()

func _draw_board() -> void:
	if board_owner == null:
		return
	if not _has_property(board_owner, "board"):
		return

	var geometry := get_board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var board_origin: Vector2 = geometry["origin"]
	var board_step: float = geometry["step"]
	if _has_property(board_owner, "board_rect"):
		board_owner.board_rect = board_rect
	if _has_property(board_owner, "board_origin"):
		board_owner.board_origin = board_origin
	if _has_property(board_owner, "board_step"):
		board_owner.board_step = board_step

	var wood_color := Color(0.86, 0.73, 0.48)
	var line_color := Color(0.32, 0.22, 0.12)
	draw_rect(Rect2(Vector2.ZERO, size), wood_color, true)
	draw_rect(board_rect, wood_color, true)
	draw_rect(board_rect, line_color, false, 2.5)

	for i in range(BOARD_SIZE):
		var x : float = board_origin.x + i * board_step
		var y : float = board_origin.y + i * board_step
		draw_line(Vector2(x, board_origin.y), Vector2(x, board_origin.y + board_step * (BOARD_SIZE - 1)), line_color, 2.0)
		draw_line(Vector2(board_origin.x, y), Vector2(board_origin.x + board_step * (BOARD_SIZE - 1), y), line_color, 2.0)

	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			if board_owner.board[y][x] == 0:
				continue
			var center := Vector2(board_origin.x + x * board_step, board_origin.y + y * board_step)
			var stone_color := Color(0.09, 0.09, 0.09) if board_owner.board[y][x] == board_owner.BLACK else Color(0.96, 0.96, 0.96)
			draw_circle(center, board_step * 0.42, stone_color)
			draw_circle(center, board_step * 0.42, Color(0.0, 0.0, 0.0, 0.0), false, 1.5)

	var stars := [
		Vector2i(2, 2),
		Vector2i(2, 6),
		Vector2i(4, 4),
		Vector2i(6, 2),
		Vector2i(6, 6)
	]
	for star in stars:
		var star_center := Vector2(board_origin.x + star.x * board_step, board_origin.y + star.y * board_step)
		draw_circle(star_center, 5.0, Color(0.08, 0.08, 0.08))

	if _has_property(board_owner, "territory_dots") and not board_owner.territory_dots.is_empty():
		for marker in board_owner.territory_dots:
			var region: Array = marker["region"]
			if region.is_empty():
				continue
			var dot_color := Color(0.08, 0.08, 0.08) if marker["color"] == board_owner.BLACK else Color(0.96, 0.96, 0.96)
			for cell in region:
				var center := Vector2(board_origin.x + int(cell.x) * board_step, board_origin.y + int(cell.y) * board_step)
				draw_circle(center, maxf(board_step * 0.12, 2.5), dot_color)

	if hovered_cell != Vector2i(-1, -1):
		if hovered_cell.x < 0 or hovered_cell.x >= BOARD_SIZE or hovered_cell.y < 0 or hovered_cell.y >= BOARD_SIZE:
			return
		if _has_property(board_owner, "board") and board_owner.board[hovered_cell.y][hovered_cell.x] == 0:
			var hover_center := Vector2(board_origin.x + hovered_cell.x * board_step, board_origin.y + hovered_cell.y * board_step)
			var hover_color := Color(0.09, 0.09, 0.09, 0.45) if board_owner.current_player == board_owner.BLACK else Color(0.96, 0.96, 0.96, 0.45)
			draw_circle(hover_center, board_step * 0.42, hover_color)

func _gui_input(event: InputEvent) -> void:
	if board_owner == null:
		return
	if event is InputEventMouseMotion:
		var mouse_position := get_local_mouse_position()
		if board_owner.has_method("_screen_to_cell"):
			hovered_cell = board_owner._screen_to_cell(mouse_position)
			queue_redraw()
		else:
			hovered_cell = Vector2i(-1, -1)
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			board_owner._on_board_gui_input(event)

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			queue_redraw()
