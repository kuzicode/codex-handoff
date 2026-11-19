# Brief template

Copy, fill in, and save as a file (e.g. `<tmp>/brief-<block>.md`). Then pass it with `--brief`.
Write it in the user's language. Be concrete: name the files and functions, and give commands that can be copied and run as they are.

```markdown
## Background
Why this change exists, the current behaviour / bug, and the key files and functions involved.
Link the plan section if there is one (e.g. docs/plan.md "M12").

## Scope (this block only)
- Do: …
- Do NOT: … (out-of-scope refactors, other modules, docs other than CHANGELOG)

## Hard limits
- No deploy / ssh / real orders / private or production API calls.
- Do not read or modify .env, secrets/, keys/, real config files; do not run git write commands.
- Tests must be hermetic (temp dirs for runtime files, HTTP stubbed).
- Anything you cannot verify because of the sandbox (ports, network, .git) → list it under
  "Unverified". Do not rewrite or weaken tests to get around the sandbox.

## Acceptance
Commands to run from the repo root, with the expected result:
    <test command>            # expect: no FAIL
    <lint / typecheck>        # expect: clean
    <hash check of runtime files before/after>   # expect: identical

## Report format
1. Changed files
2. Deviations from this brief, with reasons
3. Unverified items
4. Full output of the acceptance commands
Do not end the report with a question.
```

## Fix brief (for `resume`)

Keep it short. The session already has the context.

```markdown
Review findings to fix (keep everything else unchanged):
1. <file:line> — <what is wrong> → <expected behaviour>
2. …
Re-run the acceptance commands and report in the same format. Do not end with a question.
```
