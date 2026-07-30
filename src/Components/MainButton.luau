local MainButton = {}

function MainButton.new(parent, text, callback)
	local button = Instance.new("TextButton")
	button.Name = "ImportButton"
	button.LayoutOrder = 4
	button.Size = UDim2.new(1, 0, 0, 42)
	button.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	button.MouseButton1Click:Connect(callback)
	button.Parent = parent

	return button
end

return MainButton
