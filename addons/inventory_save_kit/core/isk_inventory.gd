class_name ISKInventory
extends Resource
## A fixed number of slots, each empty or holding one [ISKItemStack].
##
## [method add_item] fills matching stacks first, then empty slots in slot order.
## Every public operation that changes the inventory emits [signal changed] once,
## [signal slot_changed] once per touched slot and [signal item_added] /
## [signal item_removed] at most once per item type. Pure moves between slots
## ([method move]) and [method from_dict] emit no add/remove signals.
## Slot contents returned by [method get_slot] belong to the inventory: read
## them, but change slots only through the methods of this class.
##
## With [member max_weight] above 0, adding items stops at the weight limit;
## refused or partial operations return [code]false[/code] or a remainder.
## Subclasses restrict slots through [method can_accept] and
## [method _slot_capacity] (equipment slots in the full edition do that).

## Emitted once for every slot whose content changed during an operation.
signal slot_changed(index: int)
## Emitted when [param amount] × [param item] entered the inventory.
signal item_added(item: ISKItemDefinition, amount: int)
## Emitted when [param amount] × [param item] left the inventory.
signal item_removed(item: ISKItemDefinition, amount: int)

## Tolerance for float sums such as 0.1 × 3 when checking [member max_weight].
const WEIGHT_EPSILON := 0.0001

## Number of slots. Shrinking drops the stacks in the removed slots silently:
## only [signal changed] is emitted (no [signal slot_changed] or
## [signal item_removed]), so listeners resync the whole inventory on
## [signal changed]. Meant for setup, not for gameplay.
@export_range(0, 1000, 1, "or_greater") var slot_count: int = 20:
	set(value):
		value = maxi(value, 0)
		if value == slot_count and _slots.size() == value:
			return
		slot_count = value
		_slots.resize(value)
		emit_changed()

## Weight limit for [method total_weight]; 0 = no limit. Lowering it below the
## current weight removes nothing, it only refuses further weight.
@export_range(0.0, 10000.0, 0.01, "or_greater") var max_weight: float = 0.0:
	set(value):
		max_weight = maxf(value, 0.0)

var _slots: Array[ISKItemStack] = []


func _init() -> void:
	_slots.resize(slot_count)


## Adds [param amount] × [param item] with per-instance [param data].
## Fills existing stacks that can merge first, then empty slots, both in slot
## order, and stops at [member max_weight]. Returns the remainder that did not
## fit (0 = everything was added).
func add_item(item: ISKItemDefinition, amount: int = 1, data: Dictionary = {}) -> int:
	if item == null or amount <= 0:
		return maxi(amount, 0)
	var incoming := ISKItemStack.new(item, mini(amount, _weight_room_for(item)), data)
	var allowed: int = incoming.count
	var touched: Array[int] = []
	for i: int in _slots.size():
		if incoming.count == 0:
			break
		var stack: ISKItemStack = _slots[i]
		if stack == null or not stack.can_merge(incoming) or _space_in(i, stack) == 0:
			continue
		if not can_accept(i, stack):
			continue
		var moved: int = mini(_space_in(i, stack), incoming.count)
		stack.count += moved
		incoming.count -= moved
		touched.append(i)
	for i: int in _slots.size():
		if incoming.count == 0:
			break
		if _slots[i] != null or _slot_capacity(i, item) < 1:
			continue
		var part := ISKItemStack.new(item, mini(incoming.count, _slot_capacity(i, item)), data)
		if not can_accept(i, part):
			continue
		_slots[i] = part
		incoming.count -= part.count
		touched.append(i)
	var added: int = allowed - incoming.count
	if added > 0:
		_emit_slots(touched)
		item_added.emit(item, added)
		emit_changed()
	return amount - added


## Removes up to [param amount] items matching [param item_or_id] (an
## [ISKItemDefinition], [StringName] or [String] ID), taking from the last
## matching slot first. Returns how many were removed.
func remove_item(item_or_id: Variant, amount: int = 1) -> int:
	var id: Variant = _id_of(item_or_id)
	if id == null or amount <= 0:
		return 0
	var left: int = amount
	var touched: Array[int] = []
	var removed_item: ISKItemDefinition = null
	for i: int in range(_slots.size() - 1, -1, -1):
		if left == 0:
			break
		var stack: ISKItemStack = _slots[i]
		if stack == null or stack.item.id != id:
			continue
		removed_item = stack.item
		var taken: int = mini(stack.count, left)
		stack.count -= taken
		left -= taken
		if stack.count <= 0:
			_slots[i] = null
		touched.append(i)
	var removed: int = amount - left
	if removed > 0:
		_emit_slots(touched)
		item_removed.emit(removed_item, removed)
		emit_changed()
	return removed


