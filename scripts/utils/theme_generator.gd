@tool
extends ProgrammaticTheme

# Fonts
const FONT_REGULAR     = "res://themes/fonts/SpaceMono-Regular.ttf"
const FONT_BOLD        = "res://themes/fonts/SpaceMono-Bold.ttf"
const FONT_ITALIC      = "res://themes/fonts/SpaceMono-Italic.ttf"
const FONT_BOLD_ITALIC = "res://themes/fonts/SpaceMono-BoldItalic.ttf"

# Color Palette
const COLOR_BRIGHT  = Color("#ebebeb") # Text color for labels
const COLOR_SHADOW  = Color("#9cafb3") # Secondary text color
const COLOR_HOVER   = Color("#324a5f") # Button hover color
const COLOR_PRESSED = Color("#9ca0a3") # Button pressed color
const COLOR_MID     = Color("#889ca1") # Middle tone (text)
const COLOR_DARK    = Color("#565a5d") # Dark elements (borders)
const COLOR_BLACK   = Color("#242430") # Background color

# Theme Setup
func setup() -> void:
	set_save_path("res://themes/generated/theme.tres")

# Define Theme
func define_theme() -> void:
	_define_fonts()
	_define_styles()

# Define Fonts
func _define_fonts() -> void:
	define_default_font(ResourceLoader.load(FONT_REGULAR))
	define_default_font_size(14)

# Define Styles
func _define_styles() -> void:
	define_panel()
	define_labels()
	#define_buttons()
	#define_text_inputs()
	#define_lists()
	#define_scrollbar()
	#define_misc()
	pass

# Panel (Backgrounds)
func define_panel() -> void:
	var sb_panel = stylebox_flat({
		border_ = border_width(2),
		bg_color = COLOR_BLACK,
		border_color = COLOR_DARK,
		corners_ = corner_radius(3),
	})
	define_style("Panel",{
		panel = sb_panel
	})

# Labels
func define_labels() -> void:
	define_style("Label", {
		font_color = COLOR_BRIGHT,
	})
	define_style("TextEdit", {
		font_color = COLOR_BRIGHT
	})
	#define_style("RichTextLabel", {
		#default_color = COLOR_BRIGHT,
		#line_separation = 2,
		#focus = stylebox_flat({
			#border_ = border_width(2),
			#border_color = COLOR_SHADOW,
			#corners_ = corner_radius(2),
			#bg_color = COLOR_BLACK,
		#}),
		#normal = stylebox_flat({
			#bg_color = COLOR_BLACK,
		#})
	#})

# Buttons
func define_buttons() -> void:
	var sb_normal = stylebox_flat({
		border_ = border_width(2),
		bg_color = COLOR_BLACK,
		border_color = COLOR_DARK,
		corners_ = corner_radius(4),
		expand_margins_ = expand_margins(3),
		anti_aliasing = false,
	})
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = COLOR_HOVER
	var sb_focus = sb_normal.duplicate()
	sb_hover.bg_color = COLOR_HOVER
	var sb_pressed = sb_normal.duplicate()
	sb_pressed.bg_color = COLOR_PRESSED
	
	var sb_normal_mirrored = sb_normal.duplicate()
	sb_normal_mirrored.bg_color = COLOR_HOVER

	var sb_normal_no_border = sb_normal.duplicate()
	sb_normal_no_border.border_ = border_width(0)
	
	define_style("Button", {
		font_color         = COLOR_BRIGHT,
		normal  = sb_normal,
		focus   = sb_focus,
		hover   = sb_hover,
		pressed = sb_pressed,
		disabled = sb_pressed,
		hover_pressed = sb_pressed,
		normal_mirrored = sb_normal_mirrored,
	})
	
	define_style("CheckButton", {
		font_color         = COLOR_BRIGHT,
		font_focus_color   = COLOR_SHADOW,
		font_pressed_color = COLOR_SHADOW,
		font_hover_color   = COLOR_SHADOW,
		normal = sb_normal_no_border,
		focus = sb_normal_no_border,
		hover = sb_normal_no_border,
		pressed = sb_normal_no_border,
		disabled = sb_normal_no_border,
		hover_pressed = sb_normal_no_border,
	})
	
	define_style("OptionButton", {
		font_color = COLOR_BRIGHT,
		focus = stylebox_flat({ bg_color = COLOR_DARK, border_color = COLOR_SHADOW }),
		normal = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_SHADOW }),
		hover = stylebox_flat({ bg_color = COLOR_DARK, border_color = COLOR_SHADOW }),
		pressed = stylebox_flat({ bg_color = COLOR_DARK, border_color = COLOR_SHADOW }),
		disabled = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_DARK }),
	})
	
# Text Inputs (LineEdit, TextEdit)
func define_text_inputs() -> void:
	var sb_input = stylebox_flat({
		border_ = border_width(1),
		border_color = COLOR_SHADOW,
		bg_color = COLOR_BLACK,
		corners_ = corner_radius(4),
	})

	define_style("LineEdit", {
		font_color = COLOR_BRIGHT,
		normal = sb_input,
		focus = sb_input,
	})

	define_style("TextEdit", {
		font_color = COLOR_BRIGHT,
		normal = sb_input,
		focus = sb_input,
	})
	
# Lists (ItemList, Tree, OptionButton)
func define_lists() -> void:
	define_style("ItemList", {
		font_color = COLOR_BRIGHT,
		font_selected_color = COLOR_BRIGHT,
		panel = stylebox_flat({ bg_color = COLOR_BLACK })
	})

	define_style("Tree", {
		font_color = COLOR_BRIGHT,
		font_selected_color = COLOR_BRIGHT,
		panel = stylebox_flat({ bg_color = COLOR_BLACK })
	})


# ScrollBar
func define_scrollbar() -> void:
	var sb_scroll = stylebox_flat({
		bg_color = COLOR_DARK,
		corners_ = corner_radius(2),
	})

	define_style("HScrollBar", {
		grabber = sb_scroll,
		grabber_highlight = sb_scroll,
	})

	define_style("VScrollBar", {
		grabber = sb_scroll,
		grabber_highlight = sb_scroll,
	})

	# Ensure ScrollContainer has a proper background
	define_style("ScrollContainer", {
		bg_color = COLOR_BLACK,  # Fix bright background
	})

# Miscellaneous UI (Sliders, Checkboxes)
func define_misc() -> void:
	var sb_normal = stylebox_flat({
		border_ = border_width(2),
		border_color = COLOR_DARK,
		corners_ = corner_radius(4),
		bg_color = COLOR_BLACK,
		expand_margins_ = expand_margins(3),
		anti_aliasing = false,
	})
	
	var sb_slider = stylebox_flat({
		bg_color = COLOR_DARK,
		corners_ = corner_radius(2),
	})

	define_style("Slider", {
		grabber = sb_slider,
		grabber_highlight = sb_slider,
	})

	define_style("CheckBox", {
		font_color         = COLOR_BRIGHT,
		font_focus_color   = COLOR_SHADOW,
		font_pressed_color = COLOR_SHADOW,
		font_hover_color   = COLOR_SHADOW,
		focus = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_SHADOW }),
		normal = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_SHADOW }),
		hover = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_SHADOW }),
		pressed = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_SHADOW }),
		disabled = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_SHADOW }),
		hover_pressed = stylebox_flat({ bg_color = COLOR_BLACK, border_color = COLOR_SHADOW }),
	})
