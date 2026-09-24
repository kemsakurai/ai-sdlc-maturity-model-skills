#!/usr/bin/env bash
# =============================================================================
# 証拠収集スクリプト（読み取り専用、criteria.md 0.0.1 準拠）
# このファイルは assessing-ai-sdlc-maturity スキルによりプロジェクト固有に生成されました。
# https://github.com/kemsakurai/ai-sdlc-maturity-model-skills
#
# 使い方: collect-evidence.sh [対象リポジトリのパス] [--window-days N]
# =============================================================================
set -u

CRITERIA_VERSION="0.0.1"
SKILL_VERSION="0.0.1"
WINDOW_DAYS=90
TARGET_PATH="."

while [ $# -gt 0 ]; do
  case "$1" in
    --window-days)
      WINDOW_DAYS="$2"
      shift 2
      ;;
    *)
      TARGET_PATH="$1"
      shift
      ;;
  esac
done

if [ -n "$TARGET_PATH" ] && [ "$TARGET_PATH" != "." ]; then
  cd "$TARGET_PATH" || { echo "エラー: $TARGET_PATH に移動できません" >&2; exit 1; }
fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "エラー: $(pwd) は git リポジトリではない" >&2; exit 1; }

# =============================================================================
# [プロジェクト固有設定ブロック] - 初回プロファイリング時に自動調整されます
# =============================================================================
# ADR（設計決定記録）ディレクトリ
ADR_DIR="{{ADR_DIR}}"

# 変更履歴・リリースログのファイルパス
CHANGELOG_FILE="{{CHANGELOG_FILE}}"

# ルール履歴ドキュメントのパス候補（空白区切り）
RULE_HISTORY_FILES="{{RULE_HISTORY_FILES}}"

# テストファイルの探索パターン（find コマンド用 glob または条件式）
# 例: -name 'test_*.py' -o -name '*.test.ts' -o -name '*_test.go'
TEST_FILE_FIND_EXPR='{{TEST_FILE_FIND_EXPR}}'

# テストケース（関数・メソッド）のカウント用 grep 正規表現
# 例: 'def test_|it\(|test\('
TEST_CASE_REGEX='{{TEST_CASE_REGEX}}'

# カバレッジ設定ファイル・CIゲートの検索語句
COVERAGE_GATE_FILES="{{COVERAGE_GATE_FILES}}"

# アーキテクチャ静的検査設定ファイル
ARCH_LINT_CONFIG_FILES="{{ARCH_LINT_CONFIG_FILES}}"
ARCH_LINT_ENFORCE_PATTERN='{{ARCH_LINT_ENFORCE_PATTERN}}'

# デプロイ・リリース関連ワークフローのパターン
DEPLOY_WORKFLOW_REGEX='{{DEPLOY_WORKFLOW_REGEX}}'

# ロールバックドキュメントの探索パス
ROLLBACK_DOC_FILES="{{ROLLBACK_DOC_FILES}}"

# 監視・死活監視の設定・スクリプト探索パターン
MONITORING_PATTERNS='{{MONITORING_PATTERNS}}'

# データ・スキーマ・モデル管理に関連する Issue ラベル正規表現
DATA_LABELS_REGEX='{{DATA_LABELS_REGEX}}'

# ユーザーリサーチ・検証に関連するキーワード正規表現（Issue/ラベル）
USER_RESEARCH_REGEX='{{USER_RESEARCH_REGEX}}'

# ふりかえり・継続的改善のキーワード正規表現（ドキュメント/PRタイトル）
RETRO_DOC_REGEX='{{RETRO_DOC_REGEX}}'
RETRO_PR_SEARCH='{{RETRO_PR_SEARCH}}'

# 価値計測・定量的改善のキーワード正規表現（ドキュメント/ログ）
VALUE_METRIC_REGEX='{{VALUE_METRIC_REGEX}}'
QUANTITATIVE_IMPACT_REGEX='{{QUANTITATIVE_IMPACT_REGEX}}'

# ロードマップ・探索のラベル正規表現
ROADMAP_LABELS_REGEX='{{ROADMAP_LABELS_REGEX}}'

# 設計・運用ドキュメントを置くディレクトリ（空白区切り。ふりかえり・価値計測・監視の検索対象）
DOC_DIRS="{{DOC_DIRS}}"
# =============================================================================

