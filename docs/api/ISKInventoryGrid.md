# ISKInventoryGrid

**Extends:** `GridContainer` · **File:** `ui/isk_inventory_grid.gd`

Shows an [`ISKInventory`](ISKInventory.md) as a grid of [`ISKSlotView`](ISKSlotView.md)s (one per slot).

Rebuilds the slot views when the slot count changes (shrinking [`ISKInventory.slot_count`](ISKInventory.md#slot_count) only emits `Resource.changed`) and refreshes single views on [`ISKInventory.slot_changed`](ISKInventory.md#slot_changed). Drag & drop works between any grids, also across inventories. Keyboard: arrow keys move the focus between slots (Godot focus neighbours), `ui_accept` activates a slot. Set `GridContainer.columns` for the layout; looks come from the theme (see [`ISKSlotView`](ISKSlotView.md)).

## Signals

### slot_activated

```gdscript
signal slot_activated(index: int)
```

Emitted when a slot is double-clicked or activated with `ui_accept`.

## Properties

### inventory

```gdscript
@export var inventory: ISKInventory
```

The inventory to show; `null` shows nothing.

### select_on_activate

```gdscript
@export var select_on_activate: bool = true
```

Mark the last activated slot as selected.

### selected_index

```gdscript
var selected_index: int = -1
```

Index of the selected slot, -1 = none.

## Methods

### get_slot_view

```gdscript
func get_slot_view(index: int) -> ISKSlotView
```

Returns the view of slot `index`, or `null`.

### get_slot_view_count

```gdscript
func get_slot_view_count() -> int
```

Number of slot views currently shown.
