#!/usr/bin/env bash
# Remove skills installed under Cursor, Claude Code, or Codex (reverse of skill_install.sh).
# Usage: skill_uninstall.sh <platform> [skill]
#   platform: cursor | claudecode | codex  (aliases: claude, claude-code)
#   skill:    skill directory name; omit or "all" to uninstall every skill from this repo

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
Usage: skill_uninstall.sh [-h | --help]
       skill_uninstall.sh <platform> [skill]

Options:
  -h, --help   Show this help and exit.

Platforms:
  cursor       -> ~/.cursor/skills/<skill>/
  claudecode   -> ~/.claude/skills/<skill>/  (aliases: claude, claude-code)
  codex        -> ~/.agents/skills/<skill>/ and legacy ~/.codex/skills/<skill>/

Examples:
  skill_uninstall.sh cursor markdown-to-docx
  skill_uninstall.sh claudecode              # uninstall all skills from this repo
  skill_uninstall.sh codex all

Note: Only removes entries under the platform skills directory (never deletes files in $REPO_ROOT).
      Set SKILL_UNINSTALL_FORCE=1 to remove without origin checks.
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

legacy_codex_root() {
  printf '%s/.codex/skills' "$HOME"
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

want_all_skills() {
  local s="${1:-}"
  [[ -z "$s" ]] && return 0
  case "${s,,}" in
    all|"\*"|-) return 0 ;;
    *) return 1 ;;
  esac
}

describe_path() {
  local path="$1"
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    log_debug "path does not exist: $path"
    return 1
  fi
  if [[ -L "$path" ]]; then
    local target
    target="$(readlink -f "$path" 2>/dev/null || readlink "$path" 2>/dev/null || echo '?')"
    log_info "found symlink: $path -> $target"
    if [[ -d "$path" ]]; then
      log_debug "symlink type: directory link"
    else
      log_debug "symlink type: file link"
    fi
  elif [[ -d "$path" ]]; then
    local nfiles
    nfiles="$(find "$path" -type f 2>/dev/null | wc -l | tr -d ' ')"
    log_info "found directory: $path (${nfiles} file(s) under tree)"
    if [[ -f "$path/SKILL.md" ]]; then
      log_debug "contains SKILL.md at root"
    fi
  else
    log_info "found file (unexpected for skill): $path"
  fi
  return 0
}

