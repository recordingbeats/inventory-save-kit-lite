extends "res://tests/unit/isk_inventory_fixture.gd"
## ISKInventory: fill order, remainder, stack overflow, remove/count/has, clear.

# --- slots and fill order ---------------------------------------------------


func test_new_inventory_is_empty() -> void:
	var inv := ISKInventory.new()
	assert_eq(inv.slot_count, 20)
	for i: int in inv.slot_count:
		assert_null(inv.get_slot(i))
	assert_null(inv.get_slot(-1))
	assert_null(inv.get_slot(20))
	assert_false(inv.is_full())
	assert_eq(inv.count_of(&"potion"), 0)


func test_add_fills_empty_slots_in_order() -> void:
	assert_eq(_inv.add_item(_potion, 25), 0)
	assert_eq(_counts(), [10, 10, 5, 0])
	assert_eq(_inv.count_of(_potion), 25)


func test_add_fills_existing_stacks_first() -> void:
	_inv.set_slot(2, ISKItemStack.new(_potion, 7))
	assert_eq(_inv.add_item(_potion, 5), 0)
	assert_eq(_counts(), [2, 0, 10, 0])


func test_add_skips_stacks_with_other_data() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 1, {"q": 1}))
	_inv.add_item(_potion, 2, {"q": 2})
	assert_eq(_counts(), [1, 2, 0, 0])
	assert_eq(_inv.get_slot(1).data, {"q": 2})


func test_unstackable_items_take_one_slot_each() -> void:
	assert_eq(_inv.add_item(_sword, 3), 0)
	assert_eq(_counts(), [1, 1, 1, 0])


func test_add_returns_remainder_when_full() -> void:
	assert_eq(_inv.add_item(_potion, 45), 5)
	assert_eq(_counts(), [10, 10, 10, 10])
	assert_true(_inv.is_full())
	assert_eq(_inv.add_item(_potion, 3), 3)
	assert_eq(_inv.add_item(_sword), 1)


func test_stack_overflow_spills_into_next_free_slot() -> void:
	_inv.set_slot(1, ISKItemStack.new(_potion, 9))
	_inv.set_slot(0, ISKItemStack.new(_gem, 1))
	assert_eq(_inv.add_item(_potion, 4), 0)
	assert_eq(_counts(), [1, 10, 3, 0])


func test_add_no_room_for_new_stack_returns_all() -> void:
	for i: int in 4:
		_inv.set_slot(i, ISKItemStack.new(_gem, 1))
	assert_false(_inv.is_full())
	assert_eq(_inv.add_item(_potion, 2), 2)
	assert_eq(_inv.add_item(_gem, 2), 0)
	assert_eq(_inv.count_of(_gem), 6)


func test_add_invalid_arguments() -> void:
	assert_eq(_inv.add_item(null, 3), 3)
	assert_eq(_inv.add_item(_potion, 0), 0)
	assert_eq(_inv.add_item(_potion, -2), 0)
	assert_eq(_counts(), [0, 0, 0, 0])


func test_add_respects_can_accept() -> void:
	var inv := PickyInventory.new()
	inv.slot_count = 3
	inv.add_item(_potion, 15)
	assert_null(inv.get_slot(0))
	assert_eq(inv.get_slot(1).count, 10)
	inv.add_item(_sword)
	assert_eq(inv.get_slot(0).item, _sword)


func test_add_copies_data() -> void:
	var state := {"durability": 5}
	_inv.add_item(_sword, 1, state)
	state["durability"] = 0
	assert_eq(_inv.get_slot(0).data["durability"], 5)


# --- remove / count / has ---------------------------------------------------


func test_remove_takes_from_last_slot_first() -> void:
	_inv.add_item(_potion, 25)
	assert_eq(_inv.remove_item(_potion, 7), 7)
	assert_eq(_counts(), [10, 8, 0, 0])


func test_remove_by_id_and_partial() -> void:
	_inv.add_item(_potion, 3)
	assert_eq(_inv.remove_item(&"potion", 5), 3)
	assert_eq(_counts(), [0, 0, 0, 0])
	assert_eq(_inv.remove_item("potion"), 0)
	assert_eq(_inv.remove_item(null), 0)
	assert_eq(_inv.remove_item(42), 0)


func test_count_and_has_item() -> void:
	_inv.add_item(_potion, 12)
	_inv.add_item(_sword)
	assert_eq(_inv.count_of(&"potion"), 12)
	assert_eq(_inv.count_of("sword"), 1)
	assert_eq(_inv.count_of(_gem), 0)
	assert_true(_inv.has_item(_potion, 12))
	assert_false(_inv.has_item(_potion, 13))
	assert_true(_inv.has_item(&"sword"))
	assert_false(_inv.has_item(&"gem"))
	assert_true(_inv.has_item(&"gem", 0))


func test_total_weight() -> void:
	_inv.add_item(_potion, 4)
	_inv.add_item(_sword)
	assert_almost_eq(_inv.total_weight(), 5.0, 0.0001)


func test_clear() -> void:
	_inv.add_item(_potion, 15)
	_inv.add_item(_sword)
	_inv.clear()
	assert_eq(_counts(), [0, 0, 0, 0])
	assert_eq(_inv.total_weight(), 0.0)
