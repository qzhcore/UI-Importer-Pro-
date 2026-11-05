-- Produces a self-contained Studio script without installing or modifying a plugin.
local fs = require("@lune/fs")
local modules = {
	"ResponsiveLayout",
	"AutoLayoutMapper",
	"FontMapper",
	"RichTextCompiler",
	"ImportIdentity",
	"VisualProperties",
	"ReimportEngine",
	"DesignSource",
	"ImportDiagnostics",
	"AssetUploader",
	"FigmaLayout",
	"FigmaVisual",
	"RenderPolicy",
	"UIBuilder",
	"DesignDocument",
	"ImportJob",
	"ImportPipeline",
	"BackgroundFilter",
	"PsdEffects",
	"PsdParser",
	"FigParser",
	"PngDecoder",
	"Deflate",
}
local parts = {
	"local factories, cache = {}, {}",
	"local function import(name) if cache[name] then return cache[name] end local result = factories[name]() cache[name] = result return result end",
}
for _, name in ipairs(modules) do
	local source = fs.readFile("src/Logic/" .. name .. ".luau")
	source = string.gsub(source, "require%(script%.Parent%.(%w+)%)", function(dependency)
		return string.format('import("%s")', dependency)
	end)
	table.insert(parts, string.format('factories["%s"] = function()\n%s\nend', name, source))
end
local factories = table.concat(parts, "\n")
table.insert(parts, "local fixture = (function()\n" .. fs.readFile("tests/FigFixture.luau") .. "\nend)()")
table.insert(
	parts,
	"return (function()\n"
		.. fs.readFile("tests/studio_smoke.luau")
		.. "\nend)()(import, fixture, { Instance = Instance, Enum = Enum, game = game, Vector2 = Vector2 })"
)
if not fs.isDir("work") then
	fs.writeDir("work")
end
fs.writeFile("work/studio-smoke.luau", table.concat(parts, "\n"))
fs.writeFile(
	"work/studio-architecture.luau",
	factories
		.. "\nreturn (function()\n"
		.. fs.readFile("tests/studio_architecture.luau")
		.. "\nend)()(import, { game = game, Instance = Instance, UDim2 = UDim2, Vector2 = Vector2, task = task })"
)
print("Created work/studio-smoke.luau. Run this script in Studio Edit mode for detached smoke tests.")
