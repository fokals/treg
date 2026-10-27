#!/usr/bin/env bash
# Isolated treg registry for verification. Same contract as ./e2e-server.sh: default port 18795,
# a private sqlite file, kill the listener on that port, ready when uvicorn logs
# "Application startup complete", fresh Fernet key. This launcher does not source ./.env and does
# not use ./e2e.db — those belong to e2e_check.py.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
STATE_DIR="${TREG_VERIFY_STATE_DIR:-/tmp/treg-verify}"
STATE_FILE="$STATE_DIR/state.env"
PORT="${TREG_VERIFY_PORT:-18795}"

export PATH="${HOME}/.local/bin:${PATH}"

die() { printf 'verify-treg: %s\n' "$*" >&2; exit 1; }

need_uv() {
  command -v uv >/dev/null 2>&1 || die "uv is not on PATH (need >= 0.12; https://docs.astral.sh/uv/)"
}

load_state() {
  # shellcheck disable=SC1090
  [ -f "$STATE_FILE" ] && . "$STATE_FILE"
}

listener_pids() {
  lsof -ti :"${1:-$PORT}" -sTCP:LISTEN 2>/dev/null || true
}

environ_has() {
  local pid="$1" key="$2" want="$3" line
  [ -r "/proc/$pid/environ" ] || return 1
  line="$(tr '\0' '\n' < "/proc/$pid/environ" | awk -F= -v k="$key" '$1==k {print substr($0, length(k)+2); exit}')"
  [ "$line" = "$want" ]
}

our_listener() {
  local pid
  load_state
  [ -n "${RUN_ID:-}" ] || return 1
  for pid in $(listener_pids "${PORT_SAVED:-${PORT:-18795}}"); do
    if environ_has "$pid" TREG_VERIFY_MARKER "$RUN_ID"; then
      printf '%s\n' "$pid"
      return 0
    fi
  done
  return 1
}

cmd_doctor() {
  local pid url title cli_ver cwd db_ok=0
  load_state
  [ -n "${RUN_ID:-}" ] || die "no verification server state at $STATE_FILE"
  pid="$(our_listener || true)"
  [ -n "$pid" ] || die "port ${PORT_SAVED:-$PORT} is not held by marker $RUN_ID"
  url="${URL:-http://127.0.0.1:${PORT_SAVED:-$PORT}}"
  title="$(curl -fsS "$url/openapi.json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["title"])')" \
    || die "openapi.json did not answer at $url"
  [ "$title" = "treg" ] || die "openapi title is $title, expected treg"
  environ_has "$pid" TREG_DATABASE_URL "$DATABASE_URL" || die "listener database does not match $DATABASE_URL"
  [ -f "$DATABASE" ] && db_ok=1
  [ "$db_ok" = 1 ] || die "sqlite file missing: $DATABASE"
  grep -q "Application startup complete" "$LOG" || die "log has no Application startup complete: $LOG"
  curl -fsS -o /dev/null "$url/" || die "GET / did not succeed at $url"
  cwd="$(readlink "/proc/$pid/cwd" || true)"
  cli_ver="$(uv run --frozen --directory "$ROOT" treg version)"
  printf 'ok verify-treg\n'
  printf 'url: %s\n' "$url"
  printf 'run_id: %s\n' "$RUN_ID"
  printf 'port: %s\n' "${PORT_SAVED:-$PORT}"
  printf 'pid: %s\n' "$pid"
  printf 'cwd: %s\n' "$cwd"
  printf 'database: %s\n' "$DATABASE"
  printf 'log: %s\n' "$LOG"
  printf 'openapi_title: %s\n' "$title"
  printf 'cli: %s\n' "$cli_ver"
  printf 'marker: %s\n' "$RUN_ID"
}

kill_marked() {
  local pid="$1" pgid
  [ -n "$pid" ] || return 0
  kill -0 "$pid" 2>/dev/null || return 0
  pgid="$(ps -o pgid= -p "$pid" | tr -d ' ')"
  if [ -n "$pgid" ] && [ "$pgid" != "$(ps -o pgid= -p $$ | tr -d ' ')" ]; then
    kill -- "-$pgid" 2>/dev/null || kill "$pid" 2>/dev/null || true
  else
    kill "$pid" 2>/dev/null || true
  fi
}

cmd_stop() {
  local pid mine
  load_state
  mine="$(our_listener || true)"
  if [ -n "${STARTER:-}" ]; then
    kill_marked "$STARTER"
  fi
  if [ -n "$mine" ]; then
    kill_marked "$mine"
  fi
  if [ -z "$mine" ] && { [ -z "${STARTER:-}" ] || ! kill -0 "${STARTER:-}" 2>/dev/null; }; then
    echo "wasn't running"
  else
    :
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      our_listener >/dev/null 2>&1 || break
      sleep 0.3
    done
    if our_listener >/dev/null 2>&1; then
      pid="$(our_listener)"
      kill -9 "$pid" 2>/dev/null || true
      sleep 0.5
    fi
    our_listener >/dev/null 2>&1 && die "listener still holding port ${PORT_SAVED:-$PORT}"
    echo "stopped ($mine)"
  fi
  if [ -n "${SCRATCH:-}" ] && [ -d "$SCRATCH" ]; then
    rm -rf "$SCRATCH"
  fi
  rm -f "$STATE_FILE"
}

