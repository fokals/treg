# treg verification map

This directory is the maintained source for verifying the user-facing behavior of treg. Read the index before driving the app, then use the matching feature file as the recipe.

## Baseline preconditions

- Launch the registry with `bash .agents/skills/verify-treg/scripts/server.sh start`.
- The default URL is `http://127.0.0.1:18795`. The database is a new sqlite file under `/tmp/treg-verify/runs/<run-id>/`.
- Run `bash .agents/skills/verify-treg/scripts/server.sh doctor` and require `ok verify-treg`, that URL, that database, and `openapi_title: treg`.
- Drive the CLI only through `bash .agents/skills/verify-treg/scripts/cli.sh`. It keeps the token in the run scratch directory.
- Never drive an instance that was not started by this verification run. Never start `./e2e-server.sh` on the same port.

## Driving conventions

- Start every recipe from the baseline state unless its preconditions say otherwise.
- Treat every command as literal. Keep quoted names and flags unchanged.
- The only substitution is `<run-id>`, the `RUN_ID=` line from `bash .agents/skills/verify-treg/scripts/server.sh state`.
- Prefer `treg --json ...` when the feature file says so. The JSON is the stable assertion. Human text is what a person sees; do not invent a second path and call it the same proof.
- A fresh server has an empty database. You do not restore rows by hand. `server.sh stop` drops the database.
- Do not remove proof artifacts during cleanup.

## Proof and skip reporting

- Capture the user action and the resulting state, not only the final screen.
- CLI proof includes the command, stdout, and exit code.
- Mutation proof includes a second read-only command that shows the stored value. A secret's second read shows the name and omits the value.
- Read-only proof includes a second read that shows a charge did not happen (`balance_micro` unchanged) when the feature says so.
- Record the feature ID and entry point in the evidence directory's `manifest.txt`.
- Report an unreachable path with the attempted command and the unmet precondition.
- Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with verify-treg` starts with `Preconditions:` and uses labeled bullets that pair each user action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only user paths, stable handles, required state, commands, and observable proof.

## Features

- [Sign in](./sign-in.md) covers email-code register-or-login, creating the first team, and reading the account back.
- [Search the catalog](./catalog-search.md) covers shelves, a matching search, opening one result, an empty search, and recently added tools.
- [Register your own tool](./own-tools.md) covers adding a secret, registering a tool, listing both, and keeping the secret value hidden.
- [Read the balance](./balance.md) covers the signup grant and the ledger line a new team starts with.
- [Send feedback](./feedback.md) covers submitting a note and reading it back.
