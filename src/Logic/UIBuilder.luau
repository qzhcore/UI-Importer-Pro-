local AssetUploader = require(script.Parent.AssetUploader)

local UIBuilder = {}

local ROLE_ALIASES = {
	["frame"] = "Frame",
	["scroll"] = "ScrollingFrame",
	["scrollingframe"] = "ScrollingFrame",
	["viewport"] = "ViewportFrame",
	["viewportframe"] = "ViewportFrame",
	["text"] = "TextLabel",
	["textlabel"] = "TextLabel",
	["image"] = "ImageLabel",
	["imagelabel"] = "ImageLabel",
	["video"] = "VideoFrame",
	["videoframe"] = "VideoFrame",
	["textbutton"] = "TextButton",
	["button"] = "ImageButton",
	["imagebutton"] = "ImageButton",
	["input"] = "TextBox",
	["textbox"] = "TextBox",
	["list"] = "UIListLayout",
	["listlayout"] = "UIListLayout",
	["uilistlayout"] = "UIListLayout",
	["grid"] = "UIGridLayout",
	["gridlayout"] = "UIGridLayout",
	["uigridlayout"] = "UIGridLayout",
	["page"] = "UIPageLayout",
	["pagelayout"] = "UIPageLayout",
	["uipagelayout"] = "UIPageLayout",
	["table"] = "UITableLayout",
	["tablelayout"] = "UITableLayout",
	["uitablelayout"] = "UITableLayout",
	["aspect"] = "UIAspectRatioConstraint",
	["aspectratio"] = "UIAspectRatioConstraint",
	["uiaspectratioconstraint"] = "UIAspectRatioConstraint",
	["sizeconstraint"] = "UISizeConstraint",
	["uisizeconstraint"] = "UISizeConstraint",
	["textsizeconstraint"] = "UITextSizeConstraint",
	["uitextsizeconstraint"] = "UITextSizeConstraint",
	["corner"] = "UICorner",
	["uicorner"] = "UICorner",
	["stroke"] = "UIStroke",
	["uistroke"] = "UIStroke",
	["gradient"] = "UIGradient",
	["uigradient"] = "UIGradient",
	["padding"] = "UIPadding",
	["uipadding"] = "UIPadding",
	["scale"] = "UIScale",
	["uiscale"] = "UIScale",
	["uiscaling"] = "UIScale",
}

local MODIFIER_ROLES = {
	UIListLayout = true,
	UIGridLayout = true,
	UIPageLayout = true,
	UITableLayout = true,
	UIAspectRatioConstraint = true,
	UISizeConstraint = true,
	UITextSizeConstraint = true,
	UICorner = true,
	UIStroke = true,
	UIGradient = true,
	UIPadding = true,
	UIScale = true,
}

local function containsWord(value, word)
	return string.find(string.lower(value), "%f[%a]" .. word .. "%f[%A]") ~= nil
end

local function getExplicitRole(name)
	local marker = string.match(name, "^%s*%[([^%]]+)%]")
	if not marker then
		return nil
	end

	local normalized = string.lower(string.gsub(marker, "[^%w]", ""))
	return ROLE_ALIASES[normalized]
end

local function stripRoleMarkers(name)
	local stripped = string.gsub(name, "^%s*%b[]%s*", "")
	stripped = string.gsub(stripped, "^%s*[Bb]utton%s*:%s*", "")
	stripped = string.gsub(stripped, "^%s*[Tt]ext%s*:%s*", "")
	stripped = string.gsub(stripped, "^%s*[Ii]mage%s*:%s*", "")
	stripped = string.gsub(stripped, "^%s*[Ff]rame%s*:%s*", "")
	stripped = string.gsub(stripped, "^%s*[Pp]anel%s*:%s*", "")
	return stripped
end

