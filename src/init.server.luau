local DesignImporter = require(script.Logic.DesignImporter)
local Toolbar = require(script.Plugin.Toolbar)

Toolbar.init(plugin, function(progressCallback, options)
	return DesignImporter.promptAndImport(progressCallback, options)
end)
