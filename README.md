# ai-sdlc-maturity-model-skills

GitHub リポジトリの git 履歴・ファイル・Issue・PR・GitHub Actions の状況をもとに、AI を組み込んだソフトウェア開発ライフサイクル（AI-SDLC）の成熟度をアセスメントするエージェントスキルです。

| スキル | 呼び出し | 内容 |
| --- | --- | --- |
| [`assessing-ai-sdlc-maturity`](skills/assessing-ai-sdlc-maturity/SKILL.md) | `/assessing-ai-sdlc-maturity` | 固定の判定基準シート（16 項目 × 7 段階）でリポジトリを採点し、ベースラインと再評価を GitHub の親 Issue に記録する |

## このスキルでできること・できないこと

**できること**

- リポジトリから一次証拠（コミット、PR のレビュー状況、ワークフローの実行結果、ADR、テスト、ラベル等）を読み取り専用で集め、キー付きの JSON にまとめます。
- その JSON を根拠に 16 項目を −1〜5 で採点し、軸ごとのスコア、全体の中央値と最小値、次のレベルへのギャップ、推奨アクションを出します。
- 推奨アクションを、証拠キーで書いた受け入れ基準付きの Issue にします（例：`c.adr_duplicates == 0`）。四半期ごとの再評価では、前回の JSON との差分から説明します。

**できないこと（必ず読んでください）**

- 証拠は **GitHub 上にあるものだけ** です。口頭で合意している手順、Slack や Notion などの別ツールで回しているふりかえり、社内の監視ダッシュボードといった、GitHub で管理していないプロセスは拾えません。そのようなプロセスが多いチームでは、実態より **低く** 採点されます。
- このため、出力は確定した評価ではなく **参考情報** として扱ってください。GitHub の外で回しているプロセスが多い場合は特にそうです。
- 出力は **アセスメントのたたき台（ドラフト）** です。チームのメンバーと一緒に、ドラフトをもとに「この項目は実際にはこう回している」「ここは確かに弱い」と話し合う使い方をおすすめします。話し合いで分かった GitHub の外の実態は、親 Issue にコメントとして残しておくと次回の再評価で役立ちます。

## 必要なもの

- [Claude Code](https://docs.claude.com/en/docs/claude-code)（`SKILL.md` 形式のスキルを読めるエージェント）
- `git`、`jq`、`curl`
- [GitHub CLI](https://cli.github.com/)（`gh`）。対象リポジトリを読める権限で `gh auth login` を済ませておく
- 対象リポジトリが GitHub にあること

## インストール

### ユーザースキルとして入れる（推奨）

すべてのプロジェクトから `/assessing-ai-sdlc-maturity` で呼び出せるようになります。

```sh
git clone https://github.com/kemsakurai/ai-sdlc-maturity-model-skills.git ~/ai-sdlc-maturity-model-skills
mkdir -p ~/.claude/skills
ln -s ~/ai-sdlc-maturity-model-skills/skills/assessing-ai-sdlc-maturity ~/.claude/skills/assessing-ai-sdlc-maturity
```

更新は clone したディレクトリで `git pull` するだけです。symlink を使わずにディレクトリをコピーしてもかまいません。

### Claude Code のプラグインとして入れる

```text
/plugin marketplace add kemsakurai/ai-sdlc-maturity-model-skills
/plugin install ai-sdlc-maturity@ai-sdlc-maturity
```

プラグインとして入れた場合、呼び出し名は `/ai-sdlc-maturity:assessing-ai-sdlc-maturity` になります。

## 使い方

対象リポジトリのディレクトリで Claude Code を起動して、次のように呼び出します。モデルが自動で起動することはなく、明示的に呼び出したときだけ動きます。

```text
/assessing-ai-sdlc-maturity                 # カレントのリポジトリを初回評価する
/assessing-ai-sdlc-maturity path/to/repo    # パスを指定する
/assessing-ai-sdlc-maturity 再評価 #123      # 親 Issue #123 のベースラインと比べて再評価する
```

初回の流れは次のとおりです。

1. リポジトリの構成（言語、テストの書き方、CI、ADR の場所、ラベル体系など）を調べ、同梱のテンプレートから、そのリポジトリ専用の証拠収集スクリプト（既定は `.agents/collect-evidence.sh`）を生成します。配置先は実行時に確認されます。生成したパスは `AGENTS.md` か `CLAUDE.md` に 1 行記録されます。
2. スクリプトを実行して証拠の JSON を得ます。スクリプトは読み取り専用で、`.env` には触れません。既定の集計期間は 90 日です。
3. `criteria.md` に沿って採点し、結果を出力します。
4. 結果と JSON を GitHub の親 Issue に記録し、推奨アクションを 1 件ずつ Issue にします。

生成されたスクリプトはリポジトリにコミットしてください。次回からはそれを使うので、再評価で同じ物差しを保てます。

## 採点の考え方

- **尺度**：−1（抵抗）/ 0（場当たり）/ 1（探索）/ 2（構造化）/ 3（確立）/ 4（統合）/ 5（変革）の 7 段階。1 から連続して満たした最高レベルがその項目のスコアです。
- **存在と運用は区別します**：ルールやワークフローが「ある」だけならレベル 2 止まりです。レベル 3 以上には、実行の実績（成功した実行の件数、日付、ログ）が必要です。
- **全体スコア**は、全項目の中央値と最小値（階層準拠）を併記します。最小値を決めている項目が、いちばん大きな運用リスクです。
- 判定基準の全文は [`criteria.md`](skills/assessing-ai-sdlc-maturity/criteria.md)、証拠キーの意味は [`references/evidence-keys.md`](skills/assessing-ai-sdlc-maturity/references/evidence-keys.md) にあります。

## 構成

```text
.
├── .claude-plugin/            # Claude Code プラグイン / マーケットプレイスの定義
├── skills/
│   └── assessing-ai-sdlc-maturity/
│       ├── SKILL.md           # スキル本体（手順）
│       ├── criteria.md        # 判定基準シート
│       ├── references/
│       │   └── evidence-keys.md
│       └── templates/
│           └── collect-evidence.template.sh
├── CHANGELOG.md
└── LICENSE
```

## バージョン

[Semantic Versioning](https://semver.org/lang/ja/) に従います。`criteria.md` の文言を変えると以前の採点と比較できなくなるので、判定基準を変えたときは少なくともマイナーバージョンを上げます。証拠 JSON の `header.criteria_version` と `header.skill_version` に、どの版で採点したかが残ります。変更履歴は [`CHANGELOG.md`](CHANGELOG.md) を参照してください。

## 出典とライセンス

このリポジトリのコードと文書は [MIT License](LICENSE) で公開しています。ただし、以下の第三者の資料はそれぞれの権利者とライセンスに従います。

- **DEFRA「AI-SDLC Maturity Assessment」**（<https://github.com/DEFRA/ai-sdlc-maturity-assessment>）：7 段階の尺度、次元の名前、階層準拠の採点法を参照しています。項目別の判定基準は、各次元ページの Sample assessment questions を参考に独自に翻案・再構成したものです。DEFRA の尺度の定義文は収録していないので、原文はリンク先を参照してください。
- **Gigacore「AI-Maturity-Model」**（<https://github.com/Gigacore/AI-Maturity-Model>、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)）：6 つの軸とレベル名を、日本語化して項目に対応づけるという改変を加えて使っています。

このスキルは DEFRA とも Gigacore とも無関係の非公式なものです。
