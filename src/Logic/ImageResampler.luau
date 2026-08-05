local ImageResampler = {}

local MAX_OUTPUT_PIXELS = 4 * 1024 * 1024
local MAX_SCALE = 4
local SHARPEN_AMOUNT = 0.35

local function pixelOffset(width, x, y)
	return (y * width + x) * 4
end

local function clampedByte(value)
	return math.clamp(math.floor(value + 0.5), 0, 255)
end

local function fitOutputSize(sourceWidth, sourceHeight, requestedWidth, requestedHeight)
	local targetWidth = math.min(requestedWidth, sourceWidth * MAX_SCALE)
	local targetHeight = math.min(requestedHeight, sourceHeight * MAX_SCALE)
	if targetWidth * targetHeight > MAX_OUTPUT_PIXELS then
		local scale = math.sqrt(MAX_OUTPUT_PIXELS / (targetWidth * targetHeight))
		targetWidth *= scale
		targetHeight *= scale
	end
	return math.max(sourceWidth, math.floor(targetWidth + 0.5)), math.max(sourceHeight, math.floor(targetHeight + 0.5))
end

local function bilinearResize(source, sourceWidth, sourceHeight, targetWidth, targetHeight)
	local resized = buffer.create(targetWidth * targetHeight * 4)
	for targetY = 0, targetHeight - 1 do
		local sourceY = math.clamp((targetY + 0.5) * sourceHeight / targetHeight - 0.5, 0, sourceHeight - 1)
		local top = math.floor(sourceY)
		local bottom = math.min(sourceHeight - 1, top + 1)
		local verticalMix = sourceY - top
		for targetX = 0, targetWidth - 1 do
			local sourceX = math.clamp((targetX + 0.5) * sourceWidth / targetWidth - 0.5, 0, sourceWidth - 1)
			local left = math.floor(sourceX)
			local right = math.min(sourceWidth - 1, left + 1)
			local horizontalMix = sourceX - left
			local topLeft = pixelOffset(sourceWidth, left, top)
			local topRight = pixelOffset(sourceWidth, right, top)
			local bottomLeft = pixelOffset(sourceWidth, left, bottom)
			local bottomRight = pixelOffset(sourceWidth, right, bottom)
			local targetOffset = pixelOffset(targetWidth, targetX, targetY)
			for channel = 0, 3 do
				local topValue = buffer.readu8(source, topLeft + channel) * (1 - horizontalMix)
					+ buffer.readu8(source, topRight + channel) * horizontalMix
				local bottomValue = buffer.readu8(source, bottomLeft + channel) * (1 - horizontalMix)
					+ buffer.readu8(source, bottomRight + channel) * horizontalMix
				buffer.writeu8(
					resized,
					targetOffset + channel,
					clampedByte(topValue * (1 - verticalMix) + bottomValue * verticalMix)
				)
			end
		end
	end
	return resized
end

local function sharpen(source, width, height)
	local sharpened = buffer.create(width * height * 4)
	for y = 0, height - 1 do
		local above = math.max(0, y - 1)
		local below = math.min(height - 1, y + 1)
		for x = 0, width - 1 do
			local left = math.max(0, x - 1)
			local right = math.min(width - 1, x + 1)
			local centerOffset = pixelOffset(width, x, y)
			for channel = 0, 2 do
				local center = buffer.readu8(source, centerOffset + channel)
				local neighborAverage = (
					buffer.readu8(source, pixelOffset(width, left, y) + channel)
					+ buffer.readu8(source, pixelOffset(width, right, y) + channel)
					+ buffer.readu8(source, pixelOffset(width, x, above) + channel)
					+ buffer.readu8(source, pixelOffset(width, x, below) + channel)
				) / 4
				buffer.writeu8(
					sharpened,
					centerOffset + channel,
					clampedByte(center + (center - neighborAverage) * SHARPEN_AMOUNT)
				)
			end
			buffer.writeu8(sharpened, centerOffset + 3, buffer.readu8(source, centerOffset + 3))
		end
	end
	return sharpened
end

function ImageResampler.upscaleSharpened(image, requestedWidth, requestedHeight)
	local sourceWidth = image.width
	local sourceHeight = image.height
	requestedWidth = math.max(1, math.floor(requestedWidth + 0.5))
	requestedHeight = math.max(1, math.floor(requestedHeight + 0.5))
	if requestedWidth <= sourceWidth or requestedHeight <= sourceHeight then
		return image
	end

	local targetWidth, targetHeight = fitOutputSize(sourceWidth, sourceHeight, requestedWidth, requestedHeight)
	if targetWidth == sourceWidth and targetHeight == sourceHeight then
		return image
	end
	local resized = bilinearResize(image.pixels, sourceWidth, sourceHeight, targetWidth, targetHeight)
	return {
		width = targetWidth,
		height = targetHeight,
		pixels = sharpen(resized, targetWidth, targetHeight),
		sourceWidth = sourceWidth,
		sourceHeight = sourceHeight,
	}
end

return ImageResampler
