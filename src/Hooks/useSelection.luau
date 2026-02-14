local Selection = game:GetService("Selection")

local useSelection = {}

function useSelection.get()
	local currentSelection = Selection:Get()
	local validObjects = {}

	for _, instance in ipairs(currentSelection) do
		if instance:IsA("GuiObject") or instance:IsA("ScreenGui") then
			table.insert(validObjects, instance)
		end
	end

	return validObjects
end

return useSelection
