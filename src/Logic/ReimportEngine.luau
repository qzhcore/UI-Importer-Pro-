local VisualProperties = require(script.Parent.VisualProperties)
local ReimportEngine = {}

local function indexTree(root)
	local byId = {}
	local all = { root }
	for _, child in ipairs(root:GetDescendants()) do
		table.insert(all, child)
	end
	for _, instance in ipairs(all) do
		local id = instance:GetAttribute("DesignUID")
		if id then
			assert(
				type(id) == "string" and not byId[id],
				"Duplicate DesignUID; remove the duplicated import or assign distinct source IDs before updating"
			)
			byId[id] = instance
		end
	end
	return byId
end

function ReimportEngine.plan(existing, staged, job)
	assert(
		existing:GetAttribute("UIImporterStableIds") ~= false and staged:GetAttribute("UIImporterStableIds") ~= false,
		"This source lacks unique durable layer IDs. Re-import would be ambiguous; export stable node IDs or import separately."
	)
	assert(
		existing:GetAttribute("DesignUID") == staged:GetAttribute("DesignUID"),
		"Select a root imported by this version before re-importing"
	)
	assert(
		existing:GetAttribute("UIImporterDocumentId") == staged:GetAttribute("UIImporterDocumentId"),
		"The selected UI belongs to another design document"
	)
	assert(
		existing:GetAttribute("UIImporterVisualMode") == staged:GetAttribute("UIImporterVisualMode"),
		"Keep the same artwork mode when re-importing"
	)
	local old = indexTree(existing)
	indexTree(staged)
	local plan = { entries = {}, warnings = {}, existing = existing, staged = staged }
	local incoming = {}
	local function visit(source, parentEntry)
		if job then
			job:checkpoint()
		end
		local id = source:GetAttribute("DesignUID")
		assert(id, "Generated instance is missing DesignUID")
		local target = old[id]
		assert(
			not target or target.ClassName == source.ClassName,
			"Class conflict for "
				.. id
				.. "; existing instance preserved. Import separately or keep the original class."
		)
		local entry = { source = source, target = target, parentEntry = parentEntry, properties = {} }
		local moved = target and parentEntry and target.Parent ~= parentEntry.target
		local geometry =
			{ Size = true, Position = true, AnchorPoint = true, Rotation = true, LayoutOrder = true, ZIndex = true }
		for _, property in ipairs(VisualProperties.list(source)) do
			local ok, value = pcall(function()
				return source[property]
			end)
			if ok and not (moved and geometry[property]) then
				table.insert(entry.properties, { name = property, value = value })
			end
		end
		if moved then
			table.insert(
				plan.warnings,
				source.Name
					.. ": source hierarchy changed; existing parent and geometry preserved to protect script paths. Review this layer manually."
			)
		end
		incoming[id] = true
		table.insert(plan.entries, entry)
		for _, child in ipairs(source:GetChildren()) do
			visit(child, entry)
		end
	end
	visit(staged, nil)
	for id, target in pairs(old) do
		if not incoming[id] then
			table.insert(
				plan.warnings,
				target.Name .. ": absent from source; retained unchanged with its developer content."
			)
		end
	end
	return plan
end

-- The journal also handles failure in the caller's Studio undo commit.
function ReimportEngine.apply(plan, job)
	local journal, created = {}, {}
	local transaction = { root = plan.existing, warnings = plan.warnings, updated = 0, added = 0 }
	function transaction.rollback()
		local failures = {}
		for index = #journal, 1, -1 do
			local entry = journal[index]
			local ok, message = pcall(function()
				entry.instance[entry.property] = entry.value
			end)
			if not ok then
				table.insert(failures, tostring(message))
			end
		end
		for index = #created, 1, -1 do
			created[index]:Destroy()
		end
		if #failures > 0 then
			warn("[UI Importer Pro] Rollback needs Studio Undo: " .. table.concat(failures, "; "))
		end
		journal, created = {}, {}
	end
	local ok, message = pcall(function()
		for _, entry in ipairs(plan.entries) do
			if job then
				job:checkpoint()
			end
			local target = entry.target
			local isNew = target == nil
			if isNew then
				target = Instance.new(entry.source.ClassName)
				table.insert(created, target)
				target.Name = entry.source.Name
				for name, value in pairs(entry.source:GetAttributes()) do
					target:SetAttribute(name, value)
				end
				for _, tag in ipairs(entry.source:GetTags()) do
					target:AddTag(tag)
				end
				entry.target = target
				transaction.added += 1
			else
				transaction.updated += 1
			end
			for _, property in ipairs(entry.properties) do
				table.insert(journal, { instance = target, property = property.name, value = target[property.name] })
				target[property.name] = property.value
			end
			-- Only new objects get parented. Existing object identity/paths survive.
			if isNew then
				target.Parent = entry.parentEntry.target
			end
		end
	end)
	if not ok then
		transaction.rollback()
		error(message, 0)
	end
	return transaction
end

return ReimportEngine
