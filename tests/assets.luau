local roblox = require("@lune/roblox")
local loader = require("./ModuleLoader")
local ImportJob = loader()("ImportJob")
local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	assert(ok, name .. ": " .. tostring(message))
	passed += 1
	print("PASS " .. name)
end
local function harness(behavior)
	local state = { created = 0, destroyed = 0, uploads = {}, previews = 0, writes = {} }
	local service = {}
	function service:CreateEditableImage()
		state.created += 1
		return {
			WritePixelsBuffer = function(_, _, _, pixels)
				if behavior == "writeFailure" then
					error("write failed")
				end
				table.insert(state.writes, buffer.tostring(pixels))
			end,
			Destroy = function()
				state.destroyed += 1
			end,
		}
	end
	function service:CreateDataModelContentAsync()
		state.previews += 1
		return "Success", "session-content"
	end
	function service:CreateAssetAsync(_, assetType, parameters)
		assert(assetType == "Image", "Expected an image upload")
		table.insert(state.uploads, parameters)
		if behavior == "uploadFailure" then
			return "Denied", "no permission"
		end
		if state.onUpload then
			state.onUpload()
		end
		return "Success", 1000 + #state.uploads
	end
	local globals = {
		game = {
			CreatorId = 42,
			CreatorType = "Group",
			GetService = function()
				return service
			end,
		},
		Enum = {
			CreateAssetResult = { Success = "Success" },
			CreateContentResult = { Success = "Success" },
			AssetType = { Image = "Image" },
			CreatorType = { Group = "Group" },
			AssetCreatorType = { Group = "AssetGroup", User = "AssetUser" },
		},
		Vector2 = roblox.Vector2,
		Content = {
			fromUri = function(uri)
				return uri
			end,
			fromObject = function(object)
				return object
			end,
		},
	}
	return loader(globals)("AssetUploader"), state
end
local function layer(width)
	local pixels = buffer.create(width * 4)
	for index = 0, width - 1 do
		buffer.writeu32(pixels, index * 4, index)
	end
	return { name = "Fixture", width = width, height = 1, pixels = pixels }
end

test("session previews never upload image assets and release editable storage", function()
	local uploader, state = harness()
	local tiles = uploader.createLayerContent(layer(2), nil, ImportJob.new())
	assert(#state.uploads == 0 and state.previews == 1, "Unexpected storage backend")
	assert(tiles[1].content == "session-content", "Missing preview")
	assert(state.created == state.destroyed, "EditableImage leaked")
end)

test("persistent image tiles use the experience owner and preserve edge pixels", function()
	local uploader, state = harness()
	local job = ImportJob.new()
	local source = layer(1025)
	local tiles =
		uploader.createLayerContent(source, nil, job, { imageStorage = "RobloxAsset", assetOwner = "Experience" })
	assert(#tiles == 2 and #state.uploads == 2 and state.previews == 0, "Wrong tile/upload count")
	assert(state.uploads[1].CreatorId == 42 and state.uploads[1].CreatorType == "AssetGroup", "Wrong owner")
	assert(tiles[2].x == 1024 and tiles[2].width == 1, "Wrong edge geometry")
	assert(state.writes[1] .. state.writes[2] == buffer.tostring(source.pixels), "Pixels changed during tiling")
	assert(tiles[2].content == "rbxassetid://1002" and tiles[2].assetId == 1002, "Missing durable asset reference")
	assert(#job.uploadedAssets == 2 and state.created == state.destroyed, "Missing receipt or leaked image")
end)

test("account uploads use the logged-in user's default owner", function()
	local uploader, state = harness()
	uploader.createLayerContent(layer(1), nil, ImportJob.new(), { imageStorage = "RobloxAsset", assetOwner = "User" })
	assert(state.uploads[1].CreatorId == nil and state.uploads[1].CreatorType == nil, "Wrong user owner")
end)

test("failed writes and rejected uploads release editable images", function()
	for _, behavior in ipairs({ "writeFailure", "uploadFailure" }) do
		local uploader, state = harness(behavior)
		local job = ImportJob.new()
		local tiles, message =
			uploader.createLayerContent(layer(1), nil, job, { imageStorage = "RobloxAsset", assetOwner = "User" })
		assert(tiles == nil and type(message) == "string", "Expected upload failure")
		assert(state.created == state.destroyed and #job.uploadedAssets == 0, "Leaked image or false receipt")
	end
end)

test("cancellation during an upload retains its receipt and stops the next tile", function()
	local uploader, state = harness()
	local job = ImportJob.new()
	state.onUpload = function()
		job:cancel()
	end
	local ok, message = pcall(function()
		uploader.createLayerContent(layer(1025), nil, job, { imageStorage = "RobloxAsset", assetOwner = "User" })
	end)
	assert(not ok and string.find(tostring(message), "cancelled", 1, true), "Cancellation was ignored")
	assert(#state.uploads == 1 and job.uploadedAssets[1].id == 1001, "Lost upload receipt")
	assert(state.created == state.destroyed, "EditableImage leaked")
end)

test("invalid storage modes cannot silently fall back to temporary content", function()
	local uploader, state = harness()
	local ok = pcall(function()
		uploader.createLayerContent(layer(1), nil, ImportJob.new(), { imageStorage = "Typo" })
	end)
	assert(not ok and state.created == 0, "Invalid storage mode accepted")
end)

test("cancellation from progress prevents starting an upload", function()
	local uploader, state = harness()
	local job = ImportJob.new()
	local ok = pcall(function()
		uploader.createLayerContent(layer(1), function()
			job:cancel()
		end, job, { imageStorage = "RobloxAsset", assetOwner = "User" })
	end)
	assert(not ok and #state.uploads == 0 and state.created == 0, "Upload started after cancellation")
end)

print(string.format("All %d artwork storage tests passed.", passed))
