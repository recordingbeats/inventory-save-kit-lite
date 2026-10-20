# ISKItemStack

**Extends:** `RefCounted` · **File:** `core/isk_item_stack.gd`

A number of identical items in one slot, plus per-instance state.

Two stacks merge only if they hold the same item and equal `data`. A stack never holds more than [`ISKItemDefinition.max_stack`](ISKItemDefinition.md#max_stack) items.

## Properties

### item

```gdscript
var item: ISKItemDefinition
```

The item type; `null` makes the stack invalid.

### count

```gdscript
var count: int = 0
```

Number of items, 1..`item.max_stack` for a valid stack.

### data

```gdscript
var data: Dictionary = {}
```

Per-instance state (durability, ...). Keep it JSON compatible.

## Methods

### get_max_stack

```gdscript
func get_max_stack() -> int
```

Maximum stack size of `item`, 0 without an item.

### space_left

```gdscript
func space_left() -> int
```

How many more items fit into this stack.

### is_empty

```gdscript
func is_empty() -> bool
```

Returns `true` if the stack holds no item or a count below 1.

### is_full

```gdscript
func is_full() -> bool
```

Returns `true` if no further item fits.

### can_merge

```gdscript
func can_merge(other: ISKItemStack) -> bool
```

Returns `true` if `other` holds the same item (same instance or same ID) with equal `data`. Numbers compare by value, so `3` equals `3.0` (JSON loads every number as float). Capacity is not checked; see `merge_from`.

### merge_from

```gdscript
func merge_from(other: ISKItemStack) -> int
```

Moves as many items from `other` into this stack as fit. Returns the remainder left in `other` (all of it if they cannot merge).

### duplicate_stack

```gdscript
func duplicate_stack() -> ISKItemStack
```

Returns a copy (deep copy of `data`, same `item`).

### validate

```gdscript
func validate() -> PackedStringArray
```

Returns a list of problems; empty means the stack is valid.

### to_dict

```gdscript
func to_dict() -> Dictionary
```

Returns the save representation `{"id", "n", "d"}`.

### from_dict

```gdscript
static func from_dict(d: Dictionary, db: ISKItemDatabase) -> ISKItemStack
```

Builds a stack from `to_dict` output, resolving the ID through `db`. Returns `null` for unknown IDs, malformed input or a count outside 1..max_stack (save files are untrusted input).
