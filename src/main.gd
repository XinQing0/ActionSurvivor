extends Node3D

## Run orchestration: builds the arena, owns run state, and wires the systems
## together. Gameplay rules live in `src/gameplay/`; this file only decides when
## a run starts, pauses for a level-up, and ends.

const LOADOUT_CONFIG_PATH := "res://config/player_loadout.json"
const SPELL_CONFIG_PATH := "res://config/spells.json"
const PROGRESSION_CONFIG_PATH := "res://config/progression.json"
const AUGMENT_CONFIG_PATH := "res://config/augments.json"
const REACTION_CONFIG_PATH := "res://config/reactions.json"

const DEMO_WAVES_PATH := "res://config/waves_demo.json"
const FULL_WAVES_PATH := "res://config/waves_10min.json"

const InputSetup := preload("res://src/gameplay/input_setup.gd")
const PlayerPawn := preload("res://src/gameplay/player_pawn.gd")
const WaveDirector := preload("res://src/gameplay/wave_director.gd")
const CameraRig := preload("res://src/gameplay/camera_rig.gd")
const PlayerStats := preload("res://src/gameplay/player_stats.gd")
const Progression := preload("res://src/gameplay/progression.gd")
const Draft := preload("res://src/gameplay/draft.gd")
const XpOrb := preload("res://src/gameplay/xp_orb.gd")
const Reactions := preload("res://src/gameplay/reactions.gd")
const Hud := preload("res://src/ui/hud.gd")
const DraftScreen := preload("res://src/ui/draft_screen.gd")
const OverlayScreen := preload("res://src/ui/overlay_screen.gd")
const UiTheme := preload("res://src/ui/ui_theme.gd")

enum RunState { TITLE, RUNNING, DRAFTING, WON, LOST }

## Survives `reload_current_scene`, which is how restarting keeps the mode the
## player picked on the title screen.
static var selected_waves_path := DEMO_WAVES_PATH
static var skip_title := false

var player: CharacterBody3D
var director: Node
var camera: Camera3D
var run_state := RunState.TITLE
var stats: RefCounted
var progression: RefCounted
var reactions: Node

var _draft: RefCounted
var _spell_root: Node
var _projectile_root: Node
var _orb_root: Node
var _hud: CanvasLayer
var _draft_screen: CanvasLayer
var _overlay: CanvasLayer
var _owned_spells := {}
var _taken_upgrades := {}
var _taken_augments := {}
var _orb_settings := {}
var _run_seed := 20260915


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    InputSetup.ensure_actions()

    var loadout := _load_json(LOADOUT_CONFIG_PATH)
    var spell_config := _load_json(SPELL_CONFIG_PATH)
    var progression_config := _load_json(PROGRESSION_CONFIG_PATH)
    _orb_settings = progression_config.get("orb", {})

    stats = PlayerStats.new()
    progression = Progression.new()
    progression.configure(progression_config.get("xp_curve", {}))
    _draft = Draft.new()
    _draft.configure(spell_config, progression_config, _run_seed, _load_json(AUGMENT_CONFIG_PATH))

    reactions = Reactions.new()
    reactions.name = "Reactions"
    reactions.configure(_load_json(REACTION_CONFIG_PATH), stats, self)
    add_child(reactions)

    player = PlayerPawn.new()
    player.stats = stats
    player.configure(loadout.get("player", {}))
    add_child(player)

    director = WaveDirector.new()
    director.reactions = reactions
    director.configure(selected_waves_path, player)
    add_child(director)
    director.enemy_died.connect(_on_enemy_died)

    player.arena_radius = director.arena_radius
    player.position = Vector3(0.0, player.body_height * 0.5, 0.0)
    player.died.connect(_on_player_died)
    player.health_changed.connect(_on_player_health_changed)

    _build_environment()
    _build_arena(director.arena_radius)

    camera = CameraRig.new()
    camera.target = player
    add_child(camera)

    _projectile_root = Node3D.new()
    _projectile_root.name = "Projectiles"
    add_child(_projectile_root)

    _orb_root = Node3D.new()
    _orb_root.name = "Orbs"
    add_child(_orb_root)

    _spell_root = Node.new()
    _spell_root.name = "Spells"
    add_child(_spell_root)

    _hud = Hud.new()
    _hud.name = "Hud"
    add_child(_hud)

    _draft_screen = DraftScreen.new()
    _draft_screen.name = "DraftScreen"
    _draft_screen.option_chosen.connect(_on_draft_option_chosen)
    add_child(_draft_screen)

    _overlay = OverlayScreen.new()
    _overlay.name = "Overlay"
    _overlay.action_selected.connect(_on_overlay_action)
    add_child(_overlay)

    for spell_id in loadout.get("starting_spells", []):
        _grant_spell(str(spell_id))

    if skip_title:
        _start_run()
    else:
        _show_title()


