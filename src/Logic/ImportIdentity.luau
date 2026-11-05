local ImportIdentity = {}

-- Called only on the newly built detached tree, never on developer content.
function ImportIdentity.stamp(root, documentId)
	root:SetAttribute("DesignUID", "$root")
	root:SetAttribute("UIImporterDocumentId", documentId)
	local function visit(parent)
		local counts = {}
		for _, child in ipairs(parent:GetChildren()) do
			local key = child.ClassName .. ":" .. child.Name
			counts[key] = (counts[key] or 0) + 1
			local id = child:GetAttribute("UIImporterSourceId")
				or parent:GetAttribute("DesignUID") .. "/helper:" .. key .. ":" .. counts[key]
			child:SetAttribute("DesignUID", id)
			child:SetAttribute("UIImporterGenerated", true)
			child:SetAttribute("UIImporterDocumentId", documentId)
			child:AddTag("UIImporterGenerated")
			visit(child)
		end
	end
	visit(root)
end

return ImportIdentity
