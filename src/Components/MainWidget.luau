local MainWidget = {}

function MainWidget.new(plugin)
	local info = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false,
		false,
		300,
		200,
		250,
		150
	)

	local widget = plugin:CreateDockWidgetPluginGui("UIImporterPro", info)
	widget.Title = "UI Importer Pro"
	
	local container = Instance.new("Frame")
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	container.Parent = widget
	
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.8, 0, 0.2, 0)
	button.Position = UDim2.fromScale(0.5, 0.5)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Text = "Fix Selected UI"
	button.Parent = container
	
	return widget, button
end

return MainWidget
