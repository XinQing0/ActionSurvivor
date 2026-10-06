extends CanvasLayer

## The level-up choice screen.
##
## It runs while the rest of the tree is paused, so its process mode is set to
## always. Options are pickable with the mouse or with the number keys, because
## a survivors-like is played with one hand on the movement keys and reaching
## for the mouse every level-up breaks the rhythm.

const UiTheme := preload("res://src/ui/ui_theme.gd")

signal option_chosen(option: Dictionary)

var _options: Array[Dictionary] = []
var _root: Control
var _card_row: HBoxContainer


func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    hide_screen()


func present(options: Array[Dictionary], level: int) -> void:
    _options = options
    for child in _card_row.get_children():
        _card_row.remove_child(child)
        child.queue_free()

    for index in range(_options.size()):
        _card_row.add_child(_build_card(_options[index], index))

    _root.get_node("Scrim/Column/Title").text = "LEVEL %d" % level
    _root.visible = true


func hide_screen() -> void:
    _root.visible = false


func _unhandled_input(event: InputEvent) -> void:
    if not _root.visible:
        return
    var key_event := event as InputEventKey
    if key_event == null or not key_event.pressed or key_event.echo:
        return
    var index := key_event.keycode - KEY_1
    if index >= 0 and index < _options.size():
        get_viewport().set_input_as_handled()
        _choose(index)


func _choose(index: int) -> void:
    if index < 0 or index >= _options.size():
        return
    var option := _options[index]
    hide_screen()
    option_chosen.emit(option)


func _build() -> void:
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    var scrim := ColorRect.new()
    scrim.name = "Scrim"
    scrim.color = UiTheme.SCRIM
    scrim.anchor_right = 1.0
    scrim.anchor_bottom = 1.0
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(scrim)

    var column := VBoxContainer.new()
    column.name = "Column"
    column.anchor_left = 0.0
    column.anchor_top = 0.0
    column.anchor_right = 1.0
    column.anchor_bottom = 1.0
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 22)
    scrim.add_child(column)

    var title := UiTheme.make_label("LEVEL UP", 44, UiTheme.EMBER)
    title.name = "Title"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)

    var subtitle := UiTheme.make_label("Choose one. Press 1, 2 or 3.", 16, UiTheme.INK_DIM)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(subtitle)

    _card_row = HBoxContainer.new()
    _card_row.alignment = BoxContainer.ALIGNMENT_CENTER
    _card_row.add_theme_constant_override("separation", 18)
    column.add_child(_card_row)


func _build_card(option: Dictionary, index: int) -> Control:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(268.0, 190.0)
    panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, _accent_for(option)))

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 8)
    panel.add_child(body)

    var heading := UiTheme.make_label("%d.  %s" % [index + 1, str(option.get("name", "?"))], 21, UiTheme.INK)
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(heading)

    var detail := UiTheme.make_label(str(option.get("detail", "")), 14, _accent_for(option))
    body.add_child(detail)

    var description := UiTheme.make_label(str(option.get("description", "")), 15, UiTheme.INK_DIM)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(description)

    # A transparent button laid over the whole card keeps the rich text layout
    # of a container while still behaving like one clickable control.
    var hit_area := Button.new()
    hit_area.flat = true
    hit_area.anchor_right = 1.0
    hit_area.anchor_bottom = 1.0
    hit_area.focus_mode = Control.FOCUS_NONE
    hit_area.pressed.connect(_choose.bind(index))
    panel.add_child(hit_area)

    return panel


func _accent_for(option: Dictionary) -> Color:
    match str(option.get("kind", "")):
        "new_spell":
            return UiTheme.EMBER
        "spell_level":
            return UiTheme.EXPERIENCE
        "augment":
            return Color(0.82, 0.62, 1.0)
        _:
            return UiTheme.PANEL_EDGE.lightened(0.35)
