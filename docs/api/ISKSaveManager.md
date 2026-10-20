# ISKSaveManager

**Extends:** `Node` · **File:** `save/isk_save_manager.gd`

Saves and loads game data as JSON slots (autoload `ISKSave`).

Put the data to persist into `data` (for example in a handler of `save_started`), call `save_game`, and read it back after `load_game`. Files live in `save_dir` as `<slot>.json`; see [`ISKSaveFile`](ISKSaveFile.md) for the envelope and the atomic write.

## Signals

### save_started

```gdscript
signal save_started(slot: String)
```

Emitted before a slot is written. Handlers may still change `data`.

### save_finished

```gdscript
signal save_finished(slot: String, err: Error)
```

Emitted after `save_game`, also on failure.

### load_finished

```gdscript
signal load_finished(slot: String, err: Error)
```

Emitted after `load_game`, also on failure. `ERR_FILE_CORRUPT` means the main file was broken and the `.bak` copy was loaded.

## Properties

### save_dir

```gdscript
@export var save_dir := "user://saves"
```

Directory of the save slots.

### current_format_version

```gdscript
@export var current_format_version: int = 1
```

Save layout version of the game. Bump it when the layout of `data` changes; files from a newer version are refused.

### game_version

```gdscript
@export var game_version: String = ""
```

Game version written into each save; defaults to `application/config/version`.

### data

```gdscript
var data: Dictionary = {}
```

The game data written by `save_game` and replaced by `load_game`.

### meta

```gdscript
var meta: Dictionary = {}
```

Header data of the last loaded slot.

## Methods

### save_game

```gdscript
func save_game(slot: String, save_meta: Dictionary = {}) -> Error
```

Writes `data` to `slot`. `meta` is stored in the header. Returns `ERR_INVALID_PARAMETER` for an invalid slot name.

### load_game

```gdscript
func load_game(slot: String) -> Error
```

Loads `slot` into `data` and `meta`. Returns `OK`; `ERR_FILE_CORRUPT` if the backup was loaded (data is applied); `ERR_INVALID_PARAMETER` for an invalid slot name, `ERR_FILE_NOT_FOUND`, `ERR_FILE_UNRECOGNIZED` for a file from a newer `current_format_version`, or another read error (data unchanged).

### has_slot

```gdscript
func has_slot(slot: String) -> bool
```

Returns true if a save file (or its backup) exists for `slot`.

### get_slot_path

```gdscript
func get_slot_path(slot: String) -> String
```

Returns the file path of `slot` (no validation).
