local RenderPolicy = {}
local FontMapper = require(script.Parent.FontMapper)

function RenderPolicy.prepare(document, options)
	local mode = options and options.visualMode or "Editable"
	if mode ~= "Editable" and mode ~= "Reference" then
		error("Unsupported artwork mode: " .. tostring(mode))
	end
	if mode == "Reference" then
		if not document.compositePixels or (options and options.embedImages == false) then
			error("This file has no readable reference image. Choose Editable layers instead.", 0)
		end
		table.insert(document.warnings, "Reference image mode creates a static image, without editable controls.")
		if document.sourceType == "FIG" then
			table.insert(
				document.warnings,
				"The Figma reference is the file thumbnail; its resolution and selected region are controlled by Figma."
			)
		end
		return mode
	end
	for _, layer in ipairs(document.layers) do
		local reasons = {}
		local complex = layer.requiresRenderedFallback
			or layer.complexVector
			or layer.specularMap
			or (layer.fillGradient and layer.fillGradient.type ~= "GRADIENT_LINEAR")
			or (layer.strokeGradient and layer.strokeGradient.type ~= "GRADIENT_LINEAR")
		if layer.imageAssetId ~= nil then
			assert(
				type(layer.imageAssetId) == "string" and string.match(layer.imageAssetId, "^rbxassetid://[1-9]%d*$"),
				"Image asset references must use rbxassetid:// followed by a positive numeric ID"
			)
			layer.renderAsImage = true
		end
		if complex then
			layer.renderAsImage = true
			layer.pixels = nil
			if not layer.imageAssetId then
				table.insert(
					reasons,
					"transparent PNG fallback required: export this layer, upload it to Roblox, and supply imageAssetId = rbxassetid://ID; artwork is not yet rendered"
				)
			end
		end
		if layer.renderAsImage then
			layer.fillGradient, layer.strokeGradient = nil, nil
			layer.backgroundColor, layer.backgroundTransparency = nil, 1
			layer.effects, layer.strokeColor, layer.strokeThickness = nil, nil, nil
		end
		if layer.fontFamily then
			local mapped, substituted = FontMapper.resolve(layer.fontFamily)
			if substituted then
				table.insert(reasons, "font " .. layer.fontFamily .. " substituted with " .. mapped)
			end
		end
		if
			layer.primaryAxisSizingMode == "AUTO"
			or layer.counterAxisSizingMode == "AUTO"
			or string.find(tostring(layer.primaryAxisSizingMode), "RESIZE_TO_FIT", 1, true)
			or string.find(tostring(layer.counterAxisSizingMode), "RESIZE_TO_FIT", 1, true)
			or layer.primaryAxisSizingMode == "HUG"
			or layer.counterAxisSizingMode == "HUG"
		then
			table.insert(
				reasons,
				"hug contents uses its exported bounds to avoid a circular dependency with Scale-only children"
			)
		end
		if layer.layoutWrap == "WRAP" and layer.counterAxisSpacing then
			table.insert(reasons, "independent wrapped-line spacing is not represented by UIListLayout")
		end
		if layer.counterAxisAlignItems == "BASELINE" then
			table.insert(reasons, "baseline alignment uses start alignment")
		end
		if layer.requiresRenderedFallback then
			table.insert(reasons, "some Figma artwork cannot be rendered natively")
		end
		if layer.hasLayerEffects and layer.unsupportedPsdEffects ~= false then
			table.insert(
				reasons,
				"some Photoshop effects are not rendered; supported color overlays and text strokes are applied"
			)
		end
		if layer.clipping and layer.clipping ~= 0 then
			table.insert(reasons, "Photoshop clipping groups are not rendered")
		end
		if
			layer.blendMode
			and layer.blendMode ~= "norm"
			and layer.blendMode ~= "normal"
			and layer.blendMode ~= "pass"
			and layer.blendMode ~= "NORMAL"
			and layer.blendMode ~= "PASS_THROUGH"
		then
			table.insert(reasons, "blend mode " .. layer.blendMode .. " is approximated")
		end
		if layer.unsupportedMask then
			table.insert(reasons, "this Photoshop mask requires a rendered layer export")
		end
		if
			layer.pixels
			and layer.imageScaleMode
			and layer.imageScaleMode ~= "STRETCH"
			and ((layer.pixelWidth or layer.width) > 1024 or (layer.pixelHeight or layer.height) > 1024)
		then
			table.insert(
				reasons,
				"image fills larger than 1024 pixels use stretched tiles; crop the artwork to the layer bounds before importing"
			)
		end
		if #reasons > 0 then
			layer.importWarning = table.concat(reasons, "; ")
			table.insert(document.warnings, layer.name .. ": " .. layer.importWarning .. ".")
		end
	end
	return mode
end

return RenderPolicy
