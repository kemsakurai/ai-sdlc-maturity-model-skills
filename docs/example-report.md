# 出力例：AI-SDLC 成熟度アセスメント

> **これは架空のリポジトリ `example-org/todo-api` を想定した出力例です。** 数値もチームの状況も実在しません。スキルが出すレポートの形と、証拠から採点までのつながりを示すために作りました。実際の出力は、対象リポジトリや実行するエージェントによって細部が変わります。

- 対象：`example-org/todo-api`（Python の API サーバーと TypeScript の管理画面。開発者 3 名、GitHub Copilot と Claude Code を併用）
- 評価日：2026-09-24（集計期間：2026-06-26〜2026-09-24、90 日）
- 判定基準シート：0.1.1
- 証拠：`scripts/ai-sdlc/collect-evidence.sh --anonymize-authors` の出力（末尾に抜粋）

---

## 結論

| 指標 | 値 |
| --- | --- |
| 全項目の中央値（平均） | **2**（1.9） |
| 階層準拠（全項目の最小値） | **0**（M. 合成ユーザーリサーチ、N. 継続的改善のフィードバックループ） |

コーディングからデプロイまでの流れには AI が組み込まれ、ルールとして明文化されています（多くの項目が 2、一部が 3）。一方で、ふりかえりとユーザーリサーチの記録が GitHub に残っておらず、全体の最小値を 0 に下げています。ただし、ふりかえりは GitHub の外（オンラインホワイトボード）で毎スプリント行っているとチームから聞いています。N の 0 は「実施していない」ではなく「GitHub から確認できない」という意味です。

## KPI

| 指標 | 値 | 証拠キー |
| --- | --- | --- |
| 集計期間のコミット数 | 380 | `d.commits_window` |
| PR 経由のコミットの割合 | 0.96 | `d.pr_commit_ratio_window` |
| AI 関与率（下限値） | 0.41 | `k.coauthored_ratio_lower_bound` |
| マージされた PR のうちレビュー付き | 190 / 212 | `l.pr_review_stats_window` |
| デプロイの成功回数（集計期間） | 58 | `f.deploy_runs` |
| デプロイ後の検証ステップ | 0 | `f.smoke_steps` |

AI 関与率は、AI エージェントの `Co-authored-by` を持つコミットの割合です。トレーラーを付けずに AI を使ったコミットは数えられないので、下限値として読んでください。

## 軸別サマリ

軸のスコアは配下の項目の最小値です（括弧内は中央値）。

| 軸 | スコア | 項目 |
| --- | --- | --- |
| AI リテラシー・コンピテンシー | 2 | A |
| ワークフロー・SDLC 統合 | 1（2） | B, C, D, E, F, G, H |
| ツーリング統合 | 2 | I |
| 信頼・安全・ガバナンス | 2（2.5） | J, K |
| AI 協働 | 0（1） | L, M |
| 事業インパクト・革新 | 0（2） | N, O, P |

## 項目別

| 項目 | スコア | 主な証拠 | 次のレベルへのギャップ |
| --- | --- | --- | --- |
| A. エージェント運用知識の蓄積と継承 | 2 | `AGENTS.md` と `.github/copilot-instructions.md` がある | ルールに識別子が無く、変更理由の履歴も無い（`a.rule_history_doc_present == false`） |
| B. 要件定義 | 2 | Issue / PR テンプレートあり。`agent-ready` ラベルで着手可能な Issue を示している | 要件の品質を機械的に検査する仕組みが無い |
| C. システム設計・アーキテクチャ | 2 | ADR 12 件、番号の重複なし | 依存方向の静的検査が無い（`c.arch_lint_configured == false`） |
| D. コーディング・開発 | 3 | PR 経由 96%、AI 関与率 0.41、pre-commit で整形・lint を強制 | リポジトリ固有の文脈（索引・知識ベース）を AI に渡す仕組みが無い |
| E. テスト・QA | 3 | テスト 214 ファイル、CI でカバレッジ下限 80% を強制（成功実行あり） | 不安定なテストやカバレッジの欠落を AI が検出していない |
| F. デプロイ・リリース | 2 | デプロイ 58 回成功 | デプロイ後の検証が 0 ステップ、ロールバック手順の文書が無い |
| G. 監視・インシデント対応 | 2 | Sentry を設定。incident ラベルの Issue 3 件 | AI によるログの要約や対応手順の提示が無い |
| H. データ管理 | 1 | migration ラベル 6 件。AI でマイグレーションを書いた PR がある | データの取り込み・変換の手順が定義されていない |
| I. 開発環境・パイプラインへの AI 組み込み | 2 | Copilot と Claude Code の設定をリポジトリで共有 | ローカルのガードレール（`repo: local` のフック）が 0 |
| J. AI 利用ポリシーと機械的強制 | 3 | `AGENTS.md` に AI 利用方針。Dependabot と CodeQL が定期的に成功 | AI が関わった判断の妥当性を検証する仕組みが無い |
| K. 透明性・監査証跡 | 2 | AI の共著者を明記したコミット 326 件（全 795 件中） | プロンプト・検証内容が変更ごとに記録されていない |
| L. 人間–AI・AI–AI の協働プロトコル | 2 | マージされた PR の 90% にレビューあり | 役割分担と、複数のエージェントが同時に作業するときの取り決めが無い |
| M. 合成ユーザーリサーチ | 0 | 該当する Issue・ラベルが 0 件 | AI でユーザー視点を試した記録が 1 件あれば 1 |
| N. 継続的改善のフィードバックループ | 0 | ふりかえりの文書・PR が 0 件（GitHub の外で実施、後述） | ふりかえりの結果を GitHub に残せば 1〜2 |
| O. 価値計測 | 2 | CHANGELOG に「CI 時間 12 分 → 7 分」など定量的な記載 5 件 | リードタイム等を継続的に追跡していない |
| P. ビジョンと適応 | 2 | `roadmap` ラベル 8 件、集計期間の ADR 更新 3 件 | 方向性を計測に基づいて見直した記録が無い |

