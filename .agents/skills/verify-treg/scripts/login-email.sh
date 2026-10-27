#!/usr/bin/env bash
# Drive `treg login --email` against the verification server. The server returns the one-time
# code in the CLI output (TREG_EMAIL_DEV_MODE on sqlite). This feeds that code back to the prompt.
# Stdout redacts the code. The saved token stays in the run's TREG_CONFIG.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
email="${1:-}"
[ -n "$email" ] || { printf 'usage: login-email.sh <email>\n' >&2; exit 2; }

export VERIFY_TREG_CLI="$SCRIPT_DIR/cli.sh"
export VERIFY_TREG_EMAIL="$email"

exec python3 - <<'PY'
import os, re, subprocess, sys

email = os.environ["VERIFY_TREG_EMAIL"]
cli = os.environ["VERIFY_TREG_CLI"]
proc = subprocess.Popen(
    [cli, "login", "--email", email],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True,
)
buf = []
code = None
assert proc.stdout is not None and proc.stdin is not None
while True:
    chunk = proc.stdout.read(1)
    if chunk == "":
        break
    buf.append(chunk)
    if code is None:
        match = re.search(r"\(dev\) your code is: (\d{6})", "".join(buf))
        if match:
            code = match.group(1)
            proc.stdin.write(code + "\n")
            proc.stdin.close()
try:
    rc = proc.wait(timeout=60)
except subprocess.TimeoutExpired:
    proc.kill()
    rc = proc.wait()
    sys.stderr.write("verify-treg: login timed out\n")
text = "".join(buf)
if code:
    text = text.replace(code, "******")
sys.stdout.write(text)
if not text.endswith("\n"):
    sys.stdout.write("\n")
if code is None:
    sys.stderr.write("verify-treg: no dev code in login output\n")
    sys.exit(1)
sys.exit(rc)
PY
