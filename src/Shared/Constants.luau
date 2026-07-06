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
		"CanvasGroup",
	},

	ASPECT_RATIO_SETTINGS = {
		DominantAxis = Enum.DominantAxis.Width,
		AspectType = Enum.AspectType.FitWithinMaxSize,
	},

	LAYOUT_CLASSES = {
		"UIListLayout",
		"UIGridLayout",
		"UIPageLayout",
		"UITableLayout",
	},

	ORGANIZER = {
		MIN_CHILDREN = 3,
		ALIGNMENT_TOLERANCE = 6,
		SIZE_TOLERANCE = 8,
		GRID_TOLERANCE = 10,
		PAGE_COVERAGE = 0.8,
	},
}

return table.freeze(Constants)
