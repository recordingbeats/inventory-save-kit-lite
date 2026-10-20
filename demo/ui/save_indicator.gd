extends Control
## Demo save/load/autosave indicator: a short toast in the top right corner.
## [br]Listens to the [code]ISKSave[/code] signals by itself, so the demo only has
## to instance the scene (lite and full). Autosaves are recognised by the slot
## name ([code]autosave_slot[/code] of the full manager). Text, not colour, carries
## the state; errors also use the error look.

## Seconds a message stays fully visible before it fades out.
@export var hold_seconds: float = 1.6
## Seconds of the fade-out.
@export var fade_seconds: float = 0.4

var _tween: Tween = null
var _manager: ISKSaveManager = null

@onready var _panel: PanelContainer = %Toast
@onready var _label: Label = %Message


func _ready() -> void:
	_panel.modulate.a = 0.0
	if _manager == null:
		set_save_manager(get_node_or_null(^"/root/ISKSave") as ISKSaveManager)


## Listens to [param manager] instead of the [code]ISKSave[/code] autoload (the
## capture tour uses its own manager).
func set_save_manager(manager: ISKSaveManager) -> void:
	if _manager != null and _manager.save_started.is_connected(_on_save_started):
		_manager.save_started.disconnect(_on_save_started)
		_manager.save_finished.disconnect(_on_save_finished)
		_manager.load_finished.disconnect(_on_load_finished)
	_manager = manager
	if manager == null:
		return
	manager.save_started.connect(_on_save_started)
	manager.save_finished.connect(_on_save_finished)
	manager.load_finished.connect(_on_load_finished)


## Shows [param text] for [member hold_seconds]; [param is_error] switches to the
## error look. "Saving…" style messages pass [param sticky] and stay until the
## next message.
func show_message(text: String, is_error: bool = false, sticky: bool = false) -> void:
	_label.text = text
	_panel.theme_type_variation = &"DemoToastError" if is_error else &"DemoToast"
	_label.theme_type_variation = &"DemoToastErrorLabel" if is_error else &"DemoToastLabel"
	if _tween != null:
		_tween.kill()
	_panel.modulate.a = 1.0
	if sticky:
		return
	_tween = create_tween()
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(_panel, "modulate:a", 0.0, fade_seconds)


## Returns the text shown so far ("" before the first message).
func get_message() -> String:
	return _label.text


## True while a message is visible (also during the fade).
func is_showing() -> bool:
	return _panel.modulate.a > 0.0


## Message for a finished save of [param slot] (pure, used by the tests).
static func save_text(slot: String, err: Error, autosave_slot: String) -> String:
	if err != OK:
		return "Save failed: %s" % error_string(err)
	return "Autosaved" if slot == autosave_slot else "Game saved"


## Message for a finished load (pure). [constant ERR_FILE_CORRUPT] means the
## manager fell back to the backup copy, so the game did load.
static func load_text(err: Error) -> String:
	match err:
		OK:
			return "Game loaded"
		ERR_FILE_CORRUPT:
			return "Save was damaged – loaded the backup"
		_:
			return "Load failed: %s" % error_string(err)


func _on_save_started(slot: String) -> void:
	show_message("Autosaving…" if slot == _autosave_slot() else "Saving…", false, true)


func _on_save_finished(slot: String, err: Error) -> void:
	show_message(save_text(slot, err, _autosave_slot()), err != OK)


func _on_load_finished(_slot: String, err: Error) -> void:
	show_message(load_text(err), err != OK and err != ERR_FILE_CORRUPT)


func _autosave_slot() -> String:
	var value: Variant = _manager.get(&"autosave_slot") if _manager != null else null
	return value if value is String else "autosave"
