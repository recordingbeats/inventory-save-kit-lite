class_name ISKItemStack
extends RefCounted
## A number of identical items in one slot, plus per-instance state.
##
## Two stacks merge only if they hold the same item and equal [member data].
## A stack never holds more than [member ISKItemDefinition.max_stack] items.

## The item type; [code]null[/code] makes the stack invalid.
var item: ISKItemDefinition
## Number of items, 1..[code]item.max_stack[/code] for a valid stack.
var count: int = 0
## Per-instance state (durability, ...). Keep it JSON compatible.
var data: Dictionary = {}


## Creates a stack of [param amount] × [param definition] with [param state].
func _init(definition: ISKItemDefinition = null, amount: int = 1, state: Dictionary = {}) -> void:
	item = definition
	count = amount
	data = state.duplicate(true)


## Maximum stack size of [member item], 0 without an item.
func get_max_stack() -> int:
	return item.max_stack if item != null else 0


## How many more items fit into this stack.
func space_left() -> int:
	return maxi(get_max_stack() - count, 0)


## Returns [code]true[/code] if the stack holds no item or a count below 1.
func is_empty() -> bool:
	return item == null or count <= 0


## Returns [code]true[/code] if no further item fits.
func is_full() -> bool:
	return space_left() == 0


## Returns [code]true[/code] if [param other] holds the same item (same
## instance or same ID) with equal [member data]. Numbers compare by value, so
## [code]3[/code] equals [code]3.0[/code] (JSON loads every number as float).
## Capacity is not checked; see [method merge_from].
func can_merge(other: ISKItemStack) -> bool:
	if other == null or item == null or other.item == null:
		return false
	if item != other.item and item.id != other.item.id:
		return false
	return _values_equal(data, other.data)


## Moves as many items from [param other] into this stack as fit.
## Returns the remainder left in [param other] (all of it if they cannot merge).
func merge_from(other: ISKItemStack) -> int:
	if other == null:
		return 0
	if not can_merge(other) or other.count <= 0:
		return maxi(other.count, 0)
	var moved: int = mini(space_left(), other.count)
	count += moved
	other.count -= moved
	return other.count


## Returns a copy (deep copy of [member data], same [member item]).
func duplicate_stack() -> ISKItemStack:
	return ISKItemStack.new(item, count, data)


## Returns a list of problems; empty means the stack is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if item == null:
		errors.append("stack has no item")
		return errors
	for problem: String in item.validate():
		errors.append(problem)
	if count < 1 or count > item.max_stack:
		errors.append("stack of '%s': count %d outside 1..%d" % [item.id, count, item.max_stack])
	return errors


## Returns the save representation [code]{"id", "n", "d"}[/code].
func to_dict() -> Dictionary:
	return {
		"id": String(item.id) if item != null else "",
		"n": count,
		"d": data.duplicate(true),
	}


## Builds a stack from [method to_dict] output, resolving the ID through
## [param db]. Returns [code]null[/code] for unknown IDs, malformed input or a
## count outside 1..max_stack (save files are untrusted input).
static func from_dict(d: Dictionary, db: ISKItemDatabase) -> ISKItemStack:
	if db == null:
		return null
	var raw_id: Variant = d.get("id")
	if not (raw_id is String or raw_id is StringName):
		return null
	var definition := db.get_item(StringName(raw_id))
	if definition == null:
		return null
	var n: Variant = _to_int(d.get("n", 1))
	if n == null:
		return null
	var state: Variant = d.get("d", {})
	if not state is Dictionary:
		return null
	var stack := ISKItemStack.new(definition, n, state)
	if not stack.validate().is_empty():
		return null
	return stack


## Converts an int or an integral float (JSON numbers) to int, else null.
static func _to_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floorf(value):
		return int(value)
	return null


## Deep equality where int and float compare by value.
static func _values_equal(a: Variant, b: Variant) -> bool:
	var a_num: bool = a is int or a is float
	var b_num: bool = b is int or b is float
	if a_num or b_num:
		return a_num and b_num and float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for key: Variant in da:
			if not db.has(key) or not _values_equal(da[key], db[key]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i: int in aa.size():
			if not _values_equal(aa[i], ab[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b
