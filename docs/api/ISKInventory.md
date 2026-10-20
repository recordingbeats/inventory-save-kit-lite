# ISKInventory

**Extends:** `Resource` · **File:** `core/isk_inventory.gd`

A fixed number of slots, each empty or holding one [`ISKItemStack`](ISKItemStack.md).

`add_item` fills matching stacks first, then empty slots in slot order. Every public operation that changes the inventory emits `changed` once, `slot_changed` once per touched slot and `item_added` / `item_removed` at most once per item type. Pure moves between slots (`move`) and `from_dict` emit no add/remove signals. Slot contents returned by `get_slot` belong to the inventory: read them, but change slots only through the methods of this class.

With `max_weight` above 0, adding items stops at the weight limit; refused or partial operations return `false` or a remainder. Subclasses restrict slots through `can_accept` and `_slot_capacity` (equipment slots in the full edition do that).

## Signals

### slot_changed

```gdscript
signal slot_changed(index: int)
```

Emitted once for every slot whose content changed during an operation.

### item_added

```gdscript
signal item_added(item: ISKItemDefinition, amount: int)
```

Emitted when `amount` × `item` entered the inventory.

### item_removed

```gdscript
signal item_removed(item: ISKItemDefinition, amount: int)
```

Emitted when `amount` × `item` left the inventory.

## Constants

### WEIGHT_EPSILON

```gdscript
const WEIGHT_EPSILON := 0.0001
```

Tolerance for float sums such as 0.1 × 3 when checking `max_weight`.

## Properties

### slot_count

```gdscript
@export_range(0, 1000, 1, "or_greater") var slot_count: int = 20
```

Number of slots. Shrinking drops the stacks in the removed slots silently: only `changed` is emitted (no `slot_changed` or `item_removed`), so listeners resync the whole inventory on `changed`. Meant for setup, not for gameplay.

### max_weight

```gdscript
@export_range(0.0, 10000.0, 0.01, "or_greater") var max_weight: float = 0.0
```

Weight limit for `total_weight`; 0 = no limit. Lowering it below the current weight removes nothing, it only refuses further weight.

## Methods

### add_item

```gdscript
func add_item(item: ISKItemDefinition, amount: int = 1, data: Dictionary = {}) -> int
```

Adds `amount` × `item` with per-instance `data`. Fills existing stacks that can merge first, then empty slots, both in slot order, and stops at `max_weight`. Returns the remainder that did not fit (0 = everything was added).

### remove_item

```gdscript
func remove_item(item_or_id: Variant, amount: int = 1) -> int
```

Removes up to `amount` items matching `item_or_id` (an [`ISKItemDefinition`](ISKItemDefinition.md), `StringName` or `String` ID), taking from the last matching slot first. Returns how many were removed.

### get_slot

```gdscript
func get_slot(index: int) -> ISKItemStack
```

Returns the stack in slot `index`, or `null` if the slot is empty or out of range.

### set_slot

```gdscript
func set_slot(index: int, stack: ISKItemStack) -> bool
```

Puts a copy of `stack` into slot `index`, replacing its content; `null` or an empty stack clears the slot. Returns `false` (and changes nothing) if the index is out of range, the stack is invalid, `can_accept` refuses it or it would raise the weight above `max_weight`.

### move

```gdscript
func move(from: int, to: int) -> bool
```

Moves the stack in slot `from` to slot `to`: into an empty slot, merged into a matching stack (the remainder stays in `from`) or swapped with a different stack. Returns `true` if anything moved.

### split

```gdscript
func split(index: int, amount: int) -> bool
```

Moves `amount` items from the stack in slot `index` into the first empty slot that accepts them (same [`ISKItemStack.data`](ISKItemStack.md#data)). Returns `false` (nothing changed) if the slot is empty, `amount` is not in 1..count − 1 or no empty slot accepts the part. Emits `slot_changed` for both slots and `changed`, no add/remove signals.

### transfer

```gdscript
func transfer(from_index: int, target: ISKInventory, to_index: int = -1) -> int
```

Moves the stack in slot `from_index` into `target`, a different inventory, and returns how many items moved (0 = refused, nothing changed).
- `to_index` = -1: like `add_item` on the target (merge first, then empty slots); the rest stays in `from_index`.
- `to_index` ≥ 0, empty or matching stack: as many as fit there (slot capacity, `can_accept`, weight); the rest stays.
- `to_index` ≥ 0 with a different stack: both stacks swap if each side accepts the other completely, else nothing happens.  
Both inventories emit their own signals, `changed` once each. Use `move` inside one inventory; `target` == self returns 0.

### move_preview

```gdscript
func move_preview(from: int, to: int) -> int
```

Returns how many items `move` with the same arguments would move (0 = refused; a swap counts the whole source stack). Changes nothing; UI drop checks use it.

### transfer_preview

```gdscript
func transfer_preview(from_index: int, target: ISKInventory, to_index: int = -1) -> int
```

Returns how many items `transfer` with the same arguments would move (0 = refused). Changes nothing; UI drop checks use it.

### count_of

```gdscript
func count_of(item_or_id: Variant) -> int
```

Returns how many items matching `item_or_id` the inventory holds.

### has_item

```gdscript
func has_item(item_or_id: Variant, amount: int = 1) -> bool
```

Returns `true` if at least `amount` items matching `item_or_id` are in the inventory.

### total_weight

```gdscript
func total_weight() -> float
```

Sum of [`ISKItemDefinition.weight`](ISKItemDefinition.md#weight) × count over all slots.

### is_full

```gdscript
func is_full() -> bool
```

Returns `true` if every slot holds a full stack, so `add_item` cannot add anything (the weight limit is not checked here).

### clear

```gdscript
func clear() -> void
```

Empties all slots.

### can_accept

```gdscript
func can_accept(index: int, stack: ISKItemStack) -> bool
```

Virtual: returns `true` if slot `index` may hold `stack`. The base inventory accepts any stack in range; equipment overrides this to check item tags.

### to_dict

```gdscript
func to_dict() -> Dictionary
```

Returns the save representation `{"slots": [{"i", "id", "n", "d"}]}` (empty slots are left out).

### from_dict

```gdscript
func from_dict(d: Dictionary, db: ISKItemDatabase) -> void
```

Replaces the content with `to_dict` output, resolving IDs through `db`. `d` is untrusted input: malformed entries, unknown IDs, out-of-range or duplicate indices and refused stacks are dropped with a warning (`_warn`); the rest is loaded. Without a usable `slots` array the inventory ends up empty. Emits `slot_changed` for changed slots and `changed`, but no add/remove signals.
