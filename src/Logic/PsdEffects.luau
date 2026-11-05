-- Bounded reader for the ActionDescriptor subset used by PSD layer styles.
-- Format: https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
local PsdEffects = {}

function PsdEffects.decode(data, job)
	local position = 1
	local items = 0
	local function bytes(count)
		if count < 0 or position + count - 1 > #data then
			error("Truncated PSD effects descriptor.", 0)
		end
		local value = string.sub(data, position, position + count - 1)
		position += count
		return value
	end
	local function uint()
		local a, b, c, d = string.byte(bytes(4), 1, 4)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	local function double()
		local value = buffer.readf64(buffer.fromstring(string.reverse(bytes(8))), 0)
		if value ~= value or math.abs(value) == math.huge then
			error("Invalid PSD effects number.", 0)
		end
		return value
	end
	local function key()
		local length = uint()
		return bytes(if length == 0 then 4 else length)
	end
	local function unicode()
		-- Descriptor names are not needed for effect mapping. Keep the raw UTF-16.
		return bytes(uint() * 2)
	end
	local value
	local descriptor
	local function count(amount, depth)
		items += amount
		if items > 10000 or depth > 32 then
			error("PSD effects descriptor exceeds its limits.", 0)
		end
		job:checkpoint()
	end
	descriptor = function(depth)
		unicode()
		local result = { classId = key() }
		local length = uint()
		count(length, depth)
		for _ = 1, length do
			local field = key()
			result[field] = value(bytes(4), depth + 1)
		end
		return result
	end
	value = function(kind, depth)
		if depth > 32 then
			error("PSD effects descriptor exceeds its limits.", 0)
		end
		if kind == "Objc" or kind == "GlbO" then
			return descriptor(depth)
		end
		if kind == "VlLs" then
			local result = {}
			local length = uint()
			count(length, depth)
			for index = 1, length do
				result[index] = value(bytes(4), depth + 1)
			end
			return result
		end
		if kind == "doub" then
			return double()
		end
		if kind == "UntF" then
			local unit = bytes(4)
			return { unit = unit, value = double() }
		end
		if kind == "long" then
			local n = uint()
			return if n >= 2147483648 then n - 4294967296 else n
		end
		if kind == "bool" then
			return string.byte(bytes(1)) ~= 0
		end
		if kind == "enum" then
			local enumType = key()
			return { enumType = enumType, value = key() }
		end
		if kind == "TEXT" then
			return unicode()
		end
		if kind == "tdta" or kind == "alis" then
			return bytes(uint())
		end
		if kind == "comp" then
			return bytes(8)
		end
		if kind == "type" or kind == "GlbC" then
			unicode()
			return key()
		end
		error("Unsupported PSD effects descriptor type: " .. kind, 0)
	end
	if uint() ~= 0 or uint() ~= 16 then
		error("Unsupported PSD effects version.", 0)
	end
	return descriptor(0)
end

local function number(value, fallback)
	if type(value) == "table" then
		value = value.value
	end
	return if type(value) == "number" then value else fallback
end

local function rgb(color)
	if type(color) ~= "table" or color.classId ~= "RGBC" then
		return nil
	end
	if not color["Rd  "] or not color["Grn "] or not color["Bl  "] then
		return nil
	end
	return {
		r = math.clamp(number(color["Rd  "], 0) / 255, 0, 1),
		g = math.clamp(number(color["Grn "], 0) / 255, 0, 1),
		b = math.clamp(number(color["Bl  "], 0) / 255, 0, 1),
	}
end

local function normal(effect)
	return type(effect) == "table"
		and effect.enab == true
		and type(effect["Md  "]) == "table"
		and effect["Md  "].value == "Nrml"
end

function PsdEffects.map(layer, descriptor)
	if descriptor.masterFXSwitch == false then
		layer.unsupportedPsdEffects = false
		return
	end
	local fills = descriptor.solidFillMulti or { descriptor.SoFi }
	local overlays = {}
	for _, effect in ipairs(fills) do
		local color = if normal(effect) then rgb(effect["Clr "]) else nil
		if color then
			color.a = math.clamp(number(effect.Opct, 100) / 100, 0, 1)
			table.insert(overlays, color)
		end
	end
	if #overlays > 0 then
		layer.psdColorOverlays = overlays
		if layer.text and #overlays == 1 and overlays[1].a == 1 then
			layer.backgroundColor = overlays[1]
		end
	end
	local stroke = descriptor.FrFX
	if layer.text and normal(stroke) then
		local color = rgb(stroke["Clr "])
		if color and stroke.PntT and stroke.PntT.value == "SClr" then
			color.a = math.clamp(number(stroke.Opct, 100) / 100, 0, 1)
			layer.strokeColor = color
			layer.strokeThickness =
				math.clamp(number(stroke["Sz  "], 0) * number(descriptor["Scl "], 100) / 100, 0, 100)
		end
	end
	local unsupported = false
	for effectName, effect in pairs(descriptor) do
		if type(effect) == "table" and effect.enab == true then
			local supportedFill = effectName == "SoFi" and #overlays == 1
			local supportedStroke = effectName == "FrFX" and layer.strokeColor ~= nil
			if not supportedFill and not supportedStroke then
				unsupported = true
			end
		elseif type(effect) == "table" and #effect > 0 then
			for _, entry in ipairs(effect) do
				if type(entry) == "table" and entry.enab == true then
					unsupported = true
				end
			end
		end
	end
	layer.unsupportedPsdEffects = unsupported
end

function PsdEffects.applyPixels(layer, job)
	if not layer.pixels or not layer.psdColorOverlays then
		return
	end
	for index = 0, layer.width * layer.height - 1 do
		if index % 8192 == 0 then
			job:checkpoint()
		end
		local offset = index * 4
		for _, color in ipairs(layer.psdColorOverlays) do
			buffer.writeu8(
				layer.pixels,
				offset,
				math.floor(buffer.readu8(layer.pixels, offset) * (1 - color.a) + color.r * 255 * color.a + 0.5)
			)
			buffer.writeu8(
				layer.pixels,
				offset + 1,
				math.floor(buffer.readu8(layer.pixels, offset + 1) * (1 - color.a) + color.g * 255 * color.a + 0.5)
			)
			buffer.writeu8(
				layer.pixels,
				offset + 2,
				math.floor(buffer.readu8(layer.pixels, offset + 2) * (1 - color.a) + color.b * 255 * color.a + 0.5)
			)
		end
	end
end

return PsdEffects
