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

# 証拠キーの数と、そのうち GitHub から取る 12 キー
N_KEYS=50
GH_KEYS='["b.issues_closed_count","b.issues_open_count","f.deploy_runs","g.incident_labeled_issues_count","h.data_management_labels_count","l.ai_pr_stats_window","l.pr_authors_window","l.pr_review_stats_window","m.user_research_issues_count","m.user_research_labels_count","n.retro_prs_window_count","p.roadmap_label_count"]'
N_LOCAL_KEYS=38

# --- 偽の gh ----------------------------------------------------------------
# FAKE_GH_MODE で振る舞いを切り替える。呼ばれた回数を FAKE_GH_COUNTER に数え、引数を FAKE_GH_LOG に 1 行ずつ残す。
# gh api には REST API の生の応答（JSON）を返し、--jq の式は本物の jq で評価する（スクリプトの jq 式も検査するため）。
#   unauth    : 常に「未認証」で失敗する（再試行しても直らない失敗）
#   ok        : 常に成功する
#   flaky     : 奇数回目の呼び出しは HTTP 502 で失敗し、偶数回目は成功する（一時的な失敗）
#   ratelimit : 奇数回目の呼び出しは HTTP 403 のレート制限で失敗し、偶数回目は成功する（一時的な失敗）
#   down      : 最初の疎通確認だけ成功し、ほかは常に HTTP 502 で失敗する（継続的な失敗）
#   notfound  : 最初の疎通確認だけ成功し、ほかは常に HTTP 404 で失敗する（再試行しても直らない失敗）
#   nographql : GraphQL を使う gh pr list だけ HTTP 403 で失敗し、REST は成功する（Claude Code on the web 等）
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
n=$(( $(cat "$FAKE_GH_COUNTER" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE_GH_COUNTER"
echo "$*" >> "$FAKE_GH_LOG"

# api_response <endpoint> <検索クエリ> : REST API の生の応答
# PR 7（bob）は AI のレビューの後に人が承認。PR 8 は AI エージェントが作り、レビューが無い
api_response() {
  case "$1" in
    repos/example/repo) echo '{"full_name":"example/repo"}' ;;
    repos/example/repo/issues\?*page=1) echo '[{"labels":[{"name":"dataset"},{"name":"roadmap"}]},{"pull_request":{},"labels":[{"name":"dataset"}]}]' ;;
    repos/example/repo/issues\?*) echo '[]' ;;
    repos/example/repo/pulls/7) echo '{"additions":10}' ;;
    repos/example/repo/pulls/8) echo '{"additions":30}' ;;
    repos/example/repo/pulls/7/reviews\?*) echo '[{"user":{"login":"Copilot","type":"Bot"},"state":"COMMENTED","submitted_at":"2026-01-01T00:00:00Z"},{"user":{"login":"carol","type":"User"},"state":"APPROVED","submitted_at":"2026-01-02T00:00:00Z"}]' ;;
    repos/example/repo/pulls/8/reviews\?*) echo '[]' ;;
    search/issues)
      case "$2" in
        *"is:merged"*) echo '{"total_count":2,"items":[{"number":7,"comments":0,"user":{"login":"bob","type":"User"}},{"number":8,"comments":2,"user":{"login":"copilot-swe-agent[bot]","type":"Bot"}}]}' ;;
        *) echo '{"total_count":3,"items":[{"labels":[{"name":"incident"}]},{"labels":[{"name":"Postmortem"}]},{"labels":[{"name":"bug"}]}]}' ;;
      esac ;;
    *) echo "fake gh: unknown endpoint $1" >&2; exit 1 ;;
  esac
}

