# Scripting Imported UI

Imported UI is normal Roblox UI. The safest scripts target the named semantic
objects and leave generated artwork objects alone.

## Wait for the imported ScreenGui

Put this in a `LocalScript` under `StarterPlayerScripts`:

```luau
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local fishingGui = playerGui:WaitForChild("DGfishingGameFrame5")
local canvas = fishingGui:WaitForChild("Canvas")
```

Replace `DGfishingGameFrame5` with the name of the generated root in Explorer.

## Connect an imported button

Layer names are converted to clean PascalCase names. Button roles receive a
`Button` suffix when needed.

```luau
local equipButton = canvas:FindFirstChild("EquipButton", true)

if equipButton and equipButton:IsA("GuiButton") then
	equipButton.Activated:Connect(function()
		print("Equip selected")
	end)
end
```

Use `Activated` instead of only `MouseButton1Click` so the control works with
mouse, touch, and gamepad activation.

## Find objects by original design-layer name

This is useful when generated names change because of duplicates:

```luau
local function findImportedLayer(root: Instance, originalName: string): Instance?
	for _, descendant in root:GetDescendants() do
		if descendant:GetAttribute("UIImporterOriginalName") == originalName then
			return descendant
		end
	end

	return nil
end

local closeControl = findImportedLayer(canvas, "X_Button")
if closeControl and closeControl:IsA("GuiButton") then
	closeControl.Activated:Connect(function()
		fishingGui.Enabled = false
	end)
end
```

## Discover every imported root

```luau
local CollectionService = game:GetService("CollectionService")

for _, instance in CollectionService:GetTagged("UIImporterGenerated") do
	if instance:IsA("LayerCollector") then
		print(
			instance:GetFullName(),
			instance:GetAttribute("UIImporterSource"),
			instance:GetAttribute("UIImporterResponsiveMode")
		)
	end
end
```

## Handle a TextBox

```luau
local searchBox = canvas:FindFirstChild("Search", true)

if searchBox and searchBox:IsA("TextBox") then
	searchBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			print("Search:", searchBox.Text)
		end
	end)
end
```

Validate user input on the server before using it for gameplay or saved data.

## Add a camera to a ViewportFrame

```luau
local preview = canvas:FindFirstChild("CharacterPreview", true)

if preview and preview:IsA("ViewportFrame") then
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(0, 2, 8)
	camera.Parent = preview
	preview.CurrentCamera = camera

	local model = game:GetService("ReplicatedStorage")
		:WaitForChild("PreviewModel")
		:Clone()
	model.Parent = preview
end
```

Anchor and position the preview model for the camera used by your experience.

## Editable layers and reference images

The default Editable layers mode creates normal visible controls. Changing
Text, Visible, or position affects the corresponding control. Unsupported
artwork is listed in Output and in UIImporterWarning on the affected layer.

Reference image mode creates a static RenderedDesign image with no controls.
Use it as a comparison image, not as an editable menu.

Auto-layout containers have a LayoutContent child holding flow items and the
UIListLayout. Absolute overlays and artwork are outside that flow. Recursive
lookup remains useful. UIImporterSourceId stores native Figma/PSD identifiers
where available; sources without identifiers use a hierarchy path. DesignUID tracks
all generated objects. Use Update selected import for sources with durable IDs:
matched instances, scripts, custom attributes, tags, and names are preserved.
See [the re-import contract](ARCHITECTURE.md#non-destructive-update-contract).

## Recommended project structure

Keep imported UI, controller logic, and server logic separate:

```text
StarterGui
└── DGfishingGameFrame5
    ├── Canvas
    └── UIController.client.lua

ReplicatedStorage
└── Remotes
    └── EquipItem

ServerScriptService
└── EquipmentService.server.lua
```

Never trust a button click as proof that a player owns an item. Send the request
to the server and validate permissions, inventory, prices, and rate limits
there.