TMP_JSONL="$(mktemp)"
trap 'rm -f "$TMP_JSONL"' EXIT

RUN_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ASSESSED_DATE="$(date -u +%Y-%m-%d)"

compute_window_start() {
  local end_date="$1" days="$2"
  if date -d "$end_date - $days days" +%Y-%m-%d >/dev/null 2>&1; then
    date -d "$end_date - $days days" +%Y-%m-%d
  else
    date -j -v-"${days}"d -f %Y-%m-%d "$end_date" +%Y-%m-%d
  fi
}

WINDOW_START="$(compute_window_start "$ASSESSED_DATE" "$WINDOW_DAYS")"
WINDOW_END="$ASSESSED_DATE"

HEAD_SHA="$(git rev-parse HEAD)"
REPO_NWO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
if [ -z "$REPO_NWO" ]; then
  REPO_NWO="$(git remote get-url origin 2>/dev/null | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#' || true)"
fi
AUTHORS_TOP5_JSON="$(git log --format='%an' | sort | uniq -c | sort -rn | head -5 | \
  jq -R -s 'split("\n") | map(select(length>0)) | map(capture("^\\s*(?<count>[0-9]+)\\s+(?<author>.+)$")) | map({author: .author, count: (.count|tonumber)})')"
SINGLE_AUTHOR="$(echo "$AUTHORS_TOP5_JSON" | jq 'length <= 1')"

# emit <key> <command> <limit-or-empty> <value-json>
emit() {
  local key="$1" cmd="$2" limit="$3" value_json="$4"
  jq -n --arg k "$key" --arg cmd "$cmd" --arg limit "$limit" --arg ts "$RUN_TS" --argjson v "$value_json" \
    '{($k): {value: $v, command: $cmd, limit: (if $limit == "" then null else ($limit | tonumber? // $limit) end), collected_at: $ts}}' \
    >> "$TMP_JSONL"
}

json_bool() { [ "$1" = "1" ] && echo true || echo false; }
json_int() { echo "${1:-0}" | tr -d '[:space:]' | sed 's/^$/0/'; }
lines_to_array() { jq -R -s 'split("\n") | map(select(length>0))'; }

# ---------------------------------------------------------------------------
# A. エージェント運用知識の蓄積と継承
# ---------------------------------------------------------------------------
A_FILES=()
for f in AGENTS.md CLAUDE.md .agents .claude .cursor .github/copilot-instructions.md; do
  [ -e "$f" ] && A_FILES+=("$f")
done
A_FILES_JSON="$(printf '%s\n' "${A_FILES[@]:-}" | lines_to_array)"
emit "a.agent_instruction_files" \
  "ls AGENTS.md CLAUDE.md .agents .claude .cursor .github/copilot-instructions.md" "" "$A_FILES_JSON"

A_SKILLS_COUNT="$({ ls .agents/skills .claude/skills skills 2>/dev/null || true; } | sort -u | wc -l | tr -d ' ')"
emit "a.skills_count" "ls .agents/skills .claude/skills skills | sort -u | wc -l" "" "$(json_int "$A_SKILLS_COUNT")"

A_RULE_HISTORY="0"
for rf in ${RULE_HISTORY_FILES:-docs/rule-history.md rule-history.md}; do
  [ -f "$rf" ] && { A_RULE_HISTORY="1"; break; }
done
emit "a.rule_history_doc_present" "check rule-history docs" "" "$(json_bool "$A_RULE_HISTORY")"

# ---------------------------------------------------------------------------
# B. 要件定義
# ---------------------------------------------------------------------------
B_ISSUE_TMPL="0"; { [ -d .github/ISSUE_TEMPLATE ] || [ -f .github/issue_template.md ]; } && B_ISSUE_TMPL="1"
emit "b.issue_template_exists" "check issue templates" "" "$(json_bool "$B_ISSUE_TMPL")"

B_PR_TMPL="0"; { [ -f .github/pull_request_template.md ] || [ -f .github/PULL_REQUEST_TEMPLATE.md ] || [ -d .github/PULL_REQUEST_TEMPLATE ]; } && B_PR_TMPL="1"
emit "b.pr_template_exists" "check pr templates" "" "$(json_bool "$B_PR_TMPL")"

