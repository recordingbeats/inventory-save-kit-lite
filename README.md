# Inventory & Save Kit Lite

Inventory, inventory UI and a simple save system for Godot 4, written in
GDScript. Items are resources, inventories are resources, saves are readable
JSON files in `user://`. Works on desktop and in Web exports. Free, MIT licence.

This is the **Lite edition**. The **full edition** (paid, itch.io) adds
equipment slots, a list UI with tooltips and a split dialog, multiple save
slots with autosave, versioned saves with migrations and saveable nodes. It
uses the same API, so a project can switch later without code changes.

## Features

| Feature | Lite | Full |
|---|---|---|
| Item definitions (`ISKItemDefinition`), item database, stacks with per-item data | ✓ | ✓ |
| Inventory: slots, stacking, slot limit, signals | ✓ | ✓ |
| Weight limit, split stacks, transfer between inventories | ✓ | ✓ |
| Grid UI with drag & drop and keyboard support, default theme | ✓ | ✓ |
| Save/load of one slot as a JSON file (atomic write, `.bak` fallback) | ✓ | ✓ |
| Equipment slots by tag | – | ✓ |
| List UI with sorting, item tooltip, split dialog | – | ✓ |
| Multiple save slots with slot list, delete, autosave, save on quit | – | ✓ |
| Versioned save format with migrations, item ID renames | – | ✓ |
| Saveable nodes (`ISKSaveComponent`) | – | ✓ |
| Demo | small | full demo + Web demo |

All visuals come from a Godot theme (type variations `ISKSlot`, `ISKSlotHover`,
`ISKSlotSelected`, `ISKSlotLocked`, `ISKCountLabel`), so the UI can be restyled
without touching code. The addon never sets a texture filter; pixel-art and
smooth-art games both work.

## Compatibility

