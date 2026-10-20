# ISKItemDefinition

**Extends:** `Resource` · **File:** `core/isk_item_definition.gd`

Static description of an item type (sword, potion, ...).

Create one resource per item type. Extend it for typed fields: `class_name Sword extends ISKItemDefinition`. Save files only store `id`, never resource paths, so `id` must stay stable across game versions.

## Constants

### MIN_STACK

```gdscript
const MIN_STACK: int = 1
```

Smallest allowed `max_stack`.

### MAX_STACK

```gdscript
const MAX_STACK: int = 9999
```

Largest allowed `max_stack`.

## Properties

### id

```gdscript
@export var id: StringName = &""
```

Unique, stable identifier. Saves store it.

### display_name

```gdscript
@export var display_name: String = ""
```

Name shown to the player.

### description

```gdscript
@export_multiline var description: String = ""
```

Description shown to the player.

### icon

```gdscript
@export var icon: Texture2D
```

Icon for slots and tooltips. Not part of `to_dict`.

### max_stack

```gdscript
@export_range(1, 9999) var max_stack: int = 1
```

How many items fit into one stack.

### weight

```gdscript
@export var weight: float = 0.0
```

Weight of a single item.

### tags

```gdscript
@export var tags: Array[StringName] = []
```

Free tags, e.g. `&"weapon"`; equipment slots filter by them.

### properties

```gdscript
@export var properties: Dictionary = {}
```

Free per-type data (damage, price, ...). Keep it JSON compatible.

## Methods

### is_stackable

```gdscript
func is_stackable() -> bool
```

Returns `true` if this item can form stacks larger than one.

### has_tag

```gdscript
func has_tag(tag: StringName) -> bool
```

Returns `true` if `tags` contains `tag`.

### validate

```gdscript
func validate() -> PackedStringArray
```

Returns a list of problems; empty means the definition is valid.

### to_dict

```gdscript
func to_dict() -> Dictionary
```

Returns a JSON-compatible dictionary of all fields except `icon`.

### from_dict

```gdscript
static func from_dict(d: Dictionary) -> ISKItemDefinition
```

Builds a definition from `to_dict` output (e.g. parsed JSON). Returns `null` if `d` is malformed or the result does not pass `validate`. Missing optional keys keep their defaults.