## 推奨アクション

優先順は「最小値を決めている項目 → 次に低い項目 → 1 手で昇格できる項目」です。それぞれを Issue にするときの受け入れ基準は、証拠キーで書きます。

1. **N：ふりかえりの結果を GitHub に残す**（0 → 2 見込み）
   毎スプリントのふりかえりの要点と Try を、`docs/retrospectives/` か Issue に残す。
   受け入れ基準：`n.retro_docs_count >= 3`
2. **M：AI ペルソナでユーザー視点を試す**（0 → 1 見込み）
   主要な画面について AI ペルソナで操作を試し、見つかった点を `user-research` ラベルの Issue にする。
   受け入れ基準：`m.user_research_issues_count >= 1`
3. **F：デプロイ後の検証を自動化する**（2 → 3 見込み）
   デプロイ用ワークフローの最後にヘルスチェックとスモークテストを加え、ロールバック手順を `docs/rollback.md` に書く。
   受け入れ基準：`f.smoke_steps >= 1 かつ f.rollback_doc_present == true かつ f.deploy_runs.<workflow>.success > 0`
4. **H：データ変更の手順を定義する**（1 → 2 見込み）
   マイグレーションの作り方とレビュー手順を文書化する。

## 再評価

- 次回：2026-12-24（四半期ごと）
- 推奨アクション 1〜3 は月次で進み具合を見る
- 次回も判定基準シート 0.1.x で採点する（patch だけの違いなら比較できる）

## 評価の限界

- **GitHub の外で回っているプロセスは拾えていません。** チームによれば、ふりかえりはオンラインホワイトボードで毎スプリント行い、ユーザーインタビューも四半期に 1 回実施しています。これらは GitHub に記録が無いので、N と M は 0 と採点しました。実態としてはもっと高い可能性があります。
- 監視ダッシュボード（Sentry）の中身は確認していません。G は設定ファイルと Issue だけから判定しました。
- AI 関与率は下限値です。トレーラーを付けずに AI を使ったコミットは数えていません。
- このレポートは確定した評価ではなく、チームで話し合うためのたたき台です。「この項目は実際にはこう回している」という情報が出たら、親 Issue にコメントとして残し、次回の再評価に使ってください。

---

## 付録：証拠 JSON（抜粋）

```json
{
  "header": {
    "repository": "example-org/todo-api",
    "head_sha": "3f9c2a1…",
    "assessed_at": "2026-09-24",
    "criteria_version": "0.1.1",
    "skill_version": "0.1.1",
    "window": {"start": "2026-06-26", "end": "2026-09-24", "days": 90},
    "authors_top5": [
      {"author": "author-1", "count": 412},
      {"author": "author-2", "count": 287},
      {"author": "author-3", "count": 96}
    ],
    "single_author": false,
    "authors_anonymized": true
  },
  "evidence": {
    "a.agent_instruction_files": {"value": ["AGENTS.md", ".github/copilot-instructions.md"]},
    "a.rule_history_doc_present": {"value": false},
    "c.adr_count": {"value": 12},
    "c.adr_duplicates": {"value": []},
    "c.arch_lint_configured": {"value": false},
    "d.commits_window": {"value": 380},
    "d.pr_commit_ratio_window": {"value": 0.96},
    "e.test_files_count": {"value": 214},
    "e.coverage_gate_configured": {"value": true},
    "f.smoke_steps": {"value": 0},
    "f.rollback_doc_present": {"value": false},
    "f.deploy_runs": {"value": {"deploy.yml": {"success": 58, "failure": 2}}, "limit": 500},
    "d.commit_count_total": {"value": 795},
    "k.coauthored_count": {"value": 326},
    "k.coauthored_ratio_lower_bound": {"value": 0.41},
    "l.pr_review_stats_window": {"value": {"count": 212, "with_review": 190, "with_comments": 131, "avg_additions": 164}, "limit": 500},
    "m.user_research_issues_count": {"value": 0, "limit": 500},
    "n.retro_docs_count": {"value": 0},
    "n.retro_prs_window_count": {"value": 0, "limit": 500}
  }
}
```

実際の出力では、44 個すべてのキーに `command` と `collected_at` も付きます。各キーの意味は [`references/evidence-keys.md`](../skills/assessing-ai-sdlc-maturity/references/evidence-keys.md) を参照してください。
