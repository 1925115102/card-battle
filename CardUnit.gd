extends Button

signal unit_clicked(unit)

var grid_pos: Vector2i
var suit: String = "♠"
var rank: String = "A"
var hp: int = 6
var atk: int = 2
var move_range: int = 1
var unit_owner: String = "player"
var has_acted: bool = false

@onready var card_image: TextureRect = get_node("CardImage")
@onready var hp_label = $HPLabel
@onready var atk_label = $ATKLabel
@onready var outline = $Outline

func setup(new_grid_pos: Vector2i, new_suit: String, new_rank: String, new_hp: int, new_atk: int, new_owner: String):
	text = ""
	grid_pos = new_grid_pos
	suit = new_suit
	rank = new_rank
	hp = new_hp
	atk = new_atk
	unit_owner = new_owner
	size = Vector2(120, 120)
	
	if unit_owner == "player":
		outline.color = Color(0.2, 0.5, 1.0)
	else:
		outline.color = Color(1.0, 0.2, 0.2)

	var image_path = "res://assets/cards/%s_%s.png" % [suit_to_name(suit), rank_to_name(rank)]
	card_image.texture = load(image_path)

	hp_label.text = str(hp)
	atk_label.text = str(atk)
	
	apply_suit_bonus()
	update_display()

func _ready():
	hp_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
	atk_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	
	hp_label.add_theme_font_size_override("font_size", 36)
	atk_label.add_theme_font_size_override("font_size", 36)

	pressed.connect(_on_pressed)

func _on_pressed():
	print("Clicked unit: ", rank, suit, " at ", grid_pos)
	unit_clicked.emit(self)

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

func apply_suit_bonus():
	match suit:
		"♠":
			atk += 1

		"♥":
			hp += 2

		"♦":
			hp += 1

		"♣":
			move_range += 1

func update_display():
	hp_label.text = str(hp)
	atk_label.text = str(atk)

func update_outline(selected := false, attackable := false):

	if has_acted:
		outline.color = Color(0.4, 0.4, 0.4)
		return

	if selected:
		outline.color = Color(1.0, 1.0, 0.2)
		return

	if attackable:
		outline.color = Color(1.0, 0.4, 0.4)
		return

	if unit_owner == "player":
		outline.color = Color(0.2, 0.5, 1.0)
	else:
		outline.color = Color(1.0, 0.2, 0.2)
