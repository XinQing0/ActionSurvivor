extends Object

## Shared colours and panel styles.
##
## The palette is deliberately narrow: a warm ember accent against a cold
## purple dark, matching the alchemy-workshop setting, with one saturated
## colour per meaning (health, experience, danger) so the HUD stays readable
## against a crowded arena.

const INK := Color(0.93, 0.90, 0.82)
const INK_DIM := Color(0.66, 0.63, 0.74)
const EMBER := Color(1.0, 0.71, 0.36)
const HEALTH := Color(0.94, 0.38, 0.42)
const EXPERIENCE := Color(0.49, 0.91, 0.69)
const PANEL := Color(0.09, 0.08, 0.13, 0.92)
const PANEL_EDGE := Color(0.34, 0.28, 0.44)
const SCRIM := Color(0.02, 0.02, 0.04, 0.72)


static func panel_style(fill: Color = PANEL, edge: Color = PANEL_EDGE) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = edge
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(14)
    return style


static func bar_style(fill: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.set_corner_radius_all(4)
    return style


static func make_label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label


static func make_bar(fill: Color, height: int) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0.0, float(height))
    bar.max_value = 1.0
    bar.value = 1.0
    bar.add_theme_stylebox_override("background", bar_style(Color(0.16, 0.14, 0.2)))
    bar.add_theme_stylebox_override("fill", bar_style(fill))
    return bar
