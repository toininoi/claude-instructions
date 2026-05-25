#!/usr/bin/env bash
# Record an asciinema cast + agg-rendered GIF of the README demo:
# an interactive `agent-instructions` install driven by expect(1).
#
# Outputs:
#   docs/demo.cast
#   docs/demo.gif
#
# Usage:
#   ./scripts/demo/record_demo.sh             # record cast + gif
#   ./scripts/demo/record_demo.sh --no-gif    # skip agg conversion
#
# Requires: asciinema, agg, expect. The CLI is built fresh from this
# checkout via `pnpm build:cli` so the demo always reflects current behavior.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCENARIO="$REPO_ROOT/scripts/demo/scenario.exp"
DOCS_DIR="$REPO_ROOT/docs"
mkdir -p "$DOCS_DIR"

COLS=100
ROWS=30
THEME="${AGG_THEME:-monokai}"
FONT_SIZE="${AGG_FONT_SIZE:-14}"
FPS_CAP="${AGG_FPS_CAP:-60}"
SPEED="${AGG_SPEED:-1.0}"

WANT_GIF=1
for arg in "$@"; do
    case "$arg" in
        --no-gif) WANT_GIF=0 ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

for bin in expect asciinema; do
    command -v "$bin" >/dev/null || {
        echo "missing required tool: $bin" >&2
        exit 1
    }
done

echo "==> Building CLI"
(cd "$REPO_ROOT" && pnpm build:cli >/dev/null)

# Avoid /tmp — macOS resolves it to /private/tmp via realpath, which leaks
# into the CLI's "Installed N commands to /private/tmp/…" line.
WORKSPACE_ROOT="${HOME:?HOME must be set}/.agent-instructions-demo-workspace"
rm -rf "$WORKSPACE_ROOT"
mkdir -p "$WORKSPACE_ROOT/my-project"
trap 'rm -rf "$WORKSPACE_ROOT"' EXIT

(
    cd "$WORKSPACE_ROOT/my-project"
    git init -q
    git commit --allow-empty -q -m 'Initial commit'
)

CAST="$DOCS_DIR/demo.cast"
GIF="$DOCS_DIR/demo.gif"

echo "==> Recording cast (interactive install via expect)"
asciinema rec \
    --overwrite \
    --window-size "${COLS}x${ROWS}" \
    --idle-time-limit 1.5 \
    --command "cd '$WORKSPACE_ROOT/my-project' && expect '$SCENARIO' '$REPO_ROOT/bin/cli.js'" \
    "$CAST"
echo "    wrote $CAST"

if [[ "$WANT_GIF" -eq 1 ]]; then
    if command -v agg >/dev/null 2>&1; then
        agg --theme "$THEME" --font-size "$FONT_SIZE" --fps-cap "$FPS_CAP" --speed "$SPEED" "$CAST" "$GIF"
        echo "    wrote $GIF"
    else
        echo "    agg not installed - skipping gif (brew install agg)" >&2
    fi
fi

echo "==> Done."
