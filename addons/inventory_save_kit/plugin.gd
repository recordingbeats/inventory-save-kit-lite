@tool
extends EditorPlugin
## Editor entry point of Inventory & Save Kit: registers the [code]ISKSave[/code] autoload.

## Name of the save autoload.
const AUTOLOAD_NAME := "ISKSave"
## Script of the save autoload (lite edition).
const AUTOLOAD_PATH := "res://addons/inventory_save_kit/save/isk_save_manager.gd"
## Script of the save autoload in the full edition; used when it is present.
const AUTOLOAD_PATH_FULL := "res://addons/inventory_save_kit/save/isk_save_manager_full.gd"


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, get_autoload_path())


## Returns the script used for the save autoload: the full manager if the
## edition ships it, else the lite one.
static func get_autoload_path() -> String:
	if FileAccess.file_exists(AUTOLOAD_PATH_FULL):
		return AUTOLOAD_PATH_FULL
	return AUTOLOAD_PATH


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
