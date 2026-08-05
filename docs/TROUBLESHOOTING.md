# Troubleshooting and Limitations

## The toolbar button is missing

1. Confirm the file is named `UIImporterPro.rbxm` and is inside the folder
   opened by **Plugins → Plugins Folder**.
2. Remove older duplicate copies such as `UIImporterPro (1).rbxm`.
3. Restart Roblox Studio.
4. Check the Output window for the first plugin error.

The toolbar button should say **UI Importer Pro** and use the configured plugin
icon.

## `Logic is not a valid member of Plugin`

This means the `.rbxm` was built with an incomplete hierarchy. Install the
release build, which contains the `Logic` modules inside the plugin model. Do
not copy only `init.server.luau` into the Plugins folder.

## Clicking the toolbar button does nothing

- Open **View → Output** and check for the first error.
- Make sure only one current copy of UI Importer Pro is installed.
- Restart Studio after replacing the file.
- Re-download the release if the local file is unusually small or corrupted.

## The PSD is rejected

Verify that it is:

- a standard `.psd`, not a `.psb`;
- RGB color mode;
- 8 bits per channel; and
- no larger than Studio's 100 MB local-file limit.

CMYK, 16/32-bit documents, PSB, and ZIP-compressed individual layer pixels are
not supported in this beta.

## The import is blank or gray

- Confirm the import completed with a green status message.
- Expand the generated root and `Canvas` in Explorer.
- Check that `Canvas.RenderedDesign` is visible when it exists.
- Make sure no old full-screen Frame from another GUI is covering the import.
- Test the generated `ScreenGui` in Play mode under `PlayerGui`.

## Photoshop effects look different

When effects are detected, UI Importer Pro preserves the rendered PSD
composition in `RenderedDesign`. Keep that object visible. Roblox-native
strokes, gradients, and shadows cannot recreate every Photoshop effect exactly.

The semantic overlay objects are designed for scripting and may be transparent.
Changing one overlay does not automatically repaint the composite artwork.

## The design stretches

Re-import with **Preserve aspect**. Adaptive mode fills the screen and can
stretch a fixed-ratio design.

Preserve-aspect mode can create empty space on devices with a different aspect
ratio. That is expected and prevents distortion.

## The design is too small on a phone

A wide desktop composition cannot automatically become a good portrait design.
Create a mobile composition, split the UI into responsive groups, or adjust the
generated constraints after import. Test with Studio's Device Emulator.

## A SurfaceGui or BillboardGui is invisible

Set the generated root's `Adornee`.

- `SurfaceGui`: assign a BasePart and choose the correct `Face`.
- `BillboardGui`: assign a BasePart or Attachment and adjust `StudsOffset`.

The root includes a `UIImporterSetupRequired` attribute describing this step.

## A ViewportFrame or VideoFrame is empty

These classes need Roblox content after import:

- `ViewportFrame`: add a `Camera` and 3D instances.
- `VideoFrame`: assign an uploaded Roblox video asset.

## A Figma image or effect looks soft

Lossless PNG fills are decoded into native artwork. JPEG/WebP fills, complex
vectors, masks, non-linear gradients, inner shadows, and blur use the embedded
Figma preview when the `.fig` archive includes one. Keep `RenderedDesign`
visible; the transparent objects above it are semantic controls for scripting.

The preview resolution is chosen by the exporting application, so a large
design can still look softer than the source. The importer upscales and
sharpens that preview and keeps supported independent layers native, but it
cannot recreate detail that was never stored in the archive. Re-export the
`.fig` after opening the correct page and zooming to the intended composition.
If the archive has no preview, unsupported visuals fall back to native
approximations and the plugin reports a warning.

## Re-import created a duplicate

That is intentional. Imports do not overwrite or merge with existing UI.
Compare the new root, reconnect scripts, and then delete the old root. Use Undo
immediately after import to remove the new hierarchy as one operation.

## Reporting a bug

Open a
[bug report](https://github.com/qzhcore/UI-Importer-Pro-/issues/new?template=bug_report.yml)
and include:

- UI Importer Pro version;
- Roblox Studio version and operating system;
- PSD or `.fig` document properties;
- selected root class and sizing mode;
- exact Output errors; and
- a minimal file that reproduces the problem, if it is safe to share.

Do not publicly attach confidential client artwork. Replace it with a minimal
test file or contact the maintainers privately.
