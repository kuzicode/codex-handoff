# Handoff file template

A handoff file is the **work order for one block** of an already-approved plan. It is not a second plan.
- It references the plan of record (e.g. `docs/plan.md` M3, or an Issue / PR) instead of restating goals.
- It adds only what the plan lacks: block scope, files not to touch, stop conditions, hard limits, runnable acceptance commands and the report format.

Create one with `codex-task.sh new --cwd <repo> --slug <name> --plan-ref <M3-2>`. That fills in the skeleton below and stores the file outside the repo.
Write it in the user's language. After each `run` / `resume`, Codex's report is appended under `## Result — …`.

```markdown
# Handoff: <block title>

Plan ref: <PLAN_REF>   ·   Repo: <REPO>

## Scope (this block only)
- Do: …
- Key files / functions: …

## Non-goals / do not touch
- Out of scope: … (other modules, unrelated refactors)
- Do not edit: AGENTS.md, docs/plan*.md, docs/issues*.md (the commander maintains them)

## Stop conditions
Stop and report instead of expanding scope if:
- the change needs files or modules outside Scope;
- the plan is ambiguous or contradicts the code you find;
- acceptance cannot pass without weakening a test or a safety check.

## Hard limits
- No deploy / ssh / real orders or payments / private or production API calls.
- Do not read or modify .env, secrets/, keys/, or real config files. Do not run git write commands.
- Tests must be hermetic: temp dirs for runtime files (DB, logs, caches, state), and HTTP stubbed.
- Anything you cannot verify because of the sandbox (ports, network, .git) → "Unverified".
  Never rewrite or weaken tests to get around the sandbox.

## Acceptance
Run from the repo root (expected result in comments):
    <test command>                                  # expect: no FAIL
    <lint / typecheck>                              # expect: clean
    <hash runtime files before/after the suite>     # expect: identical

## Report format
1. Changed files
2. Deviations from this handoff, with reasons
3. Unverified items
4. Issue candidates (non-trivial bugs found or fixed; the commander records them)
5. Out-of-scope findings / tech debt (not fixed; the commander decides)
6. Full output of the acceptance commands
Do not end the report with a question.
```

## Fix round (for `resume`)

Write the fix round as a short file of its own, or append it under the handoff file. The session already has the context, so keep it short.

```markdown
Fix round <n> — findings to fix (keep everything else unchanged):
1. [P0] <file:line> — <what is wrong> → <expected behaviour>
2. [P1] …
Re-run the acceptance commands and report in the same format. Do not end with a question.
```
