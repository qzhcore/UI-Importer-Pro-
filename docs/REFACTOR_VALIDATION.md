# Import pipeline refactor validation

Branch: `refactor/studio-import-pipeline`. This is a development build, not a
production-readiness certification.

## Implemented

- Separate file acquisition and undo ownership from parsing, document validation,
  artwork storage, and Roblox instance generation.
- Build detached trees, cancel failed imports, and release files and EditableImages.
- Keep editable controls visible; offer a separate static reference mode.
- Add source IDs, geometry validation, decoder budgets, nesting limits, progress,
  and cooperative cancellation.
- Apply basic PSD raster masks; keep absolute Figma children outside auto-layout.
- Use compact PNG and DEFLATE buffers and avoid unnecessary composite decoding.
- Separate temporary images from explicit persistent uploads, including owner
  selection, asset attributes, and receipts for partial uploads.

## Automated checks

Run from the repository root with the versions pinned in `aftman.toml`:

```sh
lune run tests/run.luau
lune run tests/import_pipeline.luau
lune run tests/assets.luau
lune run tests/appearance.luau
lune run tests/architecture.luau
stylua --check src tests
selene src
selene --config tests/selene.toml tests
rojo build default.project.json --output UIImporterPro-refactor.rbxm
```

The suites cover 26 existing decoder/layout cases, 23 parser/pipeline cases, and 7
artwork lifecycle cases, plus 7 appearance and 12 architecture cases (75 total). Full synthetic FIG and PSD documents pass
through production parsers and detached instance generation. Upload tests use a
mock AssetService and do not create remote assets.

## Native Studio smoke check

```sh
lune run tests/bundle_studio_smoke.luau
```

Run the generated `work/studio-smoke.luau` in Studio Edit mode. Five cases check
ScreenGui, SurfaceGui, BillboardGui, wrapping auto-layout with absolute children,
and real temporary image creation/readback. The check uses detached objects,
destroys them afterward, and never uploads assets or changes place content.

These five native cases passed again on 2026-11-04 in the separate UIImporter-Test.rbxl session.
The architecture runtime check also preserved a script, attribute, instance identity,
and a live Text property signal connection. Padded layout measurements at widths
400/800 produced child widths 100/200, gaps 20/40, left insets 40/80, and badge
right margins 20/40. All temporary test objects were cleaned up.
They do not exercise the file-picker UI, persistent uploads, or screenshot fidelity.

## Remaining release checks

- Real design fixtures from Photoshop and Figma: visual comparison across nested
  groups, rotation, text/font substitutions, masks, and images.
- Local plugin file picker, cancel controls, one-step Undo/Redo, and plugin unload.
- Actual image uploads under a user and group; moderation and permission failures;
  save/reopen and published-client persistence.
- Supported image-upload workflow for Creator Store distribution. Roblox's current
  direct upload API is limited to locally loaded plugins.
- Frame/page selection and preview before import remain future work.
- Re-import is implemented and regression-tested, including native instance/connection
  preservation. Complete the interactive picker and Undo/Redo acceptance checklist.
- Exact rendering for unsupported PSD effects/blends and complex Figma artwork,
  JPEG/WebP fills, and large non-stretch image fills remains incomplete and is
  reported as warnings.

## Real-file findings

A private local PSD (60 layers) and FIG (440 layers) completed native conversion,
but visual comparison exposed major fidelity gaps. A successful conversion is not
a visual acceptance test. A separate unpublished test place is used for comparisons.

The follow-up fixes add default document-backdrop exclusion, preserve text-based
buttons and their dimensions, and read supported PSD color overlays/text strokes.
Complex Photoshop effects and exact font reproduction remain release blockers.
Private source designs and generated test places are kept in ignored local work files.

## Architecture build

See [architecture](ARCHITECTURE.md) and [test steps](TEST_BUILD.md).
The new regression suite covers proportional nested anchors across mobile/1080p/4K,
list/grid/flex/padding, RichText escaping, transparent-image requirements, protected
JSON/HTTP boundaries, ID/class/document conflicts, developer data preservation,
source removals/reparenting, cancellation rollback, and commit-failure rollback.
