# 証拠キー リファレンス

`collect-evidence.sh` が出力する JSON の `evidence.<key>` それぞれが、何を数え、何の目安になるかの辞書。証拠はスクリプトの出力をそのまま使い、このファイルを見て手でコマンドを実行・転記しない。

キーを追加・削除・変更したら、`criteria.md` の該当項目にある「参照する証拠キー」行もあわせて直し、版を上げる。

## 出力の形

```json
{
  "header": {
    "repository": "owner/name",
    "head_sha": "…",
    "assessed_at": "YYYY-MM-DD",
    "criteria_version": "0.1.2",
    "skill_version": "0.1.2",
    "window": {"start": "YYYY-MM-DD", "end": "YYYY-MM-DD", "days": 90},
    "authors_top5": [{"author": "…", "count": 0}],
    "single_author": false,
    "authors_anonymized": false,
    "gh_available": true,
    "collection_errors": []
  },
  "evidence": {
    "<key>": {"value": "…", "command": "…", "limit": null, "collected_at": "…"}
  }
}
```

- `value`：採点と受け入れ基準に使う値
- `command`：値を出したコマンドの要約
- `limit`：`gh` の取得件数の上限。値がこの上限に張り付いているときは、実数がもっと多い可能性がある
- `single_author`：コミット著者が 1 名なら `true`。`criteria.md` の N/A 注記を当てるかどうかの判断に使う
- `authors_anonymized`：`--anonymize-authors` を付けて実行したなら `true`。このとき `header.authors_top5` と `l.pr_authors_window` の名前は `author-1`・`pr-author-1` のような仮の名前になる（bot は除く）。件数や順位は変わらない
- `gh_available`：実行の最初の確認で `gh` を使えたなら `true`。`false` のときは、GitHub から取るキーがすべて取得できていない
- `collection_errors`：取得できなかったキーの一覧。空でなければ、該当するキーを採点に使う前に再実行する

## 取得できなかったキー

GitHub から取るキー（`b.issues_*`、`f.deploy_runs`、`g.incident_labeled_issues_count`、`h.data_management_labels_count`、`l.*`、`m.*`、`n.retro_prs_window_count`、`p.roadmap_label_count`）は、`gh` が失敗すると取得できない。スクリプトは一時的な失敗（ネットワーク、API の 5xx、レート制限など）に備えて `GH_RETRY_MAX` 回（既定 3）まで試す。未認証・リモートが無い・HTTP 401/404 のように再試行しても直らない失敗は、すぐにあきらめる。

それでも取得できなかったキーは次の形で記録する。値を `0` や `{}` にすると「実態が 0」と読み違えるので、`null` にする。

```json
"b.issues_open_count": {"value": null, "error": "HTTP 502: Bad Gateway", "command": "…", "limit": 500, "collected_at": "…"}
```

採点では、`value` が `null` のキーを 0 として扱わない。再実行しても取得できなければ「未取得」と明記し、そのキーに頼らずに判定するか、判定を保留する。

## 個人名が含まれるキー

`header.authors_top5`（コミット著者名）と `l.pr_authors_window`（PR 作成者のログイン名）には個人名が入る。`k.coauthored_by_model` は AI エージェントの名前だけを数えるので、通常は個人名を含まない。証拠 JSON を公開の場所（Public リポジトリの Issue 等）に投稿するときは、`--anonymize-authors` を付けて実行する。

## 時間窓

`--window-days`（既定 90）で指定した日数を、実行日（UTC）から遡った期間を「窓」と呼ぶ。`_window` で終わるキーと、`created:>=` / `merged:>=` で検索するキーは窓の中だけを数える。件数の上限だけで区切ると実行する時期によって別の期間を指してしまうので、時間で区切っている。

## プロジェクト固有の設定

以下はテンプレートの設定ブロックにある変数で、初回のスキャフォールドで対象リポジトリに合わせて埋める。空文字にするとスクリプト内の既定値が使われる。存在しないファイル・ディレクトリを列挙しても、そのパスは無視されるだけで結果は誤らない。

