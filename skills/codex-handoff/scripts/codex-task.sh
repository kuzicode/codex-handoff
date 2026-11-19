#!/usr/bin/env bash
# codex-task.sh — one entry point for handing work to the Codex CLI from any
# "commander" agent (Claude Code, Antigravity, Gemini CLI, Cursor, ...).
#
# Subcommands:
#   check                                    verify codex is installed and logged in
#   new    --cwd DIR --slug NAME [--plan-ref REF]
#                                            create a handoff file from the template; prints its path
#   list   --cwd DIR                         list handoff files for this repo (newest first)
#   run    --cwd DIR --brief FILE|- [opts]   start a new Codex task (workspace-write sandbox)
#   resume --cwd DIR --brief FILE|- [opts]   continue the most recent Codex session in DIR
#   review --cwd DIR [--uncommitted|--base BRANCH|--commit SHA] [--focus TEXT]
#                                            read-only second-opinion review
# Options:
#   --effort low|medium|high|xhigh   reasoning effort (default: high)
#   --worktree                       (run) let Codex work in a new managed git worktree
#   --append-to FILE                 (run/resume) handoff file to append the report to (default: --brief)
#   --no-append                      (run/resume) don't append the report anywhere
#   --out DIR                        where report.md / logs go (default: <handoff>.logs/<timestamp>)
#   --dry-run                        print the codex command instead of running it
#
# Handoff files live outside the repo:
#   ${CODEX_HANDOFF_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/codex-handoff}/<repo>/<date>-<ref>-<slug>.md
# Never passes --model (account default) and never uses --dangerously-* flags.
set -euo pipefail

die() { echo "codex-task: $*" >&2; exit 2; }
usage() { awk 'NR>1 && /^#/{sub(/^# ?/,"");print;next} NR>1{exit}' "$0"; }
here=$(cd "$(dirname "$0")" && pwd)
template="$here/../references/brief-template.md"

[ $# -ge 1 ] || { usage; exit 2; }
cmd=$1; shift
case "$cmd" in
  check|new|list|run|resume|review) ;;
  -h|--help|help) usage; exit 0 ;;
  *) die "unknown subcommand: $cmd (expected check|new|list|run|resume|review)" ;;
esac

cwd="" brief="" effort="high" out="" dry=0 scope="" scope_arg="" focus=""
slug="" plan_ref="" worktree=0 append=1 append_to=""
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd) cwd=${2:?--cwd needs a value}; shift 2 ;;
    --brief) brief=${2:?--brief needs a value}; shift 2 ;;
    --effort) effort=${2:?--effort needs a value}; shift 2 ;;
    --out) out=${2:?--out needs a value}; shift 2 ;;
    --slug) slug=${2:?--slug needs a value}; shift 2 ;;
    --plan-ref) plan_ref=${2:?--plan-ref needs a value}; shift 2 ;;
    --worktree) worktree=1; shift ;;
    --no-append) append=0; shift ;;
    --append-to) append_to=${2:?--append-to needs a file}; shift 2 ;;
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
# Group handoffs by the repo's top-level dir name (falls back to the dir itself).
repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
home_dir="${CODEX_HANDOFF_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/codex-handoff}"
handoff_dir="$home_dir/$(basename "$repo_root")"
stamp=$(date +%Y%m%d-%H%M%S)

clean() { printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//'; }

if [ "$cmd" = new ]; then
  [ -n "$slug" ] || die "--slug is required"
  [ -f "$template" ] || die "template not found: $template"
  name="$(date +%Y-%m-%d)"; [ -z "$plan_ref" ] || name="$name-$(clean "$plan_ref")"
  file="$handoff_dir/$name-$(clean "$slug").md"
  [ ! -e "$file" ] || die "already exists: $file"
  mkdir -p "$handoff_dir"
  # The template's first fenced markdown block is the handoff skeleton.
  awk '/^```markdown$/{f=1;next} f&&/^```$/{exit} f' "$template" \
    | sed "s|<PLAN_REF>|${plan_ref:-<plan reference>}|; s|<REPO>|$repo_root|" > "$file"
  echo "$file"
  exit 0
fi

if [ "$cmd" = list ]; then
  [ -d "$handoff_dir" ] || { echo "(no handoff files in $handoff_dir)"; exit 0; }
  ls -1t "$handoff_dir"/*.md 2>/dev/null | while read -r f; do
    n=$(grep -c '^## Result — ' "$f" || true)
    printf '%s  (%s result%s)\n' "$f" "$n" "$([ "$n" = 1 ] || echo s)"
  done
  exit 0
fi

if [ "$cmd" != review ]; then
  [ -n "$brief" ] || die "--brief FILE (or - for stdin) is required"
  [ "$brief" = - ] || [ -f "$brief" ] || die "brief file not found: $brief"
fi
[ "$cmd" != review ] || append=0
[ -n "$append_to" ] || append_to=$brief
[ "$append_to" != - ] || append=0
[ "$append" = 0 ] || [ -f "$append_to" ] || die "--append-to file not found: $append_to"

if [ -z "$out" ]; then
  if [ "$append" = 1 ]; then
    out="${append_to%.md}.logs/$cmd-$stamp"
  else
    out="$home_dir/_adhoc/$(basename "$repo_root")-$cmd-$stamp"
  fi
fi

effort_cfg="model_reasoning_effort=\"$effort\""
case "$cmd" in
  run)
    argv=(codex exec -C "$cwd" -s workspace-write -c "$effort_cfg")
    [ "$worktree" = 0 ] || argv+=(--worktree)
    argv+=(--json -o "$out/report.md" -) ;;
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
      argv+=("Review $what. Report concrete bugs with file:line, severity (P0/P1/P2) and a failure scenario. Focus: $focus")
    fi ;;
esac

if [ "$dry" = 1 ]; then
  printf 'cd %q &&' "$cwd"; printf ' %q' "${argv[@]}"
  if [ "$cmd" != review ]; then
    if [ "$brief" = - ]; then printf ' < (stdin)'; else printf ' < %q' "$brief"; fi
  fi
  printf '\n'
  exit 0
fi

command -v codex >/dev/null || die "codex CLI not found"
mkdir -p "$out"
echo "codex-task: $cmd started; logs: $out" >&2

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

if [ -s "$out/report.md" ]; then report=$(cat "$out/report.md")
else report="(no report produced; see $out)"; fi

if [ "$cmd" != review ] && [ "$append" = 1 ]; then
  { printf '\n## Result — %s %s exit=%s\n\n' "$cmd" "$(date '+%Y-%m-%d %H:%M')" "$rc"
    printf '%s\n' "$report"; } >> "$append_to"
fi

echo "===== codex-task $cmd exit=$rc ====="
printf '%s\n' "$report"
[ -s "$out/report.md" ] || tail -n 20 "$out"/stderr.log "$out"/events.log 2>/dev/null || true
echo
echo "report: $out/report.md"
[ "$cmd" = review ] || [ "$append" = 0 ] || echo "appended to: $append_to"
exit "$rc"
