extends GutTest
## ISKSaveManager: single-slot save/load, signals, backup fallback, version check.


## Records warnings instead of printing them (the test log must stay warning-free).
class QuietManager:
	extends ISKSaveManager
	var warnings: PackedStringArray = []

	func _warn(message: String) -> void:
		warnings.append(message)


var _manager: QuietManager


func before_each() -> void:
	_manager = QuietManager.new()
	_manager.save_dir = "user://isk_test_save_manager_%d" % Time.get_ticks_usec()
	add_child_autofree(_manager)
	watch_signals(_manager)


func after_each() -> void:
	var dir := _manager.save_dir
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func test_round_trip() -> void:
	_manager.data = {"gold": 42, "name": "Hero", "pos": ISKSaveFile.vec2_to_json(Vector2(3, 4))}
	assert_eq(_manager.save_game("slot_1", {"playtime": 12}), OK)
	_manager.data = {}
	assert_eq(_manager.load_game("slot_1"), OK)
	assert_eq(int(_manager.data["gold"]), 42)
	assert_eq(_manager.data["name"], "Hero")
	assert_eq(ISKSaveFile.json_to_vec2(_manager.data["pos"]), Vector2(3, 4))
	assert_eq(int(_manager.meta["playtime"]), 12)
	assert_true(_manager.has_slot("slot_1"))
	assert_eq(_manager.warnings.size(), 0)


func test_signals() -> void:
	_manager.save_game("slot_1")
	_manager.load_game("slot_1")
	assert_signal_emitted_with_parameters(_manager, "save_started", ["slot_1"])
	assert_signal_emitted_with_parameters(_manager, "save_finished", ["slot_1", OK])
	assert_signal_emitted_with_parameters(_manager, "load_finished", ["slot_1", OK])


func test_save_started_handler_can_fill_data() -> void:
	_manager.save_started.connect(func(_slot: String) -> void: _manager.data = {"filled": true})
	_manager.save_game("slot_1")
	_manager.data = {}
	_manager.load_game("slot_1")
	assert_eq(_manager.data.get("filled"), true)


func test_corrupt_file_loads_backup() -> void:
	_manager.data = {"value": 1}
	_manager.save_game("slot_1")
	_manager.data = {"value": 2}
	_manager.save_game("slot_1")
	var f := FileAccess.open(_manager.get_slot_path("slot_1"), FileAccess.WRITE)
	f.store_string('{"format": "isk-save", truncated')
	f.close()
	_manager.data = {}
	assert_eq(_manager.load_game("slot_1"), ERR_FILE_CORRUPT)
	assert_eq(int(_manager.data["value"]), 1)
	assert_signal_emitted_with_parameters(_manager, "load_finished", ["slot_1", ERR_FILE_CORRUPT])
	assert_eq(_manager.warnings.size(), 1)


func test_invalid_slot_name_is_refused() -> void:
	assert_eq(_manager.save_game("../escape"), ERR_INVALID_PARAMETER)
	assert_eq(_manager.load_game("../escape"), ERR_INVALID_PARAMETER)
	assert_signal_not_emitted(_manager, "save_started")
	assert_signal_emitted_with_parameters(
		_manager, "save_finished", ["../escape", ERR_INVALID_PARAMETER]
	)
	assert_false(_manager.has_slot("../escape"))
	assert_false(FileAccess.file_exists("user://escape.json"))


func test_newer_format_version_is_refused() -> void:
	_manager.current_format_version = 3
	_manager.data = {"value": 1}
	_manager.save_game("slot_1")
	_manager.current_format_version = 2
	_manager.data = {"value": 9}
	assert_eq(_manager.load_game("slot_1"), ERR_FILE_UNRECOGNIZED)
	assert_eq(int(_manager.data["value"]), 9)
	assert_signal_emitted_with_parameters(
		_manager, "load_finished", ["slot_1", ERR_FILE_UNRECOGNIZED]
	)


func test_missing_slot_is_not_found() -> void:
	assert_eq(_manager.load_game("empty"), ERR_FILE_NOT_FOUND)
	assert_false(_manager.has_slot("empty"))
	assert_eq(_manager.warnings.size(), 0)


func test_game_version_and_header_are_written() -> void:
	_manager.game_version = "1.2.0"
	_manager.current_format_version = 4
	_manager.save_game("slot_1", {"location": "Forest"})
	var file := ISKSaveFile.new()
	assert_eq(file.read(_manager.get_slot_path("slot_1")), OK)
	assert_eq(file.game_version, "1.2.0")
	assert_eq(file.format_version, 4)
	assert_eq(file.slot, "slot_1")
	assert_true(file.saved_at.ends_with("Z"))
	assert_eq(file.meta["location"], "Forest")
