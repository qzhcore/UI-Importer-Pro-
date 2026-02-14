local ScalingEngine = {}

local AnchorHandler = require(script.Parent.AnchorHandler)

function ScalingEngine.ToScale(instance)
	if not instance:IsA("GuiObject") then return end
	
	AnchorHandler.CenterAnchor(instance)
	
	local parent = instance.Parent
	local parentSize = (parent:IsA("GuiObject") or parent:IsA("LayerCollector")) and parent.AbsoluteSize or Vector2.new(1920, 1080)
	
	local absSize = instance.AbsoluteSize
	local absPos = instance.AbsolutePosition
	
	instance.Size = UDim2.fromScale(absSize.X / parentSize.X, absSize.Y / parentSize.Y)
	instance.Position = UDim2.fromScale(absPos.X / parentSize.X, absPos.Y / parentSize.Y)
end

function ScalingEngine.ProcessRecursive(root)
	ScalingEngine.ToScale(root)
	
	for _, child in ipairs(root:GetChildren()) do
		ScalingEngine.ProcessRecursive(child)
	end
end

return ScalingEngine
