local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local StudioService = game:GetService("StudioService")

local FigParser = require(script.Parent.FigParser)
local PsdParser = require(script.Parent.PsdParser)
local UIBuilder = require(script.Parent.UIBuilder)

local DesignImporter = {}

local function getDocumentName(fileName)
	local withoutExtension = string.gsub(fileName, "%.[^%.]+$", "")
	return if withoutExtension == "" then "ImportedUI" else withoutExtension
end

local function emitProgress(progressCallback, update)
	if progressCallback then
		progressCallback(update)
	end
end

local function getExtension(fileName)
	return string.lower(string.match(fileName, "%.([^%.]+)$") or "")
end

function DesignImporter.promptAndImport(progressCallback, options)
	emitProgress(progressCallback, {
		stage = "ChoosingFile",
		message = "Choose a layered Photoshop PSD or Figma Design FIG file.",
	})

	local file = StudioService:PromptImportFileAsync({ "psd", "fig" })
	if not file then
		return false, "Import cancelled."
	end

	emitProgress(progressCallback, {
		stage = "Reading",
		message = string.format("Reading %s…", file.Name),
	})

	local fileName = file.Name
	local extension = getExtension(fileName)
	local ok, dataOrError = pcall(function()
		return file:GetBinaryContents()
	end)
	file:Destroy()

	if not ok then
		return false, "Studio could not read that design file: " .. tostring(dataOrError)
	end

	emitProgress(progressCallback, {
		stage = "Parsing",
		message = if extension == "fig"
			then "Reading Figma scene graph and hierarchy…"
			else "Reading Photoshop layers and hierarchy…",
	})

	local parser = if extension == "fig" then FigParser else PsdParser
	local parseOk, documentOrError = pcall(parser.parse, dataOrError)
	if not parseOk then
		return false, tostring(documentOrError)
	end

	local document = documentOrError
	document.sourceType = if extension == "fig" then "FIG" else "PSD"
	local recording = ChangeHistoryService:TryBeginRecording("UIImporterProImport", "Import Design UI")
	if not recording then
		return false, "Studio could not start an undo recording. Stop Play mode and try again."
	end

	local buildOk, resultOrError = pcall(function()
		return UIBuilder.build(document, getDocumentName(fileName), StarterGui, progressCallback, options)
	end)

	if not buildOk then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		return false, tostring(resultOrError)
	end

	local result = resultOrError
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	Selection:Set({ result.root })

	local message = string.format(
		"Imported %d layers into StarterGui.%s and embedded %d image tile(s).",
		result.layerCount,
		result.root.Name,
		result.imageCount
	)
	if result.visualMode == "CompositeOverlay" then
		message ..= " Photoshop effects preserved with a rendered design and script-ready Roblox overlays."
	end

	if #result.warnings > 0 then
		message ..= string.format(" Completed with %d warning(s); see Output.", #result.warnings)
		for _, warning in ipairs(result.warnings) do
			warn("[UI Importer Pro] " .. warning)
		end
	end

	emitProgress(progressCallback, {
		stage = "Complete",
		message = message,
	})

	return true, message, result
end

return DesignImporter