## Returns the stack in slot [param index], or [code]null[/code] if the slot is
## empty or out of range.
func get_slot(index: int) -> ISKItemStack:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


## Puts a copy of [param stack] into slot [param index], replacing its content;
## [code]null[/code] or an empty stack clears the slot. Returns
## [code]false[/code] (and changes nothing) if the index is out of range, the
## stack is invalid, [method can_accept] refuses it or it would raise the
## weight above [member max_weight].
func set_slot(index: int, stack: ISKItemStack) -> bool:
	if index < 0 or index >= _slots.size():
		return false
	var new_stack: ISKItemStack = null
	if stack != null and not stack.is_empty():
		if not stack.validate().is_empty() or not can_accept(index, stack):
			return false
		if stack.count > _slot_capacity(index, stack.item):
			return false
		new_stack = stack.duplicate_stack()
	var old_stack: ISKItemStack = _slots[index]
	if not _fits_weight(_weight_of(new_stack) - _weight_of(old_stack)):
		return false
	if old_stack == null and new_stack == null:
		return true
	_slots[index] = new_stack
	slot_changed.emit(index)
	if old_stack != null and new_stack != null and old_stack.item.id == new_stack.item.id:
		var delta: int = new_stack.count - old_stack.count
		if delta > 0:
			item_added.emit(new_stack.item, delta)
		elif delta < 0:
			item_removed.emit(old_stack.item, -delta)
	else:
		if old_stack != null:
			item_removed.emit(old_stack.item, old_stack.count)
		if new_stack != null:
			item_added.emit(new_stack.item, new_stack.count)
	emit_changed()
	return true


## Moves the stack in slot [param from] to slot [param to]: into an empty slot,
## merged into a matching stack (the remainder stays in [param from]) or
## swapped with a different stack. Returns [code]true[/code] if anything moved.
func move(from: int, to: int) -> bool:
	if from == to or get_slot(from) == null or to < 0 or to >= _slots.size():
		return false
	var source: ISKItemStack = _slots[from]
	var target: ISKItemStack = _slots[to]
	if target == null:
		if not _can_hold(to, source):
			return false
		_slots[to] = source
		_slots[from] = null
	elif target.can_merge(source):
		if _space_in(to, target) == 0 or not can_accept(to, target):
			return false
		var moved: int = mini(_space_in(to, target), source.count)
		target.count += moved
		source.count -= moved
		if source.count <= 0:
			_slots[from] = null
	else:
		if not _can_hold(to, source) or not _can_hold(from, target):
			return false
		_slots[to] = source
		_slots[from] = target
	_emit_slots([from, to])
	emit_changed()
	return true


## Moves [param amount] items from the stack in slot [param index] into the
## first empty slot that accepts them (same [member ISKItemStack.data]).
## Returns [code]false[/code] (nothing changed) if the slot is empty,
## [param amount] is not in 1..count − 1 or no empty slot accepts the part.
## Emits [signal slot_changed] for both slots and [signal changed], no
## add/remove signals.
func split(index: int, amount: int) -> bool:
	var stack: ISKItemStack = get_slot(index)
	if stack == null or amount < 1 or amount >= stack.count:
		return false
	var part := ISKItemStack.new(stack.item, amount, stack.data)
	for i: int in _slots.size():
		if _slots[i] != null or not _can_hold(i, part):
			continue
		stack.count -= amount
		_slots[i] = part
		_emit_slots([index, i])
		emit_changed()
		return true
	return false


