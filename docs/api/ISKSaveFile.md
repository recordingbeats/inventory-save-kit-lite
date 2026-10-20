# ISKSaveFile

**Extends:** `RefCounted` · **File:** `save/isk_save_file.gd`

JSON save envelope of Inventory & Save Kit: read, validate and write one save file.

A save file is plain JSON text (see ARCHITECTURE.md §3.3). Writes are atomic: the new content goes to `<slot>.json.tmp`, the previous valid file is kept as `<slot>.json.bak`, then the temp file is renamed into place. Reading never uses `str_to_var`: save files are untrusted input. Header fields are written first and `data` last, one top-level key per line, so slot lists can read the header without parsing the game data.  
  
The class also offers helpers to store vectors and colours as JSON arrays, so games do not invent their own encodings.

## Constants

### FORMAT

```gdscript
const FORMAT := "isk-save"
```

Value of the `format` field that marks an Inventory & Save Kit file.

### EXTENSION

```gdscript
const EXTENSION := ".json"
```

File extension of a save slot.

### BACKUP_SUFFIX

```gdscript
const BACKUP_SUFFIX := ".bak"
```

Suffix of the backup copy of the previous save.

### TEMP_SUFFIX

```gdscript
const TEMP_SUFFIX := ".tmp"
```

Suffix of the temporary file used for atomic writes.

### SLOT_NAME_PATTERN

```gdscript
const SLOT_NAME_PATTERN := "^[a-z0-9_-]{1,32}$"
```

Allowed slot names: lowercase letters, digits, `_` and `-`, 1–32 chars.

## Properties

### slot

```gdscript
var slot: String = ""
```

Slot name this file belongs to.

### format_version

```gdscript
var format_version: int = 0
```

Save layout version of the game that wrote the file.

### game_version

```gdscript
var game_version: String = ""
```

Game version string at save time (free text, e.g. "1.2.0").

### saved_at

```gdscript
var saved_at: String = ""
```

UTC timestamp of the save, ISO 8601 ("2026-10-18T15:00:00Z").

### meta

```gdscript
var meta: Dictionary = {}
```

Small header data for slot lists (playtime, location …).

### data

```gdscript
var data: Dictionary = {}
```

The game data.

### used_backup

```gdscript
var used_backup: bool = false
```

True if the last `read_with_backup` had to use the `.bak` file.

## Methods

### is_valid_slot_name

```gdscript
static func is_valid_slot_name(slot_name: String) -> bool
```

Returns true if `slot_name` is a valid slot name (prevents path traversal).

### slot_path

```gdscript
static func slot_path(dir: String, slot_name: String) -> String
```

Returns the path of `slot_name` inside `dir` (no validation).

### utc_now

```gdscript
static func utc_now() -> String
```

Current UTC time as ISO 8601 string with `Z` suffix.

### to_dict

```gdscript
func to_dict() -> Dictionary
```

Builds the envelope dictionary that is written to disk.

### from_dict

```gdscript
func from_dict(envelope: Variant) -> Error
```

Fills this object from a parsed envelope. Returns `OK` or `ERR_FILE_CORRUPT` if `envelope` is not a valid save envelope.

### read

```gdscript
func read(path: String) -> Error
```

Reads and validates the file at `path`. Returns `OK`, `ERR_FILE_NOT_FOUND`, `ERR_FILE_CANT_READ` or `ERR_FILE_CORRUPT` (not JSON or not a save envelope).

### read_with_backup

```gdscript
func read_with_backup(path: String) -> Error
```

Reads `path`; if it is missing or corrupt, falls back to its `.bak` copy and sets `used_backup`. Returns the error of the main file if the backup could not be read either.

### write

```gdscript
func write(path: String) -> Error
```

Writes this envelope atomically to `path`, creating the directory if needed. The previous file is kept as `.bak` if it is a valid save; a corrupt previous file is dropped so it never replaces a good backup.

### vec2_to_json

```gdscript
static func vec2_to_json(value: Vector2) -> Array
```

`Vector2` → `[x, y]`.

### json_to_vec2

```gdscript
static func json_to_vec2(value: Variant, fallback := Vector2.ZERO) -> Vector2
```

`[x, y]` → `Vector2`; returns `fallback` if the array is malformed.

### vec2i_to_json

```gdscript
static func vec2i_to_json(value: Vector2i) -> Array
```

`Vector2i` → `[x, y]`.

### json_to_vec2i

```gdscript
static func json_to_vec2i(value: Variant, fallback := Vector2i.ZERO) -> Vector2i
```

`[x, y]` → `Vector2i`; returns `fallback` if the array is malformed.

### vec3_to_json

```gdscript
static func vec3_to_json(value: Vector3) -> Array
```

`Vector3` → `[x, y, z]`.

### json_to_vec3

```gdscript
static func json_to_vec3(value: Variant, fallback := Vector3.ZERO) -> Vector3
```

`[x, y, z]` → `Vector3`; returns `fallback` if the array is malformed.

### color_to_json

```gdscript
static func color_to_json(value: Color) -> Array
```

`Color` → `[r, g, b, a]`.

### json_to_color

```gdscript
static func json_to_color(value: Variant, fallback := Color.WHITE) -> Color
```

`[r, g, b, a]` → `Color`; returns `fallback` if the array is malformed.
