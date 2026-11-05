local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local path = process.args[1] or "dist/UIImporterPro.rbxm"
local roots = roblox.deserializeModel(fs.readFile(path))
assert(#roots == 1, "Expected one plugin entry point")
local root = roots[1]
assert(root.ClassName == "Script" and root.RunContext == roblox.Enum.RunContext.Plugin, "Invalid plugin RunContext")
for _, name in ipairs({
	"DesignSource",
	"ImportPipeline",
	"ResponsiveLayout",
	"AutoLayoutMapper",
	"FontMapper",
	"RichTextCompiler",
	"ImportIdentity",
	"VisualProperties",
	"ReimportEngine",
	"ImportDiagnostics",
}) do
	assert(root.Logic:FindFirstChild(name), "Missing module: " .. name)
end
local count = 1
assert(loadstring(root.Source), "Entry point failed compilation")
for _, object in ipairs(root:GetDescendants()) do
	if object:IsA("LuaSourceContainer") then
		assert(loadstring(object.Source), "Compilation failed: " .. object.Name)
		count += 1
	end
end
print(string.format("Verified %s: plugin entry point and %d compiled scripts.", path, count))
