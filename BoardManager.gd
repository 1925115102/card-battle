extends Node2D

const GRID_WIDTH := 6
const GRID_HEIGHT := 6
const CELL_SIZE := 128
const START_CARD_GRID_POS := Vector2i(2, 3)
const BOARD_OFFSET := Vector2(0, 200)

var cells := {}
var card_units := {}
var selected_unit = null
var current_turn := "player"

var deck: Array = []
var discard_pile: Array = []

var player_hand: Array = []
var enemy_hand: Array = []

var player_deploy_zone := [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)
]

var enemy_deploy_zone := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)
]

var selected_hand_index: int = -1
var selected_hand_owner: String = ""

const CARD_UNIT_SCENE := preload("res://CardUnit.tscn")

@onready var turn_label = $CanvasLayer/TurnLabel
@onready var end_turn_button = $CanvasLayer/EndTurnButton
@onready var player_hand_container = $CanvasLayer/PlayerHandContainer
@onready var enemy_hand_container = $CanvasLayer/EnemyHandContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_board()

	build_deck()

	for i in range(5):
		draw_card("player")
		draw_card("enemy")

	deploy_from_hand("player", 0, Vector2i(1, 4))
	deploy_from_hand("player", 0, Vector2i(2, 4))
	deploy_from_hand("player", 0, Vector2i(3, 4))

	deploy_from_hand("enemy", 0, Vector2i(1, 1))
	deploy_from_hand("enemy", 0, Vector2i(2, 1))
	deploy_from_hand("enemy", 0, Vector2i(3, 1))

	end_turn_button.pressed.connect(end_turn)
	update_turn_label()
	update_hand_ui()
	update_enemy_hand_ui()

func generate_board():
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell := create_cell(x,y)
			add_child(cell)
			cells[Vector2i(x,y)] = cell

func create_cell(x:int, y:int) -> Button:
	var cell := Button.new()

	cell.size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.position = Vector2(
	x * CELL_SIZE,
	y * CELL_SIZE
) + BOARD_OFFSET

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

	if selected_hand_index != -1:
		deploy_from_hand(selected_hand_owner, selected_hand_index, grid_pos)
		selected_hand_index = -1
		selected_hand_owner = ""
		update_hand_ui()
		update_enemy_hand_ui()
		return

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

func spawn_unit(
	grid_pos: Vector2i,
	suit: String,
	rank: String,
	hp: int,
	atk: int,
	shield: int,
	move_range: int,
	attack_range: int,
	attack_area: int,
	action_count: int,
	owner: String
):
	var unit = CARD_UNIT_SCENE.instantiate()
	add_child(unit)

	unit.setup(
		grid_pos,
		suit,
		rank,
		hp,
		atk,
		shield,
		move_range,
		attack_range,
		attack_area,
		action_count,
		owner
	)

	unit.position = Vector2(
		grid_pos.x * CELL_SIZE + 8,
		grid_pos.y * CELL_SIZE + 8
	) + BOARD_OFFSET

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
		if is_in_attack_range(selected_unit, unit):
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
	) + BOARD_OFFSET

	card_units[new_grid_pos] = unit

	print("Moved unit to: ", new_grid_pos)

func attack_unit(attacker, target):
	var damage = attacker.atk

	if target.shield > 0:
		var shield_damage = min(target.shield, damage)
		target.shield -= shield_damage
		damage -= shield_damage

	if damage > 0:
		target.hp -= damage

	apply_element_effect(attacker, target)
	target.update_display()

	print(attacker.rank, attacker.suit, " attacked ", target.rank, target.suit)

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
			if is_in_attack_range(unit, other_unit):
				other_unit.update_outline(false, true)

func end_turn():
	selected_unit = null
	clear_highlights()

	if current_turn == "player":
		current_turn = "enemy"
	else:
		current_turn = "player"

	draw_card(current_turn)

	for unit in card_units.values():
		unit.has_acted = false
		unit.update_outline()

	update_turn_label()
	update_hand_ui()
	update_enemy_hand_ui()

	print("Current turn: ", current_turn)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		end_turn()

func update_turn_label():
	turn_label.text = "Current Turn: " + current_turn
	
func is_in_attack_range(attacker, target) -> bool:
	var diff = attacker.grid_pos - target.grid_pos
	var distance = abs(diff.x) + abs(diff.y)
	return distance <= attacker.attack_range
	
func apply_element_effect(attacker, target):
	match attacker.element:
		"air":
			add_status(target, "exposed")
		"water":
			add_status(target, "wet")
		"earth":
			add_status(target, "rooted")
		"fire":
			add_status(target, "burn")


