# Publish WORDERS Windows build to GitHub Releases.
# Requires: gh CLI authenticated (`gh auth login`)
# Usage: .\scripts\publish_release.ps1 [-Tag v0.1.0]

param(
    [string]$Tag = "v0.1.0"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$Exe = Join-Path $Root "worders.exe"
$Pck = Join-Path $Root "worders.pck"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found. Install: winget install GitHub.cli"
}

gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Not logged in to GitHub. Run: gh auth login"
}

if (-not (Test-Path $Exe)) {
    throw "Missing worders.exe in project root. Export from Godot first."
}
if (-not (Test-Path $Pck)) {
    throw "Missing worders.pck in project root. Export from Godot first."
}

$Notes = "## WORDERS $Tag`n`nWindows build (Godot 4.6.3).`n`n1. Download worders.exe and worders.pck`n2. Place both in the same folder`n3. Run worders.exe"

Write-Host "Creating release $Tag ..."
gh release create $Tag `
    --repo "MUSH2077/worders" `
    --title "WORDERS $Tag" `
    --notes $Notes `
    "$Exe" "$Pck"

Write-Host "Done: https://github.com/MUSH2077/worders/releases/tag/$Tag"