func _process(_delta: float) -> void:
    if run_state == RunState.RUNNING:
        if director.elapsed_time >= director.run_duration_seconds:
            _end_run(RunState.WON)
        elif progression.pending_levels > 0:
            _open_draft()

    if is_instance_valid(camera):
        camera.set_density(director.get_crowd_density())
    _refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_pressed():
        return
    var key_event := event as InputEventKey
    if key_event == null or key_event.echo:
        return
    if key_event.keycode == KEY_ESCAPE and run_state == RunState.RUNNING:
        get_viewport().set_input_as_handled()
        _end_run(RunState.LOST)


# --- Run lifecycle --------------------------------------------------------

func _show_title() -> void:
    run_state = RunState.TITLE
    get_tree().paused = true
    _hud.visible = false
    _overlay.present(
        "ACTION SURVIVOR",
        "An abandoned alchemy workshop. Your spells cast themselves.",
        [
            "Move with WASD or the arrow keys. That is the only control.",
            "Choose an upgrade every level. Escape abandons a run.",
        ],
        [
            {"id": "demo", "label": "Quick run  -  90 seconds"},
            {"id": "full", "label": "Full run  -  10 minutes"},
        ]
    )


func _start_run() -> void:
    run_state = RunState.RUNNING
    get_tree().paused = false
    _hud.visible = true
    _overlay.hide_screen()


func _restart(waves_path: String) -> void:
    selected_waves_path = waves_path
    skip_title = true
    get_tree().paused = false
    get_tree().reload_current_scene()


func _on_player_died() -> void:
    _end_run(RunState.LOST)


func _end_run(new_state: RunState) -> void:
    if run_state != RunState.RUNNING and run_state != RunState.DRAFTING:
        return
    run_state = new_state
    director.run_active = false
    director.spawning_enabled = false
    for spell in _spell_root.get_children():
        spell.enabled = false
    _draft_screen.hide_screen()

    var survived := new_state == RunState.WON
    if survived:
        # Clearing the arena is what makes surviving read as a win rather than
        # a freeze-frame. Leave the group explicitly: `queue_free` does not
        # take a node out of its groups until the end of the frame, so the
        # alive count on the result screen would otherwise be stale.
        for enemy in get_tree().get_nodes_in_group("enemies"):
            enemy.remove_from_group("enemies")
            enemy.queue_free()
    var minutes := int(director.elapsed_time) / 60
    var seconds := int(director.elapsed_time) % 60
    _overlay.present(
        "SURVIVED" if survived else "DOWNED",
        "",
        [
            "Lasted %d:%02d of %d:%02d" % [
                minutes, seconds,
                int(director.run_duration_seconds) / 60,
                int(director.run_duration_seconds) % 60,
            ],
            "Reached level %d" % progression.level,
            "Slew %d of %d" % [director.total_killed, director.total_spawned],
            _describe_build(),
        ],
        [
            {"id": "again", "label": "Run it again"},
            {"id": "title", "label": "Back to the title"},
        ],
        UiTheme.EXPERIENCE if survived else UiTheme.HEALTH
    )
    get_tree().paused = true


func _on_overlay_action(action_id: String) -> void:
    match action_id:
        "demo":
            _restart(DEMO_WAVES_PATH)
        "full":
            _restart(FULL_WAVES_PATH)
        "again":
            _restart(selected_waves_path)
        "title":
            skip_title = false
            get_tree().paused = false
            get_tree().reload_current_scene()


# --- Progression ----------------------------------------------------------

func _on_enemy_died(position: Vector3, experience: int) -> void:
    if experience <= 0:
        return
    var orb := XpOrb.new()
    orb.configure(
        experience,
        player,
        float(_orb_settings.get("radius", 0.22)),
        Color.from_string(str(_orb_settings.get("color", "7de8b0")), UiTheme.EXPERIENCE),
        float(_orb_settings.get("magnet_speed", 14.0))
    )
    orb.position = Vector3(position.x, 0.35, position.z)
    orb.collected.connect(_on_orb_collected)
    _orb_root.add_child(orb)


func _on_orb_collected(value: int) -> void:
    progression.add_experience(maxi(int(round(float(value) * stats.xp_multiplier)), 1))


func _on_player_health_changed(_current: float, _maximum: float) -> void:
    _refresh_hud()


