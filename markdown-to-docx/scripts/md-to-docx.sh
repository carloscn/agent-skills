#!/usr/bin/env bash
# Markdown → DOCX (cross-platform). See ../SKILL.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=discover-tools.sh
source_discover() {
  local need_filter="${1:-1}"
  # Inline discovery (same logic as discover-tools, no hardcoded paths)
  is_exe() { [[ -n "${1:-}" && (-x "$1" || -f "$1") ]]; }

  resolve_pandoc() {
    is_exe "${PANDOC:-}" && return 0
    command -v pandoc >/dev/null 2>&1 && PANDOC="$(command -v pandoc)" && return 0
    local letter pf
    for letter in c d e f; do
      for pf in "/mnt/${letter}/Program Files/Pandoc/pandoc.exe" \
                "/mnt/${letter}/Program Files (x86)/Pandoc/pandoc.exe"; do
        if [[ -f "$pf" ]]; then PANDOC="$pf"; return 0; fi
      done
    done
    return 1
  }

  resolve_filter() {
    [[ -n "${MERMAID_FILTER:-}" ]] && return 0
    local n prefix f skill_root
    for n in mermaid-filter mermaid-filter.cmd; do
      command -v "$n" >/dev/null 2>&1 && MERMAID_FILTER="$(command -v "$n")" && return 0
    done
    if command -v npm >/dev/null 2>&1; then
      prefix="$(npm prefix -g 2>/dev/null || true)"
      if [[ -n "$prefix" ]]; then
        for f in "$prefix/bin/mermaid-filter" "$prefix/bin/mermaid-filter.cmd"; do
          [[ -f "$f" ]] && MERMAID_FILTER="$f" && return 0
        done
      fi
    fi
    skill_root="$(cd "$SCRIPT_DIR/.." && pwd)"
    for f in "$skill_root/node_modules/.bin/mermaid-filter" "$skill_root/node_modules/.bin/mermaid-filter.cmd"; do
      [[ -f "$f" ]] && MERMAID_FILTER="$f" && return 0
    done
    return 1
  }

  resolve_mmdc() {
    [[ -n "${MERMAID_FILTER_CMD_MMDC:-}" ]] && return 0
    command -v mmdc >/dev/null 2>&1 && MERMAID_FILTER_CMD_MMDC="$(command -v mmdc)" && return 0
    if [[ -n "${MERMAID_FILTER:-}" ]]; then
      local dir="$(_dirname "$MERMAID_FILTER")"
      local f
      for f in "$dir/mmdc" "$dir/mmdc.cmd" "$dir/../node_modules/.bin/mmdc" "$dir/../node_modules/.bin/mmdc.cmd"; do
        if [[ -f "$f" ]]; then MERMAID_FILTER_CMD_MMDC="$f"; return 0; fi
      done
    fi
    return 0
  }

  _dirname() {
    dirname "$1"
  }

  resolve_pandoc || { echo "Pandoc not found. Run: $SCRIPT_DIR/discover-tools.sh" >&2; exit 1; }
  if [[ "$need_filter" == 1 ]]; then
    resolve_filter || { echo "mermaid-filter not found. npm i -g mermaid-filter or use --no-mermaid" >&2; exit 1; }
    resolve_mmdc
  fi
  export PANDOC
  [[ -n "${MERMAID_FILTER:-}" ]] && export MERMAID_FILTER
  [[ -n "${MERMAID_FILTER_CMD_MMDC:-}" ]] && export MERMAID_FILTER_CMD_MMDC
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") INPUT.md [OUTPUT.docx]
  $(basename "$0") --batch DIR [GLOB]
  $(basename "$0") --verify FILE.docx
  $(basename "$0") --no-mermaid INPUT.md [OUTPUT.docx]

Environment (optional overrides):
  PANDOC  MERMAID_FILTER  MERMAID_FILTER_CMD_MMDC
  MERMAID_FILTER_WIDTH  MERMAID_FILTER_SCALE  MERMAID_FILTER_FORMAT
  PANDOC_FROM  PANDOC_REFERENCE_DOC
EOF
}

