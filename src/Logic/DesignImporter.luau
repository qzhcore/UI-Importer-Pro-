local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local StudioService = game:GetService("StudioService")

local ImportJob = require(script.Parent.ImportJob)
local ImportPipeline = require(script.Parent.ImportPipeline)
local ReimportEngine = require(script.Parent.ReimportEngine)
local Diagnostics = require(script.Parent.ImportDiagnostics)

local DesignImporter = {}

function DesignImporter.promptAndImport(progressCallback, options)
	options = options or {}
	local job = options.job
		or ImportJob.new({
			progressCallback = progressCallback,
			yieldCallback = function()
				task.wait()
			end,
		})
	local file
	local result
	local recording
	local stagedRoot
	local transaction
	local target
	local ok, message = pcall(function()
		if options.reimportSelected then
			local selected = Selection:Get()
			assert(#selected == 1, "Select one imported root or one of its children to update.")
			target = selected[1]
			while target and not target:IsA("LayerCollector") do
				target = target.Parent
			end
			assert(
				target and target:GetAttribute("DesignUID") == "$root",
				"Select an import created by this version. Existing untracked UI is never overwritten."
			)
			options = table.clone(options)
			options.layerCollectorClass = target.ClassName
		end
		job:progress({ stage = "ChoosingFile", message = "Choose a PSD, FIG, or JSON design file." })
		file = StudioService:PromptImportFileAsync({ "psd", "fig", "json" })
		if not file then
			job:cancel()
		end
		job:checkpoint(true)
		local fileName = file.Name
		local extension = string.lower(string.match(fileName, "%.([^%.]+)$") or "")
		if extension ~= "psd" and extension ~= "fig" and extension ~= "json" then
			error("Choose a .fig, .psd, or .json design file.", 0)
		end
		if file.Size > job.limits.fileBytes then
			error("Choose a design file smaller than 100 MB.", 0)
		end
		job:progress({ stage = "Reading", message = "Reading " .. fileName .. "..." })
		local data = file:GetBinaryContents()
		file:Destroy()
		file = nil
		local name = string.gsub(fileName, "%.[^%.]+$", "")
		result = ImportPipeline.convert(data, string.upper(extension), name, StarterGui, options, job)
		stagedRoot = result.root
		local plan = if target then ReimportEngine.plan(target, stagedRoot, job) else nil
		job:checkpoint(true)
		recording = ChangeHistoryService:TryBeginRecording("UIImporterProImport", "Import Design UI")
		if not recording then
			error("Studio could not start an undo recording. Stop Play mode and try again.", 0)
		end
		if plan then
			transaction = ReimportEngine.apply(plan, job)
			result.root = target
			result.screenGui = target
			result.reimported = true
			for _, warning in ipairs(transaction.warnings) do
				table.insert(result.warnings, warning)
			end
		else
			stagedRoot.Parent = StarterGui
		end
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		recording = nil
	end)
	if file then
		file:Destroy()
	end
	if not ok then
		if transaction then
			transaction.rollback()
		end
		if stagedRoot then
			stagedRoot:Destroy()
		end
		if recording then
			pcall(function()
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			end)
		end
		local failure = if job.cancelled then "Import cancelled." else Diagnostics.report("Import failed", message)
		if #job.uploadedAssets > 0 then
			failure ..= string.format(
				" %d uploaded image asset(s) remain on Roblox; see Output for their IDs.",
				#job.uploadedAssets
			)
			for _, asset in ipairs(job.uploadedAssets) do
				warn(
					string.format(
						"[UI Importer Pro] Uploaded image retained: %s (rbxassetid://%s)",
						asset.name,
						tostring(asset.id)
					)
				)
			end
		end
		return false, failure
	end
	if target and stagedRoot then
		stagedRoot:Destroy()
	end

	-- Notifications must not turn a committed import into a failure.
	pcall(function()
		Selection:Set({ result.root })
	end)
	local summary = if result.reimported
		then string.format(
			"Updated %d matched objects; added %d. Existing developer content preserved.",
			transaction.updated,
			transaction.added
		)
		elseif result.visualMode == "Reference" then string.format(
			"Imported a static reference into StarterGui.%s.",
			result.root.Name
		)
		else string.format("Imported %d editable layers into StarterGui.%s.", result.layerCount, result.root.Name)
	if #result.warnings > 0 then
		summary ..= string.format(" %d warning(s); see Output and layer attributes.", #result.warnings)
		for _, warning in ipairs(result.warnings) do
			warn("[UI Importer Pro] " .. warning)
		end
	end
	if progressCallback then
		pcall(progressCallback, { stage = "Complete", message = summary })
	end
	return true, summary, result
end

return DesignImporter
