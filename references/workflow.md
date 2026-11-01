# 完整工作流

从「新一章的笔记目录」到「可下载的 GitHub 版本」。每步都有可执行的命令。

## 步骤 0：确认输入

```powershell
Get-ChildItem <笔记根目录> -Directory | ForEach-Object {
  $n = (Get-ChildItem $_.FullName -File -Include *.jpeg,*.jpg,*.png -Recurse).Count
  [pscustomobject]@{ 小节 = $_.Name; 图片 = $n }
} | Format-Table -AutoSize
```

要检查的只有两件事：**子目录名是否就是想要的小节标题**、**图片文件名里的数字排序能否表达讲课顺序**。
排序不对就在文件名上补数字（构建是自然序，`2 (1)` 会排在 `1.jpeg` 之后）。

## 步骤 1：构建

```powershell
cd image-notes-book
./scripts/build-page.ps1 `
  -Source 'C:\path\to\第5章' `
  -Out    'C:\path\to\第5章\计算机组成原理-第5章图片笔记-轻量版.html' `
  -ChapterNo 5 -ChapterTitle '中央处理器' -Series '计组 · 图片笔记'
```

耗时：图片编码约 100 张 / 1–2 分钟；复用模式（`-ReuseFrom`）为秒级。

## 步骤 2：校验

```powershell
./scripts/check-page.ps1 -Path '<上面 -Out 的路径>'
```

必须看到 `结论: 通过`。有 node 时会顺带做 `node --check`；没装 node 会写 `skip`，不算失败。

## 步骤 3：人工检查（3 项，30 秒）

1. 双击打开 → 默认只显示第 1 节，左下胶囊显示 `1/16 · …`
2. 点任意图 → 灯箱打开，`←/→` 翻页，再点一次图变原始尺寸
3. `Ctrl+P` 打印预览 → 应该是**全部小节**分页，而不是一节

## 步骤 4：增量重建

两种情形、两条命令：

| 情形 | 命令 | 耗时 |
|---|---|---|
| 只改标题 / 版式 / 文案 | 加 `-ReuseFrom <产出文件本身>` | 秒级 |
| 增删了图片 | 去掉 `-ReuseFrom`，重新编码 | 1–2 分钟 |

`-ReuseFrom` 会校验「旧页内嵌张数 == 当前目录张数」，不等就直接报错，不会悄悄错位。

## 步骤 5：发布

交给 `github-release-publish` 技能（同一套 DSH 环境）：

1. 先探测：`detect-state.ps1 -Path . -CheckRemote`
2. 状态 A/B → 问清仓库可见性（默认 private）→ `gh repo create … --source . --remote origin --push`
3. 首个版本建议 `v0.1.0`，tag + Release 一起建，正文用 `CHANGELOG.md` 对应小节
4. 回报固定表格：版本 / 提交 / 标签 / Release / 下载链接

发布前的验证口径：技能自身无构建，但必须跑一次真实构建 —— 拿任意一章的目录生成到临时文件，
`check-page.ps1` 通过后再发布。

## 常见故障

| 现象 | 原因 | 处理 |
|---|---|---|
| `无法加载脚本…未数字签名` | 执行策略是 Restricted | 用 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-page.ps1 …` 运行（推荐）；`Invoke-Expression` 也能跑，但 `$PSScriptRoot` 为空，必须显式传 `-TemplateDir` |
| 中文变成乱码 | .ps1 被存成 ANSI | 脚本必须以 UTF-8 **带 BOM** 保存（PS 5.1 靠 BOM 判断编码），仓库里已如此 |
| 目录里多出一个空小节 | 技能仓库本身就放在笔记根目录里 | 构建会自动跳过含 `.git` 的目录；若放的是别的东西，用 `-Exclude 目录名` |
| 页面显示 `AT&amp;T` | 目录名里带着 HTML 实体 | 构建脚本已自动还原；若仍出现，检查是否被二次转义 |
| 图片看起来发虚 | 版心超过图片原生宽度 | 确认 `assets/style.css` 里 `figure{max-width:1000px}` 还在 |
| 打印只有一节 | 打印块缺少 `#chapters section[hidden]{display:block!important}` | 补上（见 `layout-spec.md` §4） |
| 首屏很慢 / 浏览器卡 | 单文件过大 | `-Quality 72`，或按章拆成多页 |
| `占位符残留` 报错 | 模板被改坏了 | 对照 `assets/shell.html` 的 `{{TOKEN}}` 清单 |
| 输出路径报「目录不存在」 | `-Out` 的父目录必须先存在 | 先建目录；脚本不会替你建 |

## 一次真实运行的记录（第 4 章）

```text
Source : 计组\4（16 个子目录 = 16 节，112 张截图）
参数   : -ChapterNo 4 -ChapterTitle 指令系统 -Quality 80
结果   : 112 张图，16.28 MB 原图 → 8.05 MB 单文件
校验   : 小节 16 / 图片 112 / 目录项 16 一一对应，脚本语法通过
备注   : 4.3.1_3_AT&amp;T格式和Intel格式 的目录名带实体，页面内还原为 AT&T
```
