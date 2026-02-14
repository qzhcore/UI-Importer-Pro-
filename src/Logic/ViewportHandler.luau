local ViewportHandler = {}

function ViewportHandler.GetViewportSize(pluginGui)
	if pluginGui and pluginGui:IsA("DockWidgetPluginGui") then
		return pluginGui.AbsoluteSize
	end
	
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	
	return Vector2.new(1920, 1080)
end

function ViewportHandler.GetDeviceType(size)
	local aspectRatio = size.X / size.Y
	
	if aspectRatio > 1.8 then
		return "Widescreen"
	elseif aspectRatio < 0.6 then
		return "Mobile"
	end
	return "Standard"
end

return ViewportHandler
