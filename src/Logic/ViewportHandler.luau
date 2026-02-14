local ViewportHandler = {}

function ViewportHandler.GetViewportSize(gui: LayerCollector?)
	if gui then
		return gui.AbsoluteSize
	end
	
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1920, 1080)
end

function ViewportHandler.GetAspectRatio(size: Vector2)
	return size.X / size.Y
end

function ViewportHandler.IsMobile(size: Vector2)
	return size.X < 700 or size.Y < 500
end

return ViewportHandler
