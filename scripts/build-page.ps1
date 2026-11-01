<#
.SYNOPSIS
  把「每个小节一个文件夹、图片按文件名排序」的目录，构建成一个可离线打开的单文件 HTML 阅读页。

.DESCRIPTION
  - 子目录 = 小节，按名称中的数字自然排序（2.3.1_x 排在 2.3.2_y 之前，1 (2) 排在 1 (10) 之前）
  - 图片重编码后以 base64 内嵌，产物是单个可转发、可离线、可打印的 .html
  - 版式：悬浮目录卡片（不占版心）+ 单节视图 + 搜索 + 双列切换 + 灯箱
  - 已生成过的页面可用 -ReuseFrom 复用其中已内嵌的图片，重建只需几秒且画质不再受损

.EXAMPLE
  ./scripts/build-page.ps1 -Source ../notes -Out ../notes/notes.html `
    -ChapterNo 2 -ChapterTitle '主题名' -Series 'My Notes'

.EXAMPLE
  # 只改了标题/样式，图片直接复用上一版，秒级重建
  ./scripts/build-page.ps1 -Source ../notes -Out ../notes/notes.html `
    -ReuseFrom ../notes/notes.html -ChapterTitle '改过的标题'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Out,
  [string]$Source = (Get-Location).Path,
  [string]$Title = '',
  [string]$ChapterNo = '',
  [string]$ChapterTitle = '',
  [string]$Series = '图片笔记',
  [string]$BrandSub = 'STUDY COLLECTION',
  [string]$Eyebrow = '',
  [string]$HeadNote = '目录是悬浮卡片，随时收起；点击目录外任意处也会关闭。',
  [string]$Footnote = '保留原文件夹名称；图片已压缩以减小文件体积。非图片文件未收录。',
  [int]$Quality = 80,
  [string]$ReuseFrom = '',
  [int]$Wide = 1720,
  [string]$StorageKey = 'notes-toc',
  [string]$TemplateDir = '',
  [string[]]$Exclude = @('.git', 'assets', 'scripts', 'node_modules', 'out', 'build')
)

$ErrorActionPreference = 'Stop'

function Get-NaturalKey([string]$text) {
  $sb = New-Object System.Text.StringBuilder
  $digits = ''
  foreach ($ch in $text.ToCharArray()) {
    if ([char]::IsDigit($ch)) { $digits += $ch }
    else {
      if ($digits -ne '') { [void]$sb.Append($digits.PadLeft(6, '0')); $digits = '' }
      [void]$sb.Append($ch)
    }
  }
  if ($digits -ne '') { [void]$sb.Append($digits.PadLeft(6, '0')) }
  return $sb.ToString()
}

function ConvertTo-HtmlText([string]$text) {
  $text = $text -replace '&', '&amp;'
  $text = $text -replace '<', '&lt;'
  $text = $text -replace '>', '&gt;'
  $text = $text -replace '"', '&quot;'
  return $text
}

# 有些目录的名字是带着 HTML 实体存下来的（如 A&amp;B），展示时还原
function ConvertFrom-HtmlText([string]$text) {
  $text = $text -replace '&amp;', '&'
  $text = $text -replace '&lt;', '<'
  $text = $text -replace '&gt;', '>'
  $text = $text -replace '&quot;', '"'
  return $text
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

if ($TemplateDir -eq '') {
  if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    throw '无法定位模板目录：当前不是以 -File 方式运行（$PSScriptRoot 为空）。请改用 "powershell -ExecutionPolicy Bypass -File .\scripts\build-page.ps1 ..."，或显式传 -TemplateDir。'
  }
  $TemplateDir = Join-Path (Join-Path $PSScriptRoot '..') 'assets'
}
$TemplateDir = (Resolve-Path -LiteralPath $TemplateDir).Path
$Source = (Resolve-Path -LiteralPath $Source).Path
if (-not [System.IO.Path]::IsPathRooted($Out)) { $Out = Join-Path (Get-Location).Path $Out }
$OutDir = Split-Path -Parent $Out
if ($OutDir -and -not (Test-Path -LiteralPath $OutDir)) { throw "输出目录不存在: $OutDir" }

