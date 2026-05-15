$pkg = "$env:USERPROFILE\.vscode\extensions\sumneko.y3-helper-2.1.0\package.json"
$json = Get-Content $pkg -Raw -Encoding UTF8
if ($json -match "onStartupFinished") {
    Write-Host "Already fixed."
} else {
    $json = $json -replace '"activationEvents": \[', '"activationEvents": [`r`n        "onStartupFinished",'
    [System.IO.File]::WriteAllText($pkg, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Fixed. Reload VSCode: Ctrl+Shift+P -> Developer: Reload Window"
}
