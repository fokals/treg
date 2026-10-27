#!/usr/bin/env bash
# Checkout CLI pointed at the verification registry. Config and HOME stay in the run scratch
# directory, so ~/.treg/config.json is never read or written.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
STATE_FILE="${TREG_VERIFY_STATE_DIR:-/tmp/treg-verify}/state.env"

export PATH="${HOME}/.local/bin:${PATH}"

[ -f "$STATE_FILE" ] || { printf 'verify-treg: no server state at %s (server.sh start first)\n' "$STATE_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
. "$STATE_FILE"

export TREG_CONFIG="$SCRATCH/cli/config.json"
export HOME="$SCRATCH/home"
export TREG_VERIFY_BASE_URL="$URL"

mkdir -p "$SCRATCH/home" "$(dirname "$TREG_CONFIG")"
uv run --frozen --directory "$ROOT" python - <<'PY'
import json, os
from pathlib import Path
path = Path(os.environ["TREG_CONFIG"])
url = os.environ["TREG_VERIFY_BASE_URL"]
data = {}
if path.exists():
    data = json.loads(path.read_text(encoding="utf-8"))
if data.get("base_url") != url:
    data["base_url"] = url
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    path.chmod(0o600)
PY

exec uv run --frozen --directory "$ROOT" treg "$@"
