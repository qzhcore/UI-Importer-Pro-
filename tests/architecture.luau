local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local loader = require("./ModuleLoader")
local modules = loader(roblox, {
	AssetUploader = {
		countTiles = function()
			return 0
		end,
		createLayerContent = function()
			return {}
		end,
	},
})
local Job = modules("ImportJob")
local Source = modules("DesignSource")
local Pipeline = modules("ImportPipeline")
local Reimport = modules("ReimportEngine")
local passed = 0
local function expect(condition, message)
	assert(condition, message or "Expectation failed; see named regression case")
end
local function test(name, callback)
	local ok, problem = pcall(callback)
	expect(ok, name .. ": " .. tostring(problem))
	passed += 1
	print("PASS " .. name)
end
local function near(a, b)
	expect(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b))
end
local function fails(callback, expected)
	local ok, problem = pcall(callback)
	expect(not ok and string.find(tostring(problem), expected, 1, true), tostring(problem))
end
local function payload()
	return {
		schemaVersion = 1,
		documentId = "test-document",
		width = 1920,
		height = 1080,
		tree = {
			{
				id = "panel",
				name = "Panel",
				x = 192,
				y = 108,
				width = 960,
				height = 540,
				suggestedRole = "Frame",
				children = {
					{
						id = "title",
						name = "Title",
						x = 480,
						y = 54,
						width = 384,
						height = 108,
						text = "Before",
						suggestedRole = "TextLabel",
						constraints = { horizontal = "MAX", vertical = "CENTER" },
						fontFamily = "Inter",
						textSize = 24,
					},
					{
						id = "avatar",
						name = "Avatar",
						x = 96,
						y = 108,
						width = 108,
						height = 108,
						suggestedRole = "Frame",
						shape = "AVATAR",
					},
				},
			},
		},
	}
