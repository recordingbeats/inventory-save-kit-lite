extends GutTest
## Demo save indicator (P9b, lite + full): messages for save, autosave, load
## and errors, driven by the ISKSave signals.

const SCENE := preload("res://demo/ui/save_indicator.tscn")
const Indicator := preload("res://demo/ui/save_indicator.gd")

var _ui: Control


func before_each() -> void:
	_ui = SCENE.instantiate() as Control
	add_child_autofree(_ui)


func test_hidden_until_first_message() -> void:
	assert_false(_ui.call(&"is_showing"))


func test_save_texts() -> void:
	assert_eq(Indicator.save_text("slot_1", OK, "autosave"), "Game saved")
	assert_eq(Indicator.save_text("autosave", OK, "autosave"), "Autosaved")
	assert_string_starts_with(Indicator.save_text("slot_1", ERR_CANT_CREATE, "a"), "Save failed")


func test_load_texts() -> void:
	assert_eq(Indicator.load_text(OK), "Game loaded")
	assert_string_contains(Indicator.load_text(ERR_FILE_CORRUPT), "backup")
	assert_string_starts_with(Indicator.load_text(ERR_FILE_NOT_FOUND), "Load failed")


func test_reacts_to_save_signals() -> void:
	ISKSave.save_started.emit("slot_1")
	assert_eq(_ui.call(&"get_message"), "Saving…")
	assert_true(_ui.call(&"is_showing"))
	ISKSave.save_finished.emit("slot_1", OK)
	assert_eq(_ui.call(&"get_message"), "Game saved")
	ISKSave.load_finished.emit("slot_1", ERR_FILE_NOT_FOUND)
	assert_eq((_ui.get_node(^"%Toast") as Control).theme_type_variation, &"DemoToastError")


func test_message_fades_out() -> void:
	_ui.set(&"hold_seconds", 0.05)
	_ui.set(&"fade_seconds", 0.05)
	_ui.call(&"show_message", "Game saved")
	await wait_seconds(0.3)
	assert_false(_ui.call(&"is_showing"))
