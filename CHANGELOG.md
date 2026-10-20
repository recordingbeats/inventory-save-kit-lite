# Changelog

All notable changes to Inventory & Save Kit. Versions follow
[Semantic Versioning](https://semver.org/). Features marked *(Full)* are only in
the full edition.

## [Unreleased]

## [1.0.0] – 2026-10-19

First release, for Godot 4.7+ (tested with 4.7.2).

### Items
- `ISKItemDefinition` (ID, name, description, icon, max stack, weight, tags,
  free-form `properties`) with `validate()`.
- `ISKItemDatabase`: lookup by ID, duplicate-ID check.
- `ISKItemStack`: count plus per-instance `data`, merge rules, `to_dict()` /
  `from_dict()`.

### Inventory
- `ISKInventory`: fixed slots, stacking (existing stacks first, then empty
  slots), slot limit with remainder, weight limit `max_weight`.
- `set_slot`, `move` (merge or swap), `split`, `transfer` between inventories,
  `move_preview` / `transfer_preview` for drop checks, `count_of`, `has_item`,
  `total_weight`, `clear`.
- Signals once per operation: `changed`, `slot_changed`, `item_added`,
  `item_removed`.
- `to_dict()` / `from_dict()`; invalid entries and unknown item IDs in save data
  are dropped with a warning instead of crashing.
- *(Full)* `ISKEquipment`: one item per slot, slots accept items by tag,
  `equipped` / `unequipped` signals.

### UI
- `ISKInventoryGrid` and `ISKSlotView`: grid of slots with icon, count and
  hover/selected/locked states, drag & drop within and between inventories,
  keyboard focus and `ui_accept`, `slot_activated` signal.
- Default theme with type variations, no hard-coded colours or sizes; text
  contrast ≥ 4.5:1.
- *(Full)* `ISKEquipmentGrid` for equipment slots.
- *(Full)* `ISKInventoryList`: rows with icon, name, count and weight, sortable
  by header, drag & drop with grids.
- *(Full)* `ISKTooltip` (name, description, selected properties, weight) and
  `ISKSplitDialog` (right click = amount dialog, Shift + right click = half).

### Saving
- `ISKSave` autoload (registered by the plugin), `save_game` / `load_game` /
  `has_slot`, signals `save_started`, `save_finished`, `load_finished`.
- `ISKSaveFile`: readable JSON envelope (format version, game version, time,
  meta, data), atomic write with `.bak` fallback, slot-name check, helpers for
  vectors and colours.
- *(Full)* Multiple slots: `list_slots()` (reads only the header),
  `delete_slot()`.
- *(Full)* Autosave timer (`autosave_interval`, `autosave()`), `save_on_quit`.
- *(Full)* Versioned save format: `register_migration`, step-by-step upgrade,
  `ISKSaveMigrator.rename_item_ids`, newer files refused.
- *(Full)* Saveable nodes: group `isk_saveable`, `ISKSaveComponent` saves chosen
  properties and an inventory of its parent under `data["nodes"]`.
- *(Full)* `save_dir` restricted to `user://`.

### Demo and docs
- Demo world: walk around, pick up items (`Area2D` pickups), drop them back
  into the world, use potions, save and load; Lite demo
  `demo/lite/main_lite.tscn` with save indicator and a placeholder bag.
- *(Full)* Demo `demo/main.tscn`: equipment with visible effects (speed, light,
  weapon in hand), player saved by `ISKSaveComponent`s, main menu with save
  slots, inventory window (drop by dragging out), autosave at checkpoints.
- Demo controls: I or Tab opens and closes the inventory window / Lite bag,
  also while a slot has keyboard focus (Tab no longer moves focus there; the
  arrow keys move between slots).
- Save indicator toast, demo theme, item icons from Kenney (CC0).
- README with tested code examples, API reference in `docs/api/` generated from
  the doc comments.
- Tested on Linux desktop and in the Web export (Chromium, no threads), including
  saves in the browser surviving a page reload.

### Licence
- Full edition: commercial licence (use in any number of games and apps, no
  redistribution of the addon itself), `LICENSE` of the full package.
- Lite edition: MIT.
- Copyright (c) 2026 Recordingbeats. Demo art: Kenney, CC0 1.0.