# ---- 1. 收集目录与小节 ----
# 跳过：显式排除项、隐藏目录、以及本身是 git 工作树/技能包的目录（它们不是讲课小节）
$dirs = Get-ChildItem -LiteralPath $Source -Directory |
  Where-Object {
    $Exclude -notcontains $_.Name -and
    -not $_.Name.StartsWith('.') -and
    -not (Test-Path -LiteralPath (Join-Path $_.FullName '.git'))
  } |
  Sort-Object @{ Expression = { Get-NaturalKey $_.Name } }

$sections = @()
foreach ($dir in $dirs) {
  $files = Get-ChildItem -LiteralPath $dir.FullName -File |
    Where-Object { $_.Extension -match '^\.(jpe?g|png|gif|webp|bmp)$' } |
    Sort-Object @{ Expression = { Get-NaturalKey $_.Name } }
  $sections += [pscustomobject]@{
    Name    = $dir.Name
    Display = ConvertFrom-HtmlText $dir.Name
    Files   = $files
  }
}
if ($sections.Count -eq 0) { throw "在 $Source 下没有找到任何小节目录" }

$total = 0
foreach ($sec in $sections) { $total += $sec.Files.Count }

# ---- 2. 图片：复用旧页内嵌数据，或重新编码 ----
$uris = @()
if ($ReuseFrom -ne '') {
  $ReuseFrom = (Resolve-Path -LiteralPath $ReuseFrom).Path
  $old = [System.IO.File]::ReadAllText($ReuseFrom, [System.Text.Encoding]::UTF8)
  foreach ($m in [regex]::Matches($old, 'src="(data:image/[a-z]+;base64,[^"]+)"')) { $uris += $m.Groups[1].Value }
  if ($uris.Count -ne $total) {
    throw "复用失败：旧页内嵌 $($uris.Count) 张，当前目录有 $total 张。请去掉 -ReuseFrom 重新编码。"
  }
  Write-Host "复用已有内嵌图片：$($uris.Count) 张（不重新编码）"
}
else {
  Add-Type -AssemblyName System.Drawing
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
  Write-Host "编码图片：$total 张，JPEG 质量 $Quality"
  foreach ($sec in $sections) {
    foreach ($f in $sec.Files) {
      $img = [System.Drawing.Image]::FromFile($f.FullName)
      $ms = New-Object System.IO.MemoryStream
      try {
        $img.Save($ms, $codec, $encoderParams)
        $uris += 'data:image/jpeg;base64,' + [Convert]::ToBase64String($ms.ToArray())
      }
      finally {
        $ms.Dispose()
        $img.Dispose()
      }
    }
  }
}

# ---- 3. 生成目录与小节标记 ----
$nav = New-Object System.Text.StringBuilder
$content = New-Object System.Text.StringBuilder
$cursor = 0
$secNo = 0
$emptyDirs = 0
foreach ($sec in $sections) {
  $secNo++
  $sid = 'chapter-' + $secNo
  $escName = ConvertTo-HtmlText $sec.Display
  $n = $sec.Files.Count
  if ($n -eq 0) { $emptyDirs++ }
  [void]$nav.Append('<a href="#' + $sid + '" data-name="' + $escName + '"><span>' + $escName + '</span><small>' + $n + '</small></a>')
  [void]$content.Append('<section id="' + $sid + '" data-name="' + $escName + '"><div class="chapter-heading"><h2>' + $escName + '</h2><span>' + $n + ' 张图片</span></div>')
  if ($n -eq 0) { [void]$content.Append('<p class="empty">此文件夹暂无图片，已保留章节位置。</p>') }
  $i = 0
  foreach ($f in $sec.Files) {
    $i++
    $alt = ConvertTo-HtmlText ($sec.Display + ' · ' + $f.Name)
    [void]$content.Append('<figure><button class="picture" data-index="' + $cursor + '" aria-label="放大：' + $escName + '，第 ' + $i + ' 张"><img src="' + $uris[$cursor] + '" alt="' + $alt + '" loading="lazy" decoding="async"></button><figcaption><span>' + $i.ToString('00') + ' / ' + $n.ToString('00') + '</span><span>' + (ConvertTo-HtmlText $f.Name) + '</span><span>点击放大 ↗</span></figcaption></figure>')
    $cursor++
  }
  [void]$content.Append('</section>')
}

