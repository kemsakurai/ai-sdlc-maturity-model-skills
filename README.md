# ai-sdlc-maturity-model-skills

> **English summary** — An agent skill (Claude Code `SKILL.md` format) that assesses how maturely a team uses AI across its software development lifecycle (AI-SDLC). It collects read-only evidence from a GitHub repository — git history, files, Issues, PRs and GitHub Actions runs — and scores 16 items on a fixed 7-level scale (−1 to 5) adapted from DEFRA's AI-SDLC Maturity Assessment and Gigacore's AI-Maturity-Model. Because only what lives on GitHub counts as evidence, processes run elsewhere score low: treat the output as a draft to discuss with your team, not a final verdict. The skill, its criteria and this README are written in Japanese. Licensed under MIT.

GitHub リポジトリの git 履歴・ファイル・Issue・PR・GitHub Actions の状況をもとに、AI を組み込んだソフトウェア開発ライフサイクル（AI-SDLC）の成熟度をアセスメントするエージェントスキルです。

| スキル | 呼び出し | 内容 |
| --- | --- | --- |
| [`assessing-ai-sdlc-maturity`](skills/assessing-ai-sdlc-maturity/SKILL.md) | `/assessing-ai-sdlc-maturity` | 固定の判定基準シート（16 項目 × 7 段階）でリポジトリを採点し、ベースラインと再評価を GitHub の親 Issue に記録する |

## このスキルでできること・できないこと

**できること**

- リポジトリから一次証拠（コミット、PR のレビュー状況、ワークフローの実行結果、ADR、テスト、ラベル等）を読み取り専用で集め、キー付きの JSON にまとめます。
- その JSON を根拠に 16 項目を −1〜5 で採点し、軸ごとのスコア、全体の中央値と最小値、次のレベルへのギャップ、推奨アクションを出します。
- 推奨アクションを、証拠キーで書いた受け入れ基準付きの Issue にします（例：`c.adr_duplicates == []`）。四半期ごとの再評価では、前回の JSON との差分から説明します。

**できないこと（必ず読んでください）**

- 証拠は **GitHub 上にあるものだけ** です。口頭で合意している手順、Slack や Notion などの別ツールで回しているふりかえり、社内の監視ダッシュボードといった、GitHub で管理していないプロセスは拾えません。そのようなプロセスが多いチームでは実態より **低く** 採点されるので、結果は **参考情報** として扱ってください。
- 出力は確定した評価ではなく、**アセスメントのたたき台（ドラフト）** です。チームのメンバーと一緒に、ドラフトをもとに「この項目は実際にはこう回している」「ここは確かに弱い」と話し合う使い方をおすすめします。話し合いで分かった GitHub の外の実態は、親 Issue にコメントとして残しておくと次回の再評価で役立ちます。

どんなレポートが出るかは、架空のリポジトリで作った [出力例](docs/example-report.md) を見てください。

## 必要なもの

