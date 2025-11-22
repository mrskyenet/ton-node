#!/usr/bin/env bash
set -euo pipefail

# project-dump.sh (max-info defaults)
# - Dumps all text files (binary files auto-skipped) into one Markdown.
# - Shows full project tree by default.
# - Central hardcoded ignore list below.
#
# Usage:
#   ./project-dump.sh
#   ./project-dump.sh --root . --out project-dump.md
#   ./project-dump.sh --tree-depth 8          # cap tree depth if you want
#   ./project-dump.sh --respect-gitignore=true# switch to git ls-files

# ---------------- hardcoded ignores (edit here) ----------------
# Directories to skip (affects both tree and find):
IGNORE_DIRS=(
  .git node_modules dist build .next .cache .venv .terraform .idea .vscode .turbo coverage
  .husky .pnpm-store .gradle .yarn .npm out tmp/.cache
)

# Optional extra file globs to skip (comma-separated, shell-style):
# e.g. "**/*.map,**/*.lock"
EXTRA_EXCLUDES=""

# ---------------- defaults (max info) ----------------
root="."
out="dump.md"
include_globs=""
exclude_globs="$EXTRA_EXCLUDES"
respect_gitignore="false"     # ignore .gitignore so we see everything
max_bytes_per_file="0"        # 0 = no per-file truncation
max_total_bytes="0"           # 0 = unlimited total
show_hidden="true"            # include dotfiles/dirs
include_tree="true"
tree_depth="0"                # 0 = unlimited
tree_ignore=""                # auto-built from IGNORE_DIRS if empty

# ---------------- arg parsing ----------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --include) include_globs="$2"; shift 2;;
    --exclude) exclude_globs="${exclude_globs:+$exclude_globs,}$2"; shift 2;;
    --respect-gitignore=*) respect_gitignore="${1#*=}"; shift 1;;
    --max-bytes-per-file) max_bytes_per_file="$2"; shift 2;;
    --max-total-bytes) max_total_bytes="$2"; shift 2;;
    --show-hidden=*) show_hidden="${1#*=}"; shift 1;;
    --include-tree=*) include_tree="${1#*=}"; shift 1;;
    --tree-depth) tree_depth="$2"; shift 2;;
    --tree-ignore) tree_ignore="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

root="$(cd "$root" && pwd -P)"
out="$(realpath -m "$out")"
mkdir -p "$(dirname "$out")"

# ---------------- helpers ----------------
join_by() { local IFS="$1"; shift; echo "$*"; }

# Build a pipe-separated tree ignore pattern from IGNORE_DIRS if not provided:
if [[ -z "$tree_ignore" && ${#IGNORE_DIRS[@]} -gt 0 ]]; then
  tree_ignore="$(join_by '|' "${IGNORE_DIRS[@]}")"
fi

match_any_glob() {
  local path="$1"; local csv="$2"
  [[ -z "$csv" ]] && return 0
  IFS=',' read -r -a arr <<< "$csv"
  for g in "${arr[@]}"; do
    g="${g#"${g%%[![:space:]]*}"}"; g="${g%"${g##*[![:space:]]}"}"
    [[ -z "$g" ]] && continue
    case "$path" in
      $g) return 0;;
      */$g) return 0;;
    esac
  done
  return 1
}

exclude_match() {
  local path="$1"; local csv="$2"
  IFS=',' read -r -a arr <<< "$csv"
  for g in "${arr[@]}"; do
    g="${g#"${g%%[![:space:]]*}"}"; g="${g%"${g##*[![:space:]]}"}"
    [[ -z "$g" ]] && continue
    case "$path" in
      $g) return 0;;
      */$g) return 0;;
    esac
  done
  return 1
}

ext_to_lang() {
  local f="$1"
  case "${f##*.}" in
    js|mjs|cjs) echo "javascript";;
    ts) echo "typescript";;
    tsx) echo "tsx";;
    jsx) echo "jsx";;
    json) echo "json";;
    json5) echo "json5";;
    yml|yaml) echo "yaml";;
    md) echo "markdown";;
    sh|bash|zsh) echo "bash";;
    ps1) echo "powershell";;
    py) echo "python";;
    rb) echo "ruby";;
    php) echo "php";;
    go) echo "go";;
    rs) echo "rust";;
    java) echo "java";;
    cs) echo "csharp";;
    c) echo "c";;
    h) echo "c";;
    cpp|cc|cxx|hpp|hxx) echo "cpp";;
    css|scss|less) echo "css";;
    html|htm) echo "html";;
    sql) echo "sql";;
    lua) echo "lua";;
    kt|kts) echo "kotlin";;
    swift) echo "swift";;
    toml) echo "toml";;
    ini|conf|cfg|env) echo "ini";;
    *) echo "";;
  esac
}

is_text_file() {
  local f="$1"
  if command -v file >/dev/null 2>&1; then
    local enc; enc=$(file -b --mime-encoding -- "$f" 2>/dev/null || true)
    [[ "$enc" != "binary" ]] && return 0 || return 1
  else
    if grep -Iq . -- "$f"; then return 0; else return 1; fi
  fi
}

