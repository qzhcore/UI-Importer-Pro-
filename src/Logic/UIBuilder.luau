local AssetUploader = require(script.Parent.AssetUploader)
local FigmaLayout = require(script.Parent.FigmaLayout)
local FigmaVisual = require(script.Parent.FigmaVisual)

local RenderPolicy = require(script.Parent.RenderPolicy)

local ResponsiveLayout = require(script.Parent.ResponsiveLayout)
local AutoLayoutMapper = require(script.Parent.AutoLayoutMapper)
local FontMapper = require(script.Parent.FontMapper)
local RichTextCompiler = require(script.Parent.RichTextCompiler)
local ImportIdentity = require(script.Parent.ImportIdentity)

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

local TEXT_X_ALIGN = {
	LEFT = Enum.TextXAlignment.Left,
	CENTER = Enum.TextXAlignment.Center,
	RIGHT = Enum.TextXAlignment.Right,
	JUSTIFIED = Enum.TextXAlignment.Left,
}

local TEXT_Y_ALIGN = {
	TOP = Enum.TextYAlignment.Top,
	CENTER = Enum.TextYAlignment.Center,
	BOTTOM = Enum.TextYAlignment.Bottom,
}

local IMAGE_SCALE_TYPES = {
	STRETCH = Enum.ScaleType.Stretch,
	FIT = Enum.ScaleType.Fit,
	FILL = Enum.ScaleType.Crop,
	TILE = Enum.ScaleType.Tile,
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
	if layer.renderAsImage then
		return if layer.interactive
				or string.find(string.lower(layer.suggestedRole or layer.name), "button", 1, true)
			then "ImageButton"
			else "ImageLabel"
	end
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

	if containsWord(name, "imagebutton") then
		return "ImageButton"
	end
	if containsWord(name, "button") then
		return if layer.text or layer.textRuns then "TextButton" else "ImageButton"
	end

	if layer.text or layer.textRuns then
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
	return FigmaLayout.getEffectiveBounds(layer) or fallback
end

local function normalizedGradientStops(gradient)
	local stops = {}
	for _, stop in ipairs(gradient and gradient.gradientStops or {}) do
		if stop.color then
			table.insert(stops, {
				position = math.clamp(stop.position or 0, 0, 1),
				color = stop.color,
			})
		end
	end
	table.sort(stops, function(left, right)
		return left.position < right.position
	end)
	if #stops == 0 then
		return nil
	elseif #stops == 1 then
		stops = {
			{ position = 0, color = stops[1].color },
			{ position = 1, color = stops[1].color },
		}
	else
		if stops[1].position > 0 then
			table.insert(stops, 1, { position = 0, color = stops[1].color })
		end
		if stops[#stops].position < 1 then
			table.insert(stops, { position = 1, color = stops[#stops].color })
		end
	end

	if #stops > 20 then
		local reduced = table.create(20)
		for index = 1, 20 do
			local sourceIndex = math.floor((index - 1) * (#stops - 1) / 19 + 1.5)
			reduced[index] = stops[math.clamp(sourceIndex, 1, #stops)]
		end
		stops = reduced
	end

	for index = 2, #stops - 1 do
		local minimum = stops[index - 1].position + 0.0001
		local maximum = 1 - (#stops - index) * 0.0001
		stops[index].position = math.clamp(stops[index].position, minimum, maximum)
	end
	stops[1].position = 0
	stops[#stops].position = 1
	return stops
end

local function addGradient(parent, gradient, name)
	local stops = normalizedGradientStops(gradient)
	if not stops then
		return nil
	end
	local colors = table.create(#stops)
	local transparencies = table.create(#stops)
	for index, stop in ipairs(stops) do
		colors[index] = ColorSequenceKeypoint.new(stop.position, Color3.new(stop.color.r, stop.color.g, stop.color.b))
		transparencies[index] = NumberSequenceKeypoint.new(stop.position, 1 - (stop.color.a or 1))
	end

	local visual = FigmaVisual.gradientGeometry(gradient)
	local uiGradient = Instance.new("UIGradient")
	uiGradient.Name = name
	uiGradient.Color = ColorSequence.new(colors)
	uiGradient.Transparency = NumberSequence.new(transparencies)
	uiGradient.Rotation = visual.rotation
	uiGradient.Offset = Vector2.new(visual.offsetX, visual.offsetY)
	uiGradient:SetAttribute("UIImporterGenerated", true)
	uiGradient:SetAttribute("UIImporterGradientType", gradient.type)
	if gradient.type ~= "GRADIENT_LINEAR" then
		uiGradient:SetAttribute("UIImporterApproximation", "Roblox UIGradient is linear")
	end
	uiGradient.Parent = parent
	return uiGradient
end

local function styleTextObject(instance, layer)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	FontMapper.apply(instance, layer)
	instance.Text, instance.RichText =
		RichTextCompiler.compile(layer.text or stripRoleMarkers(layer.name), layer.textRuns)
	instance.TextColor3 = if layer.fillGradient
		then Color3.new(1, 1, 1)
		elseif layer.backgroundColor then Color3.new(
			layer.backgroundColor.r,
			layer.backgroundColor.g,
			layer.backgroundColor.b
		)
		else Color3.new(1, 1, 1)
	instance.TextScaled = true
	if layer.textSize then
		instance.TextSize = math.clamp(layer.textSize, 1, 100)
	end
	local fillOpacity = if layer.fillGradient then 1 else 1 - (layer.backgroundTransparency or 0)
	instance.TextTransparency = 1 - (layer.opacity / 255) * fillOpacity
	instance.TextStrokeTransparency = 1
	instance.TextWrapped = true
	instance.TextXAlignment = TEXT_X_ALIGN[layer.textAlignHorizontal] or Enum.TextXAlignment.Left
	instance.TextYAlignment = TEXT_Y_ALIGN[layer.textAlignVertical] or Enum.TextYAlignment.Center

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.Name = "ResponsiveTextSize"
	sizeConstraint.MinTextSize = layer.minTextSize or 10
	sizeConstraint.MaxTextSize = math.max(
		sizeConstraint.MinTextSize,
		layer.maxTextSize or (if layer.textSize then math.clamp(math.floor(layer.textSize * 2), 10, 100) else 72)
	)
	sizeConstraint.Parent = instance
end

local function backgroundTransparency(layer)
	local fillOpacity = 1 - math.clamp(layer.backgroundTransparency or 0, 0, 1)
	return 1 - fillOpacity * (layer.opacity / 255)
end

local function styleContainer(instance, layer)
	if layer and layer.fillGradient then
		instance.BackgroundColor3 = Color3.new(1, 1, 1)
		instance.BackgroundTransparency = 1 - (layer.opacity / 255)
	elseif layer and layer.backgroundColor then
		instance.BackgroundColor3 =
			Color3.new(layer.backgroundColor.r, layer.backgroundColor.g, layer.backgroundColor.b)
		instance.BackgroundTransparency = backgroundTransparency(layer)
	else
		instance.BackgroundTransparency = 1
	end
	instance.BorderSizePixel = 0
	instance.ClipsDescendants = layer and (layer.clipsContent == true or layer.imageScaleMode ~= nil) or false
end

local function applyImageScale(image, layer)
	image.ScaleType = IMAGE_SCALE_TYPES[layer.imageScaleMode] or Enum.ScaleType.Stretch
	if image.ScaleType == Enum.ScaleType.Tile then
		image.TileSize = UDim2.fromScale(
			(layer.pixelWidth or layer.width) / math.max(1, layer.width),
			(layer.pixelHeight or layer.height) / math.max(1, layer.height)
		)
	end
end

local function addImageTiles(instance, layer, tiles, hideOriginalArtwork)
	if not tiles or #tiles == 0 then
		return
	end

	local supportsImage = instance:IsA("ImageLabel") or instance:IsA("ImageButton")
	local imageOpacity = (layer.opacity / 255) * (layer.imageOpacity or 1)
	if supportsImage and #tiles == 1 then
		instance.ImageContent = tiles[1].content
		instance:SetAttribute("UIImporterAssetId", tiles[1].assetId)
		instance.ImageTransparency = 1 - imageOpacity
		applyImageScale(instance, layer)
		return
	end

	if #tiles == 1 then
		local image = Instance.new("ImageLabel")
		image.Name = "OriginalArtwork"
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.ImageContent = tiles[1].content
		image:SetAttribute("UIImporterAssetId", tiles[1].assetId)
		image.ImageTransparency = 1 - imageOpacity
		image.Position = UDim2.fromScale(0, 0)
		image.Size = UDim2.fromScale(1, 1)
		applyImageScale(image, layer)
		image.Visible = not hideOriginalArtwork
		image.ZIndex = 0
		image:SetAttribute("UIImporterArtwork", true)
		image.Parent = instance
		return
	end

	local sourceWidth = layer.pixelWidth or layer.width
	local sourceHeight = layer.pixelHeight or layer.height
	local holder = Instance.new("Frame")
	holder.Name = "OriginalArtworkTiles"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Position = UDim2.fromScale(0, 0)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Visible = not hideOriginalArtwork
	holder.ZIndex = 0
	holder:SetAttribute("UIImporterArtwork", true)
	holder:SetAttribute("UIImporterImageScaleMode", layer.imageScaleMode or "STRETCH")
	holder.Parent = instance

	for index, tile in ipairs(tiles) do
		local image = Instance.new("ImageLabel")
		image.Name = string.format("ArtworkTile%02d", index)
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.ImageContent = tile.content
		image:SetAttribute("UIImporterAssetId", tile.assetId)
		image.ImageTransparency = 1 - imageOpacity
		image.Position = UDim2.fromScale(tile.x / sourceWidth, tile.y / sourceHeight)
		image.Size = UDim2.fromScale(tile.width / sourceWidth, tile.height / sourceHeight)
		image.ScaleType = Enum.ScaleType.Stretch
		image.ZIndex = 0
		image:SetAttribute("UIImporterArtwork", true)
		image.Parent = holder
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
		if layer.fillGradient then
			instance.BackgroundColor3 = Color3.new(1, 1, 1)
			instance.BackgroundTransparency = 1 - (layer.opacity / 255)
		elseif layer.backgroundColor then
			instance.BackgroundColor3 =
				Color3.new(layer.backgroundColor.r, layer.backgroundColor.g, layer.backgroundColor.b)
			instance.BackgroundTransparency = backgroundTransparency(layer)
		else
			instance.BackgroundTransparency = 1
		end
		instance.BorderSizePixel = 0
		instance.ImageTransparency = if layer.imageAssetId then 1 - layer.opacity / 255 else 1
		if layer.imageAssetId then
			instance.Image = layer.imageAssetId
		end
		instance.ScaleType = Enum.ScaleType.Stretch
		if instance:IsA("ImageButton") then
			instance.AutoButtonColor = false
		end
	end

	if
		not layer.figmaType and (instance:IsA("TextButton") or instance:IsA("ImageButton") or instance:IsA("TextBox"))
	then
		if layer.width < 44 or layer.height < 44 then
			instance:SetAttribute(
				"UIImporterTouchTargetWarning",
				"Review this control's touch hit area; source dimensions were preserved."
			)
		end
	end
end

local function addImportedStyles(instance, layer, bounds, layoutParent)
	local minimumDimension = math.max(1, math.min(bounds.width, bounds.height))

	local cornerRadii = layer.cornerRadii
	local maximumCorner = if cornerRadii
		then math.max(cornerRadii.topLeft, cornerRadii.topRight, cornerRadii.bottomRight, cornerRadii.bottomLeft)
		else layer.cornerRadius or 0
	if maximumCorner > 0 then
		local corner = Instance.new("UICorner")
		corner.Name = "ImportedCorner"
		corner.CornerRadius = UDim.new(math.clamp(maximumCorner / minimumDimension, 0, 0.5), 0)
		if cornerRadii then
			local ok = pcall(function()
				corner.TopLeftRadius = UDim.new(math.clamp(cornerRadii.topLeft / minimumDimension, 0, 0.5), 0)
				corner.TopRightRadius = UDim.new(math.clamp(cornerRadii.topRight / minimumDimension, 0, 0.5), 0)
				corner.BottomRightRadius = UDim.new(math.clamp(cornerRadii.bottomRight / minimumDimension, 0, 0.5), 0)
				corner.BottomLeftRadius = UDim.new(math.clamp(cornerRadii.bottomLeft / minimumDimension, 0, 0.5), 0)
			end)
			if not ok and cornerRadii.independent then
				corner:SetAttribute("UIImporterApproximation", "Per-corner radii flattened to the largest radius")
			end
		end
		corner:SetAttribute("UIImporterGenerated", true)
		corner.Parent = instance
	end

	if layer.fillGradient then
		addGradient(instance, layer.fillGradient, "ImportedFillGradient")
	end

	for effectIndex, effect in ipairs(layer.effects or {}) do
		if effect.type == "DROP_SHADOW" then
			local color = effect.color or { r = 0, g = 0, b = 0, a = 0.25 }
			local created, shadow = pcall(function()
				local result = Instance.new("UIShadow")
				result.Name = string.format("ImportedShadow%02d", effectIndex)
				result.BlurRadius = UDim.new(effect.radius / minimumDimension, 0)
				result.Color = Color3.new(color.r, color.g, color.b)
				result.Transparency = 1 - (color.a or 1) * (layer.opacity / 255)
				result.Offset = UDim2.fromScale(effect.offsetX / bounds.width, effect.offsetY / bounds.height)
				result.Spread = UDim2.fromScale(effect.spread / bounds.width, effect.spread / bounds.height)
				result.ZIndex = 0
				result:SetAttribute("UIImporterGenerated", true)
				result.Parent = instance
				return result
			end)
			if not created then
				local fallback = Instance.new("UIStroke")
				fallback.Name = string.format("ImportedShadowFallback%02d", effectIndex)
				fallback.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				fallback.Color = Color3.new(color.r, color.g, color.b)
				fallback.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
				fallback.Thickness = math.max(1, effect.radius + effect.spread) / minimumDimension
				fallback.Transparency = math.clamp(1 - (color.a or 1) * (layer.opacity / 255) * 0.5, 0, 1)
				fallback:SetAttribute("UIImporterGenerated", true)
				fallback:SetAttribute("UIImporterApproximation", tostring(shadow))
				fallback.Parent = instance
			end
		end
	end

	if (layer.strokeColor or layer.strokeGradient) and layer.strokeThickness and layer.strokeThickness > 0 then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "ImportedStroke"
		local isText = instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")
		stroke.ApplyStrokeMode = if isText then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
		if layer.strokeGradient then
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Transparency = 1 - (layer.opacity / 255)
		else
			stroke.Color = Color3.new(layer.strokeColor.r, layer.strokeColor.g, layer.strokeColor.b)
			stroke.Transparency = 1 - (layer.strokeColor.a or 1) * (layer.opacity / 255)
		end
		stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		stroke.Thickness = layer.strokeThickness / minimumDimension
		if layer.strokeJoin == "BEVEL" then
			stroke.LineJoinMode = Enum.LineJoinMode.Bevel
		elseif layer.strokeJoin == "MITER" then
			stroke.LineJoinMode = Enum.LineJoinMode.Miter
		else
			stroke.LineJoinMode = Enum.LineJoinMode.Round
		end
		pcall(function()
			if layer.strokeAlign == "INSIDE" then
				stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
			elseif layer.strokeAlign == "OUTSIDE" then
				stroke.BorderStrokePosition = Enum.BorderStrokePosition.Outer
			else
				stroke.BorderStrokePosition = Enum.BorderStrokePosition.Center
			end
		end)
		stroke:SetAttribute("UIImporterGenerated", true)
		stroke.Parent = instance
		if layer.strokeGradient then
			addGradient(stroke, layer.strokeGradient, "ImportedStrokeGradient")
		end
	end

	AutoLayoutMapper.apply(layoutParent, layer, bounds)
end

local function configureModifier(instance, role, layer, bounds, parentBounds)
	if role == "UIListLayout" then
		instance.FillDirection = if containsWord(layer.name, "horizontal")
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		instance.Padding = UDim.new(
			8
				/ (
					if instance.FillDirection == Enum.FillDirection.Horizontal
						then parentBounds.width
						else parentBounds.height
				),
			0
		)
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UIGridLayout" then
		instance.CellPadding = UDim2.fromScale(8 / parentBounds.width, 8 / parentBounds.height)
		instance.CellSize = UDim2.fromScale(bounds.width / parentBounds.width, bounds.height / parentBounds.height)
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UIPageLayout" then
		instance.Padding = UDim.new(12 / parentBounds.width, 0)
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UITableLayout" then
		instance.Padding = UDim2.fromScale(8 / parentBounds.width, 8 / parentBounds.height)
		instance.SortOrder = Enum.SortOrder.LayoutOrder
	elseif role == "UIAspectRatioConstraint" then
		instance.AspectRatio = math.max(0.01, bounds.width / math.max(1, bounds.height))
		instance.AspectType = Enum.AspectType.FitWithinMaxSize
	elseif role == "UISizeConstraint" then
		instance.MinSize = Vector2.zero
		instance.MaxSize = Vector2.new(math.max(1, bounds.width), math.max(1, bounds.height))
	elseif role == "UITextSizeConstraint" then
		instance.MinTextSize = 10
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
	instance:SetAttribute("UIImporterSourceId", layer.sourceId)
	instance:SetAttribute("UIImporterWarning", layer.importWarning)
	instance:SetAttribute("UIImporterRole", role)
	instance:SetAttribute("UIImporterBlendMode", layer.blendMode or "normal")
	instance:SetAttribute("UIImporterRequiresImage", layer.renderAsImage and not layer.imageAssetId or nil)
	instance:AddTag("UIImporterGenerated")
end

local function createLayer(layer, parent, parentBounds, canvasBounds, sourceType, parentLayout, job)
	if job then
		job:checkpoint()
	end
	local role = getLayerRole(layer)
	local bounds = getBounds(layer, parentBounds)
	local instance = Instance.new(role)
	local preferredName = appendRoleSuffix(toInstanceName(layer.name, role), role)

	local childLayout = if AutoLayoutMapper.isFlow(layer) then { mode = layer.layoutMode } else nil

	instance.Name = uniqueName(parent, preferredName)
	instance.Parent = parent
	applyImporterMetadata(instance, layer, role, sourceType)

	if MODIFIER_ROLES[role] then
		configureModifier(instance, role, layer, bounds, parentBounds)
		instance.Parent = parent

		if layer.children then
			for _, child in ipairs(layer.children) do
				createLayer(child, parent, parentBounds, canvasBounds, sourceType, childLayout, job)
			end
		end

		return instance
	end

	instance.LayoutOrder = layer.index
	instance.Visible = layer.visible
	instance.ZIndex = math.max(1, layer.index)
	instance.Rotation = layer.rotation or 0
	local inFlow = parentLayout ~= nil and layer.layoutPositioning ~= "ABSOLUTE"
	ResponsiveLayout.apply(instance, layer, bounds, parentBounds, inFlow)
	if inFlow and parentLayout.mode ~= "GRID" then
		AutoLayoutMapper.child(instance, layer)
	end

	configureLayerInstance(instance, role, layer)
	instance.Parent = parent
	local flowParent = instance
	local hasContentContainer = childLayout ~= nil or AutoLayoutMapper.hasPadding(layer)
	if hasContentContainer then
		flowParent = Instance.new("Frame")
		flowParent.Name = "LayoutContent"
		flowParent.BackgroundTransparency = 1
		flowParent.BorderSizePixel = 0
		flowParent.Size = UDim2.fromScale(1, 1)
		flowParent.ZIndex = 1
		flowParent:SetAttribute("UIImporterLayoutContent", true)
		flowParent.Parent = instance
	end
	addImportedStyles(instance, layer, bounds, flowParent)

	local hideOriginalArtwork = role == "TextLabel" or role == "TextButton" or role == "TextBox"
	addImageTiles(instance, layer, layer.tiles, hideOriginalArtwork)
	if
		role == "ImageLabel"
		and (not layer.tiles or #layer.tiles == 0)
		and not layer.backgroundColor
		and not layer.imageAssetId
	then
		instance:SetAttribute("UIImporterMissingArtwork", true)
	end

	if layer.children then
		for _, child in ipairs(layer.children) do
			local inContent = hasContentContainer and child.layoutPositioning ~= "ABSOLUTE"
			local childParent = if inContent then flowParent else instance
			local childBounds = if inContent then AutoLayoutMapper.contentBounds(bounds, layer) else bounds
			createLayer(child, childParent, childBounds, canvasBounds, sourceType, childLayout, job)
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
		if not MODIFIER_ROLES[getLayerRole(layer)] then
			count += AssetUploader.countTiles(layer)
		end
	end)
	return count
end

local function embedLayerArtwork(document, progressCallback, job, options)
	local totalTiles = countContentTiles(document.tree)
	local embeddedTiles = 0
	local embeddedImages = 0
	local cache = {}

	walkLayers(document.tree, function(layer)
		if layer.imageAssetId or not layer.pixels or MODIFIER_ROLES[getLayerRole(layer)] then
			return
		end

		local cached = cache[layer.pixels]
		local pixelWidth = layer.pixelWidth or layer.width
		local pixelHeight = layer.pixelHeight or layer.height
		if cached and cached.width == pixelWidth and cached.height == pixelHeight then
			layer.tiles = cached.tiles
			layer.pixels = nil
			embeddedTiles += #cached.tiles
			return
		end
		local pixels = layer.pixels
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
		end, job, options)

		if not tiles then
			error(string.format("Could not embed design layer '%s': %s", layer.name, contentError))
		end

		cache[pixels] = { tiles = tiles, width = pixelWidth, height = pixelHeight }
		layer.tiles = tiles
		embeddedImages += #tiles
		layer.pixels = nil
	end)

	return embeddedImages
end

local function embedCompositeArtwork(document, progressCallback, job, options)
	local compositeWidth = document.compositeWidth or document.width
	local compositeHeight = document.compositeHeight or document.height
	local compositeLayer = {
		name = "RenderedDesign",
		width = compositeWidth,
		height = compositeHeight,
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
				layerName = if document.compositeSource == "FigmaThumbnail"
					then "Rendered Figma preview"
					else "Rendered PSD design",
				current = embeddedTiles,
				total = totalTiles,
			})
		end
	end, job, options)

	if not tiles then
		error("Could not embed the rendered design reference: " .. tostring(contentError))
	end

	document.compositeTiles = tiles
	document.compositePixels = nil
	walkLayers(document.tree, function(layer)
		layer.pixels = nil
	end)

	return #tiles
end

local function addCompositeArtwork(canvas, document)
	local compositeWidth = document.compositeWidth or document.width
	local compositeHeight = document.compositeHeight or document.height
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
	renderedDesign:SetAttribute("UIImporterVisualSource", document.compositeSource or "PSDComposite")
	renderedDesign:AddTag("UIImporterGenerated")
	renderedDesign.Parent = canvas

	addImageTiles(renderedDesign, {
		width = compositeWidth,
		height = compositeHeight,
		pixelWidth = compositeWidth,
		pixelHeight = compositeHeight,
		opacity = 255,
	}, document.compositeTiles, false)
end

local function buildInto(document, documentName, targetParent, progressCallback, options, job, layerCollector)
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
	local visualMode = RenderPolicy.prepare(document, options)
	local useCompositeArtwork = visualMode == "Reference"
	local embeddedImages = 0
	if useCompositeArtwork then
		embeddedImages = embedCompositeArtwork(document, progressCallback, job, options)
	elseif shouldEmbedImages then
		embeddedImages = embedLayerArtwork(document, progressCallback, job, options)
	end
	local imageStorage = options and options.imageStorage or "Session"
	if embeddedImages > 0 and imageStorage == "Session" then
		table.insert(
			document.warnings,
			"Artwork is temporary for this Studio session. Reimport with Upload to Roblox before saving or shipping image-based UI."
		)
	elseif embeddedImages > 0 then
		table.insert(
			document.warnings,
			"Uploaded artwork must pass Roblox moderation and have permission to load in the target experience. Undo does not delete uploaded assets."
		)
	end
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
		layerCollector.Size = UDim2.fromScale(10, 10 * document.height / document.width)
		layerCollector.StudsOffset = Vector3.new(0, 3, 0)
		layerCollector:SetAttribute(
			"UIImporterSetupRequired",
			"Set Adornee to the BasePart or Attachment this UI should follow."
		)
	end

	layerCollector.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	layerCollector:SetAttribute("UIImporterGenerated", true)
	layerCollector:SetAttribute("UIImporterSource", sourceType)
	layerCollector:SetAttribute("UIImporterCanvasWidth", document.width)
	layerCollector:SetAttribute("UIImporterCanvasHeight", document.height)
	layerCollector:SetAttribute("UIImporterResponsiveMode", responsiveMode)
	layerCollector:SetAttribute("UIImporterDeviceSafe", layerCollector:IsA("ScreenGui"))
	layerCollector:SetAttribute("UIImporterVisualMode", visualMode)
	layerCollector:SetAttribute("UIImporterSchemaVersion", document.schemaVersion or 1)
	layerCollector:SetAttribute("UIImporterImageStorage", if embeddedImages == 0 then "None" else imageStorage)
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

	if not useCompositeArtwork then
		if job then
			job:progress({ stage = "Building", message = "Creating editable Roblox layers..." })
		end
		for _, layer in ipairs(document.tree) do
			createLayer(layer, canvas, canvasBounds, canvasBounds, sourceType, nil, job)
		end
	end

	ImportIdentity.stamp(layerCollector, sourceType .. ":" .. (document.documentId or documentName))
	layerCollector:SetAttribute("UIImporterStableIds", document.stableIds ~= false)
	return {
		root = layerCollector,
		screenGui = layerCollector,
		layerCount = if useCompositeArtwork then 0 else #document.layers,
		imageCount = embeddedImages,
		assetCount = embeddedImages,
		visualMode = visualMode,
		warnings = document.warnings,
	}
end

-- Build detached so errors and cancellation cannot leave partial trees in the game.
function UIBuilder.build(document, documentName, targetParent, progressCallback, options, job)
	local className = options and options.layerCollectorClass or "ScreenGui"
	if className ~= "ScreenGui" and className ~= "SurfaceGui" and className ~= "BillboardGui" then
		error("Unsupported UI root: " .. tostring(className), 0)
	end
	local root = Instance.new(className)
	local ok, result = pcall(buildInto, document, documentName, targetParent, progressCallback, options, job, root)
	if not ok then
		root:Destroy()
		error(result, 0)
	end
	return result
end

return UIBuilder
