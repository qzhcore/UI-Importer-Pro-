local roblox = require("@lune/roblox")
local loader = require("./ModuleLoader")
local modules = loader(roblox, { AssetUploader = {
	countTiles = function()
		return 0
	end,
} })
local ImportJob = modules("ImportJob")
local Document = modules("DesignDocument")
local BackgroundFilter = modules("BackgroundFilter")
local Effects = modules("PsdEffects")
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local function document(tree)
	return Document.normalize({ sourceType = "PSD", width = 100, height = 100, tree = tree }, ImportJob.new())
end
local function layer(name, width, children)
	return { name = name, left = 0, top = 0, width = width or 100, height = 100, children = children or {} }
end
test("default backdrop exclusion preserves panel backgrounds and stable source IDs", function()
	local doc = document({ layer("Background"), layer("Card", 50, { layer("Background", 50) }) })
	local id = doc.tree[2].sourceId
	BackgroundFilter.apply(doc)
	assert(#doc.tree == 1 and #doc.layers == 2 and doc.tree[1].name == "Card", "Wrong background removed")
	assert(doc.tree[1].children[1].name == "Background" and doc.tree[1].sourceId == id, "Panel content changed")
end)
test("background inclusion and explicit UI roles override automatic exclusion", function()
	local doc = document({ layer("Background"), layer("[Frame] Background") })
	BackgroundFilter.apply(doc, { includeBackground = true })
	assert(#doc.tree == 2, "Inclusion ignored")
	BackgroundFilter.apply(doc)
	assert(#doc.tree == 1 and doc.tree[1].name == "[Frame] Background", "Explicit role ignored")
end)
test("smaller backgrounds and full-canvas UI groups are retained", function()
	local doc = document({ layer("Background", 50), layer("Background", 100, { layer("Content", 50) }) })
	BackgroundFilter.apply(doc)
	assert(#doc.tree == 2, "Removed UI instead of a document backdrop")
end)
test("flattened references cannot silently reintroduce an excluded backdrop", function()
	local ok, err = pcall(function()
		BackgroundFilter.apply(document({ layer("Background"), layer("Card", 50) }), { visualMode = "Reference" })
	end)
	assert(not ok and string.find(tostring(err), "flattened background", 1, true), "Flattened background was accepted")
end)
test("text named Button remains editable and keeps its source geometry", function()
	local source = layer("Button", 30)
	source.height = 20
	source.text = "Equip"
	local target = roblox.Instance.new("Folder")
	local result =
		modules("UIBuilder").build(document({ source }), "Test", target, nil, { embedImages = false }, ImportJob.new())
	local button = result.root:FindFirstChild("Button", true)
	assert(button.ClassName == "TextButton" and button.Text == "Equip", "Text became raster artwork")
	assert(button:FindFirstChildWhichIsA("UISizeConstraint") == nil, "Source button was stretched")
	result.root:Destroy()
	target:Destroy()
end)
local function u32(n)
	return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end
local function key(s)
	return u32(#s) .. s
end
local function double(n)
	local b = buffer.create(8)
	buffer.writef64(b, 0, n)
	return string.reverse(buffer.tostring(b))
end
local function field(k, t, v)
	return key(k) .. t .. v
end
local function descriptor(class, fields)
	return u32(0) .. key(class) .. u32(#fields) .. table.concat(fields)
end
local color = descriptor(
	"RGBC",
	{ field("Rd  ", "doub", double(23)), field("Grn ", "doub", double(23)), field("Bl  ", "doub", double(23)) }
)
local effect = descriptor("SoFi", {
	field("enab", "bool", string.char(1)),
	field("Md  ", "enum", key("BlnM") .. key("Nrml")),
	field("Opct", "UntF", "#Prc" .. double(100)),
	field("Clr ", "Objc", color),
})
local fixture = u32(0)
	.. u32(16)
	.. descriptor("Lefx", { field("masterFXSwitch", "bool", string.char(1)), field("SoFi", "Objc", effect) })
test("PSD color overlay descriptors restore authored colors while preserving alpha", function()
	local job = ImportJob.new()
	local style = Effects.decode(fixture, job)
	local source = { width = 1, height = 1, pixels = buffer.fromstring(string.char(32, 112, 3, 128)) }
	Effects.map(source, style)
	Effects.applyPixels(source, job)
	assert(buffer.tostring(source.pixels) == string.char(23, 23, 23, 128), "Overlay or alpha is incorrect")
end)
test("disabled effects remain disabled and malformed descriptors are bounded", function()
	local style = Effects.decode(fixture, ImportJob.new())
	style.masterFXSwitch = false
	local source = { text = "Title" }
	Effects.map(source, style)
	assert(source.psdColorOverlays == nil, "Disabled effect was applied")
	local ok = pcall(Effects.decode, string.sub(fixture, 1, -2), ImportJob.new())
	assert(not ok, "Truncated descriptor accepted")
end)
print(string.format("All %d appearance regression tests passed.", passed))
