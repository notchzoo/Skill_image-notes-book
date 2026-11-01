# Changelog

## v0.1.0 — 2026-11-01

首个版本：从一次真实的多小节截图整理中提炼成可复用技能包。

### 新增

- `scripts/build-page.ps1`：参数化构建单文件阅读页
  - 子目录即小节，名称与小节内图片均按**自然序**排序（`1 (2)` < `1 (10)`，`2.3.1_x` < `2.3.2_y`）
  - JPEG 质量可调重编码 + base64 内嵌，100 张截图约 16 MB → 8 MB
  - `-ReuseFrom` 复用旧页已内嵌图片，改为只调文案/版式时秒级重建且不二次损失画质
  - 目录名中的 HTML 实体（`A&amp;B`）在页面内还原为 `A&B`，磁盘文件名不动
  - 空目录保留标题占位；非图片文件忽略；`-Exclude` 跳过指定目录，含 `.git` 的子目录自动跳过
- `scripts/check-page.ps1`：校验小节/图片/内嵌数据计数一致、目录项对应、占位符残留、
  CSS 括号平衡、重复 id、内嵌脚本语法（有 node 时）
- `assets/`：`shell.html` + `style.css` + `app.js` 三段模板，占位符为 `{{TOKEN}}`

### 版式

- 目录为**悬浮卡片**（300px，`position:fixed`），正文 `max-width:1080px` 居中，不再让出 306px 版心
- 四条收起路径：左下胶囊按钮、`Esc`、点面板外、窄屏下选中小节自动收起；`/` 展开并聚焦搜索
- 默认展开阈值 `1720px`（≈ 正文 1080 + 两侧面板留白），低于该值默认收起
- `figure` 限宽 1000px，避免宽屏把 800–1100px 的截图拉伸到 1.5 倍以上糊掉
- 打印时解除单节视图，全部小节分页输出（`#chapters section[hidden]{display:block!important}`）
- 搜索单一监听，匹配范围扩到图片文件名；清空关键词可回到单节视图
- 灯箱 `←/→` 翻页、适应宽度/原始尺寸切换；移动端（≤850px）目录抽屉化
- 可达性：焦点环、`aria-expanded`、`aria-current`、`aria-live`、`prefers-reduced-motion`

### 文档

- `SKILL.md`：与主题无关的表述与触发词，输入契约限定为「按主题分文件夹的图片」
- `references/layout-spec.md`：版式与交互规格，含每条规则的成因
- `references/workflow.md`：端到端流程、增量重建、故障排查、性能参考
- 全部示例使用中性占位（`notes/`、`01_总览/`、`主题名`、`My Notes`），不含特定项目内容

### 已知限制

- 首次构建依赖 Windows 的 `System.Drawing` 做 JPEG 重编码
- 不含已读标记、批注、OCR 图注（planned）
- 不含多份产物的总入口页（planned）
