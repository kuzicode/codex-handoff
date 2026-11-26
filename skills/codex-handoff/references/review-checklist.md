# Commander review checklist

Do this after every `run` / `resume`, before committing. While you review, don't edit Codex's block. The only exception is a one- or two-line obvious typo.

1. **Read the report, then distrust it.**
   - Rerun the acceptance suite locally, plus the **full cross-module regression suite** that Codex skipped in its fast inner-loop.
   - Run everything the sandbox could not: production build, HTTP / port-binding tests, browser tests, network checks, repo health / lint checks.
2. **Isolation.** Hash local runtime / data / config files before and after the suite. They must be identical, and no stray files may appear.
3. **Read the diff & audit new risk surfaces.**
   - `git diff --stat` first, then the critical hunks.
   - Read money / trading / auth / write / delete paths line by line.
   - Inventory every **newly added or modified state field, lock/gate, queue, backoff, cache, clock comparison, or schema column**, and check:
     - **Failure branches**: timeout, 429 / rate limit, 5xx, partial success, invalid response. State must stay conservative (no double spend, nothing left untracked, no silent zero).
     - **Blast radius**: does a new lock/backoff block healthy sibling operations or starve other accounts/tenants via shared queues?
     - **Clock & cache purity**: are remote/venue timestamps kept separate from local lifecycle/grace clocks? Can transient lag samples poison a durable fallback cache?
4. **Check scope and deviations.**
   - Were the stop conditions and file-length caps respected?
   - Did any change land outside Scope, or in files marked "do not touch"?
   - Is each deviation and unverified item acceptable? Watch especially for tests weakened to get around the sandbox.
5. **Grade findings & apply the closure cutoff.**
   - **P0**: blocks merge. Wrong behaviour, data or money risk, mis-closing live state, unprotected exposure, a broken safety check, a test weakened to pass.
   - **P1**: must fix before commit. A real bug on a less critical path, cross-entity starvation, a missing test for a changed failure branch, a scope violation.
   - **P2**: suggestion. Style, naming, minor simplification, or low-impact telemetry edge case. Record it, don't loop on it.
   - **Known-limit cutoff**: only P0 / P1 go into the fix file. Multi-fault edge combinations with bounded, recoverable degradation (e.g. a 1-round delay under simultaneous cold-start + upstream outage) should be escalated as "fix vs. log as known limit" instead of looping automatically.
6. **Second opinion when risky.**
   - Run `codex-task.sh review --uncommitted --focus "..."` (enforced read-only), then triage its findings with the same grades. It is safe to run before `resume`: resume follows the handoff's bound thread.
   - Build `--focus` from the risk surfaces inventoried in Step 3 using **neutral engineering phrasing** (e.g. "timestamp comparison, queue scoping, fallback caching, retry weight limits" — avoid exploit/security-attack phrasing that can trip automated content filters).
7. **Fix loop, patch-stacking guard & closure.**
   - Run `codex-task.sh resume --brief fix.md --append-to handoff.md`, then return to step 1.
   - **Hard cap of 2 fix rounds**: if it still fails after 2 rounds, or Codex hits a stop condition, stop and bring it to the user.
   - **Patch-stacking reset**: if a fix round shows that a mechanism introduced in an earlier round needs structural rework (e.g. relocating a lock twice or patching around drifted assumptions), stop and consider redesigning or starting a fresh `run` thread with consolidated invariants instead of stacking patches on a long `resume` thread.
   - **Small final convergence**: after a user-approved, surgical final fix (e.g. <15 lines with direct regression tests), verify locally and close out rather than starting another open-ended review cycle.
8. **Close out.**
   - Commit one block per commit, with a conventional prefix. Refactors go in a separate `refactor:` commit. Update the changelog if the project keeps one.
   - For public repos, scan the outgoing diff for secrets, hostnames, emails and wallet addresses before pushing.
   - Update the plan of record: a one-line outcome plus the commit hash. Add issue-log entries from Codex's "Issue candidates", and log tech debt from its "Out-of-scope findings".
9. **Deploy.** Only committed versions, and only on the user's word. Record the commit hash in the deploy log.
