$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  return [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..\..\..\..'))
}

function New-Utf8File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )

  $directory = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
  }

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function ConvertTo-PlainText {
  param(
    [AllowNull()][object]$Value
  )

  if ($null -eq $Value) {
    return ''
  }

  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) {
    return ''
  }

  $text = [System.Text.RegularExpressions.Regex]::Replace($text, '<[^>]+>', ' ')
  $text = [System.Net.WebUtility]::HtmlDecode($text)
  $text = $text -replace '\s+', ' '
  return $text.Trim()
}

function Escape-LuaString {
  param(
    [AllowNull()][string]$Value
  )

  if ($null -eq $Value) {
    return ''
  }

  return ($Value -replace '\\', '\\\\' -replace "'", "\\'")
}

function Get-LanguageText {
  param(
    [hashtable]$LanguageMap,
    [AllowNull()][object]$FieldValue
  )

  if ($null -eq $FieldValue) {
    return ''
  }

  $key = [string]$FieldValue
  if ($LanguageMap.ContainsKey($key)) {
    return ConvertTo-PlainText $LanguageMap[$key]
  }

  return ConvertTo-PlainText $FieldValue
}

function Get-ObjectName {
  param(
    [hashtable]$LanguageMap,
    [pscustomobject]$ObjectData,
    [string]$FallbackId
  )

  $name = Get-LanguageText -LanguageMap $LanguageMap -FieldValue $ObjectData.name
  if (-not [string]::IsNullOrWhiteSpace($name)) {
    return $name
  }

  $name = ConvertTo-PlainText $ObjectData.key
  if (-not [string]::IsNullOrWhiteSpace($name)) {
    return $name
  }

  return $FallbackId
}

function Get-ScaffoldContent {
  param(
    [hashtable]$TypeConfig,
    [string]$ObjectId,
    [string]$ObjectName,
    [string]$SourceRelativePath
  )

  $safeName = Escape-LuaString $ObjectName
  $safeSource = Escape-LuaString $SourceRelativePath

  if ($TypeConfig.wrapper) {
    $sampleEvent = $TypeConfig.sample_event
    $sampleComment = if ([string]::IsNullOrWhiteSpace($sampleEvent)) {
      '-- M:event(''事件名'', function(_, data)'
    } else {
      "-- M:event('$sampleEvent', function(_, data)"
    }

    return @"
local M = y3.object.$($TypeConfig.wrapper)[$ObjectId] -- $ObjectName

-- 物编类型：$($TypeConfig.source_dir)
-- 物编 ID：$ObjectId
-- 数据源：$SourceRelativePath
-- 直接在这个文件里给 M 挂事件或写物编相关逻辑即可。
$sampleComment
-- end)

return M
"@
  }

  $note = Escape-LuaString $TypeConfig.note
  return @"
local M = {
  id = $ObjectId,
  type = '$($TypeConfig.source_dir)',
  name = '$safeName',
  source = '$safeSource',
}

-- $($TypeConfig.note)

return M
"@
}

function Get-ManifestEntry {
  param(
    [string]$ObjectId,
    [string]$ObjectName,
    [string]$ModuleName,
    [string]$SourceRelativePath
  )

  $safeName = Escape-LuaString $ObjectName
  $safeModule = Escape-LuaString $ModuleName
  $safeSource = Escape-LuaString $SourceRelativePath

  return "    { id = $ObjectId, name = '$safeName', module = '$safeModule', source = '$safeSource' },"
}

$repoRoot = Get-RepoRoot
$editorTableRoot = Join-Path $repoRoot 'maps\EntryMap\editor_table'
$languageFile = Join-Path $repoRoot 'maps\EntryMap\zhlanguage.json'
$outputRoot = Join-Path $repoRoot 'maps\EntryMap\script\entry_objects\object_editor'

$typeConfigs = @(
  @{
    source_dir = 'abilityall'
    wrapper = 'ability'
    sample_event = '施法-出手'
    note = ''
  },
  @{
    source_dir = 'editorunit'
    wrapper = 'unit'
    sample_event = '单位-创建'
    note = ''
  },
  @{
    source_dir = 'editoritem'
    wrapper = 'item'
    sample_event = '物品-使用'
    note = ''
  },
  @{
    source_dir = 'modifierall'
    wrapper = 'buff'
    sample_event = '效果-获得'
    note = ''
  },
  @{
    source_dir = 'projectileall'
    wrapper = 'projectile'
    sample_event = '投射物-创建'
    note = ''
  },
  @{
    source_dir = 'editordestructible'
    wrapper = 'destructible'
    sample_event = ''
    note = ''
  },
  @{
    source_dir = 'technologyall'
    wrapper = $null
    sample_event = ''
    note = '当前 y3 库没有和 unit / ability 一样的 y3.object.technology 入口，这里先保留脚手架供你按科技 ID 写逻辑。'
  },
  @{
    source_dir = 'editordecoration'
    wrapper = $null
    sample_event = ''
    note = '装饰物编当前没有直接对应的 y3.object 编辑入口，这个文件用于承接与该物编相关的脚本和备注。'
  },
  @{
    source_dir = 'soundall'
    wrapper = $null
    sample_event = ''
    note = '声音物编当前没有直接对应的 y3.object 编辑入口，这个文件用于承接与该物编相关的脚本和备注。'
  },
  @{
    source_dir = 'stateall'
    wrapper = $null
    sample_event = ''
    note = '状态物编当前没有直接对应的 y3.object 编辑入口，这个文件用于承接与该物编相关的脚本和备注。'
  },
  @{
    source_dir = 'storeall'
    wrapper = $null
    sample_event = ''
    note = '商店物编当前没有直接对应的 y3.object 编辑入口，这个文件用于承接与该物编相关的脚本和备注。'
  },
  @{
    source_dir = 'editorphysicsobject'
    wrapper = $null
    sample_event = ''
    note = '物理物体物编当前没有直接对应的 y3.object 编辑入口，这个文件用于承接与该物编相关的脚本和备注。'
  },
  @{
    source_dir = 'editorphysicsobjectlogic'
    wrapper = $null
    sample_event = ''
    note = '物理逻辑物编当前没有直接对应的 y3.object 编辑入口，这个文件用于承接与该物编相关的脚本和备注。'
  }
)

