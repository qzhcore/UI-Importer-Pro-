local Deflate = {}

local MAX_OUTPUT_BYTES = 128 * 1024 * 1024

local LENGTH_BASE = {
	3,
	4,
	5,
	6,
	7,
	8,
	9,
	10,
	11,
	13,
	15,
	17,
	19,
	23,
	27,
	31,
	35,
	43,
	51,
	59,
	67,
	83,
	99,
	115,
	131,
	163,
	195,
	227,
	258,
}

local LENGTH_EXTRA = {
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	1,
	1,
	1,
	1,
	2,
	2,
	2,
	2,
	3,
	3,
	3,
	3,
	4,
	4,
	4,
	4,
	5,
	5,
	5,
	5,
	0,
}

local DISTANCE_BASE = {
	1,
	2,
	3,
	4,
	5,
	7,
	9,
	13,
	17,
	25,
	33,
	49,
	65,
	97,
	129,
	193,
	257,
	385,
	513,
	769,
	1025,
	1537,
	2049,
	3073,
	4097,
	6145,
	8193,
	12289,
	16385,
	24577,
}

local DISTANCE_EXTRA = {
	0,
	0,
	0,
	0,
	1,
	1,
	2,
	2,
	3,
	3,
	4,
	4,
	5,
	5,
	6,
	6,
	7,
	7,
	8,
	8,
	9,
	9,
	10,
	10,
	11,
	11,
	12,
	12,
	13,
	13,
}

local CODE_LENGTH_ORDER = {
	16,
	17,
	18,
	0,
	8,
	7,
	9,
	6,
	10,
	5,
	11,
	4,
	12,
	3,
	13,
	2,
	14,
	1,
	15,
}

local function newBitReader(data)
	return {
		data = data,
		bytePosition = 1,
		bitBuffer = 0,
		bitCount = 0,
	}
end

local function readBits(reader, count)
	while reader.bitCount < count do
		local nextByte = string.byte(reader.data, reader.bytePosition)
		if not nextByte then
			error("Unexpected end of DEFLATE stream.")
		end

		reader.bytePosition += 1
		reader.bitBuffer = bit32.bor(reader.bitBuffer, bit32.lshift(nextByte, reader.bitCount))
		reader.bitCount += 8
	end

	local mask = if count == 0 then 0 else bit32.lshift(1, count) - 1
	local value = bit32.band(reader.bitBuffer, mask)
	reader.bitBuffer = bit32.rshift(reader.bitBuffer, count)
	reader.bitCount -= count
	return value
end

local function alignToByte(reader)
	reader.bitBuffer = 0
	reader.bitCount = 0
end

local function buildHuffman(lengths)
	local counts = {
		[0] = 0,
	}
	local maximumLength = 0

	for _, length in ipairs(lengths) do
		counts[length] = (counts[length] or 0) + 1
		if length > 0 then
			maximumLength = math.max(maximumLength, length)
		end
	end

	local offsets = {
		[1] = 0,
	}
	for length = 1, maximumLength - 1 do
		offsets[length + 1] = offsets[length] + (counts[length] or 0)
	end

	local symbols = {}
	for symbolIndex, length in ipairs(lengths) do
		if length > 0 then
			local offset = offsets[length]
			symbols[offset] = symbolIndex - 1
			offsets[length] = offset + 1
		end
	end

	return {
		counts = counts,
		symbols = symbols,
		maximumLength = maximumLength,
	}
end

local function decodeSymbol(reader, tree)
	local code = 0
	local first = 0
	local symbolIndex = 0

	for length = 1, tree.maximumLength do
		code = bit32.bor(code, readBits(reader, 1))
		local count = tree.counts[length] or 0
		local difference = code - first
		if difference >= 0 and difference < count then
			return tree.symbols[symbolIndex + difference]
		end

		symbolIndex += count
		first = bit32.lshift(first + count, 1)
		code = bit32.lshift(code, 1)
	end

	error("Invalid Huffman code in DEFLATE stream.")
end

local function getFixedTrees()
	local literalLengths = table.create(288, 0)
	for symbol = 0, 287 do
		if symbol <= 143 or symbol >= 280 then
			literalLengths[symbol + 1] = 8
		elseif symbol <= 255 then
			literalLengths[symbol + 1] = 9
		else
			literalLengths[symbol + 1] = 7
		end
	end

	local distanceLengths = table.create(32, 5)
	return buildHuffman(literalLengths), buildHuffman(distanceLengths)
end

