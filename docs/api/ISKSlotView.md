# ISKSlotView

**Extends:** `PanelContainer` · **File:** `ui/isk_slot_view.gd`

Shows one slot of an [`ISKInventory`](ISKInventory.md): icon, count and state, with drag & drop.

Dragging a slot onto another slot calls [`ISKInventory.move`](ISKInventory.md#move) inside one inventory and [`ISKInventory.transfer`](ISKInventory.md#transfer) between inventories (bags, equipment, chests). `_can_drop_data` refuses drops that would move nothing (wrong tag, weight limit, full stack), so Godot shows the forbidden cursor. Keyboard: the slot is focusable (focus looks like hover), `ui_accept` or a double click emits `slot_activated`.  
Full edition: filled slots show an item tooltip and a right click splits the stack (amount dialog; Shift + right click = half). The view finds these full-only scripts by file presence (`TOOLTIP_PATH`, `SPLIT_PATH`), so the lite edition simply has neither.  
All looks come from the theme type variations `ISKSlot`, `ISKSlotHover`, `ISKSlotSelected`, `ISKSlotLocked` and `ISKCountLabel` (see `docs/ui-spec.md`); the view never sets colours, sizes or a texture filter itself.

## Signals

### slot_activated

```gdscript
signal slot_activated(index: int)
```

Emitted on double click or `ui_accept` (e.g. "use" or "equip").

### stack_dropped

```gdscript
signal stack_dropped(from_inventory: ISKInventory, from_index: int, moved: int)
```

Emitted on the target slot after a drop moved `moved` items into it from slot `from_index` of `from_inventory`.

## Constants

### DRAG_TYPE

```gdscript
const DRAG_TYPE := &"isk_slot"
```

Key that marks drag data created by an [`ISKSlotView`](ISKSlotView.md).

### TOOLTIP_PATH

```gdscript
const TOOLTIP_PATH := "res://addons/inventory_save_kit/ui/isk_tooltip.gd"
```

Tooltip script of the full edition; slots show no tooltip without it.

### SPLIT_PATH

```gdscript
const SPLIT_PATH := "res://addons/inventory_save_kit/ui/isk_split_dialog.gd"
```

Split dialog script of the full edition; right click does nothing without it.

## Properties

### inventory

```gdscript
var inventory: ISKInventory
```

The inventory this view shows a slot of.

### index

```gdscript
var index: int = -1
```

Slot index in `inventory`.

### selected

```gdscript
var selected: bool = false
```

Selected look (activated slot, slot picked for split, equipment in use).

### locked

```gdscript
var locked: bool = false
```

Locked slot: dimmed icon, forbidden cursor, no drag and no drop.

## Methods

### get_item_stack

```gdscript
func get_item_stack() -> ISKItemStack
```

Returns the stack shown by this view, or `null` if empty.

### refresh

```gdscript
func refresh() -> void
```

Re-reads icon and count from `inventory`. The grid calls it on [`ISKInventory.slot_changed`](ISKInventory.md#slot_changed).

### get_state_variation

```gdscript
func get_state_variation() -> StringName
```

Name of the theme type variation for the current state (priority locked > selected > hover; the drag source only fades the icon).

### is_drag_source

```gdscript
func is_drag_source() -> bool
```

Returns `true` while this slot's stack is being dragged.

### request_split

```gdscript
func request_split(half: bool) -> bool
```

Right click action: splits the stack (full edition) – `half` splits half at once, else the amount dialog opens. Returns `true` if it split or opened the dialog, `false` if refused (locked, empty, single item, no free slot) or in the lite edition.

### item_label

```gdscript
static func item_label(item: ISKItemDefinition) -> String
```

Name shown for `item`: its display name, or its ID if the name is empty.

### edition_script

```gdscript
static func edition_script(path: String) -> Script
```

Returns the full-edition script at `path`, or `null` if the edition does not ship it (cached).

### drop_amount

```gdscript
func drop_amount(data: Variant) -> int
```

How many items a drop of `data` (from `_get_drag_data`) would move into this slot; 0 = refused. Changes nothing.