B_OPEN="$(gh issue list --state open --limit 500 --json number -q 'length' 2>/dev/null || echo 0)"
emit "b.issues_open_count" "gh issue list --state open --limit 500 --json number -q 'length'" "500" "$(json_int "$B_OPEN")"

B_CLOSED="$(gh issue list --state closed --limit 1000 --json number -q 'length' 2>/dev/null || echo 0)"
emit "b.issues_closed_count" "gh issue list --state closed --limit 1000 --json number -q 'length'" "1000" "$(json_int "$B_CLOSED")"

# ---------------------------------------------------------------------------
# C. システム設計・アーキテクチャ
# ---------------------------------------------------------------------------
ADR_TARGET="${ADR_DIR:-docs/adr}"
C_ADR_COUNT="$(ls "$ADR_TARGET" 2>/dev/null | grep -c '\.md$' || true)"
emit "c.adr_count" "ls $ADR_TARGET | grep '\\.md$' | wc -l" "" "$(json_int "$C_ADR_COUNT")"

C_ADR_DUP_JSON="$(ls "$ADR_TARGET" 2>/dev/null | grep '\.md$' | cut -c1-4 | sort | uniq -d | lines_to_array)"
emit "c.adr_duplicates" "ls $ADR_TARGET | cut -c1-4 | sort | uniq -d" "" "$C_ADR_DUP_JSON"

C_ARCH_CFG="0"
for af in ${ARCH_LINT_CONFIG_FILES:-.importlinter .dependency-cruiser.*}; do
  ls $af >/dev/null 2>&1 && { C_ARCH_CFG="1"; break; }
done
emit "c.arch_lint_configured" "check arch lint configs" "" "$(json_bool "$C_ARCH_CFG")"

C_ARCH_ENFORCED="0"
ARCH_ENFORCE_PTN="${ARCH_LINT_ENFORCE_PATTERN:-lint-imports|import-linter|depcruise}"
{ grep -rEn "$ARCH_ENFORCE_PTN" .pre-commit-config.yaml Taskfile.yml Makefile .github/workflows >/dev/null 2>&1; } && C_ARCH_ENFORCED="1"
emit "c.arch_lint_enforced" "grep arch lint in pre-commit / Taskfile / CI" "" "$(json_bool "$C_ARCH_ENFORCED")"

# ---------------------------------------------------------------------------
# D. コーディング・開発
# ---------------------------------------------------------------------------
D_COMMIT_TOTAL="$(git rev-list --count HEAD)"
emit "d.commit_count_total" "git rev-list --count HEAD" "" "$(json_int "$D_COMMIT_TOTAL")"

D_COMMITS_WINDOW="$(git log --since="$WINDOW_START" --oneline | wc -l | tr -d ' ')"
emit "d.commits_window" "git log --since=<window-start> --oneline | wc -l" "" "$(json_int "$D_COMMITS_WINDOW")"

D_BY_MONTH_JSON="$(git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c | tail -12 | \
  jq -R -s 'split("\n") | map(select(length>0)) | map(capture("^\\s*(?<count>[0-9]+)\\s+(?<month>.+)$")) | map({(.month): (.count|tonumber)}) | add // {}')"
emit "d.commits_by_month" "git log --format='%ad' --date=format:'%Y-%m' | sort | uniq -c | tail -12" "12" "$D_BY_MONTH_JSON"

D_PR_COMMITS_WINDOW="$(git log --since="$WINDOW_START" --format='%s' | grep -c '(#[0-9]*)' || true)"
if [ "${D_COMMITS_WINDOW:-0}" -gt 0 ]; then
  D_PR_RATIO="$(jq -n --argjson a "${D_PR_COMMITS_WINDOW:-0}" --argjson b "$D_COMMITS_WINDOW" '(($a/$b)*1000|round)/1000')"
else
  D_PR_RATIO="null"
fi
emit "d.pr_commit_ratio_window" "git log --since=<window-start> --format='%s' | grep -c '(#[0-9]*)' / commits_window" "" "$D_PR_RATIO"

# ---------------------------------------------------------------------------
# E. テスト・QA
# ---------------------------------------------------------------------------
# 除外ディレクトリ
EXCLUDE_DIRS="-path '*/node_modules' -o -path '*/.worktrees' -o -path '*/.claude/worktrees' -o -path '*/.git' -o -path '*/vendor'"

