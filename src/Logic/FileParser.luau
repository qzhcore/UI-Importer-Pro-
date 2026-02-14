local FileParser = {}

local ScalingEngine = require(script.Parent.ScalingEngine)

function FileParser.SanitizeAndProcess(instances)
	for _, instance in ipairs(instances) do
		if instance:IsA("GuiObject") then
			ScalingEngine.ProcessRecursive(instance)
		elseif instance:IsA("Instance") then
			for _, child in ipairs(instance:GetChildren()) do
				FileParser.SanitizeAndProcess({child})
			end
		end
	end
end

return FileParser