$languageJson = Get-Content -Raw $languageFile | ConvertFrom-Json
$languageMap = @{}
foreach ($property in $languageJson.PSObject.Properties) {
  $languageMap[$property.Name] = $property.Value
}

[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null

$manifestSections = @()
$loadAllModules = New-Object System.Collections.Generic.List[string]
$summary = New-Object System.Collections.Generic.List[string]

foreach ($typeConfig in $typeConfigs) {
  $sourceDirName = $typeConfig.source_dir
  $sourceDir = Join-Path $editorTableRoot $sourceDirName
  $targetDir = Join-Path $outputRoot $sourceDirName
  [System.IO.Directory]::CreateDirectory($targetDir) | Out-Null

  $entries = New-Object System.Collections.Generic.List[string]
  $moduleNames = New-Object System.Collections.Generic.List[string]

  if (Test-Path $sourceDir) {
    $jsonFiles = Get-ChildItem $sourceDir -Filter *.json | Sort-Object BaseName
    foreach ($jsonFile in $jsonFiles) {
      $objectId = $jsonFile.BaseName
      $objectData = Get-Content -Raw $jsonFile.FullName | ConvertFrom-Json
      $objectName = Get-ObjectName -LanguageMap $languageMap -ObjectData $objectData -FallbackId $objectId
      $sourceRelativePath = "maps/EntryMap/editor_table/$sourceDirName/$($jsonFile.Name)"
      $moduleName = "entry_objects.object_editor.$sourceDirName.$objectId"
      $targetFile = Join-Path $targetDir "$objectId.lua"

      $content = Get-ScaffoldContent -TypeConfig $typeConfig -ObjectId $objectId -ObjectName $objectName -SourceRelativePath $sourceRelativePath
      New-Utf8File -Path $targetFile -Content $content

      $entries.Add((Get-ManifestEntry -ObjectId $objectId -ObjectName $objectName -ModuleName $moduleName -SourceRelativePath $sourceRelativePath)) | Out-Null
      $moduleNames.Add($moduleName) | Out-Null
      $loadAllModules.Add("require '$moduleName'") | Out-Null
    }
  }

  $manifestSections += @(
    "  $sourceDirName = {"
    $entries
    "  },"
  )
  $summary.Add("$sourceDirName`t$($moduleNames.Count)") | Out-Null
}

$manifestContent = @(
  '-- Auto-generated by generate_object_editor_scaffolds.ps1.'
  '-- 每个条目都对应 maps/EntryMap/editor_table 里的一个物编 JSON。'
  'return {'
  $manifestSections
  '}'
) -join "`r`n"
New-Utf8File -Path (Join-Path $outputRoot 'manifest.lua') -Content $manifestContent

$loadAllContent = @(
  '-- Auto-generated by generate_object_editor_scaffolds.ps1.'
  '-- 按需 require 这个文件即可一次性加载全部物编脚本脚手架。'
  $loadAllModules
  ''
  "return require 'entry_objects.object_editor.manifest'"
) -join "`r`n"
New-Utf8File -Path (Join-Path $outputRoot 'load_all.lua') -Content $loadAllContent

$readmeLines = @(
  '# Object Editor Script Scaffolds',
  '',
  '这个目录由 `generate_object_editor_scaffolds.ps1` 自动生成。',
  '',
  '- 数据来源：`maps/EntryMap/editor_table/*/*.json`',
  '- 语言来源：`maps/EntryMap/zhlanguage.json`',
  '- 单文件命名：`<物编ID>.lua`',
  '- 清单文件：`manifest.lua`',
  '- 可选总加载入口：`load_all.lua`',
  '',
  '当前统计：',
  ''
)

foreach ($line in $summary) {
  $parts = $line -split "`t"
  $readmeLines += "- $($parts[0]): $($parts[1])"
}

$readmeContent = $readmeLines -join "`r`n"
New-Utf8File -Path (Join-Path $outputRoot 'README.md') -Content $readmeContent

Write-Output "Generated object editor scaffolds under $outputRoot"
foreach ($line in $summary) {
  Write-Output $line
}
