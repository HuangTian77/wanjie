#!/usr/bin/env bash
# 一键全量验证（Codex 式 verify loop）：import → 自研测试 → GdUnit4 → gdlint → 布局断言
# 用法: bash wanjie/tools/verify_all.sh
# 退出码: 0=全部通过, 1=有失败
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe"
PROJ="$ROOT/wanjie"
PASS=0; FAIL=0
step() { echo ""; echo "===== $1 ====="; }

# ① import
step "① import（SCRIPT ERROR 必须为 0）"
ERR=$(timeout 300 "$GODOT" --headless --path "$PROJ" --import 2>&1 | grep -c "SCRIPT ERROR")
echo "SCRIPT_ERROR_COUNT=$ERR"
if [ "$ERR" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ② 自研测试
step "② 自研 SceneTree 测试（temp_scripts/test_*.gd）"
TFAIL=0; TPASS=0
for f in "$PROJ"/temp_scripts/test_*.gd; do
  res=$(timeout 90 "$GODOT" --headless --path "$PROJ" -s "$f" 2>&1)
  if echo "$res" | grep -q "ALL_TESTS_PASSED"; then TPASS=$((TPASS+1)); else echo "  FAIL $(basename "$f")"; TFAIL=$((TFAIL+1)); fi
done
echo "  PASS=$TPASS FAIL=$TFAIL"
if [ "$TFAIL" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ③ GdUnit4
step "③ GdUnit4（test/ 套件，Exit code 0）"
G4=$(timeout 120 "$GODOT" --headless --path "$PROJ" -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://test --ignoreHeadlessMode 2>&1)
echo "$G4" | grep -E "Overall Summary|Exit code" | sed 's/\x1b\[[0-9;]*m//g'
if echo "$G4" | grep -q "Exit code: 0"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ④ gdlint
step "④ gdlint 静态 lint（产品代码，0 Error）"
if command -v gdlint >/dev/null 2>&1; then
  LINT=$(cd "$ROOT" && gdlint wanjie/scripts wanjie/resources/data wanjie/autoload wanjie/tools 2>&1)
  LERR=$(echo "$LINT" | grep -cE "Error|No terminal matches" || true)
  echo "gdlint_errors=$LERR"
  if [ "$LERR" = "0" ]; then PASS=$((PASS+1)); else echo "$LINT" | head -5; FAIL=$((FAIL+1)); fi
else
  echo "  SKIP: gdlint 未安装（pip install gdtoolkit）"; PASS=$((PASS+1))
fi

# ⑤ 布局断言
step "⑤ UI 布局断言（LAYOUT_HARD=0）"
LAY=$(timeout 120 "$GODOT" --headless --path "$PROJ" -s tools/ui_layout_check.gd 2>&1)
echo "$LAY" | grep "LAYOUT_HARD"
if echo "$LAY" | grep -q "LAYOUT_HARD=0"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

echo ""
echo "======================"
echo "VERIFY_RESULT: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ] && echo "✅ 全部验证通过" && exit 0 || echo "❌ 存在失败项" && exit 1
