-- A small, synthetic Kiwi scene encoded independently of the production reader.
local function uint(value)
	local parts = {}
	repeat
		local byte = value % 128
		value = math.floor(value / 128)
		table.insert(parts, string.char(byte + if value > 0 then 128 else 0))
	until value == 0
	return table.concat(parts)
end
local function int(value)
	return uint(if value < 0 then -value * 2 - 1 else value * 2)
end
local function str(value)
	return value .. "\0"
end
local function u32(value)
	return string.char(
		value % 256,
		math.floor(value / 256) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 16777216) % 256
	)
end
local function field(name, datatype, array, id)
	return str(name) .. int(datatype) .. string.char(if array then 1 else 0) .. uint(id)
end
local function schemaType(name, kind, fields)
	return str(name) .. string.char(kind) .. uint(#fields) .. table.concat(fields)
end
local function stored(data)
	local size = #data
	assert(size < 65536, "Synthetic FIG fixture exceeds a stored DEFLATE block")
	local inverse = 65535 - size
	return string.char(1, size % 256, math.floor(size / 256), inverse % 256, math.floor(inverse / 256)) .. data
end
return function()
	local schema = uint(8)
		.. table.concat({
			schemaType("Guid", 1, { field("sessionID", -4, false, 1), field("localID", -4, false, 2) }),
			schemaType("Parent", 1, { field("guid", 0, false, 1), field("position", -6, false, 2) }),
			schemaType("Size", 1, { field("x", -4, false, 1), field("y", -4, false, 2) }),
			schemaType("Node", 2, {
				field("guid", 0, false, 1),
				field("parentIndex", 1, false, 2),
				field("type", -6, false, 3),
				field("name", -6, false, 4),
				field("size", 2, false, 5),
				field("textData", 4, false, 6),
				field("fontSize", -4, false, 7),
				field("fillPaints", 7, true, 8),
			}),
			schemaType("Text", 1, { field("characters", -6, false, 1) }),
			schemaType("Message", 2, { field("nodeChanges", 3, true, 1) }),
			schemaType("Color", 1, { field("r", -4, false, 1), field("g", -4, false, 2), field("b", -4, false, 3) }),
			schemaType(
				"Paint",
				1,
				{ field("type", -6, false, 1), field("color", 6, false, 2), field("opacity", -4, false, 3) }
			),
		})
	local function node(id, parent, kind, name, size, text)
		local result = uint(1) .. uint(0) .. uint(id) .. uint(3) .. str(kind) .. uint(4) .. str(name)
		if parent then
			result ..= uint(2) .. uint(0) .. uint(parent) .. str("a")
		end
		if size then
			result ..= uint(5) .. uint(size[1]) .. uint(size[2])
		end
		if text then
			result ..= uint(6) .. str(text) .. uint(7) .. uint(20)
			result ..= uint(8) .. uint(1) .. str("SOLID") .. uint(1) .. uint(1) .. uint(1) .. uint(1)
		end
		return result .. uint(0)
	end
	local message = uint(1)
		.. uint(3)
		.. node(1, nil, "CANVAS", "Page")
		.. node(2, 1, "FRAME", "Menu", { 400, 300 })
		.. node(3, 2, "TEXT", "Title", { 200, 40 }, "Play")
		.. uint(0)
	local compressedSchema, compressedMessage = stored(schema), stored(message)
	return "fig-kiwi"
		.. u32(15)
		.. u32(#compressedSchema)
		.. compressedSchema
		.. u32(#compressedMessage)
		.. compressedMessage
end
