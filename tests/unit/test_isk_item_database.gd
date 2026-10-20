extends GutTest
## ISKItemDatabase: lookup, duplicate detection, dict round trip.


func _def(id: StringName, max_stack: int = 1) -> ISKItemDefinition:
	var def := ISKItemDefinition.new()
	def.id = id
	def.max_stack = max_stack
	return def


func _db(defs: Array[ISKItemDefinition]) -> ISKItemDatabase:
	var db := ISKItemDatabase.new()
	db.items = defs
	return db


func test_lookup_by_id() -> void:
	var sword := _def(&"sword")
	var potion := _def(&"potion", 10)
	var db := _db([sword, potion])
	assert_same(db.get_item(&"sword"), sword)
	assert_same(db.get_item(&"potion"), potion)
	assert_true(db.has_item(&"potion"))


func test_unknown_id_returns_null() -> void:
	var db := _db([_def(&"sword")])
	assert_null(db.get_item(&"axe"))
	assert_false(db.has_item(&"axe"))
	assert_null(ISKItemDatabase.new().get_item(&"sword"))


func test_lookup_after_in_place_append() -> void:
	var db := _db([_def(&"sword")])
	assert_null(db.get_item(&"shield"))
	var shield := _def(&"shield")
	db.items.append(shield)
	assert_same(db.get_item(&"shield"), shield)


func test_lookup_after_in_place_removal() -> void:
	var db := _db([_def(&"sword"), _def(&"shield")])
	assert_not_null(db.get_item(&"shield"))
	db.items.remove_at(1)
	assert_null(db.get_item(&"shield"))


func test_lookup_after_id_change() -> void:
	var def := _def(&"old")
	var db := _db([def])
	assert_same(db.get_item(&"old"), def)
	def.id = &"new"
	db.rebuild_index()
	assert_same(db.get_item(&"new"), def)
	assert_null(db.get_item(&"old"))


func test_valid_database_has_no_errors() -> void:
	assert_eq(_db([_def(&"a"), _def(&"b")]).validate().size(), 0)


func test_duplicate_ids_are_reported_and_first_wins() -> void:
	var first := _def(&"potion")
	var db := _db([first, _def(&"sword"), _def(&"potion")])
	var errors := db.validate()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "duplicate item id 'potion'")
	assert_same(db.get_item(&"potion"), first)


func test_empty_ids_and_null_entries_are_reported() -> void:
	var db := _db([_def(&""), null, _def(&"")])
	var errors := db.validate()
	# two empty ids (not reported as duplicates) + one null entry
	assert_eq(errors.size(), 3)


func test_invalid_item_is_reported() -> void:
	var errors := _db([_def(&"a", 0)]).validate()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "items[0]")


func test_dict_round_trip() -> void:
	var db := _db([_def(&"sword"), _def(&"potion", 10)])
	var parsed: Variant = JSON.parse_string(JSON.stringify(db.to_dict()))
	var copy := ISKItemDatabase.from_dict(parsed)
	assert_not_null(copy)
	assert_eq(copy.items.size(), 2)
	assert_eq(copy.get_item(&"potion").max_stack, 10)
	assert_eq(copy.validate().size(), 0)


func test_from_dict_rejects_invalid_input() -> void:
	var bad: Array[Dictionary] = [
		{},
		{"items": "sword"},
		{"items": [1]},
		{"items": [{"id": ""}]},
		{"items": [{"id": "a"}, {"id": "a"}]},
	]
	for d: Dictionary in bad:
		assert_null(ISKItemDatabase.from_dict(d), "should reject %s" % d)
