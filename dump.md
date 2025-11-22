# Project Dump

- Root: `/home/skye/bitsler-github-repos/mrskyenet/ton-node`
- Generated: 2025-11-22 19:07:55 UTC
- Files included: 10
- Per-file cap: 0 bytes (0 = unlimited)

## Project Structure

```text
/home/skye/bitsler-github-repos/mrskyenet/ton-node
├── .dockerignore
├── .github
│   └── workflows
│       └── docker-image.yml
├── .gitignore
├── DOCKERHUB
├── Dockerfile
├── README.md
├── VERSION
├── dump.md
├── dump.sh
└── files
    ├── _docker-compose.env
    └── _docker-compose.yml

4 directories, 11 files
```

## Table of Contents

 1. [`.dockerignore`](#file-1)
 2. [`.github/workflows/docker-image.yml`](#file-2)
 3. [`.gitignore`](#file-3)
 4. [`DOCKERHUB`](#file-4)
 5. [`Dockerfile`](#file-5)
 6. [`README.md`](#file-6)
 7. [`VERSION`](#file-7)
 8. [`dump.sh`](#file-8)
 9. [`files/_docker-compose.env`](#file-9)
 10. [`files/_docker-compose.yml`](#file-10)

---

### 1. `.dockerignore`
<a id="file-1"></a>

- Size: 45 bytes

```
.git/
.github/
files*
README.md
.dockerignore
```

---

### 2. `.github/workflows/docker-image.yml`
<a id="file-2"></a>

- Size: 909 bytes

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.HUB_USERNAME }}
          password: ${{ secrets.HUB_TOKEN }}
      - name: Build the Docker image
        run: |
          VERSION=$(cat VERSION)
          DOCKERHUB=$(cat DOCKERHUB)
          docker build . \
            --build-arg VERSION=$VERSION \
            --tag $DOCKERHUB:$VERSION \
            --tag $DOCKERHUB:latest

      - name: Push Docker image
        run: |
          VERSION=$(cat VERSION)
          DOCKERHUB=$(cat DOCKERHUB)
          docker push $DOCKERHUB:$VERSION
          docker push $DOCKERHUB:latest
```

---

### 3. `.gitignore`
<a id="file-3"></a>

- Size: 5 bytes

```
.git/
```

---

### 4. `DOCKERHUB`
<a id="file-4"></a>

- Size: 18 bytes

```
mrskyenet/ton-node
```

---

### 5. `Dockerfile`
<a id="file-5"></a>

- Size: 1882 bytes

```
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ---- Build-time config (feel free to tweak) ----
ARG MODE=liteserver       # validator|liteserver|collator|...
ARG NETWORK=mainnet       # mainnet|testnet
ARG TELEMETRY=false       # true|false (false => pass -t)
ARG IGNORE_REQS=true      # true|false (true => pass -i)
ARG DUMP=true             # true|false (true => pass -d)

# Env vars used by install.sh (from docs)
ENV ARCHIVE_TTL=2592000 \
    STATE_TTL=0 \
    ADD_SHARD="" \
    ARCHIVE_BLOCKS="" \
    COLLATE_SHARD="0:8000000000000000"

# ---- Base packages ----
RUN apt-get update && \
    apt-get install -y \
      curl wget git ca-certificates \
      python3 python3-pip \
      tmux jq sudo \
      build-essential pkg-config libssl-dev \
      && rm -rf /var/lib/apt/lists/*

# ---- Non-root operator (as MyTonCtrl expects) ----
RUN useradd -m -s /bin/bash ton && \
    echo "ton ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ton
WORKDIR /home/ton

# ---- Fetch installer script ----
RUN wget https://raw.githubusercontent.com/ton-blockchain/mytonctrl/master/scripts/install.sh && \
    chmod +x install.sh

# ---- Run installer non-interactively during build ----
RUN set -eux; \
    INSTALL_FLAGS=""; \
    if [ "$DUMP" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -d"; fi; \
    if [ -n "$MODE" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -m $MODE"; fi; \
    if [ -n "$NETWORK" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -n $NETWORK"; fi; \
    if [ "$TELEMETRY" = "false" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -t"; fi; \
    if [ "$IGNORE_REQS" = "true" ]; then INSTALL_FLAGS="$INSTALL_FLAGS -i"; fi; \
    sudo bash ./install.sh $INSTALL_FLAGS

# Optionally expose some common ports (tune for your setup)
EXPOSE 30303 32768 4924 4925

# Default: drop you into a shell so you can run `mytonctrl`
CMD ["bash"]

```

---

### 6. `README.md`
<a id="file-6"></a>

- Size: 12 bytes

```markdown
# ton-node

```

---

### 7. `VERSION`
<a id="file-7"></a>

- Size: 10 bytes

```
v2025.11

```

---

### 8. `dump.sh`
<a id="file-8"></a>

- Size: 8611 bytes

```bash
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

```

---

### 9. `files/_docker-compose.env`
<a id="file-9"></a>

- Size: 72 bytes

```ini
BASE=/path
TON_NODE_IMAGE=mrskyenet/ton-node
TON_NODE_VERSION=v2025.11
```

---

### 10. `files/_docker-compose.yml`
<a id="file-10"></a>

- Size: 600 bytes

```yaml
services:
  ton-node:
    container_name: ton-node
    image: ${TON_NODE_IMAGE}:${TON_NODE_VERSION}
    restart: unless-stopped
    network_mode: host
    volumes:
      - ${BASE}/data:/var/ton-work

  ton-http-api:
    image: toncenter/ton-http-api:latest
    container_name: ton-http-api
    restart: unless-stopped
    depends_on:
      - ton-node
    ports:
      - "8081:8081"
    volumes:
      - /mnt/hdd/ton-work:/var/ton-work:ro
    environment:
      TON_LITESERVER_CONFIG: /var/ton-work/db/liteserver.config.json
      TON_HTTP_HOST: 0.0.0.0
      TON_HTTP_PORT: 8081
```

---
