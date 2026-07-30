local Toolbar = {}

local MainWidget = require(script.Parent.Parent.Components.MainWidget)

local BUTTON_ID = "UIImporterPro"
local BUTTON_TEXT = "UI Importer Pro"
local BUTTON_TOOLTIP = "Import layered PSD and Figma UI designs into StarterGui as organized Roblox UI."
local BUTTON_ICON = "rbxassetid://70728428582426"

function Toolbar.init(plugin, onAction)
	local toolbar = plugin:CreateToolbar("UI Importer Pro")
	local button = toolbar:CreateButton(BUTTON_ID, BUTTON_TOOLTIP, BUTTON_ICON, BUTTON_TEXT)
	local widget = MainWidget.new(plugin, onAction)

	local function updateActiveState()
		button:SetActive(widget.Enabled)
	end

	button.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)
	widget:GetPropertyChangedSignal("Enabled"):Connect(updateActiveState)
	updateActiveState()

	return button, widget
end

return Toolbar
