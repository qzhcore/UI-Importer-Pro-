# UI Importer Pro

[![Version](https://img.shields.io/badge/version-0.3.0--beta.3-1687ff)](wally.toml)
[![CI](https://github.com/qzhcore/UI-Importer-Pro-/actions/workflows/ci.yml/badge.svg)](https://github.com/qzhcore/UI-Importer-Pro-/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-f1c40f)](LICENSE)

UI Importer Pro turns layered Photoshop PSD and native Figma `.fig` files into
organized, responsive, script-ready Roblox UI under `StarterGui`.

This is beta software. Keep a copy of the source design and test the generated
UI before shipping it in a live experience.

## Download and install

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
4. Click **Import Design File…** and select a compatible PSD or `.fig`.
5. Inspect the selected generated root under `StarterGui`.
6. Test the result with Studio's Device Emulator before scripting or shipping.

The complete walkthrough is in the [User Guide](docs/GUIDE.md).

## What gets generated

Every import creates a new, uniquely named `ScreenGui`, `SurfaceGui`, or
`BillboardGui` under `StarterGui`, containing:

- a responsive `Canvas`;
- clean PascalCase instance names;
- Roblox UI classes inferred from design types and layer-name hints;
- source metadata stored as `UIImporter…` attributes;
- the `UIImporterGenerated` tag for discovery;
- embedded DataModel-scoped artwork tiles;
- touch-safe constraints for interactive controls; and
- one undoable Studio operation.

When a PSD uses Photoshop-only effects, the importer preserves its exact
appearance in `Canvas.RenderedDesign` and places transparent, named Roblox
objects over it for scripting and interaction. Script the semantic controls;
do not delete `RenderedDesign` unless you intentionally want to remove the
preserved Photoshop appearance.

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
- raster layers, text layers, groups, visibility, opacity, and ordering; and
- Photoshop-effect preservation through the rendered composite.

Not supported yet:

- PSB;
- CMYK;
- 16-bit or 32-bit channels; and
- ZIP-compressed individual layer pixels.

### Native Figma `.fig`

Supported in beta:

- raw or ZIP-wrapped Kiwi scene graphs;
- frames, groups, components, vectors, shapes, and text;
- solid fills, corners, strokes, and hierarchy; and
- DEFLATE and Zstandard segments.

Embedded bitmap fills currently create a placeholder and warning. Figma's
native `.fig` format is proprietary and can change, so keep the original file.

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
stylua --check src
selene src
rojo build default.project.json --output UIImporterPro.rbxm
```

Read [Contributing](CONTRIBUTING.md), [Security](SECURITY.md), and the
[Changelog](CHANGELOG.md) before contributing or reporting a problem.

## Documentation

- [User Guide](docs/GUIDE.md)
- [Scripting Imported UI](docs/SCRIPTING.md)
- [Troubleshooting and Limitations](docs/TROUBLESHOOTING.md)
- [Discord Server Blueprint](docs/DISCORD_SETUP.md)
- [Beta Launch Checklist](docs/LAUNCH_CHECKLIST.md)
- [Privacy](PRIVACY.md)
- [Hosted website](https://qzhcore.github.io/UI-Importer-Pro-/)

## License

UI Importer Pro is available under the [MIT License](LICENSE).
