-- One job is shared by every stage. No module-global cancellation state.
local ImportJob = {}
ImportJob.__index = ImportJob

ImportJob.Limits = table.freeze({
	fileBytes = 100000000,
	layers = 10000,
	depth = 128,
	imagePixels = 16 * 1024 * 1024,
	decodedBytes = 256 * 1024 * 1024,
	archiveBytes = 128 * 1024 * 1024,
})

function ImportJob.new(options)
	options = options or {}
	return setmetatable({
		cancelled = false,
		decodedBytes = 0,
		uploadedAssets = {},
		limits = ImportJob.Limits,
		lastYield = os.clock(),
		yieldCallback = options.yieldCallback,
		progressCallback = options.progressCallback,
	}, ImportJob)
end

function ImportJob:cancel()
	self.cancelled = true
end

function ImportJob:fail(message)
	self.failure = message
	error(message, 0)
end

function ImportJob:checkpoint(forceYield)
	if self.failure then
		error(self.failure, 0)
	end
	if self.cancelled then
		error("Import cancelled.", 0)
	end
	if self.yieldCallback and (forceYield or os.clock() - self.lastYield >= 0.016) then
		self.yieldCallback()
		self.lastYield = os.clock()
	end
	if self.cancelled then
		error("Import cancelled.", 0)
	end
end

function ImportJob:progress(update)
	self:checkpoint()
	if self.progressCallback then
		self.progressCallback(update)
	end
end

function ImportJob:reserveBytes(count)
	if count < 0 or count ~= count or count == math.huge or self.decodedBytes + count > self.limits.decodedBytes then
		self:fail("This design exceeds the 256 MB decoded-data budget. Import a smaller document.")
	end
	self.decodedBytes += count
	self:checkpoint()
end

function ImportJob:checkImage(width, height)
	if
		width ~= width
		or height ~= height
		or width < 0
		or height < 0
		or width % 1 ~= 0
		or height % 1 ~= 0
		or width * height > self.limits.imagePixels
	then
		self:fail("An image exceeds the 16 megapixel limit or has invalid dimensions.")
	end
end

return ImportJob
