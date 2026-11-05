local DesignDocument = require(script.Parent.DesignDocument)
local BackgroundFilter = require(script.Parent.BackgroundFilter)
local FigParser = require(script.Parent.FigParser)
local PsdParser = require(script.Parent.PsdParser)
local UIBuilder = require(script.Parent.UIBuilder)
local DesignSource = require(script.Parent.DesignSource)

local ImportPipeline = {}

function ImportPipeline.fromDocument(document, documentName, targetParent, options, job)
	job:progress({ stage = "Validating", message = "Checking design geometry and artwork..." })
	document = DesignDocument.normalize(document, job)
	document = BackgroundFilter.apply(document, options)
	return UIBuilder.build(document, documentName, targetParent, function(update)
		job:progress(update)
	end, options, job)
end

function ImportPipeline.fromApi(url, documentName, targetParent, options, job)
	return ImportPipeline.fromDocument(DesignSource.fetch(url, job), documentName, targetParent, options, job)
end

-- File acquisition and Studio transaction ownership stay outside the converter.
function ImportPipeline.convert(data, sourceType, documentName, targetParent, options, job)
	if type(data) ~= "string" or #data > job.limits.fileBytes then
		error("Choose a design file smaller than 100 MB.", 0)
	end
	if sourceType ~= "FIG" and sourceType ~= "PSD" and sourceType ~= "JSON" then
		error("Choose a .fig, .psd, or .json design file.", 0)
	end
	job:progress({ stage = "Parsing", message = "Reading design layers..." })
	local parser = if sourceType == "FIG" then FigParser else PsdParser
	local document = if sourceType == "JSON" then DesignSource.decode(data, job) else parser.parse(data, job, options)
	document.sourceType = sourceType
	return ImportPipeline.fromDocument(document, documentName, targetParent, options, job)
end

return ImportPipeline
