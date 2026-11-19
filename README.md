# codex-handoff

把实现任务交给 **OpenAI Codex CLI** 的通用 Agent Skill。规划和 review 由"指挥官"agent 负责，可以是 Claude Code、Antigravity、Gemini CLI、Cursor 等任何能执行 shell 命令的 coding agent；Codex 只负责在沙箱里实施。

> An [Agent Skill](https://agentskills.io) that lets any shell-capable coding agent (Claude Code, Antigravity, Gemini CLI, Cursor, …) act as the **commander**, handing scoped implementation tasks to the **Codex CLI** and reviewing the results.

## 工作流

```
指挥官规划 → 用户确认 → Codex 实施（一次一块）→ 指挥官 review（重跑验证，不信报告）
                                  ↑                │
                                  └── resume 修复 ──┘   高风险改动：Codex 只读 review 作第二意见
指挥官提交（按块）→ 用户口令后 push / 部署（只部署已提交版本）
```

## 安装

需要已安装并登录 [Codex CLI](https://github.com/openai/codex)（`codex login`，ChatGPT 订阅或 API key 均可）。

```bash
# 推荐：用 skills CLI 一次装到多个 agent
npx skills add kuzicode/codex-handoff -g -a claude-code -a antigravity
# 其它 agent：-a gemini-cli / -a cursor / -a codex …，不带 -a 会列出本机检测到的 agent

# 或手动：把 skills/codex-handoff/ 复制或软链到对应 agent 的 skills 目录
#   Claude Code: ~/.claude/skills/codex-handoff
```

## 用法

在指挥官 agent 里直接说"把这一块交给 Codex 实现"，agent 会按 `SKILL.md` 的流程执行。底层统一调用：

```bash
codex-task.sh check                                          # Codex 是否安装、是否登录
codex-task.sh run    --cwd <repo> --brief brief.md --effort high
codex-task.sh resume --cwd <repo> --brief fix.md             # 续接同一个 Codex 会话修复
codex-task.sh review --cwd <repo> --uncommitted --focus "资金路径"   # 只读第二意见
codex-task.sh run ... --dry-run                              # 只打印将执行的 codex 命令
```

报告写在仓库之外的临时目录（`$TMPDIR/codex-handoff/…/report.md`），脚本结束时打印报告内容。

## 设计原则

- **指挥官无关**：只依赖 `codex exec` CLI 和 bash，不依赖任何 agent 的私有插件。各 agent 的差异（怎么等长任务、读哪个规则文件）见 `references/commanders.md`。
- **安全默认**：使用 `workspace-write` 沙箱；从不传 `--dangerously-*`，也不传 `--model`（模型用账号默认）。
- **规则单一来源**：项目规则放 `AGENTS.md`，Codex 和指挥官都读它；交接说明只写本次任务。
- **验证不外包**：沙箱里跑不了的验证（`.git`、端口、网络）报告为"未验证项"，由指挥官在本机补跑，禁止为了绕开沙箱改写测试。

## 文件

| 文件 | 内容 |
|---|---|
| `skills/codex-handoff/SKILL.md` | 核心流程 |
| `skills/codex-handoff/scripts/codex-task.sh` | 统一入口脚本 |
| `skills/codex-handoff/references/brief-template.md` | 交接说明 / 修复说明模板 |
| `skills/codex-handoff/references/review-checklist.md` | 收货 review 清单 |
| `skills/codex-handoff/references/commanders.md` | 各指挥官 agent 的差异说明 |
| `tests/smoke.sh` | 离线自检（不调用 Codex） |

## License

MIT