local function toInstanceName(sourceName, fallback)
	local source = stripRoleMarkers(sourceName)
	local words = {}

	for word in string.gmatch(source, "[%w]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end

	local name = table.concat(words)
	if name == "" then
		name = fallback
	end

	if string.match(name, "^%d") then
		name = "_" .. name
	end

	return name
end

local function uniqueName(parent, preferredName)
	local candidate = preferredName
	local suffix = 2

	while parent:FindFirstChild(candidate) do
		candidate = preferredName .. tostring(suffix)
		suffix += 1
	end

	return candidate
end

local function getLayerRole(layer)
	local name = string.lower(layer.name)
	local explicitRole = getExplicitRole(layer.name)
	if explicitRole then
		return explicitRole
	end

	if layer.suggestedRole then
		return layer.suggestedRole
	end

	if layer.sectionType == 1 or layer.sectionType == 2 then
		return "Frame"
	end

	if containsWord(name, "scrollingframe") or containsWord(name, "scroll") then
		return "ScrollingFrame"
	end

	if containsWord(name, "viewportframe") or containsWord(name, "viewport") then
		return "ViewportFrame"
	end

	if containsWord(name, "videoframe") or containsWord(name, "video") then
		return "VideoFrame"
	end

	if containsWord(name, "textbox") or containsWord(name, "input") then
		return "TextBox"
	end

	if containsWord(name, "textbutton") then
		return "TextButton"
	end

	if containsWord(name, "imagebutton") or containsWord(name, "button") then
		return "ImageButton"
	end

	if layer.text then
		return "TextLabel"
	end

	if containsWord(name, "text") or string.match(name, "^%s*%[text%]") then
		return "TextLabel"
	end

	if containsWord(name, "frame") or containsWord(name, "panel") or containsWord(name, "container") then
		return "Frame"
	end

	return "ImageLabel"
end

local function getBounds(layer, fallback)
	if layer.width > 0 and layer.height > 0 then
		return {
			left = layer.left,
			top = layer.top,
			width = layer.width,
			height = layer.height,
		}
	end

	if layer.children and #layer.children > 0 then
		local minimumX = math.huge
		local minimumY = math.huge
		local maximumX = -math.huge
		local maximumY = -math.huge

		for _, child in ipairs(layer.children) do
			local childBounds = getBounds(child, fallback)
			minimumX = math.min(minimumX, childBounds.left)
			minimumY = math.min(minimumY, childBounds.top)
			maximumX = math.max(maximumX, childBounds.left + childBounds.width)
			maximumY = math.max(maximumY, childBounds.top + childBounds.height)
		end

		if minimumX < math.huge and maximumX > minimumX and maximumY > minimumY then
			return {
				left = minimumX,
				top = minimumY,
				width = maximumX - minimumX,
				height = maximumY - minimumY,
			}
		end
	end

	return fallback
end

local function inferAnchor(positionScale, sizeScale)
	local center = positionScale + (sizeScale * 0.5)
	if center < 0.34 then
		return 0
	elseif center > 0.66 then
		return 1
	end

	return 0.5
end

local function applyGeometry(instance, bounds, parentBounds)
	local parentWidth = math.max(1, parentBounds.width)
	local parentHeight = math.max(1, parentBounds.height)
	local xScale = (bounds.left - parentBounds.left) / parentWidth
	local yScale = (bounds.top - parentBounds.top) / parentHeight
	local widthScale = bounds.width / parentWidth
	local heightScale = bounds.height / parentHeight
	local anchorX = inferAnchor(xScale, widthScale)
	local anchorY = inferAnchor(yScale, heightScale)

	instance.AnchorPoint = Vector2.new(anchorX, anchorY)
	instance.Position = UDim2.fromScale(xScale + (widthScale * anchorX), yScale + (heightScale * anchorY))
	instance.Size = UDim2.fromScale(widthScale, heightScale)
end

local function styleTextObject(instance, layer)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.Font = Enum.Font.Gotham
	instance.Text = layer.text or stripRoleMarkers(layer.name)
	instance.TextColor3 = if layer.backgroundColor
		then Color3.new(layer.backgroundColor.r, layer.backgroundColor.g, layer.backgroundColor.b)
		else Color3.new(1, 1, 1)
	instance.TextScaled = true
	instance.TextTransparency = 1 - (layer.opacity / 255)
	instance.TextWrapped = true
	instance.TextXAlignment = Enum.TextXAlignment.Left
	instance.TextYAlignment = Enum.TextYAlignment.Center

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.Name = "ResponsiveTextSize"
	sizeConstraint.MinTextSize = 1
	sizeConstraint.MaxTextSize = if layer.textSize then math.clamp(math.floor(layer.textSize * 1.5), 8, 100) else 72
	sizeConstraint.Parent = instance
end

local function styleContainer(instance, layer)
	if layer and layer.backgroundColor then
		instance.BackgroundColor3 =
			Color3.new(layer.backgroundColor.r, layer.backgroundColor.g, layer.backgroundColor.b)
		instance.BackgroundTransparency = math.clamp(layer.backgroundTransparency or 0, 0, 1)
	else
		instance.BackgroundTransparency = 1
	end
	instance.BorderSizePixel = 0
	instance.ClipsDescendants = false
end

local function addImageTiles(instance, layer, tiles, hideOriginalArtwork)
	if not tiles or #tiles == 0 then
		return
	end

	local supportsImage = instance:IsA("ImageLabel") or instance:IsA("ImageButton")
	if supportsImage and #tiles == 1 then
		instance.ImageContent = tiles[1].content
		instance.ImageTransparency = 1 - (layer.opacity / 255)
		instance.ScaleType = Enum.ScaleType.Stretch
		return
	end

	for index, tile in ipairs(tiles) do
		local image = Instance.new("ImageLabel")
		image.Name = if #tiles == 1 then "OriginalArtwork" else string.format("ArtworkTile%02d", index)
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.ImageContent = tile.content
		image.ImageTransparency = 1 - (layer.opacity / 255)
		image.Position = UDim2.fromScale(tile.x / layer.width, tile.y / layer.height)
		image.Size = UDim2.fromScale(tile.width / layer.width, tile.height / layer.height)
		image.ScaleType = Enum.ScaleType.Stretch
		image.Visible = not hideOriginalArtwork
		image.ZIndex = instance.ZIndex
		image:SetAttribute("UIImporterArtwork", true)
		image.Parent = instance
	end
end

local function configureLayerInstance(instance, role, layer)
	if role == "TextLabel" or role == "TextButton" or role == "TextBox" then
		styleTextObject(instance, layer)
	elseif role == "ScrollingFrame" then
		styleContainer(instance, layer)
		instance.AutomaticCanvasSize = Enum.AutomaticSize.XY
		instance.CanvasSize = UDim2.new()
		instance.ScrollBarThickness = 6
	elseif role == "Frame" then
		styleContainer(instance, layer)
	elseif role == "ViewportFrame" then
		styleContainer(instance, layer)
		instance.Ambient = Color3.fromRGB(200, 200, 200)
		instance.LightColor = Color3.new(1, 1, 1)
		instance:SetAttribute("UIImporterSetupRequired", "Add a Camera and 3D content to this ViewportFrame.")
	elseif role == "VideoFrame" then
		styleContainer(instance, layer)
		instance.Looped = false
		instance:SetAttribute("UIImporterSetupRequired", "Set Video to a Roblox video asset ID.")
	else
		if layer.backgroundColor then
			instance.BackgroundColor3 =
				Color3.new(layer.backgroundColor.r, layer.backgroundColor.g, layer.backgroundColor.b)
			instance.BackgroundTransparency = math.clamp(layer.backgroundTransparency or 0, 0, 1)
		else
			instance.BackgroundTransparency = 1
		end
		instance.BorderSizePixel = 0
		instance.ImageTransparency = 1
		instance.ScaleType = Enum.ScaleType.Stretch
		if instance:IsA("ImageButton") then
			instance.AutoButtonColor = false
		end
	end

	if instance:IsA("TextButton") or instance:IsA("ImageButton") or instance:IsA("TextBox") then
		local touchConstraint = Instance.new("UISizeConstraint")
		touchConstraint.Name = "ResponsiveTouchTarget"
		touchConstraint.MinSize = Vector2.new(44, 44)
		touchConstraint.MaxSize = Vector2.new(100000, 100000)
		touchConstraint:SetAttribute("UIImporterGenerated", true)
		touchConstraint.Parent = instance
	end
end

local function addImportedStyles(instance, layer, bounds)
	local minimumDimension = math.max(1, math.min(bounds.width, bounds.height))

	if layer.cornerRadius and layer.cornerRadius > 0 then
		local corner = Instance.new("UICorner")
		corner.Name = "ImportedCorner"
		corner.CornerRadius = UDim.new(math.clamp(layer.cornerRadius / minimumDimension, 0, 0.5), 0)
		corner:SetAttribute("UIImporterGenerated", true)
		corner.Parent = instance
	end

	if layer.strokeColor and layer.strokeThickness and layer.strokeThickness > 0 then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "ImportedStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.new(layer.strokeColor.r, layer.strokeColor.g, layer.strokeColor.b)
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		stroke.Thickness = layer.strokeThickness / minimumDimension
		stroke.Transparency = 1 - (layer.strokeColor.a or 1)
		stroke:SetAttribute("UIImporterGenerated", true)
		stroke.Parent = instance
	end

	if layer.layoutMode == "HORIZONTAL" or layer.layoutMode == "VERTICAL" then
		local layout = Instance.new("UIListLayout")
		layout.Name = "ImportedAutoLayout"
		layout.FillDirection = if layer.layoutMode == "HORIZONTAL"
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		local layoutReference = if layer.layoutMode == "HORIZONTAL"
			then math.max(1, bounds.width)
			else math.max(1, bounds.height)
		layout.Padding = UDim.new((layer.layoutGap or 0) / layoutReference, 0)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout:SetAttribute("UIImporterGenerated", true)
		layout.Parent = instance
	end

	if layer.paddingLeft or layer.paddingRight or layer.paddingTop or layer.paddingBottom then
		local padding = Instance.new("UIPadding")
		padding.Name = "ImportedPadding"
		padding.PaddingLeft = UDim.new((layer.paddingLeft or 0) / math.max(1, bounds.width), 0)
		padding.PaddingRight = UDim.new((layer.paddingRight or 0) / math.max(1, bounds.width), 0)
		padding.PaddingTop = UDim.new((layer.paddingTop or 0) / math.max(1, bounds.height), 0)
		padding.PaddingBottom = UDim.new((layer.paddingBottom or 0) / math.max(1, bounds.height), 0)
		padding:SetAttribute("UIImporterGenerated", true)
		padding.Parent = instance
	end
end

local function configureModifier(instance, role, layer, bounds)
	if role == "UIListLayout" then
		instance.FillDirection = if containsWord(layer.name, "horizontal")
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		instance.Padding = UDim.new(0, 8)
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UIGridLayout" then
		instance.CellPadding = UDim2.fromOffset(8, 8)
		instance.CellSize = UDim2.fromOffset(math.max(1, bounds.width), math.max(1, bounds.height))
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UIPageLayout" then
		instance.Padding = UDim.new(0, 12)
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UITableLayout" then
		instance.Padding = UDim2.fromOffset(8, 8)
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UIAspectRatioConstraint" then
		instance.AspectRatio = math.max(0.01, bounds.width / math.max(1, bounds.height))
		instance.AspectType = Enum.AspectType.FitWithinMaxSize
	elseif role == "UISizeConstraint" then
		instance.MinSize = Vector2.zero
		instance.MaxSize = Vector2.new(math.max(1, bounds.width), math.max(1, bounds.height))
	elseif role == "UITextSizeConstraint" then
		instance.MinTextSize = 1
		instance.MaxTextSize = math.max(8, math.min(100, bounds.height))
	elseif role == "UICorner" then
		instance.CornerRadius = UDim.new(0.08, 0)
	elseif role == "UIStroke" then
		instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		instance.Color = Color3.new(1, 1, 1)
		instance.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		instance.Thickness = 0.01
	elseif role == "UIGradient" then
		instance.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180))
	elseif role == "UIPadding" then
		local padding = UDim.new(0.025, 0)
		instance.PaddingBottom = padding
		instance.PaddingLeft = padding
		instance.PaddingRight = padding
		instance.PaddingTop = padding
	elseif role == "UIScale" then
		instance.Scale = 1
	end
