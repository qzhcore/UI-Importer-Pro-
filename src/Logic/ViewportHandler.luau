local ViewportHandler = {}

local Constants = require(script.Parent.Parent.Shared.Constants)

function ViewportHandler.GetResolution(instance)
	local screen = instance:FindFirstAncestorWhichIsA("LayerCollector")
	
	if screen then
		return screen.AbsoluteSize
	end
	
	return Constants.CANVAS_SIZE
end

function ViewportHandler.GetScaleFromOffset(offset, resolution)
	return offset / resolution
end

return ViewportHandler
