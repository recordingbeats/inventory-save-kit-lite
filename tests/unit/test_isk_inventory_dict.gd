extends "res://tests/unit/isk_inventory_fixture.gd"
## ISKInventory: to_dict/from_dict, JSON round trip and untrusted input.

# --- serialization ------------------------------------------------------------


func test_to_dict_format() -> void:
	_inv.set_slot(2, ISKItemStack.new(_potion, 3, {"q": 1}))
	assert_eq(_inv.to_dict(), {"slots": [{"i": 2, "id": "potion", "n": 3, "d": {"q": 1}}]})


func test_json_round_trip() -> void:
	_inv.add_item(_potion, 13)
	_inv.add_item(_sword, 1, {"durability": 7})
	_inv.move(2, 3)
	var text := JSON.stringify(_inv.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	var copy := QuietInventory.new()
	copy.slot_count = 4
	copy.from_dict(parsed, _db)
	assert_eq(copy.warnings.size(), 0)
	for i: int in 4:
		var a := _inv.get_slot(i)
		var b := copy.get_slot(i)
		assert_eq(b == null, a == null, "slot %d occupancy" % i)
		if a != null and b != null:
			assert_eq(b.count, a.count, "slot %d count" % i)
			assert_true(b.can_merge(a), "slot %d item and data" % i)
	# JSON turns data numbers into floats; a second trip must be stable.
	var text2 := JSON.stringify(copy.to_dict())
	var copy2 := QuietInventory.new()
	copy2.slot_count = 4
	copy2.from_dict(JSON.parse_string(text2), _db)
	assert_eq(JSON.stringify(copy2.to_dict()), text2)
	assert_eq(copy.get_slot(3).item, _sword)
	assert_true(copy.get_slot(3).can_merge(ISKItemStack.new(_sword, 1, {"durability": 7})))


func test_from_dict_replaces_content_and_signals() -> void:
	_inv.add_item(_gem, 5)
	_inv.add_item(_sword)
	watch_signals(_inv)
	_inv.from_dict(
		{"slots": [{"i": 0, "id": "gem", "n": 5, "d": {}}, {"i": 3, "id": "potion"}]}, _db
	)
	assert_eq(_counts(), [5, 0, 0, 1])
	assert_signal_emit_count(_inv, "changed", 1)
	assert_signal_emit_count(_inv, "slot_changed", 2, "slot 0 unchanged, 1 cleared, 3 filled")
	assert_signal_not_emitted(_inv, "item_added")
	assert_signal_not_emitted(_inv, "item_removed")


func test_from_dict_drops_invalid_entries_with_warning() -> void:
	var entries: Array = [
		{"i": 0, "id": "potion", "n": 2},
		"junk",
		{"i": 1, "id": "dragon", "n": 1},
		{"i": 7, "id": "potion"},
		{"i": -1, "id": "potion"},
		{"i": 1.5, "id": "potion"},
		{"id": "potion"},
		{"i": 0, "id": "gem"},
		{"i": 2, "id": "potion", "n": 11},
		{"i": 2, "id": "potion", "n": "3"},
		{"i": 2, "id": 5},
		{"i": 2, "id": "sword", "d": []},
		{"i": 3.0, "id": "sword", "n": 1.0},
	]
	_inv.from_dict({"slots": entries}, _db)
	assert_eq(_counts(), [2, 0, 0, 1])
	assert_eq(_inv.warnings.size(), 11)
	assert_true(_inv.warnings[1].contains("dragon"), "unknown id is named")


func test_from_dict_respects_can_accept() -> void:
	var inv := PickyInventory.new()
	inv.slot_count = 2
	inv.from_dict({"slots": [{"i": 0, "id": "potion"}, {"i": 1, "id": "potion"}]}, _db)
	assert_null(inv.get_slot(0))
	assert_eq(inv.get_slot(1).count, 1)
	assert_eq(inv.warnings.size(), 1)


func test_from_dict_malformed_root_empties_inventory() -> void:
	for bad: Dictionary in [{}, {"slots": "x"}, {"slots": {"0": {}}}]:
		_inv.add_item(_potion, 3)
		_inv.from_dict(bad, _db)
		assert_eq(_counts(), [0, 0, 0, 0])
	_inv.add_item(_potion, 3)
	_inv.from_dict({"slots": []}, null)
	assert_eq(_counts(), [0, 0, 0, 0])
	assert_eq(_inv.warnings.size(), 4)