end

local function appendRoleSuffix(name, role)
	if role == "ImageButton" or role == "TextButton" then
		return if string.match(name, "Button$") then name else name .. "Button"
	end

	if role == "TextBox" then
		return if string.match(name, "Input$") then name else name .. "Input"
	end

	return name
end

local function applyImporterMetadata(instance, layer, role, sourceType)
	instance:SetAttribute("UIImporterGenerated", true)
	instance:SetAttribute("UIImporterSource", sourceType)
	instance:SetAttribute("UIImporterOriginalName", layer.name)
	instance:SetAttribute("UIImporterLayerIndex", layer.index)
	instance:SetAttribute("UIImporterRole", role)
	instance:SetAttribute("UIImporterBlendMode", layer.blendMode or "normal")
	instance:AddTag("UIImporterGenerated")
end

local function configureSemanticOverlay(instance)
	instance:SetAttribute("UIImporterVisualSource", "RenderedDesign")
	instance.BackgroundTransparency = 1

	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") or instance:IsA("ViewportFrame") then
		instance.ImageTransparency = 1
	elseif instance:IsA("VideoFrame") then
		instance.VideoTransparency = 1
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		instance.TextTransparency = 1
		instance.TextStrokeTransparency = 1
	end

	if instance:IsA("ScrollingFrame") then
		instance.ScrollBarImageTransparency = 1
	end

	for _, modifier in ipairs(instance:GetChildren()) do
		if modifier:IsA("UIStroke") then
			modifier.Transparency = 1
		elseif modifier:IsA("UIGradient") then
			modifier.Transparency = NumberSequence.new(1)
		end
	end