# テストファイルの検索
if [ -n "$TEST_FILE_FIND_EXPR" ]; then
  E_TEST_FILES="$(eval "find . \\( $EXCLUDE_DIRS \\) -prune -o \\( $TEST_FILE_FIND_EXPR \\) -print" 2>/dev/null | wc -l | tr -d ' ')"
else
  # デフォルト: Python/JS/TS/Go/Rust 共通パターン
  E_TEST_FILES="$(find . \( -path '*/node_modules' -o -path '*/.worktrees' -o -path '*/.git' -o -path '*/vendor' \) -prune -o \( -name 'test_*.py' -o -name '*_test.py' -o -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' -o -name '*_test.go' -o -name 'test_*.rs' \) -print 2>/dev/null | wc -l | tr -d ' ')"
fi
emit "e.test_files_count" "find test files" "" "$(json_int "$E_TEST_FILES")"

# テストケースの検索
E_CASE_REGEX="${TEST_CASE_REGEX:-def test_|it\(|test\(|func Test|#\[test\]}"
if [ -n "$TEST_FILE_FIND_EXPR" ]; then
  E_TEST_CASES="$(eval "find . \\( $EXCLUDE_DIRS \\) -prune -o \\( $TEST_FILE_FIND_EXPR \\) -print" 2>/dev/null | xargs grep -c -E "$E_CASE_REGEX" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
else
  E_TEST_CASES="$(find . \( -path '*/node_modules' -o -path '*/.worktrees' -o -path '*/.git' -o -path '*/vendor' \) -prune -o \( -name 'test_*.py' -o -name '*_test.py' -o -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' -o -name '*_test.go' -o -name 'test_*.rs' \) -print 2>/dev/null | xargs grep -c -E "$E_CASE_REGEX" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
fi
emit "e.test_cases_count" "grep test cases across test files" "" "$(json_int "$E_TEST_CASES")"

E_COV_GATE="0"
COV_FILES="${COVERAGE_GATE_FILES:-pytest.ini .coveragerc Taskfile.yml Makefile .github/workflows/*.yml}"
{ grep -rnE 'fail-under|fail_under|cov-fail|minimum-coverage' $COV_FILES >/dev/null 2>&1; } && E_COV_GATE="1"
emit "e.coverage_gate_configured" "check coverage gate in config/workflows" "" "$(json_bool "$E_COV_GATE")"

# ---------------------------------------------------------------------------
# F. デプロイ・リリース
# ---------------------------------------------------------------------------
DEPLOY_WF_PTN="${DEPLOY_WORKFLOW_REGEX:-deploy|release|cd|publish}"
F_SMOKE=0
DEPLOY_FILES="$(ls .github/workflows 2>/dev/null | grep -iE "$DEPLOY_WF_PTN" || true)"
if [ -n "$DEPLOY_FILES" ]; then
  for df in $DEPLOY_FILES; do
    c="$(grep -c -iE 'smoke|curl|health|verify' ".github/workflows/$df" 2>/dev/null || true)"
    F_SMOKE=$((F_SMOKE + c))
  done
fi
emit "f.smoke_steps" "grep smoke/health/verify in deploy workflows" "" "$(json_int "$F_SMOKE")"

F_ROLLBACK="0"
# ワークフロー内またはドキュメント内でのロールバック記載
{ ls .github/workflows 2>/dev/null | grep -iE "$DEPLOY_WF_PTN" | xargs -I{} grep -qli 'rollback' ".github/workflows/{}" 2>/dev/null; } && F_ROLLBACK="1"
for rbd in ${ROLLBACK_DOC_FILES:-docs/rollback.md docs/ops/rollback.md}; do
  [ -f "$rbd" ] && { F_ROLLBACK="1"; break; }
done
emit "f.rollback_doc_present" "check rollback documentation in workflows and docs" "" "$(json_bool "$F_ROLLBACK")"

