#!/usr/bin/env bash
# collect-evidence.template.sh の回帰テスト。
# 境界ケースを入れた使い捨ての git リポジトリを作り、テンプレートから生成したスクリプトの出力を検査する。
# GitHub API には触れない。PATH の先頭に偽の gh を置き、成功・一時的な失敗・継続的な失敗を再現する。
#
# 使い方: bash tests/template_test.sh
# 必要なコマンド: bash, git (2.22 以上), jq
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$ROOT/skills/assessing-ai-sdlc-maturity/templates/collect-evidence.template.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILED=0
pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILED=1; }

# check <説明> <JSON ファイル> <jq の条件式>
check() {
  if jq -e "$3" "$2" >/dev/null 2>&1; then pass "$1"; else fail "$1 ($3)"; fi
}

# GitHub から取る 11 キー
GH_KEYS='["b.issues_closed_count","b.issues_open_count","f.deploy_runs","g.incident_labeled_issues_count","h.data_management_labels_count","l.pr_authors_window","l.pr_review_stats_window","m.user_research_issues_count","m.user_research_labels_count","n.retro_prs_window_count","p.roadmap_label_count"]'

# --- 偽の gh ----------------------------------------------------------------
# FAKE_GH_MODE で振る舞いを切り替える。呼ばれた回数を FAKE_GH_COUNTER に数える。
#   noremote : 常に「リモートが無い」で失敗する（再試行しても直らない失敗）
#   ok       : 常に成功する
#   flaky    : 奇数回目の呼び出しは HTTP 502 で失敗し、偶数回目は成功する（一時的な失敗）
#   down     : repo view だけ成功し、ほかは常に HTTP 502 で失敗する（継続的な失敗）
#   notfound : repo view だけ成功し、ほかは常に HTTP 404 で失敗する（再試行しても直らない失敗）
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
n=$(( $(cat "$FAKE_GH_COUNTER" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE_GH_COUNTER"
succeed() {
  case " $* " in
    *" repo view "*) echo "example/repo" ;;
    *" -q "*"length"*) echo "3" ;;
    *" -q "*"conclusion"*) printf 'success\nsuccess\nfailure\n' ;;
    *" -q "*) printf 'dataset\nroadmap\n' ;;
    *) echo '[{"reviews":[1],"comments":[],"additions":10,"author":{"login":"bob"}}]' ;;
  esac
  exit 0
}
case "${FAKE_GH_MODE:-noremote}" in
  noremote) echo "no git remotes found" >&2; exit 1 ;;
  ok) succeed "$@" ;;
  flaky) [ $(( n % 2 )) -eq 0 ] && succeed "$@"; echo "HTTP 502: Bad Gateway" >&2; exit 1 ;;
  down) [ "$1 $2" = "repo view" ] && succeed "$@"; echo "HTTP 502: Bad Gateway" >&2; exit 1 ;;
  notfound) [ "$1 $2" = "repo view" ] && succeed "$@"; echo "HTTP 404: Not Found" >&2; exit 1 ;;
esac
FAKE_GH
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"
export FAKE_GH_COUNTER="$WORK/gh-calls"
export GH_RETRY_SLEEP=0

# only_warnings <stderr ファイル> : stderr に、取得できなかったキーの警告以外が出ていなければ 0
only_warnings() { ! grep -vE '^警告: |^  - ' "$1" >/dev/null; }

# --- テンプレートから 2 通りのスクリプトを生成する -------------------------------
# default: すべての {{...}} を空にする（スクリプト内の既定値を使う）
sed -E 's/\{\{[A-Z_]+\}\}//g' "$TPL" > "$WORK/default.sh"
# example: 設定ブロックのコメントにある例をそのまま埋める
sed -E \
  -e 's#\{\{TEST_FILE_FIND_EXPR\}\}#-name "test_*.py" -o -name "*.test.ts" -o -name "*_test.go"#' \
  -e 's#\{\{TEST_CASE_REGEX\}\}#def test_|it\\(|test\\(#' \
  -e 's/\{\{[A-Z_]+\}\}//g' "$TPL" > "$WORK/example.sh"

for v in default example; do
  if bash -n "$WORK/$v.sh"; then pass "$v: bash -n"; else fail "$v: bash -n"; fi
done

