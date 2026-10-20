extends "res://tests/unit/isk_inventory_fixture.gd"
## ISKInventory P2b: weight limit, split and transfer (base class, Lite too).

var _bag: QuietInventory


func before_each() -> void:
	super()
	_bag = QuietInventory.new()
	_bag.slot_count = 3


# --- weight ------------------------------------------------------------------


func test_weight_limit_returns_remainder() -> void:
	_inv.max_weight = 2.0
	assert_eq(_inv.add_item(_potion, 6), 2, "4 × 0.5 fit, 2 are left")
	assert_eq(_inv.count_of(_potion), 4)
	assert_almost_eq(_inv.total_weight(), 2.0, 0.0001)
	assert_eq(_inv.add_item(_potion, 1), 1, "full by weight")
	assert_eq(_inv.add_item(_gem, 5), 0, "weightless items ignore the limit")


func test_weight_limit_tolerates_float_sums() -> void:
	var feather := _make_item(&"feather", 99, 0.1)
	_inv.max_weight = 0.3
	assert_eq(_inv.add_item(feather, 3), 0)


func test_weight_limit_signals_only_added_amount() -> void:
	_inv.max_weight = 3.0
	watch_signals(_inv)
	assert_eq(_inv.add_item(_sword, 2), 1)
	assert_signal_emitted_with_parameters(_inv, "item_added", [_sword, 1])
	assert_signal_emit_count(_inv, "changed", 1)
	assert_eq(_inv.add_item(_sword, 1), 1)
	assert_signal_emit_count(_inv, "changed", 1, "refused add emits nothing")


func test_weight_limit_set_slot() -> void:
	_inv.max_weight = 4.0
	assert_true(_inv.set_slot(0, ISKItemStack.new(_sword)))
	assert_false(_inv.set_slot(1, ISKItemStack.new(_sword)), "3 + 3 > 4")
	assert_true(_inv.set_slot(0, ISKItemStack.new(_potion, 8)), "replacing frees weight")
	_inv.max_weight = 1.0
	assert_true(_inv.set_slot(0, ISKItemStack.new(_potion, 4)), "lighter is allowed")
	assert_true(_inv.move(0, 3), "moves never change the weight")


func test_max_weight_not_negative() -> void:
	_inv.max_weight = -1.0
	assert_eq(_inv.max_weight, 0.0)


# --- split -------------------------------------------------------------------


func test_split_into_first_empty_slot() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 7, {"q": 1}))
	_inv.set_slot(1, ISKItemStack.new(_sword))
	assert_true(_inv.split(0, 3))
	assert_eq(_counts(), [4, 1, 3, 0])
	assert_eq(_inv.get_slot(2).data, {"q": 1})


func test_split_invalid_amount() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 5))
	assert_false(_inv.split(0, 0))
	assert_false(_inv.split(0, -2))
	assert_false(_inv.split(0, 5), "whole stack is a move, not a split")
	assert_false(_inv.split(0, 6))
	assert_false(_inv.split(1, 1), "empty slot")
	assert_false(_inv.split(9, 1), "out of range")
	assert_eq(_counts(), [5, 0, 0, 0])


func test_split_without_free_slot() -> void:
	_inv.add_item(_potion, 35)
	assert_false(_inv.split(3, 2))
	assert_eq(_counts(), [10, 10, 10, 5])


func test_split_signals_once() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	watch_signals(_inv)
	_inv.split(0, 3)
	assert_signal_emit_count(_inv, "changed", 1)
	assert_signal_emit_count(_inv, "slot_changed", 2)
	assert_signal_not_emitted(_inv, "item_added")
	assert_signal_not_emitted(_inv, "item_removed")


# --- transfer ----------------------------------------------------------------


func test_transfer_auto_slot_merges_first() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	_bag.set_slot(2, ISKItemStack.new(_potion, 8))
	assert_eq(_inv.transfer(0, _bag), 6)
	assert_null(_inv.get_slot(0))
	assert_eq(_bag.get_slot(2).count, 10)
	assert_eq(_bag.get_slot(0).count, 4)


func test_transfer_to_full_target() -> void:
	_bag.add_item(_potion, 30)
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	assert_eq(_inv.transfer(0, _bag), 0)
	assert_eq(_inv.transfer(0, _bag, 1), 0)
	assert_eq(_inv.get_slot(0).count, 6)
	assert_eq(_bag.count_of(_potion), 30)


func test_transfer_partial_keeps_rest() -> void:
	_bag.set_slot(1, ISKItemStack.new(_potion, 7))
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	assert_eq(_inv.transfer(0, _bag, 1), 3)
	assert_eq(_inv.get_slot(0).count, 3)
	assert_eq(_bag.get_slot(1).count, 10)


func test_transfer_respects_target_weight() -> void:
	_bag.max_weight = 1.0
	_inv.set_slot(0, ISKItemStack.new(_potion, 5))
	assert_eq(_inv.transfer(0, _bag, 0), 2)
	assert_eq(_inv.get_slot(0).count, 3)
	_inv.set_slot(1, ISKItemStack.new(_sword))
	assert_eq(_inv.transfer(1, _bag), 0)


func test_transfer_swaps_different_stacks() -> void:
	_inv.set_slot(0, ISKItemStack.new(_sword))
	_bag.set_slot(1, ISKItemStack.new(_potion, 4))
	assert_eq(_inv.transfer(0, _bag, 1), 1)
	assert_eq(_inv.get_slot(0).item, _potion)
	assert_eq(_bag.get_slot(1).item, _sword)


func test_transfer_swap_refused_by_weight() -> void:
	_bag.max_weight = 2.0
	_bag.set_slot(0, ISKItemStack.new(_potion, 2))
	_inv.set_slot(0, ISKItemStack.new(_sword))
	assert_eq(_inv.transfer(0, _bag, 0), 0)
	assert_eq(_inv.get_slot(0).item, _sword)


func test_transfer_invalid() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 2))
	assert_eq(_inv.transfer(1, _bag), 0, "empty source")
	assert_eq(_inv.transfer(0, null), 0)
	assert_eq(_inv.transfer(0, _inv, 1), 0, "same inventory: use move")
	assert_eq(_inv.transfer(0, _bag, 7), 0, "target index out of range")
	assert_eq(_inv.get_slot(0).count, 2)


func test_transfer_signals_once_per_inventory() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	watch_signals(_inv)
	watch_signals(_bag)
	_inv.transfer(0, _bag, 2)
	assert_signal_emit_count(_inv, "changed", 1)
	assert_signal_emit_count(_inv, "slot_changed", 1)
	assert_signal_emitted_with_parameters(_inv, "item_removed", [_potion, 6])
	assert_signal_emit_count(_bag, "changed", 1)
	assert_signal_emit_count(_bag, "slot_changed", 1)
	assert_signal_emitted_with_parameters(_bag, "item_added", [_potion, 6])


func test_transfer_swap_signals_once_per_inventory() -> void:
	_inv.set_slot(0, ISKItemStack.new(_sword))
	_bag.set_slot(0, ISKItemStack.new(_potion, 4))
	watch_signals(_inv)
	watch_signals(_bag)
	_inv.transfer(0, _bag, 0)
	for inv: ISKInventory in [_inv, _bag]:
		assert_signal_emit_count(inv, "changed", 1)
		assert_signal_emit_count(inv, "slot_changed", 1)
		assert_signal_emit_count(inv, "item_added", 1)
		assert_signal_emit_count(inv, "item_removed", 1)
