#!/usr/bin/env bash
# Install skills from this repo into Cursor, Claude Code, or Codex.
# Usage: skill_install.sh <platform> [skill]
#   platform: cursor | claudecode | codex  (aliases: claude, claude-code)
#   skill:    skill directory name; omit or "all" to install every skill here

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="$(basename "$0")"

log_info()  { printf 'INFO  %s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
log_warn()  { printf 'WARN  %s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
log_error() { printf 'ERROR %s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
log_ok()    { printf 'OK    %s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
log_step()  { printf 'STEP  %s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
log_debug() { printf 'DEBUG %s: %s\n' "$SCRIPT_NAME" "$*" >&2; }

is_help_arg() {
  case "$1" in
    -h|--help) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<EOF
Usage: skill_install.sh [-h | --help]
       skill_install.sh <platform> [skill]

Options:
  -h, --help   Show this help and exit.

Platforms:
  cursor       -> ~/.cursor/skills/<skill>/
  claudecode   -> ~/.claude/skills/<skill>/  (aliases: claude, claude-code)
  codex        -> ~/.agents/skills/<skill>/   (OpenAI Codex; legacy: ~/.codex/skills)

Examples:
  skill_install.sh cursor markdown-to-docx
  skill_install.sh claudecode              # install all skills
  skill_install.sh codex all
EOF
}

normalize_platform() {
  local p="${1,,}"
  case "$p" in
    cursor) echo cursor ;;
    claudecode|claude|claude-code) echo claudecode ;;
    codex) echo codex ;;
    *)
      log_error "Unknown platform: $1"
      usage >&2
      exit 1
      ;;
  esac
}

skills_dest_root() {
  local platform="$1"
  case "$platform" in
    cursor) printf '%s/.cursor/skills' "$HOME" ;;
    claudecode) printf '%s/.claude/skills' "$HOME" ;;
    codex) printf '%s/.agents/skills' "$HOME" ;;
  esac
}

list_repo_skills() {
  local d name
  for d in "$REPO_ROOT"/*/; do
    [[ -f "${d}SKILL.md" ]] || continue
    name="$(basename "$d")"
    [[ "$name" == .* ]] && continue
    printf '%s\n' "$name"
  done
}

install_one() {
  local platform="$1"
  local skill="$2"
  local src="$REPO_ROOT/$skill"
  local root dest

  log_info "----- install skill='$skill' platform='$platform' -----"
  log_debug "REPO_ROOT=$REPO_ROOT source=$src"

  if [[ ! -f "$src/SKILL.md" ]]; then
    log_error "no skill '$skill' (missing $src/SKILL.md)"
    exit 1
  fi
  log_debug "SKILL.md size=$(wc -c <"$src/SKILL.md" | tr -d ' ') bytes"

  root="$(skills_dest_root "$platform")"
  dest="$root/$skill"
  log_info "destination root=$root"
  log_info "destination path=$dest"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      log_warn "existing install (symlink): $dest -> $(readlink "$dest" 2>/dev/null || echo '?')"
    elif [[ -d "$dest" ]]; then
      log_warn "existing install (directory); will replace with symlink"
    else
      log_warn "existing path at $dest (will replace)"
    fi
  else
    log_debug "no previous install at $dest"
  fi

  log_step "mkdir -p $root"
  mkdir -p "$root"
  log_step "ln -snf '$src' '$dest'"
  ln -snf "$src" "$dest"
  log_ok "installed '$skill' -> $dest"
  log_debug "resolved target: $(readlink -f "$dest" 2>/dev/null || readlink "$dest")"

  if [[ "$platform" == codex ]]; then
    local legacy="$HOME/.codex/skills/$skill"
    log_info "legacy codex destination=$legacy"
    log_step "mkdir -p $HOME/.codex/skills"
    mkdir -p "$HOME/.codex/skills"
    log_step "ln -snf '$src' '$legacy'"
    ln -snf "$src" "$legacy"
    log_ok "legacy codex install '$skill' -> $legacy"
    log_debug "legacy resolved: $(readlink -f "$legacy" 2>/dev/null || readlink "$legacy")"
  fi
}

want_all_skills() {
  local s="${1:-}"
  [[ -z "$s" ]] && return 0
  case "${s,,}" in
    all|"\*"|-) return 0 ;;
    *) return 1 ;;
  esac
}

main() {
  if [[ $# -ge 1 ]] && is_help_arg "$1"; then
    usage
    exit 0
  fi
  if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
  fi

  log_info "starting $SCRIPT_NAME (pid=$$ user=${USER:-?})"
  log_info "REPO_ROOT=$REPO_ROOT HOME=$HOME"

  local platform skill
  platform="$(normalize_platform "$1")"
  skill="${2:-}"
  log_info "normalized platform='$platform' skill_arg='${skill:-<all>}'"

  if want_all_skills "$skill"; then
    log_step "mode: install all skills from repository"
    local names=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && names+=("$line")
    done < <(list_repo_skills)
    if [[ ${#names[@]} -eq 0 ]]; then
      log_error "no skills found under $REPO_ROOT"
      exit 1
    fi
    log_info "skills to install (${#names[@]}): ${names[*]}"
    for skill in "${names[@]}"; do
      install_one "$platform" "$skill"
    done
    log_ok "batch install finished (${#names[@]} skill(s))"
  else
    log_step "mode: install single skill '$skill'"
    install_one "$platform" "$skill"
    log_ok "single install finished"
  fi
}

main "$@"