| 変数 | 影響するキー | 既定値の要点 |
| --- | --- | --- |
| `ADR_DIR` | `c.adr_*`, `p.adr_recent_count_window` | `docs/adr` |
| `CHANGELOG_FILE` | `n.changelog_lines`, `o.changelog_measurement_lines_count` | `CHANGELOG.md` |
| `RULE_HISTORY_FILES` | `a.rule_history_doc_present` | `docs/rule-history.md rule-history.md`（仮の名前。エージェント向けルールの変更理由を残すファイルは決まった名前が無いので、スキャフォールドのときに探して設定する） |
| `TEST_FILE_FIND_EXPR`, `TEST_CASE_REGEX` | `e.test_files_count`, `e.test_cases_count` | Python / JS / TS / Go / Java / Ruby の一般的な命名 |
| `COVERAGE_GATE_FILES` | `e.coverage_gate_configured` | pytest / coverage / jest / vitest の設定ファイル（`ENFORCEMENT_FILES` も併せて探す） |
| `ARCH_LINT_CONFIG_FILES`, `ARCH_LINT_ENFORCE_PATTERN` | `c.arch_lint_*` | import-linter / dependency-cruiser / ArchUnit |
| `ENFORCEMENT_FILES` | `c.arch_lint_enforced`, `e.coverage_gate_configured`, `h.data_integrity_gate_configured` | pre-commit / husky / lefthook / Taskfile / Makefile / justfile / package.json / `.github/workflows` |
| `DEPLOY_WORKFLOW_REGEX`, `ROLLBACK_DOC_FILES` | `f.*` | ワークフロー名に deploy / release / publish を含むもの |
| `MONITORING_PATTERNS`, `MONITORING_DIRS` | `g.monitoring_configured` | 監視ツール名を、ワークフロー・インフラ定義・スクリプトから探す |
| `DATA_LABELS_REGEX`, `DATA_GATE_PATTERN` | `h.*` | dataset / schema / migration / etl 等 |
| `USER_RESEARCH_REGEX` | `m.*` | persona / user-research / usability 等 |
| `RETRO_DOC_REGEX`, `RETRO_PR_SEARCH` | `n.retro_*` | ふりかえり / retrospective / postmortem |
| `VALUE_METRIC_REGEX`, `QUANTITATIVE_IMPACT_REGEX` | `o.*` | リードタイム・スループット・DORA 指標 / 数値＋単位、短縮・削減 |
| `ROADMAP_LABELS_REGEX` | `p.roadmap_label_count` | roadmap / explore / rfc / proposal / spike |
| `DOC_DIRS` | `n.retro_docs_count`, `o.value_metric_mentions_count` | `docs` |
| `AI_COAUTHOR_REGEX` | `k.*` | Claude / Copilot / OpenAI / Gemini / Cursor / Devin / Aider / `[bot]` など |

## A. エージェント運用知識の蓄積と継承

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `a.agent_instruction_files` | `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` / `.agents` / `.claude` / `.cursor` / `.github/copilot-instructions.md` のうち存在するもの | あればレベル 2 の候補 |
| `a.skills_count` | `.agents/skills` / `.claude/skills` / `skills` 直下のディレクトリ（symlink 含む）の数。同名はまとめて 1 | スキルとして体系化されていればレベル 3 の候補 |
| `a.rule_history_doc_present` | ルール変更の根拠履歴（`RULE_HISTORY_FILES`）の有無 | レベル 3 の候補 |

## B. 要件定義

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `b.issue_template_exists` | Issue テンプレートの有無 | レベル 1〜2 |
| `b.pr_template_exists` | PR テンプレートの有無 | レベル 1〜2 |
| `b.issues_open_count` | 未完了 Issue 数（上限 500） | 規模の把握 |
| `b.issues_closed_count` | 完了 Issue 数（上限 1000） | GitHub で要件を管理しているか |

## C. システム設計・アーキテクチャ

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `c.adr_count` | `ADR_DIR` 直下の `.md` 数（README / index / template で始まるものを除く） | レベル 2 |
| `c.adr_duplicates` | ファイル名の最初の数字列（先頭のゼロは無視）を ADR 番号とみなし、重複している番号の一覧。`0003-x.md` と `adr-003-y.md` はどちらも 3 | 空配列が望ましい |
| `c.arch_lint_configured` | 層構造・依存方向の静的検査の設定ファイルの有無 | 設定だけならレベル 2 止まり |
| `c.arch_lint_enforced` | その検査を呼ぶ行が `ENFORCEMENT_FILES` のどこかにあるか | レベル 3 には `true` が要る |

## D. コーディング・開発

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `d.commit_count_total` | 総コミット数 | 規模の把握 |
| `d.commits_window` | 窓内のコミット数 | 活動量 |
| `d.commits_by_month` | 直近 12 か月の月別コミット数 | 活動の推移 |
| `d.pr_commit_ratio_window` | 既定ブランチの first-parent 履歴（窓内）のうち、件名が `(#N)`（squash merge）または `Merge pull request #N`（merge commit）のコミットの割合 | PR を経由する運用の度合い。rebase merge だけの運用では低く出る |

## E. テスト・QA

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `e.test_files_count` | テストファイル数（`node_modules`、仮想環境、worktree、ビルド出力を除く） | 規模の把握 |
| `e.test_cases_count` | テストファイル内で `TEST_CASE_REGEX` に一致する行の数 | 規模の把握 |
| `e.coverage_gate_configured` | カバレッジの下限設定（`fail-under`、`coverageThreshold` 等）の有無 | レベル 3 の候補 |

