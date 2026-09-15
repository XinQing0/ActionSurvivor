[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPaths = @(
    Join-Path $repositoryRoot 'config/waves_demo.json'
    Join-Path $repositoryRoot 'config/waves_10min.json'
)

foreach ($configPath in $configPaths) {
    $config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json
    if (-not $config.enemy_types.PSObject.Properties) {
        throw "$configPath has no enemy types."
    }
    if (-not $config.waves -or $config.waves.Count -lt 2) {
        throw "$configPath must define at least two waves."
    }

    $previousStart = -1
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
    }
    Write-Output "Validated $configPath"
}

$projectFile = Join-Path $repositoryRoot 'project.godot'
$mainScene = Join-Path $repositoryRoot 'src/main.tscn'
if (-not (Test-Path -LiteralPath $projectFile) -or -not (Test-Path -LiteralPath $mainScene)) {
    throw 'Godot project entry files are missing.'
}

Write-Output 'Wave prototype static validation passed.'
