# 修复 y3-helper 侧边栏图标消失问题
# 在 activationEvents 中添加 onStartupFinished 确保扩展在 VSCode 启动时激活

$pkg = "$env:USERPROFILE\.vscode\extensions\sumneko.y3-helper-2.1.0\package.json"

if (-not (Test-Path $pkg)) {
    Write-Host "找不到 y3-helper 扩展，请确认已安装" -ForegroundColor Red
    pause
    exit 1
}

$json = Get-Content $pkg -Raw -Encoding UTF8

# 检查是否已经修复
if ($json -match "onStartupFinished") {
    Write-Host "已修复，无需重复操作" -ForegroundColor Green
    pause
    exit 0
}

# 添加 onStartupFinished
$json = $json -replace '"activationEvents": \[', '"activationEvents": [`n        "onStartupFinished",'

Set-Content $pkg -Value $json -Encoding UTF8 -NoNewline
Write-Host "修复完成！请重启 VSCode (Ctrl+Shift+P → Developer: Reload Window)" -ForegroundColor Green
pause
