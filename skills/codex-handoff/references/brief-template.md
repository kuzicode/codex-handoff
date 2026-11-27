# Handoff file template

A handoff file is the **work order for one block** of an already-approved plan. It is not a second plan.
- It references the plan of record (e.g. `docs/plan.md` M3, or an Issue / PR) instead of restating goals.
- It adds only what the plan lacks: block scope, invariants, boundary cases, files not to touch, stop conditions, hard limits, two-tier acceptance commands and the report format.

Create one with `codex-task.sh new --cwd <repo> --slug <name> --plan-ref <M3-2>`. That fills in the skeleton below and stores the file outside the repo.
Write it in the user's language. After each `run` / `resume`, Codex's report is appended under `## Result — …`.

```markdown
# Handoff: <block title>

Plan ref: <PLAN_REF>   ·   Repo: <REPO>

## Scope (this block only)
- Do: … (state outcomes and constraints; avoid over-prescribing internal concurrency/wiring unless required)
- Key files / functions: …
- Existing contracts touched: … (each reused constant / enum / aggregator / payload field → its writers and consumers, reuse or new, fallback for old caches or rows missing the field)

## Invariants & Contracts (keep the sections that apply, delete the rest)
State / money / concurrency / quota / clock:
- Global invariants: … (e.g. monotonic state or timestamp ordering, clock-domain separation, cross-tenant/cross-entity isolation)
- Failure & retry matrix: … (expected behavior on 4xx/5xx/timeout/quota-exhaustion, fail-fast check ordering, retry budget headroom)
Read-only aggregation:
- Definitions & honesty: … (which states count, e.g. include "closing"; unknown → null or "partial", never a silent 0; existing totals or reducers that must follow the same rule)
UI:
- Point to the project's viewport and no-truncation rules (e.g. its conventions doc). The commander verifies them in a browser; Codex cannot.

## Non-goals / do not touch
- Out of scope: … (other modules, unrelated refactors)
- Do not edit: AGENTS.md, docs/plan*.md, docs/issues*.md (the commander maintains them)

## Stop conditions
Stop and report instead of expanding scope if:
- the change needs files or modules outside Scope;
- the plan is ambiguous or contradicts the code you find;
- acceptance cannot pass without weakening a test or a safety check;
- correctness or state honesty would conflict with performance, request count or brevity. Correctness wins: report the conflict and never degrade silently;
- an expected value in the boundary cases does not match what the code or data produce.

## Hard limits
- No deploy / ssh / real orders or payments / private or production API calls.
- Do not read or modify .env, secrets/, keys/, or real config files. Do not run git write commands.
- Tests must be hermetic: temp dirs for runtime files (DB, logs, caches, state), and HTTP stubbed.
- Keep touched files within the repo's size limits; if a target test file is near the limit, create a focused new test file.
- Anything you cannot verify because of the sandbox (ports, network, .git) → "Unverified".
  Never rewrite or weaken tests to get around the sandbox.

## Acceptance
Codex runs (fast inner-loop only; repo root):
    <lint / typecheck>                              # expect: clean
    <block-local offline tests (focused subset)>    # expect: no FAIL

Must-prove boundary cases (encode as offline assertions):
- <adversarial scenario 1 — e.g. clock skew, partial failure, retry under quota>
- <adversarial scenario 2>

Commander runs locally (do NOT attempt in the sandbox; list under "Unverified"):
    <full cross-module regression suite, build, HTTP / browser / port-listening tests, external tools>
    <hash runtime files before/after the suite>     # expect: identical

## Report format
1. Changed files (with line counts if the repo enforces file-length caps)
2. Deviations from this handoff, with reasons
3. Unverified items
4. Issue candidates (non-trivial bugs found or fixed; the commander records them)
5. Out-of-scope findings / tech debt (not fixed; the commander decides)
6. Full output of the acceptance commands
Do not end the report with a question.
```

## Fix round (for `resume`)

Write the fix round as a short file of its own, or append it under the handoff file. The session already has the context, so keep it short.

If any fix **introduces or alters a lock, queue, backoff, cache, state transition, or schema column**, include a 3-line **Coupling check** so the fix does not break sibling paths or global schedulers.

```markdown
Fix round <n> — findings to fix (keep everything else unchanged):
1. [P0] <file:line> — <what is wrong> → <expected behaviour + regression assertion>
2. [P1] …

Coupling check (include whenever adding/changing a lock, backoff, queue, cache, state field, or schema):
- Scope & release: gate only the failing I/O, release as soon as it settles, never block healthy sibling reads.
- Cross-entity & scheduler: ensure cooldown/backoff does not starve other entities or leave stale global queue tickets.
- Cache safety: never persist unconfirmed/lagging samples that could poison fallback paths during a later outage.

Re-run the fast inner-loop acceptance commands and report in the same format. Do not end with a question.
```
