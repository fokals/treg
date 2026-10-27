---
name: verify-treg
description: "Drive the treg (tools-registry) CLI against an isolated local registry and prove a user-facing flow. Use when checking catalog search, sign-in, balance, own tools, or feedback on a local server, or when a change needs a scripted CLI proof before it is called done."
metadata:
  internal: true
---

# Verify treg

treg's user-facing surface for this skill is the `treg` CLI talking to a local registry. The registry is the product's server (`python -m treg`). The dashboard and the browser suite are a second surface: this skill does not start Vite and does not run Playwright.

The launcher follows the same isolation rules as `./e2e-server.sh`: default port **18795**, a private sqlite file, kill by the listening port (never by process name), and ready only after the log contains `Application startup complete`. It does not source `./.env` and it does not use `./e2e.db`. Those two belong to `e2e_check.py` (see [Failure-capture harness](#failure-capture-harness)).

Scripts live in `.agents/skills/verify-treg/scripts/`. `.claude/skills` is a symlink to `.agents/skills`, so the same files are reached from either path. Run them from the repo root.

## Launch

Preconditions: `uv` >= 0.12 on `PATH` (or `$HOME/.local/bin`), and `uv sync --frozen --group dev` already done in this checkout so `python -m treg` can import the server.

```bash
bash .agents/skills/verify-treg/scripts/server.sh start
```

What it does:

- Refuses to start when something else is already listening on the port. It never kills a process it did not start.
- If a server this script started is still healthy, it prints `server.sh doctor` and leaves that process alone.
- Creates `/tmp/treg-verify/runs/<run-id>/` with a new sqlite file, a new Fernet key (`python -m treg keygen`), and `TREG_EMAIL_DEV_MODE=true`. Email codes are returned to the CLI only when dev mode is on **and** the database URL contains `sqlite`.
- Sets `TREG_FRONTEND_DEV=false`, an empty `TREG_RESEND_API_KEY`, and an empty `TREG_PLATFORM_PROVIDERS`. No provider key is loaded. Catalog reads do not call upstreams.
- Runs `uv run --frozen --directory <repo> python -m treg`, which applies migrations before it listens.
- Waits until the log contains `Application startup complete` and the listener's environment contains `TREG_VERIFY_MARKER=<run-id>`.

Ready looks like:

```text
verify-treg up on http://127.0.0.1:18795 (run <run-id>, db /tmp/treg-verify/runs/<run-id>/treg.db, log ...)
```

`http://127.0.0.1:18795/openapi.json` then has `"title": "treg"`, and `GET /` returns the landing page. A database file that exists before that log line is not ready.

Override the port with `TREG_VERIFY_PORT` only when 18795 is taken by a server you must keep. `e2e_check.py` is hardcoded to 18795, so a non-default port cannot run that script.

State for the run is `/tmp/treg-verify/state.env` (`server.sh state`).

## Doctor

Run this first whenever a drive looks wrong. It is read-only.

```bash
bash .agents/skills/verify-treg/scripts/server.sh doctor
```

Exit 0 prints:

- `ok verify-treg`
- `url` `http://127.0.0.1:18795` (or `TREG_VERIFY_PORT`)
- `run_id` matching `TREG_VERIFY_MARKER` on the listener
- `database` the sqlite path in that process's `TREG_DATABASE_URL`
- `openapi_title: treg`
- `cli: treg <version>` from `treg version` in this checkout
- the listener `pid` and `cwd` (the repo root)

Any other listener, a missing ready line, or a title other than `treg` is a failure. Do not drive that process.

## Drive

Point the CLI at the run with `cli.sh`. It sets `TREG_CONFIG` and `HOME` inside the run scratch directory, so `~/.treg/config.json` is never used. The first invocation writes `base_url` to that config from the server URL. `treg login` reads `base_url` from the config file; `TREG_URL` alone does not sign you in.

```bash
bash .agents/skills/verify-treg/scripts/server.sh state
bash .agents/skills/verify-treg/scripts/cli.sh --help
bash .agents/skills/verify-treg/scripts/login-email.sh "verify-<run-id>@example.com"
```

`login-email.sh` runs `treg login --email`, reads the `(dev) your code is:` line, submits that code, and redacts it in its own stdout. The token stays in the scratch config.

Global `--json` (anywhere in the argv, conventionally first) makes table commands print the response JSON. Exit status is the CLI's status.

The feature map is the source of which commands to run. Read `features/README.md`, then one feature file. Drive that file's bullets in order. A path the file lists and you did not run is not verified.

## Evidence

Proof artifacts go under `.agents/skills/verify-treg/evidence/<feature-id>/<run-id>/`. Create the directory with:

```bash
bash .agents/skills/verify-treg/scripts/server.sh evidence <feature-id>
```

That path is inside the skill tree, not under `/tmp/treg-verify`. `server.sh stop` deletes the scratch database, the CLI config (including the token), and the state file. It does not delete `evidence/`.

For every proof:

- Exercise the CLI command a user runs. Do not insert rows with SQL, and do not call a test-only route.
- Save the command, stdout, and exit code. Save the next user-facing read that shows the result (a second `whoami`, `catalog get`, `secret ls`, `feedback get`).
- For a read, also show the side effect that must **not** happen. Catalog search leaves `balance_micro` unchanged.
- For a secret, `secret ls` and `tool ls` must not contain the secret string. The scratch sqlite file must not contain those plaintext bytes either. Check that before `server.sh stop`; the file is removed with the scratch dir.
- Do not store `treg org create` stdout. That JSON includes the new token. Store `treg --json whoami` and `treg --json org ls` instead.
- Record `feature` and the entry command in `manifest.txt` in the evidence directory.
- A skipped entry point stays skipped. Do not mark it verified because a different command returned similar data.

`e2e_check.py` is not a stand-in for these proofs. It spends against real provider keys and reads `./e2e.db`.

## Cleanup

```bash
bash .agents/skills/verify-treg/scripts/server.sh stop
```

This kills the process group of the server this run started, and only when its environment still has this run's marker (or it is the starter pid recorded at launch). It then deletes `/tmp/treg-verify/runs/<run-id>/` and `/tmp/treg-verify/state.env`.

After cleanup:

- `lsof -ti :18795 -sTCP:LISTEN` prints nothing (when you used the default port).
- The evidence directory from [Evidence](#evidence) is still there.

Run `stop` after a failed launch too, so a half-started process is not left on the port. `stop` when nothing of ours is running prints `wasn't running` and exits 0.

## Helpers

| Script | Role |
|---|---|
| `scripts/server.sh start` | Boot the isolated registry. Prints the URL and run id. |
| `scripts/server.sh doctor` | Read-only health check. Exit 0 means drive it. |
| `scripts/server.sh state` | Print `RUN_ID`, `URL`, `DATABASE`, `LOG`. |
| `scripts/server.sh evidence <feature-id>` | Create and print the evidence directory. |
| `scripts/server.sh logs` | Follow the server log. |
| `scripts/server.sh stop` | Kill this run and delete its scratch. Evidence stays. |
| `scripts/cli.sh <treg args>` | `treg` against this run, sandboxed config. |
| `scripts/login-email.sh <email>` | Non-interactive `treg login --email` using the dev code. |

All three scripts are executable. Invoke them with `bash` as shown so the path is obvious.

## Failure-capture harness

`./e2e-server.sh` and `e2e_check.py` are the repo's existing check that a real provider error is stored with the platform key redacted. They are not this skill's launcher:

- `./e2e-server.sh` sources `./.env` (absent from a clean checkout) and pins the database to `./e2e.db`.
- `e2e_check.py` calls real upstreams on the platform keys in that file, reads `./e2e.db`, and uses `http://127.0.0.1:18795`. It spends a small amount.
- It does not set `TREG_EMAIL_DEV_MODE`, so `login-email.sh` will not see a dev code on that process.
- Do not point `e2e_check.py` at a verify-treg server. The database path will not match, and there is no platform key.

To run it: stop any verify-treg server on 18795, have a private `./.env`, run `./e2e-server.sh`, then `uv run --frozen python e2e_check.py`, then `./e2e-server.sh stop`. Do not commit `.env`, `e2e.db`, or response bodies from that run into `evidence/`.

## Maintenance

When a command, a ready line, or a feature's observable result changes, update this skill and the feature file in the same change. Use `/maintain-verification-skill` to keep the map aligned with the app.
