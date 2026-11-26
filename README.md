# agent-skills

可 Git 维护的 Cursor / Agent **Skills** 集合。每个子目录为一个 skill（含 `SKILL.md`）。

## 安装（推荐）

在仓库根目录使用跨平台安装脚本（存在则覆盖目标）。

| 平台 | 个人 skills 目录 |
|------|------------------|
| `cursor` | `~/.cursor/skills/<skill>/` |
| `claudecode`（别名 `claude`、`claude-code`） | `~/.claude/skills/<skill>/` |
| `codex` | `~/.agents/skills/<skill>/`（并同步链到遗留路径 `~/.codex/skills/`） |

```bash
# Linux / WSL / macOS
chmod +x skill_install.sh
./skill_install.sh cursor markdown-to-docx
./skill_install.sh claudecode          # 安装本仓库内全部 skill
./skill_install.sh codex all
```

```cmd
REM Windows（在仓库根目录）
skill_install.cmd cursor markdown-to-docx
skill_install.cmd claude               REM 第二个参数省略 = 安装全部
```

脚本默认用符号链接（Linux）或目录联接 junction / 复制（Windows）指向本仓库里的 skill 目录，便于 `git pull` 后即用。四个脚本均带分级日志（`INFO` / `STEP` / `DEBUG` / `WARN` / `OK`）。

## 卸载

```bash
chmod +x skill_uninstall.sh
./skill_uninstall.sh cursor markdown-to-docx
./skill_uninstall.sh claudecode              # 卸载本仓库定义的全部 skill
```

```cmd
skill_uninstall.cmd claude markdown-to-docx
skill_uninstall.cmd codex
```

默认只删除**指向本仓库**的 symlink/junction，或与仓库 `SKILL.md` 一致的复制安装；若目标路径是其它来源，会打 `WARN` 并跳过。强制删除：

```bash
SKILL_UNINSTALL_FORCE=1 ./skill_uninstall.sh cursor markdown-to-docx
```

（Windows：`set SKILL_UNINSTALL_FORCE=1` 后运行 `skill_uninstall.cmd`。）

也可手动链接：

```bash
ln -snf "$(pwd)/markdown-to-docx" ~/.cursor/skills/markdown-to-docx
```

或在项目内使用：`.cursor/skills/`、`.claude/skills/`、`.agents/skills/` 下放同名目录或 submodule。

## Skills

| Skill | 说明 |
|-------|------|
| [markdown-to-docx](markdown-to-docx/) | Markdown → Word（Mermaid 图 + `$` 公式 → OMML） |