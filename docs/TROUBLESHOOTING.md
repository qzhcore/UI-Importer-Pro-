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

Editable mode imports each layer and reports effects that it cannot render.
Rasterize those effects into the individual decorative layers before importing,
or use Reference image mode to import the static merged image for comparison.
Basic raster masks are supported; parameterized/vector/group masks, clipping
groups, and non-normal blend modes still require preparation in Photoshop.

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

PNG fills are decoded into layer artwork. JPEG/WebP fills, complex vectors,
masks, and some effects remain unsupported or approximate in Editable mode.
Inspect Output and UIImporterWarning attributes.

Reference mode uses the thumbnail stored by Figma, without artificial
sharpening or native overlays. Its region and resolution may differ from the
page you wanted. It cannot replace a full-resolution export of each layer.

## An import exceeds a limit or needs to be cancelled

Use Cancel import to stop between processing chunks. File selection and
individual Studio asset API calls must return before cancellation takes effect.
The tree is attached only after successful generation. Split documents that
exceed the 16-megapixel per-image, 10,000-layer, 128-level, expanded-archive,
or decoded-memory budgets; compressed file size alone does not predict memory.

## Re-import created a duplicate

Create new is the default. Select an import made with this version, then choose
**Update selected import**. Updates require the same document and durable layer IDs.
Class changes, duplicate IDs, and older untracked imports are rejected safely.
Source-deleted nodes are retained with warnings; they are not silently destroyed.

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

## Images disappear after restarting Studio

**Session preview** uses temporary content. Reimport using **Upload to Roblox**
with the locally installed plugin. Inspect the root's `UIImporterImageStorage`
attribute and the image's `UIImporterAssetId` attribute to check the storage path.
Uploaded images may still be unavailable while moderation or experience permissions
are unresolved. See [Artwork Storage](ARTWORK_STORAGE.md).

## Upload rejected or cancelled halfway through

Use the local plugin, select an owner you can upload for, and check Studio Output.
The importer stops on upload failure; it does not replace persistent images with
temporary ones. IDs of images already uploaded are listed in Output. Those assets
remain on Roblox even when the generated UI is rolled back.
