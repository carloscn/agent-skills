# markdown-to-docx — reference

## Cross-platform entry points

| OS | Command |
|----|---------|
| Linux / macOS / Git Bash / WSL | `scripts/md-to-docx.sh` |
| Windows PowerShell | `scripts/md-to-docx.ps1` |

## Tool discovery（无固定路径）

`scripts/discover-tools.sh` 按顺序：

1. 环境变量 `PANDOC` / `MERMAID_FILTER` / `MERMAID_FILTER_CMD_MMDC`
2. `PATH`（`pandoc`、`mermaid-filter`、`mmdc`）
3. `npm prefix -g` 下的 `bin/`
4. skill 目录内 `node_modules/.bin/`（若用户 `npm i` 在 skill 根目录）
5. WSL：扫描 `/mnt/{c,d,e,f}/Program Files/Pandoc/pandoc.exe`（**不写死盘符以外的路径**）

用户也可用包管理器安装，无需告诉 skill 安装位置：

- Debian/Ubuntu: `apt install pandoc`（版本可能偏旧，需自测）
- macOS: `brew install pandoc`
- Windows: 官方 MSI / winget
- mermaid-filter: `npm install -g mermaid-filter`

## Pandoc 数学 → docx

- `--from=markdown+tex_math_dollars`
- 输出为 **OMML**（Word 原生公式）

## mermaid-filter

- Fence 必须带 class：`{.mermaid}`（脚本自动从 ` ```mermaid` 改写）
- 高清：`MERMAID_FILTER_WIDTH`、`MERMAID_FILTER_SCALE`
- 错误日志：运行 cwd 下 `mermaid-filter.err`

## 可选本地 npm 依赖

在 skill 目录：

```bash
npm init -y && npm install mermaid-filter
```

发现逻辑会优先使用 `markdown-to-docx/node_modules/.bin/mermaid-filter`。

## reference.docx

```bash
pandoc -o reference.docx --print-default-data-file reference.docx
export PANDOC_REFERENCE_DOC=/path/to/reference.docx
```