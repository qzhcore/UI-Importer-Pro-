local BackgroundFilter = {}

local NAMES = { background = true, canvasbackground = true, documentbackground = true, artboardbackground = true }

-- Only root backdrop layers are candidates. A panel's own background is part of its UI.
function BackgroundFilter.apply(document, options)
	if options and options.includeBackground == true then
		return document
	end
	local removed = 0
	local roots = {}
	for _, layer in ipairs(document.tree) do
		local name = string.lower(string.gsub(layer.name, "[%s_-]", ""))
		local coversCanvas = layer.left <= 1
			and layer.top <= 1
			and layer.left + layer.width >= document.width - 1
			and layer.top + layer.height >= document.height - 1
		local explicitRole = string.match(layer.name, "^%s*%[") ~= nil
		local backdrop = layer.isDocumentBackground == true
			or (NAMES[name] and coversCanvas and not explicitRole and not layer.text and #layer.children == 0)
		if backdrop then
			removed += 1
		else
			table.insert(roots, layer)
		end
	end
	if removed == 0 then
		return document
	end
	if options and options.visualMode == "Reference" then
		error(
			"The reference image contains a flattened background. Use Editable layers to exclude it, or enable Include document background.",
			0
		)
	end
	if #roots == 0 then
		error("Only a document background was found. Enable Include document background to import it.", 0)
	end
	local layers = {}
	local function visit(layer)
		layer.index = #layers + 1
		table.insert(layers, layer)
		for _, child in ipairs(layer.children) do
			visit(child)
		end
	end
	for _, root in ipairs(roots) do
		visit(root)
	end
	document.tree = roots
	document.layers = layers
	document.excludedBackgrounds = removed
	return document
end

return BackgroundFilter
