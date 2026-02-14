local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local ScalingEngine = require(script.Parent.Logic.ScalingEngine)
local Toolbar = require(script.Parent.Plugin.Toolbar)

Toolbar.init(plugin, function()
	local selected = Selection:Get()
	if #selected == 0 then return end
	
	local waypoint = ChangeHistoryService:SetWaypoint("UIAutoImporterFix")
	
	for _, obj in ipairs(selected) do
		ScalingEngine.ProcessRecursive(obj)
	end
	
	ChangeHistoryService:SetWaypoint("UIAutoImporterFixFinished")
end)
