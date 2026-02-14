local Selection = game:GetService("Selection")

local SelectionHandler = {}

function SelectionHandler.GetSelectedGuiObjects(): {GuiObject}
	local selected = Selection:Get()
	local valid = {}
	
	for _, instance in ipairs(selected) do
		if instance:IsA("GuiObject") then
			table.insert(valid, instance)
		end
	end
	
	return valid
end

function SelectionHandler.Observe(callback: ({Instance}) -> ())
	return Selection.SelectionChanged:Connect(function()
		callback(Selection:Get())
	end)
end

return SelectionHandler
