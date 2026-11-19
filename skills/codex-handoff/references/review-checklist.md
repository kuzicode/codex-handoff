# Commander review checklist

Do this after every `run` / `resume`, before committing. While you review, don't edit Codex's block. The only exception is a one- or two-line obvious typo.

1. **Read the report, then distrust it.**
   - Rerun the full acceptance suite locally with timeouts.
   - Also run what the sandbox could not: HTTP / port-binding tests, browser tests, network-dependent checks.
2. **Isolation.** Hash local runtime / data / config files before and after the suite. They must be identical, and no stray files may appear.
3. **Read the diff.**
   - `git diff --stat` first, then the critical hunks.
   - Read money / trading / write / delete paths line by line.
   - Check the failure branches: timeout, 429 / rate limit, partial success, invalid response. State must stay conservative: no double spend, nothing left untracked, no silent zero.
4. **Check scope and deviations.**
   - Were the stop conditions respected?
   - Did any change land outside Scope, or in files marked "do not touch"?
   - Is each deviation and unverified item acceptable? Watch especially for tests weakened to get around the sandbox.
5. **Grade findings.**
   - **P0**: blocks merge. Wrong behaviour, data or money risk, a broken safety check, a test weakened to pass.
   - **P1**: must fix before commit. A real bug on a less critical path, a missing test for a changed failure branch, a scope violation.
   - **P2**: suggestion. Style, naming, minor simplification. Record it, don't loop on it.
   Only P0 / P1 go into the fix file.
6. **Second opinion when risky.** Run `codex-task.sh review --uncommitted --focus "..."`, then triage its findings with the same grades.
7. **Fix loop.** Run `codex-task.sh resume --brief fix.md --append-to handoff.md`, then return to step 1. After 3 rounds that still fail, stop and bring it to the user.
8. **Close out.**
   - Commit one block per commit, with a conventional prefix. Refactors go in a separate `refactor:` commit. Update the changelog if the project keeps one.
   - For public repos, scan the outgoing diff for secrets, hostnames, emails and wallet addresses before pushing.
   - Update the plan of record: a one-line outcome plus the commit hash. Add issue-log entries from Codex's "Issue candidates", and log tech debt from its "Out-of-scope findings".
9. **Deploy.** Only committed versions, and only on the user's word. Record the commit hash in the deploy log.
