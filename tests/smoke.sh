#!/usr/bin/env bash
# Offline self-test: argument validation and --dry-run command shapes. Never calls Codex.
set -u
S="$(cd "$(dirname "$0")/.." && pwd)/skills/codex-handoff/scripts/codex-task.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo "do something" > "$tmp/brief.md"
fails=0
ok()   { echo "  ok   $1"; }
bad()  { echo "  FAIL $1"; fails=$((fails+1)); }
expect_out() { # name, pattern, cmd...
  local name=$1 pat=$2; shift 2
  local o; o=$("$@" 2>&1); if printf '%s' "$o" | grep -qF -- "$pat"; then ok "$name"; else bad "$name: got [$o]"; fi
}
expect_fail() { # name, cmd...
  local name=$1; shift
  if "$@" >/dev/null 2>&1; then bad "$name (should fail)"; else ok "$name"; fi
}

expect_out  "run dry-run uses workspace-write"   "-s workspace-write"               bash "$S" run --cwd "$tmp" --brief "$tmp/brief.md" --dry-run
expect_out  "run dry-run sets effort"            'model_reasoning_effort=\"medium\"' bash "$S" run --cwd "$tmp" --brief "$tmp/brief.md" --effort medium --dry-run
expect_out  "run dry-run reads brief from file"  "< $tmp/brief.md"                  bash "$S" run --cwd "$tmp" --brief "$tmp/brief.md" --dry-run
expect_out  "resume uses --last"                 "resume --last"                    bash "$S" resume --cwd "$tmp" --brief - --dry-run
expect_out  "resume sets sandbox via config"     'sandbox_mode=\"workspace-write\"' bash "$S" resume --cwd "$tmp" --brief - --dry-run
expect_out  "review defaults to --uncommitted"   "review"                           bash "$S" review --cwd "$tmp" --dry-run
expect_out  "review --uncommitted present"       "--uncommitted"                    bash "$S" review --cwd "$tmp" --dry-run
expect_out  "review --base"                      "--base main"                      bash "$S" review --cwd "$tmp" --base main --dry-run
expect_out  "review --focus folds scope into prompt" "relative\\ to\\ main" bash "$S" review --cwd "$tmp" --base main --focus "money paths" --dry-run
o=$(bash "$S" review --cwd "$tmp" --focus x --dry-run 2>&1); printf '%s' "$o" | grep -q -- ' --uncommitted' && bad "review --focus must not pass scope flag" || ok "review --focus drops scope flag"
expect_out  "help works"                        "Subcommands"                      bash "$S" --help

expect_fail "unknown subcommand"                 bash "$S" frobnicate
expect_fail "missing --cwd"                      bash "$S" run --brief "$tmp/brief.md" --dry-run
expect_fail "missing --brief"                    bash "$S" run --cwd "$tmp" --dry-run
expect_fail "missing brief file"                 bash "$S" run --cwd "$tmp" --brief "$tmp/nope.md" --dry-run
expect_fail "bad effort"                         bash "$S" run --cwd "$tmp" --brief "$tmp/brief.md" --effort max --dry-run
expect_fail "bad cwd"                            bash "$S" run --cwd "$tmp/nope" --brief "$tmp/brief.md" --dry-run

grep -v '^#' "$S" | grep -q -- '--dangerously' && bad "script must not use --dangerously-* flags" || ok "no --dangerously-* flags"
grep -v '^#' "$S" | grep -qE -- '(-m|--model) ' && bad "script must not pass --model" || ok "no --model passed"

echo; [ $fails -eq 0 ] && echo "OK" || echo "FAIL $fails"
exit $fails
