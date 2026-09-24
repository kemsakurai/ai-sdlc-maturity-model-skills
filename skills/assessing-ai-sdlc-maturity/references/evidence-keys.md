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
    "criteria_version": "0.0.1",
    "skill_version": "0.0.1",
    "window": {"start": "YYYY-MM-DD", "end": "YYYY-MM-DD", "days": 90},
    "authors_top5": [{"author": "…", "count": 0}],
    "single_author": false
  },
  "evidence": {
    "<key>": {"value": "…", "command": "…", "limit": null, "collected_at": "…"}
  }
}
```

- `value`：採点と受け入れ基準に使う値
- `command`：値を出したコマンドの要約
- `limit`：`gh` の取得件数の上限。値がこの上限に張り付いているときは実数がもっと多い可能性がある
- `single_author`：コミット著者が 1 名なら `true`。`criteria.md` の N/A 注記を当てるかどうかの判断に使う

## 時間窓

`--window-days`（既定 90）で指定した日数を、実行日（UTC）から遡った期間を「窓」と呼ぶ。`_window` で終わるキーと、`created:>=` / `merged:>=` で検索するキーは窓の中だけを数える。件数の上限だけで区切ると実行する時期によって別の期間を指してしまうので、時間で区切っている。

## プロジェクト固有の設定

以下はテンプレートの設定ブロックにある変数で、初回のスキャフォールドで対象リポジトリに合わせて埋める。空文字にするとスクリプト内の既定値が使われる。

| 変数 | 影響するキー |
| --- | --- |
| `ADR_DIR` | `c.adr_*`, `p.adr_recent_count_window` |
| `CHANGELOG_FILE` | `n.changelog_lines`, `o.changelog_measurement_lines_count` |
| `RULE_HISTORY_FILES` | `a.rule_history_doc_present` |
| `TEST_FILE_FIND_EXPR`, `TEST_CASE_REGEX` | `e.test_files_count`, `e.test_cases_count` |
| `COVERAGE_GATE_FILES` | `e.coverage_gate_configured` |
| `ARCH_LINT_CONFIG_FILES`, `ARCH_LINT_ENFORCE_PATTERN` | `c.arch_lint_*` |
| `DEPLOY_WORKFLOW_REGEX`, `ROLLBACK_DOC_FILES` | `f.*` |
| `MONITORING_PATTERNS` | `g.monitoring_configured` |
| `DATA_LABELS_REGEX` | `h.data_management_labels_count` |
| `USER_RESEARCH_REGEX` | `m.*` |
| `RETRO_DOC_REGEX`, `RETRO_PR_SEARCH` | `n.retro_*` |
| `VALUE_METRIC_REGEX`, `QUANTITATIVE_IMPACT_REGEX` | `o.*` |
| `ROADMAP_LABELS_REGEX` | `p.roadmap_label_count` |
| `DOC_DIRS` | `g.monitoring_configured`, `n.retro_docs_count`, `o.value_metric_mentions_count` |

## A. エージェント運用知識の蓄積と継承

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `a.agent_instruction_files` | `AGENTS.md` / `CLAUDE.md` / `.agents` / `.claude` / `.cursor` / `.github/copilot-instructions.md` のうち存在するもの | あればレベル 2 の候補 |
| `a.skills_count` | `.agents/skills` / `.claude/skills` / `skills` 配下のエントリ数 | スキルとして体系化されていればレベル 3 の候補 |
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
| `c.adr_count` | `ADR_DIR` 配下の `.md` 数 | レベル 2 |
| `c.adr_duplicates` | 番号（先頭 4 文字）が重複している ADR の一覧 | 空配列が望ましい |
| `c.arch_lint_configured` | 層構造・依存方向の静的検査の設定ファイルの有無 | 設定だけならレベル 2 止まり |
| `c.arch_lint_enforced` | その検査を呼ぶ pre-commit / Taskfile / Makefile / CI の行の有無 | レベル 3 には `true` が要る |

## D. コーディング・開発

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `d.commit_count_total` | 総コミット数 | 規模の把握 |
| `d.commits_window` | 窓内のコミット数 | 活動量 |
| `d.commits_by_month` | 直近 12 か月の月別コミット数 | 活動の推移 |
| `d.pr_commit_ratio_window` | 窓内で件名に `(#N)` を含むコミットの割合 | PR を経由する運用の度合い |

## E. テスト・QA

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `e.test_files_count` | テストファイル数 | 規模の把握 |
| `e.test_cases_count` | テストケース数（`TEST_CASE_REGEX` の一致数） | 規模の把握 |
| `e.coverage_gate_configured` | カバレッジの下限設定（`fail-under` 等）の有無 | レベル 3 の候補 |

## F. デプロイ・リリース

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `f.smoke_steps` | デプロイ系ワークフロー内の検証ステップ（smoke / health / verify 等）の数 | 0 なら F はレベル 3 未達 |
| `f.rollback_doc_present` | 戻し手順の記載（ワークフローまたはドキュメント）の有無 | レベル 3 の候補 |
| `f.deploy_runs` | 窓内のデプロイ系ワークフローの実行結果（ワークフロー別 × conclusion 別の件数） | `success` が無く `skipped` / `failure` ばかりなら「存在のみ」でレベル 2 止まり |

## G. 監視・インシデント対応

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `g.monitoring_configured` | ワークフロー・インフラ定義・ドキュメント内の監視ツールへの言及の有無 | 言及だけなので、実際に運用しているかは別に確認する |
| `g.incident_labeled_issues_count` | 窓内に作られた `incident` / `postmortem` ラベル付き Issue 数 | 障害が GitHub に記録されているか |

## H. データ管理

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `h.data_management_labels_count` | データ管理系ラベル（`DATA_LABELS_REGEX`）の延べ数（上限 1000） | 取り込み・ライセンスを管理しているか |
| `h.data_integrity_gate_configured` | 整合性・ドリフト検査を呼ぶ行の有無 | レベル 3 の候補 |

## I. 開発環境・パイプラインへの AI 組み込み

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `i.tool_integration_files` | AI ツールの共有設定（`.claude/settings.json` / `.cursor` / `.gemini` 等） | レベル 2 |
| `i.local_guardrail_hooks_count` | pre-commit の `repo: local` フック数 | ガードレールを機械的に強制しているか（レベル 3） |

## J. AI 利用ポリシーと機械的強制

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `j.governance_docs_present` | ガイドライン文書（`AGENTS.md` / `docs/ai-policy.md` 等）の有無 | レベル 2 |
| `j.dependabot_or_renovate_present` | 依存関係の自動更新設定の有無 | 自動の準拠チェック（レベル 3）の一部 |
| `j.codeql_security_workflow_present` | セキュリティ系ワークフローの有無 | 同上 |

## K. 透明性・監査証跡

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `k.coauthored_count` | `Co-Authored-By` トレーラーを持つコミット数 | レベル 2 |
| `k.coauthored_by_model` | トレーラーの名前別の内訳（上位 10） | どのエージェントが関与しているか |
| `k.coauthored_ratio_lower_bound` | `k.coauthored_count / d.commit_count_total` | AI 関与率の**下限値**。トレーラーの無いコミットの由来は判別できない |

## L. 人間–AI・AI–AI の協働プロトコル

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `l.pr_review_stats_window` | 窓内にマージされた PR の件数・レビュー付き件数・コメント付き件数・平均追加行数 | レビュー工程に AI の出力を通しているか |
| `l.pr_authors_window` | 窓内にマージされた PR の著者別の件数 | 人間と複数エージェントの関与 |

## M. 合成ユーザーリサーチ

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `m.user_research_issues_count` | 窓内に作られた、ユーザーリサーチ系キーワードを含む Issue 数 | キーワード検索なので取りこぼしがある |
| `m.user_research_labels_count` | リサーチ系ラベルの延べ数（上限 1000） | 探索を Issue 化しているか |

## N. 継続的改善のフィードバックループ

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `n.retro_docs_count` | `DOC_DIRS` 内でふりかえり系キーワードを含むファイル数 | レベル 2 |
| `n.changelog_lines` | `CHANGELOG_FILE` の行数 | 変更を記録しているか |
| `n.retro_prs_window_count` | 窓内にマージされた、タイトルがふりかえり・棚卸し系の PR 数 | 改善が PR として出ているか（レベル 3） |

## O. 価値計測

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `o.value_metric_mentions_count` | `DOC_DIRS` 内のフロー指標（リードタイム・スループット等）への言及数 | レベル 1〜2 |
| `o.changelog_measurement_lines_count` | `CHANGELOG_FILE` 内の定量的な効果の記載行数 | 個別の改善を計測しているか（レベル 2） |

## P. ビジョンと適応

| キー | 数えるもの | 目安 |
| --- | --- | --- |
| `p.roadmap_label_count` | ロードマップ・探索系ラベルの延べ数（上限 1000） | レベル 2 |
| `p.adr_recent_count_window` | 窓内に更新された ADR ファイル数 | 判断を ADR に残しているか（レベル 3） |
