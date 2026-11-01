<#
.SYNOPSIS
  校验构建出的单文件笔记页：结构计数、占位符残留、CSS 括号、重复 id、内嵌脚本语法。

.EXAMPLE
  ./scripts/check-page.ps1 -Path ../第4章图片笔记-轻量版.html
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path
)

$failures = 0
function Report-Ok([string]$msg) { Write-Host ('  ok   ' + $msg) }
function Report-Fail([string]$msg) { Write-Host ('  FAIL ' + $msg); $script:failures++ }

if (-not (Test-Path -LiteralPath $Path)) { Write-Host ('  FAIL 文件不存在: ' + $Path); exit 1 }
$Path = (Resolve-Path -LiteralPath $Path).Path
$html = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
Write-Host ('检查: ' + $Path)

$size = (Get-Item -LiteralPath $Path).Length
Report-Ok ('体积 ' + [math]::Round($size / 1MB, 2) + ' MB')
if ($size -gt 25MB) { Write-Host '  warn 单文件超过 25 MB，首屏解析会明显变慢，考虑 -Quality 降低或分章拆页' }

$sections = ([regex]::Matches($html, '<section id="chapter-\d+" data-name="')).Count
$figures = ([regex]::Matches($html, '<figure>')).Count
$uris = ([regex]::Matches($html, 'src="data:image/')).Count
$navLinks = ([regex]::Matches($html, '<a href="#chapter-\d+" data-name="')).Count

if ($sections -gt 0) { Report-Ok ('小节 ' + $sections + ' 个') } else { Report-Fail '没有解析到任何小节' }
if ($figures -eq $uris) { Report-Ok ('图片 ' + $figures + ' 张，且全部内嵌') } else { Report-Fail ('图片标签 ' + $figures + ' 张，内嵌数据 ' + $uris + ' 条，数量不一致') }
if ($navLinks -eq $sections) { Report-Ok '目录项与小节一一对应' } else { Report-Fail ('目录项 ' + $navLinks + ' 与小节 ' + $sections + ' 不一致') }

$leftover = [regex]::Matches($html, '\{\{[A-Z_]+\}\}')
if ($leftover.Count -eq 0) { Report-Ok '无未替换占位符' } else { Report-Fail ('占位符残留: ' + (($leftover | ForEach-Object { $_.Value }) -join ', ')) }

$css = [regex]::Match($html, '(?s)<style>(.*?)</style>').Groups[1].Value
$open = ([regex]::Matches($css, '\{')).Count
$close = ([regex]::Matches($css, '\}')).Count
if ($open -eq $close) { Report-Ok ('CSS 括号平衡 (' + $open + ')') } else { Report-Fail ('CSS 括号 ' + $open + ' / ' + $close + ' 不平衡') }

$ids = @{}
$dup = @()
foreach ($m in [regex]::Matches($html, '\sid="([^"]+)"')) {
  $id = $m.Groups[1].Value
  if ($ids.ContainsKey($id)) { if ($dup -notcontains $id) { $dup += $id } } else { $ids[$id] = 1 }
}
if ($dup.Count -eq 0) { Report-Ok ('id 唯一 (' + $ids.Count + ' 个)') } else { Report-Fail ('重复 id: ' + ($dup -join ', ')) }

$js = [regex]::Match($html, '(?s)<script>\s*\r?\n(.*?)\r?\n</script>').Groups[1].Value
$node = Get-Command node -ErrorAction SilentlyContinue
if ($js -ne '' -and $node) {
  $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'notes-page-check-' + [guid]::NewGuid().ToString('N') + '.js')
  [System.IO.File]::WriteAllText($tmp, $js, (New-Object System.Text.UTF8Encoding($false)))
  try {
    & $node.Source --check $tmp *> $null
    if ($LASTEXITCODE -eq 0) { Report-Ok '内嵌脚本语法通过' } else { Report-Fail '内嵌脚本语法错误（node --check 非 0）' }
  }
  finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
elseif ($js -eq '') { Report-Fail '没有找到内嵌脚本' }
else { Write-Host '  skip 未安装 node，跳过脚本语法检查' }

if ($failures -eq 0) { Write-Host '结论: 通过'; exit 0 }
Write-Host ('结论: ' + $failures + ' 项未通过')
exit 1
