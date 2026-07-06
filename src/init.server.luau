local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FileParser = require(script.Parent.Logic.FileParser)
local Toolbar = require(script.Parent.Plugin.Toolbar)

Toolbar.init(plugin, function()
	local selected = Selection:Get()
	if #selected == 0 then
		return
	end

	ChangeHistoryService:SetWaypoint("UIImporterProBeforeScale")
	FileParser.processImported(selected)
	ChangeHistoryService:SetWaypoint("UIAutoImporterFixFinished")
end)
