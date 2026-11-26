#!/usr/bin/env bash
# Markdown → DOCX (cross-platform). See ../SKILL.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=discover-tools.sh
source "$SCRIPT_DIR/discover-tools.sh"

PANDOC_IS_WIN=0
TMP_FILES=()
cleanup() {
  if [[ ${#TMP_FILES[@]} -gt 0 ]]; then
    rm -f "${TMP_FILES[@]}"
  fi
}
trap cleanup EXIT

die() { echo "$*" >&2; exit 1; }

# Absolute path for a (possibly not yet existing) file.
abspath() {
  local p="$1" d
  case "$p" in
    /*) printf '%s\n' "$p" ;;
    *)
      d="$(cd "$(dirname "$p")" 2>/dev/null && pwd)" || die "directory not found for: $p"
      printf '%s/%s\n' "$d" "$(basename "$p")"
      ;;
  esac
}

# Path as the pandoc binary sees it (Windows pandoc.exe under WSL needs C:\... paths).
pandoc_path() {
  if [[ "$PANDOC_IS_WIN" == 1 ]]; then
    wslpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

setup_tools() {
  local need_filter="$1" p m

  p="$(find_pandoc)" || die "Pandoc not found. Run: $SCRIPT_DIR/discover-tools.sh"
  PANDOC="$p"
  export PANDOC
  if [[ "$PANDOC" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
    PANDOC_IS_WIN=1
  fi

  if [[ "$need_filter" == 1 ]]; then
    MERMAID_FILTER="$(find_mermaid_filter)" || die "mermaid-filter not found. npm i -g mermaid-filter or use --no-mermaid"
    export MERMAID_FILTER
    if [[ "$PANDOC_IS_WIN" == 1 && "$MERMAID_FILTER" != *.cmd && "$MERMAID_FILTER" != *.exe ]]; then
      echo "WARN: Windows pandoc.exe cannot run Linux mermaid-filter ($MERMAID_FILTER);" \
        "install pandoc inside WSL or set MERMAID_FILTER to a Windows mermaid-filter.cmd" >&2
    fi
    m="$(find_mmdc)"
    if [[ "$m" != npx:* ]]; then
      MERMAID_FILTER_CMD_MMDC="$m"
      export MERMAID_FILTER_CMD_MMDC
    fi
  fi
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

# Rewrite ```mermaid / ~~~mermaid fences (tolerating CRLF and trailing spaces)
# into {.mermaid width=.. scale=..} so mermaid-filter picks them up.
prep_mermaid() {
  local src="$1" dst="$2"
  local w="${MERMAID_FILTER_WIDTH:-2400}"
  local s="${MERMAID_FILTER_SCALE:-2.5}"
  awk -v w="$w" -v s="$s" '
    {
      line = $0
      cr = ""
      if (sub(/\r$/, "", line)) cr = "\r"
      fence = line
      if (sub(/[ \t]*mermaid[ \t]*$/, "", fence) && (fence ~ /^```+$/ || fence ~ /^~~~+$/)) {
        print fence "{.mermaid width=" w " scale=" s "}" cr
      } else {
        print $0
      }
    }
  ' "$src" >"$dst"
}

verify_docx() {
  local out="$1"
  [[ -f "$out" ]] || die "missing: $out"
  if command -v unzip >/dev/null 2>&1; then
    local xml n disp imgs
    xml="$(unzip -p "$out" word/document.xml 2>/dev/null || true)"
    # Each formula is exactly one <m:oMath> (display math additionally wraps it in <m:oMathPara>).
    n="$(printf '%s' "$xml" | grep -o '<m:oMath>' | wc -l | tr -d ' ')"
    disp="$(printf '%s' "$xml" | grep -o '<m:oMathPara>' | wc -l | tr -d ' ')"
    imgs="$(unzip -l "$out" 2>/dev/null | grep -c 'word/media/' || true)"
    echo "file: $out"
    echo "omml_blocks: $n (display: $disp)"
    echo "media_entries: $imgs"
  else
    echo "file: $out (install unzip for --verify details)"
  fi
}

convert_one() {
  local src="$1" out="$2" use_filter="$3"
  local dir base prep sep=":" refargs=() filterargs=()

  [[ -f "$src" ]] || die "missing: $src"
  src="$(abspath "$src")"
  dir="$(dirname "$src")"
  base="$(basename "$src" .md)"
  if [[ -z "$out" ]]; then
    out="${dir}/${base}.docx"
  else
    out="$(abspath "$out")"
  fi

  prep="$(mktemp "${TMPDIR:-/tmp}/md2docx.XXXXXX")"
  TMP_FILES+=("$prep")
  prep_mermaid "$src" "$prep"

  export MERMAID_FILTER_WIDTH="${MERMAID_FILTER_WIDTH:-2400}"
  export MERMAID_FILTER_SCALE="${MERMAID_FILTER_SCALE:-2.5}"
  export MERMAID_FILTER_FORMAT="${MERMAID_FILTER_FORMAT:-png}"
  export MERMAID_FILTER_BACKGROUND="${MERMAID_FILTER_BACKGROUND:-white}"
  export MERMAID_FILTER_LOC="${MERMAID_FILTER_LOC:-inline}"

  local from="${PANDOC_FROM:-markdown+tex_math_dollars}"
  if [[ -n "${PANDOC_REFERENCE_DOC:-}" ]]; then
    [[ -f "$PANDOC_REFERENCE_DOC" ]] || die "PANDOC_REFERENCE_DOC not found: $PANDOC_REFERENCE_DOC"
    refargs=(--reference-doc="$(pandoc_path "$(abspath "$PANDOC_REFERENCE_DOC")")")
  fi
  if [[ "$use_filter" == 1 ]]; then
    filterargs=(--filter="$(pandoc_path "$MERMAID_FILTER")")
  fi
  # pandoc separates --resource-path entries with ';' on Windows
  [[ "$PANDOC_IS_WIN" == 1 ]] && sep=";"

  echo "==> $out"
  (
    cd "$dir"
    "$PANDOC" "$(pandoc_path "$prep")" \
      --from="$from" \
      --to=docx \
      ${filterargs[@]+"${filterargs[@]}"} \
      --resource-path=".${sep}.." \
      --standalone \
      ${refargs[@]+"${refargs[@]}"} \
      -o "$(pandoc_path "$out")"
  )
  verify_docx "$out"
}

NO_MERMAID=0
BATCH_DIR=""
BATCH_GLOB="*.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --verify) shift; verify_docx "${1:?docx}"; exit 0 ;;
    --no-mermaid) NO_MERMAID=1; shift ;;
    --batch)
      shift
      BATCH_DIR="${1:?DIR}"
      BATCH_GLOB="${2:-*.md}"
      break
      ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) break ;;
  esac
done

USE_FILTER=$((1 - NO_MERMAID))
setup_tools "$USE_FILTER"

if [[ -n "$BATCH_DIR" ]]; then
  [[ -d "$BATCH_DIR" ]] || die "not a directory: $BATCH_DIR"
  shopt -s nullglob
  count=0
  for f in "$BATCH_DIR"/$BATCH_GLOB; do
    [[ -f "$f" ]] || continue
    convert_one "$f" "" "$USE_FILTER"
    count=$((count + 1))
  done
  [[ "$count" -gt 0 ]] || die "no files matched $BATCH_DIR/$BATCH_GLOB"
  exit 0
fi

[[ $# -ge 1 ]] || { usage >&2; exit 1; }
convert_one "$1" "${2:-}" "$USE_FILTER"