F_DEPLOY_RUNS_JSON="{}"
if [ -n "$DEPLOY_FILES" ]; then
  for w in $DEPLOY_FILES; do
    CONCL_JSON="$(gh run list --workflow "$w" --created ">=$WINDOW_START" -L 500 --json conclusion -q '.[].conclusion' 2>/dev/null | \
      sort | uniq -c | jq -R -s 'split("\n") | map(select(length>0)) | map(capture("^\\s*(?<count>[0-9]+)\\s+(?<c>.+)$")) | map({(.c): (.count|tonumber)}) | add // {}')"
    F_DEPLOY_RUNS_JSON="$(jq -n --argjson base "$F_DEPLOY_RUNS_JSON" --arg w "$w" --argjson c "$CONCL_JSON" '$base + {($w): $c}')"
  done
fi
emit "f.deploy_runs" "gh run list for deploy workflows in window" "500" "$F_DEPLOY_RUNS_JSON"

# ---------------------------------------------------------------------------
# G. 監視・インシデント対応
# ---------------------------------------------------------------------------
G_MONITORING="0"
MON_PTN="${MONITORING_PATTERNS:-sentry|uptime|alert|healthcheck|health-check|datadog|newrelic}"
{ grep -rliE "$MON_PTN" .github/workflows terraform scripts ${DOC_DIRS:-docs .agents} >/dev/null 2>&1; } && G_MONITORING="1"
emit "g.monitoring_configured" "check monitoring configuration" "" "$(json_bool "$G_MONITORING")"

G_INCIDENT_COUNT="$(gh issue list --state all --search "created:>=$WINDOW_START" --json labels -q \
  '[.[] | select([.labels[].name] | any(test("incident|postmortem";"i")))] | length' 2>/dev/null || echo 0)"
emit "g.incident_labeled_issues_count" "gh issue list with incident/postmortem labels in window" "" "$(json_int "$G_INCIDENT_COUNT")"

# ---------------------------------------------------------------------------
# H. データ管理
# ---------------------------------------------------------------------------
DATA_PTN="${DATA_LABELS_REGEX:-license|ingest|dataset|data-pipeline|schema}"
H_DATA_LABELS="$(gh issue list --state all --limit 1000 --json labels -q '.[].labels[].name' 2>/dev/null | grep -ciE "$DATA_PTN" || true)"
emit "h.data_management_labels_count" "gh issue list labels matching data management keywords" "1000" "$(json_int "$H_DATA_LABELS")"

H_DATA_GATE="0"
{ grep -rnE 'validate-data|drift|integrity|schema-check' Taskfile.yml Makefile .pre-commit-config.yaml .github/workflows >/dev/null 2>&1; } && H_DATA_GATE="1"
emit "h.data_integrity_gate_configured" "check data/schema integrity gate" "" "$(json_bool "$H_DATA_GATE")"

# ---------------------------------------------------------------------------
# I. 開発環境・パイプラインへの AI 組み込み
# ---------------------------------------------------------------------------
I_FILES=()
for f in .claude/settings.json .cursor .cursorrules .github/copilot-instructions.md .gemini; do
  [ -e "$f" ] && I_FILES+=("$f")
done
I_FILES_JSON="$(printf '%s\n' "${I_FILES[@]:-}" | lines_to_array)"
emit "i.tool_integration_files" "check AI tool config files" "" "$I_FILES_JSON"

I_LOCAL_HOOKS="$(grep -c 'repo: local' .pre-commit-config.yaml 2>/dev/null || true)"
I_LOCAL_HOOKS="$(json_int "$I_LOCAL_HOOKS")"
emit "i.local_guardrail_hooks_count" "count local pre-commit/guardrail hooks" "" "$I_LOCAL_HOOKS"

# ---------------------------------------------------------------------------
# J. AI 利用ポリシーと機械的強制
# ---------------------------------------------------------------------------
J_GOV="0"
for gf in AGENTS.md CLAUDE.md docs/ai-policy.md docs/governance.md docs/ai-guidelines.md; do
  [ -f "$gf" ] && { J_GOV="1"; break; }
done
emit "j.governance_docs_present" "check governance docs" "" "$(json_bool "$J_GOV")"

J_DEPENDABOT="0"
{ [ -f .github/dependabot.yml ] || [ -f .github/renovate.json ] || [ -f renovate.json ]; } && J_DEPENDABOT="1"
emit "j.dependabot_or_renovate_present" "check dependabot/renovate" "" "$(json_bool "$J_DEPENDABOT")"

