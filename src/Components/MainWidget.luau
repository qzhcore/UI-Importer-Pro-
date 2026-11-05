local MainWidget = {}

local MainButton = require(script.Parent.MainButton)
local ImportJob = require(script.Parent.Parent.Logic.ImportJob)

function MainWidget.new(plugin, onAction)
	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 400, 690, 340, 500)

	local widget = plugin:CreateDockWidgetPluginGuiAsync("UIImporterProWidget", info)
	widget.Title = "UI Importer Pro"

	local container = Instance.new("ScrollingFrame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 = Color3.fromRGB(37, 37, 40)
	container.BorderSizePixel = 0
	container.CanvasSize = UDim2.new()
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ScrollBarThickness = 5
	container.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 16)
	padding.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.LayoutOrder = 1
	heading.Size = UDim2.new(1, 0, 0, 28)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.Text = "UI Importer Pro"
	heading.TextColor3 = Color3.fromRGB(245, 245, 245)
	heading.TextSize = 20
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = container

	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.LayoutOrder = 2
	description.Size = UDim2.new(1, 0, 0, 68)
	description.BackgroundTransparency = 1
	description.Font = Enum.Font.Gotham
	description.Text =
		"Import layered Photoshop or Figma designs as responsive Roblox UI with clean names, hierarchy, and styling."
	description.TextColor3 = Color3.fromRGB(190, 190, 195)
	description.TextSize = 13
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.Parent = container

	local compatibility = Instance.new("TextLabel")
	compatibility.Name = "Compatibility"
	compatibility.LayoutOrder = 3
	compatibility.Size = UDim2.new(1, 0, 0, 42)
	compatibility.BackgroundColor3 = Color3.fromRGB(48, 48, 53)
	compatibility.BorderSizePixel = 0
	compatibility.Font = Enum.Font.Gotham
	compatibility.Text = "PSD (RGB, 8-bit, Raw/RLE) - FIG - JSON schema v1"
	compatibility.TextColor3 = Color3.fromRGB(145, 205, 255)
	compatibility.TextSize = 12
	compatibility.TextWrapped = true
	compatibility.Parent = container

	local compatibilityCorner = Instance.new("UICorner")
	compatibilityCorner.CornerRadius = UDim.new(0, 7)
	compatibilityCorner.Parent = compatibility

	local targetLabel = Instance.new("TextLabel")
	targetLabel.Name = "TargetLabel"
	targetLabel.LayoutOrder = 4
	targetLabel.Size = UDim2.new(1, 0, 0, 18)
	targetLabel.BackgroundTransparency = 1
	targetLabel.Font = Enum.Font.GothamMedium
	targetLabel.Text = "ROOT CLASS - CREATED IN STARTERGUI"
	targetLabel.TextColor3 = Color3.fromRGB(175, 175, 180)
	targetLabel.TextSize = 11
	targetLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetLabel.Parent = container

	local targetSelector = Instance.new("Frame")
	targetSelector.Name = "TargetSelector"
	targetSelector.LayoutOrder = 5
	targetSelector.Size = UDim2.new(1, 0, 0, 36)
	targetSelector.BackgroundTransparency = 1
	targetSelector.Parent = container

	local targetLayout = Instance.new("UIListLayout")
	targetLayout.FillDirection = Enum.FillDirection.Horizontal
	targetLayout.Padding = UDim.new(0, 6)
	targetLayout.SortOrder = Enum.SortOrder.LayoutOrder
	targetLayout.Parent = targetSelector

	local selectedTarget = "ScreenGui"
	local targetButtons = {}
	local busy = false
	local activeJob
	plugin.Unloading:Connect(function()
		if activeJob then
			activeJob:cancel()
		end
	end)

	local function updateTargetButtons()
		for className, targetButton in pairs(targetButtons) do
			local selected = className == selectedTarget
			targetButton.BackgroundColor3 = if selected then Color3.fromRGB(0, 125, 210) else Color3.fromRGB(55, 55, 60)
			targetButton.TextColor3 = if selected then Color3.new(1, 1, 1) else Color3.fromRGB(190, 190, 195)
		end
	end

	local function addTargetButton(className, text, order)
		local targetButton = Instance.new("TextButton")
		targetButton.Name = className .. "Option"
		targetButton.LayoutOrder = order
		targetButton.Size = UDim2.new(1 / 3, -4, 1, 0)
		targetButton.BorderSizePixel = 0
		targetButton.Font = Enum.Font.GothamMedium
		targetButton.Text = text
		targetButton.TextSize = 11
		targetButton.AutoButtonColor = true
		targetButton.MouseButton1Click:Connect(function()
			if not busy then
				selectedTarget = className
				updateTargetButtons()
			end
		end)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = targetButton
		targetButton.Parent = targetSelector
		targetButtons[className] = targetButton
	end

	addTargetButton("ScreenGui", "ScreenGui", 1)
	addTargetButton("SurfaceGui", "SurfaceGui", 2)
	addTargetButton("BillboardGui", "BillboardGui", 3)
	updateTargetButtons()

	local sizingLabel = Instance.new("TextLabel")
	sizingLabel.Name = "SizingLabel"
	sizingLabel.LayoutOrder = 6
	sizingLabel.Size = UDim2.new(1, 0, 0, 18)
	sizingLabel.BackgroundTransparency = 1
	sizingLabel.Font = Enum.Font.GothamMedium
	sizingLabel.Text = "SCREEN SIZING"
	sizingLabel.TextColor3 = Color3.fromRGB(175, 175, 180)
	sizingLabel.TextSize = 11
	sizingLabel.TextXAlignment = Enum.TextXAlignment.Left
	sizingLabel.Parent = container

	local sizingSelector = Instance.new("Frame")
	sizingSelector.Name = "SizingSelector"
	sizingSelector.LayoutOrder = 7
	sizingSelector.Size = UDim2.new(1, 0, 0, 36)
	sizingSelector.BackgroundTransparency = 1
	sizingSelector.Parent = container

	local sizingLayout = Instance.new("UIListLayout")
	sizingLayout.FillDirection = Enum.FillDirection.Horizontal
	sizingLayout.Padding = UDim.new(0, 6)
	sizingLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sizingLayout.Parent = sizingSelector

	local selectedSizing = "Adaptive"
	local sizingButtons = {}

	local function updateSizingButtons()
		for mode, sizingButton in pairs(sizingButtons) do
			local selected = mode == selectedSizing
			sizingButton.BackgroundColor3 = if selected then Color3.fromRGB(0, 125, 210) else Color3.fromRGB(55, 55, 60)
			sizingButton.TextColor3 = if selected then Color3.new(1, 1, 1) else Color3.fromRGB(190, 190, 195)
		end
	end

	local function addSizingButton(mode, text, order)
		local sizingButton = Instance.new("TextButton")
		sizingButton.Name = mode .. "Option"
		sizingButton.LayoutOrder = order
		sizingButton.Size = UDim2.new(0.5, -3, 1, 0)
		sizingButton.BorderSizePixel = 0
		sizingButton.Font = Enum.Font.GothamMedium
		sizingButton.Text = text
		sizingButton.TextSize = 11
		sizingButton.AutoButtonColor = true
		sizingButton.MouseButton1Click:Connect(function()
			if not busy then
				selectedSizing = mode
				updateSizingButtons()
			end
		end)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = sizingButton
		sizingButton.Parent = sizingSelector
		sizingButtons[mode] = sizingButton
	end

	addSizingButton("Adaptive", "Adaptive (all screens)", 1)
	addSizingButton("PreserveAspect", "Preserve aspect", 2)
	updateSizingButtons()

	local visualMode = "Editable"
	local updateMode
	local modeButton = MainButton.new(container, "Artwork: Editable layers", function()
		if not busy then
			visualMode = if visualMode == "Editable" then "Reference" else "Editable"
			updateMode()
		end
	end)
	modeButton.Name = "ArtworkMode"
	modeButton.LayoutOrder = 8
	local modeDescription = Instance.new("TextLabel")
	modeDescription.Name = "ArtworkModeDescription"
	modeDescription.LayoutOrder = 9
	modeDescription.Size = UDim2.new(1, 0, 0, 52)
	modeDescription.BackgroundTransparency = 1
	modeDescription.TextColor3 = Color3.fromRGB(190, 190, 195)
	modeDescription.TextSize = 12
	modeDescription.Font = Enum.Font.Gotham
	modeDescription.TextWrapped = true
	modeDescription.TextXAlignment = Enum.TextXAlignment.Left
	modeDescription.Parent = container
	updateMode = function()
		modeButton.Text = if visualMode == "Editable" then "Artwork: Editable layers" else "Artwork: Reference image"
		modeDescription.Text = if visualMode == "Editable"
			then "Creates editable controls. Unsupported effects are reported in Output and on the affected layers."
			else "Creates a static image without controls. Figma uses its exported thumbnail, which may show another region."
	end
	updateMode()

	local imageStorage = "Session"
	local assetOwner = if game.CreatorId > 0 then "Experience" else "User"
	local updateStorage
	local storageButton = MainButton.new(container, "Images: Session preview", function()
		if not busy then
			imageStorage = if imageStorage == "Session" then "RobloxAsset" else "Session"
			updateStorage()
		end
	end)
	storageButton.Name = "ImageStorage"
	storageButton.LayoutOrder = 10
	local ownerButton = MainButton.new(container, "", function()
		if not busy then
			assetOwner = if assetOwner == "Experience" then "User" else "Experience"
			updateStorage()
		end
	end)
	ownerButton.Name = "ArtworkOwner"
	ownerButton.LayoutOrder = 11
	local storageDescription = Instance.new("TextLabel")
	storageDescription.Name = "ImageStorageDescription"
	storageDescription.LayoutOrder = 12
	storageDescription.Size = UDim2.new(1, 0, 0, 90)
	storageDescription.BackgroundTransparency = 1
	storageDescription.Font = Enum.Font.Gotham
	storageDescription.TextSize = 12
	storageDescription.TextColor3 = Color3.fromRGB(255, 205, 130)
	storageDescription.TextWrapped = true
	storageDescription.TextXAlignment = Enum.TextXAlignment.Left
	storageDescription.Parent = container
	updateStorage = function()
		storageButton.Text = if imageStorage == "Session" then "Images: Session preview" else "Images: Upload to Roblox"
		ownerButton.Visible = imageStorage == "RobloxAsset"
		ownerButton.Text = if assetOwner == "Experience"
			then "Asset owner: Experience creator"
			else "Asset owner: My account"
		storageDescription.Text = if imageStorage == "Session"
			then "Preview artwork is temporary and will not survive restarting Studio. Use Upload to Roblox for persistent images. Native text and shapes are saved normally."
			else "Import uploads image tiles to Roblox under the selected owner. Requires the locally installed plugin. Assets undergo moderation; cancel and undo do not remove uploads."
	end
	updateStorage()
	local includeBackground = false
	local backgroundButton
	backgroundButton = MainButton.new(container, "Document background: Excluded", function()
		if not busy then
			includeBackground = not includeBackground
			backgroundButton.Text = if includeBackground
				then "Document background: Included"
				else "Document background: Excluded"
		end
	end)
	backgroundButton.Name = "IncludeBackground"
	backgroundButton.LayoutOrder = 13
	local reimportSelected = false
	local workflowButton
	workflowButton = MainButton.new(container, "Import: Create new", function()
		if not busy then
			reimportSelected = not reimportSelected
			workflowButton.Text = if reimportSelected then "Import: Update selected import" else "Import: Create new"
		end
	end)
	workflowButton.Name = "ImportWorkflow"
	workflowButton.LayoutOrder = 14

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.LayoutOrder = 18
	status.Size = UDim2.new(1, 0, 0, 58)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "Ready. Imports are built under StarterGui."
	status.TextColor3 = Color3.fromRGB(170, 170, 175)
	status.TextSize = 12
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Parent = container

	local importButton
	local cancelButton = MainButton.new(container, "Cancel import", function()
		if activeJob then
			activeJob:cancel()
			status.Text = "Cancelling import..."
		end
	end)
	cancelButton.Name = "CancelImport"
	cancelButton.LayoutOrder = 17
	cancelButton.Visible = false
	importButton = MainButton.new(container, "Import Design File…", function()
		if busy then
			return
		end

		busy = true
		cancelButton.Visible = true
		importButton.Text = "Importing…"
		importButton.AutoButtonColor = false
		status.Text = "Opening file picker…"
		status.TextColor3 = Color3.fromRGB(145, 205, 255)

		local function onProgress(update)
			if update.message then
				status.Text = update.message
			elseif update.stage == "Embedding" then
				status.Text = string.format("Embedding %s (%d/%d)…", update.layerName, update.current, update.total)
			end
		end
		activeJob = ImportJob.new({
			progressCallback = onProgress,
			yieldCallback = function()
				task.wait()
			end,
		})
		local ok, succeeded, message = pcall(onAction, onProgress, {
			layerCollectorClass = selectedTarget,
			responsiveMode = selectedSizing,
			visualMode = visualMode,
			imageStorage = imageStorage,
			assetOwner = assetOwner,
			includeBackground = includeBackground,
			reimportSelected = reimportSelected,
			job = activeJob,
		})

		busy = false
		activeJob = nil
		cancelButton.Visible = false
		importButton.Text = "Import Design File…"
		importButton.AutoButtonColor = true

		if not ok then
			status.Text = "Import failed: " .. tostring(succeeded)
			status.TextColor3 = Color3.fromRGB(255, 110, 110)
			return
		end

		status.Text = tostring(message)
		status.TextColor3 = if succeeded then Color3.fromRGB(110, 220, 145) else Color3.fromRGB(255, 190, 95)
	end)
	importButton.LayoutOrder = 16

	return widget
end

return MainWidget
