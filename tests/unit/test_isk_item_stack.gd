extends GutTest
## ISKItemStack: merge/stack rules and dict round trip.

var _potion: ISKItemDefinition
var _sword: ISKItemDefinition
var _db: ISKItemDatabase


func before_each() -> void:
	_potion = ISKItemDefinition.new()
	_potion.id = &"potion"
	_potion.max_stack = 10
	_sword = ISKItemDefinition.new()
	_sword.id = &"sword"
	_db = ISKItemDatabase.new()
	_db.items = [_potion, _sword]


func test_new_stack_copies_data() -> void:
	var state := {"durability": 5}
	var stack := ISKItemStack.new(_sword, 1, state)
	state["durability"] = 0
	assert_eq(stack.data["durability"], 5)


func test_capacity() -> void:
	var stack := ISKItemStack.new(_potion, 7)
	assert_eq(stack.get_max_stack(), 10)
	assert_eq(stack.space_left(), 3)
	assert_false(stack.is_full())
	stack.count = 10
	assert_true(stack.is_full())
	assert_true(ISKItemStack.new().is_empty())


func test_can_merge_same_item_equal_data() -> void:
	var a := ISKItemStack.new(_potion, 1, {"q": 1})
	var b := ISKItemStack.new(_potion, 4, {"q": 1})
	assert_true(a.can_merge(b))


func test_can_merge_same_id_other_instance() -> void:
	var twin := ISKItemDefinition.new()
	twin.id = &"potion"
	twin.max_stack = 10
	assert_true(ISKItemStack.new(_potion).can_merge(ISKItemStack.new(twin)))


func test_cannot_merge_different_item_data_or_null() -> void:
	var a := ISKItemStack.new(_potion, 1)
	assert_false(a.can_merge(ISKItemStack.new(_sword, 1)))
	assert_false(a.can_merge(ISKItemStack.new(_potion, 1, {"q": 2})))
	assert_false(a.can_merge(null))
	assert_false(a.can_merge(ISKItemStack.new()))


func test_can_merge_compares_numbers_by_value() -> void:
	var a := ISKItemStack.new(_potion, 1, {"q": 1, "list": [2, {"x": 3}]})
	var b := ISKItemStack.new(_potion, 1, {"q": 1.0, "list": [2.0, {"x": 3.0}]})
	assert_true(a.can_merge(b))
	assert_false(a.can_merge(ISKItemStack.new(_potion, 1, {"q": 1.5, "list": [2, {"x": 3}]})))
	assert_false(a.can_merge(ISKItemStack.new(_potion, 1, {"q": "1", "list": [2, {"x": 3}]})))
	assert_false(a.can_merge(ISKItemStack.new(_potion, 1, {"q": 1, "list": [2]})))


func test_merge_moves_all_when_space() -> void:
	var a := ISKItemStack.new(_potion, 3)
	var b := ISKItemStack.new(_potion, 4)
	assert_eq(a.merge_from(b), 0)
	assert_eq(a.count, 7)
	assert_eq(b.count, 0)
	assert_true(b.is_empty())


func test_merge_respects_max_stack_and_returns_remainder() -> void:
	var a := ISKItemStack.new(_potion, 8)
	var b := ISKItemStack.new(_potion, 5)
	assert_eq(a.merge_from(b), 3)
	assert_eq(a.count, 10)
	assert_eq(b.count, 3)


func test_merge_into_full_stack_moves_nothing() -> void:
	var a := ISKItemStack.new(_potion, 10)
	var b := ISKItemStack.new(_potion, 2)
	assert_eq(a.merge_from(b), 2)
	assert_eq(a.count, 10)


func test_unstackable_items_do_not_merge() -> void:
	var a := ISKItemStack.new(_sword, 1)
	var b := ISKItemStack.new(_sword, 1)
	assert_true(a.can_merge(b))
	assert_eq(a.merge_from(b), 1)
	assert_eq(a.count, 1)


func test_merge_incompatible_returns_full_count() -> void:
	var a := ISKItemStack.new(_potion, 1)
	var b := ISKItemStack.new(_potion, 4, {"q": 2})
	assert_eq(a.merge_from(b), 4)
	assert_eq(a.count, 1)
	assert_eq(a.merge_from(null), 0)


func test_duplicate_stack_is_independent() -> void:
	var a := ISKItemStack.new(_sword, 1, {"durability": {"cur": 5}})
	var b := a.duplicate_stack()
	(b.data["durability"] as Dictionary)["cur"] = 1
	assert_same(b.item, a.item)
	assert_eq((a.data["durability"] as Dictionary)["cur"], 5)


func test_validate() -> void:
	assert_eq(ISKItemStack.new(_potion, 10).validate().size(), 0)
	assert_false(ISKItemStack.new(_potion, 0).validate().is_empty())
	assert_false(ISKItemStack.new(_potion, 11).validate().is_empty())
	assert_false(ISKItemStack.new(null, 1).validate().is_empty())


func test_to_dict_format() -> void:
	var d := ISKItemStack.new(_potion, 3, {"q": 1}).to_dict()
	assert_eq(d, {"id": "potion", "n": 3, "d": {"q": 1}})


func test_dict_round_trip_through_json() -> void:
	var stack := ISKItemStack.new(_sword, 1, {"durability": 42, "gems": ["red"]})
	var parsed: Variant = JSON.parse_string(JSON.stringify(stack.to_dict()))
	var copy := ISKItemStack.from_dict(parsed, _db)
	assert_not_null(copy)
	assert_same(copy.item, _sword)
	assert_eq(copy.count, 1)
	assert_eq(typeof(copy.count), TYPE_INT)
	assert_true(copy.can_merge(stack))


func test_from_dict_defaults() -> void:
	var copy := ISKItemStack.from_dict({"id": "potion"}, _db)
	assert_not_null(copy)
	assert_eq(copy.count, 1)
	assert_eq(copy.data, {})


func test_from_dict_rejects_invalid_input() -> void:
	var bad: Array[Dictionary] = [
		{},
		{"id": 3, "n": 1},
		{"id": "unknown", "n": 1},
		{"id": "potion", "n": 0},
		{"id": "potion", "n": -1},
		{"id": "potion", "n": 11},
		{"id": "potion", "n": 1.5},
		{"id": "potion", "n": "2"},
		{"id": "potion", "n": 1, "d": []},
	]
	for d: Dictionary in bad:
		assert_null(ISKItemStack.from_dict(d, _db), "should reject %s" % d)
	assert_null(ISKItemStack.from_dict({"id": "potion", "n": 1}, null))