end

local function createLayer(layer, parent, parentBounds, canvasBounds, sourceType, useCompositeArtwork)
	local role = getLayerRole(layer)
	local bounds = getBounds(layer, parentBounds)
	local instance = Instance.new(role)
	local preferredName = appendRoleSuffix(toInstanceName(layer.name, role), role)

	instance.Name = uniqueName(parent, preferredName)
	applyImporterMetadata(instance, layer, role, sourceType)

	if MODIFIER_ROLES[role] then
		configureModifier(instance, role, layer, bounds)
		instance.Parent = parent

		if layer.children then
			for _, child in ipairs(layer.children) do
				createLayer(child, parent, parentBounds, canvasBounds, sourceType, useCompositeArtwork)
			end
		end

		return instance
	end

	instance.LayoutOrder = layer.index
	instance.Visible = layer.visible
	-- Photoshop records arrive bottom-to-top, so later records must render
	-- above earlier records. Using the source index also preserves ordering
	-- across nested groups when ZIndexBehavior is Global.
	instance.ZIndex = math.max(1, layer.index + if useCompositeArtwork then 1 else 0)
	instance.Rotation = layer.rotation or 0
	applyGeometry(instance, bounds, parentBounds)
	configureLayerInstance(instance, role, layer)
	instance.Parent = parent
	addImportedStyles(instance, layer, bounds)

	if useCompositeArtwork then
		configureSemanticOverlay(instance)
	else
		local hideOriginalArtwork = role == "TextLabel" or role == "TextButton" or role == "TextBox"
		addImageTiles(instance, layer, layer.tiles, hideOriginalArtwork)
	end
	if
		not useCompositeArtwork
		and role == "ImageLabel"
		and (not layer.tiles or #layer.tiles == 0)
		and not layer.backgroundColor
	then
		instance.Visible = false
		instance:SetAttribute("UIImporterMissingArtwork", true)
	end

	if layer.children then
		for _, child in ipairs(layer.children) do
			createLayer(child, instance, bounds, canvasBounds, sourceType, useCompositeArtwork)
		end
	end

	return instance
end

local function walkLayers(layers, callback)
	for _, layer in ipairs(layers) do
		callback(layer)
		if layer.children then
			walkLayers(layer.children, callback)
		end
	end
end

local function countContentTiles(layers)
	local count = 0
	walkLayers(layers, function(layer)
		if layer.visible and not MODIFIER_ROLES[getLayerRole(layer)] then
			count += AssetUploader.countTiles(layer)
		end
	end)
	return count
end

local function embedLayerArtwork(document, progressCallback)
	local totalTiles = countContentTiles(document.tree)
	local embeddedTiles = 0
	local embeddedImages = 0

	walkLayers(document.tree, function(layer)
		if not layer.visible or not layer.pixels or MODIFIER_ROLES[getLayerRole(layer)] then
			return
		end

		local tiles, contentError = AssetUploader.createLayerContent(layer, function()
			embeddedTiles += 1
			if progressCallback then
				progressCallback({
					stage = "Embedding",
					layerName = layer.name,
					current = embeddedTiles,
					total = totalTiles,
				})
			end
		end)

		if not tiles then
			error(string.format("Could not embed design layer '%s': %s", layer.name, contentError))
		end

		layer.tiles = tiles
		embeddedImages += #tiles
		layer.pixels = nil
	end)

	return embeddedImages
end

local function embedCompositeArtwork(document, progressCallback)
	local compositeLayer = {
		name = "RenderedDesign",
		width = document.width,
		height = document.height,
		opacity = 255,
		pixels = document.compositePixels,
	}
	local totalTiles = AssetUploader.countTiles(compositeLayer)
	local embeddedTiles = 0
	local tiles, contentError = AssetUploader.createLayerContent(compositeLayer, function()
		embeddedTiles += 1
		if progressCallback then
			progressCallback({
				stage = "Embedding",
				layerName = "Rendered PSD design",
				current = embeddedTiles,
				total = totalTiles,
			})
		end
	end)

	if not tiles then
		error("Could not embed the rendered PSD design: " .. tostring(contentError))
	end

	document.compositeTiles = tiles
	document.compositePixels = nil
	walkLayers(document.tree, function(layer)
		layer.pixels = nil
	end)

	return #tiles
end

local function addCompositeArtwork(canvas, document)
	local renderedDesign = Instance.new("ImageLabel")
	renderedDesign.Name = "RenderedDesign"
	renderedDesign.Size = UDim2.fromScale(1, 1)
	renderedDesign.BackgroundTransparency = 1
	renderedDesign.BorderSizePixel = 0
	renderedDesign.ImageTransparency = 1
	renderedDesign.ScaleType = Enum.ScaleType.Stretch
	renderedDesign.ZIndex = 1
	renderedDesign.Active = false
	renderedDesign.Selectable = false
	renderedDesign:SetAttribute("UIImporterGenerated", true)
	renderedDesign:SetAttribute("UIImporterVisualSource", "PSDComposite")
	renderedDesign:AddTag("UIImporterGenerated")
	renderedDesign.Parent = canvas

	addImageTiles(renderedDesign, {
		width = document.width,
		height = document.height,
		opacity = 255,
	}, document.compositeTiles, false)
end

function UIBuilder.build(document, documentName, targetParent, progressCallback, options)
	if progressCallback then
		progressCallback({
			stage = "Preparing",
			layerName = "",
			current = 0,
			total = #document.layers,
		})
	end

	local sourceType = document.sourceType or "PSD"
	local shouldEmbedImages = not options or options.embedImages ~= false
	local useCompositeArtwork = shouldEmbedImages
		and sourceType == "PSD"
		and document.hasLayerEffects == true
		and document.compositePixels ~= nil
	local embeddedImages = if useCompositeArtwork
		then embedCompositeArtwork(document, progressCallback)
		elseif shouldEmbedImages then embedLayerArtwork(document, progressCallback)
		else 0
	local layerCollectorClass = if options and options.layerCollectorClass
		then options.layerCollectorClass
		else "ScreenGui"
	local responsiveMode = if layerCollectorClass ~= "ScreenGui"
		then "PreserveAspect"
		elseif options and options.responsiveMode == "PreserveAspect" then "PreserveAspect"
		else "Adaptive"
	if
		layerCollectorClass ~= "ScreenGui"
		and layerCollectorClass ~= "SurfaceGui"
		and layerCollectorClass ~= "BillboardGui"
	then
		error("Unsupported UI root: " .. tostring(layerCollectorClass))
	end

	local canvasBounds = {
		left = 0,
		top = 0,
		width = document.width,
		height = document.height,
	}

	local layerCollector = Instance.new(layerCollectorClass)
	layerCollector.Name = uniqueName(targetParent, toInstanceName(documentName, "ImportedUI"))

	if layerCollector:IsA("ScreenGui") then
		layerCollector.DisplayOrder = 0
		layerCollector.IgnoreGuiInset = false
		layerCollector.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		layerCollector.ClipToDeviceSafeArea = true
		layerCollector.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
		layerCollector.ResetOnSpawn = false
	elseif layerCollector:IsA("SurfaceGui") then
		layerCollector.AlwaysOnTop = false
		layerCollector.CanvasSize = Vector2.new(document.width, document.height)
		layerCollector.LightInfluence = 0
		layerCollector.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		layerCollector:SetAttribute(
			"UIImporterSetupRequired",
			"Set Adornee to the BasePart that should display this UI."
		)
	elseif layerCollector:IsA("BillboardGui") then
		layerCollector.AlwaysOnTop = true
		layerCollector.Size = UDim2.fromOffset(document.width, document.height)
		layerCollector.StudsOffset = Vector3.new(0, 3, 0)
		layerCollector:SetAttribute(
			"UIImporterSetupRequired",
			"Set Adornee to the BasePart or Attachment this UI should follow."
		)
	end

	layerCollector.ZIndexBehavior = Enum.ZIndexBehavior.Global
	layerCollector:SetAttribute("UIImporterGenerated", true)
	layerCollector:SetAttribute("UIImporterSource", sourceType)
	layerCollector:SetAttribute("UIImporterCanvasWidth", document.width)
	layerCollector:SetAttribute("UIImporterCanvasHeight", document.height)
	layerCollector:SetAttribute("UIImporterResponsiveMode", responsiveMode)
	layerCollector:SetAttribute("UIImporterDeviceSafe", layerCollector:IsA("ScreenGui"))
	layerCollector:SetAttribute(
		"UIImporterVisualMode",
		if useCompositeArtwork then "CompositeOverlay" else "LayerArtwork"
	)
	layerCollector:AddTag("UIImporterGenerated")

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true
	canvas.Parent = layerCollector

	if responsiveMode == "PreserveAspect" or not layerCollector:IsA("ScreenGui") then
		local aspectRatio = Instance.new("UIAspectRatioConstraint")
		aspectRatio.Name = "DesignAspectRatio"
		aspectRatio.AspectRatio = document.width / document.height
		aspectRatio.AspectType = Enum.AspectType.FitWithinMaxSize
		aspectRatio.DominantAxis = Enum.DominantAxis.Width
		aspectRatio.Parent = canvas
	else
		canvas:SetAttribute("UIImporterLayout", "AdaptiveFullScreen")
	end

	if useCompositeArtwork then
		addCompositeArtwork(canvas, document)
	end

	for _, layer in ipairs(document.tree) do
		createLayer(layer, canvas, canvasBounds, canvasBounds, sourceType, useCompositeArtwork)
	end

	layerCollector.Parent = targetParent

	return {
		root = layerCollector,
		screenGui = layerCollector,
		layerCount = #document.layers,
		imageCount = embeddedImages,
		assetCount = embeddedImages,
		visualMode = if useCompositeArtwork then "CompositeOverlay" else "LayerArtwork",
		warnings = document.warnings,
	}
end

return UIBuilder
