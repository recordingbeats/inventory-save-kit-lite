extends PanelContainer
## UI test scene without the demo game: two bags with drag & drop between them.
## Loaded by the smoke test; also handy for trying the grid by hand.

const ICONS := "res://demo/art/items/%s.png"

@onready var _bag: ISKInventoryGrid = %Bag
@onready var _chest: ISKInventoryGrid = %Chest


func _ready() -> void:
	var potion := make_item(&"health_potion", 10, 0.5, [])
	var sword := make_item(&"short_sword", 1, 3.0, [&"weapon"])
	var coin := make_item(&"gold_coin", 99, 0.0, [])
	var bag := ISKInventory.new()
	bag.slot_count = 12
	bag.add_item(potion, 7)
	bag.add_item(sword)
	bag.add_item(coin, 42)
	var chest := ISKInventory.new()
	chest.slot_count = 8
	chest.max_weight = 5.0
	chest.add_item(potion, 4)
	_bag.inventory = bag
	_chest.inventory = chest


## Creates an item with a demo icon (file name = [param id]).
static func make_item(
	id: StringName, max_stack: int, weight: float, tags: Array[StringName]
) -> ISKItemDefinition:
	var item := ISKItemDefinition.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.icon = load(ICONS % id) as Texture2D
	item.max_stack = max_stack
	item.weight = weight
	item.tags = tags
	return item
