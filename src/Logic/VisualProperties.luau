-- Re-import never writes Name, Parent, scripts, user attributes, tags,
-- interaction behavior, bindings, Adornee, cameras, or event connections.
local VisualProperties = {}
local GUI = {
	"Size",
	"Position",
	"AnchorPoint",
	"Rotation",
	"LayoutOrder",
	"ZIndex",
	"Visible",
	"BackgroundColor3",
	"BackgroundTransparency",
	"BorderSizePixel",
	"ClipsDescendants",
	"AutomaticSize",
}
local TEXT = {
	"Text",
	"TextColor3",
	"TextTransparency",
	"TextStrokeColor3",
	"TextStrokeTransparency",
	"TextSize",
	"TextScaled",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
	"RichText",
	"FontFace",
	"LineHeight",
}
local IMAGE = {
	"Image",
	"ImageContent",
	"ImageColor3",
	"ImageTransparency",
	"ScaleType",
	"TileSize",
	"SliceCenter",
	"SliceScale",
	"ImageRectOffset",
	"ImageRectSize",
}
local CLASSES = {
	ScreenGui = { "ZIndexBehavior" },
	SurfaceGui = { "ZIndexBehavior", "CanvasSize", "SizingMode" },
	BillboardGui = { "ZIndexBehavior", "Size" },
	UIListLayout = {
		"FillDirection",
		"SortOrder",
		"HorizontalAlignment",
		"VerticalAlignment",
		"Padding",
		"Wraps",
		"HorizontalFlex",
		"VerticalFlex",
		"ItemLineAlignment",
	},
	UIGridLayout = {
		"FillDirection",
		"SortOrder",
		"HorizontalAlignment",
		"VerticalAlignment",
		"CellSize",
		"CellPadding",
		"FillDirectionMaxCells",
		"StartCorner",
	},
	UIPageLayout = { "Padding", "FillDirection", "SortOrder", "HorizontalAlignment", "VerticalAlignment" },
	UITableLayout = {
		"Padding",
		"FillDirection",
		"SortOrder",
		"HorizontalAlignment",
		"VerticalAlignment",
		"FillEmptySpaceColumns",
		"FillEmptySpaceRows",
	},
	UIPadding = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" },
	UICorner = { "CornerRadius", "TopLeftRadius", "TopRightRadius", "BottomLeftRadius", "BottomRightRadius" },
	UIStroke = {
		"ApplyStrokeMode",
		"Color",
		"Transparency",
		"Thickness",
		"StrokeSizingMode",
		"LineJoinMode",
		"BorderStrokePosition",
		"Enabled",
	},
	UIGradient = { "Color", "Transparency", "Rotation", "Offset", "Enabled" },
	UIShadow = { "Color", "Transparency", "BlurRadius", "Offset", "Spread", "ZIndex" },
	UIAspectRatioConstraint = { "AspectRatio", "AspectType", "DominantAxis" },
	UISizeConstraint = { "MinSize", "MaxSize" },
	UITextSizeConstraint = { "MinTextSize", "MaxTextSize" },
	UIScale = { "Scale" },
	UIFlexItem = { "FlexMode", "GrowRatio", "ShrinkRatio", "ItemLineAlignment" },
}

function VisualProperties.list(instance)
	local result = {}
	local function append(properties)
		for _, name in ipairs(properties) do
			table.insert(result, name)
		end
	end
	if instance:IsA("GuiObject") then
		append(GUI)
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		append(TEXT)
	end
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		append(IMAGE)
	end
	if instance:IsA("ScrollingFrame") then
		append({
			"CanvasSize",
			"AutomaticCanvasSize",
			"ScrollBarThickness",
			"ScrollBarImageColor3",
			"ScrollBarImageTransparency",
		})
	end
	append(CLASSES[instance.ClassName] or {})
	return result
end

return VisualProperties
