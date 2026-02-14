local Selection = game:GetService("Selection")

local SelectionWatcher = {}

function SelectionWatcher.GetSelectedGuiObjects()
	local selected = Selection:Get()
	local guiObjects = {}

	for _, obj in ipairs(selected) do
		if obj:IsA("GuiObject") or obj:IsA("ScreenGui") then
			table.insert(guiObjects, obj)
		end
	end

	return guiObjects
end

return SelectionWatcher
