extends GutTest
## ISKItemDefinition: validation and dict round trip.


func _make() -> ISKItemDefinition:
	var def := ISKItemDefinition.new()
	def.id = &"potion"
	def.display_name = "Potion"
	def.description = "Heals.\nTastes bad."
	def.max_stack = 20
	def.weight = 0.5
	def.tags = [&"consumable", &"red"]
	def.properties = {"heal": 25, "nested": {"a": [1, 2]}}
	return def


func test_valid_definition_has_no_errors() -> void:
	assert_eq(_make().validate().size(), 0)


func test_empty_id_is_invalid() -> void:
	var def := _make()
	def.id = &""
	assert_eq(def.validate().size(), 1)
	def.id = &"  "
	assert_eq(def.validate().size(), 1)


func test_max_stack_out_of_range_is_invalid() -> void:
	var def := _make()
	def.max_stack = 0
	assert_false(def.validate().is_empty())
	def.max_stack = ISKItemDefinition.MAX_STACK + 1
	assert_false(def.validate().is_empty())


func test_negative_weight_is_invalid() -> void:
	var def := _make()
	def.weight = -1.0
	assert_false(def.validate().is_empty())


func test_is_stackable_and_has_tag() -> void:
	var def := _make()
	assert_true(def.is_stackable())
	assert_true(def.has_tag(&"red"))
	assert_false(def.has_tag(&"weapon"))
	def.max_stack = 1
	assert_false(def.is_stackable())


func test_dict_round_trip() -> void:
	var def := _make()
	var copy := ISKItemDefinition.from_dict(def.to_dict())
	assert_not_null(copy)
	assert_eq(copy.id, def.id)
	assert_eq(copy.display_name, def.display_name)
	assert_eq(copy.description, def.description)
	assert_eq(copy.max_stack, def.max_stack)
	assert_eq(copy.weight, def.weight)
	assert_eq(copy.tags, def.tags)
	assert_eq(copy.properties, def.properties)


func test_round_trip_through_json() -> void:
	var def := _make()
	var parsed: Variant = JSON.parse_string(JSON.stringify(def.to_dict()))
	var copy := ISKItemDefinition.from_dict(parsed)
	assert_not_null(copy)
	assert_eq(copy.max_stack, 20)
	assert_eq(copy.tags, def.tags)


func test_to_dict_does_not_share_properties() -> void:
	var def := _make()
	var d := def.to_dict()
	(d["properties"] as Dictionary)["heal"] = 0
	assert_eq(def.properties["heal"], 25)


func test_from_dict_defaults_for_optional_keys() -> void:
	var def := ISKItemDefinition.from_dict({"id": "stone"})
	assert_not_null(def)
	assert_eq(def.max_stack, 1)
	assert_eq(def.tags.size(), 0)


func test_from_dict_rejects_invalid_input() -> void:
	var bad: Array[Dictionary] = [
		{},
		{"id": 5},
		{"id": ""},
		{"id": "a", "max_stack": 0},
		{"id": "a", "max_stack": 2.5},
		{"id": "a", "max_stack": "3"},
		{"id": "a", "max_stack": 100000},
		{"id": "a", "weight": "heavy"},
		{"id": "a", "weight": -2},
		{"id": "a", "tags": "weapon"},
		{"id": "a", "tags": [1]},
		{"id": "a", "properties": []},
		{"id": "a", "display_name": 3},
	]
	for d: Dictionary in bad:
		assert_null(ISKItemDefinition.from_dict(d), "should reject %s" % d)
