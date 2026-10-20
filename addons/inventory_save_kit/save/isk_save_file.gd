class_name ISKSaveFile
extends RefCounted
## JSON save envelope of Inventory & Save Kit: read, validate and write one save file.
##
## A save file is plain JSON text (see ARCHITECTURE.md §3.3). Writes are atomic:
## the new content goes to [code]<slot>.json.tmp[/code], the previous valid file is
## kept as [code]<slot>.json.bak[/code], then the temp file is renamed into place.
## Reading never uses [code]str_to_var[/code]: save files are untrusted input.
## Header fields are written first and [code]data[/code] last, one top-level key
## per line, so slot lists can read the header without parsing the game data.
## [br][br]
## The class also offers helpers to store vectors and colours as JSON arrays, so
## games do not invent their own encodings.

## Value of the [code]format[/code] field that marks an Inventory & Save Kit file.
const FORMAT := "isk-save"
## File extension of a save slot.
const EXTENSION := ".json"
## Suffix of the backup copy of the previous save.
const BACKUP_SUFFIX := ".bak"
## Suffix of the temporary file used for atomic writes.
const TEMP_SUFFIX := ".tmp"
## Allowed slot names: lowercase letters, digits, [code]_[/code] and [code]-[/code], 1–32 chars.
const SLOT_NAME_PATTERN := "^[a-z0-9_-]{1,32}$"

static var _slot_regex: RegEx

## Slot name this file belongs to.
var slot: String = ""
## Save layout version of the game that wrote the file.
var format_version: int = 0
## Game version string at save time (free text, e.g. "1.2.0").
var game_version: String = ""
## UTC timestamp of the save, ISO 8601 ("2026-10-18T15:00:00Z").
var saved_at: String = ""
## Small header data for slot lists (playtime, location …).
var meta: Dictionary = {}
## The game data.
var data: Dictionary = {}
## True if the last [method read_with_backup] had to use the [code].bak[/code] file.
var used_backup: bool = false


## Returns true if [param slot_name] is a valid slot name (prevents path traversal).
static func is_valid_slot_name(slot_name: String) -> bool:
	if _slot_regex == null:
		_slot_regex = RegEx.create_from_string(SLOT_NAME_PATTERN)
	return _slot_regex.search(slot_name) != null


## Returns the path of [param slot_name] inside [param dir] (no validation).
static func slot_path(dir: String, slot_name: String) -> String:
	return dir.path_join(slot_name + EXTENSION)


## Current UTC time as ISO 8601 string with [code]Z[/code] suffix.
static func utc_now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


## Builds the envelope dictionary that is written to disk.
func to_dict() -> Dictionary:
	return {
		"format": FORMAT,
		"format_version": format_version,
		"game_version": game_version,
		"saved_at": saved_at,
		"slot": slot,
		"meta": meta,
		"data": data,
	}


## Fills this object from a parsed envelope. Returns [constant OK] or
## [constant ERR_FILE_CORRUPT] if [param envelope] is not a valid save envelope.
func from_dict(envelope: Variant) -> Error:
	if not _is_envelope(envelope):
		return ERR_FILE_CORRUPT
	var d: Dictionary = envelope
	var version: Variant = d["format_version"]
	var meta_value: Variant = d.get("meta", {})
	format_version = int(version)
	data = d["data"]
	meta = meta_value
	game_version = str(d.get("game_version", ""))
	saved_at = str(d.get("saved_at", ""))
	slot = str(d.get("slot", ""))
	return OK


## Reads and validates the file at [param path].
## Returns [constant OK], [constant ERR_FILE_NOT_FOUND], [constant ERR_FILE_CANT_READ]
## or [constant ERR_FILE_CORRUPT] (not JSON or not a save envelope).
func read(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		return ERR_FILE_CANT_READ
	var json := JSON.new()
	if json.parse(text) != OK:
		return ERR_FILE_CORRUPT
	return from_dict(json.data)


## Reads [param path]; if it is missing or corrupt, falls back to its
## [code].bak[/code] copy and sets [member used_backup].
## Returns the error of the main file if the backup could not be read either.
func read_with_backup(path: String) -> Error:
	used_backup = false
	var err := read(path)
	if err == OK:
		return OK
	var backup_err := read(path + BACKUP_SUFFIX)
	if backup_err == OK:
		used_backup = true
		return OK
	return err


## Writes this envelope atomically to [param path], creating the directory if needed.
## The previous file is kept as [code].bak[/code] if it is a valid save; a corrupt
## previous file is dropped so it never replaces a good backup.
func write(path: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		return err
	var temp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t", false))
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK:
		DirAccess.remove_absolute(temp_path)
		return err
	if FileAccess.file_exists(path):
		var backup_path := path + BACKUP_SUFFIX
		if ISKSaveFile.new().read(path) == OK:
			if FileAccess.file_exists(backup_path):
				err = DirAccess.remove_absolute(backup_path)
				if err != OK:
					return err
			err = DirAccess.rename_absolute(path, backup_path)
		else:
			err = DirAccess.remove_absolute(path)
		if err != OK:
			return err
	return DirAccess.rename_absolute(temp_path, path)


## [Vector2] → [code][x, y][/code].
static func vec2_to_json(value: Vector2) -> Array:
	return [value.x, value.y]


## [code][x, y][/code] → [Vector2]; returns [param fallback] if the array is malformed.
static func json_to_vec2(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	var n := _numbers(value, 2)
	return fallback if n.is_empty() else Vector2(n[0], n[1])


## [Vector2i] → [code][x, y][/code].
static func vec2i_to_json(value: Vector2i) -> Array:
	return [value.x, value.y]


## [code][x, y][/code] → [Vector2i]; returns [param fallback] if the array is malformed.
static func json_to_vec2i(value: Variant, fallback := Vector2i.ZERO) -> Vector2i:
	var n := _numbers(value, 2)
	return fallback if n.is_empty() else Vector2i(roundi(n[0]), roundi(n[1]))


## [Vector3] → [code][x, y, z][/code].
static func vec3_to_json(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


## [code][x, y, z][/code] → [Vector3]; returns [param fallback] if the array is malformed.
static func json_to_vec3(value: Variant, fallback := Vector3.ZERO) -> Vector3:
	var n := _numbers(value, 3)
	return fallback if n.is_empty() else Vector3(n[0], n[1], n[2])


## [Color] → [code][r, g, b, a][/code].
static func color_to_json(value: Color) -> Array:
	return [value.r, value.g, value.b, value.a]


## [code][r, g, b, a][/code] → [Color]; returns [param fallback] if the array is malformed.
static func json_to_color(value: Variant, fallback := Color.WHITE) -> Color:
	var n := _numbers(value, 4)
	return fallback if n.is_empty() else Color(n[0], n[1], n[2], n[3])


# True if `value` has the envelope shape: format marker, whole non-negative
# format_version, data dictionary and (optional) meta dictionary.
static func _is_envelope(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var d: Dictionary = value
	var version: Variant = d.get("format_version")
	if not (version is float or version is int):
		return false
	return (
		d.get("format") == FORMAT
		and version >= 0
		and float(version) == floorf(float(version))
		and d.get("data") is Dictionary
		and d.get("meta", {}) is Dictionary
	)


# Returns the array as floats if it has exactly `count` numbers, else an empty array.
static func _numbers(value: Variant, count: int) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	if not value is Array or (value as Array).size() != count:
		return result
	for v: Variant in value:
		if not (v is float or v is int):
			return PackedFloat64Array()
		result.append(float(v))
	return result
