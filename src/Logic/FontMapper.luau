-- Only supported bundled families. Inter is an explicit approximation.
local FontMapper = {}
local FAMILIES = table.freeze({
	arial = "Arimo",
	helvetica = "Arimo",
	arimo = "Arimo",
	inter = "BuilderSans",
	sfpro = "BuilderSans",
	sfprodisplay = "BuilderSans",
	sfprotext = "BuilderSans",
	buildersans = "BuilderSans",
	gotham = "Montserrat",
	gothamssm = "Montserrat",
	montserrat = "Montserrat",
	roboto = "Roboto",
	robotomono = "RobotoMono",
	robotocondensed = "RobotoCondensed",
	sourcesans = "SourceSansPro",
	sourcesanspro = "SourceSansPro",
	nunito = "Nunito",
	ubuntu = "Ubuntu",
	oswald = "Oswald",
	merriweather = "Merriweather",
	fredoka = "FredokaOne",
	fredokaone = "FredokaOne",
	bangers = "Bangers",
	amaticsc = "AmaticSC",
	creepster = "Creepster",
	denkone = "DenkOne",
	inconsolata = "Inconsolata",
	jura = "Jura",
	luckiestguy = "LuckiestGuy",
})
local WEIGHTS = {
	Enum.FontWeight.Thin,
	Enum.FontWeight.ExtraLight,
	Enum.FontWeight.Light,
	Enum.FontWeight.Regular,
	Enum.FontWeight.Medium,
	Enum.FontWeight.SemiBold,
	Enum.FontWeight.Bold,
	Enum.FontWeight.ExtraBold,
	Enum.FontWeight.Heavy,
}

function FontMapper.resolve(family)
	local key = string.lower(string.gsub(family or "BuilderSans", "[^%w]", ""))
	local mapped = FAMILIES[key] or "BuilderSans"
	return mapped, key ~= string.lower(mapped)
end

function FontMapper.apply(instance, layer)
	local family, substituted = FontMapper.resolve(layer.fontFamily)
	local weight = WEIGHTS[math.clamp(math.floor((layer.fontWeight or 400) / 100 + 0.5), 1, 9)]
	local ok, face =
		pcall(Font.fromName, family, weight, if layer.fontItalic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
	if ok then
		instance.FontFace = face
	else
		instance.Font = Enum.Font.BuilderSans
		substituted = true
	end
	if substituted and layer.fontFamily then
		instance:SetAttribute("UIImporterOriginalFont", layer.fontFamily)
		instance:SetAttribute("UIImporterFontFallback", family)
	end
end

return FontMapper
