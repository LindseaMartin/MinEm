extends Node2D

enum WallType { NONE, TAN_SOIL, DARKER_SOIL, LARGE_ROCK }
const GRID_SIZE = 10
const CELL_SIZE = Vector2(64, 64)  # Replace this value with the size of your tiles

var grid : Array
var tile_map : TileMap
var is_wall_collapsed : bool = false
var click_count : int = 0
const MIN_CLICKS_BEFORE_COLLAPSE = 3

func _ready():
	tile_map = $TileMap
	initialize_grid()
	spawn_cave_wall()

func initialize_grid():
	grid = []
	for _i in range(GRID_SIZE):
		grid.append([])
		for _j in range(GRID_SIZE):
			grid[-1].append(WallType.TAN_SOIL)

func spawn_cave_wall():
	for i in range(GRID_SIZE):
		for j in range(GRID_SIZE):
			tile_map.set_cell(i, Vector2i(j, 0), grid[i][j])

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if not is_wall_collapsed:
			handle_click(event.position)

func handle_click(position: Vector2):
	var x = int(position.x / CELL_SIZE.x)
	var y = int(position.y / CELL_SIZE.y)

	if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
		grid[x][y] = min(grid[x][y] + 1, WallType.LARGE_ROCK + 1)
		if grid[x][y] > WallType.LARGE_ROCK:
			grid[x][y] = WallType.NONE
		tile_map.set_cell(x, Vector2i(y, 0), grid[x][y])

		click_count += 1
		if click_count >= MIN_CLICKS_BEFORE_COLLAPSE:
			is_wall_collapsed = true
			# Reward player with what they dug up before the wall collapsed
			print("Wall collapsed. Game Over.")
			# TODO: Implement a proper reward system

func check_wall_collapse() -> bool:
	# TODO: Implement a more sophisticated wall collapse check
	for row in grid:
		for cell in row:
			if cell == WallType.LARGE_ROCK:
				return false
	return true
