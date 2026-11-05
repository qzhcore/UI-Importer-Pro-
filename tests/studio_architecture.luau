-- Run only in the separate unpublished UIImporter-Test place.
return function(import, globals)
	local game, Instance, UDim2, task = globals.game, globals.Instance, globals.UDim2, globals.task
	assert(game.PlaceId == 0 and game.Name == "UIImporter-Test.rbxl", "Use the dedicated test place")
	local Job, Pipeline, Source = import("ImportJob"), import("ImportPipeline"), import("DesignSource")
	local Reimport = import("ReimportEngine")
	local roots = {}
	local target = Instance.new("Folder")
	local overlay = Instance.new("ScreenGui")
	overlay.Name = "UIImporterArchitectureCheck"
	overlay.IgnoreGuiInset = true
	overlay.Parent = game:GetService("CoreGui")
	local payload = {
		schemaVersion = 1,
		documentId = "native-test",
		width = 400,
		height = 200,
		tree = {
			{
				id = "row",
				name = "Row",
				width = 400,
				height = 200,
				suggestedRole = "Frame",
				layoutMode = "HORIZONTAL",
				paddingLeft = 40,
				paddingRight = 40,
				layoutGap = 20,
				children = {
					{
						id = "title",
						name = "Title",
						width = 100,
						height = 40,
						suggestedRole = "TextLabel",
						text = "Before",
					},
					{ id = "second", name = "Second", width = 100, height = 40, suggestedRole = "Frame" },
					{
						id = "badge",
						name = "Badge",
						x = 360,
						y = 10,
						width = 20,
						height = 20,
						suggestedRole = "Frame",
						layoutPositioning = "ABSOLUTE",
						constraints = { horizontal = "MAX", vertical = "MIN" },
					},
				},
			},
		},
	}
	local function build()
		local job = Job.new()
		local result =
			Pipeline.fromDocument(Source.fromTable(payload, job), "Native", target, { embedImages = false }, job)
		table.insert(roots, result.root)
		return result.root
	end
	local measurements = {}
	local ok, problem = pcall(function()
		local root = build()
		local title = root:FindFirstChild("Title", true)
		local script = Instance.new("LocalScript")
		script.Name = "DeveloperLogic"
		script.Source = "return 'retained'"
		script.Parent = title
		title:SetAttribute("CustomValue", 123)
		local changed = 0
		local connection = title:GetPropertyChangedSignal("Text"):Connect(function()
			changed += 1
		end)
		payload.tree[1].children[1].text = "After"
		local staged = build()
		Reimport.apply(Reimport.plan(root, staged))
		task.wait()
		assert(root:FindFirstChild("Title", true) == title and title.Text == "After", "Native identity mismatch")
		assert(
			script.Parent == title and script.Source == "return 'retained'" and title:GetAttribute("CustomValue") == 123,
			"Developer data lost"
		)
		assert(connection.Connected and changed > 0, "Native event connection lost")
		connection:Disconnect()
		-- Keep the inert script fixture detached; CoreGui has different capabilities.
		script.Parent = target
		local canvas = root.Canvas
		canvas.AnchorPoint = globals.Vector2.zero
		canvas.Position = UDim2.fromScale(0, 0)
		canvas.Parent = overlay
		for _, width in ipairs({ 400, 800 }) do
			canvas.Size = UDim2.fromOffset(width, width / 2)
			task.wait()
			task.wait()
			local row = canvas.Row
			local first = row:FindFirstChild("Title", true)
			local second = row:FindFirstChild("Second", true)
			local badge = row.Badge
			table.insert(measurements, {
				width = width,
				childWidth = first.AbsoluteSize.X,
				left = first.AbsolutePosition.X - row.AbsolutePosition.X,
				gap = second.AbsolutePosition.X - first.AbsolutePosition.X - first.AbsoluteSize.X,
				badgeRight = row.AbsolutePosition.X
					+ row.AbsoluteSize.X
					- badge.AbsolutePosition.X
					- badge.AbsoluteSize.X,
			})
			local actual = measurements[#measurements]
			assert(math.abs(actual.childWidth - width / 4) < 0.1, "Padding changed the child size")
			assert(math.abs(actual.gap - width / 20) < 0.1, "Padding changed the authored gap")
			assert(math.abs(actual.left - width / 10) < 0.1, "Left inset mismatch")
			assert(math.abs(actual.badgeRight - width / 20) < 0.1, "Absolute overlay shifted")
		end
		canvas.Parent = root
	end)
	overlay:Destroy()
	for _, root in ipairs(roots) do
		root:Destroy()
	end
	target:Destroy()
	assert(ok, tostring(problem))
	return measurements
end
