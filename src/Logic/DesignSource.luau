-- JSON and API callers use the same versioned schema.
-- No code, arbitrary Instance classes, or URLs inside nodes are executed.
local Diagnostics = require(script.Parent.ImportDiagnostics)
local DesignSource = {}

function DesignSource.fromTable(payload, job)
	assert(type(payload) == "table" and payload.schemaVersion == 1, "JSON requires schemaVersion 1")
	assert(type(payload.documentId) == "string" and #payload.documentId > 0, "JSON requires a stable documentId")
	assert(type(payload.tree) == "table", "JSON requires a tree array")
	local document = table.clone(payload)
	document.sourceType = "JSON"
	document.tree = {}
	local seen, ids, count = {}, {}, 0
	local function node(source, parentLeft, parentTop, depth)
		job:checkpoint()
		count += 1
		assert(depth <= job.limits.depth and count <= job.limits.layers, "JSON exceeds layer or nesting limit")
		assert(type(source) == "table" and not seen[source], "JSON has repeated or cyclic nodes")
		seen[source] = true
		assert(
			type(source.id) == "string" and #source.id > 0 and not ids[source.id],
			"JSON nodes require unique, stable string IDs"
		)
		ids[source.id] = true
		local result = table.clone(source)
		result.sourceId = "JSON:" .. source.id
		-- x/y are parent-local; left/top are document-space, never a mix.
		if source.x ~= nil or source.y ~= nil then
			assert(source.left == nil and source.top == nil, "Use x/y OR left/top, not both")
			assert(type(source.x or 0) == "number" and type(source.y or 0) == "number", "Invalid JSON position")
			result.left = parentLeft + (source.x or 0)
			result.top = parentTop + (source.y or 0)
		end
		result.left = result.left or 0
		result.top = result.top or 0
		result.children = {}
		for _, child in ipairs(source.children or {}) do
			table.insert(result.children, node(child, result.left, result.top, depth + 1))
		end
		return result
	end
	for _, source in ipairs(payload.tree) do
		table.insert(document.tree, node(source, 0, 0, 1))
	end
	return document
end

function DesignSource.decode(data, job, httpService)
	assert(type(data) == "string" and #data <= job.limits.fileBytes, "JSON exceeds the file size limit")
	local http = httpService or game:GetService("HttpService")
	local ok, payload = pcall(function()
		return http:JSONDecode(data)
	end)
	if not ok then
		error(Diagnostics.explain("JSON decoding failed", payload), 0)
	end
	return DesignSource.fromTable(payload, job)
end

function DesignSource.fetch(url, job, httpService)
	assert(type(url) == "string" and string.match(url, "^https://[^/%s]+"), "Design API requires an HTTPS URL")
	job:checkpoint()
	local http = httpService or game:GetService("HttpService")
	local ok, response = pcall(function()
		return http:RequestAsync({ Url = url, Method = "GET" })
	end)
	if not ok then
		error(Diagnostics.explain("Design HTTP request failed", response), 0)
	end
	job:checkpoint()
	if not response.Success then
		error(
			"Design HTTP request returned status "
				.. tostring(response.StatusCode)
				.. ". Check authentication, permissions, or rate limits.",
			0
		)
	end
	return DesignSource.decode(response.Body, job, http)
end

return DesignSource