prep_mermaid() {
  local src="$1" dst="$2"
  local w="${MERMAID_FILTER_WIDTH:-2400}"
  local s="${MERMAID_FILTER_SCALE:-2.5}"
  if grep -q '^```mermaid$' "$src"; then
    sed 's/^```mermaid$/```{.mermaid width='"${w}"' scale='"${s}"'}/' "$src" >"$dst"
  else
    cp "$src" "$dst"
  fi
}

verify_docx() {
  local out="$1"
  [[ -f "$out" ]] || { echo "missing: $out" >&2; exit 1; }
  if command -v unzip >/dev/null 2>&1; then
    local n imgs
    n="$(unzip -p "$out" word/document.xml 2>/dev/null | grep -o 'm:oMath' | wc -l || true)"
    imgs="$(unzip -l "$out" 2>/dev/null | grep -c 'word/media/' || true)"
    echo "file: $out"
    echo "omml_blocks: $n"
    echo "media_entries: $imgs"
  else
    echo "file: $out (install unzip for --verify details)"
  fi
}

convert_one() {
  local src="$1" out="$2" use_filter="$3"
  local dir base prep refargs=() filterargs=()

  [[ -f "$src" ]] || { echo "missing: $src" >&2; exit 1; }
  dir="$(cd "$(dirname "$src")" && pwd)"
  base="$(basename "$src" .md)"
  prep="$(mktemp "${TMPDIR:-/tmp}/md2docx.XXXXXX.md")"
  trap 'rm -f "$prep"' RETURN

  prep_mermaid "$src" "$prep"
  [[ -z "$out" ]] && out="${dir}/${base}.docx"

  export MERMAID_FILTER_WIDTH="${MERMAID_FILTER_WIDTH:-2400}"
  export MERMAID_FILTER_SCALE="${MERMAID_FILTER_SCALE:-2.5}"
  export MERMAID_FILTER_FORMAT="${MERMAID_FILTER_FORMAT:-png}"
  export MERMAID_FILTER_BACKGROUND="${MERMAID_FILTER_BACKGROUND:-white}"
  export MERMAID_FILTER_LOC="${MERMAID_FILTER_LOC:-inline}"

  local from="${PANDOC_FROM:-markdown+tex_math_dollars}"
  [[ -n "${PANDOC_REFERENCE_DOC:-}" && -f "$PANDOC_REFERENCE_DOC" ]] && refargs=(--reference-doc="$PANDOC_REFERENCE_DOC")
  [[ "$use_filter" == 1 ]] && filterargs=(--filter="$MERMAID_FILTER")

  echo "==> $out"
  (
    cd "$dir"
    "$PANDOC" "$prep" \
      --from="$from" \
      --to=docx \
      "${filterargs[@]}" \
      --resource-path=".:.." \
      --standalone \
      "${refargs[@]}" \
      -o "$out"
  )
  verify_docx "$out"
}

NO_MERMAID=0
USE_FILTER=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --verify) shift; verify_docx "${1:?docx}"; exit 0 ;;
    --no-mermaid) NO_MERMAID=1; shift ;;
    --batch)
      shift
      bdir="${1:?DIR}"
      glob="${2:-*.md}"
      source_discover "$((1 - NO_MERMAID))"
      USE_FILTER=$((1 - NO_MERMAID))
      shopt -s nullglob
      for f in "$bdir"/$glob; do
        [[ -f "$f" ]] || continue
        convert_one "$f" "" "$USE_FILTER"
      done
      exit 0
      ;;
    *) break ;;
  esac
done

src="${1:?INPUT.md}"
out="${2:-}"
USE_FILTER=$((1 - NO_MERMAID))
if [[ "$USE_FILTER" -eq 1 ]]; then
  source_discover 1
else
  source_discover 0
fi
convert_one "$src" "$out" "$USE_FILTER"