succeed() {
  if [ "$1" = "api" ]; then
    shift
    local endpoint="" q="" jqexpr=""
    while [ $# -gt 0 ]; do
      case "$1" in
        -X) shift 2 ;;
        --paginate) shift ;;
        -f) case "$2" in q=*) q="${2#q=}" ;; esac; shift 2 ;;
        --jq) jqexpr="$2"; shift 2 ;;
        *) endpoint="$1"; shift ;;
      esac
    done
    if [ -n "$jqexpr" ]; then api_response "$endpoint" "$q" | jq -r "$jqexpr"; else api_response "$endpoint" "$q"; fi
    exit 0
  fi
  case "$1 $2" in
    "run list") printf 'success\nsuccess\nfailure\n' ;;
    # bob の PR は AI のレビューの後に人が承認。AI エージェントの PR は、人が承認した後に AI がレビュー
    "pr list") echo '[{"reviews":[{"author":{"login":"copilot-pull-request-reviewer"},"state":"COMMENTED","submittedAt":"2026-01-01T00:00:00Z"},{"author":{"login":"carol"},"state":"APPROVED","submittedAt":"2026-01-02T00:00:00Z"}],"comments":[],"additions":10,"author":{"login":"bob"}},{"reviews":[{"author":{"login":"carol"},"state":"APPROVED","submittedAt":"2026-01-01T00:00:00Z"},{"author":{"login":"copilot-pull-request-reviewer"},"state":"COMMENTED","submittedAt":"2026-01-02T00:00:00Z"}],"comments":[1],"additions":30,"author":{"login":"app/copilot-swe-agent"}}]' ;;
    *) echo "fake gh: unknown command $*" >&2; exit 1 ;;
  esac
  exit 0
}
is_probe() { [ "$*" = "api repos/example/repo --jq .full_name" ]; }

case "${FAKE_GH_MODE:-unauth}" in
  unauth) echo "To get started with GitHub CLI, please run:  gh auth login" >&2; exit 1 ;;
  ok) succeed "$@" ;;
  flaky) [ $(( n % 2 )) -eq 0 ] && succeed "$@"; echo "HTTP 502: Bad Gateway" >&2; exit 1 ;;
  ratelimit) [ $(( n % 2 )) -eq 0 ] && succeed "$@"; echo "HTTP 403: API rate limit exceeded for user ID 1." >&2; exit 1 ;;
  down) is_probe "$@" && succeed "$@"; echo "HTTP 502: Bad Gateway" >&2; exit 1 ;;
  notfound) is_probe "$@" && succeed "$@"; echo "HTTP 404: Not Found" >&2; exit 1 ;;
  nographql) [ "$1 $2" = "pr list" ] && { echo "HTTP 403: Forbidden (https://api.github.com/graphql)" >&2; exit 1; }; succeed "$@" ;;
esac
FAKE_GH
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"
export FAKE_GH_COUNTER="$WORK/gh-calls"
export FAKE_GH_LOG="$WORK/gh-log"
export GH_RETRY_SLEEP=0

# reset_gh : 偽の gh の呼び出し回数と記録を消す
reset_gh() { rm -f "$FAKE_GH_COUNTER" "$FAKE_GH_LOG"; }
# gh_calls : 偽の gh が呼ばれた回数
gh_calls() { cat "$FAKE_GH_COUNTER" 2>/dev/null || echo 0; }

# only_warnings <stderr ファイル> : stderr に、警告以外が出ていなければ 0
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
  git remote add origin https://github.com/example/repo.git

  mkdir -p docs/adr tests .github/workflows .github/instructions .github/skills/review .cursor/rules .claude/worktrees/x/tests
  # 同じ人が別の名前・メールアドレスでもコミットしている（.mailmap で名寄せする）
  printf 'Alice Example <alice@example.com> alice-alt <alice.alt@example.com>\n' > .mailmap
  # GitHub Copilot のパス別指示書・スキルと Cursor のルール（AGENTS.md 等は無い）
  printf -- '---\napplyTo: "**"\n---\nDo not commit secrets.\n' > .github/instructions/x.instructions.md
  printf -- '---\nname: review\n---\n' > .github/skills/review/SKILL.md
  printf -- '---\ndescription: r1\n---\n' > .cursor/rules/r1.mdc
  # Claude Code の設定：hooks 2 件（イベント 2 種）と権限の拒否ルール 3 件
  printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"a"}]}],"Stop":[{"hooks":[{"type":"command","command":"b"}]}]},"permissions":{"deny":["Read(.env)","Read(**/secrets/**)","Bash(rm -rf:*)"]}}' > .claude/settings.json
  # PR テンプレートはリポジトリのルートに置く（大文字）
  printf '## 概要\n' > PULL_REQUEST_TEMPLATE.md
  # JVM のカバレッジ下限
  printf 'kover { verify { rule { minBound(80) } } }\ntasks.named("check") { dependsOn("koverVerify") }\n' > build.gradle.kts
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
  git commit -q --allow-empty --author="alice-alt <alice.alt@example.com>" -m "topic work"
  git checkout -q main
  git merge -q --no-ff topic -m "Merge pull request #2 from x/topic"

  # 追跡していないファイル（ローカルにしかない指示書・テスト・監視スクリプト）は数えない
  printf '# local only\n' > AGENTS.md
  printf 'def test_c():\n    pass\n' > tests/test_untracked.py
  mkdir -p infra
  printf 'sentry_dsn = "x"\n' > infra/sentry.tf
) || { echo "fixture の作成に失敗"; exit 1; }

