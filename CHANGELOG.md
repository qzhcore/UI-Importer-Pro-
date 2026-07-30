# Changelog

All notable changes to UI Importer Pro are documented here.

## [0.3.0-beta.3] - 2026-07-29

### Added

- Standard PSD import for RGB, 8-bit raw and RLE layer pixels.
- Native Figma `.fig` decoding for Kiwi scene graphs.
- `ScreenGui`, `SurfaceGui`, and `BillboardGui` root selection.
- Adaptive and preserve-aspect sizing modes.
- Embedded DataModel-scoped artwork with tiling for large images.
- Layer-name hints for Roblox UI classes, layouts, constraints, and modifiers.
- Source metadata attributes and the `UIImporterGenerated` tag.
- Device-safe ScreenGui behavior and touch-target constraints.

### Fixed

- Plugin package now contains the required `Logic` modules.
- Toolbar name, icon, hover description, and dock-widget opening behavior.
- Photoshop bottom-to-top layer order.
- Photoshop group reconstruction.
- RLE-compressed PSD composite decoding.
- Empty unsupported raster layers no longer cover valid UI.

### Changed

- PSDs with Photoshop effects use the exact rendered composite for visual
  fidelity with aligned, transparent Roblox semantic controls for scripting.
- Imports are always created under `StarterGui` as one undoable operation.

### Known limitations

- PSB, CMYK, 16/32-bit PSDs, and ZIP-compressed individual layer pixels are not
  supported.
- Embedded bitmap fills in native `.fig` files are placeholders.
- A flat desktop composition cannot automatically become a purpose-designed
  portrait layout.

[0.3.0-beta.3]: https://github.com/qzhcore/UI-Importer-Pro-/releases/tag/v0.3.0-beta.3
