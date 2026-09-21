extends Node3D

const WAVE_CONFIG_PATH := "res://config/waves_demo.json"
const LOADOUT_CONFIG_PATH := "res://config/player_loadout.json"

const InputSetup := preload("res://src/gameplay/input_setup.gd")
const PlayerPawn := preload("res://src/gameplay/player_pawn.gd")
const WaveDirector := preload("res://src/gameplay/wave_director.gd")
const CameraRig := preload("res://src/gameplay/camera_rig.gd")

enum RunState { RUNNING, WON, LOST }

var player: CharacterBody3D
var director: Node
var camera: Camera3D
var run_state := RunState.RUNNING

var _spell_root: Node
var _projectile_root: Node
var _status_label: Label
var _health_label: Label
var _banner_label: Label


func _ready() -> void:
    InputSetup.ensure_actions()

    var loadout := _load_json(LOADOUT_CONFIG_PATH)

    player = PlayerPawn.new()
    player.configure(loadout.get("player", {}))
    add_child(player)

    director = WaveDirector.new()
    director.configure(WAVE_CONFIG_PATH, player)
    add_child(director)

    player.arena_radius = director.arena_radius
    player.position = Vector3(0.0, player.body_height * 0.5, 0.0)
    player.died.connect(_on_player_died)

    _build_environment()
    _build_arena(director.arena_radius)
    _build_hud()

    camera = CameraRig.new()
    camera.target = player
    add_child(camera)

    _projectile_root = Node3D.new()
    _projectile_root.name = "Projectiles"
    add_child(_projectile_root)

    _spell_root = Node.new()
    _spell_root.name = "Spells"
    add_child(_spell_root)
    _equip_spells(loadout.get("starting_spells", []))


func _process(_delta: float) -> void:
    if not (is_instance_valid(director) and director.is_ready):
        return

    if run_state == RunState.RUNNING and director.elapsed_time >= director.run_duration_seconds:
        _end_run(RunState.WON)

    if is_instance_valid(camera):
        camera.set_density(director.get_crowd_density())

    _status_label.text = "%05.1f / %.0fs   Wave %d   Alive %d   Spawned %d   Killed %d" % [
        director.elapsed_time,
        director.run_duration_seconds,
        director.current_wave_index + 1,
        director.get_alive_enemy_count(),
        director.total_spawned,
        director.total_killed,
    ]
    _health_label.text = "HP  %d / %d" % [roundi(player.health), roundi(player.max_health)]


func _equip_spells(spell_definitions: Array) -> void:
    for index in range(spell_definitions.size()):
        var spell_definition: Dictionary = spell_definitions[index]
        var script_path := str(spell_definition.get("script", ""))
        if script_path.is_empty() or not ResourceLoader.exists(script_path):
            push_error("Spell definition has no loadable script: %s" % spell_definition)
            continue
        var spell_script: GDScript = load(script_path)
        var spell: Node = spell_script.new()
        spell.name = "Spell%d_%s" % [index, str(spell_definition.get("id", "unnamed"))]
        _spell_root.add_child(spell)
        spell.configure(spell_definition, player, _projectile_root, 20260915 + index)


func _on_player_died() -> void:
    _end_run(RunState.LOST)


func _end_run(new_state: RunState) -> void:
    if run_state != RunState.RUNNING:
        return
    run_state = new_state
    director.run_active = false
    director.spawning_enabled = false
    for spell in _spell_root.get_children():
        spell.enabled = false

    if run_state == RunState.WON:
        get_tree().call_group("enemies", "queue_free")
        _banner_label.text = "SURVIVED"
        _banner_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
    else:
        _banner_label.text = "DOWNED"
        _banner_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.42))
    _banner_label.visible = true


func _build_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.035, 0.027, 0.055)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.36, 0.32, 0.48)
    environment.ambient_light_energy = 0.9
    environment.fog_enabled = true
    environment.fog_light_color = Color(0.09, 0.07, 0.13)
    environment.fog_density = 0.012

    var world_environment := WorldEnvironment.new()
    world_environment.environment = environment
    add_child(world_environment)

    var key_light := DirectionalLight3D.new()
    key_light.light_color = Color(1.0, 0.91, 0.78)
    key_light.light_energy = 1.15
    key_light.shadow_enabled = true
    key_light.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
    add_child(key_light)


func _build_arena(arena_radius: float) -> void:
    var floor_mesh := CylinderMesh.new()
    floor_mesh.top_radius = arena_radius
    floor_mesh.bottom_radius = arena_radius
    floor_mesh.height = 0.4
    floor_mesh.radial_segments = 64
    floor_mesh.material = _flat_material(Color(0.13, 0.11, 0.16))

    var floor_instance := MeshInstance3D.new()
    floor_instance.name = "ArenaFloor"
    floor_instance.mesh = floor_mesh
    floor_instance.position = Vector3(0.0, -0.2, 0.0)
    add_child(floor_instance)

    var rim_mesh := TorusMesh.new()
    rim_mesh.inner_radius = arena_radius - 0.25
    rim_mesh.outer_radius = arena_radius + 0.25
    rim_mesh.rings = 64
    rim_mesh.material = _flat_material(Color(0.42, 0.28, 0.2))

    var rim_instance := MeshInstance3D.new()
    rim_instance.name = "ArenaRim"
    rim_instance.mesh = rim_mesh
    add_child(rim_instance)

    var furnace_mesh := BoxMesh.new()
    furnace_mesh.size = Vector3(1.8, 1.4, 1.8)
    furnace_mesh.material = _flat_material(Color(0.3, 0.14, 0.12))

    var furnace_instance := MeshInstance3D.new()
    furnace_instance.name = "Furnace"
    furnace_instance.mesh = furnace_mesh
    # Offset from the centre so it does not sit under the player spawn.
    furnace_instance.position = Vector3(0.0, 0.7, -arena_radius * 0.45)
    add_child(furnace_instance)


func _flat_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    return material


func _build_hud() -> void:
    var hud := CanvasLayer.new()
    hud.name = "HUD"
    add_child(hud)

    _status_label = Label.new()
    _status_label.position = Vector2(18.0, 14.0)
    _status_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
    _status_label.add_theme_font_size_override("font_size", 18)
    hud.add_child(_status_label)

    _health_label = Label.new()
    _health_label.position = Vector2(18.0, 40.0)
    _health_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.82))
    _health_label.add_theme_font_size_override("font_size", 22)
    hud.add_child(_health_label)

    _banner_label = Label.new()
    _banner_label.set_anchors_preset(Control.PRESET_CENTER)
    _banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _banner_label.grow_vertical = Control.GROW_DIRECTION_BOTH
    _banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _banner_label.add_theme_font_size_override("font_size", 56)
    _banner_label.visible = false
    hud.add_child(_banner_label)


func _load_json(config_path: String) -> Dictionary:
    if not FileAccess.file_exists(config_path):
        push_error("Configuration not found: %s" % config_path)
        return {}
    var file := FileAccess.open(config_path, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Configuration must contain a JSON object: %s" % config_path)
        return {}
    return parsed
