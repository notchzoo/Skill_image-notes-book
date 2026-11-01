# image-notes-book · 图片笔记成册

把一个「每个小节一个文件夹、里面按顺序放着截图」的目录，压成**一个可离线、可转发、可打印的单文件 HTML 阅读页**。
这不是文档项目，而是一个可直接执行的技能包：两个 PowerShell 脚本 + 一套版式模板。

当前版本：**v0.1.0** · 变更见 [CHANGELOG.md](CHANGELOG.md)

## 特性

- **单文件交付**：图片 base64 内嵌，双击即开，可离线、可外发、可 U 盘带走
- **悬浮目录**：300px 目录卡片浮在正文上，不占版心；胶囊按钮 / `Esc` / 点空白 / 选完小节 四条收起路径
- **单节视图 + 搜索**：一次只读一节，搜索覆盖小节名与图片文件名，`/` 直接聚焦搜索框
- **灯箱**：`←/→` 翻页，点击切「适应宽度 / 原始尺寸」
- **双列浏览**：一屏扫更多图
- **打印全展开**：`Ctrl+P` 打印的是全部小节，不是当前一节
- **体积可控**：JPEG 质量 80 重编码 + 复用已内嵌图片的增量重建

## 快速开始

```powershell
# 1. 构建（首次，约 1–2 分钟 / 100 张）
./scripts/build-page.ps1 -Source '../notes' -Out '../notes/notes.html' `
  -ChapterNo 2 -ChapterTitle '主题名' -Series 'My Notes'

# 2. 校验
./scripts/check-page.ps1 -Path '../notes/notes.html'
```

参数表、输入契约、边界与限制见 [SKILL.md](SKILL.md)；
版式细节见 [references/layout-spec.md](references/layout-spec.md)；
端到端流程与故障排查见 [references/workflow.md](references/workflow.md)。

## 目录结构

```text
image-notes-book/
├── SKILL.md                     技能主文件（输入契约、参数、校验口径）
├── README.md
├── CHANGELOG.md
├── VERSION
├── assets/
│   ├── shell.html               HTML 骨架（{{TOKEN}} 占位）
│   ├── style.css                全部样式（含悬浮目录、打印规则）
│   └── app.js                   全部交互（目录、搜索、灯箱、双列）
├── scripts/
│   ├── build-page.ps1           参数化构建
│   └── check-page.ps1           结构校验
└── references/
    ├── layout-spec.md           版式与交互规格
    └── workflow.md              端到端工作流
```

## 设计取舍

| 决定 | 代价 | 为什么仍然这么做 |
|---|---|---|
| 图片全部内嵌 | 单文件 8 MB 级别，首屏要解析整份 HTML | 换来「一个文件走天下」；这类页面看的人少、移动需求高，不是高并发 Web |
| 悬浮目录覆盖正文 | 窄屏上开目录会盖住图 | 换来正文不再永久让出 306px；四条收起路径让遮挡是瞬时的 |
| `figure` 限宽 1000px | 超宽屏两侧留白 | 截图常见宽度 800–1100px，不限宽就是 1.5 倍以上拉伸糊图 |
| 单节视图而非长滚动 | 不能一屏搜到底 | 几十个小节上百张图全展开是灾难；搜索 + 目录已经覆盖跳转需求 |

## 环境要求

- Windows + Windows PowerShell 5.1（或 PowerShell 7）
- 首次构建依赖 `System.Drawing`（Windows 自带）做 JPEG 重编码
- 可选：Node.js（仅用于校验内嵌脚本语法）

## 许可证

未指定许可证。未附加 LICENSE 文件时默认保留所有权利；如需开源请自行添加。
