local FileParser = {}

local ScalingEngine = require(script.Parent.ScalingEngine)
local Constants = require(script.Parent.Parent.Shared.Constants)

local supportedClasses = {}
for _, className in ipairs(Constants.SUPPORTED_CLASSES) do
	supportedClasses[className] = true
end

function FileParser.validate(instance)
	return instance:IsA("ScreenGui") or (instance:IsA("GuiObject") and supportedClasses[instance.ClassName] == true)
end

function FileParser.identify(instances)
	local valid = {}
	for _, obj in ipairs(instances) do
		if FileParser.validate(obj) then
			table.insert(valid, obj)
		end
	end

	return valid
end

function FileParser.processImported(instances)
	local processed = 0
	for _, obj in ipairs(FileParser.identify(instances)) do
		processed += ScalingEngine.ProcessRecursive(obj)
	end

	return processed
end

return FileParser
