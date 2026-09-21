extends CanvasLayer

## A general full-screen overlay used for the title screen and the run result.
##
## Both screens are the same shape - a heading, some lines of text, and a short
## list of choices - so they share one implementation rather than two nearly
## identical ones.

const UiTheme := preload("res://src/ui/ui_theme.gd")

signal action_selected(action_id: String)

var _root: Control
var _title: Label
var _subtitle: Label
var _lines: VBoxContainer
var _buttons: VBoxContainer
var _actions: Array[String] = []


func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    hide_screen()


## `buttons` is an array of {id, label}.
func present(title: String, subtitle: String, lines: Array, buttons: Array, accent: Color = UiTheme.EMBER) -> void:
    _title.text = title
    _title.add_theme_color_override("font_color", accent)
    _subtitle.text = subtitle
    _subtitle.visible = not subtitle.is_empty()

    for child in _lines.get_children():
        _lines.remove_child(child)
        child.queue_free()
    for line in lines:
        var label := UiTheme.make_label(str(line), 17, UiTheme.INK_DIM)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _lines.add_child(label)

    for child in _buttons.get_children():
        _buttons.remove_child(child)
        child.queue_free()
    _actions.clear()

    for index in range(buttons.size()):
        var entry: Dictionary = buttons[index]
        var action_id := str(entry.get("id", ""))
        _actions.append(action_id)
        var button := Button.new()
        button.text = "%d.  %s" % [index + 1, str(entry.get("label", action_id))]
        button.custom_minimum_size = Vector2(340.0, 46.0)
        button.focus_mode = Control.FOCUS_NONE
        button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        button.add_theme_font_size_override("font_size", 18)
        button.pressed.connect(_emit_action.bind(action_id))
        _buttons.add_child(button)

    _root.visible = true


func hide_screen() -> void:
    _root.visible = false


func is_open() -> bool:
    return _root != null and _root.visible


func _unhandled_input(event: InputEvent) -> void:
    if not is_open():
        return
    var key_event := event as InputEventKey
    if key_event == null or not key_event.pressed or key_event.echo:
        return
    var index := key_event.keycode - KEY_1
    if index >= 0 and index < _actions.size():
        get_viewport().set_input_as_handled()
        _emit_action(_actions[index])


func _emit_action(action_id: String) -> void:
    hide_screen()
    action_selected.emit(action_id)


func _build() -> void:
    _root = Control.new()
    _root.anchor_right = 1.0
    _root.anchor_bottom = 1.0
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    var scrim := ColorRect.new()
    scrim.color = Color(0.02, 0.02, 0.04, 0.88)
    scrim.anchor_right = 1.0
    scrim.anchor_bottom = 1.0
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(scrim)

    var column := VBoxContainer.new()
    column.anchor_right = 1.0
    column.anchor_bottom = 1.0
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 14)
    scrim.add_child(column)

    _title = UiTheme.make_label("", 58, UiTheme.EMBER)
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_title)

    _subtitle = UiTheme.make_label("", 19, UiTheme.INK)
    _subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(_subtitle)

    _lines = VBoxContainer.new()
    _lines.add_theme_constant_override("separation", 4)
    column.add_child(_lines)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0.0, 12.0)
    column.add_child(spacer)

    _buttons = VBoxContainer.new()
    _buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    _buttons.add_theme_constant_override("separation", 8)
    column.add_child(_buttons)