## Returns whether a choice screen actually opened. Every caller must resume
## the run when it did not, or the tree stays paused with no way out.
func _open_draft() -> bool:
    if not progression.consume_pending_level():
        return false
    var options: Array[Dictionary] = _draft.build_options(_owned_spells, _taken_upgrades, _taken_augments)
    if options.is_empty():
        # Everything is maxed out. Nothing to offer, so do not stop the run.
        return false
    run_state = RunState.DRAFTING
    get_tree().paused = true
    _draft_screen.present(options, progression.level)
    return true


func _on_draft_option_chosen(option: Dictionary) -> void:
    match str(option.get("kind", "")):
        Draft.KIND_NEW_SPELL:
            _grant_spell(str(option.get("id", "")))
        Draft.KIND_SPELL_LEVEL:
            _level_up_spell(str(option.get("id", "")))
        Draft.KIND_STAT:
            _apply_upgrade(str(option.get("id", "")))
        Draft.KIND_AUGMENT:
            _grant_augment(str(option.get("id", "")))

    # More than one level can be earned from a single orb pickup.
    if progression.pending_levels > 0 and _open_draft():
        return
    run_state = RunState.RUNNING
    get_tree().paused = false
    _refresh_hud()


func _grant_spell(spell_id: String) -> void:
    if spell_id.is_empty() or _owned_spells.has(spell_id):
        return
    var definition: Dictionary = _draft.get_spell_definition(spell_id)
    if definition.is_empty():
        push_error("Unknown spell id: %s" % spell_id)
        return
    var script_path := str(definition.get("script", ""))
    if not ResourceLoader.exists(script_path):
        push_error("Spell '%s' names a missing script: %s" % [spell_id, script_path])
        return

    var spell: Node = (load(script_path) as GDScript).new()
    spell.name = "Spell_%s" % spell_id
    _spell_root.add_child(spell)
    spell.configure(definition, player, _projectile_root, stats, _run_seed + _owned_spells.size() * 31)
    _owned_spells[spell_id] = 1


func _level_up_spell(spell_id: String) -> void:
    var spell := _spell_root.get_node_or_null("Spell_%s" % spell_id)
    if spell == null:
        return
    spell.level_up()
    _owned_spells[spell_id] = spell.level


func _apply_upgrade(upgrade_id: String) -> void:
    var upgrade: Dictionary = _draft.get_upgrade_definition(upgrade_id)
    if upgrade.is_empty():
        return
    var field := str(upgrade.get("field", ""))
    var amount := float(upgrade.get("amount", 0.0))
    if not stats.apply_modifier(field, amount):
        return
    _taken_upgrades[upgrade_id] = int(_taken_upgrades.get(upgrade_id, 0)) + 1
    if field == "max_health_bonus":
        player.refresh_max_health(amount)


func _grant_augment(augment_id: String) -> void:
    var augment: Dictionary = _draft.get_augment_definition(augment_id)
    if augment.is_empty() or _taken_augments.has(augment_id):
        return
    stats.grant_augment(augment_id, augment.get("params", {}))
    _taken_augments[augment_id] = true


func _describe_build() -> String:
    if _owned_spells.is_empty():
        return ""
    var parts: Array[String] = []
    for spell_id in _owned_spells:
        var definition: Dictionary = _draft.get_spell_definition(spell_id)
        parts.append("%s %d" % [str(definition.get("name", spell_id)), int(_owned_spells[spell_id])])
    for augment_id in _taken_augments:
        parts.append(str(_draft.get_augment_definition(augment_id).get("name", augment_id)))
    return " / ".join(parts)


# --- Presentation ---------------------------------------------------------

func _refresh_hud() -> void:
    if _hud == null or not _hud.visible:
        return
    _hud.update_run(
        director.elapsed_time,
        director.run_duration_seconds,
        director.current_wave_index + 1,
        director.get_alive_enemy_count(),
        director.total_killed
    )
    _hud.update_level(progression.level, progression.progress_to_next_level())
    _hud.update_health(player.health, player.get_max_health())
    _hud.update_spells(_spell_summary())


func _spell_summary() -> Array:
    var summary: Array = []
    for spell in _spell_root.get_children():
        summary.append({
            "name": spell.display_name,
            "level": spell.level,
            "max_level": spell.max_level,
        })
    for augment_id in _taken_augments:
        summary.append({
            "name": str(_draft.get_augment_definition(augment_id).get("name", augment_id)),
            "augment": true,
        })
    return summary


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
    environment.glow_enabled = true
    environment.glow_intensity = 0.5
    environment.glow_bloom = 0.15

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
