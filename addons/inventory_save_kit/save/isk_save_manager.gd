class_name ISKSaveManager
extends Node
## Saves and loads game data as JSON slots (autoload [code]ISKSave[/code]).
##
## Put the data to persist into [member data] (for example in a handler of
## [signal save_started]), call [method save_game], and read it back after
## [method load_game]. Files live in [member save_dir] as [code]<slot>.json[/code];
## see [ISKSaveFile] for the envelope and the atomic write.

## Emitted before a slot is written. Handlers may still change [member data].
signal save_started(slot: String)
## Emitted after [method save_game], also on failure.
signal save_finished(slot: String, err: Error)
## Emitted after [method load_game], also on failure. [constant ERR_FILE_CORRUPT]
## means the main file was broken and the [code].bak[/code] copy was loaded.
signal load_finished(slot: String, err: Error)

## Directory of the save slots.
@export var save_dir := "user://saves"
## Save layout version of the game. Bump it when the layout of [member data] changes;
## files from a newer version are refused.
@export var current_format_version: int = 1
## Game version written into each save; defaults to [code]application/config/version[/code].
@export var game_version: String = ""

## The game data written by [method save_game] and replaced by [method load_game].
var data: Dictionary = {}
## Header data of the last loaded slot.
var meta: Dictionary = {}


## Writes [member data] to [param slot]. [param meta] is stored in the header.
## Returns [constant ERR_INVALID_PARAMETER] for an invalid slot name.
func save_game(slot: String, save_meta: Dictionary = {}) -> Error:
	if not ISKSaveFile.is_valid_slot_name(slot):
		_warn("ISKSave: invalid slot name '%s'" % slot)
		save_finished.emit(slot, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER
	save_started.emit(slot)
	var file := ISKSaveFile.new()
	file.slot = slot
	file.format_version = current_format_version
	file.game_version = _game_version()
	file.saved_at = ISKSaveFile.utc_now()
	file.meta = save_meta
	file.data = _collect_data()
	var err := file.write(get_slot_path(slot))
	if err != OK:
		_warn("ISKSave: saving slot '%s' failed: %s" % [slot, error_string(err)])
	save_finished.emit(slot, err)
	return err


## Loads [param slot] into [member data] and [member meta].
## Returns [constant OK]; [constant ERR_FILE_CORRUPT] if the backup was loaded
## (data is applied); [constant ERR_INVALID_PARAMETER] for an invalid slot name,
## [constant ERR_FILE_NOT_FOUND], [constant ERR_FILE_UNRECOGNIZED] for a file from a
## newer [member current_format_version], or another read error (data unchanged).
func load_game(slot: String) -> Error:
	var err := _load(slot)
	load_finished.emit(slot, err)
	return err


## Returns true if a save file (or its backup) exists for [param slot].
func has_slot(slot: String) -> bool:
	if not ISKSaveFile.is_valid_slot_name(slot):
		return false
	var path := get_slot_path(slot)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ISKSaveFile.BACKUP_SUFFIX)


## Returns the file path of [param slot] (no validation).
func get_slot_path(slot: String) -> String:
	return ISKSaveFile.slot_path(save_dir, slot)


func _load(slot: String) -> Error:
	if not ISKSaveFile.is_valid_slot_name(slot):
		_warn("ISKSave: invalid slot name '%s'" % slot)
		return ERR_INVALID_PARAMETER
	var file := ISKSaveFile.new()
	var err := file.read_with_backup(get_slot_path(slot))
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			_warn("ISKSave: loading slot '%s' failed: %s" % [slot, error_string(err)])
		return err
	if file.format_version > current_format_version:
		_warn(
			(
				"ISKSave: slot '%s' has format_version %d, newer than %d"
				% [slot, file.format_version, current_format_version]
			)
		)
		return ERR_FILE_UNRECOGNIZED
	err = _upgrade(file)
	if err != OK:
		return err
	_apply_data(file.data)
	meta = file.meta
	if file.used_backup:
		_warn("ISKSave: slot '%s' was corrupt, loaded the backup" % slot)
		return ERR_FILE_CORRUPT
	return OK


## Virtual: returns the data to save. Default: [member data].
func _collect_data() -> Dictionary:
	return data


## Virtual: applies loaded data. Default: replaces [member data].
func _apply_data(loaded: Dictionary) -> void:
	data = loaded


## Virtual: brings an older [param file] up to [member current_format_version].
## Default: no change (migrations are added by the full edition).
func _upgrade(_file: ISKSaveFile) -> Error:
	return OK


## Virtual: reports a problem. Default: [method @GlobalScope.push_warning].
func _warn(message: String) -> void:
	push_warning(message)


func _game_version() -> String:
	if not game_version.is_empty():
		return game_version
	return str(ProjectSettings.get_setting("application/config/version", ""))
