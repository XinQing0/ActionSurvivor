extends Node2D

const WAVE_CONFIG_PATH := "res://config/waves_demo.json"
const ARENA_SIZE := Vector2(960.0, 540.0)
const PlayerAvatar := preload("res://src/gameplay/player_avatar.gd")
const WaveDirector := preload("res://src/gameplay/wave_director.gd")

var player: CharacterBody2D
var director: Node
var status_label: Label


func _ready() -> void:
    _create_arena()
    player = PlayerAvatar.new()
    player.position = ARENA_SIZE * 0.5
    add_child(player)

    director = WaveDirector.new()
    director.configure(WAVE_CONFIG_PATH, Rect2(Vector2.ZERO, ARENA_SIZE), player)
    add_child(director)

    status_label = Label.new()
    status_label.position = Vector2(16.0, 14.0)
    status_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
    status_label.add_theme_font_size_override("font_size", 18)
    add_child(status_label)


func _process(_delta: float) -> void:
    if is_instance_valid(director) and director.is_ready:
        status_label.text = "DEMO  %05.1fs   Wave %d   Alive %d   Spawned %d" % [
            director.elapsed_time,
            director.current_wave_index + 1,
            director.get_alive_enemy_count(),
            director.total_spawned,
        ]


func _create_arena() -> void:
    var background := Polygon2D.new()
    background.polygon = PackedVector2Array([
        Vector2.ZERO,
        Vector2(ARENA_SIZE.x, 0.0),
        ARENA_SIZE,
        Vector2(0.0, ARENA_SIZE.y),
    ])
    background.color = Color(0.08, 0.065, 0.11)
    add_child(background)

    var furnace := Polygon2D.new()
    furnace.position = ARENA_SIZE * 0.5
    furnace.polygon = PackedVector2Array([
        Vector2(-34.0, -34.0), Vector2(34.0, -34.0),
        Vector2(34.0, 34.0), Vector2(-34.0, 34.0),
    ])
    furnace.color = Color(0.3, 0.14, 0.12)
    add_child(furnace)
