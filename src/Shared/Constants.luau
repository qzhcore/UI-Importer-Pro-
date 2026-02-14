local Constants = {
	VERSION = "1.0.0",
	
	CANVAS_SIZE = Vector2.new(1920, 1080),
	
	SUPPORTED_CLASSES = {
		"Frame",
		"TextLabel",
		"ImageLabel",
		"TextButton",
		"ImageButton",
		"TextBox",
		"ScrollingFrame",
		"ViewportFrame",
		"CanvasGroup"
	},
	
	ASPECT_RATIO_SETTINGS = {
		DominantAxis = Enum.DominantAxis.Width,
		AspectType = Enum.AspectType.FitWithinMaxSize
	}
}

return table.freeze(Constants)
