---
name: codex-handoff
description: Hand a scoped implementation task to the OpenAI Codex CLI and review what comes back. Use when you (the commander agent) have an approved plan and want Codex to implement one block of it, when sending review findings back to Codex for a fix, or when you want a read-only Codex second-opinion review of risky changes. Works from any agent that can run shell commands (Claude Code, Antigravity, Gemini CLI, Cursor, ...).
---

# Codex handoff

You are the **commander**: you plan, the user approves, **Codex implements**, you review and commit.
Codex is the **executor**: it runs in a sandbox, edits files, and reports back.

All Codex calls go through one script, so the commander never needs to remember CLI quirks:

```bash
S=<this skill dir>/scripts/codex-task.sh
$S check                                              # codex installed + logged in?
$S run    --cwd <repo> --brief <brief.md> [--effort high]
$S resume --cwd <repo> --brief <fix.md>               # continue the same Codex session
$S review --cwd <repo> [--uncommitted|--base main|--commit SHA] [--focus "money paths"]
$S run ... --dry-run                                  # print the exact codex command
```

The script prints Codex's final report and its path (`report.md` in a temp dir outside the repo).
It never passes `--model` (the account default is used) and never uses `--dangerously-*` flags.

## Workflow

1. **Slice.** One handoff = one block (e.g. dashboard → alerts → trading). Never hand over a whole milestone.
2. **Write the brief to a file** using `references/brief-template.md`. Write it in the user's language.
   Put only this task in it. Project rules live in `AGENTS.md`, which Codex reads itself, so don't copy them into the brief.
3. **Run it.** `run --effort medium|high|xhigh`. Use medium for small, well-specified blocks, high by default, and xhigh for cross-module work or hard diagnosis.
   Tasks can take 10–60 minutes; see "Waiting" below.
4. **Review. Don't trust the report.** Follow `references/review-checklist.md`: rerun every verification command yourself, read the critical diff, and compare file hashes for isolation.
5. **Fix loop.** Write only the findings into a short fix brief and `resume` the session, so Codex keeps its context. Then review again.
6. **Second opinion** for risky changes (money, trading, data writes, auth, deletion): `review --uncommitted --focus "<what to scrutinise>"`. It is read-only. Weigh its findings and don't apply them blindly.
7. **Commit.** You (the commander) commit, one commit per block, because Codex's sandbox usually cannot write `.git`. Push, PR and deploy happen only on the user's word. Deploy only committed versions.

## Waiting for long tasks

Pick the first one your harness supports:
- **Background execution with completion notification** (e.g. Claude Code `run_in_background`): start it and stop working on it. Don't poll, and don't restart a task that is still running.
- **Foreground with a long timeout** (≥ 60 min) when the harness lets you set one.
- **Fallback:** `nohup $S run ... > run.log 2>&1 &`, then check at low frequency (every few minutes) for the `===== codex-task` line in `run.log`.

See `references/commanders.md` for per-agent notes.

## Sandbox limits

Codex's `workspace-write` sandbox typically **cannot write `.git`**, **cannot listen on ports**, and **may have no network**.
- The commander does those steps locally: commits, HTTP and browser tests, anything that needs network.
- Every brief must say: *anything you cannot verify because of the sandbox goes under "Unverified" in the report. Never rewrite or weaken tests to get around the sandbox.*

## Hard rules for every brief

Adapt these to the project, but keep the spirit:
- No deploys, no ssh, no real orders or payments, no calls to private or production APIs.
- Don't read or modify secrets (`.env`, keys, real configs). Don't run git write commands.
- Tests must be hermetic: runtime files (DB, logs, caches, state) go to temp dirs, and HTTP is stubbed.
- The report lists changed files, deviations with reasons, unverified items, and full output of the acceptance commands. It must **not end with a question**, because nobody is there to answer it.