## Moves the stack in slot [param from_index] into [param target], a different
## inventory, and returns how many items moved (0 = refused, nothing changed).
## [br]- [param to_index] = -1: like [method add_item] on the target (merge
## first, then empty slots); the rest stays in [param from_index].
## [br]- [param to_index] ≥ 0, empty or matching stack: as many as fit there
## (slot capacity, [method can_accept], weight); the rest stays.
## [br]- [param to_index] ≥ 0 with a different stack: both stacks swap if each
## side accepts the other completely, else nothing happens.
## [br]Both inventories emit their own signals, [signal changed] once each.
## Use [method move] inside one inventory; [param target] == self returns 0.
func transfer(from_index: int, target: ISKInventory, to_index: int = -1) -> int:
	var source: ISKItemStack = get_slot(from_index)
	if source == null or target == null or target == self:
		return 0
	var moved: int = 0
	if to_index < 0:
		moved = source.count - target.add_item(source.item, source.count, source.data)
	else:
		var current: ISKItemStack = target.get_slot(to_index)
		if current != null and not current.can_merge(source):
			return _swap_with(from_index, target, to_index)
		moved = target._receive(to_index, source)
	if moved > 0:
		_take(from_index, moved)
	return moved


## Returns how many items [method move] with the same arguments would move
## (0 = refused; a swap counts the whole source stack). Changes nothing; UI drop
## checks use it.
func move_preview(from: int, to: int) -> int:
	if from == to or get_slot(from) == null or to < 0 or to >= _slots.size():
		return 0
	var source: ISKItemStack = _slots[from]
	var target: ISKItemStack = _slots[to]
	if target == null:
		return source.count if _can_hold(to, source) else 0
	if target.can_merge(source):
		return mini(_space_in(to, target), source.count) if can_accept(to, target) else 0
	return source.count if _can_hold(to, source) and _can_hold(from, target) else 0


## Returns how many items [method transfer] with the same arguments would move
## (0 = refused). Changes nothing; UI drop checks use it.
func transfer_preview(from_index: int, target: ISKInventory, to_index: int = -1) -> int:
	var source: ISKItemStack = get_slot(from_index)
	if source == null or target == null or target == self:
		return 0
	if to_index < 0:
		return target._add_preview(source)
	var current: ISKItemStack = target.get_slot(to_index)
	if current != null and not current.can_merge(source):
		return source.count if _can_swap_with(from_index, target, to_index) else 0
	return target._receive_preview(to_index, source)


## Returns how many items matching [param item_or_id] the inventory holds.
func count_of(item_or_id: Variant) -> int:
	var id: Variant = _id_of(item_or_id)
	if id == null:
		return 0
	var total: int = 0
	for stack: ISKItemStack in _slots:
		if stack != null and stack.item.id == id:
			total += stack.count
	return total


## Returns [code]true[/code] if at least [param amount] items matching
## [param item_or_id] are in the inventory.
func has_item(item_or_id: Variant, amount: int = 1) -> bool:
	return count_of(item_or_id) >= amount


## Sum of [member ISKItemDefinition.weight] × count over all slots.
func total_weight() -> float:
	var total: float = 0.0
	for stack: ISKItemStack in _slots:
		if stack != null:
			total += stack.item.weight * stack.count
	return total


## Returns [code]true[/code] if every slot holds a full stack, so
## [method add_item] cannot add anything (the weight limit is not checked here).
func is_full() -> bool:
	for i: int in _slots.size():
		var stack: ISKItemStack = _slots[i]
		if stack == null or _space_in(i, stack) > 0:
			return false
	return true


## Empties all slots.
func clear() -> void:
	var touched: Array[int] = []
	var removed: Dictionary = {}
	var items: Dictionary = {}
	for i: int in _slots.size():
		var stack: ISKItemStack = _slots[i]
		if stack == null:
			continue
		touched.append(i)
		removed[stack.item.id] = int(removed.get(stack.item.id, 0)) + stack.count
		if not items.has(stack.item.id):
			items[stack.item.id] = stack.item
		_slots[i] = null
	if touched.is_empty():
		return
	_emit_slots(touched)
	for id: StringName in removed:
		item_removed.emit(items[id], removed[id])
	emit_changed()


## Virtual: returns [code]true[/code] if slot [param index] may hold
## [param stack]. The base inventory accepts any stack in range; equipment
## overrides this to check item tags.
func can_accept(index: int, stack: ISKItemStack) -> bool:
	return index >= 0 and index < _slots.size() and stack != null


## Virtual: how many [param item] slot [param index] holds at most. Default:
## [member ISKItemDefinition.max_stack]; equipment returns 1.
func _slot_capacity(_index: int, item: ISKItemDefinition) -> int:
	return item.max_stack