local function getDynamicTrees(reader)
	local literalCount = readBits(reader, 5) + 257
	local distanceCount = readBits(reader, 5) + 1
	local codeLengthCount = readBits(reader, 4) + 4
	local codeLengths = table.create(19, 0)

	for index = 1, codeLengthCount do
		codeLengths[CODE_LENGTH_ORDER[index] + 1] = readBits(reader, 3)
	end

	local codeLengthTree = buildHuffman(codeLengths)
	local lengths = {}
	local requiredLengthCount = literalCount + distanceCount

	while #lengths < requiredLengthCount do
		local symbol = decodeSymbol(reader, codeLengthTree)
		if symbol <= 15 then
			table.insert(lengths, symbol)
		elseif symbol == 16 then
			if #lengths == 0 then
				error("Invalid repeated code length in DEFLATE stream.")
			end
			local repeated = lengths[#lengths]
			for _ = 1, readBits(reader, 2) + 3 do
				table.insert(lengths, repeated)
			end
		elseif symbol == 17 then
			for _ = 1, readBits(reader, 3) + 3 do
				table.insert(lengths, 0)
			end
		elseif symbol == 18 then
			for _ = 1, readBits(reader, 7) + 11 do
				table.insert(lengths, 0)
			end
		else
			error("Invalid code-length symbol in DEFLATE stream.")
		end

		if #lengths > requiredLengthCount then
			error("DEFLATE code lengths exceed the announced count.")
		end
	end

	local literalLengths = table.create(literalCount)
	local distanceLengths = table.create(distanceCount)
	for index = 1, literalCount do
		literalLengths[index] = lengths[index]
	end
	for index = 1, distanceCount do
		distanceLengths[index] = lengths[literalCount + index]
	end

	return buildHuffman(literalLengths), buildHuffman(distanceLengths)
end

local function decodeCompressedBlock(reader, output, literalTree, distanceTree)
	while true do
		local symbol = decodeSymbol(reader, literalTree)
		if symbol < 256 then
			table.insert(output, symbol)
		elseif symbol == 256 then
			return
		elseif symbol <= 285 then
			local lengthIndex = symbol - 256
			local length = LENGTH_BASE[lengthIndex] + readBits(reader, LENGTH_EXTRA[lengthIndex])
			local distanceSymbol = decodeSymbol(reader, distanceTree)
			if distanceSymbol > 29 then
				error("Invalid DEFLATE distance symbol.")
			end

			local distanceIndex = distanceSymbol + 1
			local distance = DISTANCE_BASE[distanceIndex] + readBits(reader, DISTANCE_EXTRA[distanceIndex])
			if distance > #output then
				error(
					string.format(
						"DEFLATE distance %d points before output byte %d (literal symbol %d, distance symbol %d).",
						distance,
						#output,
						symbol,
						distanceSymbol
					)
				)
			end

			for _ = 1, length do
				table.insert(output, output[#output - distance + 1])
				if #output > MAX_OUTPUT_BYTES then
					error("Decompressed data exceeds the 128 MB safety limit.")
				end
			end
		else
			error("Invalid DEFLATE literal/length symbol.")
		end
	end
end

local function bytesToString(bytes)
	local parts = {}
	local chunkSize = 4096
	for startIndex = 1, #bytes, chunkSize do
		local endIndex = math.min(#bytes, startIndex + chunkSize - 1)
		table.insert(parts, string.char(table.unpack(bytes, startIndex, endIndex)))
	end
	return table.concat(parts)
end

function Deflate.decompress(data)
	local reader = newBitReader(data)
	local output = {}
	local isFinal = false

	while not isFinal do
		isFinal = readBits(reader, 1) == 1
		local blockType = readBits(reader, 2)

		if blockType == 0 then
			alignToByte(reader)
			local lengthLow = readBits(reader, 8)
			local lengthHigh = readBits(reader, 8)
			local length = lengthLow + lengthHigh * 256
			local inverseLength = readBits(reader, 8) + readBits(reader, 8) * 256
			if bit32.band(bit32.bnot(length), 0xFFFF) ~= inverseLength then
				error("Invalid uncompressed DEFLATE block length.")
			end
			for _ = 1, length do
				table.insert(output, readBits(reader, 8))
			end
		elseif blockType == 1 then
			local literalTree, distanceTree = getFixedTrees()
			decodeCompressedBlock(reader, output, literalTree, distanceTree)
		elseif blockType == 2 then
			local literalTree, distanceTree = getDynamicTrees(reader)
			decodeCompressedBlock(reader, output, literalTree, distanceTree)
		else
			error("Reserved DEFLATE block type.")
		end

		if #output > MAX_OUTPUT_BYTES then
			error("Decompressed data exceeds the 128 MB safety limit.")
		end
	end

	return bytesToString(output)
end

return Deflate
