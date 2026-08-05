local AssetUploader = require(script.Parent.AssetUploader)
local FigmaLayout = require(script.Parent.FigmaLayout)

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

-- Figma's primaryAxisAlignItems / counterAxisAlignItems values, mapped onto
-- the Roblox UIListLayout alignment enums. Roblox has no equivalent for
-- SPACE_BETWEEN, so it degrades to edge-alignment (see the UIImporterNote
-- attribute added in addImportedStyles below, which flags this on the
-- generated instance rather than silently guessing at extra spacing).
local FIG_HORIZONTAL_ALIGN = {
	MIN = Enum.HorizontalAlignment.Left,
	CENTER = Enum.HorizontalAlignment.Center,
	MAX = Enum.HorizontalAlignment.Right,
	SPACE_BETWEEN = Enum.HorizontalAlignment.Left,
}

local FIG_VERTICAL_ALIGN = {
	MIN = Enum.VerticalAlignment.Top,
	CENTER = Enum.VerticalAlignment.Center,
	MAX = Enum.VerticalAlignment.Bottom,
	SPACE_BETWEEN = Enum.VerticalAlignment.Top,
}

local FIG_ITEM_ALIGN = {
	MIN = Enum.ItemLineAlignment.Start,
	CENTER = Enum.ItemLineAlignment.Center,
	MAX = Enum.ItemLineAlignment.End,
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
	return FigmaLayout.getEffectiveBounds(layer) or fallback
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

-- Maps ONE axis of a Figma resize constraint onto (AnchorPoint, Position,
-- Size) expressed as a single UDim per component. `near`/`size`/`parentSize`
-- are all in the same design-space "pixel" unit that the parser already
-- works in (the same unit `applyGeometry` above converts to pure Scale).
--
-- The key idea: Roblox's UDim2 already natively supports "part proportional,
-- part fixed" the same way Figma's constraints do - Scale mirrors Figma's
-- SCALE constraint and Offset mirrors a fixed-pixel pin. So each constraint
-- type below is just a different mix of the two, chosen to reproduce what
-- Figma itself does when its frame is resized:
--   MIN     - pinned to the near edge, fixed size            -> pure Offset
--   MAX     - pinned to the far edge, fixed size              -> Scale(1) + Offset
--   CENTER  - pinned to the center, fixed size                -> Scale(0.5) + Offset, AnchorPoint 0.5
--   STRETCH - both edges pinned, size grows with the parent   -> Scale(1) size, Offset margins
--   SCALE   - everything proportional                         -> pure Scale (matches legacy applyGeometry)
-- Figma-specific replacement for applyGeometry: uses the node's actual
-- horizontal/vertical resize constraints instead of guessing an anchor from
-- where the layer happens to sit. This is what fixes the "severe positional
-- drift" the constraint-guessing heuristic in inferAnchor/applyGeometry
-- produced for non-SCALE constraints - that heuristic only ever looked at
-- the layer's own position, so a MIN-pinned icon that happened to sit near
-- the middle of its frame (common with fixed-size headers, etc.) would get
-- center-anchored and then drift as soon as the parent resized to anything
-- other than its exact export-time size.
local function applyFigmaConstraintGeometry(instance, bounds, parentBounds, constraints)
	local geometry = FigmaLayout.constraintGeometry(bounds, parentBounds, constraints)
	instance.AnchorPoint = Vector2.new(geometry.x.anchor, geometry.y.anchor)
	instance.Position = UDim2.new(
		geometry.x.positionScale,
		geometry.x.positionOffset,
		geometry.y.positionScale,
		geometry.y.positionOffset
	)
	instance.Size = UDim2.new(geometry.x.sizeScale, geometry.x.sizeOffset, geometry.y.sizeScale, geometry.y.sizeOffset)
end

-- Sizes a child that lives inside a Figma auto-layout frame. Deliberately
-- does NOT touch Position: see the comment at its call site in createLayer
-- for why setting an explicit Position here would double up the auto-layout
-- spacing that UIListLayout is about to apply on top of it.
local function applyAutoLayoutChildSize(instance, layer, bounds, parentLayout)
	instance.AnchorPoint = Vector2.new(0, 0)
	local layoutSize = FigmaLayout.autoLayoutChildSize(layer, bounds, parentLayout)
	instance.Size = UDim2.new(layoutSize.x.scale, layoutSize.x.offset, layoutSize.y.scale, layoutSize.y.offset)

	if layoutSize.grow or layoutSize.stretch then
		-- UIListLayout stacks children back-to-back using each child's own
		-- size; unlike CSS flexbox it has no built-in "consume the remaining
		-- space" behavior. UIFlexItem is the supported Roblox mechanism for
		-- that, so it's attached here when the running engine has it, and
		-- silently skipped on older clients that don't (the child then just
		-- keeps its fixed baked size instead of growing).
		local created, flexItem = pcall(Instance.new, "UIFlexItem")
		if created then
			flexItem.Name = "ImportedAutoLayoutItem"
			if layoutSize.grow then
				flexItem.FlexMode = Enum.UIFlexMode.Grow
			end
			if layoutSize.stretch then
				flexItem.ItemLineAlignment = Enum.ItemLineAlignment.Stretch
			end
			flexItem:SetAttribute("UIImporterGenerated", true)
			flexItem.Parent = instance
		end
	end
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
		local isHorizontal = layer.layoutMode == "HORIZONTAL"
		local layout = Instance.new("UIListLayout")
		layout.Name = "ImportedAutoLayout"
		layout.FillDirection = if isHorizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
		-- Figma ignores its explicit item gap under SPACE_BETWEEN. Roblox's flex
		-- distribution should do the same instead of adding the two spacings.
		local layoutGap = if layer.primaryAxisAlignItems == "SPACE_BETWEEN" then 0 else layer.layoutGap or 0
		layout.Padding = UDim.new(0, layoutGap)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Wraps = layer.layoutWrap == "WRAP"

		-- Figma's primaryAxisAlignItems packs children ALONG the stacking
		-- direction; counterAxisAlignItems aligns them across it. Which
		-- Roblox property ("Horizontal"/"VerticalAlignment") is primary vs.
		-- counter flips depending on FillDirection.
		if isHorizontal then
			layout.HorizontalAlignment = FIG_HORIZONTAL_ALIGN[layer.primaryAxisAlignItems]
				or Enum.HorizontalAlignment.Left
			layout.VerticalAlignment = FIG_VERTICAL_ALIGN[layer.counterAxisAlignItems] or Enum.VerticalAlignment.Top
		else
			layout.VerticalAlignment = FIG_VERTICAL_ALIGN[layer.primaryAxisAlignItems] or Enum.VerticalAlignment.Top
			layout.HorizontalAlignment = FIG_HORIZONTAL_ALIGN[layer.counterAxisAlignItems]
				or Enum.HorizontalAlignment.Left
		end
		if FIG_ITEM_ALIGN[layer.counterAxisAlignItems] then
			layout.ItemLineAlignment = FIG_ITEM_ALIGN[layer.counterAxisAlignItems]
		end

		if layer.primaryAxisAlignItems == "SPACE_BETWEEN" then
			if isHorizontal then
				layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
			else
				layout.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
			end
		end
		if layer.counterAxisAlignItems == "BASELINE" then
			layout:SetAttribute("UIImporterNote", "Figma baseline alignment was approximated with start alignment.")
		end

		layout:SetAttribute("UIImporterGenerated", true)
		layout.Parent = instance

		-- "Hug contents" (Figma's AUTO sizing mode) on either axis is mapped
		-- onto Roblox's AutomaticSize, so the frame keeps hugging its content
		-- if it's edited further in Studio rather than staying frozen at its
		-- exported snapshot size.
		local primarySizingMode = layer.primaryAxisSizingMode
		local counterSizingMode = layer.counterAxisSizingMode
		local hugHorizontal = if isHorizontal
			then FigmaLayout.isHugSizing(primarySizingMode)
			else FigmaLayout.isHugSizing(counterSizingMode)
		local hugVertical = if isHorizontal
			then FigmaLayout.isHugSizing(counterSizingMode)
			else FigmaLayout.isHugSizing(primarySizingMode)

		if hugHorizontal and hugVertical then
			instance.AutomaticSize = Enum.AutomaticSize.XY
		elseif hugHorizontal then
			instance.AutomaticSize = Enum.AutomaticSize.X
		elseif hugVertical then
			instance.AutomaticSize = Enum.AutomaticSize.Y
		end
	end

	if layer.paddingLeft or layer.paddingRight or layer.paddingTop or layer.paddingBottom then
		local padding = Instance.new("UIPadding")
		padding.Name = "ImportedPadding"
		padding.PaddingLeft = UDim.new(0, layer.paddingLeft or 0)
		padding.PaddingRight = UDim.new(0, layer.paddingRight or 0)
		padding.PaddingTop = UDim.new(0, layer.paddingTop or 0)
		padding.PaddingBottom = UDim.new(0, layer.paddingBottom or 0)
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

-- parentLayout describes the immediate parent's Figma auto-layout, if any:
-- { mode = "HORIZONTAL" | "VERTICAL" }, or nil when the parent isn't an
-- auto-layout frame (always nil for PSD, since PSD has no such concept).
local function createLayer(layer, parent, parentBounds, canvasBounds, sourceType, useCompositeArtwork, parentLayout)
	local role = getLayerRole(layer)
	local bounds = getBounds(layer, parentBounds)
	local instance = Instance.new(role)
	local preferredName = appendRoleSuffix(toInstanceName(layer.name, role), role)

	-- A layer that itself runs Figma auto-layout hands that mode down to its
	-- own children's createLayer calls below, regardless of which branch
	-- (modifier or normal) this layer takes.
	local childLayout = if layer.layoutMode == "HORIZONTAL" or layer.layoutMode == "VERTICAL"
		then { mode = layer.layoutMode }
		else nil

	instance.Name = uniqueName(parent, preferredName)
	applyImporterMetadata(instance, layer, role, sourceType)

	if MODIFIER_ROLES[role] then
		configureModifier(instance, role, layer, bounds)
		instance.Parent = parent

		if layer.children then
			for _, child in ipairs(layer.children) do
				createLayer(child, parent, parentBounds, canvasBounds, sourceType, useCompositeArtwork, childLayout)
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

	-- Geometry dispatch, in priority order:
	--   1. This layer is a live participant in its PARENT's Figma auto-layout
	--      (parentLayout set, and the designer didn't opt it out via Figma's
	--      "Absolute position" toggle) -> size only, UIListLayout owns
	--      Position. Giving it an explicit Position here on top of a
	--      UIListLayout is exactly what produced the reported "severe drift":
	--      the baked (left, top) already reflects the padding/gap Figma
	--      solved at export time, and the live UIListLayout would then apply
	--      that same padding/gap a second time.
	--   2. This is a Figma layer with resize constraints -> constraint-based
	--      AnchorPoint/Position/Size (fixes non-SCALE constraints drifting
	--      under the old position-based anchor guess).
	--   3. Everything else (PSD layers, or FIG layers with no constraint
	--      data) -> the original scale-only heuristic, unchanged.
	local geometryMode = FigmaLayout.geometryMode(parentLayout, layer.layoutPositioning, layer.constraints)
	if geometryMode == "AUTO_LAYOUT" then
		applyAutoLayoutChildSize(instance, layer, bounds, parentLayout)
	elseif geometryMode == "CONSTRAINTS" then
		applyFigmaConstraintGeometry(instance, bounds, parentBounds, layer.constraints)
	else
		applyGeometry(instance, bounds, parentBounds)
	end

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
			createLayer(child, instance, bounds, canvasBounds, sourceType, useCompositeArtwork, childLayout)
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
		createLayer(layer, canvas, canvasBounds, canvasBounds, sourceType, useCompositeArtwork, nil)
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
