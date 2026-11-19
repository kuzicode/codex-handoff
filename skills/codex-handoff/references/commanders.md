# Notes per commander agent

The workflow is the same everywhere. What differs is how to wait for a long-running shell command and where project rules are read from.

| Commander | Waiting for `codex-task.sh` | Rules file it reads |
|---|---|---|
| Claude Code | Bash tool with `run_in_background: true`. You are re-invoked when it exits, so don't poll. | `CLAUDE.md` (point it to `AGENTS.md`) |
| Antigravity (IDE / `agy`) | Run in the terminal and let the task block. If commands time out, use the `nohup` fallback and check `run.log` occasionally. | `AGENTS.md` / `GEMINI.md`; workspace skills in `.agent/skills/` |
| Gemini CLI | Foreground shell command; if it times out, use the `nohup` fallback. | `GEMINI.md` (point it to `AGENTS.md`) |
| Cursor / Copilot / others | Foreground terminal command with a long timeout, or the `nohup` fallback. | `AGENTS.md` |

## Tips
- **One source of truth.** Keep project rules in `AGENTS.md`. Codex reads it, and so do most commanders. Make agent-specific files (`CLAUDE.md`, `GEMINI.md`) one-line pointers to it.
- **Same machine, same login.** `codex-task.sh check` confirms the Codex CLI is logged in (ChatGPT subscription or API key, whichever you use).
- **Model choice.** Leave it to the Codex account default. If you must change it, set it in `~/.codex/config.toml` after confirming your plan supports that model. Don't hard-code model names into briefs or skills.
- **Never edit while Codex is running** in the same files. Wait for the report, then review.
