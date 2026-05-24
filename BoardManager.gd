extends Node2D

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const CELL_SIZE := 96

var cells := {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_board()


func generate_board():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell := create_cell(x,y)
			add_child(cell)
			cells[Vector2i(x,y)] = cell

func create_cell(x:int, y:int) -> Button:
	var cell := Button.new()
	cell.size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.position = Vector2( x * CELL_SIZE, y * CELL_SIZE)
	cell.text = "%d, %d" % [x, y]
	
	cell.set_meta("grid_pos", Vector2i(x, y))
	
	# alter color based on the grid
	if (x + y) % 2 == 0:
		cell.modulate = Color(0.75,0.75,0.75);
	else:
		cell.modulate = Color(0.15,0.15,0.15);
	
	# record coordinate
	cell.pressed.connect(_on_cell_pressed.bind(cell))
	
	return cell

func _on_cell_pressed(cell: Button):
	var grid_pos: Vector2i = cell.get_meta("grid_pos")
	print("Clicked cell: ", grid_pos)