path_points_at_repo() {
  local path="$1"
  local skill="$2"
  local expected="$REPO_ROOT/$skill"
  local resolved="" entry

  if [[ ! -f "$expected/SKILL.md" ]]; then
    log_debug "repo has no $expected/SKILL.md; will remove by skill name only"
    return 0
  fi

  if [[ -L "$path" ]]; then
    resolved="$(readlink -f "$path" 2>/dev/null || true)"
    if [[ -n "$resolved" && "$resolved" == "$(readlink -f "$expected" 2>/dev/null || echo "$expected")" ]]; then
      log_debug "symlink target matches repo skill: $resolved"
      return 0
    fi
    log_warn "symlink target is not this repo (expected $expected, got ${resolved:-unknown})"
    return 1
  fi

  if [[ -d "$path" ]]; then
    if cmp -s "$path/SKILL.md" "$expected/SKILL.md" 2>/dev/null; then
      log_debug "directory SKILL.md matches repo for '$skill'"
      return 0
    fi
    for entry in "$path"/*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      if [[ -L "$entry" ]]; then
        resolved="$(readlink -f "$entry" 2>/dev/null || true)"
        if [[ "$resolved" == "$(readlink -f "$expected" 2>/dev/null || echo "$expected")" ]]; then
          log_debug "nested symlink under $path points at repo: $entry -> $resolved"
          return 0
        fi
      fi
    done
    if [[ -f "$path/SKILL.md" ]]; then
      log_warn "directory has SKILL.md but content differs from repo; allowing remove for repo skill '$skill'"
      return 0
    fi
    log_warn "directory does not look like skill '$skill' (no SKILL.md)"
    return 1
  fi

  return 1
}

remove_install_path() {
  local path="$1"
  local skill="$2"
  local force="${3:-0}"

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    log_info "nothing to remove at $path"
    return 2
  fi

  describe_path "$path" || true

  if [[ "$force" != "1" ]]; then
    if ! path_points_at_repo "$path" "$skill"; then
      log_warn "refusing to remove $path (not linked/copied from $REPO_ROOT/$skill)"
      log_warn "re-run with SKILL_UNINSTALL_FORCE=1 to delete anyway"
      return 3
    fi
  else
    log_warn "force mode: removing $path regardless of origin"
  fi

  if [[ -L "$path" ]]; then
    log_step "unlink symlink: $path"
    rm -f "$path"
    log_ok "removed symlink $path"
    return 0
  fi

  if [[ -d "$path" ]]; then
    log_step "remove directory tree: $path"
    rm -rf "$path"
    log_ok "removed directory $path"
    return 0
  fi

  log_step "remove file: $path"
  rm -f "$path"
  log_ok "removed file $path"
  return 0
}

uninstall_one() {
  local platform="$1"
  local skill="$2"
  local force="${SKILL_UNINSTALL_FORCE:-0}"
  local root dest legacy rc

  log_info "----- uninstall skill='$skill' platform='$platform' -----"
  log_debug "REPO_ROOT=$REPO_ROOT"
  log_debug "HOME=$HOME force=$force"

  if [[ ! -f "$REPO_ROOT/$skill/SKILL.md" ]]; then
    log_warn "skill '$skill' is not defined in this repo (missing $REPO_ROOT/$skill/SKILL.md)"
    log_warn "will still try to remove platform path named '$skill'"
  else
    log_debug "repo skill verified: $REPO_ROOT/$skill/SKILL.md"
  fi

  root="$(skills_dest_root "$platform")"
  dest="$root/$skill"
  log_info "primary destination: $dest"

  rc=0
  remove_install_path "$dest" "$skill" "$force" || rc=$?

  if [[ "$platform" == codex ]]; then
    legacy="$(legacy_codex_root)/$skill"
    log_info "legacy codex destination: $legacy"
    local legacy_rc=0
    remove_install_path "$legacy" "$skill" "$force" || legacy_rc=$?
    if [[ "$legacy_rc" -eq 0 ]]; then
      log_ok "legacy codex path cleaned"
    elif [[ "$legacy_rc" -eq 2 ]]; then
      log_debug "legacy codex path already absent"
    else
      rc="$legacy_rc"
    fi
    if [[ -d "$(legacy_codex_root)" ]]; then
      local leftover
      leftover="$(find "$(legacy_codex_root)" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
      log_debug "legacy root $(legacy_codex_root) has $leftover entr(y/ies) remaining"
      if [[ "$leftover" == "0" ]]; then
        log_step "remove empty legacy root: $(legacy_codex_root)"
        rmdir "$(legacy_codex_root)" 2>/dev/null && log_ok "removed empty $(legacy_codex_root)" || log_debug "could not rmdir legacy root (not empty or busy)"
      fi
    fi
  fi

  case "$rc" in
    0) log_ok "uninstall completed for '$skill' on $platform" ;;
    2) log_info "skill '$skill' was not installed under $platform (no-op)" ;;
    3) log_warn "uninstall skipped for '$skill' on $platform (safety)" ;;
    *) log_error "uninstall failed for '$skill' on $platform (rc=$rc)" ;;
  esac
  return "$rc"
}

main() {
  local platform skill
  local removed=0 skipped=0 absent=0 failed=0
  local names=() rc

  if [[ $# -ge 1 ]] && is_help_arg "$1"; then
    usage
    exit 0
  fi
  if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
  fi

  log_info "starting $SCRIPT_NAME (pid=$$ user=${USER:-?} host=$(hostname 2>/dev/null || echo ?))"
  log_info "REPO_ROOT=$REPO_ROOT"

  platform="$(normalize_platform "$1")"
  skill="${2:-}"
  log_info "normalized platform='$platform' skill_arg='${skill:-<all>}'"

  if want_all_skills "$skill"; then
    log_step "mode: uninstall all skills known to this repository"
    while IFS= read -r line; do
      [[ -n "$line" ]] && names+=("$line")
    done < <(list_repo_skills)
    if [[ ${#names[@]} -eq 0 ]]; then
      log_error "no skills found under $REPO_ROOT"
      exit 1
    fi
    log_info "skills to process (${#names[@]}): ${names[*]}"
    for skill in "${names[@]}"; do
      if uninstall_one "$platform" "$skill"; then
        ((removed++)) || true
      else
        rc=$?
        case "$rc" in
          2) ((absent++)) || true ;;
          3) ((skipped++)) || true ;;
          *) ((failed++)) || true ;;
        esac
      fi
    done
  else
    log_step "mode: uninstall single skill '$skill'"
    if uninstall_one "$platform" "$skill"; then
      removed=1
    else
      rc=$?
      case "$rc" in
        2) absent=1 ;;
        3) skipped=1 ;;
        *) failed=1 ;;
      esac
    fi
  fi

  log_info "===== summary ====="
  log_info "platform=$platform removed=$removed absent=$absent skipped=$skipped failed=$failed"

  if [[ "$failed" -gt 0 ]]; then
    exit 1
  fi
  if [[ "$skipped" -gt 0 ]]; then
    exit 2
  fi
  exit 0
}

main "$@"