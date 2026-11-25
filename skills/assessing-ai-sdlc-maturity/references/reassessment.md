# 再評価・校正・フレームワーク差分確認

`SKILL.md` の手順 1（初回・3 か月以上経過時）および手順 6（再評価・校正時）で参照する。

## フレームワーク差分確認

初回実行、または前回確認日（ベースライン証拠 JSON の `header.framework_checked_at`）から 3 か月以上空いたときに実行する。

1. 以下の上流ドキュメントを取得し、尺度・採点ルール・軸が `criteria.md` 冒頭の記載と変わっていないか確認する。
   - `curl -sL https://raw.githubusercontent.com/DEFRA/ai-sdlc-maturity-assessment/main/{README.md,introduction/ai-sdlc-maturity-assessment-framework.md,implementation/scoring-implementation.md}`
   - `curl -sL https://raw.githubusercontent.com/Gigacore/AI-Maturity-Model/main/README.md`
2. 変更があれば `criteria.md` の版を上げる（次元ページの Sample assessment questions はシートに無い項目を追加するときだけ取得する）。
3. 確認した日は手順 2 の実行で `--framework-checked-at <YYYY-MM-DD>` に渡す。今回確認しないときは前回の確認日を引き継ぎ、前回も無ければ渡さず `null` のままにして評価の限界に「フレームワークの差分は未確認」と書く。

## 再評価（四半期ごと／優先項目は月次）

引数に `再評価 #<親Issue番号>` または `再評価 <前回の証拠 JSON のパス>`（英語別名：`reassess`）が付いているときに実行する。

1. 前回の証拠 JSON（親 Issue のコメント、またはファイル）を取得し、前回と major・minor が同じ版の `criteria.md` で採点する（patch だけの違いは比較可能）。
2. 前回の証拠 JSON と今回の JSON の diff を取り、値が変わったキーを列挙してから採点の変化を説明する。
3. 外部運用の確認では、前回の回答（ベースライン採点表の「外部運用」列）を示して変化の有無を尋ねる。
4. レポートの採点表には**変化のあった項目だけ**を載せる。
5. `header.skill_version` が前回と違う場合は、収集方法の変更で値が動いたキーがないかをリポジトリの `CHANGELOG.md`（https://github.com/kemsakurai/ai-sdlc-maturity-model-skills/blob/main/CHANGELOG.md）で確認し、採点の変化とは分けて書く。
6. 記録先は前回と同じにする（親 Issue ならコメントで追記、ファイルなら新しい日付のファイル）。

## 校正（同一 HEAD に対する 2 回目以降の採点）

同じ HEAD に対する 2 回目以降の採点は「校正」として扱う。新しいベースラインは作らず、差分のあった項目と新しい根拠数値だけを前回の記録先へ追記する。
