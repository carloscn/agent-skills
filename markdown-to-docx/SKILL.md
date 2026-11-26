---
name: markdown-to-docx
description: Converts Markdown to Word docx using Pandoc, mermaid-filter for diagrams, and tex_math_dollars for native OMML equations. Cross-platform via discover-tools and optional env overrides. Use when exporting md to docx/word, embedding Mermaid in Word, or fixing raw dollar-sign math in docx output.
---

# Markdown → DOCX（跨平台）

## 依赖（用户自行安装，路径不假定）

| 工具 | 用途 | 安装提示 |
|------|------|----------|
| [Pandoc](https://pandoc.org) 2.19+ | md → docx | 系统包管理器 / 官方安装包 |
| [Node.js](https://nodejs.org) | 运行 filter | LTS 即可 |
| [mermaid-filter](https://www.npmjs.com/package/mermaid-filter) | ` ```mermaid` → 图 | `npm install -g mermaid-filter` |

**不**需要 Word 插件（公式为 OMML）。

## Agent 第一步：探测工具

在仓库 skill 目录执行（或由脚本隐式调用）：

```bash
scripts/discover-tools.sh
```

输出建议的 `export PANDOC=...`、`export MERMAID_FILTER=...`；**仅当自动发现失败时**才让用户设置环境变量。

规则：

1. 优先使用用户已设的 `PANDOC`、`MERMAID_FILTER`、`MERMAID_FILTER_CMD_MMDC`。
2. 否则搜索 `PATH`（`command -v` / `where`）。
3. WSL 可回退到 `Program Files/Pandoc/pandoc.exe`（扫描常见盘符，**无固定盘符路径**）。
4. `mmdc`：优先 `command -v mmdc`，否则 `npx @mermaid-js/mermaid-cli`（由 filter 或 `MERMAID_FILTER_CMD_MMDC` 指定）。

**Windows 原生**（无 Git Bash）：`scripts\md-to-docx.ps1`。

## Agent 第二步：转换

```bash
# 在 skill 目录或任意路径
/path/to/markdown-to-docx/scripts/md-to-docx.sh INPUT.md [OUTPUT.docx]
```

无 Mermaid 的纯 md：加 `--no-mermaid` 跳过 filter。

## Agent 第三步：校验

```bash
scripts/md-to-docx.sh --verify OUTPUT.docx
```

- 含 `$` 公式的源文件：OMML 计数应 > 0（见 [reference.md](reference.md)）。

## 源 Markdown 约定

- 公式：`$...$`、`$$...$$`，导出时 `--from=markdown+tex_math_dollars`（脚本默认）。
- Mermaid：fence 写 ` ```mermaid`；脚本会改为 ` ```{.mermaid ...}`。
- 下标命名：`$K_{db}$`、`$db_{\mathrm{uuid}}$`（避免 `db\_uuid`）。

## 高清 Mermaid（可选 env）

`MERMAID_FILTER_WIDTH`（默认 2400）、`MERMAID_FILTER_SCALE`（默认 2.5）、`MERMAID_FILTER_FORMAT`（默认 png）。

## 故障速查

| 现象 | 处理 |
|------|------|
| 公式仍是 `$` 文本 | 确认 `+tex_math_dollars`；源文件用 `$` 包裹 |
| 无图 | 未装 filter / 未预处理 mermaid class；看运行目录 `mermaid-filter.err` |
| mmdc 未找到 | `npm i -g @mermaid-js/mermaid-cli` 或 `discover-tools.sh` 提示 |
| WSL UNC 警告 | 可忽略或把 md 放到 `/mnt/<drive>/...` 再转 |

完整说明：[reference.md](reference.md)