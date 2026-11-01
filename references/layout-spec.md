# 版式与交互规格

改样式或改脚本前先读这一页，能省掉一轮返工。

## 1. 骨架

```text
body[data-toc=open|closed]
├── button.toc-toggle          ← 左下角常驻胶囊：☰ 目录 · 3/12 · 当前小节
├── div.scrim                  ← 只在 <1200px 出现，点它收起目录
├── aside.sidebar              ← 悬浮目录卡片，position:fixed
│   ├── .brand (small + 品牌行)
│   ├── p                      ← 标签行（Series，或「编号 / 标题」）
│   ├── input#search
│   └── nav > a × N            ← 小节链接，a.active 高亮
├── main (max-width:1080px, margin:0 auto)
│   ├── header (eyebrow / h1 / p / .stats)
│   ├── .toolbar (#result + #layout 双列按钮)
│   ├── #chapters > section × N
│   │   └── .chapter-heading + figure × M
│   ├── #no-results
│   └── footer
├── a.top
└── dialog (#view-title / #prev / #next / #zoom / #close / .viewbody > #large)
```

## 2. 悬浮目录：不占版心，遮住就收起

| 项 | 值 | 原因 |
|---|---|---|
| 面板宽度 | 300px，`left:14px; top:14px; bottom:76px` | 下沿留出 76px，胶囊按钮永远压在面板之外、可点 |
| 正文 | `max-width:1080px; margin:0 auto` | 不再 `margin-left:306px`，切节时不重排 |
| 默认状态 | `innerWidth >= 1720` 展开，否则收起 | 1720 ≈ 1080 + 2×(300+16)，此时面板正好落在留白里，零遮挡 |
| 收起动画 | `translateX(calc(-100% - 20px))` + opacity | 只动面板，不动正文 |
| localStorage | `notes-toc` = `open|closed` | 记住上次选择，多份产物共享 |

四条收起路径（缺一条就会被抱怨"关不掉"）：

1. 左下胶囊按钮（常驻、带当前小节，兼作"我现在在哪"）
2. `Esc`
3. 点面板外任意处（document 级监听，导航链接本身除外）
4. 视口 < 1720 时，选中任一小节后自动收起

另外 `/` 展开面板并把焦点送进搜索框。

## 3. 图片尺寸：为什么 `figure` 要限宽 1000px

截图常见宽度 800–1100px。若图宽随版心（`width:100%`）走，1920 屏上会被拉到约 1510px，
放大 1.5 倍以上，文字发虚。`figure{max-width:1000px;margin:0 auto 22px}` 让它接近原生比例。
双列模式（`.compact figure{max-width:none}`）因为列宽只有约 500px，不需要这个限制。

## 4. 打印：必须解除单节视图

页面平时只显示一个小节（其余 `section[hidden]`），而全局有 `[hidden]{display:none!important}`。
所以打印块里必须有：

```css
#chapters section[hidden]{display:block!important}   /* id 特异性压过全局 !important */
section{break-before:page}
figure{break-inside:avoid}
```

少这条就只能打印出当前那一节。

## 5. 搜索与单节视图

- 只绑定一个 `input` 监听。历史实现绑了两次，导致清空关键词后回不到多节状态。
- 匹配范围 = `data-name`（小节名）+ 该节 `textContent`（含图片文件名）。
- 有关键词时：过滤目录项、打开第一个命中节、显示「找到 N 个章节」。
- 清空关键词时：目录项全部恢复，正文只显示当前节。

## 6. 灯箱

`dialog` 原生对话框；`show()` 按全局图片数组取下标，左右键翻页，点图或 `#zoom` 在
「适应宽度 / 原始尺寸」间切换，`::backdrop` 毛玻璃。关闭时恢复 `body` 的 `overflow`。

## 7. 移动端（≤850px）

侧栏变成贴顶抽屉（`top:10px; left/right:10px; max-height:70vh`）、目录两列、文章内边距收窄、
`.top` 从右下挪到右上避免和胶囊按钮打架。

## 8. 可达性

`:focus-visible` 统一 3px 焦点环；胶囊按钮维护 `aria-expanded`；当前节 `aria-current="page"`；
`#result` 用 `aria-live="polite"`；灯箱按钮都有 `aria-label`；`prefers-reduced-motion` 下关掉滚动与面板动画。
