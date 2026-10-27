# Search the catalog

Search lets a person list the catalog shelves, find endpoints by what they do, open one result, and tell a miss from a recently added tool. Search does not spend the team's balance.

## Sub-features

- `search-shelves` lists platforms.
- `search-match` finds endpoints for a task description.
- `search-get` opens one result and shows the same id.
- `search-empty` reports a query that matches nothing.
- `search-new` lists tools added in the default recent window.

## How to get to it (user POV)

- Run `treg catalog`.
- Run `treg catalog search "instagram profile"`.
- Run `treg catalog get <endpoint-id>` with an id from the search.
- Run `treg catalog search "zzverify-nomatch-9f39"`.
- Run `treg catalog search --new`.

## Driving it with verify-treg

Preconditions:

- `bash .agents/skills/verify-treg/scripts/server.sh doctor` prints `ok verify-treg`.
- The sign-in recipe has been driven for this run: `treg --json whoami` shows `team` `verify-team` and `role` `owner`.
- No priced catalog call has been made in this run.

- **Record the balance.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json balance`. Exit code `0`. Remember `balance_micro`.
- **Shelves.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json catalog`. Exit code `0`. JSON `platforms` is a non-empty list. Each item has a non-empty `slug` and a non-empty `category`.
- **Matching search.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json catalog search "instagram profile" --limit 5`. Exit code `0`. JSON `query` is `instagram profile`, `engine` is `agent`, `total` is a positive integer, and `results` is a non-empty list no longer than 5. At least one result has an `id` that contains both `instagram` and `profile`.
- **Open a result.** Choose the first of those ids. Run `bash .agents/skills/verify-treg/scripts/cli.sh --json catalog get <that id>`. Exit code `0`. JSON `endpoint.id` equals that id, `endpoint.method` is non-empty, `endpoint.summary` is non-empty, and `endpoint.cost` is present.
- **Empty search.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json catalog search "zzverify-nomatch-9f39" --limit 5`. Exit code `0`. JSON `query` is `zzverify-nomatch-9f39`, `total` is `0`, and `results` is `[]`.
- **Recently added.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json catalog search --new --limit 5`. Exit code `0`. JSON `added_within_days` is `30`, `sort` is `newest`, and `results` is a non-empty list. Every result has a non-empty `added`.
- **Balance unchanged.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json balance` again. Exit code `0`. `balance_micro` equals the value recorded above.
- **Proof.** Save doctor output, `whoami` JSON, both balance JSON files, and each catalog stdout plus its exit code under the directory from `bash .agents/skills/verify-treg/scripts/server.sh evidence catalog-search`. `manifest.txt` names feature `catalog-search` and entry `treg catalog search "instagram profile"`.

## Gotchas

- Do not assert `total`, a platform count, or a specific endpoint id. The catalog changes. Pick the id from this run's search output.
- An empty search exits `0`. Without `--json` it prints `nothing matches "zzverify-nomatch-9f39"`. A non-zero exit or a non-empty `results` array fails the empty check.
- `--json` is a global flag. `treg --json catalog search ...` is the form this recipe uses.
- `--new` with no number means 30 days, newest first, and the words are optional. `--limit` caps the page; it does not cap `total`.
- These commands must not be followed by `treg call`. A call can charge the signup grant and then the balance check fails for a different reason.
- Search does not need a platform key. A miss is not a missing `./.env`.
- `treg catalog get` of an unknown id exits non-zero and prints `no endpoint`. Use an id from the search you just saved.
