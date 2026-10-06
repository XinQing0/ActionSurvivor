extends Label3D

## Floating name of a reaction, so the player can tell what just went off.
##
## Purely cosmetic and self-removing; nothing reads it.

const LIFETIME := 0.7
const RISE := 1.4

var _elapsed := 0.0
var _start_y := 0.0


func configure(text_value: String, color: Color) -> void:
    text = text_value
    modulate = color
    outline_modulate = Color(0.05, 0.04, 0.08)
    outline_size = 10
    font_size = 54
    pixel_size = 0.011
    billboard = BaseMaterial3D.BILLBOARD_ENABLED
    no_depth_test = true
    fixed_size = false


func _ready() -> void:
    _start_y = position.y


func _process(delta: float) -> void:
    _elapsed += delta
    var t := clampf(_elapsed / LIFETIME, 0.0, 1.0)
    position.y = _start_y + RISE * t
    modulate.a = 1.0 - t * t
    outline_modulate.a = modulate.a
    if t >= 1.0:
        queue_free()
