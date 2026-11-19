#!/usr/bin/env bash
# Offline self-test. Never calls the real Codex: a fake `codex` on PATH records its argv
# and writes a canned report, so run/resume/append behaviour is tested end to end.
set -u
S="$(cd "$(dirname "$0")/.." && pwd)/skills/codex-handoff/scripts/codex-task.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export CODEX_HANDOFF_HOME="$tmp/state"
repo="$tmp/repo"; mkdir -p "$repo"; git -C "$repo" init -q
echo "do something" > "$tmp/brief.md"

# fake codex: log argv, write "-o FILE" report, emit a thread.started event
mkdir -p "$tmp/bin"
cat > "$tmp/bin/codex" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_CODEX_LOG"
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out=$a; prev=$a; done
[ -z "$out" ] || echo "fake report for: $1 $2" > "$out"
n=$(wc -l < "$FAKE_CODEX_LOG" | tr -d ' ')
echo '{"type":"thread.started","thread_id":"fake-thread-'"$n"'"}'
cat >/dev/null 2>&1 || true
exit 0
EOF
chmod +x "$tmp/bin/codex"
export FAKE_CODEX_LOG="$tmp/codex.log"; : > "$FAKE_CODEX_LOG"
export PATH="$tmp/bin:$PATH"   # every call below sees the fake codex, never the real one

fails=0
ok()   { echo "  ok   $1"; }
bad()  { echo "  FAIL $1"; fails=$((fails+1)); }
expect_out() { # name, pattern, cmd...
  local name=$1 pat=$2; shift 2
  local o; o=$("$@" 2>&1); if printf '%s' "$o" | grep -qF -- "$pat"; then ok "$name"; else bad "$name: got [$o]"; fi
}
expect_fail() { local name=$1; shift; if "$@" >/dev/null 2>&1; then bad "$name (should fail)"; else ok "$name"; fi; }

echo "dry-run command shapes"
expect_out  "run uses workspace-write"          "-s workspace-write"               bash "$S" run --cwd "$repo" --brief "$tmp/brief.md" --dry-run
expect_out  "run sets effort"                   'model_reasoning_effort=\"medium\"' bash "$S" run --cwd "$repo" --brief "$tmp/brief.md" --effort medium --dry-run
expect_out  "run reads brief from file"         "< $tmp/brief.md"                  bash "$S" run --cwd "$repo" --brief "$tmp/brief.md" --dry-run
expect_out  "run --worktree passes through"     "--worktree"                       bash "$S" run --cwd "$repo" --brief "$tmp/brief.md" --worktree --dry-run
o=$(bash "$S" run --cwd "$repo" --brief "$tmp/brief.md" --dry-run); printf '%s' "$o" | grep -q -- '--worktree' && bad "no --worktree by default" || ok "no --worktree by default"
expect_fail "resume refuses without a bound thread" bash "$S" resume --cwd "$repo" --brief - --dry-run
expect_out  "resume --last only when asked"     "--last"                           bash "$S" resume --cwd "$repo" --brief - --last --dry-run
expect_out  "resume --thread uses that id"      "abc-123 -"                        bash "$S" resume --cwd "$repo" --brief - --thread abc-123 --dry-run
expect_fail "resume rejects odd thread id"      bash "$S" resume --cwd "$repo" --brief - --thread 'a;b' --dry-run
expect_out  "resume sets sandbox via config"    'sandbox_mode=\"workspace-write\"' bash "$S" resume --cwd "$repo" --brief - --last --dry-run
expect_out  "review sandbox is read-only"       'sandbox_mode=\"read-only\"'      bash "$S" review --cwd "$repo" --dry-run
expect_out  "review ignores user config (no MCP / plugins)" "--ignore-user-config"   bash "$S" review --cwd "$repo" --dry-run
mkdir -p "$tmp/codexhome"; printf 'model = "user-model"\n[profiles.x]\nmodel = "other"\n' > "$tmp/codexhome/config.toml"
expect_out  "review carries the user's top-level model" 'model=\"user-model\"'  env CODEX_HOME="$tmp/codexhome" bash "$S" review --cwd "$repo" --dry-run
o=$(env CODEX_HOME="$tmp/codexhome" bash "$S" review --cwd "$repo" --dry-run 2>&1); printf '%s' "$o" | grep -q 'other' && bad "review ignores profile models" || ok "review ignores profile models"
o=$(env CODEX_HOME="$tmp/none" bash "$S" review --cwd "$repo" --dry-run 2>&1); printf '%s' "$o" | grep -q 'model=' && bad "no model when user sets none" || ok "no model when user sets none"
expect_out  "review --uncommitted default"      "--uncommitted"                    bash "$S" review --cwd "$repo" --dry-run
expect_out  "review --base"                     "--base main"                      bash "$S" review --cwd "$repo" --base main --dry-run
expect_out  "review --focus folds scope"        "relative\\ to\\ main"             bash "$S" review --cwd "$repo" --base main --focus "money paths" --dry-run
o=$(bash "$S" review --cwd "$repo" --focus x --dry-run 2>&1); printf '%s' "$o" | grep -q -- ' --uncommitted' && bad "review --focus drops scope flag" || ok "review --focus drops scope flag"
expect_out  "help works"                        "Subcommands"                      bash "$S" --help

