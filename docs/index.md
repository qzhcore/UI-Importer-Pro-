# UI Importer Pro Documentation

UI Importer Pro converts imported Roblox UI from fixed offsets into responsive scale-based layouts.

## Quick Start

1. Open the plugin in Roblox Studio.
2. Select a `ScreenGui` or supported UI object in Explorer.
3. Click the `FixScale` toolbar button.
4. Review the converted layout at multiple viewport sizes.

## Core Behavior

- Traverses the selected UI hierarchy recursively.
- Converts `Size` from absolute pixels to parent-relative scale.
- Converts `Position` using the selected object's parent-relative absolute position.
- Sets anchors to the center while preserving the current visual placement.
- Leaves layout-managed child positions alone when a parent has `UIListLayout`, `UIGridLayout`, `UIPageLayout`, or `UITableLayout`.
- Converts `UIListLayout.Padding`, `UIGridLayout.CellSize`, `UIGridLayout.CellPadding`, `UIPageLayout.Padding`, and `UIPadding` offsets into scale.
- Converts `ScrollingFrame.CanvasSize` offsets into scale relative to the scrolling frame size.
- Accounts for local `UIScale` values when converting object size.
- Adds `UIAspectRatioConstraint` instances when one does not already exist.
- Uses `ChangeHistoryService` waypoints so the operation can be undone.

## API Reference

### `ScalingEngine.ToScale(instance: Instance): boolean`

Converts a single `GuiObject` to scale-based `Size` and `Position`. Returns `true` when the object was processed, or `false` when the instance is unsupported or has invalid parent geometry.

### `ScalingEngine.ProcessRecursive(root: Instance): number`

Processes `root` and every descendant. Returns the number of converted `GuiObject` instances.

### `FileParser.validate(instance: Instance): boolean`

Returns whether an instance can be accepted as a root selection. `ScreenGui` is allowed as a container root, and supported `GuiObject` classes are listed in `src/Shared/Constants.luau`.

### `FileParser.identify(instances: { Instance }): { Instance }`

Filters a Studio selection down to valid UI roots.

### `FileParser.processImported(instances: { Instance }): number`

Validates selected instances, processes each valid root, and returns the number of converted UI objects.

## GitHub Pages

This repository includes a GitHub Actions workflow that publishes the `docs/` folder to GitHub Pages whenever `main` changes. In the repository settings, set Pages to use GitHub Actions as the source.