# ---------------- file list ----------------
mapfile -t files < <(
  if [[ "$respect_gitignore" == "true" ]] && git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    (git -C "$root" ls-files; git -C "$root" ls-files -o --exclude-standard) \
      | sed 's#^#'"$root/"'#' | sort -u
  else
    if (( ${#IGNORE_DIRS[@]} > 0 )); then
      NAME_CLAUSE=()
      for d in "${IGNORE_DIRS[@]}"; do
        [[ ${#NAME_CLAUSE[@]} -gt 0 ]] && NAME_CLAUSE+=("-o")
        NAME_CLAUSE+=("-name" "$d")
      done
      if [[ "$show_hidden" == "true" ]]; then
        find "$root" \( -type d \( "${NAME_CLAUSE[@]}" \) -prune \) -o -type f -print 2>/dev/null | sort
      else
        find "$root" -not -path '*/.*' \( -type d \( "${NAME_CLAUSE[@]}" \) -prune \) -o -type f -print 2>/dev/null | sort
      fi
    else
      if [[ "$show_hidden" == "true" ]]; then
        find "$root" -type f -print 2>/dev/null | sort
      else
        find "$root" -type f -not -path '*/.*' -print 2>/dev/null | sort
      fi
    fi
  fi
)

# Apply include/exclude globs
filtered=()
for f in "${files[@]}"; do
  rel="${f#$root/}"
  if [[ -n "$include_globs" ]]; then
    match_any_glob "$rel" "$include_globs" || continue
  fi
  if [[ -n "$exclude_globs" ]]; then
    exclude_match "$rel" "$exclude_globs" && continue
  fi
  filtered+=("$f")
done

# ---------------- header ----------------
{
  echo "# Project Dump"
  echo
  echo "- Root: \`$root\`"
  echo "- Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  echo "- Files included: ${#filtered[@]}"
  echo "- Per-file cap: ${max_bytes_per_file} bytes (0 = unlimited)"
  if [[ "$max_total_bytes" != "0" ]]; then
    echo "- Total cap: ${max_total_bytes} bytes"
  fi
} > "$out"

# ---------------- tree section ----------------
if [[ "$include_tree" == "true" ]]; then
  {
    echo
    echo "## Project Structure"
    echo
    echo '```text'
  } >> "$out"

  if command -v tree >/dev/null 2>&1; then
    # unlimited depth if tree_depth==0
    if [[ "$show_hidden" == "true" ]]; then
      if [[ "$tree_depth" == "0" ]]; then
        tree -a ${tree_ignore:+-I "$tree_ignore"} "$root" >> "$out" 2>/dev/null || true
      else
        tree -a -L "$tree_depth" ${tree_ignore:+-I "$tree_ignore"} "$root" >> "$out" 2>/dev/null || true
      fi
    else
      if [[ "$tree_depth" == "0" ]]; then
        tree ${tree_ignore:+-I "$tree_ignore"} "$root" >> "$out" 2>/dev/null || true
      else
        tree -L "$tree_depth" ${tree_ignore:+-I "$tree_ignore"} "$root" >> "$out" 2>/dev/null || true
      fi
    fi
  else
    (
      cd "$root"
      if [[ "$show_hidden" == "true" ]]; then
        find . -print
      else
        find . -not -path '*/.*' -print
      fi
    ) | sed 's#^\./##' \
      | awk -F'/' '{indent=NF-1; pad=""; for(i=0;i<indent;i++){pad=pad "    "} print pad $NF}' >> "$out"
    echo "[note] install \`tree\` for prettier output." >> "$out"
  fi

  echo '```' >> "$out"
  echo >> "$out"
fi

# ---------------- TOC ----------------
{
  echo "## Table of Contents"
  echo
  idx=1
  for f in "${filtered[@]}"; do
    rel="${f#$root/}"
    echo " ${idx}. [\`$rel\`](#file-${idx})"
    ((idx++))
  done
  echo
  echo "---"
} >> "$out"

# ---------------- dump contents ----------------
total_written=0
idx=1
for f in "${filtered[@]}"; do
  rel="${f#$root/}"

  if ! is_text_file "$f"; then
    continue
  fi

  size=$(wc -c < "$f" | tr -d ' ')
  to_read="$size"
  truncated="false"

  # Per-file cap (0 = unlimited)
  if (( max_bytes_per_file > 0 )) && (( size > max_bytes_per_file )); then
    to_read="$max_bytes_per_file"
    truncated="true"
  fi

  # Total cap (0 = unlimited)
  if (( max_total_bytes > 0 )); then
    remaining=$(( max_total_bytes - total_written ))
    if (( remaining <= 0 )); then
      echo -e "\n> **Reached total byte cap (${max_total_bytes}). Stopping.**" >> "$out"
      break
    fi
    if (( to_read > remaining )); then
      to_read="$remaining"
      truncated="true"
    fi
  fi

  lang="$(ext_to_lang "$f")"

  {
    echo
    echo "### ${idx}. \`$rel\`"
    echo "<a id=\"file-${idx}\"></a>"
    echo
    echo "- Size: ${size} bytes"
    if [[ "$truncated" == "true" ]]; then
      echo "- Note: Truncated to ${to_read} bytes"
    fi
    echo
    echo '```'"$lang"
    head -c "$to_read" -- "$f" || true
    echo
    echo '```'
    echo
    echo '---'
  } >> "$out"

  total_written=$(( total_written + to_read ))
  ((idx++))
done

echo "Wrote: $out"
