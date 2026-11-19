#!/usr/bin/env bash
# codex-task.sh — one entry point for handing work to the Codex CLI from any
# "commander" agent (Claude Code, Antigravity, Gemini CLI, Cursor, ...).
#
# Subcommands:
#   check                                   verify codex is installed and logged in
#   run    --cwd DIR --brief FILE|- [opts]  start a new Codex task (workspace-write sandbox)
#   resume --cwd DIR --brief FILE|- [opts]  continue the most recent Codex session in DIR
#   review --cwd DIR [--uncommitted|--base BRANCH|--commit SHA] [--focus TEXT]
#                                           read-only second-opinion review
# Common options:
#   --effort low|medium|high|xhigh   reasoning effort (default: high; review default: high)
#   --out DIR                        where report.md / events.jsonl go
#                                    (default: ${TMPDIR:-/tmp}/codex-handoff/<repo>-<timestamp>)
#   --dry-run                        print the codex command instead of running it
#
# Never passes --model (uses the account default) and never uses --dangerously-* flags.
set -euo pipefail

die() { echo "codex-task: $*" >&2; exit 2; }
usage() { sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; }

[ $# -ge 1 ] || { usage; exit 2; }
cmd=$1; shift
case "$cmd" in
  check|run|resume|review) ;;
  -h|--help|help) usage; exit 0 ;;
  *) die "unknown subcommand: $cmd (expected check|run|resume|review)" ;;
esac

cwd="" brief="" effort="high" out="" dry=0 scope="" scope_arg="" focus=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd) cwd=${2:?--cwd needs a value}; shift 2 ;;
    --brief) brief=${2:?--brief needs a value}; shift 2 ;;
    --effort) effort=${2:?--effort needs a value}; shift 2 ;;
    --out) out=${2:?--out needs a value}; shift 2 ;;
    --dry-run) dry=1; shift ;;
    --uncommitted) scope="--uncommitted"; shift ;;
    --base) scope="--base"; scope_arg=${2:?--base needs a branch}; shift 2 ;;
    --commit) scope="--commit"; scope_arg=${2:?--commit needs a sha}; shift 2 ;;
    --focus) focus=${2:?--focus needs text}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

case "$effort" in low|medium|high|xhigh) ;; *) die "--effort must be low|medium|high|xhigh" ;; esac

if [ "$cmd" = check ]; then
  command -v codex >/dev/null || die "codex CLI not found (install: npm i -g @openai/codex or brew install codex)"
  codex --version
  codex login status
  exit 0
fi

[ -n "$cwd" ] || die "--cwd is required"
[ -d "$cwd" ] || die "--cwd is not a directory: $cwd"
cwd=$(cd "$cwd" && pwd)

if [ "$cmd" != review ]; then
  [ -n "$brief" ] || die "--brief FILE (or - for stdin) is required"
  [ "$brief" = - ] || [ -f "$brief" ] || die "brief file not found: $brief"
fi

if [ -z "$out" ]; then
  out="${TMPDIR:-/tmp}"; out="${out%/}/codex-handoff/$(basename "$cwd")-$(date +%Y%m%d-%H%M%S)-$$"
fi

effort_cfg="model_reasoning_effort=\"$effort\""
case "$cmd" in
  run)
    argv=(codex exec -C "$cwd" -s workspace-write -c "$effort_cfg" --json -o "$out/report.md" -) ;;
  resume)
    # `codex exec resume` has no -C / -s: run from inside the repo and set the sandbox via config.
    argv=(codex exec resume --last -c 'sandbox_mode="workspace-write"' -c "$effort_cfg" --json -o "$out/report.md" -) ;;
  review)
    argv=(codex exec review -c "$effort_cfg" -o "$out/report.md")
    [ -n "$scope" ] || scope="--uncommitted"
    if [ -z "$focus" ]; then
      argv+=("$scope"); [ -z "$scope_arg" ] || argv+=("$scope_arg")
    else
      # codex rejects scope flags together with a custom prompt: describe the scope in the prompt instead.
      case "$scope" in
        --uncommitted) what="the uncommitted changes (staged, unstaged and untracked; see git status / git diff HEAD)" ;;
        --base) what="the changes on the current branch relative to $scope_arg (git diff $scope_arg...HEAD)" ;;
        --commit) what="the changes introduced by commit $scope_arg (git show $scope_arg)" ;;
      esac
      argv+=("Review $what. Report concrete bugs with file:line, severity and a failure scenario. Focus: $focus")
    fi ;;
esac

if [ "$dry" = 1 ]; then
  printf 'cd %q &&' "$cwd"; printf ' %q' "${argv[@]}"
  [ "$cmd" = review ] || { [ "$brief" = - ] && printf ' < (stdin)' || printf ' < %q' "$brief"; }
  printf '\n'
  exit 0
fi

command -v codex >/dev/null || die "codex CLI not found"
mkdir -p "$out"
echo "codex-task: $cmd started; output dir: $out" >&2

set +e
if [ "$cmd" = review ]; then
  (cd "$cwd" && "${argv[@]}" > "$out/events.log" 2>&1 </dev/null)
elif [ "$brief" = - ]; then
  (cd "$cwd" && "${argv[@]}" > "$out/events.jsonl" 2> "$out/stderr.log")
else
  (cd "$cwd" && "${argv[@]}" > "$out/events.jsonl" 2> "$out/stderr.log" < "$brief")
fi
rc=$?
set -e

echo "===== codex-task $cmd exit=$rc ====="
if [ -s "$out/report.md" ]; then
  cat "$out/report.md"
else
  echo "(no report.md produced; last lines of logs follow)"
  tail -n 20 "$out"/stderr.log "$out"/events.log 2>/dev/null || true
fi
echo
echo "report: $out/report.md"
exit "$rc"
