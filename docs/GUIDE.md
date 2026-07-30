# UI Importer Pro User Guide

This guide covers installation, design preparation, importing, testing, and the
handoff to scripting.

## 1. Install the plugin

1. Download `UIImporterPro.rbxm` from the
   [latest release](https://github.com/qzhcore/UI-Importer-Pro-/releases/latest).
2. In Roblox Studio, open **Plugins → Plugins Folder**.
3. Move the downloaded `.rbxm` into that folder.
4. Restart Studio.
5. Open **Plugins** and click **UI Importer Pro**.

The toolbar button uses the name **UI Importer Pro** and opens a dockable widget.

## 2. Prepare the design

Good layer names produce a better Roblox hierarchy.

- Give important controls short, unique names such as `Close`, `Equip`, or
  `Search`.
- Keep related layers inside named groups.
- Add an explicit class hint when the intended Roblox class is important:
  `[TextButton] Buy`, `[Input] Search`, or `[Scroll] Inventory`.
- Rasterize critical Photoshop effects if each visual layer must remain
  independently editable after import.
- Keep a backup of the original PSD or `.fig`.

For PSD, use RGB color mode and 8 bits per channel. Save as a standard `.psd`,
not a PSB.

## 3. Choose the root class

### ScreenGui

Choose `ScreenGui` for menus, HUDs, inventories, shops, and other 2D interface
shown on the player's display. This is the normal choice.

### SurfaceGui

Choose `SurfaceGui` for a screen or panel attached to a Part. After import:

1. Select the generated `SurfaceGui`.
2. Set its `Adornee` to the target Part.
3. Set `Face`, `PixelsPerStud`, and sizing properties for the experience.

### BillboardGui

Choose `BillboardGui` for a floating label or control in the 3D world. After
import:

1. Select the generated `BillboardGui`.
2. Set its `Adornee` to a Part or Attachment.
3. Adjust `StudsOffset`, `AlwaysOnTop`, and distance behavior.

All three root classes are created under `StarterGui`.

## 4. Choose screen sizing

### Adaptive (all screens)

The canvas fills the device-safe screen area and uses scale-based geometry.
Choose it for layouts designed to stretch or occupy the whole screen.

### Preserve aspect

The canvas keeps the source design's aspect ratio. Choose it for artwork-heavy
menus where stretching would look wrong. Letterboxing on a different display
shape is expected.

Responsive does not mean the importer can invent a separate mobile composition.
A wide desktop PSD may still need a redesigned portrait layout.

## 5. Import

1. Click **Import Design File…**.
2. Choose a supported `.psd` or native `.fig`.
3. Wait for the status message to turn green.
4. Roblox Studio selects the newly generated root in `StarterGui`.

An import creates a new root; it does not merge with an older import. If you
import the same file again, compare the new version first, then delete the old
root when you are satisfied.

Use **Undo** immediately after an import to remove the complete generated
hierarchy in one operation.

## 6. Understand the hierarchy

A typical import looks like this:

```text
StarterGui
└── MyDesign
    └── Canvas
        ├── RenderedDesign
        ├── Header
        ├── CloseButton
        └── Content
            ├── EquipButton
            └── ItemName
```

`RenderedDesign` appears when Photoshop effects are preserved through the
document composite. It supplies the exact visual appearance. The named objects
aligned over it are the semantic Roblox controls used for scripts.

Every generated object has the `UIImporterGenerated` tag. Important attributes
include:

- `UIImporterOriginalName`
- `UIImporterRole`
- `UIImporterSource`
- `UIImporterLayerIndex`
- `UIImporterBlendMode`
- `UIImporterVisualSource`

The generated root also records source canvas width, height, responsive mode,
and visual mode.

## 7. Complete objects that need runtime content

- A `ViewportFrame` needs a `Camera` and cloned 3D content.
- A `VideoFrame` needs a Roblox video asset assigned to `Video`.
- A `SurfaceGui` or `BillboardGui` needs an `Adornee`.
- A `ScrollingFrame` may need runtime content and canvas tuning.
- Buttons need `Activated` handlers.
- A `TextBox` needs validation and submit behavior.

The importer adds a `UIImporterSetupRequired` attribute where an object needs
manual setup.

## 8. Script the controls

Place a `LocalScript` in the generated `ScreenGui` or in
`StarterPlayerScripts`. Use `WaitForChild` for the root and prefer `Activated`
for mouse, touch, and gamepad support.

See [Scripting Imported UI](SCRIPTING.md) for copy-ready patterns.

## 9. Test before shipping

Use Studio's Device Emulator and verify:

- phone portrait and landscape;
- tablet;
- desktop at multiple window sizes;
- console/gamepad selection;
- safe-area insets;
- text wrapping and localization;
- minimum touch target size;
- scrolling; and
- SurfaceGui/BillboardGui distance behavior if used.

Also test Play mode. The root is copied from `StarterGui` to each player's
`PlayerGui` when the experience runs.

## 10. Re-import safely

Treat the source design as the visual source of truth and keep gameplay logic in
separate scripts.

1. Rename or duplicate the current generated root as a backup.
2. Import the updated design.
3. Move or reconnect scripts to the new semantic controls.
4. Re-test all target devices.
5. Delete the old root only after verification.

Do not expect manual edits inside `RenderedDesign` or generated artwork tiles to
round-trip back into Photoshop or Figma.
