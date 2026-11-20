---
name: codex-handoff
description: Hand a scoped implementation task to the OpenAI Codex CLI and review what comes back. Use when you (the commander agent) have an approved plan and want Codex to implement one block of it, when sending review findings back to Codex for a fix, or when you want a read-only Codex second-opinion review of risky changes. Works from any agent that can run shell commands (Claude Code, Antigravity, Gemini CLI, Cursor, ...).
---

# Codex handoff

You are the **commander**: you plan, the user approves, **Codex implements**, you review and commit.
Codex is the **executor**: it runs in a sandbox, edits files, and reports back.
At any moment there is **one writer**. While Codex runs, you don't edit the repo. While you review, Codex is idle.

All Codex calls go through one script:

```bash
S=<this skill dir>/scripts/codex-task.sh
$S check                                                  # codex installed + logged in?
$S new    --cwd <repo> --slug <name> --plan-ref <M3-2>   # create a handoff file, prints its path
$S list   --cwd <repo>                                    # handoff files for this repo (resume context)
$S run    --cwd <repo> --brief <handoff.md> [--effort high] [--worktree]
$S resume --cwd <repo> --brief <fix.md> --append-to <handoff.md>   # continues the thread bound to it
$S review --cwd <repo> [--uncommitted|--base main|--commit SHA] [--focus "money paths"]   # enforced read-only
$S <run|resume|review> ... --dry-run                      # print the exact codex command
```

After `run` / `resume`, the script appends Codex's report to the handoff file under `## Result — …` and prints it.
- **Session binding.** `run` stores the Codex thread ID next to the handoff (`<handoff>.thread`), and `resume` continues exactly that thread.
  It never uses "the most recent session in this directory": a review or another task run in between would otherwise be resumed by mistake.
  `--thread ID` overrides; `--last` only if you explicitly want the old behaviour.
- **Read-only review is enforced, not promised.**
  - `review` runs with a read-only sandbox and `--ignore-user-config`, so no MCP servers or plugins are loaded (their tools act outside the sandbox).
  - Only your top-level `model` from `~/.codex/config.toml` is carried over. Login is unaffected.
It never passes `--model` (the account default is used) and never uses `--dangerously-*` flags.

## Where things live

The script assumes the project's own rules decide where plans and state go. It does not invent a second plan.

| What | Where | Who writes it |
|---|---|---|
| Long-lived rules | `AGENTS.md`. Codex reads it too; `CLAUDE.md` / `GEMINI.md` should be symlinks to it | commander, with the user |
| **Plan of record** (goal, approach, files, acceptance) | wherever the project's rules say: e.g. `docs/plan.md`, or the Issue / PR description | commander, before handoff |
| **Handoff file**: work order for one block, plus Codex results | outside the repo: `~/.local/state/codex-handoff/<repo>/` (via `new`) | commander writes it; the script appends results |
| Issue log / tech debt / plan checkboxes | the project's docs (e.g. `docs/issues.md`, `docs/plan.md`) | **commander only**. Codex lists candidates in its report |
| Code, tests, changelog | repo | Codex |

Why the handoff file stays out of the repo:
- It is an execution artifact, not the authority, so it never competes with the plan.
- It can never leak into a public repo.
- It still survives across sessions: a new commander session runs `list` and reads the file to pick up where things stand.

Durable outcomes go back into the plan of record: a short summary plus the commit hash on the plan's checkbox, and the issue log if a non-trivial bug was found.

## When not to hand off

A change of a few lines that existing tests can prove, and that doesn't touch money, trading or data-write paths, is cheaper to do yourself than one handoff round trip.
Hand off blocks with clear boundaries and runnable acceptance commands.

## Workflow

1. **Plan first.** The block must exist in the plan of record and be approved by the user.
   Slice by module (e.g. dashboard → alerts → trading). One handoff = one block, never a whole milestone.
2. **Write the handoff.** Run `new`, then fill in the skeleton from `references/brief-template.md`:
   - scope, files not to touch, **stop conditions**, hard limits, runnable acceptance commands;
   - reference the plan rather than copying it. Write it in the user's language.
3. **Run.** `run --effort medium|high|xhigh`: medium for small, well-specified blocks, high by default, xhigh for cross-module work or hard diagnosis.
   Add `--worktree` only for destructive changes, or when you need the main checkout during the run; see the worktree caveats below.
   Tasks can take 10–60 minutes; see "Waiting".
4. **Review. Don't trust the report.** Follow `references/review-checklist.md`:
   - rerun everything, check isolation hashes, read the critical diff;
   - grade findings P0 / P1 / P2.
   - Don't fix Codex's block yourself, except one- or two-line obvious typos. Send the rest back.
5. **Fix loop: at most 2 rounds.** Put the P0/P1 findings in a short fix file and run `resume --brief fix.md --append-to handoff.md`, then review again.
   If it still fails after 2 rounds, or Codex hits a stop condition, **stop and bring it to the user**. The plan probably needs to change. Never run an unattended review→fix→review loop.
   When the remaining findings only trigger in edge cases, bring them early with the options "accept as a known limit" or "change the design" instead of spending another round.
6. **Second opinion** for risky changes (money, trading, data writes, auth, deletion):
   - `review --uncommitted --focus "<what to scrutinise>"`. It is read-only (enforced) and supplements your review; it does not replace it.
   - Running it between `run` and `resume` is safe, because `resume` follows the handoff's bound thread.
7. **Close out.** You commit, one block per commit, with refactors in their own commit. Codex's sandbox usually cannot write `.git`.
   - Record the outcome and the commit hash in the plan of record, and add issue-log entries from Codex's candidates.
   - Push, PR and deploy happen only on the user's word. Deploy only committed versions.

## Waiting for long tasks

Pick the first one your harness supports:
- **Background with completion notification** (e.g. Claude Code `run_in_background`): start it and stop. Don't poll, and don't restart a task that is still running.
- **Foreground with a long timeout** (≥ 60 min).
- **Fallback:** `nohup $S run ... > run.log 2>&1 &`, then check at low frequency for the `===== codex-task` line.

## Sandbox and worktree limits

- Codex's `workspace-write` sandbox usually **cannot write `.git`**, **cannot listen on ports**, and **may have no network**.
  - You do those steps locally: commits, HTTP and browser tests, network checks.
  - Every handoff says: put anything the sandbox prevented under "Unverified", and never rewrite or weaken tests to get around it.
  - Split acceptance by who can run it: Codex runs lint, typecheck and the offline tests related to the block; the commander runs builds, HTTP / browser / port-listening tests and external tools (e.g. helm) once, locally. Asking Codex to attempt them only produces failures the commander has to rerun anyway.
- `--worktree` isolates files only.
  - The same branch cannot be checked out in two worktrees.
  - Ports, databases and local caches are shared, so don't run parallel tasks that touch them.
  - Review and commit inside the worktree Codex reports, then merge.

## One commander per task

Only one agent orchestrates a given task. Don't let Claude Code and Antigravity both drive it, and don't use another agent's built-in orchestrator or sub-agents as a second executor. See `references/commanders.md`.
