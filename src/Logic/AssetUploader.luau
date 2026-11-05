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

local function createTileContent(pixels, tileX, tileY, tileWidth, tileHeight, layerName, options, job)
	local editableImage = AssetService:CreateEditableImage({
		Size = Vector2.new(tileWidth, tileHeight),
	})

	if not editableImage then
		return nil, "Studio could not allocate an EditableImage. Close other image-heavy tools and try again."
	end

	local assetId
	local ok, contentOrError = pcall(function()
		editableImage:WritePixelsBuffer(Vector2.zero, Vector2.new(tileWidth, tileHeight), pixels)
		if options and options.imageStorage == "RobloxAsset" then
			local parameters = {
				Name = string.sub(layerName, 1, 40) .. string.format("_%d_%d", tileX, tileY),
				Description = "Artwork imported with UI Importer Pro",
			}
			if options.assetOwner == "Experience" then
				if game.CreatorId <= 0 then
					error("Publish the place first or choose your own account as the artwork owner.", 0)
				end
				parameters.CreatorId = game.CreatorId
				parameters.CreatorType = if game.CreatorType == Enum.CreatorType.Group
					then Enum.AssetCreatorType.Group
					else Enum.AssetCreatorType.User
			elseif options.assetOwner ~= "User" then
				error("Choose an artwork owner before uploading.", 0)
			end
			local result, idOrError = AssetService:CreateAssetAsync(editableImage, Enum.AssetType.Image, parameters)
			if result ~= Enum.CreateAssetResult.Success then
				error(string.format("Image upload failed (%s): %s", tostring(result), tostring(idOrError)), 0)
			end
			assetId = idOrError
			-- Record the remote side effect before checking cancellation after this yielding call.
			if job then
				table.insert(job.uploadedAssets, { id = assetId, name = parameters.Name })
			end
			return Content.fromUri("rbxassetid://" .. tostring(assetId))
		end
		local result, content = AssetService:CreateDataModelContentAsync(Content.fromObject(editableImage))
		if result ~= Enum.CreateContentResult.Success then
			error(string.format("%s: %s", tostring(result), tostring(content)), 0)
		end
		return content
	end)

	editableImage:Destroy()

	if not ok then
		return nil, tostring(contentOrError)
	end
	if job then
		job:checkpoint()
	end

	return {
		content = contentOrError,
		assetId = assetId,
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

function AssetUploader.createLayerContent(layer, progressCallback, job, options)
	local storage = options and options.imageStorage or "Session"
	if storage ~= "Session" and storage ~= "RobloxAsset" then
		error("Unsupported image storage mode.", 0)
	end
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
			if job then
				job:checkpoint()
			end
			tileIndex += 1
			local tileX = column * MAX_IMAGE_SIZE
			local tileY = row * MAX_IMAGE_SIZE
			local tileWidth = math.min(MAX_IMAGE_SIZE, pixelWidth - tileX)
			local tileHeight = math.min(MAX_IMAGE_SIZE, pixelHeight - tileY)
			local tilePixels = copyTilePixels(layer.pixels, pixelWidth, tileX, tileY, tileWidth, tileHeight)

			if progressCallback then
				progressCallback(tileIndex, tileCount)
			end
			if job then
				job:checkpoint()
			end

			local tile, contentError = createTileContent(
				tilePixels,
				tileX,
				tileY,
				tileWidth,
				tileHeight,
				layer.name or "ImportedArtwork",
				options,
				job
			)
			if not tile then
				return nil, contentError
			end

			table.insert(tiles, tile)
		end
	end

	return tiles, nil
end

return AssetUploader