J_CODEQL="0"
{ ls .github/workflows 2>/dev/null | grep -iE 'codeql|security|audit|snyk' >/dev/null 2>&1; } && J_CODEQL="1"
emit "j.codeql_security_workflow_present" "check security/codeql workflows" "" "$(json_bool "$J_CODEQL")"

# ---------------------------------------------------------------------------
# K. 透明性・監査証跡
# ---------------------------------------------------------------------------
K_COAUTHORED="$(git log --format='%b' | grep -c 'Co-Authored-By' || true)"
emit "k.coauthored_count" "git log --format='%b' | grep -c 'Co-Authored-By'" "" "$(json_int "$K_COAUTHORED")"

K_BY_MODEL_JSON="$(git log --format='%b' | grep -o 'Co-Authored-By: [^<]*' | sort | uniq -c | sort -rn | head | \
  jq -R -s 'split("\n") | map(select(length>0)) | map(capture("^\\s*(?<count>[0-9]+)\\s+Co-Authored-By:\\s*(?<model>.+)$")) | map({model: .model, count: (.count|tonumber)})')"
emit "k.coauthored_by_model" "git log Co-Authored-By top models" "10" "$K_BY_MODEL_JSON"

if [ "${D_COMMIT_TOTAL:-0}" -gt 0 ]; then
  K_RATIO="$(jq -n --argjson a "${K_COAUTHORED:-0}" --argjson b "$D_COMMIT_TOTAL" '(($a/$b)*1000|round)/1000')"
else
  K_RATIO="null"
fi
emit "k.coauthored_ratio_lower_bound" "coauthored_count / commit_count_total" "" "$K_RATIO"

# ---------------------------------------------------------------------------
# L. 人間–AI・AI–AI の協働プロトコル
# ---------------------------------------------------------------------------
L_PR_STATS_JSON="$(gh pr list --state merged --search "merged:>=$WINDOW_START" --json mergedAt,reviews,comments,additions -L 500 -q \
  '{count: length, with_review: ([.[] | select(.reviews|length>0)]|length), with_comments: ([.[] | select(.comments|length>0)]|length), avg_additions: (if length>0 then (([.[].additions]|add)/length|floor) else 0 end)}' 2>/dev/null || echo '{}')"
emit "l.pr_review_stats_window" "gh pr list merged review stats in window" "500" "$L_PR_STATS_JSON"

L_PR_AUTHORS_JSON="$(gh pr list --state merged --search "merged:>=$WINDOW_START" --json author -L 500 -q '.[].author.login' 2>/dev/null | \
  sort | uniq -c | jq -R -s 'split("\n") | map(select(length>0)) | map(capture("^\\s*(?<count>[0-9]+)\\s+(?<author>.+)$")) | map({author: .author, count: (.count|tonumber)})' || echo '[]')"
emit "l.pr_authors_window" "gh pr list merged authors in window" "500" "$L_PR_AUTHORS_JSON"

# ---------------------------------------------------------------------------
# M. 合成ユーザーリサーチ
# ---------------------------------------------------------------------------
UR_PTN="${USER_RESEARCH_REGEX:-persona|ペルソナ|user-research|ux-research|user-interview}"
M_UR_ISSUES="$(gh issue list --state all --search "created:>=$WINDOW_START $UR_PTN" --json number -q 'length' 2>/dev/null || echo 0)"
emit "m.user_research_issues_count" "gh issue list user research issues in window" "" "$(json_int "$M_UR_ISSUES")"

M_UR_LABELS="$(gh issue list --state all --limit 1000 --json labels -q '.[].labels[].name' 2>/dev/null | grep -ciE "$UR_PTN" || true)"
emit "m.user_research_labels_count" "gh issue list labels matching user research" "1000" "$(json_int "$M_UR_LABELS")"

# ---------------------------------------------------------------------------
# N. 継続的改善のフィードバックループ
# ---------------------------------------------------------------------------
RETRO_DOC_PTN="${RETRO_DOC_REGEX:-ふりかえり|retrospect|retro|postmortem}"
N_RETRO_DOCS="$(grep -rliE "$RETRO_DOC_PTN" ${DOC_DIRS:-docs .agents} 2>/dev/null | wc -l | tr -d ' ')"
emit "n.retro_docs_count" "grep retro docs in DOC_DIRS" "" "$(json_int "$N_RETRO_DOCS")"

