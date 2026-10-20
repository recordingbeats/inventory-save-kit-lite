extends GutTest
## Shared fixture for the ISKInventory tests (no test_ prefix: GUT skips it).


## Records warnings instead of printing them (the test log must stay warning-free).
class QuietInventory:
	extends ISKInventory
	var warnings: PackedStringArray = []

	func _warn(message: String) -> void:
		warnings.append(message)


## Accepts only items tagged "weapon" in slot 0 (stand-in for equipment).
class PickyInventory:
	extends QuietInventory

	func can_accept(index: int, stack: ISKItemStack) -> bool:
		if not super.can_accept(index, stack):
			return false
		return index != 0 or stack.item.tags.has(&"weapon")


var _potion: ISKItemDefinition
var _sword: ISKItemDefinition
var _gem: ISKItemDefinition
var _db: ISKItemDatabase
var _inv: QuietInventory


func before_each() -> void:
	_potion = _make_item(&"potion", 10, 0.5)
	_sword = _make_item(&"sword", 1, 3.0)
	_sword.tags = [&"weapon"]
	_gem = _make_item(&"gem", 99, 0.0)
	_db = ISKItemDatabase.new()
	_db.items = [_potion, _sword, _gem]
	_inv = QuietInventory.new()
	_inv.slot_count = 4


func _make_item(id: StringName, max_stack: int, weight: float) -> ISKItemDefinition:
	var item := ISKItemDefinition.new()
	item.id = id
	item.max_stack = max_stack
	item.weight = weight
	return item


func _counts() -> Array:
	var out: Array = []
	for i: int in _inv.slot_count:
		var stack := _inv.get_slot(i)
		out.append(0 if stack == null else stack.count)
	return out
