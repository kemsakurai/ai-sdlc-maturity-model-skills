# 証拠収集器のセットアップ・互換性・実行準備

`SKILL.md` の手順 2（および書き込みなしモードの手順 6）で、以下の分岐に該当したときに参照する。

## 収集スクリプトの探索順序

1. エージェント向け指示書（`AGENTS.md` / `CLAUDE.md` / `GEMINI.md` / `.github/copilot-instructions.md` / `.github/instructions/*.instructions.md` 等）や README に書かれた `collect-evidence.sh` のパス
2. 標準パス（`scripts/ai-sdlc/collect-evidence.sh`、`scripts/collect-evidence.sh`、`.agents/collect-evidence.sh`）
3. 書き込みなしモードでの再評価なら、ベースラインの証拠 JSON の `header.config` と `header.skill_version`（同じ版のテンプレート）から再生成する

## 評価対象コミットと実行準備

実行前に、対象リポジトリの現在のブランチ、未コミットの変更（`git status --short`）、既定ブランチとのずれ（`git rev-list --count HEAD..origin/<既定ブランチ>`）、最後に fetch した日時を確かめる。

- 既定ブランチの最新と違えば、そのことをユーザーに知らせ、どれを評価するかを決める。
- 最新を評価するときは作業ツリーに触れず、`git fetch` のうえで `git worktree add <一時ディレクトリ> origin/<既定ブランチ>` で取り出し、そのディレクトリを対象に実行する（終了後に `git worktree remove` で片付ける）。
- 実行後に標準エラーへ既定ブランチとのずれ警告が出たら、この確認に戻る。
- 実行後は `header.evaluated_ref` を確認し、評価したブランチとコミットをレポートの「評価の対象」に書く。

## 既存収集器の互換性検査と救済

既存の `collect-evidence.sh`（または既存の証拠 JSON）を使う場合、実行前または採点前に `CRITERIA_VERSION` / `SKILL_VERSION`（JSON の `header.criteria_version` / `header.skill_version`）と本スキルの `criteria.md` の版、および必要な必須キー（`a.rule_files_count`, `a.rule_change_commits_window`, `i.agent_hooks_count`, `i.agent_permission_denies_count`, `k.coauthored_ratio_window`, `l.ai_pr_stats_window`, `header.evaluated_ref` 等）が揃っているかを検査する。

非互換または必須キーが欠落している場合は、次の順で対処する。

1. **更新**：通常モード（または書き込みなしモードの一時生成）なら、`header.config` 等の設定を引き継いで最新テンプレートから再生成して収集し直す。
2. **補完**：スクリプトを更新せず旧版 JSON を使う場合は、`references/evidence-keys.md` のクエリ等で取得できる欠落キーを補完し（`"supplemented": true`）、取得できないキーは「未収集」とする。
3. **保留**：判定に必須のキーが欠落し補完もできない項目はスコアを保留（または根拠不足として低い方を採り）し、評価の限界に旧版収集器の版と未収集キーを書く。

旧版収集器が出力した JSON の `header.criteria_version` / `header.skill_version` は書き換えず元の版番号を保持し、レポートの「評価の対象」と「評価の限界」で採点基準の版と収集器の版を分けて明記する。

## 初回スキャフォールド

対象リポジトリに `collect-evidence.sh` が無い場合、次の順で生成する。

