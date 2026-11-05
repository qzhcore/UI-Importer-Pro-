local roblox = require("@lune/roblox")
local loader = require("./ModuleLoader")
local loadModule = loader(roblox, {
	AssetUploader = {
		countTiles = function()
			return 0
		end,
		createLayerContent = function()
			return {}
		end,
	},
})
local ImportJob = loadModule("ImportJob")
local DesignDocument = loadModule("DesignDocument")
local UIBuilder = loadModule("UIBuilder")
local PsdParser = loadModule("PsdParser")
local RenderPolicy = loadModule("RenderPolicy")
local Deflate = loadModule("Deflate")
local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	assert(ok, name .. ": " .. tostring(message))
	passed += 1
	print("PASS " .. name)
end
local function equal(actual, expected)
	assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function fails(callback, fragment)
	local ok, message = pcall(callback)
	assert(not ok, "Expected failure")
	assert(string.find(tostring(message), fragment, 1, true), tostring(message))
end
local function layer(name, extra)
	local result = { name = name, width = 100, height = 40, left = 0, top = 0, suggestedRole = "Frame" }
	for key, value in pairs(extra or {}) do
		result[key] = value
	end
	return result
end
local function document(tree, sourceType, extra)
	local result = { sourceType = sourceType or "FIG", width = 400, height = 300, tree = tree }
	for key, value in pairs(extra or {}) do
		result[key] = value
	end
	return DesignDocument.normalize(result, ImportJob.new())