## Returns the save representation [code]{"slots": [{"i", "id", "n", "d"}]}[/code]
## (empty slots are left out).
func to_dict() -> Dictionary:
	var out: Array[Dictionary] = []
	for i: int in _slots.size():
		var stack: ISKItemStack = _slots[i]
		if stack == null:
			continue
		var entry := stack.to_dict()
		entry["i"] = i
		out.append(entry)
	return {"slots": out}


## Replaces the content with [method to_dict] output, resolving IDs through
## [param db]. [param d] is untrusted input: malformed entries, unknown IDs,
## out-of-range or duplicate indices and refused stacks are dropped with a
## warning ([method _warn]); the rest is loaded. Without a usable
## [code]slots[/code] array the inventory ends up empty.
## Emits [signal slot_changed] for changed slots and [signal changed], but no
## add/remove signals.
func from_dict(d: Dictionary, db: ISKItemDatabase) -> void:
	var loaded: Array[ISKItemStack] = []
	loaded.resize(_slots.size())
	var raw: Variant = d.get("slots")
	if not raw is Array:
		_warn("ISKInventory: 'slots' is missing or not an array")
	elif db == null:
		_warn("ISKInventory: no item database, inventory not loaded")
	else:
		for entry: Variant in raw:
			_load_entry(entry, db, loaded)
	var touched: Array[int] = []
	for i: int in _slots.size():
		if not _same_content(_slots[i], loaded[i]):
			touched.append(i)
	_slots = loaded
	if touched.is_empty():
		return
	_emit_slots(touched)
	emit_changed()


## Virtual: reports a problem found while loading. Default:
## [method @GlobalScope.push_warning].
func _warn(message: String) -> void:
	push_warning(message)


func _load_entry(entry: Variant, db: ISKItemDatabase, loaded: Array[ISKItemStack]) -> void:
	if not entry is Dictionary:
		_warn("ISKInventory: slot entry is not a dictionary, dropped")
		return
	var index: Variant = _to_int(entry.get("i"))
	if index == null or index < 0 or index >= loaded.size():
		_warn("ISKInventory: slot index %s out of range, dropped" % str(entry.get("i")))
		return
	if loaded[index] != null:
		_warn("ISKInventory: duplicate slot index %d, dropped" % index)
		return
	var stack := ISKItemStack.from_dict(entry, db)
	if stack == null:
		var raw_id: Variant = entry.get("id")
		if (raw_id is String or raw_id is StringName) and not db.has_item(StringName(raw_id)):
			_warn("ISKInventory: unknown item id '%s' in slot %d, dropped" % [raw_id, index])
		else:
			_warn("ISKInventory: invalid stack in slot %d, dropped" % index)
		return
	if not _can_hold(index, stack):
		_warn("ISKInventory: slot %d refuses item '%s', dropped" % [index, stack.item.id])
		return
	loaded[index] = stack


## Puts up to [param stack].count items into slot [param index] (empty or
## holding a matching stack) and returns how many went in; [param stack] itself
## is not changed. Called by [method transfer] on the target inventory.
func _receive(index: int, stack: ISKItemStack) -> int:
	if index < 0 or index >= _slots.size():
		return 0
	var n: int = _receive_preview(index, stack)
	if n < 1:
		return 0
	var current: ISKItemStack = _slots[index]
	if current == null:
		_slots[index] = ISKItemStack.new(stack.item, n, stack.data)
	else:
		current.count += n
	slot_changed.emit(index)
	item_added.emit(stack.item, n)
	emit_changed()
	return n


## How many of [param stack] [method _receive] would put into slot
## [param index]; changes nothing.
func _receive_preview(index: int, stack: ISKItemStack) -> int:
	if index < 0 or index >= _slots.size():
		return 0
	var current: ISKItemStack = _slots[index]
	var room: int = 0
	if current == null:
		room = _slot_capacity(index, stack.item)
	elif current.can_merge(stack) and can_accept(index, current):
		room = _space_in(index, current)
	var n: int = mini(mini(stack.count, room), _weight_room_for(stack.item))
	if n < 1:
		return 0
	if current == null and not can_accept(index, ISKItemStack.new(stack.item, n, stack.data)):
		return 0
	return n


