# UI Importer Pro

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Wally](https://img.shields.io/badge/Wally-0.1.0-blue)](wally.toml)

UI Importer Pro is a Roblox Studio plugin for turning imported, offset-heavy UI into responsive production UI. It recursively converts selected `GuiObject` trees to scale-based sizing and positioning while preserving their current visual layout.

## Why It Matters

Imported UI often arrives as fixed pixel offsets. That works on one viewport, then breaks across phones, tablets, and ultrawide monitors. UI Importer Pro focuses on the cleanup step Roblox UI builders repeat by hand:

- convert offsets to parent-relative scale values
- preserve nested UI placement
- center anchors without moving objects visually
- respect layout-managed children instead of forcing their positions
- infer clear rows, columns, grids, tables, and pages into Roblox layout objects
- scale `UIListLayout`, `UIGridLayout`, `UIPageLayout`, `UIPadding`, and `ScrollingFrame.CanvasSize`
- account for local `UIScale` objects when calculating responsive size
- add aspect ratio constraints where they are missing
- wrap changes in Studio history waypoints for undo support

## Developer Setup

```bash
git clone https://github.com/qzhcore/UI-Importer-Pro-.git
cd UI-Importer-Pro-
aftman install
wally install
rojo build default.project.json --output UIImporterPro.rbxm
```

## Usage

1. Download `UIImporterPro.rbxm` from the latest GitHub release.
2. In Roblox Studio, open the `Plugins` tab and click `Plugins Folder`.
3. Move `UIImporterPro.rbxm` into that folder, then restart Studio.
4. Select a `ScreenGui` or supported `GuiObject` in Explorer.
5. Click the `FixScale` button in the `UI Importer Pro` toolbar.
6. Use Studio undo if the selected hierarchy needs another pass.

## API

See the hosted documentation in `docs/` for module-level API notes:

- `ScalingEngine.ToScale(instance)`
- `ScalingEngine.ProcessRecursive(root)`
- `LayoutOrganizer.ProcessRecursive(root)`
- `FileParser.identify(instances)`
- `FileParser.processImported(instances)`

## Quality

Before committing changes, run the formatter and linter used by the project:

```bash
stylua src
selene src
```
