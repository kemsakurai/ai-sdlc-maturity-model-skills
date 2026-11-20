#!/usr/bin/env bash
# verify-assessment.sh の回帰テスト。
# 16 項目のスコア集計・検算（N/A 除外・軸別サマリ）と、証拠 JSON の検査（未取得 null・上限到達・矛盾件数）を検査する。
#
# 使い方: bash tests/verify_assessment_test.sh
# 必要なコマンド: bash, jq
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/skills/assessing-ai-sdlc-maturity/scripts/verify-assessment.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILED=0
pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILED=1; }

check_json() {
  local desc="$1" json="$2" expr="$3"
  if printf '%s' "$json" | jq -e "$expr" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc ($expr)"
  fi
}

# 1. 16 項目テストケース: [3,2,3,4,4,3,2,4,4,3,2,3,2,4,2,3] -> 中央値 3, 平均 3.00, 最小値 2
OUT="$(bash "$SCRIPT" --scores-json '[3,2,3,4,4,3,2,4,4,3,2,3,2,4,2,3]')"
check_json "16項目: valid が true" "$OUT" '.scores.valid == true'
check_json "16項目: count が 16" "$OUT" '.scores.overall.count == 16'
check_json "16項目: 中央値が 3" "$OUT" '.scores.overall.median == 3'
check_json "16項目: 平均が 3.00" "$OUT" '.scores.overall.mean == 3 and .scores.overall.mean_formatted == "3.00"'
check_json "16項目: 最小値が 2（B,G,K,M,O）" "$OUT" '.scores.overall.min == 2 and .scores.overall.min_items == ["B","G","K","M","O"]'
check_json "16項目: 軸別サマリ（ワークフロー・SDLC 統合: 2/3, AI 協働: 2/2.5）" "$OUT" '
  (.scores.axes[] | select(.name == "ワークフロー・SDLC 統合") | (.min == 2 and .median == 3)) and
  (.scores.axes[] | select(.name == "AI 協働") | (.min == 2 and .median == 2.5)) and
  (.scores.axes[] | select(.name == "事業インパクト・革新") | (.min == 2 and .median == 3))'

# 2. N/A 除外のテスト（L, M がすべて N/A で軸も N/A になるケース）
cat > "$WORK/na_scores.json" <<'JSON'
{"A":3,"B":3,"C":3,"D":4,"E":4,"F":3,"G":"N/A","H":"N/A","I":4,"J":3,"K":2,"L":"N/A","M":"N/A","N":4,"O":2,"P":3}
JSON
OUT="$(bash "$SCRIPT" --scores "$WORK/na_scores.json")"
check_json "N/A 除外: count が 12、na_items が G,H,L,M" "$OUT" '.scores.overall.count == 12 and .scores.na_items == ["G","H","L","M"]'
check_json "N/A 除外: すべて N/A の軸（AI 協働）は N/A" "$OUT" '.scores.axes[] | select(.name == "AI 協働") | (.min == "N/A" and .median == "N/A")'
check_json "N/A 除外: 平均の小数第2位フォーマット（37/12 = 3.08）" "$OUT" '.scores.overall.mean_formatted == "3.08"'

# 3. 不正入力の拒否
if bash "$SCRIPT" --scores-json '[3,2,3]' >/dev/null 2>&1; then
  fail "不正入力: 16要素未満を拒否"
else
  pass "不正入力: 16要素未満を拒否"
fi
if bash "$SCRIPT" --scores-json '{"A":6,"B":2,"C":3,"D":4,"E":4,"F":3,"G":2,"H":4,"I":4,"J":3,"K":2,"L":3,"M":2,"N":4,"O":2,"P":3}' >/dev/null 2>&1; then
  fail "不正入力: 範囲外（6）を拒否"
else
  pass "不正入力: 範囲外（6）を拒否"
fi

# 4. 証拠 JSON 検査（未取得 null・上限到達 500/1000・矛盾件数 c.adr_count < p.adr_recent_count_window）
cat > "$WORK/evidence.json" <<'JSON'
{
  "header": {
    "collection_errors": ["l.pr_review_stats_window"]
  },
  "evidence": {
    "b.issues_closed_count": {"value": 1000, "limit": 1000},
    "c.adr_count": {"value": 107, "limit": null},
    "p.adr_recent_count_window": {"value": 115, "limit": null},
    "d.commit_count_total": {"value": 2292, "limit": null},
    "d.commits_window": {"value": 2115, "limit": null},
    "k.coauthored_count": {"value": 1579, "limit": null},
    "k.coauthored_by_model": {"value": [1,2,3,4,5,6,7,8,9,10], "limit": 10},
    "f.deploy_runs": {"value": {"deploy-mcp.yml": {"success": 459, "failure": 41}}, "limit": 500},
    "l.pr_review_stats_window": {"value": null, "error": "HTTP 502", "limit": 500}
  }
}
JSON
OUT="$(bash "$SCRIPT" --evidence "$WORK/evidence.json")"
check_json "証拠検査: 未取得キー（null）を検出" "$OUT" '[.evidence_checks.uncollected_keys[].key] == ["l.pr_review_stats_window"]'
check_json "証拠検査: 上限到達（1000, 500, 10）を検出" "$OUT" '([.evidence_checks.limit_reached[].key] | sort) == ["b.issues_closed_count", "f.deploy_runs", "k.coauthored_by_model"]'
check_json "証拠検査: 矛盾件数（c.adr_count < p.adr_recent_count_window）を検出" "$OUT" '(.evidence_checks.anomalies | length) == 1 and .evidence_checks.anomalies[0].keys == ["c.adr_count", "p.adr_recent_count_window"]'

if [ "$FAILED" -ne 0 ]; then echo "テストに失敗しました"; exit 1; fi
echo "すべてのテストに合格しました"
