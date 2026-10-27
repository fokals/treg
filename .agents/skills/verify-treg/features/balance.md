# Read the balance

Read the balance lets a person see the new team's signup credit and the ledger line that granted it, before any catalog call spends it.

## Sub-features

- `balance-read` shows the integer balance for the active team.
- `balance-grant` shows the signup grant as a promotional block and a ledger line.

## How to get to it (user POV)

- Run `treg balance`.
- Run `treg balance --json` for the integer micro-USD fields.

## Driving it with verify-treg

Preconditions:

- `bash .agents/skills/verify-treg/scripts/server.sh doctor` prints `ok verify-treg`.
- The sign-in recipe has been driven for this run, with active team `verify-team`.
- No catalog call and no other spend has run on this server.

- **Read the balance.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json balance`. Exit code `0`. `balance_micro` is `1000000`. `holds` is `[]`.
- **See the grant.** The same JSON has a `blocks` entry with `kind` `promotional`, `amount_micro` `1000000`, and `remaining_micro` `1000000`. `entries.items` contains one object with `kind` `grant`, `amount_micro` `1000000`, and `meta.source` `signup`.
- **Proof.** Save the JSON and exit code under the directory from `bash .agents/skills/verify-treg/scripts/server.sh evidence balance`.

## Gotchas

- Assert `balance_micro`, not `balance_usd`. The integer is the balance.
- The grant is created with the first team, not at `treg login`. Reading the balance before `org create` has no team to bill.
- The verify-treg launcher does not set `TREG_PROMO_GRANT_MICRO`. A server started with that variable at `0` will not show `1000000`, and this recipe then fails. Do not change the launcher to make the number match.
- `treg call` on a priced endpoint can reduce the balance. Run this recipe before any call.
