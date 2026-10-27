# Sign in

Sign in lets a person prove an email address, land with no team yet, create a team, and see that account and team from a second command.

## Sub-features

- `sign-in-email` registers or signs in with an email code.
- `sign-in-team` creates the first team and makes it active.
- `sign-in-whoami` reads the account, team, role, and registry back.

## How to get to it (user POV)

- Run `treg login --email <email>` and enter the 6-digit code.
- Run `treg login` to finish in the browser instead of the terminal.
- Run `treg org create "Verify Team"` after the first sign-in.
- Run `treg whoami` or `treg` with no arguments to see who is active.

## Driving it with verify-treg

Preconditions:

- `bash .agents/skills/verify-treg/scripts/server.sh doctor` prints `ok verify-treg`.
- The scratch config has no token yet (a server started by `server.sh start` and not signed in).

- **Email code.** Sign in as this run. Run `bash .agents/skills/verify-treg/scripts/login-email.sh "verify-<run-id>@example.com"`. Exit code `0`. Stdout contains `Logged in as verify-<run-id>@example.com` and `Active org: None`. The dev code is shown as `******`.
- **Create the team.** Create the team this map uses. Run `bash .agents/skills/verify-treg/scripts/cli.sh org create "Verify Team"`. Exit code `0`. Do not archive this stdout. A second command must show the team.
- **Read the account.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json whoami`. Exit code `0`. JSON `email` is `verify-<run-id>@example.com`, `team` is `verify-team`, `role` is `owner`, and `registry` is the doctor URL.
- **Read the team list.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json org ls`. Exit code `0`. The list contains one object whose `slug` is `verify-team`, `name` is `Verify Team`, `role` is `owner`, and `active` is true.
- **Proof.** Save doctor output, the redacted login stdout, `whoami` JSON, and `org ls` JSON under the evidence directory from `bash .agents/skills/verify-treg/scripts/server.sh evidence sign-in`. Do not save `org create` stdout.

## Gotchas

- A brand-new account has no team. `Active org: None` after login is the expected state, not a failed login. Catalog and balance commands that need a team come after `org create`.
- `treg login` with no `--email` opens a browser and polls for about three minutes. This harness does not drive that door. Do not report the browser door as verified.
- `treg org create` prints a new token in its JSON. Archiving that file publishes a live credential for this server. Prove the team with `whoami` and `org ls`.
- `login-email.sh` only works against the verify-treg server. `./e2e-server.sh` does not turn on email dev mode, so it will not print a code.
- The onboarding question (`New here?`) is asked only on a terminal. The helper is not a terminal, so it does not appear. If you run `treg login --email` yourself in a terminal, answer `n` or the process starts a different setup than this recipe.
- Use the run id in the email. The registry stores the address in lowercase. The run id is already lowercase, so `whoami` returns the same string you passed. Reusing one address on a server that still has the account is a second login, not a fresh registration, and a tight retry can be rate-limited.
