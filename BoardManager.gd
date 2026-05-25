extends Node2D

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const CELL_SIZE := 128
const START_CARD_GRID_POS := Vector2i(2, 3)

var cells := {}
var card_units := {}
var selected_unit = null
var current_turn := "player"

const CARD_UNIT_SCENE := preload("res://CardUnit.tscn")

@onready var turn_label = $CanvasLayer/TurnLabel
@onready var end_turn_button = $CanvasLayer/EndTurnButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_board()
	spawn_unit(Vector2i(2, 4), "♠", "A", 6, 1, "player")
	spawn_unit(Vector2i(2, 2), "♥", "3", 6, 1, "enemy")
	spawn_unit(Vector2i(1,4), "♣", "4", 6, 1, "player")
	spawn_unit(Vector2i(3,4), "♥", "5", 6, 1, "player")
	spawn_unit(Vector2i(2,1), "♠", "7", 6, 1, "enemy")

	end_turn_button.pressed.connect(end_turn)
	update_turn_label()

func generate_board():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell := create_cell(x,y)
			add_child(cell)
			cells[Vector2i(x,y)] = cell

func create_cell(x:int, y:int) -> Button:
	var cell := Button.new()

	cell.size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)

	cell.text = "%d,%d" % [x,y]

	if (x + y) % 2 == 0:
		cell.self_modulate = Color(0.75,0.75,0.75)
	else:
		cell.self_modulate = Color(0.15,0.15,0.15)

	cell.add_theme_color_override("font_color", Color.WHITE)

	cell.set_meta("grid_pos", Vector2i(x,y))

	cell.pressed.connect(_on_cell_pressed.bind(cell))

	return cell

func _on_cell_pressed(cell: Button):
	var grid_pos: Vector2i = cell.get_meta("grid_pos")
	print("Clicked cell: ", grid_pos)

	if selected_unit == null:
		return

	if card_units.has(grid_pos):
		print("This cell is occupied.")
		return

	var is_movable = cell.get_meta("movable", false)
	if is_movable:
		move_unit(selected_unit, grid_pos)
		selected_unit.has_acted = true
		selected_unit.update_outline()
		selected_unit = null
		clear_highlights()

func spawn_unit(grid_pos: Vector2i, suit: String, rank: String, hp: int, atk: int, owner: String):
	var unit = CARD_UNIT_SCENE.instantiate()
	add_child(unit)

	unit.setup(grid_pos, suit, rank, hp, atk, owner)

	unit.position = Vector2(
		grid_pos.x * CELL_SIZE + 8,
		grid_pos.y * CELL_SIZE + 8
	)

	card_units[grid_pos] = unit
	
	unit.unit_clicked.connect(_on_unit_clicked)

func _on_unit_clicked(unit):
	if selected_unit == null:
		if unit.unit_owner == current_turn:
			if unit.has_acted:
				print("This unit has already acted.")
				return

			selected_unit = unit
			selected_unit.update_outline(true)
			print("Selected unit: ", unit.rank, unit.suit)
			highlight_movable_cells(unit)
		else:
			print("Not your turn.")
		return

	if unit.unit_owner != selected_unit.unit_owner:
		if is_adjacent(selected_unit.grid_pos, unit.grid_pos):
			attack_unit(selected_unit, unit)
			selected_unit.has_acted = true
			selected_unit.update_outline()
			selected_unit = null
			clear_highlights()
		else:
			print("Enemy is too far away.")
		return

	if unit.unit_owner == current_turn:
		selected_unit = unit
		selected_unit.update_outline(true)
		print("Selected unit: ", unit.rank, unit.suit)
		highlight_movable_cells(unit)

func highlight_movable_cells(unit):
	clear_highlights()
	unit.update_outline(true)

	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for dir in directions:
		for step in range(1, unit.move_range + 1):
			var target_pos = unit.grid_pos + dir * step

			if cells.has(target_pos):
				var cell = cells[target_pos]
				cell.self_modulate = Color(0.2, 1.0, 0.2)
				cell.set_meta("movable", true)
	highlight_attackable_units(unit)

func clear_highlights():
	for grid_pos in cells.keys():
		var cell = cells[grid_pos]
		cell.set_meta("movable", false)

		if (grid_pos.x + grid_pos.y) % 2 == 0:
			cell.self_modulate = Color(0.75, 0.75, 0.75)
		else:
			cell.self_modulate = Color(0.15, 0.15, 0.15)

	for unit in card_units.values():
		unit.update_outline()

func move_unit(unit, new_grid_pos: Vector2i):
	var old_grid_pos = unit.grid_pos

	card_units.erase(old_grid_pos)

	unit.grid_pos = new_grid_pos
	unit.position = Vector2(
		new_grid_pos.x * CELL_SIZE + 8,
		new_grid_pos.y * CELL_SIZE + 8
	)

	card_units[new_grid_pos] = unit

	print("Moved unit to: ", new_grid_pos)

func attack_unit(attacker, target):
	target.hp -= attacker.atk
	target.update_display()

	print("Before/After attack, target HP: ", target.hp)

	if target.hp <= 0:
		print(target.rank, target.suit, " defeated")
		card_units.erase(target.grid_pos)
		target.queue_free()

func is_adjacent(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	var diff = pos_a - pos_b
	return abs(diff.x) + abs(diff.y) == 1

func highlight_attackable_units(unit):
	for other_unit in card_units.values():
		if other_unit.unit_owner != unit.unit_owner:
			if is_adjacent(unit.grid_pos, other_unit.grid_pos):
				other_unit.update_outline(false, true)

func end_turn():
	selected_unit = null
	clear_highlights()

	if current_turn == "player":
		current_turn = "enemy"
	else:
		current_turn = "player"

	for unit in card_units.values():
		unit.has_acted = false
		unit.update_outline()

	print("Current turn: ", current_turn)
	update_turn_label()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		end_turn()

func update_turn_label():
	turn_label.text = "Current Turn: " + current_turn
	
