extends GutTest
## Sanity checks every product keeps: plugin config and demo scene load.


func test_plugin_cfg_exists() -> void:
	assert_true(FileAccess.file_exists("res://addons/inventory_save_kit/plugin.cfg"))


func test_main_scene_loads() -> void:
	# full: demo/main.tscn, lite: demo/lite/main_lite.tscn (package.sh rewrites it)
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_string_starts_with(path, "res://demo/")
	var packed: PackedScene = load(path)
	assert_not_null(packed)


func test_save_autoload_is_registered() -> void:
	var node := get_tree().root.get_node_or_null("ISKSave")
	assert_true(node is ISKSaveManager)
