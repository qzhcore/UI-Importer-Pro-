-- This tail is bundled with production module factories for the Studio MCP smoke test.
-- Uses detached objects only; never parents generated UI into the open place.
return function(import, fixture, globals)
	local Instance = globals.Instance
	local Enum = globals.Enum
	local game = globals.game
	local Vector2 = globals.Vector2
	local ImportJob = import("ImportJob")
	local UIBuilder = import("UIBuilder")
	local DesignDocument = import("DesignDocument")
	local AssetUploader = import("AssetUploader")
	local target = Instance.new("Folder")
	local roots = {}
	local count = 0
	local ok, message = pcall(function()
		for _, className in ipairs({ "ScreenGui", "SurfaceGui", "BillboardGui" }) do
			local result = import("ImportPipeline").convert(fixture(), "FIG", "Smoke", target, {
				layerCollectorClass = className,
			}, ImportJob.new())
			table.insert(roots, result.root)
			assert(result.root.ClassName == className and result.root.Parent == nil, "Invalid detached root")
			local title = result.root:FindFirstChild("Title", true)
			assert(
				title.Text == "Play" and title.TextSize == 20 and title.TextTransparency == 0,
				"Text conversion failed"
			)
			assert(title:GetAttribute("UIImporterSourceId") == "FIG:0:3", "Missing source ID")
			count += 1
		end
		local flowJob = ImportJob.new()
		local flowDoc = DesignDocument.normalize({
			sourceType = "FIG",
			width = 400,
			height = 300,
			tree = {
				{
					name = "Card",
					width = 200,
					height = 100,
					suggestedRole = "Frame",
					layoutMode = "HORIZONTAL",
					layoutWrap = "WRAP",
					paddingLeft = 8,
					layoutGap = 12,
					children = {
						{ name = "Flow", width = 40, height = 40, layoutPositioning = "AUTO", suggestedRole = "Frame" },
						{
							name = "Badge",
							width = 20,
							height = 20,
							left = 160,
							layoutPositioning = "ABSOLUTE",
							suggestedRole = "Frame",
						},
					},
				},
			},
		}, flowJob)
		local flowResult = UIBuilder.build(flowDoc, "FlowSmoke", target, nil, { embedImages = false }, flowJob)
		table.insert(roots, flowResult.root)
		local card = flowResult.root:FindFirstChild("Card", true)
		local flow = card:FindFirstChild("Flow", true)
		local badge = card:FindFirstChild("Badge", true)
		assert(badge.Parent == card and flow.Parent ~= card, "Absolute children entered auto-layout")
		assert(flow.Parent:FindFirstChildWhichIsA("UIListLayout").Wraps, "Native wrapping was not applied")
		count += 1
		local pixels = buffer.create(16)
		for offset = 0, 12, 4 do
			buffer.writeu32(pixels, offset, 0xFF0000FF)
		end
		local job = ImportJob.new()
		local doc = DesignDocument.normalize({
			sourceType = "PSD",
			width = 2,
			height = 2,
			tree = { { name = "Red", width = 2, height = 2, pixels = pixels, suggestedRole = "ImageLabel" } },
		}, job)
		local result = UIBuilder.build(doc, "ImageSmoke", target, nil, {}, job)
		table.insert(roots, result.root)
		local image = result.root:FindFirstChild("Red", true)
		assert(image.ImageContent.SourceType == Enum.ContentSourceType.Opaque, "Missing session image content")
		assert(result.root:GetAttribute("UIImporterImageStorage") == "Session", "Missing temporary artwork marker")
		assert(#result.warnings > 0, "Missing persistence warning")
		-- Reopen the baked content to check the actual pixels after the uploader destroyed its source.
		local copy = game:GetService("AssetService"):CreateEditableImageAsync(image.ImageContent)
		assert(copy, "Could not reopen baked image")
		local actual = copy:ReadPixelsBuffer(Vector2.zero, Vector2.new(2, 2))
		copy:Destroy()
		assert(buffer.tostring(actual) == buffer.tostring(pixels), "Baked image pixels changed")
		assert(AssetUploader.countTiles({ pixels = pixels, width = 2, height = 2 }) == 1, "Wrong tile count")
		count += 1
		assert(#target:GetChildren() == 0, "Smoke test attached generated UI")
	end)
	for _, root in ipairs(roots) do
		root:Destroy()
	end
	target:Destroy()
	assert(ok, tostring(message))
	return string.format(
		"Passed %d native Studio smoke cases; all test objects destroyed. No place content changed and no assets uploaded.",
		count
	)
end
