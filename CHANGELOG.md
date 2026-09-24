# 変更履歴

このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に従います。`criteria.md` の判定基準を変えたときは、以前の採点と比較できなくなるので、少なくともマイナーバージョンを上げます。

## [0.0.2] - 2026-09-24

`criteria.md` の判定基準（項目・レベルの文言）は 0.0.1 と同じです。一方で証拠の収集方法を直したので、同じリポジトリでも一部のキーの値が変わります。0.0.1 で取った証拠と比べるときは、下の「修正（証拠の値が変わるもの）」に挙げたキーを分けて読んでください。

### 修正（証拠の値が変わるもの）

- 存在しないファイルが 1 つでも混ざると検索全体が失敗し、`false` になっていた問題を直した。対象は `c.arch_lint_enforced`、`e.coverage_gate_configured`、`g.monitoring_configured`、`h.data_integrity_gate_configured`。
- `f.rollback_doc_present`：デプロイ系ワークフローが 0 件のときに `true` になる問題と、2 件以上あると `false` になり得る問題を直した。
- `g.incident_labeled_issues_count`、`m.user_research_issues_count`、`n.retro_prs_window_count`：`gh` の既定の上限 30 件で打ち切られていたので、上限を 500 にして `limit` に記録するようにした。
- `m.user_research_issues_count`：正規表現の `|` をそのまま GitHub 検索に渡していたので、`OR` に変換するようにした。
- `e.test_cases_count`：テストファイルが 1 件だけのとき 0 になる問題を直した。
- `e.test_files_count` / `e.test_cases_count`：既定の探索で `.claude/worktrees`、`venv`、`site-packages`、`target` などを除外するようにした。
- `a.skills_count`：`ls` の見出し行まで数えていたので、スキルのディレクトリだけを数えるようにした。
- `k.coauthored_*`：`Co-authored-by` を大文字小文字を区別せずに読み、AI エージェント（`AI_COAUTHOR_REGEX`）の共著者だけを、コミット単位で数えるようにした。人間の共著者は数えない。
- `c.adr_duplicates`：先頭 4 文字ではなく、ファイル名の最初の数字列で ADR 番号を判定するようにした（`adr-001-x.md` 形式に対応）。`c.adr_count` と `p.adr_recent_count_window` は README / index / template を数えない。
- `d.pr_commit_ratio_window`：既定ブランチの first-parent 履歴で数え、merge commit 方式（`Merge pull request #N`）も PR 経由とみなすようにした。
- `g.monitoring_configured`：誤検知の多かった `alert` と `docs` を既定の検索対象から外した。
- remote の URL からリポジトリ名を求める予備処理が、macOS の sed でエラーになっていた問題を直した。

### 変更

- 特定のリポジトリの慣習に寄っていた既定値を、一般的なものにした。
  - スクリプトの既定の配置先を `scripts/ai-sdlc/collect-evidence.sh` にした（`.agents/collect-evidence.sh` も探索する）。
  - 配置先を記録する行に、特定の ID 体系（`P-XXX`）を使わないようにした。
  - データ管理ラベル・ふりかえり PR・定量効果の既定の正規表現から、特定リポジトリ由来の語を外した。
  - 検査を呼ぶ場所として husky / lefthook / justfile / package.json も見るようにした（設定変数 `ENFORCEMENT_FILES`）。
- 設定変数 `ENFORCEMENT_FILES`、`MONITORING_DIRS`、`DATA_GATE_PATTERN`、`AI_COAUTHOR_REGEX` を追加した。

### ライセンス表記

- 生成されるスクリプトのヘッダーに `SPDX-License-Identifier: MIT` と著作権表示を入れた。
- `SKILL.md` の末尾と `criteria.md` に著作権・ライセンスの表示を入れ、スキルのディレクトリだけをコピーしても表示が残るようにした。
- DEFRA の資料について「翻案」という表現をやめ、「観点を参考にし、文言は独自に書き起こした」と書き直した。`criteria.md` に CC BY 4.0 のライセンス URL を追加した。

## [0.0.1] - 2026-09-24

### 追加

- `assessing-ai-sdlc-maturity` スキルを初めて公開。
  - 判定基準シート `criteria.md`（16 項目 × 7 段階、6 軸）
  - 証拠収集スクリプトのテンプレート `templates/collect-evidence.template.sh`（初回実行時に対象リポジトリ専用のスクリプトを生成する）
  - 証拠キーの辞書 `references/evidence-keys.md`
- Claude Code のプラグイン / マーケットプレイスの定義

[0.0.2]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.0.2
[0.0.1]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.0.1
