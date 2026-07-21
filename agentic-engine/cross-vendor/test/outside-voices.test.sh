#!/usr/bin/env bash
# Shell tests for outside-voices.sh — validates core logic with mock vendor CLIs.
#
# Run: cd agentic-engine/cross-vendor && bash test/outside-voices.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_SCRIPT="$SCRIPT_DIR/../outside-voices.sh"
PASS=0
FAIL=0

ok()   { echo "  ✓ $1"; PASS=$((PASS + 1)); }
nok()  { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

assert_exit() {
  local expected="$1" actual="$2" label="$3"
  if [ "$actual" -eq "$expected" ]; then
    ok "$label (exit $actual)"
  else
    nok "$label — expected exit $expected, got $actual"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -q "$needle"; then
    ok "$label"
  else
    nok "$label — '$needle' not found in output"
  fi
}

# Run core script, capture stdout+stderr and exit code into RUN_OUTPUT / RUN_RC.
run() {
  RUN_OUTPUT=$("$@" 2>&1) && RUN_RC=0 || RUN_RC=$?
}

# ── Setup: create mock vendor CLIs ─────────────────────────────────
MOCK_DIR="$(mktemp -d)"
trap 'rm -rf "$MOCK_DIR"' EXIT

# Mock codex: succeeds, prints to stdout
cat > "$MOCK_DIR/codex" << 'EOF'
#!/usr/bin/env bash
cat
echo "codex says yes"
EOF
chmod +x "$MOCK_DIR/codex"

# Mock gemini: succeeds, prints to stdout
cat > "$MOCK_DIR/gemini" << 'EOF'
#!/usr/bin/env bash
cat
echo "gemini agrees"
EOF
chmod +x "$MOCK_DIR/gemini"

# Mock agy: fails with exit 1 + stderr
cat > "$MOCK_DIR/agy" << 'EOF'
#!/usr/bin/env bash
cat
echo "agy error" >&2
exit 1
EOF
chmod +x "$MOCK_DIR/agy"

export PATH="$MOCK_DIR:$PATH"

# ── Tests ──────────────────────────────────────────────────────────
echo "Running outside-voices.sh tests..."
echo ""

# 1. Fail-open kill switch
echo "[1] OUTSIDE_VOICES_OFF=1"
  OUTSIDE_VOICES_OFF=1 run bash "$CORE_SCRIPT" "test prompt"
  assert_exit 0 "$RUN_RC" "kill switch exits 0"

# 2. Missing CLI — point PATH at a mock-FREE dir so the vendor CLI is genuinely absent
# (the old test left MOCK_DIR on PATH, so codex was actually present; it only "passed"
# on platforms lacking `timeout`, where every vendor died anyway — it failed on CI).
echo "[2] Missing CLI"
  EMPTY_BIN="$(mktemp -d)"
  SAVED_PATH="$PATH"
  export PATH="$EMPTY_BIN:/usr/bin:/bin"
  OUTSIDE_VOICES_VENDORS="codex" run bash "$CORE_SCRIPT" "test"
  export PATH="$SAVED_PATH"
  rm -rf "$EMPTY_BIN"
  assert_exit 1 "$RUN_RC" "missing CLI exits 1"
  assert_contains "$RUN_OUTPUT" "not found" "error mentions missing CLI"

# 3. Unknown vendor
echo "[3] Unknown vendor"
  OUTSIDE_VOICES_VENDORS="totally-unknown" run bash "$CORE_SCRIPT" "test"
  assert_exit 1 "$RUN_RC" "unknown vendor exits 1"
  assert_contains "$RUN_OUTPUT" "Unknown vendor" "error mentions unknown vendor"

# 4. All-green
echo "[4] All-green"
  OUTSIDE_VOICES_VENDORS="codex,gemini" OUTSIDE_VOICES_TIMEOUT=5 run bash "$CORE_SCRIPT" "test prompt"
  assert_exit 0 "$RUN_RC" "all-green exits 0"
  assert_contains "$RUN_OUTPUT" "all-green" "STATUS: all-green"
  assert_contains "$RUN_OUTPUT" "codex says yes" "codex output present"
  assert_contains "$RUN_OUTPUT" "gemini agrees" "gemini output present"

# 5. Degraded
echo "[5] Degraded"
  OUTSIDE_VOICES_VENDORS="codex,agy" OUTSIDE_VOICES_TIMEOUT=5 run bash "$CORE_SCRIPT" "test prompt"
  assert_exit 2 "$RUN_RC" "degraded exits 2"
  assert_contains "$RUN_OUTPUT" "degraded" "STATUS: degraded"
  assert_contains "$RUN_OUTPUT" "agy error" "agy stderr captured"

# 6. All-dead — override both mocks to fail
echo "[6] All-dead"
  printf '#!/usr/bin/env bash\ncat\nexit 1\n' > "$MOCK_DIR/codex" && chmod +x "$MOCK_DIR/codex"
  printf '#!/usr/bin/env bash\ncat\nexit 1\n' > "$MOCK_DIR/gemini" && chmod +x "$MOCK_DIR/gemini"
  OUTSIDE_VOICES_VENDORS="codex,gemini" OUTSIDE_VOICES_TIMEOUT=5 run bash "$CORE_SCRIPT" "test prompt"
  assert_exit 1 "$RUN_RC" "all-dead exits 1"
  assert_contains "$RUN_OUTPUT" "all-dead" "STATUS: all-dead"

# 7. Empty output = not green
echo "[7] Empty output counted as dead"
  printf '#!/usr/bin/env bash\ncat > /dev/null\n' > "$MOCK_DIR/codex" && chmod +x "$MOCK_DIR/codex"
  printf '#!/usr/bin/env bash\ncat > /dev/null\necho "gemini has output"\n' > "$MOCK_DIR/gemini" && chmod +x "$MOCK_DIR/gemini"
  OUTSIDE_VOICES_VENDORS="codex,gemini" OUTSIDE_VOICES_TIMEOUT=5 run bash "$CORE_SCRIPT" "test prompt"
  assert_exit 2 "$RUN_RC" "empty-but-exit-0 = degraded"
  assert_contains "$RUN_OUTPUT" "degraded" "STATUS: degraded"
  assert_contains "$RUN_OUTPUT" "DEAD" "codex marked DEAD (empty output)"

# 8. Stdin input
echo "[8] Stdin input"
  printf '#!/usr/bin/env bash\ncat\necho "codex ok"\n' > "$MOCK_DIR/codex" && chmod +x "$MOCK_DIR/codex"
  printf '#!/usr/bin/env bash\ncat\necho "gemini ok"\n' > "$MOCK_DIR/gemini" && chmod +x "$MOCK_DIR/gemini"
  RUN_OUTPUT=$(echo "piped prompt" | OUTSIDE_VOICES_VENDORS="codex,gemini" OUTSIDE_VOICES_TIMEOUT=5 bash "$CORE_SCRIPT" 2>&1) && RUN_RC=0 || RUN_RC=$?
  assert_exit 0 "$RUN_RC" "stdin input succeeds"

# 9. --prompt-file
echo "[9] --prompt-file"
  echo "file-based prompt" > "$MOCK_DIR/prompt.txt"
  OUTSIDE_VOICES_VENDORS="codex,gemini" OUTSIDE_VOICES_TIMEOUT=5 run bash "$CORE_SCRIPT" --prompt-file "$MOCK_DIR/prompt.txt"
  assert_exit 0 "$RUN_RC" "--prompt-file succeeds"

# 10. Durable output
echo "[10] Durable output"
  out_dir="$MOCK_DIR/capture-test"
  OUTSIDE_VOICES_VENDORS="codex,gemini" OUTSIDE_VOICES_TIMEOUT=5 OUTSIDE_VOICES_OUT_DIR="$out_dir" run bash "$CORE_SCRIPT" "test"
  [ -f "$out_dir/result.md" ] && ok "result.md exists in OUT_DIR" || nok "result.md missing in OUT_DIR"
  { [ -f "$out_dir/codex.out" ] && [ -f "$out_dir/gemini.out" ]; } && ok "per-vendor .out files exist" || nok "per-vendor .out files missing"

# ── Summary ────────────────────────────────────────────────────────
echo ""
echo "Results: ${PASS} pass, ${FAIL} fail"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
