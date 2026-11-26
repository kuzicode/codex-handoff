# Notes per commander agent

The workflow is the same everywhere. What differs is how to wait for a long-running shell command and how project rules get loaded.

| Commander | Waiting for `codex-task.sh` | Loading project rules |
|---|---|---|
| Claude Code | Bash tool with `run_in_background: true`. You are re-invoked when it exits, so don't poll. | `CLAUDE.md` → **symlink to `AGENTS.md`** |
| Antigravity (IDE / `agy`) | Run in background with completion notification (`run_command` async wait); don't poll. Use `nohup` fallback only if the harness blocks/times out. | `AGENTS.md` (or a `GEMINI.md` symlink); workspace skills in `.agent/skills/` |
| Gemini CLI | Foreground shell command; if it times out, use the `nohup` fallback. | `GEMINI.md` → symlink to `AGENTS.md` |
| Cursor / Copilot / others | Foreground terminal command with a long timeout, or the `nohup` fallback. | `AGENTS.md` |

## Tips
- **One source of truth for rules.** Keep them in `AGENTS.md`, which Codex reads natively. Make `CLAUDE.md` / `GEMINI.md` a symlink: `ln -sf AGENTS.md CLAUDE.md`.
  - Prefer the symlink over a text pointer, which may not be loaded at all.
  - Prefer it over an `@AGENTS.md` import too: in tests, Claude Code launched from a subdirectory (`claude -p`) did not follow the import, while the symlink always loads.
- **One commander per task.** Pick one agent to drive a task end to end. Don't let two commanders schedule the same work, and don't let a commander's built-in orchestrator or sub-agents act as a second executor next to Codex. Two writers on one branch means lost work.
- **Antigravity** is a good fit for planning, reviewing artifacts and kicking off the next block. If you use its scheduled tasks, let it be the only commander for that task.
- **Claude Code + the official Codex plugin** (`openai/codex-plugin-cc`): `/codex:transfer` turns the current planning conversation into a Codex thread you can `codex resume`. It is handy when the plan lives in chat. The handoff file is still the work order.
- **Same machine, same login.** `codex-task.sh check` confirms the Codex CLI is logged in (ChatGPT subscription or API key, whichever you use).
- **Model choice.** Leave it to the Codex account default. Change it in `~/.codex/config.toml` only after confirming your plan supports the model. Don't hard-code model names into handoffs or skills.