cmd_evidence() {
  local feature="${1:-}" dir
  [ -n "$feature" ] || die "usage: server.sh evidence <feature-id>"
  load_state
  [ -n "${RUN_ID:-}" ] || die "start the server before opening an evidence directory"
  case "$feature" in
    *[!a-z0-9-]*) die "feature id must be lowercase words and hyphens" ;;
  esac
  dir="$SKILL_DIR/evidence/$feature/$RUN_ID"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

cmd_start() {
  local run scratch db log secret session pid other
  need_uv
  if our_listener >/dev/null 2>&1; then
    cmd_doctor
    return 0
  fi
  other="$(listener_pids "$PORT")"
  if [ -n "$other" ]; then
    die "port $PORT is in use by pid(s) $other and they are not this verification run. Stop that process yourself; this script only kills a server it started."
  fi
  # A stale state file with no listener is scratch from a dead run.
  if [ -f "$STATE_FILE" ]; then
    load_state
    [ -n "${SCRATCH:-}" ] && rm -rf "$SCRATCH"
    rm -f "$STATE_FILE"
  fi
  # Lowercase stamp: the registry stores emails in lowercase, and sign-in compares the
  # address it sent with the address whoami returns.
  run="$(date -u +%Y%m%dt%H%M%Sz)-$$"
  scratch="$STATE_DIR/runs/$run"
  db="$scratch/treg.db"
  log="$scratch/server.log"
  mkdir -p "$scratch/home" "$scratch/cli"
  secret="$(uv run --frozen --directory "$ROOT" python -m treg keygen)"
  session="$(uv run --frozen --directory "$ROOT" python -c 'import secrets; print(secrets.token_hex(24))')"
  PYTHONUNBUFFERED=1 \
  PORT="$PORT" \
  TREG_VERIFY_MARKER="$run" \
  TREG_DATABASE_URL="sqlite+aiosqlite:///$db" \
  TREG_SECRET_KEY="$secret" \
  TREG_SESSION_SECRET="$session" \
  TREG_EMAIL_DEV_MODE=true \
  TREG_FRONTEND_DEV=false \
  TREG_PUBLIC_URL="http://127.0.0.1:$PORT" \
  TREG_RESEND_API_KEY= \
  TREG_POSTHOG_KEY= \
  TREG_PLATFORM_PROVIDERS= \
    setsid uv run --frozen --directory "$ROOT" python -m treg >"$log" 2>&1 < /dev/null &
  local starter=$!
  # Persist enough for stop/doctor while we wait. PORT_SAVED is the port we bound, not a later override.
  cat >"$STATE_FILE" <<EOF
RUN_ID=$run
PORT_SAVED=$PORT
URL=http://127.0.0.1:$PORT
SCRATCH=$scratch
DATABASE=$db
DATABASE_URL=sqlite+aiosqlite:///$db
LOG=$log
STARTER=$starter
EOF
  local ready=0
  for _ in $(seq 1 120); do
    if grep -q "Application startup complete" "$log" 2>/dev/null; then
      ready=1
      break
    fi
    if ! kill -0 "$starter" 2>/dev/null; then
      tail -40 "$log" >&2 || true
      cmd_stop || true
      die "server process exited before it was ready"
    fi
    sleep 1
  done
  if [ "$ready" != 1 ]; then
    tail -40 "$log" >&2 || true
    cmd_stop || true
    die "did not start within 120s"
  fi
  pid=""
  for _ in $(seq 1 10); do
    pid="$(our_listener || true)"
    [ -n "$pid" ] && break
    sleep 0.3
  done
  if [ -z "$pid" ]; then
    tail -40 "$log" >&2 || true
    cmd_stop || true
    die "startup logged ready but port $PORT has no marked listener"
  fi
  printf 'PID=%s\n' "$pid" >>"$STATE_FILE"
  echo "verify-treg up on http://127.0.0.1:$PORT (run $run, db $db, log $log)"
}

cmd_state() {
  [ -f "$STATE_FILE" ] || die "no state at $STATE_FILE"
  cat "$STATE_FILE"
}

usage() {
  cat <<EOF
usage: server.sh <start|doctor|stop|state|logs|evidence <feature-id>>

  start     boot an isolated registry on port ${PORT} (TREG_VERIFY_PORT)
  doctor    read-only: our listener, openapi title treg, sqlite path, ready log
  stop      kill the marked listener and delete its scratch dir; evidence stays
  state     print RUN_ID, URL, DATABASE, LOG
  logs      follow the server log
  evidence  print (and create) the evidence directory for one feature id
EOF
}

case "${1:-}" in
  start) cmd_start ;;
  doctor) need_uv; cmd_doctor ;;
  stop) cmd_stop ;;
  state) cmd_state ;;
  logs)
    load_state
    [ -n "${LOG:-}" ] || die "no log yet"
    exec tail -f "$LOG"
    ;;
  evidence) cmd_evidence "${2:-}" ;;
  *) usage; exit 2 ;;
esac