1. **対象リポジトリの構成調査**：主要言語、テストランナーとテストファイルの命名、pre-commit・タスクランナー・CI の定義、デプロイ用ワークフロー、ADR ディレクトリ、変更履歴ファイル、エージェント向けルールの変更履歴とルールファイル、設計・運用ドキュメントのディレクトリ、ラベル体系、AI エージェントのコミット署名、AI レビュアーと PR 作成 AI エージェントのログインを調べる。
2. **既定正規表現の誤一致確認**：既定値の正規表現が誤って一致しないか確かめる。特にデプロイ系ワークフロー既定値の `release` はリリースブランチ保護等にも一致しやすいため、一致一覧を確認し必要なら `DEPLOY_WORKFLOW_REGEX` を絞る。カバレッジ下限（JVM なら JaCoCo・Kover の設定ファイル）とテストファイル命名も同様に確かめる。
3. **配置先の確認**：ユーザーに配置先のパスを確認する（既定：`scripts/ai-sdlc/collect-evidence.sh`）。対話できない実行（クラウドセッション、CI 等）で応答が無いときは既定パスを使い、結果の報告にそのパスを書く。
4. **テンプレートからの生成**：`templates/collect-evidence.template.sh` を読み込み、設定ブロックの `{{...}}` を手順 1〜2 の値に置き換えてスクリプトを生成し、`chmod +x` する。該当が無い項目は空文字（既定値が使われる）にし、引用符の制約は設定ブロック冒頭のコメントに従う。ヘッダーの著作権・ライセンス表示（MIT）はそのまま残す。
5. **指示書への記録**：配置先のパスを、そのリポジトリがエージェント向けに使っている指示書（無ければ README）に 1 行記録する（例：`- AI-SDLC 成熟度アセスメントの証拠収集スクリプト: \`<指定パス>\``）。書き込みなしモードでは記録しない。

## 書き込みなしモードと外部リポジトリ取得

引数に `書き込みなし` / `no-write` が指定された場合、または対象リポジトリに依頼範囲外のファイルを変更しない規約がある場合は、次の制約で実行する。

- スクリプトは対象リポジトリの外（一時ディレクトリやエージェント作業用ディレクトリ）に生成し、対象リポジトリのパスを引数に渡して実行する。
- 指示書や README へのパス記録（上記ステップ 5）は行わない。設定値は証拠 JSON の `header.config` に残るため、次回は `header.skill_version` と同じ版のテンプレートから再生成できる。
- レポートと証拠 JSON は GitHub へ書き込まず、対象リポジトリ外のユーザー指定場所へファイルとして保存する（ファイル名は `SKILL.md` 手順 6 を参照）。
- 外部リポジトリを一時ディレクトリ等へ clone して評価する際、対象が Git LFS を利用していると環境によって checkout が中断することがあるため、`GIT_LFS_SKIP_SMUDGE=1 git clone --depth 100 <URL> <一時ディレクトリ>`（または `git -c filter.lfs.required=false checkout`）で取得する。

## ヘッダー確認と例外対応

`evidence.json` 取得後、`header` の各項目を確認し該当する手順を実行する（各フィールドの定義は `references/evidence-keys.md` を参照）。

- **改名・リダイレクト**（`header.repository_input` ≠ `header.repository`）：スクリプトは `repos/<owner/name>` の `.full_name` で正式名を解決する。必要なら環境変数 `GH_REPO=<owner/name>` で明示して再実行し、レポートの「評価の対象」に旧名も併記する。
- **取得失敗**（`header.collection_errors` が非空）：一時的な失敗が多いためまずスクリプトを再実行する。`header.gh_available` が `false` なら `gh auth status` とリモートを確認する。
- **`gh` を使えない環境**：まず公式リリースから `gh` バイナリを用意し `GH_TOKEN` で認証できないか試す。用意できなければ `references/evidence-keys.md` の「GitHub MCP・検索 API で補完するときのクエリ」を必読のうえ、GitHub MCP または REST API（`curl` + `GH_TOKEN`）で `null` のキーを補完する。件数だけが要るキーは `per_page=1` で取得して `total_count` のみを読む。補完したキーに `"supplemented": true`、近似値には `"approximation": "<方法>"` を付け、一覧を評価の限界に書く（GraphQL 遮断自体は REST 自動フォールバックがあるため補完理由にならない）。
- **休眠リポジトリ**（`header.last_commit_date` < `header.window.start`）：集計期間の指標は 0 や `null` になる。集計期間を広げて再実行するか（`--window-days`）、そのままにするかをユーザーに確認し、選んだ方針をレポートに書く。
- **単独メンテナ**（`header.single_author`）：`false` でも `header.authors_top5` が同一人物の別名に見えるときはユーザーに確認してから `criteria.md` の N/A 注記を当てる。
