extends "res://tests/unit/isk_inventory_fixture.gd"
## ISKInventory: set_slot, move, slot_count and signals (exactly once per operation).

# --- set_slot / move ----------------------------------------------------------


func test_set_slot_stores_a_copy() -> void:
	var stack := ISKItemStack.new(_potion, 4)
	assert_true(_inv.set_slot(1, stack))
	stack.count = 9
	assert_eq(_inv.get_slot(1).count, 4)


func test_set_slot_rejects_invalid() -> void:
	assert_false(_inv.set_slot(-1, ISKItemStack.new(_potion)))
	assert_false(_inv.set_slot(4, ISKItemStack.new(_potion)))
	assert_false(_inv.set_slot(0, ISKItemStack.new(_potion, 11)))
	assert_eq(_counts(), [0, 0, 0, 0])
	var inv := PickyInventory.new()
	inv.slot_count = 2
	assert_false(inv.set_slot(0, ISKItemStack.new(_potion)))
	assert_true(inv.set_slot(0, ISKItemStack.new(_sword)))


func test_set_slot_null_or_empty_clears() -> void:
	_inv.add_item(_potion, 3)
	assert_true(_inv.set_slot(0, null))
	assert_null(_inv.get_slot(0))
	_inv.add_item(_potion, 3)
	assert_true(_inv.set_slot(0, ISKItemStack.new(_potion, 0)))
	assert_null(_inv.get_slot(0))


func test_move_into_empty_slot() -> void:
	_inv.add_item(_potion, 3)
	assert_true(_inv.move(0, 3))
	assert_eq(_counts(), [0, 0, 0, 3])


func test_move_merges_and_keeps_remainder() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	_inv.set_slot(1, ISKItemStack.new(_potion, 7))
	assert_true(_inv.move(0, 1))
	assert_eq(_counts(), [3, 10, 0, 0])
	assert_true(_inv.move(0, 2))
	assert_true(_inv.move(2, 0))
	_inv.set_slot(1, ISKItemStack.new(_potion, 2))
	assert_true(_inv.move(0, 1))
	assert_eq(_counts(), [0, 5, 0, 0])


func test_move_swaps_different_stacks() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	_inv.set_slot(1, ISKItemStack.new(_sword))
	assert_true(_inv.move(0, 1))
	assert_eq(_inv.get_slot(0).item, _sword)
	assert_eq(_inv.get_slot(1).item, _potion)
	assert_eq(_inv.get_slot(1).count, 6)


func test_move_invalid_or_blocked() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 10))
	_inv.set_slot(1, ISKItemStack.new(_potion, 10))
	assert_false(_inv.move(0, 0))
	assert_false(_inv.move(2, 0))
	assert_false(_inv.move(0, 4))
	assert_false(_inv.move(-1, 0))
	assert_false(_inv.move(0, 1), "merge into a full stack moves nothing")
	var inv := PickyInventory.new()
	inv.slot_count = 2
	inv.set_slot(1, ISKItemStack.new(_potion))
	assert_false(inv.move(1, 0))


func test_shrinking_slot_count_drops_tail() -> void:
	_inv.add_item(_sword, 4)
	_inv.slot_count = 2
	assert_eq(_inv.count_of(_sword), 2)
	_inv.slot_count = 3
	assert_null(_inv.get_slot(2))
	_inv.slot_count = -1
	assert_eq(_inv.slot_count, 0)


# --- signals: exactly once per operation -------------------------------------


func test_add_signals_once() -> void:
	_inv.set_slot(1, ISKItemStack.new(_potion, 8))
	watch_signals(_inv)
	assert_eq(_inv.add_item(_potion, 15), 0)
	assert_signal_emit_count(_inv, "changed", 1)
	assert_signal_emit_count(_inv, "item_added", 1)
	assert_signal_emitted_with_parameters(_inv, "item_added", [_potion, 15])
	assert_signal_emit_count(_inv, "slot_changed", 3)
	assert_signal_not_emitted(_inv, "item_removed")


func test_add_partial_signals_added_amount() -> void:
	_inv.slot_count = 1
	watch_signals(_inv)
	assert_eq(_inv.add_item(_potion, 14), 4)
	assert_signal_emitted_with_parameters(_inv, "item_added", [_potion, 10])
	assert_signal_emitted_with_parameters(_inv, "slot_changed", [0])
	assert_signal_emit_count(_inv, "changed", 1)


func test_no_signals_when_nothing_changes() -> void:
	_inv.add_item(_potion, 40)
	watch_signals(_inv)
	_inv.add_item(_potion, 1)
	_inv.remove_item(_gem, 1)
	_inv.move(0, 1)
	_inv.move(3, 3)
	_inv.set_slot(9, ISKItemStack.new(_potion))
	_inv.clear()
	_inv.clear()
	assert_signal_emit_count(_inv, "changed", 1, "only the first clear changes something")
	assert_signal_emit_count(_inv, "item_removed", 1)
	assert_signal_not_emitted(_inv, "item_added")


func test_remove_signals_once() -> void:
	_inv.add_item(_potion, 25)
	watch_signals(_inv)
	assert_eq(_inv.remove_item(&"potion", 12), 12)
	assert_signal_emit_count(_inv, "changed", 1)
	assert_signal_emit_count(_inv, "item_removed", 1)
	assert_signal_emitted_with_parameters(_inv, "item_removed", [_potion, 12])
	assert_signal_emit_count(_inv, "slot_changed", 2)


func test_set_slot_signals() -> void:
	watch_signals(_inv)
	_inv.set_slot(0, ISKItemStack.new(_potion, 3))
	assert_signal_emitted_with_parameters(_inv, "item_added", [_potion, 3])
	_inv.set_slot(0, ISKItemStack.new(_potion, 1))
	assert_signal_emitted_with_parameters(_inv, "item_removed", [_potion, 2])
	_inv.set_slot(0, ISKItemStack.new(_sword))
	assert_signal_emitted_with_parameters(_inv, "item_removed", [_potion, 1])
	assert_signal_emitted_with_parameters(_inv, "item_added", [_sword, 1])
	assert_signal_emit_count(_inv, "changed", 3)
	assert_signal_emit_count(_inv, "slot_changed", 3)
	assert_signal_emit_count(_inv, "item_added", 2)
	assert_signal_emit_count(_inv, "item_removed", 2)


func test_move_signals_without_add_remove() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	_inv.set_slot(1, ISKItemStack.new(_sword))
	watch_signals(_inv)
	_inv.move(0, 1)
	assert_signal_emit_count(_inv, "changed", 1)
	assert_signal_emit_count(_inv, "slot_changed", 2)
	assert_signal_not_emitted(_inv, "item_added")
	assert_signal_not_emitted(_inv, "item_removed")


func test_clear_signals_once_per_item_type() -> void:
	_inv.add_item(_potion, 15)
	_inv.add_item(_sword, 2)
	watch_signals(_inv)
	_inv.clear()
	assert_signal_emit_count(_inv, "changed", 1)
	assert_signal_emit_count(_inv, "slot_changed", 4)
	assert_signal_emit_count(_inv, "item_removed", 2)
	assert_signal_emitted_with_parameters(_inv, "item_removed", [_sword, 2])