- Godot **4.7.x** (GDScript only, no C#, no GDExtension).
- Uses only standard Control nodes and resources; the demo and the tests run
  with the Compatibility renderer.
- Web export **without threads** (no SharedArrayBuffer/COOP/COEP headers
  needed). Saves go to `user://`, which is IndexedDB in the browser.

## Installation

1. Copy the folder `addons/inventory_save_kit` into your project's `addons/`
   folder (keep the folder name).
2. Open *Project → Project Settings → Plugins* and enable
   **Inventory & Save Kit**.
3. Enabling the plugin registers the autoload **`ISKSave`**
   (*Project Settings → Globals → Autoload*), using
   `save/isk_save_manager.gd`. Disabling the plugin removes it again.

**Lite autoload:** if you later replace the addon folder with the full edition,
disable and enable the plugin once. The plugin then registers the full save
manager as `ISKSave`; your code and your Lite saves keep working.

The `demo/` and `tests/` folders are optional. Open the package folder as a
Godot project to try the demo; the tests run with
[GUT](https://github.com/bitwes/Gut) 9.x (not included).

## Quickstart

The examples below are checked by the test `tests/unit/test_readme_examples.gd`
on every build, so they match the shipped code. In a real game you would create
items and inventories as `.tres` resources in the inspector instead of code.

### 1. Items

An `ISKItemDefinition` describes an item type; an `ISKItemDatabase` holds all of
them and resolves IDs when a save is loaded.

```gdscript
var potion := ISKItemDefinition.new()
potion.id = &"potion"
potion.display_name = "Health Potion"
potion.max_stack = 10
potion.weight = 0.5

var sword := ISKItemDefinition.new()
sword.id = &"sword"
sword.display_name = "Short Sword"
sword.weight = 3.0

var db := ISKItemDatabase.new()
db.items = [potion, sword]
print(db.get_item(&"potion").display_name)  # Health Potion
print(db.validate().is_empty())  # true
```

In the editor: *FileSystem → New Resource → ISKItemDefinition*, one file per
item, and one `ISKItemDatabase` resource that lists them.

### 2. Inventory

`add_item` fills matching stacks first, then empty slots, and returns what did
not fit. `remove_item`, `count_of` and `has_item` take an item or its ID.

<!-- doctest: continue -->
```gdscript
var bag := ISKInventory.new()
bag.slot_count = 12
bag.max_weight = 20.0
bag.item_added.connect(func(item: ISKItemDefinition, amount: int) -> void:
	print("+%d %s" % [amount, item.display_name]))

print(bag.add_item(potion, 15))  # 0
print(bag.add_item(sword))  # 0
print(bag.count_of(&"potion"))  # 15
print(bag.remove_item(&"potion", 3))  # 3
print(bag.total_weight())  # 9.0
```

Slots, moving, splitting and moving stacks to another inventory (a chest, a
shop):

<!-- doctest: continue -->
```gdscript
print(bag.get_slot(0).count)  # 10
print(bag.move(2, 5))  # true
print(bag.split(0, 4))  # true
var chest := ISKInventory.new()
print(bag.transfer(0, chest))  # 6
print(chest.count_of(&"potion"))  # 6
```

The inventory emits `slot_changed(index)` per touched slot, `item_added` /
`item_removed` per item type and `changed` once per operation.

### 3. Inventory UI

Add an `ISKInventoryGrid` (a `GridContainer`) to your scene and give it the
inventory. It creates one `ISKSlotView` per slot and updates itself on every
change. Drag & drop between grids calls `move` or `transfer`; double click or
`ui_accept` emits `slot_activated`.

```gdscript
extends Control

@export var bag: ISKInventory
@export var chest: ISKInventory

@onready var bag_grid: ISKInventoryGrid = $BagGrid
@onready var chest_grid: ISKInventoryGrid = $ChestGrid


func _ready() -> void:
	bag_grid.columns = 6
	bag_grid.inventory = bag
	chest_grid.inventory = chest  # drag stacks between both grids
	bag_grid.slot_activated.connect(_on_slot_activated)


func _on_slot_activated(index: int) -> void:
	var stack := bag.get_slot(index)
	if stack != null:
		print("Use ", stack.item.display_name)
```

Theme: the default theme is `addons/inventory_save_kit/ui/theme/isk_default_theme.tres`.
Copy it, change colours and sizes, and set it on a parent control or as the
project theme.

### 4. Saving and loading

Put what you want to keep into `ISKSave.data` (only JSON values: numbers,
strings, bools, arrays, dictionaries) and save. Inventories have `to_dict()` /
`from_dict()`. The Lite edition saves one slot at a time; use one slot name
(e.g. `"slot_1"`) or a few fixed ones.

<!-- doctest: continue -->
```gdscript
ISKSave.data["gold"] = 120
ISKSave.data["bag"] = bag.to_dict()
print(ISKSave.save_game("slot_1", {"location": "Forest"}))  # 0
print(ISKSave.has_slot("slot_1"))  # true

ISKSave.data = {}
print(ISKSave.load_game("slot_1"))  # 0
print(int(ISKSave.data["gold"]))  # 120

var loaded := ISKInventory.new()
loaded.slot_count = 12  # to_dict() stores the stacks, not the slot count
loaded.from_dict(ISKSave.data["bag"], db)
print(loaded.count_of(&"potion"))  # 6
```

`save_game` and `load_game` return an `Error` (`OK` = 0) and emit
`save_started`, `save_finished` and `load_finished`. Connect to `save_started`
to fill `data` right before the file is written. Slot names are
`[a-z0-9_-]{1,32}`; files live in `ISKSave.save_dir` (default `user://saves`).

## Notes and pitfalls

- **Web: save at checkpoints.** Browsers do not always tell the game that the
  tab is closing, so do not rely on saving when the game quits. Call
  `ISKSave.save_game(...)` at checkpoints (level end, after a shop, before a
  boss).
- **Unknown item IDs are dropped, not kept.** When an inventory is loaded with
  `from_dict`, stacks whose ID the database does not know are skipped with a
  warning. Keep item IDs stable once your game is released.
- **Keep `"nodes"` free in `ISKSave.data`** if you plan to upgrade: the full
  edition stores saveable nodes under that key.
- **Save files are untrusted input.** The loader only reads JSON values, never
  Godot objects. Store paths or IDs, not objects.

## Demo

Open the package folder as a Godot project and run it (main scene
`demo/lite/main_lite.tscn`).

A small town with items lying around. Walk over an item to pick it up; a
simple bag panel shows the inventory and a toast confirms saving and loading.

| Key | Action |
| --- | --- |
| W A S D / arrow keys | walk |
| I or Tab | show / hide the bag |
| double click or Enter on a slot | drink a potion |
| Q | drop the selected stack into the world |
| F5 / F9 | save / load (one slot) |

What to try: pick up items, drink a stamina potion (faster for a few seconds), drop
something, press F5, walk on, press F9 — pickups, dropped items, the player
position and the bag come back as saved. Only one demo world runs per scene.

Other scenes: `demo/theme_preview.tscn` (all slot states of the default theme),
`demo/ui_test/grid_test.tscn` (two grids with drag & drop).

## API reference

`docs/api/README.md` lists every class with its signals, properties and
methods. It is generated from the doc comments in the code; the same text is
shown in the Godot editor help (F1, then type the class name, e.g.
`ISKInventory`).

## Changelog and licence

See `CHANGELOG.md`. Licence: MIT, see `LICENSE`. Third-party demo art (Kenney,
CC0) is listed in `PROVENANCE.md`.

## How this addon was made

The code was written with AI assistance, then reviewed and tested
(automated tests run headless on every build, see `tests/`). No AI-generated
images are included. Details in `PROVENANCE.md`.
