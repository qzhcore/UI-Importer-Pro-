local fs = require("@lune/fs")

-- Runs production modules unchanged, resolving Roblox script.Parent requires.
return function(globals, overrides)
	local cache = {}
	local loadModule
	loadModule = function(name)
		if overrides and overrides[name] then
			return overrides[name]
		end
		if cache[name] then
			return cache[name]
		end
		local parent = setmetatable({}, {
			__index = function(_, key)
				return { moduleName = key }
			end,
		})
		local path = "src/Logic/" .. name .. ".luau"
		local chunk = assert(loadstring(fs.readFile(path), "@" .. path))
		local environment = setmetatable({
			script = { Parent = parent },
			require = function(token)
				return loadModule(token.moduleName)
			end,
		}, {
			__index = function(_, key)
				if globals and globals[key] ~= nil then
					return globals[key]
				end
				return getfenv(0)[key]
			end,
		})
		setfenv(chunk, environment)
		local result = chunk()
		cache[name] = result
		return result
	end
	return loadModule
end