# --- 境界ケースを入れたリポジトリを作る ---------------------------------------
REPO="$WORK/repo"
mkdir -p "$REPO"
(
  cd "$REPO" || exit 1
  git init -q -b main
  git config user.name "Alice Example"
  git config user.email alice@example.com
  git config commit.gpgsign false

  mkdir -p docs/adr tests .github/workflows .claude/worktrees/x/tests
  # ADR: 索引・テンプレートは数えない。adr-NNN 形式と NNNN 形式が混ざり、3 番が重複している
  printf '# index\n' > docs/adr/README.md
  printf '# template\n' > docs/adr/template.md
  printf 'a\n' > docs/adr/adr-001-a.md
  printf 'b\n' > docs/adr/adr-002-b.md
  printf 'c\n' > docs/adr/0003-c.md
  printf 'd\n' > docs/adr/0003-d.md
  # テストファイルは 1 件だけ（worktree 内の同じファイルは数えない）
  printf 'def test_a():\n    pass\ndef test_b():\n    pass\n' > tests/test_x.py
  cp tests/test_x.py .claude/worktrees/x/tests/test_x.py
  # 検査を呼ぶのは pre-commit だけ（Taskfile / Makefile は無い）
  printf 'repos:\n- repo: local\n  hooks:\n  - id: lint-imports\n    entry: lint-imports\n  - id: drift\n    entry: check-drift\n' > .pre-commit-config.yaml
  printf '[importlinter]\n' > .importlinter
  # デプロイ系ワークフロー 2 件。rollback の記載は片方だけ
  printf 'jobs:\n  a:\n    steps:\n    - run: curl health\n' > .github/workflows/deploy-a.yml
  printf 'jobs:\n  b:\n    steps:\n    - run: echo rollback\n' > .github/workflows/deploy-b.yml

  git add -A
  git commit -q -m "init"
  # AI と人間の共著者が混在。キーの大文字小文字も混在
  git commit -q --allow-empty -m "feat: x (#1)

Co-authored-by: Claude Opus <noreply@anthropic.com>
Co-authored-by: Human Friend <friend@example.com>"
  git commit -q --allow-empty -m "feat: y

Co-Authored-By: GitHub Copilot <copilot@github.com>"
  git commit -q --allow-empty -m "chore: z

Co-authored-by: Only Human <h@example.com>"
  # merge commit 方式の PR
  git checkout -q -b topic
  git commit -q --allow-empty -m "topic work"
  git checkout -q main
  git merge -q --no-ff topic -m "Merge pull request #2 from x/topic"
) || { echo "fixture の作成に失敗"; exit 1; }

# --- 実行して検査する -------------------------------------------------------
for v in default example; do
  OUT="$WORK/$v.json"
  FAKE_GH_MODE=noremote bash "$WORK/$v.sh" "$REPO" > "$OUT" 2> "$WORK/$v.err"
  if only_warnings "$WORK/$v.err"; then pass "$v: stderr は取得失敗の警告だけ"; else fail "$v: stderr は取得失敗の警告だけ"; sed 's/^/     /' "$WORK/$v.err"; fi
  check "$v: 証拠キーが 44 個"                 "$OUT" '.evidence | length == 44'
  check "$v: header の版がそろっている"         "$OUT" '.header.skill_version == .header.criteria_version'
  check "$v: c.adr_count は索引・テンプレートを除く" "$OUT" '.evidence["c.adr_count"].value == 4'
  check "$v: c.adr_duplicates は番号 3 だけ"     "$OUT" '.evidence["c.adr_duplicates"].value == ["3"]'
  check "$v: c.arch_lint_enforced（pre-commit のみ）" "$OUT" '.evidence["c.arch_lint_enforced"].value == true'
  check "$v: h.data_integrity_gate_configured"  "$OUT" '.evidence["h.data_integrity_gate_configured"].value == true'
  check "$v: e.test_files_count は worktree を除く" "$OUT" '.evidence["e.test_files_count"].value == 1'
  check "$v: e.test_cases_count（ファイル 1 件）"  "$OUT" '.evidence["e.test_cases_count"].value == 2'
  check "$v: f.rollback_doc_present（2 件中 1 件）" "$OUT" '.evidence["f.rollback_doc_present"].value == true'
  check "$v: f.smoke_steps"                     "$OUT" '.evidence["f.smoke_steps"].value == 1'
  check "$v: d.pr_commit_ratio_window（squash と merge の混在）" "$OUT" '.evidence["d.pr_commit_ratio_window"].value == 0.4'
  check "$v: k.coauthored_count は AI の共著者だけ" "$OUT" '.evidence["k.coauthored_count"].value == 2'
  check "$v: k.coauthored_by_model"             "$OUT" '[.evidence["k.coauthored_by_model"].value[].model] | sort == ["Claude Opus", "GitHub Copilot"]'
  check "$v: i.local_guardrail_hooks_count"     "$OUT" '.evidence["i.local_guardrail_hooks_count"].value == 1'
  check "$v: 実名がそのまま出る（匿名化なし）"    "$OUT" '.header.authors_anonymized == false and .header.authors_top5[0].author == "Alice Example"'
done

# --anonymize-authors
OUT="$WORK/anon.json"
FAKE_GH_MODE=ok bash "$WORK/default.sh" "$REPO" --anonymize-authors > "$OUT" 2>/dev/null
check "anonymize: authors_anonymized が true"  "$OUT" '.header.authors_anonymized == true'
check "anonymize: 著者名が author-N になる"    "$OUT" '[.header.authors_top5[].author] == ["author-1"]'
check "anonymize: PR 作成者が pr-author-N になる" "$OUT" '.evidence["l.pr_authors_window"].value == [{"author": "pr-author-1", "count": 1}]'
if grep -qE "Alice Example|bob" "$OUT"; then fail "anonymize: 出力に実名が残っていない"; else pass "anonymize: 出力に実名が残っていない"; fi

