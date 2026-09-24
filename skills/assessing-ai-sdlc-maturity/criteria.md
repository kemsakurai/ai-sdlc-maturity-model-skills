# 判定基準シート 0.0.2

正本。項目の追加や文言の変更をしたら、版を上げてリポジトリの CHANGELOG（https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/blob/main/CHANGELOG.md）に理由を残す。再評価は前回と同じ版で行う（版が違うと採点を比較できない）。

## 出典とライセンス

- [DEFRA「AI-SDLC Maturity Assessment」](https://github.com/DEFRA/ai-sdlc-maturity-assessment)：7 段階の尺度の区分、次元の名前、階層準拠の採点法を参照した。項目別の判定基準は、各次元ページにある Sample assessment questions の観点を参考にし、人間と AI エージェントで運用するリポジトリ向けに文言を独自に書き起こした。DEFRA の文章は収録していないので、原文は上記リンクを参照すること。
- [Gigacore「AI-Maturity-Model」](https://github.com/Gigacore/AI-Maturity-Model)（[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)）：6 つの軸とレベル名（Exploratory〜Transformational）を、日本語化して項目に対応づけるという改変を加えて利用した。
- 上記以外（読み替え・項目の構成・判定基準の文言・証拠キー・採点注記）は MIT License, Copyright (c) 2026 kemsakurai（https://github.com/kemsakurai/ai-sdlc-maturity-model-skills）。このファイルを複製・再配布するときは、この節を残すこと。
- このシートは DEFRA とも Gigacore とも無関係の非公式なもの。

## 尺度（7 段階）

| Lv | ラベル | 読み替え（人間 + AI エージェントで運用するリポジトリ） |
| --- | --- | --- |
| −1 | 抵抗 | AI 利用や記録を意図的に禁じている |
| 0 | 場当たり | やり方が個人の記憶とその場の判断に依存 |
| 1 | 探索 | 試した・評価した形跡はあるが運用に組み込まれていない |
| 2 | 構造化 | 手順・設定として明文化され、意図して使われている |
| 3 | 確立 | ルール ID・スキル・ゲートとして一貫適用され、逸脱が検知される |
| 4 | 統合 | 仕組み自体が自己改善し、リポジトリ固有の文脈を AI が扱う |
| 5 | 変革 | 外部標準に影響を与える、または自律的に適応する |

採点: −1/0 は「状態が該当するか」、1〜5 は「基準を満たすか」。1 から連続して満たした最高レベルがスコア。−1 に該当すれば −1、1 未達なら 0（0 の行に該当していても 1 を満たせば 1 以上）。3 以上は運用の証拠（実行実績・件数・日付）が必要で、仕組みの存在だけなら 2。Gigacore の Level 1〜5（Exploratory / Applied / Standardized / Strategic / Transformational）はこの尺度の 1〜5 に対応する。

## 軸と項目

| Gigacore 軸 | 項目 |
| --- | --- |
| AI リテラシー・コンピテンシー | A |
| ワークフロー・SDLC 統合 | B, C, D, E, F, G, H |
| ツーリング統合 | I |
| 信頼・安全・ガバナンス | J, K |
| AI 協働 | L, M |
| 事業インパクト・革新 | N, O, P |

適用不能（単独メンテナ等）: DEFRA「Cross-Functional Collaboration」、Gigacore「Role-Based Progression」は N/A。理由を明記する。

N/A 注記（単独メンテナ、著者が 1 名のリポジトリ）: A のレベル 4「他者のオンボーディング」は構造的に充足不能なので **A の上限を 3 とし、4 の行を N/A** と書く。L のレベル 4「人間と AI の共同監督」は、人間のレビュー証跡（PR レビューまたは PR 本文の AI レビュー記録）があれば充足可能なので N/A にしない。

## 項目別の判定基準

各項目: 出典 → −1 / 0 / 1 / 2 / 3 / 4 / 5 の順。「参照する証拠キー」はプロジェクト固有の `collect-evidence.sh` が出力する JSON の `evidence.<key>` に対応する（値そのものではなくレベル判定のヒント。3 以上の運用証拠の判定は引き続き人/LLM の判断で行う）。

### A. エージェント運用知識の蓄積と継承（DEFRA: Skills Development / Gigacore: AI Literacy）
参照する証拠キー: `a.agent_instruction_files`, `a.skills_count`, `a.rule_history_doc_present`
- −1 AI 利用に関する知見の共有を拒む・禁じている
- 0 使い方は個人の記憶頼みで文書化されていない
- 1 使い方のメモや試行の記録が散発的に存在する
- 2 エージェント向けの指示書（AGENTS.md / CLAUDE.md 等）が意図的に整備されている
- 3 指示書が ID 付きルール・スキル・根拠履歴として体系化され、複数エージェント/ツールで共有されている
- 4 知見が他者のオンボーディングや育成に使われ、再利用されている
- 5 知見が外部標準や業界の実践に影響を与えている

### B. 要件定義（Issue / PBI の品質）（DEFRA: Requirements Engineering）
参照する証拠キー: `b.issue_template_exists`, `b.pr_template_exists`, `b.issues_open_count`, `b.issues_closed_count`
- −1 要件作成への AI 利用を禁止している
- 0 Issue は AI で書かれることもあるが基準・型がない
- 1 Issue テンプレートやラベル体系で AI 向け要件の型を試行している
- 2 エージェントが着手できる粒度に要件を整える運用（ready-for-agent 等）が定義されている
- 3 要件の品質を AI/ルールで機械的に検査する仕組みと設計ゲートが運用されている
- 4 検査結果が計画・優先順位付けに組み込まれ、要件の欠落を AI が提案する
- 5 AI が継続的ディスカバリーで要件の発生源まで扱う

### C. システム設計・アーキテクチャ（DEFRA: System Design + Software Architecture）
参照する証拠キー: `c.adr_count`, `c.adr_duplicates`, `c.arch_lint_configured`, `c.arch_lint_enforced`
- −1 設計判断の記録を拒む
- 0 設計はコード内に暗黙で、記録がない
- 1 設計メモが散発的に存在する
- 2 ADR とドメインモデルが意図的に維持されている
- 3 設計変更に AI との設計相談ゲートがあり、層構造・依存方向が静的検査で強制される
- 4 AI がアーキテクチャ逸脱を継続的に検知し、設計判断の影響範囲を提示する
- 5 AI が設計の代替案を継続的に生成・評価し、設計が文脈に応じて適応する

### D. コーディング・開発（DEFRA: Coding & Development / Gigacore: Workflow）
参照する証拠キー: `d.commit_count_total`, `d.commits_window`, `d.commits_by_month`, `d.pr_commit_ratio_window`
- −1 AI コーディング支援を禁止している
- 0 個人が標準なしに AI 支援を使う
- 1 特定の AI 支援ツールを評価した
- 2 AI 支援が PR 作成〜マージのワークフローに統合されている
- 3 定型コード生成・リファクタ・コミットメッセージ等を日常的に AI が担い、規約が強制される
- 4 AI がリポジトリ固有の文脈（スキル・code-map・知識ベース）から文脈付きの案内を提供する
- 5 ドメイン特化モデルを内部でファインチューニングしている

### E. テスト・QA（DEFRA: Testing & Quality Assurance）
参照する証拠キー: `e.test_files_count`, `e.test_cases_count`, `e.coverage_gate_configured`
- −1 テストへの AI 利用に抵抗がある
- 0 個人が AI でテストを書くが標準がない
- 1 AI テスト支援ツールを評価した
- 2 AI によるテストデータ生成・基本的な自動化がある
- 3 AI がテストケースを生成・優先順位付けし、カバレッジゲートで担保される
- 4 AI がカバレッジの欠落・重複・不安定テストを検出する（AI ペルソナ探索テスト等）
- 5 リリース前に AI で回帰リスク分析を行う

### F. デプロイ・リリース（DEFRA: Deployment & Release Engineering）
参照する証拠キー: `f.smoke_steps`, `f.rollback_doc_present`, `f.deploy_runs`
- −1 デプロイ自動化に抵抗がある
- 0 手動デプロイである
- 1 パイプラインを AI で整備・評価した
- 2 CI/CD がパスフィルタ・キャッシュ等で最適化され、AI エージェントが PR〜マージを運用する
- 3 デプロイ後の検証（スモーク・整合性）が自動化され、失敗時の戻し手順が定義されている
- 4 AI がリリースリスク・変更影響を提示する
- 5 AI がリリース判断を最適化する

### G. 監視・インシデント対応（DEFRA: Monitoring & Incident Response）
参照する証拠キー: `g.monitoring_configured`, `g.incident_labeled_issues_count`
- −1 監視の導入に抵抗がある
- 0 本番の監視・アラートが無く、障害は事後に気づく
- 1 AI による監視強化の余地を洗い出した
- 2 基本的な死活・エラー監視があり、障害記録が Issue 等に残る
- 3 AI がログ/イベントを要約し、対応手順を提示する
- 4 AI が異常を予測・相関分析する
- 5 自律的な復旧を行う

### H. データ管理（DEFRA: Data Management）
参照する証拠キー: `h.data_management_labels_count`, `h.data_integrity_gate_configured`
- −1 データ取り込みの標準化に抵抗がある
- 0 データ取り込みが場当たりである
- 1 AI での取り込み・変換を試行した
- 2 AI パイプラインが定義され再現可能である
- 3 整合性ゲート・ライセンス分類・派生物ドリフト検査が機械化されている
- 4 AI 出力の品質を決定論的ゲートで監査し、出自（provenance）を追跡する
- 5 AI がデータ品質を自律的に改善する

### I. 開発環境・パイプラインへの AI 組み込み（Gigacore: Tooling Integration）
参照する証拠キー: `i.tool_integration_files`, `i.local_guardrail_hooks_count`
- −1 ツール導入を禁止している
- 0 外部 AI ツールを単独で利用する
- 1 承認ツールをプラグイン的に利用する
- 2 IDE / CLI / CI に AI ツールが統合され設定が共有される
- 3 ツール設定が標準化され、ガードレール（フック・pre-commit）が機械的に強制される
- 4 独自の AI プラットフォーム / MCP / オーケストレーションを構築し、自動化パイプラインを持つ
- 5 適応的なプラットフォームが規模化された開発を駆動する

### J. AI 利用ポリシーと機械的強制（DEFRA: Governance & Compliance / Gigacore: Trust, Safety & Governance）
参照する証拠キー: `j.governance_docs_present`, `j.dependabot_or_renovate_present`, `j.codeql_security_workflow_present`
- −1 ガバナンス整備を意図的に避けている
- 0 反応的・場当たりに扱う
- 1 AI 利用のリスク・要件を特定した
- 2 基本ガイドラインが文書化されている
- 3 ポリシーが定義され、自動/ピア強制の準拠チェックがある
- 4 全ワークフローにガバナンスが埋め込まれ、AI 支援判断の妥当性検証が能動的に行われる
- 5 適応的ガバナンスで、外部標準に貢献する

### K. 透明性・監査証跡（DEFRA: Governance metric「AI decision auditability」）
参照する証拠キー: `k.coauthored_count`, `k.coauthored_by_model`, `k.coauthored_ratio_lower_bound`
- −1 記録を拒む
- 0 AI の作業は記録されない
- 1 一部セッションのログがある
- 2 コミットに AI 関与を明示している
- 3 変更ごとにプロンプト・変更・検証・影響が記録される
- 4 セッション記録が構造化され、横断分析に使われる
- 5 監査証跡が外部監査に耐える形式で公開される

### L. 人間–AI・AI–AI の協働プロトコル（DEFRA: Collaboration & Communication / Gigacore: AI-Augmented Collaboration）
参照する証拠キー: `l.pr_review_stats_window`, `l.pr_authors_window`
- −1 協働の取り決めを拒む
- 0 個人が AI を使い、調整がない
- 1 AI 利用を意図的に宣言する
- 2 基本的なレビュー工程に AI 出力を通す
- 3 役割分担・レビュー手順が定義され、複数エージェントの衝突回避プロトコルがある
- 4 人間と AI の共同監督（shared oversight）モデルが運用され、判断の所在が明確である
- 5 協働様式が組織標準として再定義されている

### M. 合成ユーザーリサーチ（DEFRA: User Research）
参照する証拠キー: `m.user_research_issues_count`, `m.user_research_labels_count`
- −1 ユーザー視点の検証を拒む
- 0 ユーザー視点の検証がない
- 1 AI でユーザー視点を試している
- 2 AI ペルソナ等による探索が意図的に運用され、発見が Issue 化される
- 3 合成リサーチの結果を実ユーザーのデータと突き合わせて検証する
- 4 AI が実ユーザーのフィードバックを継続的に統合する
- 5 AI がユーザーニーズを先回りして提示する

### N. 継続的改善のフィードバックループ（DEFRA: Continuous Improvement / Gigacore: Business Impact）
参照する証拠キー: `n.retro_docs_count`, `n.changelog_lines`, `n.retro_prs_window_count`
- −1 AI による改善提案に抵抗がある
- 0 改善は場当たりである
- 1 フィードバックループの候補を特定した
- 2 セッション単位のふりかえりを AI が行う
- 3 ふりかえりが定期的に横断分析され、ルールの統合 / 剪定 / 昇格が PR として出る
- 4 分析結果が機械的ゲートへ変換され、再発が計測される
- 5 AI が継続的ディスカバリーに埋め込まれる

### O. 価値計測（DEFRA: Value Measurement / Gigacore: Business Impact）
参照する証拠キー: `o.value_metric_mentions_count`, `o.changelog_measurement_lines_count`
- −1 計測を拒む
- 0 計測がない
- 1 計測すべき指標を特定した
- 2 個別の改善で効果を計測している（CI 時間等）
- 3 リードタイム / スループット / 品質を継続的に追跡し、AI の寄与を可視化する
- 4 計測が投資判断（ツール・ランナー・モデル選択）に使われる
- 5 AI 活用の価値が外部に示せる形で証明されている

### P. ビジョンと適応（DEFRA: Leadership & Vision + Adaptability & Innovation）
参照する証拠キー: `p.roadmap_label_count`, `p.adr_recent_count_window`
- −1 方向性の明示を拒む
- 0 方向性は暗黙である
- 1 方向性が README 等に書かれている
- 2 ロードマップ / 探索ラベルで探索が構造化されている
- 3 新しいモデル・ツールを迅速に取り込み、判断が ADR に残る
- 4 方向性が計測に基づき定期的に見直される
- 5 方向性が外部コミュニティを牽引する