## How many of [param stack] [method add_item] would add; changes nothing.
func _add_preview(stack: ISKItemStack) -> int:
	var left: int = mini(stack.count, _weight_room_for(stack.item))
	var allowed: int = left
	for i: int in _slots.size():
		var current: ISKItemStack = _slots[i]
		if left == 0:
			break
		if current == null or not current.can_merge(stack) or not can_accept(i, current):
			continue
		left -= mini(_space_in(i, current), left)
	for i: int in _slots.size():
		if left == 0:
			break
		if _slots[i] != null or _slot_capacity(i, stack.item) < 1:
			continue
		var part := ISKItemStack.new(
			stack.item, mini(left, _slot_capacity(i, stack.item)), stack.data
		)
		if can_accept(i, part):
			left -= part.count
	return allowed - left


## Removes [param amount] items from slot [param index] with signals.
func _take(index: int, amount: int) -> void:
	var stack: ISKItemStack = _slots[index]
	stack.count -= amount
	if stack.count <= 0:
		_slots[index] = null
	slot_changed.emit(index)
	item_removed.emit(stack.item, amount)
	emit_changed()


## Swaps slot [param from_index] with [param target] slot [param to_index] if
## both sides accept the other stack completely. Returns the moved count.
func _swap_with(from_index: int, target: ISKInventory, to_index: int) -> int:
	if not _can_swap_with(from_index, target, to_index):
		return 0
	var mine: ISKItemStack = _slots[from_index]
	var theirs: ISKItemStack = target.get_slot(to_index)
	_slots[from_index] = theirs
	target._slots[to_index] = mine
	slot_changed.emit(from_index)
	item_removed.emit(mine.item, mine.count)
	item_added.emit(theirs.item, theirs.count)
	emit_changed()
	target.slot_changed.emit(to_index)
	target.item_removed.emit(theirs.item, theirs.count)
	target.item_added.emit(mine.item, mine.count)
	target.emit_changed()
	return mine.count


func _can_swap_with(from_index: int, target: ISKInventory, to_index: int) -> bool:
	var mine: ISKItemStack = _slots[from_index]
	var theirs: ISKItemStack = target.get_slot(to_index)
	if not target._can_hold(to_index, mine) or not _can_hold(from_index, theirs):
		return false
	var delta: float = _weight_of(mine) - _weight_of(theirs)
	return target._fits_weight(delta) and _fits_weight(-delta)


## Returns [code]true[/code] if slot [param index] accepts the whole
## [param stack] (capacity and [method can_accept]).
func _can_hold(index: int, stack: ISKItemStack) -> bool:
	return can_accept(index, stack) and stack.count <= _slot_capacity(index, stack.item)


func _space_in(index: int, stack: ISKItemStack) -> int:
	return maxi(_slot_capacity(index, stack.item) - stack.count, 0)


## How many more [param item] fit under [member max_weight].
func _weight_room_for(item: ISKItemDefinition) -> int:
	if max_weight <= 0.0 or item.weight <= 0.0:
		return 1 << 62
	var room: float = max_weight - total_weight() + WEIGHT_EPSILON
	return maxi(floori(room / item.weight), 0)


## Returns [code]true[/code] if changing the weight by [param delta] is allowed:
## no limit, not heavier, or still within [member max_weight].
func _fits_weight(delta: float) -> bool:
	if max_weight <= 0.0 or delta <= 0.0:
		return true
	return total_weight() + delta <= max_weight + WEIGHT_EPSILON


static func _weight_of(stack: ISKItemStack) -> float:
	return 0.0 if stack == null else stack.item.weight * stack.count


func _emit_slots(indices: Array) -> void:
	var seen: Dictionary = {}
	for i: int in indices:
		if not seen.has(i):
			seen[i] = true
			slot_changed.emit(i)


static func _same_content(a: ISKItemStack, b: ISKItemStack) -> bool:
	if a == null or b == null:
		return a == b
	return a.item == b.item and a.count == b.count and a.can_merge(b)


static func _id_of(item_or_id: Variant) -> Variant:
	if item_or_id is ISKItemDefinition:
		return (item_or_id as ISKItemDefinition).id
	if item_or_id is StringName or item_or_id is String:
		return StringName(item_or_id)
	return null


static func _to_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floorf(value):
		return int(value)
	return null