# --- gh の失敗の扱い ---------------------------------------------------------
# gh を使えない（リモートが無い）: GitHub 由来の 11 キーが null + error。再試行はしない
rm -f "$FAKE_GH_COUNTER"
OUT="$WORK/gh-noremote.json"
FAKE_GH_MODE=noremote bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/gh-noremote.err"
check "gh 使えない: gh_available が false"              "$OUT" '.header.gh_available == false'
check "gh 使えない: collection_errors が GitHub の 11 キー" "$OUT" "(.header.collection_errors | sort) == $GH_KEYS"
check "gh 使えない: 値は 0 ではなく null"               "$OUT" "[.evidence[$GH_KEYS[]].value] | all(. == null)"
check "gh 使えない: error に理由が入る"                  "$OUT" '.evidence["b.issues_open_count"].error | test("no git remotes")'
check "gh 使えない: GitHub 以外のキーは取得できている"    "$OUT" '[.evidence | to_entries[] | select(.value.error == null)] | length == 33'
if [ "$(cat "$FAKE_GH_COUNTER")" = "1" ]; then pass "gh 使えない: 最初の確認の 1 回しか gh を呼ばない"; else fail "gh 使えない: 最初の確認の 1 回しか gh を呼ばない（$(cat "$FAKE_GH_COUNTER") 回）"; fi
if grep -q '^警告: ' "$WORK/gh-noremote.err"; then pass "gh 使えない: stderr に警告が出る"; else fail "gh 使えない: stderr に警告が出る"; fi

# 一時的な失敗: 再試行で全キーを取得できる
rm -f "$FAKE_GH_COUNTER"
OUT="$WORK/gh-flaky.json"
FAKE_GH_MODE=flaky bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/gh-flaky.err"
check "一時的な失敗: gh_available が true"        "$OUT" '.header.gh_available == true'
check "一時的な失敗: collection_errors が空"       "$OUT" '.header.collection_errors == []'
check "一時的な失敗: 値が取れている"               "$OUT" '.evidence["b.issues_open_count"].value == 3 and .evidence["h.data_management_labels_count"].value == 1'
check "一時的な失敗: f.deploy_runs"                "$OUT" '.evidence["f.deploy_runs"].value["deploy-a.yml"] == {"success": 2, "failure": 1}'
if [ -s "$WORK/gh-flaky.err" ]; then fail "一時的な失敗: stderr が空"; sed 's/^/     /' "$WORK/gh-flaky.err"; else pass "一時的な失敗: stderr が空"; fi

# 継続的な失敗（502）: repo view 以外は GH_RETRY_MAX 回試して null + error
rm -f "$FAKE_GH_COUNTER"
OUT="$WORK/gh-down.json"
FAKE_GH_MODE=down GH_RETRY_MAX=2 bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "継続的な失敗: collection_errors が GitHub の 11 キー" "$OUT" "(.header.collection_errors | sort) == $GH_KEYS"
check "継続的な失敗: error に HTTP 502"            "$OUT" '.evidence["n.retro_prs_window_count"].error | test("502")'
check "継続的な失敗: f.deploy_runs の error にワークフロー名" "$OUT" '.evidence["f.deploy_runs"].error | startswith("deploy-a.yml: ")'
# repo view 1 回 + gh を呼ぶ 8 か所（ラベル一覧・b×2・f・g・l・m・n。f は最初のワークフローで打ち切る）× 2 回 = 17
if [ "$(cat "$FAKE_GH_COUNTER")" = "17" ]; then pass "継続的な失敗: 1 か所あたり GH_RETRY_MAX 回だけ試す"; else fail "継続的な失敗: 1 か所あたり GH_RETRY_MAX 回だけ試す（$(cat "$FAKE_GH_COUNTER") 回）"; fi

# 再試行しても直らない失敗（404）: 再試行しない
rm -f "$FAKE_GH_COUNTER"
OUT="$WORK/gh-notfound.json"
FAKE_GH_MODE=notfound GH_RETRY_MAX=3 bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "404: collection_errors が GitHub の 11 キー" "$OUT" "(.header.collection_errors | sort) == $GH_KEYS"
# repo view 1 回 + 8 か所 × 1 回 = 9
if [ "$(cat "$FAKE_GH_COUNTER")" = "9" ]; then pass "404: 再試行しない（1 か所 1 回）"; else fail "404: 再試行しない（1 か所 1 回。実際は $(cat "$FAKE_GH_COUNTER") 回）"; fi

# デプロイ系ワークフローが 0 件なら rollback は false
rm "$REPO"/.github/workflows/deploy-*.yml
OUT="$WORK/nodeploy.json"
FAKE_GH_MODE=ok bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "デプロイ系ワークフロー 0 件で f.rollback_doc_present が false" "$OUT" '.evidence["f.rollback_doc_present"].value == false'
check "デプロイ系ワークフロー 0 件で f.deploy_runs は {}（gh を呼ばない）" "$OUT" '.evidence["f.deploy_runs"].value == {} and .evidence["f.deploy_runs"].error == null'

if [ "$FAILED" -ne 0 ]; then echo "テストに失敗しました"; exit 1; fi
echo "すべてのテストに合格しました"
