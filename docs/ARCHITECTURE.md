# Import architecture and integration

Version 0.4.0-beta.1 is a local Studio plugin test build. Native geometry and
supported styling are editable. Exact reproduction of every PSD/FIG is not
possible with native Roblox primitives: unsupported artwork requires exported
transparent images. No automatic Photoshop/Figma rendering service is included.

## Modules

| Module | Responsibility |
| --- | --- |
| DesignImporter | File picker, selected import, undo recording, commit/rollback, Output diagnostics |
| DesignSource | Protected JSON decoding and HTTPS API response adapter |
| PsdParser / FigParser | Bounded native file decoding |
| DesignDocument | Common tree, finite geometry, durable IDs, limits and validation |
| BackgroundFilter | Exclude document backdrops without stripping panel fills |
| ResponsiveLayout | Parent-relative Scale geometry, alignment anchors, aspect constraints |
| AutoLayoutMapper | Native list/grid/flex, relative gaps and UIPadding |
| FontMapper / RichTextCompiler | Supported families and escaped styled text runs |
| RenderPolicy | Identify missing artwork and report unsupported behavior |
| AssetUploader | Temporary previews or explicit persistent uploads |
| UIBuilder / ImportIdentity | Detached Roblox tree with stable DesignUID attributes |
| ReimportEngine / VisualProperties | Preflight ID matching and journaled visual-only updates |
| ImportJob / ImportDiagnostics | Cancellation, memory limits, actionable failures |

~~~mermaid
flowchart LR
  Source[PSD / FIG / JSON / API] --> Validate[Normalize and validate]
  Validate --> Filter[Filter document backdrop]
  Filter --> Build[Build detached UI]
  Build --> New[Create new import]
  Build --> Plan[Match DesignUID and preflight]
  Plan --> Update[Apply visual property allowlist]
  Update --> Commit[Commit Studio undo recording]
  Update --> Rollback[Rollback on failure or cancellation]
~~~

## Schema v1

The JSON picker accepts this interchange schema, not arbitrary Figma REST
responses. Convert third-party API nodes into this schema in an adapter first.
API responses passed to DesignSource.fetch must use the same envelope.
See the complete [responsive menu example](../examples/responsive-menu.json).

~~~json
{
  "schemaVersion": 1,
  "documentId": "inventory-v1",
  "width": 1920,
  "height": 1080,
  "tree": [{
    "id": "inventory-title",
    "name": "Title",
    "x": 1440, "y": 108, "width": 384, "height": 108,
    "suggestedRole": "TextLabel",
    "constraints": { "horizontal": "MAX", "vertical": "CENTER" },
    "fontFamily": "Inter",
    "textSize": 32,
    "textRuns": [{ "text": "Your " }, { "text": "Inventory", "bold": true }]
  }]
}
~~~

- IDs are nonempty, unique strings stable across renaming and reordering.
  Keep documentId unchanged for subsequent exports of the same design.
- x/y are parent-local pixels. Alternatively use document-space left/top.
  Do not mix the two forms in a node. Children are ordered back-to-front.
- width/height are design pixels. opacity is 0–255. Colors use
  {r, g, b, a} channels from 0–1; all colors and text remain data.
- Roles: Frame, ScrollingFrame, ImageLabel, ImageButton, TextLabel, TextButton,
  TextBox, ViewportFrame, VideoFrame. Arbitrary Instance classes are rejected.
- Layout: layoutMode HORIZONTAL/VERTICAL/GRID, layoutGap,
  primaryAxisAlignItems/counterAxisAlignItems MIN/CENTER/MAX,
  primary SPACE_BETWEEN, layoutWrap WRAP, layoutGrow,
  layoutAlign STRETCH, layoutPositioning ABSOLUTE.
- Grid: gridCellSize: {width, height}, gridColumns, counterAxisSpacing.
- Insets: paddingLeft, paddingRight, paddingTop, paddingBottom.
  These are content padding, not CSS margins outside an element.
- Shape: backgroundColor, backgroundTransparency, cornerRadius,
  strokeColor, strokeThickness, strokeAlign, and preserveAspectRatio.
  ELLIPSE/AVATAR shapes and square nodes named Icon also receive aspect constraints.
- Text: text or textRuns; each run has text plus optional bold, italic,
  underline, strikethrough, color, fontFamily, fontWeight, textSize.
  Text is escaped before markup compilation. minTextSize defaults to 10;
  maxTextSize defaults to twice the authored size, capped at 100 (72 if absent).
- Artwork: imageAssetId: "rbxassetid://12345" for a cropped transparent PNG.
  complexVector, specularMap, non-linear gradients, or
  requiresRenderedFallback flag an image fallback. Missing IDs produce a
  transparent placeholder and explicit warning, not an invented asset.