# --- 実行して検査する -------------------------------------------------------
for v in default example; do
  OUT="$WORK/$v.json"
  FAKE_GH_MODE=unauth bash "$WORK/$v.sh" "$REPO" > "$OUT" 2> "$WORK/$v.err"
  if only_warnings "$WORK/$v.err"; then pass "$v: stderr は警告だけ"; else fail "$v: stderr は警告だけ"; sed 's/^/     /' "$WORK/$v.err"; fi
  check "${v}: 証拠キーが $N_KEYS 個"            "$OUT" ".evidence | length == $N_KEYS"
  check "$v: header の版がそろっている"         "$OUT" '.header.skill_version == .header.criteria_version'
  check "$v: c.adr_count は索引・テンプレートを除く" "$OUT" '.evidence["c.adr_count"].value == 4'
  check "$v: c.adr_duplicates は番号 3 だけ"     "$OUT" '.evidence["c.adr_duplicates"].value == ["3"]'
  check "$v: c.arch_lint_enforced（pre-commit のみ）" "$OUT" '.evidence["c.arch_lint_enforced"].value == true'
  check "$v: h.data_integrity_gate_configured"  "$OUT" '.evidence["h.data_integrity_gate_configured"].value == true'
  check "$v: e.test_files_count は worktree と未追跡を除く" "$OUT" '.evidence["e.test_files_count"].value == 1'
  check "$v: e.test_cases_count（ファイル 1 件）"  "$OUT" '.evidence["e.test_cases_count"].value == 2'
  check "$v: JVM のカバレッジ下限を検出"          "$OUT" '.evidence["e.coverage_gate_configured"].value == true'
  check "$v: f.rollback_doc_present（2 件中 1 件）" "$OUT" '.evidence["f.rollback_doc_present"].value == true'
  check "$v: f.smoke_steps"                     "$OUT" '.evidence["f.smoke_steps"].value == 1'
  check "$v: 未追跡の監視設定は数えない"         "$OUT" '.evidence["g.monitoring_configured"].value == false'
  check "$v: d.pr_commit_ratio_window（squash と merge の混在）" "$OUT" '.evidence["d.pr_commit_ratio_window"].value == 0.4'
  check "$v: 窓内にコミットがあれば note は付かない" "$OUT" '.evidence["d.pr_commit_ratio_window"].note == null and .evidence["d.commits_window"].note == null'
  check "$v: k.coauthored_count は AI の共著者だけ" "$OUT" '.evidence["k.coauthored_count"].value == 2'
  check "$v: k.coauthored_by_model"             "$OUT" '[.evidence["k.coauthored_by_model"].value[].model] | sort == ["Claude Opus", "GitHub Copilot"]'
  check "$v: k.coauthored_ratio_window はマージコミットを除く" "$OUT" '.evidence["k.coauthored_ratio_window"].value == 0.4'
  check "$v: i.local_guardrail_hooks_count"     "$OUT" '.evidence["i.local_guardrail_hooks_count"].value == 1'
  check "$v: i.agent_hooks_count"               "$OUT" '.evidence["i.agent_hooks_count"].value == 2'
  check "$v: i.agent_permission_denies_count"   "$OUT" '.evidence["i.agent_permission_denies_count"].value == 3'
  check "$v: 実名がそのまま出る（匿名化なし）"    "$OUT" '.header.authors_anonymized == false and .header.authors_top5[0].author == "Alice Example"'
  check "$v: .mailmap で名寄せして単独メンテナ"   "$OUT" '(.header.authors_top5 | length) == 1 and .header.single_author == true and .header.single_author_basis == "commit_authors"'
  check "$v: header.last_commit_date"           "$OUT" '.header.last_commit_date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")'
  check "$v: header.evaluated_ref"              "$OUT" '.header.evaluated_ref.branch == "main" and .header.evaluated_ref.sha == .header.head_sha and .header.evaluated_ref.default_branch == null and .header.evaluated_ref.behind_default == null and .header.evaluated_ref.uncommitted_changes == false'
  check "$v: framework_checked_at は指定が無ければ null" "$OUT" '.header.framework_checked_at == null'
  check "$v: Copilot のパス別指示書を A で検出"  "$OUT" '.evidence["a.agent_instruction_files"].value | index(".github/instructions") != null'
  check "$v: 未追跡の AGENTS.md は数えない"      "$OUT" '.evidence["a.agent_instruction_files"].value | index("AGENTS.md") == null'
  check "$v: a.skills_count に .github/skills を含む" "$OUT" '.evidence["a.skills_count"].value == 1'
  check "$v: a.rule_files_count（.mdc と .instructions.md）" "$OUT" '.evidence["a.rule_files_count"].value == 2'
  check "$v: a.rule_change_commits_window"      "$OUT" '.evidence["a.rule_change_commits_window"].value == 1'
  check "$v: ルート直下の PR テンプレートを検出"  "$OUT" '.evidence["b.pr_template_exists"].value == true and .evidence["b.issue_template_exists"].value == false'
  check "$v: Copilot のパス別指示書を I で検出"  "$OUT" '.evidence["i.tool_integration_files"].value | index(".github/instructions") != null'
  check "$v: Copilot のパス別指示書で J が true" "$OUT" '.evidence["j.governance_docs_present"].value == true'
  check "$v: header.config に設定ブロックの全項目" "$OUT" '(.header.config | keys | length) == 26'
