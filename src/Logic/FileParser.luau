local FileParser = {}

local ScalingEngine = require(script.Parent.ScalingEngine)

function FileParser.validate(instance)
	return instance:IsA("GuiObject") or instance:IsA("ScreenGui")
end

function FileParser.processImported(instances)
	for _, obj in ipairs(instances) do
		if FileParser.validate(obj) then
			ScalingEngine.ProcessRecursive(obj)
		end
	end
end

return FileParser