- [Claude Code](https://docs.claude.com/en/docs/claude-code)（`SKILL.md` 形式のスキルを読めるエージェント）
- `git`、`jq`、`curl`
- [GitHub CLI](https://cli.github.com/)（`gh`）。対象リポジトリを読める権限で `gh auth login` を済ませておく。`gh` が入っていないクラウド環境（Claude Code on the web 等）では、[公式のリリース](https://github.com/cli/cli/releases) からバイナリを取得し、環境変数 `GH_TOKEN` で認証する。証拠の収集は GraphQL API が使えない環境でも REST API で動く
- 対象リポジトリが GitHub にあること

## インストール

### ユーザースキルとして入れる（推奨）

すべてのプロジェクトから `/assessing-ai-sdlc-maturity` で呼び出せるようになります。

```sh
git clone https://github.com/kemsakurai/ai-sdlc-maturity-model-skills.git ~/ai-sdlc-maturity-model-skills
mkdir -p ~/.claude/skills
ln -s ~/ai-sdlc-maturity-model-skills/skills/assessing-ai-sdlc-maturity ~/.claude/skills/assessing-ai-sdlc-maturity
```

更新は clone したディレクトリで `git pull` するだけです。symlink を使わずに `skills/assessing-ai-sdlc-maturity` ディレクトリをコピーしてもかまいません。著作権・ライセンスの表示は `SKILL.md` の末尾と `criteria.md` の「出典とライセンス」節に入っているので、コピーするときはそれらを消さないでください。

### Claude Code のプラグインとして入れる

```text
/plugin marketplace add kemsakurai/ai-sdlc-maturity-model-skills
/plugin install ai-sdlc-maturity@ai-sdlc-maturity
```

プラグインとして入れた場合、呼び出し名は `/ai-sdlc-maturity:assessing-ai-sdlc-maturity` になります。

### インストールせずに使う

クラウドのセッションなどで、利用者のホームディレクトリ（`~/.claude/skills`）に書けないときは、インストールせずに使えます。このリポジトリを作業用のディレクトリに clone し、エージェントに `skills/assessing-ai-sdlc-maturity/SKILL.md` を読ませて、その手順どおりに評価するよう頼みます。`criteria.md`・`references/`・`templates/` は `SKILL.md` からの相対パスで参照されるので、ディレクトリの構成は変えないでください。

```sh
git clone https://github.com/kemsakurai/ai-sdlc-maturity-model-skills.git /tmp/ai-sdlc-maturity-model-skills
# エージェントへの依頼の例：
#   /tmp/ai-sdlc-maturity-model-skills/skills/assessing-ai-sdlc-maturity/SKILL.md を読み、
#   その手順で path/to/repo を評価して。書き込みなしで。
```

## 使い方

対象リポジトリのディレクトリで Claude Code を起動して、次のように呼び出します。モデルが自動で起動することはなく、明示的に呼び出したときだけ動きます。

```text
/assessing-ai-sdlc-maturity                 # カレントのリポジトリを初回評価する
/assessing-ai-sdlc-maturity path/to/repo    # パスを指定する
/assessing-ai-sdlc-maturity 再評価 #123      # 親 Issue #123 のベースラインと比べて再評価する
/assessing-ai-sdlc-maturity 再評価 ./assessment-2026-09-25.json  # ファイルに保存したベースラインと比べる
/assessing-ai-sdlc-maturity 書き込みなし     # 対象リポジトリにも GitHub にも書き込まずに評価する
```

初回の流れは次のとおりです。

1. リポジトリの構成（言語、テストの書き方、pre-commit・タスクランナー・CI、ADR の場所、ラベル体系など）を調べ、同梱のテンプレートから、そのリポジトリ専用の証拠収集スクリプト（既定は `scripts/ai-sdlc/collect-evidence.sh`）を生成します。配置先は実行時に確認されます。生成したパスは、エージェント向けの指示書（`AGENTS.md` / `CLAUDE.md` など。無ければ README）に 1 行記録されます。
2. スクリプトを実行して証拠の JSON を得ます。スクリプトは読み取り専用で、`.env` には触れません。既定の集計期間は 90 日です。
3. `criteria.md` に沿って採点し、結果を出力します。
4. 結果と JSON を GitHub の親 Issue に記録し、推奨アクションを 1 件ずつ Issue にします。書き込む前に、投稿先と内容が示されて確認を求められます。Issue に記録しないときは、JSON とレポートをファイル（`assessment-<評価日>.json` / `.md`）に保存でき、次回の再評価でそのパスを渡せます。

生成されたスクリプトはリポジトリにコミットしてください。次回からはそれを使うので、再評価で同じ物差しを保てます。スクリプトのヘッダーには MIT の著作権表示が入っています。コミットするときも残してください。

リポジトリに書き込めない、または書き込みたくないときは「書き込みなし」で呼び出します。スクリプトはリポジトリの外に一時的に生成され、指示書への追記も Issue の作成もしません。スクリプトに埋めた設定値は証拠 JSON の `header.config` に残るので、次回も同じ物差しでスクリプトを再生成できます。

評価するのは、手元のチェックアウトで git が追跡しているファイルです。手元が既定ブランチの最新より古いと、最近追加された指示書などが欠けます。スキルは実行前にずれを確かめ、必要なら最新の既定ブランチを一時的な worktree に取り出して評価します（作業ツリーには触れません）。

### GitHub への書き込みと個人名について

- このスキルは、対象リポジトリに **Issue を作成し、コメントを投稿します**。Issue を作れる権限で `gh auth login` している必要があります。書き込みは毎回、実行前に確認されます。
- 証拠 JSON には、コミット著者名（`header.authors_top5`）と PR 作成者のログイン名（`l.pr_authors_window`）が含まれます。Public リポジトリでは、これらを `author-1` のような仮の名前に置き換えて収集します（証拠収集スクリプトの `--anonymize-authors`）。件数や順位はそのまま残ります。
- 他人が管理するリポジトリで使うときは、Issue を作る前にメンテナーの了解を得てください。

## 採点の考え方

- **尺度**：−1（抵抗）/ 0（場当たり）/ 1（探索）/ 2（構造化）/ 3（確立）/ 4（統合）/ 5（変革）の 7 段階。1 から連続して満たした最高レベルがその項目のスコアです。
- **存在と運用は区別します**：ルールやワークフローが「ある」だけならレベル 2 止まりです。レベル 3 以上には、実行の実績（成功した実行の件数、日付、ログ）が必要です。
- **全体スコア**は、全項目の中央値と最小値（階層準拠）を併記します。最小値を決めている項目が、いちばん大きな運用リスクです。
- 判定基準の全文は [`criteria.md`](skills/assessing-ai-sdlc-maturity/criteria.md)、証拠キーの意味は [`references/evidence-keys.md`](skills/assessing-ai-sdlc-maturity/references/evidence-keys.md) にあります。

## 構成

```text
.
├── .claude-plugin/            # Claude Code プラグイン / マーケットプレイスの定義
├── .github/workflows/test.yml # CI（shellcheck と tests/ の実行）
├── docs/
│   └── example-report.md      # 出力例（架空のリポジトリ）
├── tests/
│   ├── template_test.sh       # 証拠収集テンプレートの回帰テスト
│   └── consistency_test.sh    # 版番号・証拠キーのファイル間の整合性チェック
├── skills/
│   └── assessing-ai-sdlc-maturity/
│       ├── SKILL.md           # スキル本体（手順）
│       ├── criteria.md        # 判定基準シート
│       ├── references/
│       │   └── evidence-keys.md
│       └── templates/
│           ├── collect-evidence.template.sh
│           └── report.template.md   # レポートの雛形
├── CHANGELOG.md
├── LICENSE                    # MIT License
├── README.md
└── THIRD_PARTY_NOTICES.md     # 参照・改変した第三者資料とそのライセンス
```

## バージョン

[Semantic Versioning](https://semver.org/lang/ja/) に従います。スキル本体と判定基準シートは 1 つの版番号を共有し、証拠 JSON の `header.skill_version` と `header.criteria_version` には常に同じ値が入ります。

- **patch**（例：0.1.0 → 0.1.1）：判定基準の文言は変えません。証拠の収集方法の修正や文書の手直しです。patch だけが違う版どうしの採点は比較できます。
- **minor 以上**（例：0.1.x → 0.2.0）：判定基準の文言や項目を変えます。以前の採点とは、そのままでは比較できません。

変更履歴は [`CHANGELOG.md`](CHANGELOG.md) を参照してください。

## 出典とライセンス

このリポジトリのコードと文書は [MIT License](LICENSE) で公開しています。ただし、以下の第三者の資料はそれぞれの権利者とライセンスに従います。詳しくは [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) を参照してください。

- **DEFRA「AI-SDLC Maturity Assessment」**（<https://github.com/DEFRA/ai-sdlc-maturity-assessment>）：7 段階の尺度、次元の名前、階層準拠の採点法を参照しています。項目別の判定基準は、各次元ページにある Sample assessment questions の観点を参考にし、文言は独自に書き起こしたものです。DEFRA の文章は収録していないので、原文はリンク先を参照してください。
- **Gigacore「AI-Maturity-Model」**（<https://github.com/Gigacore/AI-Maturity-Model>、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)）：6 つの軸とレベル名を、日本語化して項目に対応づけるという改変を加えて使っています。

このスキルは DEFRA とも Gigacore とも無関係の非公式なものです。