end
local function build(data)
	local target = roblox.Instance.new("Folder")
	local job = Job.new()
	local result =
		Pipeline.fromDocument(Source.fromTable(data or payload(), job), "Fixture", target, { embedImages = false }, job)
	expect(result.root.Parent == nil and #target:GetChildren() == 0)
	target:Destroy()
	return result.root, result
end
local function byId(root, id)
	for _, child in ipairs(root:GetDescendants()) do
		if child:GetAttribute("DesignUID") == "JSON:" .. id then
			return child
		end
	end
	error("Missing " .. id)
end

test("nested right anchors reproduce geometry at mobile, design, and 4K sizes", function()
	local root = build()
	local panel, title = byId(root, "panel"), byId(root, "title")
	near(title.Size.X.Scale, 384 / 960)
	near(title.Position.X.Scale, 0.9)
	expect(title.AnchorPoint == roblox.Vector2.new(1, 0.5))
	for _, viewport in ipairs({ { 390, 844 }, { 1920, 1080 }, { 3840, 2160 } }) do
		local pw = panel.Size.X.Scale * viewport[1]
		local width = title.Size.X.Scale * pw
		local left = title.Position.X.Scale * pw - title.AnchorPoint.X * width
		near(left / pw, 0.5)
		near((pw - left - width) / pw, 0.1)
	end
	for _, object in ipairs(root:GetDescendants()) do
		if object:IsA("GuiObject") then
			expect(
				object.Size.X.Offset == 0
					and object.Size.Y.Offset == 0
					and object.Position.X.Offset == 0
					and object.Position.Y.Offset == 0
			)
		end
		expect(type(object:GetAttribute("DesignUID")) == "string")
	end
	expect(root.ZIndexBehavior == roblox.Enum.ZIndexBehavior.Sibling)
	expect(byId(root, "avatar"):FindFirstChildWhichIsA("UIAspectRatioConstraint").AspectRatio == 1)
	expect(title.TextWrapped and title.TextScaled and title.ResponsiveTextSize.MinTextSize == 10)
	root:Destroy()
end)

test("native grids, proportional padding, weighted flex, and absolute overlays coexist", function()
	local data = payload()
	local panel = data.tree[1]
	panel.layoutMode = "GRID"
	panel.gridCellSize = { width = 200, height = 100 }
	panel.gridColumns = 3
	panel.layoutGap = 24
	panel.paddingLeft = 48
	panel.children[2].layoutPositioning = "ABSOLUTE"
	local root = build(data)
	local uiPanel, avatar = byId(root, "panel"), byId(root, "avatar")
	local flow = uiPanel.LayoutContent
	expect(avatar.Parent == uiPanel and byId(root, "title").Parent == flow)
	near(flow.ImportedAutoLayout.CellSize.X.Scale, 200 / (960 - 48))
	near(flow.ImportedAutoLayout.CellPadding.Y.Scale, 24 / 540)
	near(flow.ImportedPadding.PaddingLeft.Scale, 48 / 960)
	expect(flow.ImportedAutoLayout.FillDirectionMaxCells == 3)
	root:Destroy()
	panel.layoutMode = "HORIZONTAL"
	panel.primaryAxisAlignItems = "SPACE_BETWEEN"
	panel.children[1].layoutGrow = 2
	panel.children[1].layoutAlign = "STRETCH"
	root = build(data)
	local flex = byId(root, "title").ImportedAutoLayoutItem
	expect(flex.GrowRatio == 2 and flex.ItemLineAlignment == roblox.Enum.ItemLineAlignment.Stretch)
	expect(
		byId(root, "panel").LayoutContent.ImportedAutoLayout.HorizontalFlex == roblox.Enum.UIFlexAlignment.SpaceBetween
	)
	root:Destroy()
end)

test("rich text escapes source markup and preserves mixed Unicode styles", function()
	local text, rich = modules("RichTextCompiler").compile("", {
		{ text = "A < B & " },
		{ text = "勝利", bold = true, italic = true, color = { r = 1, g = 0.5, b = 0 } },
	})
	expect(rich and string.find(text, "A &lt; B &amp; ", 1, true))
	expect(string.find(text, "<i><b>勝利</b></i>", 1, true))
	expect(string.find(text, 'color="rgb(255,128,0)"', 1, true))
	local raw, enabled = modules("RichTextCompiler").compile("<b>literal</b>")
	expect(raw == "<b>literal</b>" and enabled == false)
end)

test("complex vectors require explicit transparent artwork and validate asset IDs", function()
	local data = payload()
	local title = data.tree[1].children[1]
	title.complexVector = true
	local root, result = build(data)
	expect(byId(root, "title").ClassName == "ImageLabel")
	expect(byId(root, "title"):GetAttribute("UIImporterRequiresImage"))
	expect(#result.warnings > 0)
	root:Destroy()
	title.imageAssetId = "rbxassetid://12345"
	root = build(data)
	expect(byId(root, "title").Image == title.imageAssetId)
	expect(not byId(root, "title"):GetAttribute("UIImporterRequiresImage"))
	root:Destroy()
	title.imageAssetId = "https://untrusted.invalid/image.png"
	fails(function()
		build(data)
	end, "rbxassetid://")
end)

test("JSON decoding and HTTP failures are caught with actionable diagnostics", function()
	local http = {
		JSONDecode = function(_, data)
			return serde.decode("json", data)
		end,
	}
	local doc = Source.decode(serde.encode("json", payload()), Job.new(), http)
	expect(doc.tree[1].children[1].left == 672)
	fails(function()
		Source.decode("{oops", Job.new(), http)
	end, "JSON decoding failed")
	http.RequestAsync = function()
		error("HTTP requests disabled")
	end
	fails(function()
		Source.fetch("https://example.com/ui", Job.new(), http)
	end, "Allow HTTP Requests")
	http.RequestAsync = function()
		return { Success = false, StatusCode = 403 }
	end
	fails(function()
		Source.fetch("https://example.com/ui", Job.new(), http)
	end, "403")
	fails(function()
		Source.fetch("http://example.com/ui", Job.new(), http)
	end, "HTTPS")
end)

test("invalid JSON IDs and cyclic API nodes are rejected before generation", function()
	local data = payload()
	data.tree[1].children[1].id = "panel"
	fails(function()
		build(data)
	end, "unique")
	data = payload()
	data.tree[1].children = { data.tree[1] }
	fails(function()
		build(data)
	end, "cyclic")
	data = payload()
	data.tree[1].suggestedRole = "LocalScript"
	fails(function()
		build(data)
	end, "Unsupported design role")
end)

test("re-import retains instance identity, script source, custom data, names, and sounds", function()
	local root = build()
	local title = byId(root, "title")
	title.Name = "DeveloperTitle"
	title:SetAttribute("Price", 500)
	title:AddTag("GameplayBinding")
	local owned = {}
	for _, class in ipairs({ "LocalScript", "ModuleScript", "Configuration", "Sound" }) do
		local child = roblox.Instance.new(class)
		child.Name = "Custom" .. class
		if child:IsA("LuaSourceContainer") then
			child.Source = "return 'developer code'"
		end
		child.Parent = title
		table.insert(owned, child)
	end
	local data = payload()
	data.tree[1].children[1].name = "RenamedInDesign"
	data.tree[1].children[1].text = "After"
	data.tree[1].children[1].width = 480
	local staged = build(data)
	local plan = Reimport.plan(root, staged)
	expect(title.Text == "Before", "Planning mutated content")
	Reimport.apply(plan)
	expect(byId(root, "title") == title and title.Name == "DeveloperTitle" and title.Text == "After")
	expect(title:GetAttribute("Price") == 500 and title:HasTag("GameplayBinding"))
	for _, child in ipairs(owned) do
		expect(child.Parent == title)
		if child:IsA("LuaSourceContainer") then
			expect(child.Source == "return 'developer code'")
		end
	end
	near(title.Size.X.Scale, 0.5)
	expect(#Reimport.plan(root, staged).entries == #plan.entries, "Repeat import duplicated helpers")
	root:Destroy()
	staged:Destroy()
end)

test("removed and reparented source nodes retain existing developer paths", function()
	local root = build()
	local title = byId(root, "title")
	local parent = title.Parent
	local position, size = title.Position, title.Size
	local data = payload()
	local moved = table.remove(data.tree[1].children, 1)
	table.insert(data.tree, moved)
	data.tree[1].children = {}
	local staged = build(data)
	local plan = Reimport.plan(root, staged)
	expect(#plan.warnings >= 2)
	Reimport.apply(plan)
	expect(title.Parent == parent and byId(root, "avatar").Parent == parent)
	expect(title.Position == position and title.Size == size, "Moved source geometry corrupted the preserved parent")
	root:Destroy()
	staged:Destroy()
end)

test("class conflicts and duplicate tracking IDs abort before visual mutations", function()
	local root = build()
	local data = payload()
	data.tree[1].children[1].suggestedRole = "TextButton"
	local staged = build(data)
	fails(function()
		Reimport.plan(root, staged)
	end, "Class conflict")
	expect(byId(root, "title").Text == "Before")
	staged:Destroy()
	staged = build()
	local duplicate = byId(root, "title"):Clone()
	duplicate.Parent = root.Canvas
	fails(function()
		Reimport.plan(root, staged)
	end, "Duplicate DesignUID")
	root:Destroy()
	staged:Destroy()
end)

test("wrong document identity is rejected before update", function()
	local root = build()
	local data = payload()
	data.documentId = "other-document"
	local staged = build(data)
	fails(function()
		Reimport.plan(root, staged)
	end, "another design")
	root:Destroy()
	staged:Destroy()
end)

test("mid-apply cancellation rolls back visuals and newly added objects", function()
	local root = build()
	local original = byId(root, "title")
	local data = payload()
	data.tree[1].children[1].text = "After"
	table.insert(
		data.tree[1].children,
		1,
		{ id = "new", name = "New", width = 100, height = 50, suggestedRole = "Frame" }
	)
	local staged = build(data)
	local plan = Reimport.plan(root, staged)
	local count = 0
	local fakeJob = {
		checkpoint = function()
			count += 1
			if count == #plan.entries then
				error("Import cancelled")
			end
		end,
	}
	fails(function()
		Reimport.apply(plan, fakeJob)
	end, "cancelled")
	expect(byId(root, "title") == original and original.Text == "Before")
	expect(not root:FindFirstChild("New", true))
	root:Destroy()
	staged:Destroy()
end)

test("a failed Studio commit can roll back an already applied transaction", function()
	local root = build()
	local data = payload()
	data.tree[1].children[1].text = "After"
	local staged = build(data)
	local transaction = Reimport.apply(Reimport.plan(root, staged))
	expect(byId(root, "title").Text == "After")
	transaction.rollback()
	expect(byId(root, "title").Text == "Before")
	root:Destroy()
	staged:Destroy()
end)

print(string.format("All %d architecture regression tests passed.", passed))
