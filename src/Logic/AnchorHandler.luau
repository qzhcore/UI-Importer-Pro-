local AnchorHandler = {}

function AnchorHandler.CenterAnchor(guiObject)
	if not guiObject:IsA("GuiObject") then return end

	local oldAnchor = guiObject.AnchorPoint
	local newAnchor = Vector2.new(0.5, 0.5)
	
	if oldAnchor == newAnchor then return end

	local size = guiObject.Size
	local position = guiObject.Position

	guiObject.AnchorPoint = newAnchor
	guiObject.Position = UDim2.new(
		position.X.Scale + (size.X.Scale * (0.5 - oldAnchor.X)),
		position.X.Offset + (size.X.Offset * (0.5 - oldAnchor.X)),
		position.Y.Scale + (size.Y.Scale * (0.5 - oldAnchor.Y)),
		position.Y.Offset + (size.Y.Offset * (0.5 - oldAnchor.Y))
	)
end

return AnchorHandler