end
local function build(doc, options, job)
	local target = roblox.Instance.new("Folder")
	local result = UIBuilder.build(doc, "Fixture", target, nil, options or {}, job or ImportJob.new())
	equal(result.root.Parent, nil)
	equal(#target:GetChildren(), 0)
	target:Destroy()
	return result.root, result
end

test("effect-bearing PSDs keep editable controls visible without a flattened background", function()
	local doc = document({
		layer("[Input] Search", { text = "Search", suggestedRole = "TextBox", hasLayerEffects = true }),
		layer("Price", { text = "100", suggestedRole = "TextLabel" }),
	}, "PSD", { hasLayerEffects = true, compositePixels = buffer.create(4), compositeWidth = 1, compositeHeight = 1 })
	local root, result = build(doc)
	equal(result.visualMode, "Editable")
	equal(root:FindFirstChild("RenderedDesign", true), nil)
	local input = root:FindFirstChildWhichIsA("TextBox", true)
	equal(input.TextTransparency, 0)
	input.Text = "Changed"
	equal(input.Text, "Changed")
	assert(input:GetAttribute("UIImporterWarning"))
	root:Destroy()
end)

test("Figma reference mode creates one static reference with no duplicate native controls", function()
	local doc = document({ layer("Price", { text = "100", suggestedRole = "TextLabel" }) }, "FIG", {
		compositePixels = buffer.create(4),
		compositeWidth = 1,
		compositeHeight = 1,
	})
	local root, result = build(doc, { visualMode = "Reference" })
	equal(result.layerCount, 0)
	assert(root:FindFirstChild("RenderedDesign", true))
	equal(root:FindFirstChildWhichIsA("TextLabel", true), nil)
	root:Destroy()
end)

test("reference mode refuses missing artwork before producing a result", function()
	fails(function()
		build(document({ layer("Empty") }), { visualMode = "Reference" })
	end, "no readable reference")
end)

test("auto-layout excludes absolute children and decorative artwork", function()
	local root = build(document({
		layer("Card", {
			layoutMode = "HORIZONTAL",
			paddingLeft = 8,
			layoutGap = 12,
			children = {
				layer("Flow", { layoutPositioning = "AUTO" }),
				layer("Badge", {
					left = 80,
					layoutPositioning = "ABSOLUTE",
					constraints = { horizontal = "MAX", vertical = "MIN" },
				}),
			},
		}),
	}))
	local card = root:FindFirstChild("Card", true)
	local flow = card:FindFirstChild("Flow", true)
	local badge = card:FindFirstChild("Badge", true)
	equal(badge.Parent, card)
	assert(flow.Parent:GetAttribute("UIImporterLayoutContent"))
	assert(flow.Parent:FindFirstChildWhichIsA("UIListLayout"))
	equal(card:FindFirstChildWhichIsA("UIListLayout"), nil)
	assert(math.abs(badge.Position.X.Scale - 1.8) < 0.00001, "Right-anchored position lost source proportions")
	equal(badge.Position.X.Offset, 0)
	equal(badge.AnchorPoint.X, 1)
	root:Destroy()
end)

test("native text fits responsively with readable bounds", function()
	local root = build(document({ layer("Title", { text = "Title", textSize = 24, suggestedRole = "TextLabel" }) }))
	local text = root:FindFirstChild("Title", true)
	equal(text.TextScaled, true)
	equal(text.TextSize, 24)
	equal(text.ResponsiveTextSize.MinTextSize, 10)
	equal(text.ResponsiveTextSize.MaxTextSize, 48)
	root:Destroy()
end)

test("source IDs survive renamed and reordered source layers", function()
	local first = document({ layer("Old", { figmaNodeId = "1:2" }), layer("Second", { figmaNodeId = "1:3" }) })
	local second = document({ layer("Second", { figmaNodeId = "1:3" }), layer("Renamed", { figmaNodeId = "1:2" }) })
	equal(first.layers[1].sourceId, second.layers[2].sourceId)
	local root = build(second)
	equal(root:FindFirstChild("Renamed", true):GetAttribute("UIImporterSourceId"), "FIG:1:2")
	root:Destroy()
end)

test("validation rejects cycles, invalid coordinates and invalid RGBA buffers", function()
	local cycle = layer("Cycle")
	cycle.children = { cycle }
	fails(function()
		document({ cycle })
	end, "cyclic")
	fails(function()
		document({ layer("NaN", { left = 0 / 0 }) })
	end, "position")
	fails(function()
		document({ layer("Pixels", { pixels = buffer.create(1) }) })
	end, "RGBA")
end)

test("cancellation is observed both before and after yielding", function()
	local job = ImportJob.new()
	job:cancel()
	fails(function()
		job:checkpoint()
	end, "cancelled")
	job = ImportJob.new({
		yieldCallback = function()
			job:cancel()
		end,
	})
	fails(function()
		job:checkpoint(true)
	end, "cancelled")
end)

test("cancelled builds never attach generated UI", function()
	local job = ImportJob.new()
	job:cancel()
	fails(function()
		build(document({ layer("Cancel") }), {}, job)
	end, "cancelled")
end)

test("unsupported clipping and blend modes are attached to specific layers", function()
	local doc = document({ layer("Clip", { clipping = 1, blendMode = "mul " }) }, "PSD")
	RenderPolicy.prepare(doc)
	assert(string.find(doc.layers[1].importWarning, "clipping", 1, true))
	assert(string.find(doc.layers[1].importWarning, "blend", 1, true))
end)

local function u16(n)
	return string.char(math.floor(n / 256) % 256, n % 256)
end
local function u32(n)
	return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end
local function block(data)
	return u32(#data) .. data
end
local function psd(options)
	options = options or {}
	local mask = u32(0) .. u32(1) .. u32(2) .. u32(2) .. string.char(0, options.maskFlags or 0) .. u16(0)
	local extra = block(mask)
		.. u32(0)
		.. string.char(4)
		.. "Play"
		.. string.rep("\0", 3)
		.. "8BIMlyid"
		.. u32(4)
		.. u32(42)
	local channels = {
		{ 0, "\255\255\255\255" },
		{ 1, "\0\0\0\0" },
		{ 2, "\0\0\0\0" },
		{ 65535, "\255\255\255\255" },
		{
			65534,
			"\255\128",
		},
	}
	local records, pixels = {}, {}
	for _, channel in ipairs(channels) do
		local encoded = u16(0) .. channel[2]
		if options.rle then
			local width = if channel[1] == 65534 then 1 else 2
			local rows = {}
			for row = 1, 2 do
				local raw = string.sub(channel[2], (row - 1) * width + 1, row * width)
				rows[row] = if width == 2 then string.char(255) .. string.sub(raw, 1, 1) else string.char(0) .. raw
			end
			if options.invalidRle and channel[1] == 0 then
				rows[1] = string.char(254, 255)
			end
			encoded = u16(1) .. u16(#rows[1]) .. u16(#rows[2]) .. rows[1] .. rows[2]
		end
		table.insert(records, u16(channel[1]) .. u32(#encoded))
		table.insert(pixels, encoded)
	end
	local record = u32(0)
		.. u32(0)
		.. u32(2)
		.. u32(options.layerWidth or 2)
		.. u16(#channels)
		.. table.concat(records)
		.. "8BIMnorm"
		.. string.char(255, 0, 0, 0)
		.. block(extra)
	local info = u16(1) .. record .. table.concat(pixels)
	if #info % 2 == 1 then
		info ..= "\0"
	end
	return "8BPS"
		.. u16(1)
		.. string.rep("\0", 6)
		.. u16(3)
		.. u32(2)
		.. u32(2)
		.. u16(8)
		.. u16(3)
		.. u32(0)
		.. u32(0)
		.. block(block(info) .. u32(0))
		.. u16(0)
		.. string.rep("\255", 12)
end

test("a complete PSD fixture applies the layer mask with document-space offsets", function()
	local doc = PsdParser.parse(psd(), ImportJob.new())
	equal(doc.layers[1].psdLayerId, 42)
	local pixels = doc.layers[1].pixels
	equal(buffer.readu8(pixels, 3), 0)
	equal(buffer.readu8(pixels, 7), 255)
	equal(buffer.readu8(pixels, 11), 0)
	equal(buffer.readu8(pixels, 15), 128)
	equal(doc.compositePixels, nil)
end)

test("disabled PSD masks preserve original layer alpha", function()
	local doc = PsdParser.parse(psd({ maskFlags = 2 }), ImportJob.new())
	equal(buffer.readu8(doc.layers[1].pixels, 3), 255)
end)

test("RLE PSD channels and masks match the raw pixel fixture", function()
	local raw = PsdParser.parse(psd(), ImportJob.new())
	local compressed = PsdParser.parse(psd({ rle = true }), ImportJob.new())
	equal(buffer.tostring(compressed.layers[1].pixels), buffer.tostring(raw.layers[1].pixels))
	fails(function()
		PsdParser.parse(psd({ rle = true, invalidRle = true }), ImportJob.new())
	end, "RLE repeat run")
end)

test("PSD reference pixels are decoded only when requested", function()
	local doc = PsdParser.parse(psd(), ImportJob.new(), { visualMode = "Reference" })
	equal(buffer.len(doc.compositePixels), 16)
end)

test("PSD rejects oversized layer dimensions before allocating pixel storage", function()
	fails(function()
		PsdParser.parse(psd({ layerWidth = 20000000 }), ImportJob.new())
	end, "megapixel")
end)

test("DEFLATE enforces output limits within an uncompressed block", function()
	local compressed = string.char(1) .. string.char(4, 0, 251, 255) .. "abcd"
	equal(Deflate.decompress(compressed, nil, 4), "abcd")
	fails(function()
		Deflate.decompress(compressed, nil, 3)
	end, "size limit")
end)

test("DEFLATE grows compact buffers across long overlapping backreferences", function()
	-- Generated independently with Node zlib.deflateRawSync(Buffer.from('RGBA'.repeat(32768))).
	local hex =
		"edc3310d00000803306df0f0cfbf9821a44d9adb89aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaea2f"
	local compressed = string.gsub(hex, "%x%x", function(pair)
		return string.char(tonumber(pair, 16))
	end)
	local expected = string.rep("RGBA", 32768)
	equal(Deflate.decompress(compressed, ImportJob.new(), #expected), expected)
	fails(function()
		Deflate.decompress(compressed, ImportJob.new(), #expected - 1)
	end, "size limit")
end)

test("complete PSD bytes pass through validation and detached Roblox generation", function()
	local job = ImportJob.new()
	local target = roblox.Instance.new("Folder")
	local result = loadModule("ImportPipeline").convert(psd(), "PSD", "PSDFile", target, {}, job)
	equal(result.root.Parent, nil)
	equal(result.layerCount, 1)
	equal(result.root:FindFirstChild("Play", true):GetAttribute("UIImporterSourceId"), "PSD:42")
	result.root:Destroy()
	target:Destroy()
end)

test("complete FIG bytes pass through Kiwi decoding and editable Roblox generation", function()
	local fixture = require("./FigFixture")()
	local job = ImportJob.new()
	local target = roblox.Instance.new("Folder")
	local result = loadModule("ImportPipeline").convert(fixture, "FIG", "FigmaFile", target, {}, job)
	local title = result.root:FindFirstChild("Title", true)
	equal(title.Text, "Play")
	equal(title.TextSize, 20)
	equal(title.TextTransparency, 0)
	equal(title:GetAttribute("UIImporterSourceId"), "FIG:0:3")
	result.root:Destroy()
	target:Destroy()
end)

test("budget failures cannot be swallowed by a decoder's compatibility fallback", function()
	local job = ImportJob.new()
	pcall(function()
		job:reserveBytes(job.limits.decodedBytes + 1)
	end)
	fails(function()
		job:checkpoint()
	end, "budget")
end)

local function importerHarness(behavior)
	local state = { operations = {}, fileDestroyed = false, rootDestroyed = false }
	local root = { Name = "Imported" }
	function root:Destroy()
		state.rootDestroyed = true
		self.Parent = nil
	end
	local file = { Name = "fixture.psd", Size = 4 }
	function file:GetBinaryContents()
		if behavior == "readFailure" then
			error("cannot read")
		end
		return "data"
	end
	function file:Destroy()
		state.fileDestroyed = true
	end
	local target = {}
	local services = {
		StarterGui = target,
		StudioService = {
			PromptImportFileAsync = function()
				return file
			end,
		},
		Selection = {
			Set = function()
				state.selected = true
			end,
		},
		ChangeHistoryService = {
			TryBeginRecording = function()
				return "recording"
			end,
			FinishRecording = function(_, id, operation)
				equal(id, "recording")
				table.insert(state.operations, operation)
			end,
		},
	}
	local globals = table.clone(roblox)
	globals.game = {
		GetService = function(_, name)
			return services[name]
		end,
	}
	local imported = loader(globals, {
		ImportPipeline = {
			convert = function(_, _, _, _, _, job)
				if behavior == "convertFailure" then
					error("conversion failed")
				end
				if behavior == "cancel" then
					job:cancel()
				end
				return { root = root, visualMode = "Editable", warnings = {}, layerCount = 1 }
			end,
		},
	})("DesignImporter")
	return imported, state, root, target
end

test("Studio import commits one recording and releases the selected file", function()
	local importer, state, root, target = importerHarness("success")
	local ok = importer.promptAndImport(nil, { job = ImportJob.new() })
	equal(ok, true)
	equal(state.fileDestroyed, true)
	equal(root.Parent, target)
	equal(#state.operations, 1)
	equal(state.operations[1], roblox.Enum.FinishRecordingOperation.Commit)
end)

test("cancellation destroys detached output before any recording begins", function()
	local importer, state, root = importerHarness("cancel")
	local ok, message = importer.promptAndImport(nil, { job = ImportJob.new() })
	equal(ok, false)
	equal(message, "Import cancelled.")
	equal(state.fileDestroyed, true)
	equal(state.rootDestroyed, true)
	equal(root.Parent, nil)
	equal(#state.operations, 0)
end)

test("conversion errors precede recordings and reading errors release files", function()
	local importer, state = importerHarness("convertFailure")
	equal(importer.promptAndImport(nil, { job = ImportJob.new() }), false)
	equal(#state.operations, 0)
	importer, state = importerHarness("readFailure")
	equal(importer.promptAndImport(nil, { job = ImportJob.new() }), false)
	equal(state.fileDestroyed, true)
	equal(#state.operations, 0)
end)

print(string.format("All %d import pipeline tests passed.", passed))
