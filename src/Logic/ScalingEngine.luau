local ScalingEngine = {}

local function getAbsoluteSize(instance)
	if instance:IsA("GuiObject") then
		return instance.AbsoluteSize
	elseif instance:IsA("ScreenGui") then
		return instance.AbsoluteSize
	end
	return Vector2.new(1920, 1080)
end

function ScalingEngine.ToScale(instance)
	if not instance:IsA("GuiObject") then return end
	
	local parent = instance.Parent
	local parentSize = getAbsoluteSize(parent)
	
	local absSize = instance.AbsoluteSize
	local absPos = instance.AbsolutePosition
	
	instance.Size = UDim2.fromScale(
		absSize.X / parentSize.X, 
		absSize.Y / parentSize.Y
	)
	
	instance.Position = UDim2.fromScale(
		absPos.X / parentSize.X, 
		absPos.Y / parentSize.Y
	)
end

function ScalingEngine.ApplyConstraints(instance)
	if not instance:IsA("GuiObject") then return end
	if instance:FindFirstChildWhichIsA("UIAspectRatioConstraint") then return end

	local absSize = instance.AbsoluteSize
	if absSize.X > 0 and absSize.Y > 0 then
		local constraint = Instance.new("UIAspectRatioConstraint")
		constraint.AspectRatio = absSize.X / absSize.Y
		constraint.Parent = instance
	end
end

function ScalingEngine.ProcessRecursive(root)
	ScalingEngine.ToScale(root)
	ScalingEngine.ApplyConstraints(root)
	
	for _, child in ipairs(root:GetChildren()) do
		ScalingEngine.ProcessRecursive(child)
	end
end

return ScalingEngine