## F. デプロイ・リリース

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `f.smoke_steps` | デプロイ系ワークフロー内の検証ステップ（smoke / health / verify / curl）に一致する行の数 | 0 なら F はレベル 3 未達 |
| `f.rollback_doc_present` | デプロイ系ワークフローのどれかに rollback の記載があるか、ロールバック手順のドキュメント（`ROLLBACK_DOC_FILES`）があるか | レベル 3 の候補 |
| `f.deploy_runs` | 窓内のデプロイ系ワークフローの実行結果（ワークフロー別 × conclusion 別の件数） | `success` が無く `skipped` / `failure` ばかりなら「存在のみ」でレベル 2 止まり |

## G. 監視・インシデント対応

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `g.monitoring_configured` | ワークフロー・インフラ定義・スクリプト内の監視ツールへの言及の有無 | 言及だけなので、実際に運用しているかは別に確認する |
| `g.incident_labeled_issues_count` | 窓内に作られた `incident` / `postmortem` ラベル付き Issue 数（上限 500） | 障害が GitHub に記録されているか |

## H. データ管理

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `h.data_management_labels_count` | データ管理系ラベル（`DATA_LABELS_REGEX`）の延べ数（上限 1000） | 取り込み・スキーマを管理しているか |
| `h.data_integrity_gate_configured` | 整合性・ドリフト検査（`DATA_GATE_PATTERN`）を呼ぶ行が `ENFORCEMENT_FILES` のどこかにあるか | レベル 3 の候補 |

## I. 開発環境・パイプラインへの AI 組み込み

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `i.tool_integration_files` | AI ツールの共有設定（`.claude/settings.json` / `.cursor` / `.gemini` / `.aider.conf.yml` 等） | レベル 2 |
| `i.local_guardrail_hooks_count` | pre-commit の `repo: local` の数 + `.husky` のフックファイル数 + `lefthook.yml` の有無（1） | ガードレールを機械的に強制しているか（レベル 3） |

## J. AI 利用ポリシーと機械的強制

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `j.governance_docs_present` | ガイドライン文書（`AGENTS.md` / `docs/ai-policy.md` 等）の有無 | レベル 2 |
| `j.dependabot_or_renovate_present` | 依存関係の自動更新設定の有無 | 自動の準拠チェック（レベル 3）の一部 |
| `j.codeql_security_workflow_present` | セキュリティ系ワークフロー（CodeQL / Snyk / Trivy / Semgrep 等）の有無 | 同上 |

## K. 透明性・監査証跡

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `k.coauthored_count` | AI エージェント（`AI_COAUTHOR_REGEX` に一致）の `Co-authored-by` トレーラーを持つコミット数。キーの大文字小文字は区別せず、1 コミットに複数いても 1 と数える | レベル 2 |
| `k.coauthored_by_model` | AI エージェントの `Co-authored-by` の名前別の件数（上位 10） | どのエージェントが関与しているか |
| `k.coauthored_ratio_lower_bound` | `k.coauthored_count / d.commit_count_total` | AI 関与率の**下限値**。トレーラーを付けない運用のコミットは判別できない |

## L. 人間–AI・AI–AI の協働プロトコル

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `l.pr_review_stats_window` | 窓内にマージされた PR の件数・レビュー付き件数・コメント付き件数・平均追加行数（上限 500） | レビュー工程に AI の出力を通しているか |
| `l.pr_authors_window` | 窓内にマージされた PR の著者別の件数（上限 500） | 人間と複数エージェントの関与 |

## M. 合成ユーザーリサーチ

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `m.user_research_issues_count` | 窓内に作られ、`USER_RESEARCH_REGEX` のキーワードのどれか（GitHub 検索の OR）を含む Issue 数（上限 500） | キーワード検索なので取りこぼしも誤検知もある |
| `m.user_research_labels_count` | リサーチ系ラベルの延べ数（上限 1000） | 探索を Issue 化しているか |

## N. 継続的改善のフィードバックループ

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `n.retro_docs_count` | `DOC_DIRS` 内でふりかえり系キーワードを含むファイル数 | レベル 2 |
| `n.changelog_lines` | `CHANGELOG_FILE` の行数 | 変更を記録しているか |
| `n.retro_prs_window_count` | 窓内にマージされた、タイトルがふりかえり系の PR 数（上限 500） | 改善が PR として出ているか（レベル 3） |

## O. 価値計測

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `o.value_metric_mentions_count` | `DOC_DIRS` 内の Markdown にあるフロー指標（リードタイム・スループット・DORA 指標等）への言及行数 | レベル 1〜2 |
| `o.changelog_measurement_lines_count` | `CHANGELOG_FILE` 内の定量的な効果の記載行数（数値＋単位、短縮・削減等） | 個別の改善を計測しているか（レベル 2） |

## P. ビジョンと適応

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `p.roadmap_label_count` | ロードマップ・探索系ラベルの延べ数（上限 1000） | レベル 2 |
| `p.adr_recent_count_window` | 窓内に更新された ADR ファイルの数（README / index / template を除く） | 判断を ADR に残しているか（レベル 3） |
