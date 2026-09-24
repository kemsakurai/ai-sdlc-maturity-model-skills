# 変更履歴

このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に従います。スキル本体と判定基準シートは 1 つの版番号を共有します。`criteria.md` の判定基準を変えたときは、以前の採点と比較できなくなるので、少なくともマイナーバージョンを上げます。patch だけが違う版どうしの採点は比較できます。

## [0.1.0] - 2026-09-24

`criteria.md` の判定基準の文言を変えたので、minor バージョンを上げました。変えたのは、特定のリポジトリの運用に由来する用語の言い換えだけで、各レベルが求める水準は変えていません。それでも 0.0.x の採点と比べるときは、下の「判定基準の文言」に挙げた項目のスコアが、言い換えで変わっていないかを確かめてください。証拠収集スクリプトが出力する値は 0.0.2 と同じです。

### 判定基準の文言（`criteria.md`）

- 尺度のレベル 3、A-3：「ルール ID」「ID 付きルール」→「識別子付きのルール」
- B-2：「ready-for-agent 等」→「エージェントが着手できる状態を示すラベル等」
- D-4：「code-map」→「コードベースの索引」
- E-4：「AI ペルソナ探索テスト等」→「AI ペルソナによる探索的テスト等」
- F-3：「戻し手順」→「ロールバック手順」
- H-3：「整合性ゲート・ライセンス分類・派生物ドリフト検査が機械化されている」→「データの整合性検査・ライセンスの分類・派生データと元データのずれの検査が自動化されている」
- I-1：「承認ツールをプラグイン的に利用する」→「組織が承認したツールを拡張機能として利用する」
- N-3：「ルールの統合 / 剪定 / 昇格」→「ルールの統合・削除・格上げ」
- O-4：「ランナー」→「CI の実行環境」
- 半角のコロンを全角にそろえた。

### 変更

- 版の方針を明記した。スキル本体と判定基準シートで 1 つの版番号を使い、major・minor が同じなら（patch だけが違っても）採点を比較できる。`criteria.md`、`SKILL.md`、README、この CHANGELOG に書いた。
- LICENSE を MIT License の本文だけに戻し、第三者資料の表示を `THIRD_PARTY_NOTICES.md` に移した。GitHub が LICENSE を MIT と判定できていなかったため。
- 受け入れ基準の例 `c.adr_duplicates == 0` を `c.adr_duplicates == []` に直した（このキーの値は配列）。
- `SKILL.md`：記録の手順（ベースライン・推奨アクション・再評価・校正）を分けて書き、長い文を分けた。「固定評価表」を「判定基準シート」に、「既定窓」を「既定の集計期間（窓）」にそろえた。スキャフォールドで調べる対象に「エージェント向けルールの変更履歴」を加えた。
- README：「参考情報」と「たたき台」の説明の重なりを整理した。構成図に README と `THIRD_PARTY_NOTICES.md` を加えた。

### 証拠収集スクリプトのテンプレート

出力する値は変えていません（実在するリポジトリで、0.0.2 と 44 キーすべての値が一致することを確認）。

- 設定ブロック冒頭に、値の引用符の制約を書いた。コメントの例を、一重引用符の中にそのまま入れても壊れない形に直した。
- Issue のラベル一覧の取得を 3 回から 1 回にした。
- ADR の索引・テンプレートを除外する正規表現を 1 つにまとめた。
- `uniq -c` の出力を JSON にする処理を関数にまとめた。
- 変数名を分かりやすくした（`Q_PTN` → `QUANT_PTN`、`c` → `smoke_hits`、`J_CODEQL` → `J_SECURITY_WF`）。キー名は変えていない。
- `emit` に渡すコマンドの要約を英語にそろえた。エラーメッセージとコメントの文体をそろえた。

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
  - 配置先を記録する行に、リポジトリ固有のルール ID を使わないようにした。
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

[0.1.0]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.1.0
[0.0.2]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.0.2
[0.0.1]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.0.1
