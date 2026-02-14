local Toolbar = {}

function Toolbar.init(plugin, onAction)
	local toolbar = plugin:CreateToolbar("UI Importer Pro")
	local button = toolbar:CreateButton(
		"FixScale", 
		"Convert UI to Scale", 
		"rbxassetid://4458901886"
	)

	button.Click:Connect(onAction)
end

return Toolbar
