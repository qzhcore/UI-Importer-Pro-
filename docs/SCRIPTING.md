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

## `RenderedDesign` and semantic overlays

For PSDs with Photoshop effects:

- `RenderedDesign` is the exact visual layer.
- Named `TextButton`, `ImageButton`, `TextBox`, and other imported objects are
  aligned semantic overlays.
- Overlays may be visually transparent by design.
- Script the overlays and keep `RenderedDesign` visible.

If a control cannot be clicked, check that no unrelated `GuiObject` with
`Active = true` is covering it and that its `Visible` property is enabled.

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
