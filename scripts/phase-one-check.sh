#!/bin/zsh
set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_DIR="${CAMNEXT_PHASE_ONE_OUTPUT_DIR:-$ROOT_DIR/build/phase-one}"
BIN="$ROOT_DIR/build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext"
mkdir -p "$OUTPUT_DIR/logs"

if [[ ! -x "$BIN" ]]; then
  make build >"$OUTPUT_DIR/logs/build.log" 2>&1
fi

automatic=pass
run_check() {
  local name="$1"
  shift
  if "$@" >"$OUTPUT_DIR/logs/$name.log" 2>&1; then
    print "PASS  $name"
  else
    print "FAIL  $name"
    automatic=fail
  fi
}

run_check task-runtime "$BIN" --self-test-task-runtime
run_check codex-session-link "$BIN" --self-test-codex-session-link
run_check performance-monitor "$BIN" --self-test-performance-monitor
run_check phase-one-gate "$BIN" --self-test-phase-one-gate
run_check rate-limits "$BIN" --self-test-rate-limits
run_check statistics-time-zone "$BIN" --self-test-statistics-time-zone
run_check status-item "$BIN" --self-test-status-item
run_check parsers env CAMNEXT_SKIP_BUILD=1 "$ROOT_DIR/scripts/test-parsers.sh"
run_check palettes "$BIN" --self-test-palettes
run_check particle-animation "$BIN" --self-test-particle-animation
run_check macos-compatibility "$ROOT_DIR/scripts/test-macos-compatibility.sh"

if "$BIN" --dump-json >"$OUTPUT_DIR/probe.json" 2>"$OUTPUT_DIR/logs/probe.log" \
  && ! rg -n '"(approval|requestId|reason|command)"[[:space:]]*:' "$OUTPUT_DIR/probe.json" \
    >"$OUTPUT_DIR/logs/privacy.log" 2>&1; then
  print "PASS  privacy-boundary"
else
  print "FAIL  privacy-boundary"
  automatic=fail
fi

MANUAL_FILE="$OUTPUT_DIR/manual-checklist.md"
if [[ ! -f "$MANUAL_FILE" ]]; then
  {
    print '# 第一阶段人工验收'
    print
    print -- '- [ ] 浅色与深色模式关键页面无视觉阻断'
    print -- '- [ ] 浮窗只出现一个最高优先级事项，点击定位正确'
    print -- '- [ ] 今日任务四列、审批中、断线和回到 Codex 提示符合预期'
    print -- '- [ ] Reduce Motion、长文案和键盘操作可用'
    print -- '- [ ] 安装、升级、启动、退出链路通过'
  } >"$MANUAL_FILE"
fi
if rg -q '^- \[ \]' "$MANUAL_FILE"; then
  manual=pending
else
  manual=pass
fi

SOAK_FILE="$OUTPUT_DIR/soak.json"
if [[ ! -f "$SOAK_FILE" ]]; then
  soak=pending
else
  duration="$(plutil -extract durationSeconds raw "$SOAK_FILE" 2>/dev/null || print 0)"
  soak_result="$(plutil -extract conclusion raw "$SOAK_FILE" 2>/dev/null || print invalid)"
  if [[ "$soak_result" == "pass" && "$duration" -ge 28800 ]]; then
    soak=pass
  elif [[ "$soak_result" == "pass" ]]; then
    soak=pending
  else
    soak=fail
  fi
fi

RELEASE_FILE="$OUTPUT_DIR/release-evidence.json"
if [[ ! -f "$RELEASE_FILE" ]]; then
  release=pending
else
  release_result="$(plutil -extract conclusion raw "$RELEASE_FILE" 2>/dev/null || print invalid)"
  [[ "$release_result" == "pass" ]] && release=pass || release=fail
fi

set +e
conclusion="$($BIN --evaluate-phase-one-gate \
  "automatic=$automatic" "manual=$manual" "soak=$soak" "release=$release" \
  --output "$OUTPUT_DIR/result.json")"
gate_exit=$?
set -e

{
  print '# Codex Account Manager Next 第一阶段毕业验收'
  print
  print "结论：**$conclusion**"
  print
  print '| 检查域 | 状态 |'
  print '| --- | --- |'
  print "| 自动化与隐私 | $automatic |"
  print "| 人工交互检查 | $manual |"
  print "| 8 小时稳定性 | $soak |"
  print "| 发布链路证据 | $release |"
  print
  print 'PENDING 表示证据尚未积累完成，不等同于失败。自动化日志位于 `logs/`。'
} >"$OUTPUT_DIR/report.md"

print "Phase One Gate: $conclusion"
print "Report: $OUTPUT_DIR/report.md"
[[ "$gate_exit" -eq 1 || "$gate_exit" -eq 64 || "$gate_exit" -eq 74 ]] && exit 1
exit 0
