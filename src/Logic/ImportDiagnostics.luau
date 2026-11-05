local ImportDiagnostics = {}

function ImportDiagnostics.explain(context, problem)
	local detail = tostring(problem)
	local lower = string.lower(detail)
	local action = "Check the source data and the layer identified in this message."
	if string.find(lower, "http", 1, true) then
		action =
			"For HTTP-disabled errors, enable Allow HTTP Requests in Game Settings > Security. For plugin access errors, allow the requested domain in Plugin Management. Retry after checking the URL and network."
	elseif
		string.find(lower, "asset", 1, true)
		or string.find(lower, "image", 1, true)
		or string.find(lower, "permission", 1, true)
	then
		action =
			"Check the image owner's permissions, moderation status, and experience access in Creator Dashboard. Upload mode requires a locally installed plugin; Session preview is temporary."
	elseif string.find(lower, "json", 1, true) then
		action = "Export valid JSON using the documented schemaVersion 1 format and stable documentId/node IDs."
	end
	return context .. ": " .. detail .. " " .. action
end

function ImportDiagnostics.report(context, problem)
	local message = ImportDiagnostics.explain(context, problem)
	warn("[UI Importer Pro] " .. message)
	return message
end

return ImportDiagnostics
