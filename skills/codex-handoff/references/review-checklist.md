# Commander review checklist

Do this after every `run` / `resume`, before committing.

1. **Read the report, then distrust it.**
   - Rerun the full acceptance suite locally with timeouts.
   - Also run what the sandbox could not: HTTP / port-binding tests, browser tests, network-dependent checks.
2. **Isolation.** Hash local runtime / data / config files before and after the suite. They must be identical, and no stray files may appear.
3. **Read the diff.**
   - `git diff --stat` first, then the critical hunks.
   - Read money / trading / write / delete paths line by line.
   - Check the failure branches: timeout, 429 / rate limit, partial success, invalid response. State must stay conservative: no double spend, nothing left untracked, no silent zero.
4. **Check deviations.** For each item under "Deviations" and "Unverified", decide whether it is acceptable. Watch especially for tests weakened to get around the sandbox.
5. **Second opinion when risky.** Run `codex-task.sh review --uncommitted --focus "..."` and triage the findings.
6. **Fix loop.** Put the findings in a fix brief, run `codex-task.sh resume`, then return to step 1.
7. **Commit.**
   - One block per commit, with a conventional prefix (`feat:` / `fix:` / `refactor:` / `test:`). Update the changelog if the project keeps one.
   - For public repos, scan the outgoing diff for secrets, hostnames, emails and wallet addresses before pushing.
8. **Deploy.** Only committed versions, and only on the user's word. Record the commit hash in the deploy log.
