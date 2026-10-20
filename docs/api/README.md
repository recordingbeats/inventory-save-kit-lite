# Inventory & Save Kit 1.0.0 – API reference

Generated from the `##` doc comments of the addon scripts (`tools/apidoc.py`). The same text is shown in the Godot editor help (F1 → class name).

| Class | Extends | Summary |
|---|---|---|
| [`ISKInventory`](ISKInventory.md) | `Resource` | A fixed number of slots, each empty or holding one [`ISKItemStack`](ISKItemStack.md). |
| [`ISKInventoryGrid`](ISKInventoryGrid.md) | `GridContainer` | Shows an [`ISKInventory`](ISKInventory.md) as a grid of [`ISKSlotView`](ISKSlotView.md)s (one per slot). |
| [`ISKItemDatabase`](ISKItemDatabase.md) | `Resource` | All item definitions of a game, looked up by [`ISKItemDefinition.id`](ISKItemDefinition.md#id). |
| [`ISKItemDefinition`](ISKItemDefinition.md) | `Resource` | Static description of an item type (sword, potion, ...). |
| [`ISKItemStack`](ISKItemStack.md) | `RefCounted` | A number of identical items in one slot, plus per-instance state. |
| [`ISKSaveFile`](ISKSaveFile.md) | `RefCounted` | JSON save envelope of Inventory & Save Kit: read, validate and write one save file. |
| [`ISKSaveManager`](ISKSaveManager.md) | `Node` | Saves and loads game data as JSON slots (autoload `ISKSave`). |
| [`ISKSlotView`](ISKSlotView.md) | `PanelContainer` | Shows one slot of an [`ISKInventory`](ISKInventory.md): icon, count and state, with drag & drop. |
