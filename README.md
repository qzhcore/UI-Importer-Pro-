# UI Importer Pro

[![Version](https://img.shields.io/badge/version-0.4.0--beta.1-1687ff)](wally.toml)
[![CI](https://github.com/qzhcore/UI-Importer-Pro-/actions/workflows/ci.yml/badge.svg)](https://github.com/qzhcore/UI-Importer-Pro-/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-f1c40f)](LICENSE)

UI Importer Pro turns layered Photoshop PSD and native Figma `.fig` files into
organized, responsive, script-ready Roblox UI under `StarterGui`.

This is beta software. Keep a copy of the source design and test the generated
UI before shipping it in a live experience.

## Download and install

**Current development build: 0.4.0-beta.1.** Download the committed
[plugin build](dist/UIImporterPro.rbxm) and follow the [test instructions](docs/TEST_BUILD.md).
The older GitHub Latest release is separate from this branch.



1. Download `UIImporterPro.rbxm` from the
   [latest GitHub release](https://github.com/qzhcore/UI-Importer-Pro-/releases/latest).
2. In Roblox Studio, open **Plugins → Plugins Folder**.
3. Move `UIImporterPro.rbxm` into the folder that opens.
4. Restart Studio.
5. Open the **Plugins** tab and click **UI Importer Pro**.

If the toolbar button is missing, see
[Troubleshooting](docs/TROUBLESHOOTING.md#the-toolbar-button-is-missing).

## Import a design

1. Open the plugin.
2. Choose a root class:
   - **ScreenGui** for normal on-screen menus.
   - **SurfaceGui** for UI drawn on a Part.
   - **BillboardGui** for UI that floats in the 3D world.
3. Choose a sizing mode:
   - **Adaptive (all screens)** fills the available screen.
   - **Preserve aspect** keeps the design ratio and may letterbox.
4. Choose **Editable layers** for working controls or **Reference image** for a static visual.
5. Choose **Session preview** for temporary images, or **Upload to Roblox** and an
   asset owner for persistent images. Uploading requires the locally installed plugin.
6. Click **Import Design File** and select a compatible PSD, FIG, or schema-v1 JSON.
7. Inspect the selected generated root under `StarterGui`.
8. Test the result with Studio's Device Emulator before scripting or shipping.

The complete walkthrough is in the [User Guide](docs/GUIDE.md).

## What gets generated

By default, an editable import creates a new, uniquely named `ScreenGui`, `SurfaceGui`, or
`BillboardGui` under `StarterGui`, containing:

- a responsive `Canvas`;
- clean PascalCase instance names;
- Roblox UI classes inferred from design types and layer-name hints;
- source metadata stored as `UIImporter…` attributes;
- the `UIImporterGenerated` tag for discovery;
- image tiles using temporary previews or uploaded Roblox image assets;
- source geometry preserved, with touch-target warnings for small controls; and
- one undoable Studio operation.

**Editable layers** is the default. Text, inputs, and buttons remain visible and
individually editable. Unsupported effects are reported in Output and in the
affected object's `UIImporterWarning` attribute; the plugin does not silently
replace the design with a screenshot.

**Reference image** creates only `Canvas.RenderedDesign`, a static image without
controls. PSD uses its merged image; FIG uses its thumbnail at its original
resolution and aspect ratio. A Figma thumbnail can represent a different region
from the imported page. This mode is intended for comparison, not gameplay UI.

Document backdrops are excluded by default. This filters full-canvas root layers
named Background, Canvas Background, Document Background, or Artboard Background;
panel backgrounds and explicitly tagged UI layers remain. Use **Document background:
Included** when the backdrop is intentional. Flattened reference images cannot
separate a detected backdrop and require explicit inclusion.

Supported Photoshop color overlays and text strokes are now applied. Complex
effects, non-normal blending, and text/font fidelity remain incomplete.

**Update selected import** matches DesignUID attributes and updates visual properties
while preserving existing instances, scripts, names, attributes, and sounds.
Class conflicts or ambiguous IDs reject the update. Deleted source nodes are retained
with warnings. See the [architecture and JSON/API schema](docs/ARCHITECTURE.md).

Imports can be cancelled. The generated tree is attached only on success.

**Image storage matters:** Session preview images are temporary and will not survive
restarting Studio. Upload to Roblox sends image tiles to the selected creator's
account and stores asset references in the UI. Roblox moderation and experience
permissions still apply. Cancel and Undo remove generated UI, but cannot delete
assets already uploaded. Failed or cancelled uploads report retained asset IDs in
Output. This upload API currently supports locally installed plugins; Creator Store
distribution needs a different upload workflow. See [artwork storage](docs/ARTWORK_STORAGE.md).

## Layer naming hints

Use a class hint at the beginning of a PSD or Figma layer name when automatic
inference is not enough:

| Design layer name | Roblox class |
| --- | --- |
| `[ImageButton] Play` or `[Button] Play` | `ImageButton` |
| `[TextButton] Buy` | `TextButton` |
| `[TextLabel] Coins` or `[Text] Coins` | `TextLabel` |
| `[Input] Search` | `TextBox` |
| `[Scroll] Inventory` | `ScrollingFrame` |
| `[ViewportFrame] Character Preview` | `ViewportFrame` |
| `[VideoFrame] Trailer` | `VideoFrame` |
| `[UIListLayout] Items` | `UIListLayout` |
| `[UIGridLayout] Shop` | `UIGridLayout` |
| `[UICorner] Rounded` | `UICorner` |
| `[UIStroke] Border` | `UIStroke` |
| `[UIGradient] Fade` | `UIGradient` |
| `[UIPadding] Insets` | `UIPadding` |

See [Scripting Imported UI](docs/SCRIPTING.md) for safe runtime patterns.

## Compatibility

### PSD

Supported in beta:

- standard `.psd` documents up to Studio's 100 MB file-picker limit;
- RGB color mode;
- 8 bits per channel;
- raw or RLE-compressed layer pixels;
- raster layers, text layers, groups, visibility, opacity, and ordering;
- basic raster layer masks, including offsets, disabled masks, and alpha; and
- optional static reference imports of the merged image.

Not supported yet:

- PSB;
- CMYK;
- 16-bit or 32-bit channels; and
- ZIP-compressed individual layer pixels.

### Native Figma `.fig`

Supported in beta:

- raw or ZIP-wrapped Kiwi scene graphs;
- frames, groups, components, basic shapes, and text;
- solid and linear-gradient fills, gradient strokes, independent corners,
  drop shadows, text strokes, font metadata, and hierarchy;
- lossless PNG image fills and Figma image scale modes (fills over 1024 pixels
  currently use stretched tiles and report a warning);
- component-instance population from source component trees;
- auto-layout direction, proportional gap/padding, wrapping, alignment,
  child grow, and cross-axis stretch; Hug contents keeps exported bounds with a warning;
- MIN/MAX/CENTER alignment anchors with parent-relative Scale geometry; and
- DEFLATE and Zstandard segments.

JPEG/WebP fills, complex vectors, masks, non-linear gradients, and blur can
require separately rendered artwork for exact appearance. Editable mode keeps
supported native properties and reports approximations or missing artwork.
Only the first visible page is currently imported. Native Figma formats can
change; keep the original file.

Import limits: 100 MB source file, 16 megapixels per image, 10,000 generated
layers, 128 levels of nesting, 128 MB expanded archive data, and a conservative
256 MB decoding budget. Large documents may need to be split.

## Responsive behavior

**Adaptive** converts document geometry to scale values and fills the device-safe
screen area. It is useful for full-screen layouts but can stretch a fixed-ratio
composition.

**Preserve aspect** adds a `UIAspectRatioConstraint` to the canvas. It prevents
distortion and is usually the best choice for artwork-heavy menus. Empty space
on screens with a different aspect ratio is expected.

Neither mode can invent a new portrait layout from a flat desktop PSD. Test
phone, tablet, desktop, console, and any supported VR targets in Studio and make
intentional layout changes where necessary.

## Development

```bash
git clone https://github.com/qzhcore/UI-Importer-Pro-.git
cd UI-Importer-Pro-
aftman install
rojo build default.project.json --output UIImporterPro.rbxm
```

Before opening a pull request:

```bash
lune run tests/run.luau
lune run tests/import_pipeline.luau
lune run tests/assets.luau
lune run tests/appearance.luau
lune run tests/architecture.luau
stylua --check src tests
selene src
selene --config tests/selene.toml tests
rojo build default.project.json --output UIImporterPro.rbxm
```

Read [Contributing](CONTRIBUTING.md), [Security](SECURITY.md), and the
[Changelog](CHANGELOG.md) before contributing or reporting a problem.

## Documentation

- [Current test build](docs/TEST_BUILD.md)
- [Architecture and JSON/API examples](docs/ARCHITECTURE.md)
- [User Guide](docs/GUIDE.md)
- [Scripting Imported UI](docs/SCRIPTING.md)
- [Troubleshooting and Limitations](docs/TROUBLESHOOTING.md)
- [Discord Server Blueprint](docs/DISCORD_SETUP.md)
- [Beta Launch Checklist](docs/LAUNCH_CHECKLIST.md)
- [Privacy](PRIVACY.md)
- [Hosted website](https://qzhcore.github.io/UI-Importer-Pro-/)

## License

UI Importer Pro is available under the [MIT License](LICENSE).
