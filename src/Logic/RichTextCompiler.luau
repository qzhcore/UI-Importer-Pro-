local FontMapper = require(script.Parent.FontMapper)
local RichTextCompiler = {}

function RichTextCompiler.escape(value)
	local result = string.gsub(value, "&", "&amp;")
	result = string.gsub(result, "<", "&lt;")
	result = string.gsub(result, ">", "&gt;")
	result = string.gsub(result, '"', "&quot;")
	return (string.gsub(result, "'", "&apos;"))
end

function RichTextCompiler.compile(text, runs)
	if not runs or #runs == 0 then
		return text or "", false
	end
	local parts = {}
	for _, run in ipairs(runs) do
		assert(type(run.text) == "string", "Text runs must contain strings")
		local value = RichTextCompiler.escape(run.text)
		if run.bold then
			value = "<b>" .. value .. "</b>"
		end
		if run.italic then
			value = "<i>" .. value .. "</i>"
		end
		if run.underline then
			value = "<u>" .. value .. "</u>"
		end
		if run.strikethrough then
			value = "<s>" .. value .. "</s>"
		end
		local attributes = {}
		if run.color then
			local c = run.color
			table.insert(
				attributes,
				string.format(
					'color="rgb(%d,%d,%d)"',
					math.round(math.clamp(c.r, 0, 1) * 255),
					math.round(math.clamp(c.g, 0, 1) * 255),
					math.round(math.clamp(c.b, 0, 1) * 255)
				)
			)
		end
		if run.fontFamily then
			local family = FontMapper.resolve(run.fontFamily)
			table.insert(attributes, 'family="rbxasset://fonts/families/' .. family .. '.json"')
		end
		if run.fontWeight then
			table.insert(
				attributes,
				string.format('weight="%d"', math.clamp(math.round(run.fontWeight / 100) * 100, 100, 900))
			)
		end
		if run.textSize then
			table.insert(attributes, string.format('size="%d"', math.clamp(math.round(run.textSize), 1, 100)))
		end
		if #attributes > 0 then
			value = "<font " .. table.concat(attributes, " ") .. ">" .. value .. "</font>"
		end
		table.insert(parts, value)
	end
	return table.concat(parts), true
end

return RichTextCompiler