done
check "default: header.config は空文字（既定値）" "$WORK/default.json" '.header.config.TEST_FILE_FIND_EXPR == ""'
check "example: header.config に埋めた値が残る"   "$WORK/example.json" '.header.config.TEST_FILE_FIND_EXPR == "-name \"test_*.py\" -o -name \"*.test.ts\" -o -name \"*_test.go\""'

# --framework-checked-at
OUT="$WORK/framework.json"
FAKE_GH_MODE=unauth bash "$WORK/default.sh" "$REPO" --framework-checked-at 2026-09-01 > "$OUT" 2>/dev/null
check "framework_checked_at を記録する" "$OUT" '.header.framework_checked_at == "2026-09-01"'
if FAKE_GH_MODE=unauth bash "$WORK/default.sh" "$REPO" --framework-checked-at 9/1 >/dev/null 2>&1; then
  fail "framework_checked_at の形式が違えばエラー"
else
  pass "framework_checked_at の形式が違えばエラー"
fi

# --anonymize-authors
OUT="$WORK/anon.json"
FAKE_GH_MODE=ok bash "$WORK/default.sh" "$REPO" --anonymize-authors > "$OUT" 2>/dev/null
check "anonymize: authors_anonymized が true"  "$OUT" '.header.authors_anonymized == true'
check "anonymize: 著者名が author-N になる"    "$OUT" '[.header.authors_top5[].author] == ["author-1"]'
check "anonymize: PR 作成者が pr-author-N になり、bot はそのまま" "$OUT" '[.evidence["l.pr_authors_window"].value[].author] | sort | (.[0] == "app/copilot-swe-agent" and (.[1] | startswith("pr-author-")))'
if grep -qE "Alice Example|alice-alt|bob" "$OUT"; then fail "anonymize: 出力に実名が残っていない"; else pass "anonymize: 出力に実名が残っていない"; fi

