extends CharacterBody2D

const MOVE_SPEED := 260.0
const ARENA_BOUNDS := Rect2(Vector2(20.0, 20.0), Vector2(920.0, 500.0))


func _ready() -> void:
    queue_redraw()


func _physics_process(_delta: float) -> void:
    var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = direction * MOVE_SPEED
    move_and_slide()
    position = position.clamp(ARENA_BOUNDS.position, ARENA_BOUNDS.end)


func _draw() -> void:
    draw_circle(Vector2.ZERO, 13.0, Color(0.35, 0.9, 0.78))
    draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, Color(0.8, 1.0, 0.92), 2.0)
