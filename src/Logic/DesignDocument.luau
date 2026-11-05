-- Validated interchange format between source readers and Roblox generation.
local DesignDocument = {}

export type Layer = {
	[string]: any,
	sourceId: string,
	name: string,
	index: number,
	left: number,
	top: number,
	width: number,
	height: number,
	opacity: number,
	visible: boolean,
	children: { Layer },
}

export type Document = {
	[string]: any,
	schemaVersion: number,
	sourceType: string,
	width: number,
	height: number,
	tree: { Layer },
	layers: { Layer },
	warnings: { string },
}

local function finite(value, label)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		error("Invalid design " .. label .. ".", 0)
	end
	return value
end

function DesignDocument.normalize(document, job): Document
	if type(document) ~= "table" or type(document.tree) ~= "table" then
		error("The source reader did not produce a design tree.", 0)
	end
	if document.sourceType ~= "PSD" and document.sourceType ~= "FIG" and document.sourceType ~= "JSON" then
		error("Unsupported design source.", 0)
	end
	if finite(document.width, "width") <= 0 or finite(document.height, "height") <= 0 then
		error("The design canvas must have positive dimensions.", 0)
	end
	local normalized = table.clone(document)
	normalized.schemaVersion = 1
	normalized.warnings = table.clone(document.warnings or {})
	normalized.layers = {}
	normalized.stableIds = true
	local seen = {}
	local ids = {}
	local pixelsSeen = {}
	local totalPixels = 0
	if document.compositePixels then
		local width = document.compositeWidth or document.width
		local height = document.compositeHeight or document.height
		job:checkImage(width, height)
		if
			typeof(document.compositePixels) ~= "buffer"
			or buffer.len(document.compositePixels) ~= width * height * 4
		then
			error("The reference image has invalid RGBA data.", 0)
		end
		totalPixels = width * height * 4
	end
	local function visit(source, depth, path)
		job:checkpoint()
		if depth > job.limits.depth or #normalized.layers >= job.limits.layers then
			error("The design exceeds the layer-count or nesting limit.", 0)
		end
		if type(source) ~= "table" or seen[source] then
			error("The design contains a repeated or cyclic layer.", 0)
		end
		seen[source] = true
		local layer = table.clone(source)
		layer.name = tostring(source.name or "Layer")
		layer.left = finite(source.left or 0, "layer position")
		layer.top = finite(source.top or 0, "layer position")
		layer.width = finite(source.width or 0, "layer width")
		layer.height = finite(source.height or 0, "layer height")
		if layer.width < 0 or layer.height < 0 then
			error("A design layer has negative dimensions.", 0)
		end
		layer.rotation = finite(source.rotation or 0, "rotation")
		for _, key in ipairs({
			"textSize",
			"fontWeight",
			"minTextSize",
			"maxTextSize",
			"layoutGap",
			"counterAxisSpacing",
			"layoutGrow",
			"paddingLeft",
			"paddingRight",
			"paddingTop",
			"paddingBottom",
			"cornerRadius",
			"strokeThickness",
			"gridColumns",
			"backgroundTransparency",
			"imageOpacity",
		}) do
			if source[key] ~= nil then
				finite(source[key], key)
			end
		end
		if source.suggestedRole then
			local allowed = {
				Frame = true,
				ScrollingFrame = true,
				ImageLabel = true,
				ImageButton = true,
				TextLabel = true,
				TextButton = true,
				TextBox = true,
				ViewportFrame = true,
				VideoFrame = true,
			}
			assert(allowed[source.suggestedRole], "Unsupported design role " .. tostring(source.suggestedRole))
		end
		if source.textRuns then
			assert(type(source.textRuns) == "table", "Invalid text runs")
			for _, run in ipairs(source.textRuns) do
				assert(type(run) == "table" and type(run.text) == "string", "Invalid text run")
				if run.fontWeight then
					finite(run.fontWeight, "run weight")
				end
				if run.textSize then
					finite(run.textSize, "run size")
				end
			end
		end
		if source.gridCellSize then
			assert(
				finite(source.gridCellSize.width, "grid width") > 0
					and finite(source.gridCellSize.height, "grid height") > 0,
				"Invalid grid cells"
			)
		end
		if source.minTextSize then
			assert(source.minTextSize >= 1 and source.minTextSize <= 100, "minTextSize must be between 1 and 100")
		end
		if source.maxTextSize then
			assert(
				source.maxTextSize >= (source.minTextSize or 10) and source.maxTextSize <= 100,
				"maxTextSize must be at least minTextSize and no greater than 100"
			)
		end
		layer.index = #normalized.layers + 1
		layer.opacity = math.clamp(finite(source.opacity or 255, "opacity"), 0, 255)
		layer.visible = source.visible ~= false
		local sourceKey = source.figmaNodeId or source.psdLayerId
		local id = source.sourceId or document.sourceType .. ":" .. tostring(sourceKey or ("path:" .. path))
		assert(type(id) == "string" and #id > 0, "Source IDs must be nonempty strings")
		if not source.sourceId and sourceKey == nil then
			normalized.stableIds = false
		end
		-- Component children can share the definition's GUID across instances.
		if ids[id] then
			id ..= "@" .. path
			normalized.stableIds = false
		end
		ids[id] = true
		layer.sourceId = id
		if source.pixels then
			local width = source.pixelWidth or layer.width
			local height = source.pixelHeight or layer.height
			job:checkImage(width, height)
			if typeof(source.pixels) ~= "buffer" or buffer.len(source.pixels) ~= width * height * 4 then
				error("A layer has invalid RGBA pixel data: " .. layer.name, 0)
			end
			if not pixelsSeen[source.pixels] then
				pixelsSeen[source.pixels] = true
				totalPixels += width * height * 4
			end
			if totalPixels > job.limits.decodedBytes then
				error("The design exceeds the decoded-data budget.", 0)
			end
		end
		table.insert(normalized.layers, layer)
		layer.children = {}
		for index, child in ipairs(source.children or {}) do
			table.insert(layer.children, visit(child, depth + 1, path .. "/" .. index))
		end
		return layer
	end
	normalized.tree = {}
	for index, layer in ipairs(document.tree) do
		table.insert(normalized.tree, visit(layer, 1, tostring(index)))
	end
	if #normalized.layers == 0 then
		error("The design contains no importable layers.", 0)
	end
	if not normalized.stableIds then
		table.insert(
			normalized.warnings,
			"Some source layers lack unique durable IDs. This design can create a new import, but cannot safely update an existing import."
		)
	end
	return normalized
end

return DesignDocument
