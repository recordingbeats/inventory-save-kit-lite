# ISKItemDatabase

**Extends:** `Resource` · **File:** `core/isk_item_database.gd`

All item definitions of a game, looked up by [`ISKItemDefinition.id`](ISKItemDefinition.md#id).

Required to load saves: save files contain item IDs, never resource paths. If two items share an ID, the first one wins; `validate` reports it.

## Properties

### items

```gdscript
@export var items: Array[ISKItemDefinition] = []
```

The known items. After changing the array in place call `rebuild_index`.

## Methods

### get_item

```gdscript
func get_item(id: StringName) -> ISKItemDefinition
```

Returns the item with `id` or `null` if it is unknown.

### has_item

```gdscript
func has_item(id: StringName) -> bool
```

Returns `true` if an item with `id` exists.

### rebuild_index

```gdscript
func rebuild_index() -> void
```

Rebuilds the ID lookup. Call it after editing `items` in place.

### validate

```gdscript
func validate() -> PackedStringArray
```

Returns a list of problems (null entries, empty or duplicate IDs, invalid items); empty means the database is valid.

### to_dict

```gdscript
func to_dict() -> Dictionary
```

Returns a JSON-compatible dictionary with all definitions.

### from_dict

```gdscript
static func from_dict(d: Dictionary) -> ISKItemDatabase
```

Builds a database from `to_dict` output. Returns `null` if `d` is malformed, an entry is invalid or IDs are duplicated.
