# Y3 游戏启动脚本（自动读取配置）

$ErrorActionPreference = "Stop"

# 硬编码路径
$scriptPath = "D:\project\_codex_y3td_push\maps\EntryMap\script"
$projectPath = "D:\project\_codex_y3td_push"
$editorPath = "D:\Program Files\y3\games\2.0\game\Editor.exe"

# 验证目录
if (-not (Test-Path (Join-Path $scriptPath "main.lua"))) {
    Write-Host "[ERROR] Cannot find script directory"
    exit 1
}

# 游戏可执行文件
$gameExe = Join-Path (Split-Path -Parent $editorPath) "Engine\Binaries\Win64\Game_x64h.exe"
if (-not (Test-Path $gameExe)) {
    Write-Host "[ERROR] Cannot find Game_x64h.exe"
    exit 1
}

# 读取 header.project 获取 level_id（保持大数字精度）
$headerFile = Join-Path $projectPath "header.project"
if (-not (Test-Path $headerFile)) {
    Write-Host "[ERROR] Cannot find header.project"
    exit 1
}

# 使用 .NET 读取 JSON
Add-Type -AssemblyName System.Web.Extensions -ErrorAction SilentlyContinue
$jsonContent = Get-Content $headerFile -Raw -Encoding UTF8
$serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$headerData = $serializer.DeserializeObject($jsonContent)
$levelId = [string]$headerData.entry_map.id

Write-Host "===== Y3 Game Launcher ====="
Write-Host "[OK] Level ID: $levelId"

# 构建启动参数
$escapedProjectPath = $projectPath -replace '\\', '\\\\'
$pythonArgs = "type@editor_game,subtype@editor_game,editor_map_path@$escapedProjectPath,level_id@$levelId,release@true,lua_dummy@space,lua_wait_debugger@true"

# 启动游戏
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

Write-Host "[OK] Game launched"
