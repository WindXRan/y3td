# Y3 游戏启动脚本（自动读取配置）
# 使用方法：通过计划任务 Y3LaunchGame 调用
# 配置自动从 .vscode/settings.json 和 header.project 读取

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
    $match = [regex]::Match($content, 'cd\s+/d\s+"([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
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

# 获取脚本所在目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsDir = $scriptDir

# 向上查找 script 目录（tools 的父目录）
$scriptPath = Split-Path -Parent $toolsDir

# 验证 script 目录
if (-not (Test-Path (Join-Path $scriptPath "main.lua"))) {
    Write-Host "[ERROR] Cannot find script directory (no main.lua found)"
    exit 1
}

# 定位游戏可执行文件，优先读取 .vscode/settings.json，缺失时自动回退
$gameResolution = Resolve-GameExe -ScriptPath $scriptPath -ToolsDir $toolsDir
if (-not $gameResolution) {
    Write-Host "[ERROR] Cannot locate Game_x64h.exe"
    Write-Host "[TIP] Create .vscode/settings.json via Y3 Helper, or set Y3_EDITOR_PATH / Y3_GAME_EXE"
    exit 1
}
$gameExe = $gameResolution.GameExe

# 从 script 路径推算项目路径
# script 路径格式: <project>/maps/<map_name>/script
$pathParts = $scriptPath -split '\\'
$mapsIndex = [array]::IndexOf($pathParts, "maps")
if ($mapsIndex -lt 0) {
    Write-Host "[ERROR] Cannot find 'maps' in path to determine project root"
    exit 1
}
$projectPath = ($pathParts[0..($mapsIndex-1)]) -join '\'

# 读取 header.project 获取 level_id
$headerFile = Join-Path $projectPath "header.project"
if (-not (Test-Path $headerFile)) {
    Write-Host "[ERROR] Cannot find header.project at: $headerFile"
    exit 1
}

$headerData = Get-Content $headerFile -Raw | ConvertFrom-Json
$levelId = $headerData.entry_map.id
if (-not $levelId) {
    Write-Host "[ERROR] Cannot read entry_map.id from header.project"
    exit 1
}

# 输出配置信息
Write-Host "===== Y3 Game Launcher ====="
Write-Host "[OK] Script Path: $scriptPath"
Write-Host "[OK] Project Path: $projectPath"
Write-Host "[OK] Level ID: $levelId"
Write-Host "[OK] Game EXE: $gameExe"
Write-Host "[OK] Game EXE Source: $($gameResolution.Source)"

# 构建启动参数（注意路径中的反斜杠需要转义）
$escapedProjectPath = $projectPath -replace '\\', '\\\\'
$pythonArgs = "type@editor_game,subtype@editor_game,editor_map_path@$escapedProjectPath,level_id@$levelId,release@true,lua_dummy@space,lua_wait_debugger@false"

# 切换到游戏目录并启动
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
