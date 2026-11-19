# codex-handoff

把实现任务交给 **OpenAI Codex CLI** 的通用 Agent Skill。规划和 review 由"指挥官"agent 负责，可以是 Claude Code、Antigravity、Gemini CLI、Cursor 等任何能执行 shell 命令的 coding agent；Codex 只负责在沙箱里实施。

> An [Agent Skill](https://agentskills.io) that lets any shell-capable coding agent (Claude Code, Antigravity, Gemini CLI, Cursor, …) act as the **commander**, handing scoped implementation tasks to the **Codex CLI** and reviewing the results.

## 工作流

<p align="center"><img src="assets/workflow.svg" alt="codex-handoff 工作流：用户 / 指挥官 / Codex 三条泳道" width="960"></p>

<details><summary>文字版</summary>

```
指挥官规划（写进项目计划，如 docs/plan.md）→ 用户确认
  → new 生成交接文件（仓库外）→ run：Codex 实施一块，结果自动追加回交接文件
  → 指挥官 review（重跑验证，P0/P1/P2 分级，自己不改 Codex 的块）
  → resume 修复（最多 3 轮，仍不过就找用户）；高风险改动加 Codex 只读 review 作第二意见
  → 指挥官提交（按块），把结果和提交号摘要回项目计划 → 用户口令后 push / 部署
```

</details>

同一时刻只有一个写手；一个任务只认一个指挥官。

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
codex-task.sh check                                            # Codex 是否安装、是否登录
codex-task.sh new    --cwd <repo> --slug alerts --plan-ref M3-2   # 生成交接文件（仓库外），打印路径
codex-task.sh list   --cwd <repo>                              # 列出该仓库的交接文件（新会话接手用）
codex-task.sh run    --cwd <repo> --brief <handoff.md> --effort high [--worktree]
codex-task.sh resume --cwd <repo> --brief fix.md --append-to <handoff.md>   # 续接交接文件绑定的会话修复
codex-task.sh review --cwd <repo> --uncommitted --focus "资金路径"          # 第二意见，强制只读
codex-task.sh run ... --dry-run                                # 只打印将执行的 codex 命令
```

交接文件和日志放在仓库外的 `~/.local/state/codex-handoff/<repo>/`（可用 `CODEX_HANDOFF_HOME` 改），不会进入仓库；每轮 Codex 报告自动追加到交接文件末尾。

## 设计原则

- **指挥官无关**：只依赖 `codex exec` CLI 和 bash，不依赖任何 agent 的私有插件。各 agent 的差异（怎么等长任务、读哪个规则文件）见 `references/commanders.md`。
- **安全默认**：实施用 `workspace-write` 沙箱；从不传 `--dangerously-*`，也不指定型号（用你自己的配置或账号默认）。
- **会话绑定**：`run` 把 Codex 会话 ID 存在交接文件旁（`<交接文件>.thread`），`resume` 只续这个会话，不用「本目录最近一个会话」——中间插一次 review 或别的任务也不会续错。
- **只读是强制的**：`review` 使用只读沙箱，并以 `--ignore-user-config` 运行，因此不加载任何 MCP 服务器和插件（它们的工具不受沙箱约束），只沿用你配置里顶层的 `model`；登录不受影响。
- **规则单一来源**：项目规则放 `AGENTS.md`，Codex 和指挥官都读它；`CLAUDE.md` / `GEMINI.md` 用软链指向它（比 `@AGENTS.md` 导入更稳，子目录启动时导入可能不生效）。
- **不另起一份计划**：计划的唯一来源由项目规则决定（如 `docs/plan.md` 或 Issue / PR）。交接文件只是某一块的执行单，引用计划、不复述；`plan.md` / `issues.md` 只由指挥官写，Codex 在报告里列「ISS 候选」「范围外发现」。
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
| `assets/workflow.svg` | README 动态流程图（自适应浅色 / 深色） |

## 版本

- **v0.3**（2026-11-20）：`resume` 绑定交接文件的会话 ID（不再用 `--last`）；`review` 强制只读（只读沙箱、不加载 MCP / 插件）；补充「什么时候不必交接」。
- **v0.2**（2026-11-20）：交接文件（`new` / `list` / 结果自动追加）、停止条件与非目标、P0/P1/P2 分级、修复上限 3 轮、单写手与单指挥官、可选 `--worktree`、与项目 harness 的文档写权约定。
- **v0.1**（2026-11-19）：`check` / `run` / `resume` / `review`。

## License

MIT
