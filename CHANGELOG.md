# 変更履歴

このプロジェクトは [Semantic Versioning](https://semver.org/lang/ja/) に従います。スキル本体と判定基準シートは 1 つの版番号を共有します。`criteria.md` の判定基準を変えたときは、以前の採点と比較できなくなるので、少なくともマイナーバージョンを上げます。patch だけが違う版どうしの採点は比較できます。

## [0.2.0] - 2026-09-25

kemsakurai/action-pmd でのドッグフーディング（Claude Code on the web で実行）で見つかった問題を直しました。`criteria.md` に N/A の規定を加えたので、minor バージョンを上げました。各レベルの判定基準の文言は変えていません。0.1.x の採点と比べるときは、N/A にした項目を除いたうえで、下の「証拠の値が変わるキー」の影響を確かめてください。

### 判定基準（`criteria.md`）

- リポジトリの種類ごとの N/A 注記を加えた。本番環境を持たないライブラリ・GitHub Action・CLI では G（監視）を N/A にでき、H（データ管理）と M（合成ユーザーリサーチ）も条件付きで N/A にできる。データ基盤では M を条件付きで N/A にできる。N/A の項目は集計（軸スコア・中央値・平均・最小値）から除く。
- AI 以外の自動化が充実していても、AI の基準を満たさない項目はスコアを上げず、所見に書くことを明記した。

### 修正

- 生成した証拠収集スクリプトが自分自身の本文に一致し、監視の設定が無いリポジトリでも `g.monitoring_configured` が `true` になっていた。`MONITORING_DIRS` の既定値に入っている `scripts` の下に、既定の配置先 `scripts/ai-sdlc/` があったため。設定ファイルの grep（監視・ゲート・ドキュメントの検索）の対象から、スクリプト自身とテンプレートを外した。`scripts` は、本物の監視スクリプトを見落とさないように既定値に残した。
- GraphQL API が使えない環境（Claude Code on the web 等）で、GitHub から取る 11 キーがすべて `null` になっていた。最初の確認に `gh repo view`（GraphQL）を使っていたため。
  - 対象の `owner/name` を git のリモートから決め、疎通確認・Issue のラベル一覧・件数の取得を REST API（`gh api`）に置き換えた。
  - `l.*` の PR 一覧だけは GraphQL（1 回で済む）で取り、失敗したら REST API（検索 API と PR ごとの API）で取り直す。bot のログインは、どちらの経路でも `app/<name>` の表記にそろえる。
- HTTP 403 と「GraphQL is not available」を、再試行しても直らない失敗として扱い、再試行しないようにした（1 か所あたり約 9 秒の待ちが無くなる）。ただし、レート制限による 403 は再試行する。

### 追加

- GitHub Copilot のパス別指示書（`.github/instructions/`）、`.github/prompts`、`.github/chatmodes`、`.windsurfrules`、`.clinerules`、`CONVENTIONS.md` を、`a.agent_instruction_files`・`i.tool_integration_files`・`j.governance_docs_present` の探索対象に加えた（`i.*` には `CONVENTIONS.md` を除く）。
- 出力 JSON のヘッダーに `last_commit_date`（最後のコミットの日付）と `single_author_basis`（単独メンテナと判定した根拠）を加えた。
- 証拠キーに `note` を加えた。集計期間にコミットが無いとき、`d.commits_window`（0）と `d.pr_commit_ratio_window`（`null`）に理由が入る。`gh` の失敗による `null` と見分けられる。
- `SKILL.md`：`gh` を使えない環境で、GitHub MCP のツールや REST API で値を補完する手順と、その記録方法（`"supplemented": true`）を加えた。休眠中のリポジトリで集計期間を確かめる手順、配置先の確認に応答が無いときの扱い、リポジトリの種類の判断と N/A の集計の仕方を加えた。未運用の兆候として、ワークフローの `action_required`（承認待ちで実行されていない）を `skipped` と並べて挙げた。
- テスト：GraphQL だけが使えない場合、レート制限、リモートが無い・休眠中のリポジトリ、スクリプトを既定のパスに置いた場合、`.mailmap` と PR の作成者による単独メンテナの判定のケースを加えた。偽の `gh` は REST API の生の応答を返し、`--jq` の式は本物の `jq` で評価する。

### 変更

- 単独メンテナの判定（`header.single_author`）：コミット著者を `.mailmap` で名寄せし（`git log --use-mailmap`）、bot を除いて数えるようにした。コミット著者が 2 名以上でも、集計期間にマージされた PR の作成者（bot を除く）が 1 名なら `true` にする。`header.authors_top5` も名寄せ後の名前になる。

### 証拠の値が変わるキー

実在する 2 つのリポジトリ（kemsakurai/action-pmd、kemsakurai/scrum-guides）で 0.1.2 と比べた結果です。ほかのキーの値は 0.1.2 と同じでした。

- `a.agent_instruction_files`・`i.tool_integration_files`・`j.governance_docs_present`：上記の探索対象を置いているリポジトリで値が変わる（action-pmd では `[]` → `[".github/instructions"]`、`false` → `true`）。
- `b.issues_open_count`・`b.issues_closed_count`・`m.user_research_issues_count`：検索 API の `total_count` で数えるので、上限（500・1000）に張り付かなくなった（`limit` は `null`）。scrum-guides の `b.issues_closed_count` は 1000 → 1178。
- `n.retro_prs_window_count`：0.1.x では GraphQL の検索で `in:title` が OR の全体に効かず、タイトルにふりかえり系の語を含まない PR まで数えていた。scrum-guides では 40 → 4（40 件のうちタイトルに該当する語を含むのは 4 件だけ）。
- `g.monitoring_configured`：証拠収集スクリプトを `MONITORING_DIRS` の中に置いていたリポジトリでは、`true` から `false` に変わることがある（誤検知が無くなる）。
- `header.authors_top5`・`header.single_author`：`.mailmap` があるリポジトリや、bot のコミットがあるリポジトリで変わる。

## [0.1.2] - 2026-09-24

判定基準（`criteria.md` の文言）は 0.1.1 と同じです。`gh` がすべて成功したときの証拠の値も 0.1.1 と同じです（実在するリポジトリで 44 キーすべての一致を確認）。

### 修正

- `gh` が失敗したとき、エラーにならずに `0` や `{}` を書き込んでいた問題を直した。一時的な失敗でも「実態が 0」と区別できなかった。
  - 一時的な失敗（ネットワーク、API の 5xx、レート制限など）は、間隔を空けて `GH_RETRY_MAX` 回（既定 3）まで試す。間隔は `GH_RETRY_SLEEP`（既定 3 秒）× 試行回数。
  - 未認証・リモートが無い・HTTP 401/404 のように、再試行しても直らない失敗は再試行しない。
  - それでも取得できなかったキーは `value: null` とし、`error` に理由を残す。
  - 実行の最初に `gh` を使えるかを確かめ、使えなければ GitHub 由来のキーを再試行せずにすべて `null` で記録する。

### 追加

- 出力 JSON のヘッダーに `gh_available`（`gh` を使えたか）と `collection_errors`（取得できなかったキーの一覧）を加えた。取得できなかったキーがあると、標準エラーに警告を出す。
- `SKILL.md`：`value` が `null` のキーを 0 として採点せず、再実行しても取れなければ「未取得」と明記するルールを加えた。
- テストに偽の `gh` を使うケースを加えた（リモートが無い・一時的な失敗・継続的な失敗・再試行しても直らない失敗）。本物の `gh` やネットワークには触れない。

### 変更

- `l.pr_review_stats_window` と `l.pr_authors_window` のための PR 一覧の取得を、2 回から 1 回にまとめた。

## [0.1.1] - 2026-09-24

判定基準（`criteria.md` の項目・レベルの文言）は 0.1.0 と同じです。`--anonymize-authors` を付けずに実行したときの証拠の値も 0.1.0 と同じです。ただし `l.pr_authors_window` は、件数の多い順に並ぶようになりました。

### 追加

- 証拠収集スクリプトに `--anonymize-authors` を追加した。コミット著者名と PR 作成者のログイン名を `author-1`・`pr-author-1` のような仮の名前に置き換える（bot は除く）。出力 JSON の `header.authors_anonymized` に、置き換えたかどうかが残る。
- `tests/template_test.sh`（証拠収集テンプレートの回帰テスト）と `tests/consistency_test.sh`（版番号・証拠キーのファイル間の整合性チェック）を追加し、GitHub Actions で shellcheck とあわせて実行するようにした。

### 変更

- `SKILL.md`：GitHub への書き込み（Issue の作成・コメント）の前に、投稿先と内容を示してユーザーの確認を取る手順を加えた。Public リポジトリでは `--anonymize-authors` を付けて収集するようにした。
- README：スキルが GitHub に書き込むこと、証拠 JSON に個人名が含まれることと、その扱いを書いた。
- `l.pr_authors_window` を件数の多い順に並べるようにした（`header.authors_top5` とそろえた）。

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

[0.1.2]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.1.2
[0.1.1]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.1.1
[0.1.0]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.1.0
[0.0.2]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.0.2
[0.0.1]: https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/releases/tag/v0.0.1
