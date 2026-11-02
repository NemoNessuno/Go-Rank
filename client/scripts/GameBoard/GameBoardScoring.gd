class_name GameBoardScoring
extends RefCounted

const EMPTY := 0
const BLACK := 1
const WHITE := 2

func estimate_score(board: Array, black_captures: int, white_captures: int, komi_value: float, territory_dots: Array = []) -> Dictionary:
	var dead_stones := estimate_dead_stones(board)
	var effective_territory := territory_dots if not territory_dots.is_empty() else calculate_territory_dots(board)
	var black_territory := 0
	var white_territory := 0
	var black_stones := 0
	var white_stones := 0

	for y in range(board.size()):
		for x in range(board[y].size()):
			if board[y][x] == BLACK:
				black_stones += 1
			elif board[y][x] == WHITE:
				white_stones += 1

	for y in range(board.size()):
		for x in range(board[y].size()):
			if board[y][x] != EMPTY:
				continue
			var position := Vector2i(x, y)
			var territory_owner := -1
			for marker in effective_territory:
				if marker["region"].has(position):
					territory_owner = int(marker["color"])
					break
			if territory_owner == BLACK:
				black_territory += 1
			elif territory_owner == WHITE:
				white_territory += 1

	var black_total : float = (black_stones - dead_stones["black"]) + (black_captures + dead_stones["white"]) + black_territory
	var white_total : float = (white_stones - dead_stones["white"]) + (white_captures + dead_stones["black"]) + white_territory + komi_value
	return {"black": black_total, "white": white_total}

func calculate_territory_dots(board: Array) -> Array:
	var visited: Dictionary = {}
	var territory_dots: Array = []
	for y in range(board.size()):
		for x in range(board[y].size()):
			var position := Vector2i(x, y)
			if board[y][x] != EMPTY or visited.has(position):
				continue

			var region: Array = []
			var queue: Array = [position]
			visited[position] = true
			var border_colors: Dictionary = {}

			while queue.size() > 0:
				var current: Vector2i = queue.pop_back()
				region.append(current)
				for neighbor in _neighbors(current.x, current.y, board.size()):
					var nx: int = neighbor.x
					var ny: int = neighbor.y
					var next_position := Vector2i(nx, ny)
					if board[ny][nx] == EMPTY:
						if not visited.has(next_position):
							visited[next_position] = true
							queue.push_back(next_position)
					else:
						border_colors[board[ny][nx]] = true

			if border_colors.has(BLACK) and not border_colors.has(WHITE):
				territory_dots.append({"color": BLACK, "region": region})
			elif border_colors.has(WHITE) and not border_colors.has(BLACK):
				territory_dots.append({"color": WHITE, "region": region})

	return territory_dots

func estimate_dead_stones(board: Array) -> Dictionary:
	var dead: Dictionary = {"black": 0, "white": 0}
	var seen_groups: Dictionary = {}

	for y in range(board.size()):
		for x in range(board[y].size()):
			if board[y][x] == EMPTY:
				continue
			var color: int = board[y][x]
			var position := Vector2i(x, y)
			if seen_groups.has(position):
				continue
			var group := _collect_group(board, x, y, color)
			for stone in group:
				seen_groups[stone] = true
			var liberties := 0
			var surrounding_colors: Dictionary = {}
			for stone in group:
				for neighbor in _neighbors(stone.x, stone.y, board.size()):
					var neighbor_color: int = board[neighbor.y][neighbor.x]
					if neighbor_color == EMPTY:
						liberties += 1
					else:
						surrounding_colors[neighbor_color] = true

			if surrounding_colors.has(BLACK) and surrounding_colors.has(WHITE):
				continue
			if liberties <= 1 and surrounding_colors.has(_opponent(color)) and not surrounding_colors.has(color):
				if color == BLACK:
					dead["black"] += group.size()
				else:
					dead["white"] += group.size()

	return dead

func calculate_final_score(board: Array, black_captures: int, white_captures: int, komi_value: float, territory_dots: Array = []) -> Dictionary:
	return estimate_score(board, black_captures, white_captures, komi_value, territory_dots)

func _collect_group(board: Array, start_x: int, start_y: int, color: int) -> Array:
	var result: Array = []
	var queue: Array = [Vector2i(start_x, start_y)]
	var visited: Dictionary = {}

	while queue.size() > 0:
		var position: Vector2i = queue.pop_back()
		if visited.has(position):
			continue
		visited[position] = true
		result.append(position)

		for neighbor in _neighbors(position.x, position.y, board.size()):
			var nx: int = neighbor.x
			var ny: int = neighbor.y
			if board[ny][nx] == color and not visited.has(Vector2i(nx, ny)):
				queue.push_back(Vector2i(nx, ny))

	return result

func _neighbors(x: int, y: int, board_size: int) -> Array:
	var result: Array = []
	var candidates := [
		Vector2i(x + 1, y),
		Vector2i(x - 1, y),
		Vector2i(x, y + 1),
		Vector2i(x, y - 1)
	]
	for candidate in candidates:
		if candidate.x < 0 or candidate.x >= board_size or candidate.y < 0 or candidate.y >= board_size:
			continue
		result.append(candidate)
	return result

func _opponent(player: int) -> int:
	return WHITE if player == BLACK else BLACK