# --- 既定ブランチとのずれ -------------------------------------------------------
# origin/main を 1 コミット先に進め、origin/HEAD を origin/main に向ける
AHEAD_SHA="$(git -C "$REPO" commit-tree "HEAD^{tree}" -p HEAD -m "ahead")"
git -C "$REPO" update-ref refs/remotes/origin/main "$AHEAD_SHA"
git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
OUT="$WORK/behind.json"
FAKE_GH_MODE=unauth bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/behind.err"
check "遅れ: behind_default が 1"       "$OUT" '.header.evaluated_ref.default_branch == "main" and .header.evaluated_ref.is_default_branch == true and .header.evaluated_ref.behind_default == 1'
if grep -q '^警告: HEAD は origin/main より 1 コミット遅れています' "$WORK/behind.err"; then pass "遅れ: stderr に警告が出る"; else fail "遅れ: stderr に警告が出る"; sed 's/^/     /' "$WORK/behind.err"; fi
git -C "$REPO" checkout -q -b feature
OUT="$WORK/feature.json"
FAKE_GH_MODE=unauth bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/feature.err"
check "別ブランチ: is_default_branch が false" "$OUT" '.header.evaluated_ref.branch == "feature" and .header.evaluated_ref.is_default_branch == false'
if grep -q '^警告: 評価したのは既定ブランチ（main）ではなく feature です' "$WORK/feature.err"; then pass "別ブランチ: stderr に警告が出る"; else fail "別ブランチ: stderr に警告が出る"; fi
git -C "$REPO" checkout -q main
git -C "$REPO" branch -q -D feature
git -C "$REPO" symbolic-ref --delete refs/remotes/origin/HEAD
git -C "$REPO" update-ref -d refs/remotes/origin/main

# --- gh の取得 ---------------------------------------------------------------
# すべて成功: REST で取った値
reset_gh
OUT="$WORK/gh-ok.json"
FAKE_GH_MODE=ok bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/gh-ok.err"
check "成功: gh_available が true"                   "$OUT" '.header.gh_available == true and .header.repository == "example/repo"'
check "成功: collection_errors が空"                  "$OUT" '.header.collection_errors == []'
check "成功: 件数は検索 API の total_count"           "$OUT" '.evidence["b.issues_open_count"].value == 3 and .evidence["b.issues_open_count"].limit == null'
check "成功: ラベルは PR を除いた Issue だけから数える" "$OUT" '.evidence["h.data_management_labels_count"].value == 1 and .evidence["p.roadmap_label_count"].value == 1'
check "成功: incident / postmortem ラベルの Issue"    "$OUT" '.evidence["g.incident_labeled_issues_count"].value == 2'
check "成功: f.deploy_runs"                           "$OUT" '.evidence["f.deploy_runs"].value["deploy-a.yml"] == {"success": 2, "failure": 1}'
check "成功: l は GraphQL で取る"                     "$OUT" '(.evidence["l.pr_review_stats_window"].command | test("GraphQL")) and .evidence["l.pr_review_stats_window"].value == {"count": 2, "with_review": 2, "with_comments": 1, "avg_additions": 20}'
check "成功: l.ai_pr_stats_window（人の承認が AI のレビューより前なら数えない）" "$OUT" '.evidence["l.ai_pr_stats_window"].value == {"count": 2, "ai_authored": 1, "ai_reviewed": 2, "human_approved_after_ai_review": 1}'
if [ -s "$WORK/gh-ok.err" ]; then fail "成功: stderr が空"; sed 's/^/     /' "$WORK/gh-ok.err"; else pass "成功: stderr が空"; fi
if grep -qE '^(repo view|issue list)' "$FAKE_GH_LOG"; then fail "成功: GraphQL を使う gh repo view / gh issue list を呼ばない"; else pass "成功: GraphQL を使う gh repo view / gh issue list を呼ばない"; fi

