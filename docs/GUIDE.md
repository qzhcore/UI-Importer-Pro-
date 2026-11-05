# UI Importer Pro User Guide

This guide covers installation, design preparation, importing, testing, and the
handoff to scripting.

For the current branch build, use [these test/install instructions](TEST_BUILD.md).

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

Choose **Editable layers** for working UI or **Reference image** for a static image without controls.

1. Click **Import Design File…**.
2. Choose a supported `.psd` or native `.fig`.
3. Watch progress or click **Cancel import**. Review any warnings in Output.
4. Roblox Studio selects the newly generated root in `StarterGui`.

Create new is the default. To preserve scripted UI while applying source changes,
select an imported root or its child and choose **Update selected import**.

Use **Undo** immediately after an import to remove the complete generated
hierarchy in one operation.

## 6. Understand the hierarchy

A typical import looks like this:

```text
StarterGui
└── MyDesign
    └── Canvas
        ├── Header
        ├── CloseButton
        └── Content
            ├── EquipButton
            └── ItemName
```

Editable imports keep their controls visible and independently editable.
Figma auto-layout children live under an internal `LayoutContent` frame;
absolute-positioned children stay directly under their design parent.
Use recursive lookup or source IDs instead of assuming an exact child path.

Reference imports contain only `RenderedDesign` and its image tiles.

Every generated object has the `UIImporterGenerated` tag. Important attributes
include:

- `UIImporterOriginalName`
- `UIImporterRole`
- `UIImporterSource`
- `UIImporterLayerIndex`
- `UIImporterSourceId` (native source ID where available; otherwise a hierarchy path)
- `UIImporterWarning` (when features are approximated)
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
- warnings for small touch targets, with source dimensions preserved;
- scrolling; and
- SurfaceGui/BillboardGui distance behavior if used.

Also test Play mode. The root is copied from `StarterGui` to each player's
`PlayerGui` when the experience runs.

## 10. Re-import safely

1. Keep a backup of the current UI.
2. Select one imported root or one of its children.
3. Choose **Import: Update selected import** and select the updated source file.
4. Keep the document ID/file name and source layer IDs unchanged.
5. Verify visual changes, retained scripts/attributes, and Undo/Redo in a test place.

Existing instances are never destroyed, renamed, or reparented. Deleted source nodes
remain with warnings; class conflicts and ambiguous IDs reject the update.
See [architecture](ARCHITECTURE.md) for the property allowlist and limitations.

Do not expect manual edits inside `RenderedDesign` or generated artwork tiles to
round-trip back into Photoshop or Figma.

## Image storage

Choose **Images: Session preview** to inspect temporary artwork without uploading.
These images will not survive restarting Studio. Native text and shapes save normally.

For persistent artwork, choose **Images: Upload to Roblox** and either **Experience
creator** or **My account** before importing. The experience-owner option requires a
published place and upload permission for that owner. This feature requires the
locally installed plugin. Each unique image tile is uploaded as an image asset.

Cancellation and Undo cannot remove remote uploads. On failure, Output lists asset
IDs that were already created. Review moderation and experience permissions, then
test save/reopen and a published client before shipping.

See [Artwork Storage](ARTWORK_STORAGE.md) for the supported workflow and limits.

## Document backgrounds

The document backdrop is excluded by default; panel, card, and button backgrounds
remain. Detection is conservative: a root leaf must cover the canvas and have a
recognized background name. Explicit class markers such as `[Frame] Background`
override detection. Toggle **Document background: Included** to retain a backdrop.

Reference mode uses a flattened source image. If a document background is detected,
the plugin requires explicit inclusion instead of silently importing that background.
An arbitrary image's background cannot always be separated from its UI.
