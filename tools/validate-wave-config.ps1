[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPaths = @(
    Join-Path $repositoryRoot 'config/waves_demo.json'
    Join-Path $repositoryRoot 'config/waves_10min.json'
)

$requiredEnemyFields = @('speed', 'health', 'radius', 'height', 'contact_damage', 'attack_interval_seconds', 'color')

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
    if ($config.spawn_margin -le 0) {
        throw "$configPath must define a positive spawn_margin."
    }
    if ($config.minimum_player_distance -le 0 -or $config.minimum_player_distance -ge $config.arena_radius * 2) {
        throw "$configPath minimum_player_distance must be positive and smaller than the arena diameter, or spawning cannot satisfy it."
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

$loadoutPath = Join-Path $repositoryRoot 'config/player_loadout.json'
$loadout = Get-Content -Raw -Encoding UTF8 -LiteralPath $loadoutPath | ConvertFrom-Json
if ($loadout.player.max_health -le 0 -or $loadout.player.move_speed -le 0 -or $loadout.player.radius -le 0) {
    throw "$loadoutPath has a non-positive player stat."
}
if ($loadout.player.height -lt $loadout.player.radius * 2) {
    throw "$loadoutPath player capsule height is smaller than its two hemispheres."
}
if (-not $loadout.starting_spells -or $loadout.starting_spells.Count -lt 1) {
    throw "$loadoutPath must define at least one starting spell."
}
foreach ($spell in $loadout.starting_spells) {
    if (-not $spell.script) {
        throw "$loadoutPath has a spell without a script path."
    }
    $spellScript = Join-Path $repositoryRoot ($spell.script -replace '^res://', '')
    if (-not (Test-Path -LiteralPath $spellScript)) {
        throw "$loadoutPath references a missing spell script: $($spell.script)"
    }
    if ($spell.cooldown_seconds -le 0 -or $spell.range -le 0 -or $spell.damage -le 0) {
        throw "$loadoutPath spell '$($spell.id)' has a non-positive cooldown, range, or damage."
    }
    if ($spell.projectile_speed -le 0 -or $spell.lifetime_seconds -le 0) {
        throw "$loadoutPath spell '$($spell.id)' has a non-positive projectile speed or lifetime."
    }
    if ($spell.projectile_speed * $spell.lifetime_seconds -lt $spell.range) {
        throw "$loadoutPath spell '$($spell.id)' expires before a projectile can cross its own cast range."
    }
}
Write-Output "Validated $loadoutPath"

$requiredFiles = @(
    'project.godot'
    'src/main.tscn'
    'src/main.gd'
    'src/gameplay/player_pawn.gd'
    'src/gameplay/enemy.gd'
    'src/gameplay/wave_director.gd'
    'src/gameplay/camera_rig.gd'
    'src/gameplay/game_layers.gd'
    'src/gameplay/input_setup.gd'
    'src/gameplay/spells/projectile.gd'
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $requiredFile))) {
        throw "Missing required project file: $requiredFile"
    }
}

$projectText = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $repositoryRoot 'project.godot')
if ($projectText -notmatch 'renderer/rendering_method="forward_plus"') {
    throw 'project.godot must select the forward_plus renderer for the 2.5D slice.'
}

Write-Output 'Run prototype static validation passed.'
