# Send feedback

Send feedback lets a person file a short note for the active team and read that same note back by its id.

## Sub-features

- `feedback-submit` accepts a category and a message and returns an id.
- `feedback-get` returns that message unchanged.

## How to get to it (user POV)

- Run `treg feedback submit friction "<message>"`.
- Run `treg feedback get <id>` with the id from the receipt.

## Driving it with verify-treg

Preconditions:

- `bash .agents/skills/verify-treg/scripts/server.sh doctor` prints `ok verify-treg`.
- The sign-in recipe has been driven for this run, with active team `verify-team`.

- **Submit.** Run `bash .agents/skills/verify-treg/scripts/cli.sh feedback submit friction "The empty catalog search should say that nothing matched."`. Exit code `0`. JSON `status` is `received` and `feedback_id` is a positive integer.
- **Read it back.** Run `bash .agents/skills/verify-treg/scripts/cli.sh feedback get <that id>`. Exit code `0`. JSON `feedback_id` matches, `category` is `friction`, `status` is `received`, and `message` is `The empty catalog search should say that nothing matched.`
- **Proof.** Save both stdout files and exit codes under the directory from `bash .agents/skills/verify-treg/scripts/server.sh evidence feedback`.

## Gotchas

- Feedback requires a team. Submit before `org create` and the command fails. Create the team first.
- The message must be 1 to 2000 characters after trimming. This recipe uses one fixed sentence so the read-back can compare it exactly.
- The category is one of `quality`, `pricing`, `friction`, `other`.
- The command does not spend balance. Do not attach a call id you did not actually make.