# ---- 4. 文案默认值 ----
$chapterLabel = ''
if ($ChapterNo -ne '') { $chapterLabel = '第 ' + $ChapterNo + ' 章' }
if ($Title -eq '') {
  if ($ChapterTitle -ne '' -and $chapterLabel -ne '') { $Title = $chapterLabel + ' · ' + $ChapterTitle }
  elseif ($ChapterTitle -ne '') { $Title = $ChapterTitle }
  else { $Title = [System.IO.Path]::GetFileNameWithoutExtension($Out) }
}
if ($Eyebrow -eq '') {
  if ($ChapterNo -ne '') {
    $pad = ([string]$ChapterNo).PadLeft(2, '0')
    $Eyebrow = 'CHAPTER ' + $pad + ' · ' + $BrandSub
  }
  else { $Eyebrow = $BrandSub }
}
$h1 = $Title
if ($ChapterTitle -ne '') { $h1 = $ChapterTitle }
$sidebarNote = $Series
if ($ChapterNo -ne '' -and $ChapterTitle -ne '') { $sidebarNote = $chapterLabel + ' / ' + $ChapterTitle }
$searchPlaceholder = '搜索章节或图片名…'

$stats = '<span>' + $sections.Count + ' 个章节</span><span>' + $total + ' 张图片 · 轻量版</span><span>离线可用 · 图片已内嵌</span>'

# ---- 5. 拼装 ----
$style = [System.IO.File]::ReadAllText((Join-Path $TemplateDir 'style.css'), [System.Text.Encoding]::UTF8)
$appJs = [System.IO.File]::ReadAllText((Join-Path $TemplateDir 'app.js'), [System.Text.Encoding]::UTF8)
$shell = [System.IO.File]::ReadAllText((Join-Path $TemplateDir 'shell.html'), [System.Text.Encoding]::UTF8)

$appJs = $appJs.Replace('{{WIDE}}', [string]$Wide).Replace('{{STORAGE_KEY}}', ($StorageKey -replace '[^A-Za-z0-9._-]', '-'))

$map = [ordered]@{
  '{{TITLE}}'              = ConvertTo-HtmlText $Title
  '{{SERIES}}'             = ConvertTo-HtmlText $Series
  '{{BRAND_SUB}}'          = ConvertTo-HtmlText $BrandSub
  '{{SIDEBAR_NOTE}}'       = ConvertTo-HtmlText $sidebarNote
  '{{SEARCH_PLACEHOLDER}}' = ConvertTo-HtmlText $searchPlaceholder
  '{{EYEBROW}}'            = ConvertTo-HtmlText $Eyebrow
  '{{H1}}'                 = ConvertTo-HtmlText $h1
  '{{HEADNOTE}}'           = ConvertTo-HtmlText $HeadNote
  '{{STATS}}'              = $stats
  '{{NAV}}'                = $nav.ToString()
  '{{SECTIONS}}'           = $content.ToString()
  '{{FOOTNOTE}}'           = $Footnote
}
foreach ($key in $map.Keys) { $shell = $shell.Replace($key, $map[$key]) }
$shell = $shell.Replace('{{CSS}}', $style).Replace('{{JS}}', $appJs)

$leftover = [regex]::Matches($shell, '\{\{[A-Z_]+\}\}')
if ($leftover.Count -gt 0) { throw ("模板仍有未替换的占位符: " + (($leftover | ForEach-Object { $_.Value }) -join ', ')) }

[System.IO.File]::WriteAllText($Out, $shell, $utf8)

$size = (Get-Item -LiteralPath $Out).Length
Write-Host ('已生成: ' + $Out)
Write-Host ('章节 ' + $sections.Count + ' / 图片 ' + $total + ' / 体积 ' + [math]::Round($size / 1MB, 2) + ' MB')
if ($emptyDirs -gt 0) { Write-Host ('提示: ' + $emptyDirs + ' 个空目录已保留标题占位') }

[pscustomobject]@{
  Out      = $Out
  Sections = $sections.Count
  Images   = $total
  EmptyDirs = $emptyDirs
  Bytes    = $size
}
