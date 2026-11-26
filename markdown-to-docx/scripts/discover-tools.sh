#!/usr/bin/env bash
# Print detected Pandoc / mermaid-filter / mmdc (no hardcoded install paths).
# Can also be sourced (md-to-docx.sh does) to reuse find_pandoc / find_mermaid_filter / find_mmdc.

is_exe() {
  local f="$1"
  [[ -n "$f" && (-x "$f" || -f "$f") ]]
}

find_pandoc() {
  if is_exe "${PANDOC:-}"; then
    echo "${PANDOC}"
    return 0
  fi
  if command -v pandoc >/dev/null 2>&1; then
    command -v pandoc
    return 0
  fi
  # Git for Windows / WSL: common install names on mounted drives
  local letter pf
  for letter in c d e f; do
    for pf in "/mnt/${letter}/Program Files/Pandoc/pandoc.exe" \
              "/mnt/${letter}/Program Files (x86)/Pandoc/pandoc.exe"; do
      if [[ -f "$pf" ]]; then
        echo "$pf"
        return 0
      fi
    done
  done
  return 1
}

find_mermaid_filter() {
  if [[ -n "${MERMAID_FILTER:-}" ]]; then
    echo "${MERMAID_FILTER}"
    return 0
  fi
  local n f
  for n in mermaid-filter mermaid-filter.cmd; do
    if command -v "$n" >/dev/null 2>&1; then
      command -v "$n"
      return 0
    fi
  done
  # npm global prefix (platform-specific, from npm itself)
  if command -v npm >/dev/null 2>&1; then
    local prefix
    prefix="$(npm prefix -g 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
      for f in "$prefix/bin/mermaid-filter" "$prefix/bin/mermaid-filter.cmd" "$prefix/mermaid-filter.cmd"; do
        if [[ -f "$f" ]]; then
          echo "$f"
          return 0
        fi
      done
    fi
  fi
  # Adjacent to this repo's node_modules if user did local npm i
  local skill_root
  skill_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  for f in "$skill_root/node_modules/.bin/mermaid-filter" "$skill_root/node_modules/.bin/mermaid-filter.cmd"; do
    if [[ -f "$f" ]]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

find_mmdc() {
  if [[ -n "${MERMAID_FILTER_CMD_MMDC:-}" ]]; then
    echo "${MERMAID_FILTER_CMD_MMDC}"
    return 0
  fi
  if command -v mmdc >/dev/null 2>&1; then
    command -v mmdc
    return 0
  fi
  local filter f dir
  filter="$(find_mermaid_filter 2>/dev/null || true)"
  if [[ -n "$filter" ]]; then
    dir="$(dirname "$filter")"
    for f in "$dir/mmdc" "$dir/mmdc.cmd" "$dir/../node_modules/.bin/mmdc" "$dir/../node_modules/.bin/mmdc.cmd"; do
      if [[ -f "$f" ]]; then
        echo "$f"
        return 0
      fi
    done
  fi
  # Last resort: npx shim path (filter may invoke npx itself)
  echo "npx:@mermaid-js/mermaid-cli"
  return 0
}

main() {
  local p f m
  echo "# discover-tools.sh — set these only if md-to-docx.sh cannot auto-detect"
  if p="$(find_pandoc)"; then
    echo "export PANDOC=$(printf '%q' "$p")"
  else
    echo "# PANDOC: not found — install from https://pandoc.org"
  fi
  if f="$(find_mermaid_filter)"; then
    echo "export MERMAID_FILTER=$(printf '%q' "$f")"
  else
    echo "# MERMAID_FILTER: not found — npm install -g mermaid-filter"
  fi
  m="$(find_mmdc)"
  if [[ "$m" == npx:* ]]; then
    echo "# MERMAID_FILTER_CMD_MMDC: install @mermaid-js/mermaid-cli or rely on filter's bundled mmdc"
  else
    echo "export MERMAID_FILTER_CMD_MMDC=$(printf '%q' "$m")"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  main "$@"
fi