func add_status(unit, status_name: String):
	if not unit.status_list.has(status_name):
		unit.status_list.append(status_name)
	print(unit.rank, unit.suit, " gained status: ", status_name)

func build_deck():
	var suits = ["♠", "♥", "♦", "♣"]
	var ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

	for suit in suits:
		for rank in ranks:
			deck.append({
				"suit": suit,
				"rank": rank,
				"hp": 6,
				"atk": 1,
				"shield": 0,
				"move": 1,
				"range": 1,
				"area": 1,
				"actions": 1
			})

	deck.shuffle()
	
func draw_card(owner: String):
	if deck.is_empty():
		deck = discard_pile.duplicate()
		discard_pile.clear()
		deck.shuffle()

	if deck.is_empty():
		return

	var card_data = deck.pop_back()

	if owner == "player":
		player_hand.append(card_data)
	else:
		enemy_hand.append(card_data)

	print(owner, " drew: ", card_data.rank if false else card_data["rank"], card_data["suit"])
	
func deploy_from_hand(owner: String, hand_index: int, grid_pos: Vector2i):
	var hand = player_hand if owner == "player" else enemy_hand
	var zone = player_deploy_zone if owner == "player" else enemy_deploy_zone

	if hand_index < 0 or hand_index >= hand.size():
		print("Invalid hand index")
		return

	if not zone.has(grid_pos):
		print("Not in deploy zone")
		return

	if card_units.has(grid_pos):
		print("Cell occupied")
		return

	var card_data = hand[hand_index]

	spawn_unit(
		grid_pos,
		card_data["suit"],
		card_data["rank"],
		card_data["hp"],
		card_data["atk"],
		card_data["shield"],
		card_data["move"],
		card_data["range"],
		card_data["area"],
		card_data["actions"],
		owner
	)

	hand.remove_at(hand_index)

func update_hand_ui():
	for child in player_hand_container.get_children():
		child.queue_free()

	for i in range(player_hand.size()):
		var card_data = player_hand[i]

		var button := Button.new()
		button.custom_minimum_size = Vector2(100, 140)
		button.text = ""

		var card_image := TextureRect.new()
		card_image.size = Vector2(100, 140)
		card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var suit_name = suit_to_name(card_data["suit"])
		var rank_name = rank_to_name(card_data["rank"])
		var image_path = "res://assets/cards/%s_%s.png" % [suit_name, rank_name]
		card_image.texture = load(image_path)

		button.add_child(card_image)

		var info_label := Label.new()
		info_label.text = "HP:%d ATK:%d" % [card_data["hp"], card_data["atk"]]
		info_label.position = Vector2(5, 110)
		info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_label.add_theme_font_size_override("font_size", 14)

		button.add_child(info_label)

		button.pressed.connect(_on_hand_card_pressed.bind(i))
		player_hand_container.add_child(button)

func update_enemy_hand_ui():
	for child in enemy_hand_container.get_children():
		child.queue_free()

	for i in range(enemy_hand.size()):
		var card_data = enemy_hand[i]

		var button := Button.new()
		button.custom_minimum_size = Vector2(100, 140)
		button.text = ""

		var card_image := TextureRect.new()
		card_image.size = Vector2(100, 140)
		card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var suit_name = suit_to_name(card_data["suit"])
		var rank_name = rank_to_name(card_data["rank"])
		var image_path = "res://assets/cards/%s_%s.png" % [suit_name, rank_name]
		card_image.texture = load(image_path)

		button.add_child(card_image)
		enemy_hand_container.add_child(button)
		
		button.pressed.connect(_on_enemy_hand_card_pressed.bind(i))

func _on_hand_card_pressed(hand_index: int):
	selected_hand_index = hand_index
	selected_hand_owner = "player"
	print("Selected player hand card: ", player_hand[hand_index]["rank"], player_hand[hand_index]["suit"])
	
func _on_enemy_hand_card_pressed(hand_index: int):
	selected_hand_index = hand_index
	selected_hand_owner = "enemy"
	print("Selected enemy hand card: ", enemy_hand[hand_index]["rank"], enemy_hand[hand_index]["suit"])

func suit_to_name(suit: String) -> String:
	match suit:
		"♣":
			return "Clubs"
		"♦":
			return "Diamonds"
		"♥":
			return "Hearts"
		"♠":
			return "Spades"
		_:
			return "Unknown"


func rank_to_name(rank: String) -> String:
	if rank == "A":
		return "ACE"
	return rank
