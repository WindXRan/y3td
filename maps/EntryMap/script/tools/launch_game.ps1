$ErrorActionPreference = "Stop"

function Resolve-GameExeFromEditorPath {
    param(
        [string]$EditorPath
    )

    if (-not $EditorPath) {
        return $null
    }

    $gameDir = Split-Path -Parent $EditorPath
    $candidate = Join-Path $gameDir "Engine\Binaries\Win64\Game_x64h.exe"
    if (Test-Path $candidate) {
        return $candidate
    }

    return $null
}

function Resolve-GameExeFromLaunchBat {
    param(
        [string]$ToolsDir
    )

    $batPath = Join-Path $ToolsDir "launch_game.bat"
    if (-not (Test-Path $batPath)) {
        return $null
    }

    $content = Get-Content $batPath -Raw
    $match = [regex]::Match(
        $content,
        'cd\s+/d\s+"([^"]+)"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $match.Success) {
        return $null
    }

    $gameDir = $match.Groups[1].Value.Trim()
    if (-not $gameDir) {
        return $null
    }

    $candidate = Join-Path $gameDir "Game_x64h.exe"
    if (Test-Path $candidate) {
        return $candidate
    }

    return $null
}

function Resolve-GameExe {
    param(
        [string]$ScriptPath,
        [string]$ToolsDir
    )

    $vscodeSettings = Join-Path $ScriptPath ".vscode\settings.json"
    if (Test-Path $vscodeSettings) {
        try {
            $settings = Get-Content $vscodeSettings -Raw | ConvertFrom-Json
            $editorPath = $settings.'Y3-Helper.EditorPath'
            $candidate = Resolve-GameExeFromEditorPath -EditorPath $editorPath
            if ($candidate) {
                return @{
                    GameExe = $candidate
                    Source = ".vscode/settings.json"
                }
            }
        } catch {
        }
    }

    $candidate = Resolve-GameExeFromEditorPath -EditorPath $env:Y3_EDITOR_PATH
    if ($candidate) {
        return @{
            GameExe = $candidate
            Source = "env:Y3_EDITOR_PATH"
        }
    }

    if ($env:Y3_GAME_EXE -and (Test-Path $env:Y3_GAME_EXE)) {
        return @{
            GameExe = $env:Y3_GAME_EXE
            Source = "env:Y3_GAME_EXE"
        }
    }

    $candidate = Resolve-GameExeFromLaunchBat -ToolsDir $ToolsDir
    if ($candidate) {
        return @{
            GameExe = $candidate
            Source = "launch_game.bat"
        }
    }

    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles "y3\games\2.0\game\Engine\Binaries\Win64\Game_x64h.exe")
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "y3\games\2.0\game\Engine\Binaries\Win64\Game_x64h.exe")
    }
    $candidates += "C:\Program Files\y3\games\2.0\game\Engine\Binaries\Win64\Game_x64h.exe"

    foreach ($path in $candidates | Select-Object -Unique) {
        if ($path -and (Test-Path $path)) {
            return @{
                GameExe = $path
                Source = "common_path"
            }
        }
    }

    return $null
}

function Read-LevelIdFromHeaderProject {
    param(
        [string]$HeaderFile
    )

    if (-not (Test-Path $HeaderFile)) {
        return $null
    }

    $content = Get-Content $HeaderFile -Raw
    $match = [regex]::Match(
        $content,
        '"entry_map"\s*:\s*\{.*?"id"\s*:\s*(?:"(?<quoted>[^"]*)"|(?<raw>\d+))',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if (-not $match.Success) {
        return $null
    }

    if ($match.Groups['quoted'].Success) {
        return $match.Groups['quoted'].Value
    }

    if ($match.Groups['raw'].Success) {
        return $match.Groups['raw'].Value
    }

    return $null
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsDir = $scriptDir
$scriptPath = Split-Path -Parent $toolsDir

if (-not (Test-Path (Join-Path $scriptPath "main.lua"))) {
    Write-Host "[ERROR] Cannot find script directory (no main.lua found)"
    exit 1
}

$gameResolution = Resolve-GameExe -ScriptPath $scriptPath -ToolsDir $toolsDir
if (-not $gameResolution) {
    Write-Host "[ERROR] Cannot locate Game_x64h.exe"
    Write-Host "[TIP] Create .vscode/settings.json via Y3 Helper, or set Y3_EDITOR_PATH / Y3_GAME_EXE"
    exit 1
}
$gameExe = $gameResolution.GameExe

$mapDir = Split-Path -Parent $scriptPath
$mapsDir = Split-Path -Parent $mapDir
$projectPath = Split-Path -Parent $mapsDir
if (-not $projectPath) {
    Write-Host "[ERROR] Cannot determine project root from script path: $scriptPath"
    exit 1
}

$headerFile = Join-Path $projectPath "header.project"
if (-not (Test-Path $headerFile)) {
    Write-Host "[ERROR] Cannot find header.project at: $headerFile"
    exit 1
}

$levelId = Read-LevelIdFromHeaderProject -HeaderFile $headerFile
if (-not $levelId) {
    Write-Host "[ERROR] Cannot read entry_map.id from header.project"
    exit 1
}

Write-Host "===== Y3 Game Launcher ====="
Write-Host "[OK] Script Path: $scriptPath"
Write-Host "[OK] Project Path: $projectPath"
Write-Host "[OK] Level ID: $levelId"
Write-Host "[OK] Game EXE: $gameExe"
Write-Host "[OK] Game EXE Source: $($gameResolution.Source)"

$escapedProjectPath = $projectPath -replace '\\', '\\\\'
$pythonArgs = "type@editor_game,subtype@editor_game,editor_map_path@$escapedProjectPath,level_id@$levelId,release@true,lua_dummy@space,lua_wait_debugger@false"

$gameWorkDir = Split-Path -Parent $gameExe
Set-Location $gameWorkDir

Write-Host "[OK] Starting game..."
Start-Process -FilePath $gameExe -ArgumentList @(
    "--dx11",
    "--start=Python",
    "--python-args=$pythonArgs",
    "--plugin-config=Plugins-PyQt",
    "--console",
    "--luaconsole"
)

Write-Host "[OK] Game launch command sent"
