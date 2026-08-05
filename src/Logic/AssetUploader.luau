local AssetService = game:GetService("AssetService")

local AssetUploader = {}

local MAX_IMAGE_SIZE = 1024

local function copyTilePixels(source, sourceWidth, tileX, tileY, tileWidth, tileHeight)
	local tile = buffer.create(tileWidth * tileHeight * 4)

	for row = 0, tileHeight - 1 do
		local sourceOffset = (((tileY + row) * sourceWidth) + tileX) * 4
		local targetOffset = row * tileWidth * 4
		buffer.copy(tile, targetOffset, source, sourceOffset, tileWidth * 4)
	end

	return tile
end

local function createTileContent(pixels, tileX, tileY, tileWidth, tileHeight)
	local editableImage = AssetService:CreateEditableImage({
		Size = Vector2.new(tileWidth, tileHeight),
	})

	if not editableImage then
		return nil, "Studio could not allocate an EditableImage. Close other image-heavy tools and try again."
	end

	editableImage:WritePixelsBuffer(Vector2.zero, Vector2.new(tileWidth, tileHeight), pixels)

	local ok, result, contentOrError = pcall(function()
		local objectContent = Content.fromObject(editableImage)
		return AssetService:CreateDataModelContentAsync(objectContent)
	end)

	editableImage:Destroy()

	if not ok then
		return nil, tostring(result)
	end

	if result ~= Enum.CreateContentResult.Success then
		return nil, string.format("%s: %s", tostring(result), tostring(contentOrError))
	end

	return {
		content = contentOrError,
		x = tileX,
		y = tileY,
		width = tileWidth,
		height = tileHeight,
	}
end

function AssetUploader.countTiles(layer)
	local pixelWidth = layer.pixelWidth or layer.width
	local pixelHeight = layer.pixelHeight or layer.height
	if not layer.pixels or pixelWidth <= 0 or pixelHeight <= 0 then
		return 0
	end

	return math.ceil(pixelWidth / MAX_IMAGE_SIZE) * math.ceil(pixelHeight / MAX_IMAGE_SIZE)
end

function AssetUploader.createLayerContent(layer, progressCallback)
	local pixelWidth = layer.pixelWidth or layer.width
	local pixelHeight = layer.pixelHeight or layer.height
	if not layer.pixels or pixelWidth <= 0 or pixelHeight <= 0 then
		return {}, nil
	end

	local columns = math.ceil(pixelWidth / MAX_IMAGE_SIZE)
	local rows = math.ceil(pixelHeight / MAX_IMAGE_SIZE)
	local tileCount = columns * rows
	local tiles = table.create(tileCount)
	local tileIndex = 0

	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			tileIndex += 1
			local tileX = column * MAX_IMAGE_SIZE
			local tileY = row * MAX_IMAGE_SIZE
			local tileWidth = math.min(MAX_IMAGE_SIZE, pixelWidth - tileX)
			local tileHeight = math.min(MAX_IMAGE_SIZE, pixelHeight - tileY)
			local tilePixels = copyTilePixels(layer.pixels, pixelWidth, tileX, tileY, tileWidth, tileHeight)

			if progressCallback then
				progressCallback(tileIndex, tileCount)
			end

			local tile, contentError = createTileContent(tilePixels, tileX, tileY, tileWidth, tileHeight)
			if not tile then
				return nil, contentError
			end

			table.insert(tiles, tile)
		end
	end

	return tiles, nil
end

return AssetUploader