# GraphQL が使えない（Claude Code on the web 等）: REST で全キーを取得できる。l は REST で取り直す
reset_gh
OUT="$WORK/gh-nographql.json"
FAKE_GH_MODE=nographql GH_RETRY_MAX=3 bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/gh-nographql.err"
check "GraphQL なし: gh_available が true"            "$OUT" '.header.gh_available == true'
check "GraphQL なし: collection_errors が空"           "$OUT" '.header.collection_errors == []'
check "GraphQL なし: GitHub の 12 キーに null が無い"  "$OUT" "[.evidence[${GH_KEYS}[]].value] | all(. != null)"
check "GraphQL なし: l は REST で取る"                 "$OUT" '.evidence["l.pr_review_stats_window"].command | test("REST")'
check "GraphQL なし: l.pr_review_stats_window"         "$OUT" '.evidence["l.pr_review_stats_window"].value == {"count": 2, "with_review": 1, "with_comments": 1, "avg_additions": 20}'
check "GraphQL なし: bot のログインを app/<name> にそろえる" "$OUT" '(.evidence["l.pr_authors_window"].value | sort_by(.author)) == [{"author": "app/copilot-swe-agent", "count": 1}, {"author": "bob", "count": 1}]'
check "GraphQL なし: l.ai_pr_stats_window"             "$OUT" '.evidence["l.ai_pr_stats_window"].value == {"count": 2, "ai_authored": 1, "ai_reviewed": 1, "human_approved_after_ai_review": 1}'
if [ "$(grep -c '^pr list' "$FAKE_GH_LOG")" = "1" ]; then pass "GraphQL なし: 403 の gh pr list を再試行しない"; else fail "GraphQL なし: 403 の gh pr list を再試行しない（$(grep -c '^pr list' "$FAKE_GH_LOG") 回）"; fi
# 疎通確認 1 + ラベル 1 ページ + b×2 + f×2（ワークフロー 2 件）+ g + l（GraphQL 1 + 検索 1 + PR 2 件 × 2）+ m + n = 15
if [ "$(gh_calls)" = "15" ]; then pass "GraphQL なし: gh の呼び出しは 15 回"; else fail "GraphQL なし: gh の呼び出しは 15 回（$(gh_calls) 回）"; fi

# gh を使えない（未認証）: GitHub 由来の 12 キーが null + error。再試行はしない
reset_gh
OUT="$WORK/gh-unauth.json"
FAKE_GH_MODE=unauth bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/gh-unauth.err"
check "gh 使えない: gh_available が false"              "$OUT" '.header.gh_available == false'
check "gh 使えない: collection_errors が GitHub の 12 キー" "$OUT" "(.header.collection_errors | sort) == $GH_KEYS"
check "gh 使えない: 値は 0 ではなく null"               "$OUT" "[.evidence[${GH_KEYS}[]].value] | all(. == null)"
check "gh 使えない: error に理由が入る"                  "$OUT" '.evidence["b.issues_open_count"].error | test("gh auth login")'
check "gh 使えない: GitHub 以外のキーは取得できている"    "$OUT" "[.evidence | to_entries[] | select(.value.error == null)] | length == $N_LOCAL_KEYS"
if [ "$(gh_calls)" = "1" ]; then pass "gh 使えない: 最初の確認の 1 回しか gh を呼ばない"; else fail "gh 使えない: 最初の確認の 1 回しか gh を呼ばない（$(gh_calls) 回）"; fi
if grep -q '^警告: ' "$WORK/gh-unauth.err"; then pass "gh 使えない: stderr に警告が出る"; else fail "gh 使えない: stderr に警告が出る"; fi

# 一時的な失敗: 再試行で全キーを取得できる
for mode in flaky ratelimit; do
  reset_gh
  OUT="$WORK/gh-$mode.json"
  FAKE_GH_MODE=$mode bash "$WORK/default.sh" "$REPO" > "$OUT" 2> "$WORK/gh-$mode.err"
  check "一時的な失敗（${mode}）: gh_available が true"  "$OUT" '.header.gh_available == true'
  check "一時的な失敗（${mode}）: collection_errors が空" "$OUT" '.header.collection_errors == []'
  check "一時的な失敗（${mode}）: 値が取れている"         "$OUT" '.evidence["b.issues_open_count"].value == 3 and .evidence["h.data_management_labels_count"].value == 1'
  check "一時的な失敗（${mode}）: f.deploy_runs"          "$OUT" '.evidence["f.deploy_runs"].value["deploy-a.yml"] == {"success": 2, "failure": 1}'
  if [ -s "$WORK/gh-$mode.err" ]; then fail "一時的な失敗（${mode}）: stderr が空"; sed 's/^/     /' "$WORK/gh-$mode.err"; else pass "一時的な失敗（${mode}）: stderr が空"; fi
done