echo "argument validation"
expect_fail "unknown subcommand"                bash "$S" frobnicate
expect_fail "missing --cwd"                     bash "$S" run --brief "$tmp/brief.md" --dry-run
expect_fail "missing --brief"                   bash "$S" run --cwd "$repo" --dry-run
expect_fail "missing brief file"                bash "$S" run --cwd "$repo" --brief "$tmp/nope.md" --dry-run
expect_fail "bad effort"                        bash "$S" run --cwd "$repo" --brief "$tmp/brief.md" --effort max --dry-run
expect_fail "bad cwd"                           bash "$S" run --cwd "$tmp/nope" --brief "$tmp/brief.md" --dry-run
expect_fail "new needs --slug"                  bash "$S" new --cwd "$repo"
expect_fail "missing --append-to file"          bash "$S" resume --cwd "$repo" --brief "$tmp/brief.md" --append-to "$tmp/nope.md" --dry-run

echo "handoff files (fake codex)"
h=$(bash "$S" new --cwd "$repo" --slug "alerts block" --plan-ref "M3-2")
case "$h" in "$CODEX_HANDOFF_HOME/repo/"*-M3-2-alerts-block.md) ok "new path under state dir" ;; *) bad "new path: $h" ;; esac
[ -f "$h" ] && grep -q '^## Stop conditions' "$h" && grep -q 'Plan ref: M3-2' "$h" && ok "new fills skeleton" || bad "new skeleton"
expect_fail "new refuses to overwrite"          bash "$S" new --cwd "$repo" --slug "alerts block" --plan-ref "M3-2"
[ -z "$(git -C "$repo" status --porcelain)" ] && ok "new leaves repo clean" || bad "new wrote into repo"

bash "$S" run --cwd "$repo" --brief "$h" --effort low >/dev/null 2>&1 && ok "run exit 0" || bad "run exit"
grep -q '^## Result — run ' "$h" && grep -q 'fake report for: exec -C' "$h" && ok "run appends Result" || bad "run append"
tid=$(cat "${h%.md}.thread" 2>/dev/null)
[ -n "$tid" ] && grep -q "thread=$tid" "$h" && ok "run binds thread id to handoff ($tid)" || bad "thread not stored"
bash "$S" review --cwd "$repo" >/dev/null 2>&1   # an unrelated session in the same dir, newer than run
echo "fix this" > "$tmp/fix.md"
bash "$S" resume --cwd "$repo" --brief "$tmp/fix.md" --append-to "$h" >/dev/null 2>&1
tail -1 "$FAKE_CODEX_LOG" | grep -q -- "exec resume .* $tid -\$" && ok "resume continues the bound thread, not the newer review" || bad "resume thread: $(tail -1 "$FAKE_CODEX_LOG")"
! tail -1 "$FAKE_CODEX_LOG" | grep -q -- '--last' && ok "resume did not use --last" || bad "resume used --last"
[ "$(grep -c '^## Result — ' "$h")" = 2 ] && ok "resume appends to handoff via --append-to" || bad "resume append"
! grep -q 'Result' "$tmp/fix.md" && ok "fix file untouched" || bad "fix file modified"
bash "$S" run --cwd "$repo" --brief "$h" --no-append >/dev/null 2>&1
[ "$(cat "${h%.md}.thread")" = "$tid" ] && ok "--no-append run keeps the bound thread" || bad "--no-append overwrote thread"
[ "$(grep -c '^## Result — ' "$h")" = 2 ] && ok "--no-append respected" || bad "--no-append"
[ -d "${h%.md}.logs" ] && ok "logs beside handoff file" || bad "logs dir"
expect_out  "list shows handoff with results"   "(2 results)"                      bash "$S" list --cwd "$repo"
[ -z "$(git -C "$repo" status --porcelain)" ] && ok "repo still clean after run/resume" || bad "repo dirtied"

echo "safety"
grep -v '^#' "$S" | grep -q -- '--dangerously' && bad "no --dangerously-* flags" || ok "no --dangerously-* flags"
grep -v '^#' "$S" | grep -qE -- '(-m|--model) ' && bad "no --model passed" || ok "no --model passed"
grep -q -- '--model\| -m ' "$FAKE_CODEX_LOG" && bad "fake codex saw --model" || ok "fake codex never saw --model"

echo; [ $fails -eq 0 ] && echo "OK" || echo "FAIL $fails"
exit $fails
