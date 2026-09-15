extends CharacterBody2D

var target: Node2D
var move_speed := 55.0
var health := 10.0
var radius := 9.0
var body_color := Color.WHITE


func configure(definition: Dictionary, new_target: Node2D) -> void:
    target = new_target
    move_speed = float(definition.get("speed", 55.0))
    health = float(definition.get("health", 10.0))
    radius = float(definition.get("radius", 9.0))
    body_color = Color.from_string(str(definition.get("color", "ffffff")), Color.WHITE)
    queue_redraw()


func _physics_process(_delta: float) -> void:
    if not is_instance_valid(target):
        velocity = Vector2.ZERO
        return
    velocity = global_position.direction_to(target.global_position) * move_speed
    move_and_slide()


func _draw() -> void:
    draw_circle(Vector2.ZERO, radius, body_color)
    draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 16, body_color.lightened(0.28), 2.0)