# 継続的な失敗（502）: 疎通確認以外は GH_RETRY_MAX 回試して null + error
reset_gh
OUT="$WORK/gh-down.json"
FAKE_GH_MODE=down GH_RETRY_MAX=2 bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "継続的な失敗: collection_errors が GitHub の 12 キー" "$OUT" "(.header.collection_errors | sort) == $GH_KEYS"
check "継続的な失敗: error に HTTP 502"            "$OUT" '.evidence["n.retro_prs_window_count"].error | test("502")'
check "継続的な失敗: f.deploy_runs の error にワークフロー名" "$OUT" '.evidence["f.deploy_runs"].error | startswith("deploy-a.yml: ")'
# 疎通確認 1 回 + gh を呼ぶ 9 か所（ラベル一覧・b×2・f・g・l の GraphQL・l の REST・m・n。f は最初のワークフローで打ち切る）× 2 回 = 19
if [ "$(gh_calls)" = "19" ]; then pass "継続的な失敗: 1 か所あたり GH_RETRY_MAX 回だけ試す"; else fail "継続的な失敗: 1 か所あたり GH_RETRY_MAX 回だけ試す（$(gh_calls) 回）"; fi

# 再試行しても直らない失敗（404）: 再試行しない
reset_gh
OUT="$WORK/gh-notfound.json"
FAKE_GH_MODE=notfound GH_RETRY_MAX=3 bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "404: collection_errors が GitHub の 12 キー" "$OUT" "(.header.collection_errors | sort) == $GH_KEYS"
# 疎通確認 1 回 + 9 か所 × 1 回 = 10
if [ "$(gh_calls)" = "10" ]; then pass "404: 再試行しない（1 か所 1 回）"; else fail "404: 再試行しない（1 か所 1 回。実際は $(gh_calls) 回）"; fi

# --- 設定ファイルの壊れた JSON ---------------------------------------------------
cp "$REPO/.claude/settings.json" "$WORK/settings.json.bak"
printf '{ broken\n' > "$REPO/.claude/settings.json"
OUT="$WORK/broken-settings.json"
FAKE_GH_MODE=unauth bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "settings.json が壊れていれば null と note" "$OUT" '.evidence["i.agent_hooks_count"].value == null and (.evidence["i.agent_hooks_count"].note | test("invalid JSON"))'
cp "$WORK/settings.json.bak" "$REPO/.claude/settings.json"

# --- 自分自身への一致 ---------------------------------------------------------
# スクリプトを既定の配置先 scripts/ai-sdlc/ に置いてコミットする。default は MONITORING_DIRS の既定値に scripts が入っている。
# scripts-dirs はドキュメントの探索先（DOC_DIRS）にも scripts を指定する
sed -E \
  -e 's#\{\{MONITORING_DIRS\}\}#scripts#' \
  -e 's#\{\{DOC_DIRS\}\}#scripts#' \
  -e 's/\{\{[A-Z_]+\}\}//g' "$TPL" > "$WORK/scripts-dirs.sh"
mkdir -p "$REPO/scripts/ai-sdlc"
cp "$TPL" "$REPO/scripts/ai-sdlc/"
for v in default scripts-dirs; do
  cp "$WORK/$v.sh" "$REPO/scripts/ai-sdlc/collect-evidence.sh"
  git -C "$REPO" add scripts && git -C "$REPO" commit -q -m "chore: add evidence script ($v)"
  OUT="$WORK/self-$v.json"
  FAKE_GH_MODE=unauth bash "$REPO/scripts/ai-sdlc/collect-evidence.sh" "$REPO" > "$OUT" 2>/dev/null
  check "自分自身（${v}）: g.monitoring_configured が false" "$OUT" '.evidence["g.monitoring_configured"].value == false'
  check "自分自身（${v}）: ドキュメントの検索にも一致しない" "$OUT" '.evidence["n.retro_docs_count"].value == 0 and .evidence["o.value_metric_mentions_count"].value == 0'
done
# 自分自身を除いても、ほかの追跡されているファイルの監視設定は検出する（既定値の scripts でも検出する）
printf '#!/bin/sh\ncurl -fsS https://example.com/healthcheck\n' > "$REPO/scripts/probe.sh"
git -C "$REPO" add scripts/probe.sh && git -C "$REPO" commit -q -m "chore: probe"
for v in default scripts-dirs; do
  cp "$WORK/$v.sh" "$REPO/scripts/ai-sdlc/collect-evidence.sh"
  OUT="$WORK/self-positive-$v.json"
  FAKE_GH_MODE=unauth bash "$REPO/scripts/ai-sdlc/collect-evidence.sh" "$REPO" > "$OUT" 2>/dev/null
  check "自分自身を除いてもほかのファイルは検出する（${v}）" "$OUT" '.evidence["g.monitoring_configured"].value == true'
