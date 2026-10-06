[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-ResPath {
    param([string] $ResPath)
    return Join-Path $repositoryRoot ($ResPath -replace '^res://', '')
}

# --- Wave configurations --------------------------------------------------

$configPaths = @(
    Join-Path $repositoryRoot 'config/waves_demo.json'
    Join-Path $repositoryRoot 'config/waves_10min.json'
)
$requiredEnemyFields = @(
    'speed', 'health', 'radius', 'height',
    'contact_damage', 'attack_interval_seconds', 'experience', 'color'
)

foreach ($configPath in $configPaths) {
    $config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json
    if (-not $config.enemy_types.PSObject.Properties) {
        throw "$configPath has no enemy types."
    }
    if (-not $config.waves -or $config.waves.Count -lt 2) {
        throw "$configPath must define at least two waves."
    }
    if ($config.arena_radius -le 0) {
        throw "$configPath must define a positive arena_radius."
    }
    if ($config.run_duration_seconds -le 0) {
        throw "$configPath must define a positive run_duration_seconds."
    }
    if ($config.spawn_ring_radius -le 0) {
        throw "$configPath must define a positive spawn_ring_radius."
    }
    if ($config.minimum_player_distance -le 0) {
        throw "$configPath must define a positive minimum_player_distance."
    }
    if ($config.spawn_ring_radius -lt $config.minimum_player_distance) {
        throw "$configPath spawns enemies closer than minimum_player_distance allows."
    }
    # The ring is anchored to the player, so a ring wider than the arena means
    # every angle lands outside it and spawns fall back to the arena edge.
    if ($config.spawn_ring_radius -gt $config.arena_radius) {
        throw "$configPath spawn_ring_radius is wider than the arena, so the spawn ring can never fit."
    }
    # Culling closer than the spawn ring would delete enemies the moment they
    # appear, so the arena would never fill.
    if ($config.despawn_radius -le $config.spawn_ring_radius) {
        throw "$configPath despawn_radius must be larger than spawn_ring_radius."
    }

    foreach ($enemyProperty in $config.enemy_types.PSObject.Properties) {
        $enemy = $enemyProperty.Value
        foreach ($field in $requiredEnemyFields) {
            if (-not $enemy.PSObject.Properties[$field]) {
                throw "$configPath enemy type '$($enemyProperty.Name)' is missing '$field'."
            }
        }
        if ($enemy.speed -le 0 -or $enemy.health -le 0 -or $enemy.radius -le 0) {
            throw "$configPath enemy type '$($enemyProperty.Name)' has a non-positive speed, health, or radius."
        }
        if ($enemy.height -lt $enemy.radius * 2) {
            throw "$configPath enemy type '$($enemyProperty.Name)' has a capsule height smaller than its two hemispheres."
        }
        if ($enemy.contact_damage -lt 0 -or $enemy.attack_interval_seconds -le 0) {
            throw "$configPath enemy type '$($enemyProperty.Name)' has an invalid contact attack."
        }
        if ($enemy.experience -lt 0) {
            throw "$configPath enemy type '$($enemyProperty.Name)' has negative experience."
        }
    }

    $previousStart = -1
    $lastWaveStart = 0
    foreach ($wave in $config.waves) {
        if ($wave.start_time_seconds -le $previousStart) {
            throw "$configPath wave start times must be strictly increasing."
        }
        if ($wave.spawn_interval_seconds -le 0 -or $wave.batch_size -lt 1 -or $wave.max_alive -lt 1) {
            throw "$configPath contains a non-positive spawn setting."
        }
        if ($wave.health_multiplier -le 0) {
            throw "$configPath contains a non-positive health_multiplier."
        }
        $weightTotal = 0.0
        foreach ($weightProperty in $wave.type_weights.PSObject.Properties) {
            if (-not $config.enemy_types.PSObject.Properties[$weightProperty.Name]) {
                throw "$configPath references unknown enemy type '$($weightProperty.Name)'."
            }
            if ($weightProperty.Value -lt 0) {
                throw "$configPath contains a negative type weight."
            }
            $weightTotal += $weightProperty.Value
        }
        if ($weightTotal -le 0) {
            throw "$configPath contains a wave without a positive type weight."
        }
        $previousStart = $wave.start_time_seconds
        $lastWaveStart = $wave.start_time_seconds
    }
    if ($lastWaveStart -ge $config.run_duration_seconds) {
        throw "$configPath has a wave that starts at or after the run ends."
    }
    Write-Output "Validated $configPath"
}

# --- Spell catalog --------------------------------------------------------

$spellPath = Join-Path $repositoryRoot 'config/spells.json'
$spellConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $spellPath | ConvertFrom-Json
if (-not $spellConfig.spells -or $spellConfig.spells.Count -lt 1) {
    throw "$spellPath must define at least one spell."
}
$spellIds = @{}
foreach ($spell in $spellConfig.spells) {
    if (-not $spell.id) {
        throw "$spellPath has a spell without an id."
    }
    if ($spellIds.ContainsKey($spell.id)) {
        throw "$spellPath defines the spell id '$($spell.id)' twice."
    }
    $spellIds[$spell.id] = $true
    if (-not (Test-Path -LiteralPath (Resolve-ResPath $spell.script))) {
        throw "$spellPath spell '$($spell.id)' names a missing script: $($spell.script)"
    }
    if ($spell.max_level -lt 1) {
        throw "$spellPath spell '$($spell.id)' has a max_level below one."
    }
    if ($spell.base.damage -le 0 -or $spell.base.cooldown_seconds -le 0) {
        throw "$spellPath spell '$($spell.id)' has a non-positive damage or cooldown."
    }
    # A per-level cooldown reduction that outruns max_level would make the
    # spell cast on a zero or negative cooldown at full rank.
    if ($spell.per_level.PSObject.Properties['cooldown_seconds']) {
        $finalCooldown = $spell.base.cooldown_seconds + $spell.per_level.cooldown_seconds * ($spell.max_level - 1)
        if ($finalCooldown -le 0) {
            throw "$spellPath spell '$($spell.id)' reaches a non-positive cooldown at max level."
        }
    }
    if ($spell.base.PSObject.Properties['projectile_speed'] -and $spell.base.PSObject.Properties['lifetime_seconds'] -and $spell.base.PSObject.Properties['range']) {
        if ($spell.base.projectile_speed * $spell.base.lifetime_seconds -lt $spell.base.range) {
            throw "$spellPath spell '$($spell.id)' expires before a projectile can cross its own cast range."
        }
    }
}
Write-Output "Validated $spellPath"

$validElements = @('fire', 'lightning', 'frost')
$validStatuses = @('burn', 'shock', 'chill')
$spellElements = @{}
foreach ($spell in $spellConfig.spells) {
    if (-not $spell.element -or $validElements -notcontains $spell.element) {
        throw "$spellPath spell '$($spell.id)' needs an element from: $($validElements -join ', ')."
    }
    $spellElements[$spell.id] = $spell.element
    if (-not $spell.status -or $validStatuses -notcontains $spell.status.id) {
        throw "$spellPath spell '$($spell.id)' needs a status from: $($validStatuses -join ', ')."
    }
    if ($spell.status.duration -le 0 -or $spell.status.potency -le 0) {
        throw "$spellPath spell '$($spell.id)' has a non-positive status duration or potency."
    }
}

# --- Reactions ------------------------------------------------------------

$reactionPath = Join-Path $repositoryRoot 'config/reactions.json'
$reactionConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $reactionPath | ConvertFrom-Json
if ($reactionConfig.max_chain_depth -lt 1 -or $reactionConfig.lockout_seconds -le 0) {
    throw "$reactionPath needs a positive max_chain_depth and lockout_seconds."
}
$reactionIds = @{}
$reactionPairs = @{}
foreach ($reaction in $reactionConfig.reactions) {
    if ($reactionIds.ContainsKey($reaction.id)) {
        throw "$reactionPath defines the reaction id '$($reaction.id)' twice."
    }
    $reactionIds[$reaction.id] = $true
    if ($reaction.requires.Count -lt 2) {
        throw "$reactionPath reaction '$($reaction.id)' needs at least two statuses; one would fire on every hit."
    }
    foreach ($status in $reaction.requires) {
        if ($validStatuses -notcontains $status) {
            throw "$reactionPath reaction '$($reaction.id)' requires unknown status '$status'."
        }
    }
    $pairKey = ($reaction.requires | Sort-Object) -join '+'
    if ($reactionPairs.ContainsKey($pairKey)) {
        throw "$reactionPath reactions '$($reactionPairs[$pairKey])' and '$($reaction.id)' both consume $pairKey."
    }
    $reactionPairs[$pairKey] = $reaction.id
    if ($reaction.damage -le 0 -or $reaction.radius -lt 0) {
        throw "$reactionPath reaction '$($reaction.id)' has a non-positive damage or negative radius."
    }
    if ($reaction.apply -and $validStatuses -notcontains $reaction.apply.id) {
        throw "$reactionPath reaction '$($reaction.id)' applies unknown status '$($reaction.apply.id)'."
    }
}
# Statuses a spell can apply should each take part in at least one reaction, or
# the spell contributes nothing to a build beyond its own damage.
foreach ($status in $validStatuses) {
    $used = $false
    foreach ($reaction in $reactionConfig.reactions) {
        if ($reaction.requires -contains $status) { $used = $true }
    }
    if (-not $used) {
        throw "$reactionPath has no reaction that uses the '$status' status."
    }
}
Write-Output "Validated $reactionPath"

# --- Augments -------------------------------------------------------------

$augmentPath = Join-Path $repositoryRoot 'config/augments.json'
$augmentConfig = Get-Content -Raw -Encoding UTF8 -LiteralPath $augmentPath | ConvertFrom-Json
$augmentIds = @{}
foreach ($augment in $augmentConfig.augments) {
    if ($augmentIds.ContainsKey($augment.id)) {
        throw "$augmentPath defines the augment id '$($augment.id)' twice."
    }
    $augmentIds[$augment.id] = $true
    if (-not $augment.name -or -not $augment.description) {
        throw "$augmentPath augment '$($augment.id)' needs a name and a description."
    }
    $requirementCount = 0
    foreach ($key in @('spell', 'element', 'distinct_elements')) {
        if ($augment.requires.PSObject.Properties[$key]) { $requirementCount++ }
    }
    if ($requirementCount -ne 1) {
        throw "$augmentPath augment '$($augment.id)' must have exactly one requirement (spell, element or distinct_elements)."
    }
    if ($augment.requires.spell -and -not $spellIds.ContainsKey($augment.requires.spell)) {
        throw "$augmentPath augment '$($augment.id)' requires unknown spell '$($augment.requires.spell)'."
    }
    if ($augment.requires.element -and $validElements -notcontains $augment.requires.element) {
        throw "$augmentPath augment '$($augment.id)' requires unknown element '$($augment.requires.element)'."
    }
    if ($augment.requires.element -and ($spellElements.Values -notcontains $augment.requires.element)) {
        throw "$augmentPath augment '$($augment.id)' requires element '$($augment.requires.element)', which no spell has."
    }
}
Write-Output "Validated $augmentPath"

# --- Progression ----------------------------------------------------------

$progressionPath = Join-Path $repositoryRoot 'config/progression.json'
$progression = Get-Content -Raw -Encoding UTF8 -LiteralPath $progressionPath | ConvertFrom-Json
if ($progression.xp_curve.base -le 0 -or $progression.xp_curve.growth -le 0) {
    throw "$progressionPath needs a positive experience curve."
}
if ($progression.draft.options -lt 1) {
    throw "$progressionPath must offer at least one draft option."
}
if (-not $progression.upgrades -or $progression.upgrades.Count -lt 1) {
    throw "$progressionPath must define at least one stat upgrade."
}

$knownFields = @(
    'damage_multiplier', 'cooldown_multiplier', 'area_multiplier',
    'projectile_speed_multiplier', 'projectile_count_bonus',
    'move_speed_multiplier', 'max_health_bonus', 'pickup_radius_bonus',
    'health_regen_per_second',
    'xp_multiplier'
)
$upgradeIds = @{}
foreach ($upgrade in $progression.upgrades) {
    if ($upgradeIds.ContainsKey($upgrade.id)) {
        throw "$progressionPath defines the upgrade id '$($upgrade.id)' twice."
    }
    $upgradeIds[$upgrade.id] = $true
    if ($knownFields -notcontains $upgrade.field) {
        throw "$progressionPath upgrade '$($upgrade.id)' targets unknown stat '$($upgrade.field)'."
    }
    if ($upgrade.max_stacks -lt 1) {
        throw "$progressionPath upgrade '$($upgrade.id)' has no stacks."
    }
    if ($upgrade.amount -eq 0) {
        throw "$progressionPath upgrade '$($upgrade.id)' does nothing."
    }
    # A multiplier that can be driven to zero or below would disable every
    # spell at once; the runtime clamps it, which would silently waste a pick.
    if ($upgrade.field -like '*_multiplier' -and $upgrade.amount -lt 0) {
        $floor = 1.0 + $upgrade.amount * $upgrade.max_stacks
        if ($floor -le 0.1) {
            throw "$progressionPath upgrade '$($upgrade.id)' can push $($upgrade.field) to the clamp floor."
        }
    }
}
Write-Output "Validated $progressionPath"

# --- Loadout --------------------------------------------------------------

$loadoutPath = Join-Path $repositoryRoot 'config/player_loadout.json'
$loadout = Get-Content -Raw -Encoding UTF8 -LiteralPath $loadoutPath | ConvertFrom-Json
if ($loadout.player.max_health -le 0 -or $loadout.player.move_speed -le 0 -or $loadout.player.radius -le 0) {
    throw "$loadoutPath has a non-positive player stat."
}
if ($loadout.player.height -lt $loadout.player.radius * 2) {
    throw "$loadoutPath player capsule height is smaller than its two hemispheres."
}
if ($loadout.player.pickup_radius -le 0) {
    throw "$loadoutPath needs a positive pickup_radius."
}
if (-not $loadout.starting_spells -or $loadout.starting_spells.Count -lt 1) {
    throw "$loadoutPath must define at least one starting spell."
}
foreach ($startingSpell in $loadout.starting_spells) {
    if (-not $spellIds.ContainsKey($startingSpell)) {
        throw "$loadoutPath starts with '$startingSpell', which is not in the spell catalog."
    }
}
if ($loadout.starting_spells.Count -gt $spellConfig.max_spells) {
    throw "$loadoutPath starts with more spells than max_spells allows."
}
Write-Output "Validated $loadoutPath"

# --- Project files --------------------------------------------------------

$requiredFiles = @(
    'project.godot'
    'src/main.tscn'
    'src/main.gd'
    'src/gameplay/player_pawn.gd'
    'src/gameplay/player_stats.gd'
    'src/gameplay/progression.gd'
    'src/gameplay/draft.gd'
    'src/gameplay/reactions.gd'
    'src/gameplay/reaction_popup.gd'
    'config/reactions.json'
    'config/augments.json'
    'tests/run_headless_build_test.gd'
    'src/gameplay/xp_orb.gd'
    'src/gameplay/enemy.gd'
    'src/gameplay/wave_director.gd'
    'src/gameplay/camera_rig.gd'
    'src/gameplay/game_layers.gd'
    'src/gameplay/input_setup.gd'
    'src/gameplay/spells/spell.gd'
    'src/gameplay/spells/projectile.gd'
    'src/gameplay/spells/spell.gd'
    'src/ui/hud.gd'
    'src/ui/draft_screen.gd'
    'src/ui/overlay_screen.gd'
    'src/ui/ui_theme.gd'
    'tests/run_headless_smoke.gd'
    'tests/run_headless_playthrough.gd'
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $requiredFile))) {
        throw "Missing required project file: $requiredFile"
    }
}

$projectText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repositoryRoot 'project.godot')
if ($projectText -notmatch 'renderer/rendering_method="forward_plus"') {
    throw 'project.godot must select the forward_plus renderer.'
}

Write-Output 'Static validation passed.'