- isDocumentBackground: true explicitly marks a backdrop. Otherwise only
  full-canvas, root-level background names are removed by default.

## Responsive contract

All generated GuiObject Size/Position values use zero Offset. Each axis is:

~~~lua
local sizeScale = layerSize / parentSize
local positionScale = (layerNear + layerSize * anchor) / parentSize
~~~

MAX/RIGHT/BOTTOM use anchor 1; CENTER uses 0.5; MIN/LEFT/TOP use 0.
Missing rules infer an anchor from the source placement. A right-pinned node's
right margin stays proportional to its parent. It does not stay a fixed number
of pixels: that would contradict the Scale-only requirement.

List/grid layouts own flow-child positioning. Absolute children and artwork
are kept outside the flow container. Decorative raster children use ZIndex 0;
flow and content use higher sibling order. ScreenGui uses Sibling ordering.
Do not sort by name: LayoutOrder and ZIndex come from source order.

Hug contents retains exported bounds with a warning. AutomaticSize on a parent
whose children are entirely Scale-sized creates a circular sizing dependency.
Independent wrap-line gaps and baseline typography are reported approximations.
Use Preserve aspect for an undistorted canvas; author separate portrait layouts
where needed. A minimum text size improves readability but does not guarantee
all strings fit every tiny container. Verify localization and narrow displays.

Roblox does not expose Enum.Font.Inter or Enum.Font.GothamSSm. Inter maps to
BuilderSans with a substitution warning; Montserrat uses
Font.fromName("Montserrat", weight, style). Exact fonts may need an approved
custom family or rendered text. See [Font](https://create.roblox.com/docs/reference/engine/datatypes/Font),
[font enums](https://create.roblox.com/docs/reference/engine/enums/Font),
[native layouts](https://create.roblox.com/docs/ui/list-flex-layouts), and
[RichText](https://create.roblox.com/docs/ui/rich-text).

## Non-destructive update contract

Choose **Import: Update selected import**, select one imported root or any child,
then select the updated source file. It updates that entire imported root.
New imports remain the default so a selected unrelated GUI is never overwritten.

Every generated object, including layouts and decoration helpers, has a DesignUID.
Re-import indexes IDs once and prepares a property plan before touching the target.
Existing instances are never destroyed, renamed, or reparented. All their
attributes, tags, scripts, configurations, sounds, and event connections remain.
New source IDs add new objects. Source-deleted objects remain with warnings.
Reparented source nodes retain their old parent and geometry with warnings.
Class changes and duplicated IDs reject the update before any mutation.

Only VisualProperties can authorize property writes: geometry, fill, text/image
appearance, visual constraints, and ordering. No Source, Name, Parent, Adornee,
CurrentCamera, custom attributes, or interaction/event properties are copied onto
matched objects. Runtime visual changes on those allowlisted properties are
intentionally replaced by the source design.

Changes are journaled. A cancellation, property failure, or failed Studio commit
restores prior properties and removes only newly created objects. Studio Undo
also covers a successful import/update. Uploaded image assets cannot be undone.
Do not edit the same UI concurrently while an update runs.

PSD uses its lyid layer IDs; FIG uses node GUIDs. Sources with missing or duplicate
durable IDs can create new imports but cannot safely update an existing one.
Older plugin imports lack these tracking IDs and must be imported once with this
version. PSD/FIG file names identify the document; keep the same file name.
JSON uses its explicit documentId. Keep artwork mode unchanged for re-import.

## Calling the pipeline from Luau

Example inside plugin code with these modules under Logic. Conversion stays
detached until the caller owns a Studio undo recording and commits the result.

~~~lua
local ImportJob = require(Logic.ImportJob)
local DesignSource = require(Logic.DesignSource)
local Pipeline = require(Logic.ImportPipeline)
local Diagnostics = require(Logic.ImportDiagnostics)

local job = ImportJob.new({ yieldCallback = task.wait })
local ok, result = pcall(function()
    local document = DesignSource.fromTable(apiPayload, job)
    return Pipeline.fromDocument(document, "Inventory", game.StarterGui, {
        visualMode = "Editable",
        includeBackground = false,
        imageStorage = "Session",
    }, job)
end)
if not ok then
    Diagnostics.report("Design conversion failed", result)
    return
end
-- result.root is detached. Use the transaction pattern in DesignImporter.
~~~

For HTTPS data, call Pipeline.fromApi(url, name, parent, options, job) inside
the same pcall. HTTP requests and JSONDecode are individually protected.
No credentials are embedded or persisted by this adapter. It does not implement
Figma authentication, a Figma OAuth flow, or a remote render service.
