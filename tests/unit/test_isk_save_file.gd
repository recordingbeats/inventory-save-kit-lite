extends GutTest
## ISKSaveFile: envelope, atomic write with backup, slot names, JSON helpers.

var _dir: String = ""


func before_each() -> void:
	_dir = "user://isk_test_save_file_%d" % Time.get_ticks_usec()


func after_each() -> void:
	if not DirAccess.dir_exists_absolute(_dir):
		return
	for f: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	DirAccess.remove_absolute(_dir)


func _make(value: int) -> ISKSaveFile:
	var file := ISKSaveFile.new()
	file.slot = "slot_1"
	file.format_version = 2
	file.game_version = "1.0.0"
	file.saved_at = ISKSaveFile.utc_now()
	file.meta = {"location": "Forest"}
	file.data = {"value": value}
	return file


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_write_read_round_trip() -> void:
	var path := ISKSaveFile.slot_path(_dir, "slot_1")
	assert_eq(_make(7).write(path), OK)
	var loaded := ISKSaveFile.new()
	assert_eq(loaded.read(path), OK)
	assert_eq(loaded.slot, "slot_1")
	assert_eq(loaded.format_version, 2)
	assert_eq(loaded.game_version, "1.0.0")
	assert_eq(loaded.meta["location"], "Forest")
	assert_eq(int(loaded.data["value"]), 7)
	assert_false(FileAccess.file_exists(path + ISKSaveFile.TEMP_SUFFIX))


func test_second_write_keeps_previous_as_backup() -> void:
	var path := ISKSaveFile.slot_path(_dir, "slot_1")
	_make(1).write(path)
	_make(2).write(path)
	var backup := ISKSaveFile.new()
	assert_eq(backup.read(path + ISKSaveFile.BACKUP_SUFFIX), OK)
	assert_eq(int(backup.data["value"]), 1)


func test_corrupt_main_file_falls_back_to_backup() -> void:
	var path := ISKSaveFile.slot_path(_dir, "slot_1")
	_make(1).write(path)
	_make(2).write(path)
	_write_text(path, "{ not json")
	var loaded := ISKSaveFile.new()
	assert_eq(loaded.read(path), ERR_FILE_CORRUPT)
	assert_eq(loaded.read_with_backup(path), OK)
	assert_true(loaded.used_backup)
	assert_eq(int(loaded.data["value"]), 1)


func test_corrupt_main_file_does_not_replace_backup_on_next_write() -> void:
	var path := ISKSaveFile.slot_path(_dir, "slot_1")
	_make(1).write(path)
	_make(2).write(path)
	_write_text(path, "garbage")
	_make(3).write(path)
	var backup := ISKSaveFile.new()
	assert_eq(backup.read(path + ISKSaveFile.BACKUP_SUFFIX), OK)
	assert_eq(int(backup.data["value"]), 1)


func test_rejects_json_that_is_not_an_envelope() -> void:
	var file := ISKSaveFile.new()
	var bad: Array = [
		[1, 2],
		{"format": "other", "format_version": 1, "data": {}},
		{"format": "isk-save", "format_version": 1.5, "data": {}},
		{"format": "isk-save", "format_version": -1, "data": {}},
		{"format": "isk-save", "format_version": "1", "data": {}},
		{"format": "isk-save", "format_version": 1, "data": []},
		{"format": "isk-save", "format_version": 1, "data": {}, "meta": "x"},
	]
	for envelope: Variant in bad:
		assert_eq(file.from_dict(envelope), ERR_FILE_CORRUPT, str(envelope))
	assert_eq(file.from_dict({"format": "isk-save", "format_version": 1, "data": {}}), OK)


func test_missing_file_is_not_found() -> void:
	var file := ISKSaveFile.new()
	assert_eq(file.read_with_backup(ISKSaveFile.slot_path(_dir, "none")), ERR_FILE_NOT_FOUND)
	assert_false(file.used_backup)


func test_slot_names() -> void:
	for good: String in ["slot_1", "autosave", "a", "a-b_c-9", "x".repeat(32)]:
		assert_true(ISKSaveFile.is_valid_slot_name(good), good)
	for bad: String in ["", "../evil", "Slot", "a/b", "a.b", "a b", "x".repeat(33), "ä"]:
		assert_false(ISKSaveFile.is_valid_slot_name(bad), bad)


func test_json_helpers_round_trip() -> void:
	var json := JSON.new()
	var payload := {
		"v2": ISKSaveFile.vec2_to_json(Vector2(1.5, -2.0)),
		"v2i": ISKSaveFile.vec2i_to_json(Vector2i(3, 4)),
		"v3": ISKSaveFile.vec3_to_json(Vector3(1, 2, 3)),
		"c": ISKSaveFile.color_to_json(Color(0.5, 0.25, 1.0, 0.75)),
	}
	assert_eq(json.parse(JSON.stringify(payload)), OK)
	var d: Dictionary = json.data
	assert_eq(ISKSaveFile.json_to_vec2(d["v2"]), Vector2(1.5, -2.0))
	assert_eq(ISKSaveFile.json_to_vec2i(d["v2i"]), Vector2i(3, 4))
	assert_eq(ISKSaveFile.json_to_vec3(d["v3"]), Vector3(1, 2, 3))
	assert_eq(ISKSaveFile.json_to_color(d["c"]), Color(0.5, 0.25, 1.0, 0.75))


func test_json_helpers_use_fallback_for_bad_input() -> void:
	assert_eq(ISKSaveFile.json_to_vec2("x", Vector2.ONE), Vector2.ONE)
	assert_eq(ISKSaveFile.json_to_vec2([1], Vector2.ONE), Vector2.ONE)
	assert_eq(ISKSaveFile.json_to_vec3([1, "a", 2]), Vector3.ZERO)
	assert_eq(ISKSaveFile.json_to_color(null), Color.WHITE)
