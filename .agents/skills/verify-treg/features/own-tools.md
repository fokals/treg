# Register your own tool

Register your own tool lets a person store a credential, attach it to a tool, and list both later. The list shows the secret's name and never its value.

## Sub-features

- `own-secret` stores a named secret.
- `own-register` registers a tool bound to that secret.
- `own-list` shows the tool and the secret from a second read.
- `own-hidden` keeps the secret value out of both lists.

## How to get to it (user POV)

- Run `treg secret add verify-key --value <value> --kind env`.
- Run `treg tool add verify-tool --base-url https://example.com --secret <id>`.
- Run `treg secret ls` and `treg tool ls`.

## Driving it with verify-treg

Preconditions:

- `bash .agents/skills/verify-treg/scripts/server.sh doctor` prints `ok verify-treg`.
- The sign-in recipe has been driven for this run, with active team `verify-team`.
- No secret is named `verify-key` and no tool is named `verify-tool`.

- **Add the secret.** Run `bash .agents/skills/verify-treg/scripts/cli.sh secret add verify-key --value "verify-secret-value" --kind env`. Exit code `0`. JSON has `name` `verify-key`, `kind` `env`, and an integer `id`. It has no `value` field.
- **Register the tool.** Run `bash .agents/skills/verify-treg/scripts/cli.sh tool add verify-tool --base-url https://example.com --secret <that id>`. Exit code `0`. JSON `name` is `verify-tool`, `base_url` is `https://example.com`, and `bindings` contains that secret id. The secret string does not appear.
- **List the secret.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json secret ls`. Exit code `0`. An object named `verify-key` is present. No object has a `value` field. The string `verify-secret-value` does not appear.
- **List the tool.** Run `bash .agents/skills/verify-treg/scripts/cli.sh --json tool ls`. Exit code `0`. An object named `verify-tool` has `base_url` `https://example.com`. The string `verify-secret-value` does not appear.
- **Reject a loopback URL.** Run `bash .agents/skills/verify-treg/scripts/cli.sh tool add loop-tool --base-url http://127.0.0.1:9 --secret <that id>`. Exit code `1`. The output says `base_url must be a public http(s) address`. `treg --json tool ls` still has no `loop-tool`.
- **Proof.** Save each stdout and exit code under the directory from `bash .agents/skills/verify-treg/scripts/server.sh evidence own-tools`. Before `server.sh stop`, confirm the run's sqlite file does not contain the bytes `verify-secret-value`.

## Gotchas

- `http://127.0.0.1` and other loopback or private base URLs are refused. `https://example.com` is a public address and does not contact that host during registration.
- The secret id in `tool add` is the integer from `secret add`, not the name, on this command.
- Deleting the secret while the tool binds it is refused. Delete the tool first if you need a clean team. A fresh server is the usual reset.
- A second `tool add` of `verify-tool` in the same team conflicts. The name is the proof's fixture; do not reuse it in another recipe on the same server.
