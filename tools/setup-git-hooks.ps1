[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repositoryRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repositoryRoot)) {
    throw 'Run this script from inside the ActionSurvivor Git repository.'
}

git -C $repositoryRoot config --local core.hooksPath .githooks
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to configure core.hooksPath.'
}

$configuredPath = git -C $repositoryRoot config --local --get core.hooksPath
if ($configuredPath -ne '.githooks') {
    throw "Unexpected hooks path: $configuredPath"
}

Write-Host 'Git hooks installed for this clone.'
Write-Host 'Commits are allowed only on feature/* branches.'
Write-Host 'Direct pushes to remote main are blocked.'