CHANGELOG_TARGET="${CHANGELOG_FILE:-CHANGELOG.md}"
N_CHANGELOG_LINES="$(wc -l "$CHANGELOG_TARGET" 2>/dev/null | awk '{print $1+0}' || echo 0)"
emit "n.changelog_lines" "wc -l $CHANGELOG_TARGET" "" "$(json_int "$N_CHANGELOG_LINES")"

RETRO_PR_SEARCH_PTN="${RETRO_PR_SEARCH:-棚卸し OR retro OR retrospective in:title}"
N_RETRO_PRS="$(gh pr list --state merged --search "merged:>=$WINDOW_START $RETRO_PR_SEARCH_PTN" --json number -q 'length' 2>/dev/null || echo 0)"
emit "n.retro_prs_window_count" "gh pr list retro PRs in window" "" "$(json_int "$N_RETRO_PRS")"

# ---------------------------------------------------------------------------
# O. 価値計測
# ---------------------------------------------------------------------------
VAL_PTN="${VALUE_METRIC_REGEX:-lead time|リードタイム|サイクルタイム|cycle time|throughput|スループット|latency}"
O_VALUE_MENTIONS="$(grep -rnE -i "$VAL_PTN" ${DOC_DIRS:-docs .agents} --include='*.md' 2>/dev/null | wc -l | tr -d ' ')"
emit "o.value_metric_mentions_count" "grep value metrics mentions in docs" "" "$(json_int "$O_VALUE_MENTIONS")"

Q_PTN="${QUANTITATIVE_IMPACT_REGEX:-秒|分短縮|→|[0-9]+% (reduction|faster|speedup)}"
O_MEASUREMENT_LINES="$(grep -nE -i "$Q_PTN" "$CHANGELOG_TARGET" 2>/dev/null | wc -l | tr -d ' ')"
emit "o.changelog_measurement_lines_count" "grep quantitative impact in changelog" "" "$(json_int "$O_MEASUREMENT_LINES")"

# ---------------------------------------------------------------------------
# P. ビジョンと適応
# ---------------------------------------------------------------------------
ROADMAP_PTN="${ROADMAP_LABELS_REGEX:-roadmap|explore|探索|rfc|proposal}"
P_ROADMAP_LABELS="$(gh issue list --state all --limit 1000 --json labels -q '.[].labels[].name' 2>/dev/null | grep -ciE "$ROADMAP_PTN" || true)"
emit "p.roadmap_label_count" "gh issue list labels matching roadmap/explore" "1000" "$(json_int "$P_ROADMAP_LABELS")"

P_ADR_RECENT="$(git log --since="$WINDOW_START" --name-only --format='' -- "$ADR_TARGET" 2>/dev/null | grep -c '\.md$' || true)"
emit "p.adr_recent_count_window" "git log recent ADR changes in window" "" "$(json_int "$P_ADR_RECENT")"

# ---------------------------------------------------------------------------
# 出力
# ---------------------------------------------------------------------------
EVIDENCE_JSON="$(jq -s 'reduce .[] as $item ({}; . + $item)' "$TMP_JSONL")"

jq -n \
  --arg repo "$REPO_NWO" \
  --arg head "$HEAD_SHA" \
  --arg assessed_at "$ASSESSED_DATE" \
  --arg criteria_version "$CRITERIA_VERSION" \
  --arg skill_version "$SKILL_VERSION" \
  --arg window_start "$WINDOW_START" \
  --arg window_end "$WINDOW_END" \
  --argjson window_days "$WINDOW_DAYS" \
  --argjson authors_top5 "$AUTHORS_TOP5_JSON" \
  --argjson single_author "$SINGLE_AUTHOR" \
  --argjson evidence "$EVIDENCE_JSON" \
  '{
    header: {
      repository: $repo,
      head_sha: $head,
      assessed_at: $assessed_at,
      criteria_version: $criteria_version,
      skill_version: $skill_version,
      window: {start: $window_start, end: $window_end, days: $window_days},
      authors_top5: $authors_top5,
      single_author: $single_author
    },
    evidence: $evidence
  }'