done
git -C "$REPO" checkout -q -- scripts
git -C "$REPO" rm -r -q scripts && git -C "$REPO" commit -q -m "chore: remove scripts"

# --- 単独メンテナの判定（PR の作成者） -----------------------------------------
# 別の人がコミットしても、窓内にマージされた PR の作成者（bot を除く）が 1 名なら単独メンテナとみなす
git -C "$REPO" -c user.name="Carol Other" -c user.email=carol@example.com commit -q --allow-empty -m "docs: carol"
OUT="$WORK/single-pr.json"
FAKE_GH_MODE=ok bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "PR の作成者が 1 名なら単独メンテナ" "$OUT" '.header.single_author == true and .header.single_author_basis == "pr_authors"'
OUT="$WORK/single-nogh.json"
FAKE_GH_MODE=unauth bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "PR の作成者が分からず著者が 2 名なら単独メンテナではない" "$OUT" '.header.single_author == false and .header.single_author_basis == null'

# --- リモートが無い・休眠中のリポジトリ ----------------------------------------
OLD="$WORK/old"
mkdir -p "$OLD"
(
  cd "$OLD" || exit 1
  git init -q -b main
  git config user.name "Dora Mant"
  git config user.email dora@example.com
  git config commit.gpgsign false
  GIT_AUTHOR_DATE="2020-01-01T00:00:00Z" GIT_COMMITTER_DATE="2020-01-01T00:00:00Z" git commit -q --allow-empty -m "old (#1)"
) || { echo "fixture の作成に失敗"; exit 1; }
reset_gh
OUT="$WORK/old.json"
FAKE_GH_MODE=ok bash "$WORK/default.sh" "$OLD" > "$OUT" 2>/dev/null
check "リモートが無い: gh_available が false"          "$OUT" '.header.gh_available == false'
check "リモートが無い: error に理由が入る"              "$OUT" '.evidence["b.issues_open_count"].error | test("no git remotes")'
if [ "$(gh_calls)" = "0" ]; then pass "リモートが無い: gh を呼ばない"; else fail "リモートが無い: gh を呼ばない（$(gh_calls) 回）"; fi
check "休眠中: header.last_commit_date"                 "$OUT" '.header.last_commit_date == "2020-01-01"'
check "休眠中: d.commits_window は 0 で note に理由"    "$OUT" '.evidence["d.commits_window"].value == 0 and (.evidence["d.commits_window"].note | test("2020-01-01"))'
check "休眠中: d.pr_commit_ratio_window は null で note に理由" "$OUT" '.evidence["d.pr_commit_ratio_window"].value == null and (.evidence["d.pr_commit_ratio_window"].note | test("no first-parent commits"))'
check "休眠中: k.coauthored_ratio_window は null で note に理由" "$OUT" '.evidence["k.coauthored_ratio_window"].value == null and (.evidence["k.coauthored_ratio_window"].note | test("2020-01-01"))'
check "休眠中: note だけのキーは collection_errors に入らない" "$OUT" '.header.collection_errors | index("d.pr_commit_ratio_window") == null'

# デプロイ系ワークフローが 0 件なら rollback は false
git -C "$REPO" rm -q .github/workflows/deploy-a.yml .github/workflows/deploy-b.yml && git -C "$REPO" commit -q -m "chore: remove deploy workflows"
OUT="$WORK/nodeploy.json"
FAKE_GH_MODE=ok bash "$WORK/default.sh" "$REPO" > "$OUT" 2>/dev/null
check "デプロイ系ワークフロー 0 件で f.rollback_doc_present が false" "$OUT" '.evidence["f.rollback_doc_present"].value == false'
check "デプロイ系ワークフロー 0 件で f.deploy_runs は {}（gh を呼ばない）" "$OUT" '.evidence["f.deploy_runs"].value == {} and .evidence["f.deploy_runs"].error == null'

if [ "$FAILED" -ne 0 ]; then echo "テストに失敗しました"; exit 1; fi
echo "すべてのテストに合格しました"
