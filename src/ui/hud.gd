extends CanvasLayer

## In-run HUD.
##
## Everything is built in code so the prototype has no scene files to keep in
## sync while the layout is still changing. Anchors and offsets are set
## explicitly rather than through presets, because the preset helpers also
## rewrite offsets and the result depends on the order the calls are made in.

const UiTheme := preload("res://src/ui/ui_theme.gd")

const MARGIN := 20.0

var _clock_label: Label
var _wave_label: Label
var _level_label: Label
var _experience_bar: ProgressBar
var _health_bar: ProgressBar
var _health_label: Label
var _spell_list: VBoxContainer


func _ready() -> void:
    layer = 1
    _build_clock()
    _build_player_panel()
    _build_spell_list()


func update_run(elapsed: float, duration: float, wave: int, alive: int, killed: int) -> void:
    var remaining := int(maxf(duration - elapsed, 0.0))
    _clock_label.text = "%d:%02d" % [remaining / 60, remaining % 60]
    _wave_label.text = "WAVE %d      %d ALIVE      %d SLAIN" % [wave, alive, killed]


func update_level(level: int, progress: float) -> void:
    _level_label.text = "LEVEL %d" % level
    _experience_bar.value = progress


func update_health(current: float, maximum: float) -> void:
    _health_bar.max_value = maxf(maximum, 1.0)
    _health_bar.value = clampf(current, 0.0, maximum)
    _health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]


## `spells` is an array of {name, level, max_level}. An entry with
## `augment: true` is listed by name only, below the spells it modifies.
func update_spells(spells: Array) -> void:
    for child in _spell_list.get_children():
        _spell_list.remove_child(child)
        child.queue_free()
    for entry in spells:
        if bool(entry.get("augment", false)):
            var tag := UiTheme.make_label(str(entry.get("name", "?")), 14, Color(0.82, 0.62, 1.0))
            tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            _spell_list.add_child(tag)
            continue
        var level := int(entry.get("level", 1))
        var max_level := int(entry.get("max_level", 5))
        var pips := "*".repeat(level) + ".".repeat(maxi(max_level - level, 0))
        var color: Color = UiTheme.EMBER if level >= max_level else UiTheme.INK
        var row := UiTheme.make_label("%s   %s" % [str(entry.get("name", "?")), pips], 15, color)
        row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        _spell_list.add_child(row)


func _build_clock() -> void:
    var column := VBoxContainer.new()
    _anchor(column, 0.5, 0.0, 0.5, 0.0, -220.0, MARGIN, 220.0, MARGIN + 88.0)
    column.add_theme_constant_override("separation", 0)
    add_child(column)

    _clock_label = UiTheme.make_label("0:00", 42, UiTheme.INK)
    _clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_clock_label)

    _wave_label = UiTheme.make_label("", 15, UiTheme.INK_DIM)
    _wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_wave_label)


func _build_player_panel() -> void:
    var column := VBoxContainer.new()
    _anchor(column, 0.0, 1.0, 0.0, 1.0, MARGIN, -(MARGIN + 104.0), MARGIN + 300.0, -MARGIN)
    column.add_theme_constant_override("separation", 4)
    add_child(column)

    _level_label = UiTheme.make_label("LEVEL 1", 17, UiTheme.EXPERIENCE)
    column.add_child(_level_label)

    _experience_bar = UiTheme.make_bar(UiTheme.EXPERIENCE, 8)
    _experience_bar.value = 0.0
    column.add_child(_experience_bar)

    _health_label = UiTheme.make_label("100 / 100", 18, UiTheme.INK)
    column.add_child(_health_label)

    _health_bar = UiTheme.make_bar(UiTheme.HEALTH, 16)
    column.add_child(_health_bar)


func _build_spell_list() -> void:
    _spell_list = VBoxContainer.new()
    _anchor(_spell_list, 1.0, 1.0, 1.0, 1.0, -(MARGIN + 320.0), -(MARGIN + 200.0), -MARGIN, -MARGIN)
    _spell_list.alignment = BoxContainer.ALIGNMENT_END
    _spell_list.add_theme_constant_override("separation", 3)
    add_child(_spell_list)


func _anchor(
    control: Control,
    anchor_x: float,
    anchor_y: float,
    anchor_x_end: float,
    anchor_y_end: float,
    left: float,
    top: float,
    right: float,
    bottom: float
) -> void:
    control.anchor_left = anchor_x
    control.anchor_top = anchor_y
    control.anchor_right = anchor_x_end
    control.anchor_bottom = anchor_y_end
    control.offset_left = left
    control.offset_top = top
    control.offset_right = right
    control.offset_bottom = bottom
