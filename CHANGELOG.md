# Changelog

All notable changes to UI Importer Pro are documented here.

## [Unreleased]

### Added

- Standalone Luau regression coverage for native Kiwi auto-layout fields,
  resize constraints, geometry dispatch, and sizeless group bounds.
- Native Figma linear fill and stroke gradients, independent corner radii,
  drop shadows, text strokes, font family/style/weight mapping, and PNG image
  fills.
- Complex Figma artwork preservation through the `.fig` archive's embedded
  preview, with transparent semantic Roblox layers retained for scripting.
- Hybrid Figma compositing keeps independently supported layers native above
  the preview, while masks, group opacity, instance overrides, and other
  isolated regions remain safely composited.
- Low-resolution Figma previews are upscaled to the design dimensions with a
  bounded sharpening pass before they are embedded.
- Regression coverage for Kiwi visual properties and lossless PNG decoding,
  plus an end-to-end parse check against a real public `.fig` archive.

### Fixed

- Native `.fig` auto-layout and constraint properties now read their actual
  Kiwi wire names instead of Plugin API aliases that decode as `nil`.
- Figma gap and padding values now use fixed offsets, preventing responsive
  scale feedback and preserving the exported pixel spacing.
- Wrapped rows, Space Between distribution, Hug contents, child grow, and
  cross-axis stretch now map to Roblox's current list/flex layout features.
- Top-level groups without an explicit size now contribute descendant bounds
  to the imported canvas dimensions.
- STRETCH constraints preserve negative margins instead of clipping overflow.
- Empty Figma instances are populated from their source component tree when
  the archive contains the referenced component.
- Repeated Kiwi node changes are canonicalized by node ID and removed nodes no
  longer reappear in imported hierarchies.
- Image artwork keeps its decoded pixel dimensions and Figma scale mode instead
  of stretching every fill to the layer bounds.
- Composite mode no longer forces every supported Figma layer to use the
  low-resolution preview.

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
- JPEG/WebP image fills, non-linear gradients, inner shadows, blur, masks, and
  complex vector geometry use the embedded Figma preview when one is present;
  their semantic layers remain native approximations.
- A flat desktop composition cannot automatically become a purpose-designed
  portrait layout.

[0.3.0-beta.3]: https://github.com/qzhcore/UI-Importer-Pro-/releases/tag/v0.3.0-beta.3
