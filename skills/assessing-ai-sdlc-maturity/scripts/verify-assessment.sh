#!/usr/bin/env bash
# =============================================================================
# AI-SDLC 成熟度アセスメントのスコア集計・検算・証拠 JSON 検査スクリプト
# https://github.com/kemsakurai/ai-sdlc-maturity-model-skills
#
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 kemsakurai
#
# 使い方:
#   verify-assessment.sh [--scores <scores.json> | --scores-json '<json>'] [--evidence <evidence.json>]
#
#   --scores / --scores-json : A〜P の 16 項目のスコア（-1〜5 の整数または "N/A"）
#     オブジェクト形式 {"A":3,"B":2,...,"P":3} または 16 要素の配列形式 [3,2,3,...,3] を受け付ける。
#   --evidence : collect-evidence.sh が出力した証拠 JSON ファイル。
#     未取得キー（value == null）、取得上限到達（value >= limit）、件数の矛盾を検出する。
#
# 必要なコマンド: bash, jq, awk
# =============================================================================
set -u

SCORES_FILE=""
SCORES_JSON=""
EVIDENCE_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scores)
      SCORES_FILE="${2:-}"
      shift 2
      ;;
    --scores-json)
      SCORES_JSON="${2:-}"
      shift 2
      ;;
    --evidence)
      EVIDENCE_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "エラー: 不明な引数です: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$SCORES_FILE" ] && [ -z "$SCORES_JSON" ] && [ -z "$EVIDENCE_FILE" ]; then
  echo "エラー: --scores / --scores-json / --evidence のいずれかを指定してください" >&2
  exit 1
fi

if [ -n "$SCORES_FILE" ] && [ -n "$SCORES_JSON" ]; then
  echo "エラー: --scores と --scores-json は同時に指定できません" >&2
  exit 1
fi

if [ -n "$SCORES_FILE" ]; then
  [ -f "$SCORES_FILE" ] || { echo "エラー: スコアファイルが見つかりません: $SCORES_FILE" >&2; exit 1; }
  SCORES_JSON="$(cat "$SCORES_FILE")"
fi

if [ -n "$EVIDENCE_FILE" ] && [ ! -f "$EVIDENCE_FILE" ]; then
  echo "エラー: 証拠 JSON ファイルが見つかりません: $EVIDENCE_FILE" >&2
  exit 1
fi

SCORES_RESULT="null"
if [ -n "$SCORES_JSON" ]; then
  if ! printf '%s' "$SCORES_JSON" | jq -e . >/dev/null 2>&1; then
    echo "エラー: スコアの入力が正しい JSON ではありません" >&2
    exit 1
  fi

  # 配列（16要素）またはオブジェクト（A..P）を正規化して検証・集計する
  if ! SCORES_RESULT="$(printf '%s' "$SCORES_JSON" | jq -c '
    def keys16: ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P"];
    def is_valid_score:
      (. == "N/A") or (type == "number" and (. == floor) and . >= -1 and . <= 5);
    def median_of($arr):
      ($arr | sort) as $s | ($s | length) as $n |
      if $n == 0 then "N/A"
      elif ($n % 2) == 1 then $s[($n - 1) / 2]
      else (($s[($n / 2) - 1] + $s[$n / 2]) / 2)
      end;
    def round2: ((. * 100) | round) / 100;
    def fmt2:
      if . == null then null
      else
        (round2 | tostring) as $s |
        if ($s | contains(".")) then
          ($s | split(".")) as $p |
          if ($p[1] | length) == 1 then "\($p[0]).\($p[1])0" else $s end
        else "\($s).00"
        end
      end;

    (if type == "array" then
      if length != 16 then error("スコア配列は 16 要素である必要があります")
      else [keys16, .] | transpose | map({(.[0]): .[1]}) | add
      end
    elif type == "object" then .
    else error("スコアはオブジェクトまたは 16 要素の配列である必要があります")
    end) as $items |

    (keys16 | map(. as $k | select(($items | has($k)) | not))) as $missing |
    (if ($missing | length) > 0 then error("不足している項目があります: \($missing | join(", "))") else . end) |

    (keys16 | map(. as $k | select(($items[$k] | is_valid_score) | not))) as $invalid |
    (if ($invalid | length) > 0 then error("不正なスコア値があります（-1〜5 の整数または \"N/A\"）: \($invalid | join(", "))") else . end) |

    (keys16 | map(. as $k | select($items[$k] == "N/A"))) as $na_items |
    (keys16 | map(. as $k | select($items[$k] != "N/A"))) as $valid_keys |
    ($valid_keys | map($items[.])) as $vals |
    (if ($vals | length) == 0 then error("N/A 以外の有効な項目が 0 件です") else . end) |

    ($vals | min) as $min_val |
    ($valid_keys | map(select($items[.] == $min_val))) as $min_items |
    (($vals | add) / ($vals | length)) as $mean_raw |
    (median_of($vals)) as $med_val |

    ([
      {name: "AI リテラシー・コンピテンシー", items: ["A"]},
      {name: "ワークフロー・SDLC 統合", items: ["B","C","D","E","F","G","H"]},
      {name: "ツーリング統合", items: ["I"]},
      {name: "信頼・安全・ガバナンス", items: ["J","K"]},
      {name: "AI 協働", items: ["L","M"]},
      {name: "事業インパクト・革新", items: ["N","O","P"]}
    ] | map(
      .items as $ak |
      ($ak | map(. as $k | select($items[$k] == "N/A"))) as $ana |
      ($ak | map(. as $k | select($items[$k] != "N/A") | $items[$k])) as $av |
      {
        name: .name,
        items: $ak,
        na_items: $ana,
        min: (if ($av | length) > 0 then ($av | min) else "N/A" end),
        median: median_of($av)
      }
    )) as $axes |

    {
      valid: true,
      items: (keys16 | map({(.): $items[.]}) | add),
      na_items: $na_items,
      overall: {
        count: ($vals | length),
        median: $med_val,
        mean: ($mean_raw | round2),
        mean_formatted: ($mean_raw | fmt2),
        min: $min_val,
        min_items: $min_items
      },
      axes: $axes
    }
  ')"; then
    exit 1
  fi
fi

EVIDENCE_CHECKS="null"
if [ -n "$EVIDENCE_FILE" ]; then
  if ! jq -e '.evidence | type == "object"' "$EVIDENCE_FILE" >/dev/null 2>&1; then
    echo "エラー: 証拠 JSON に .evidence オブジェクトがありません: $EVIDENCE_FILE" >&2
    exit 1
  fi

  EVIDENCE_CHECKS="$(jq -c '
    .evidence as $ev |
    (.header.collection_errors // []) as $hdr_errors |

    # 1. 未取得キー（value == null）: 0 として扱わない対象
    ([
      $ev | to_entries[] | select(.value.value == null) |
      .key as $k |
      {
        key: $k,
        error: (.value.error // null),
        note: (.value.note // null),
        in_collection_errors: ($hdr_errors | index($k) != null)
      }
    ] | sort_by(.key)) as $uncollected |

    # 2. 取得上限到達の検出（limit != null かつ value が limit に達している、または配列/deploy_runs が limit に達している）
    ([
      $ev | to_entries[] |
      select(.value.limit != null and .value.value != null) |
      .key as $k | .value.limit as $lim | .value.value as $v |
      if ($v | type) == "number" and ($v >= $lim) then
        [{key: $k, observed: $v, limit: $lim, reason: "value reached limit"}]
      elif ($v | type) == "array" and (($v | length) >= $lim) then
        [{key: $k, observed: ($v | length), limit: $lim, reason: "array length reached limit"}]
      elif $k == "f.deploy_runs" and (($v | type) == "object") then
        [$v | to_entries[] |
          (.value | to_entries | map(.value) | add // 0) as $wf_total |
          select($wf_total >= $lim) |
          {key: $k, workflow: .key, observed: $wf_total, limit: $lim, reason: "workflow run count reached limit"}
        ]
      elif ($k == "l.pr_review_stats_window" or $k == "l.ai_pr_stats_window") and (($v | type) == "object") and (($v.count // 0) >= $lim) then
        [{key: $k, observed: $v.count, limit: $lim, reason: "PR count reached limit"}]
      else []
      end
    ] | add // [] | sort_by(.key)) as $limit_reached |

    # 3. 矛盾件数・整合性異常の検出
    ([
      (if ($ev["c.adr_count"].value | type) == "number" and ($ev["p.adr_recent_count_window"].value | type) == "number"
          and ($ev["c.adr_count"].value < $ev["p.adr_recent_count_window"].value) then
        {type: "count_mismatch", keys: ["c.adr_count", "p.adr_recent_count_window"],
         detail: "c.adr_count (\($ev["c.adr_count"].value)) < p.adr_recent_count_window (\($ev["p.adr_recent_count_window"].value)): 削除・移動された ADR 履歴を含む可能性"}
      else empty end),
      (if ($ev["d.commit_count_total"].value | type) == "number" and ($ev["d.commits_window"].value | type) == "number"
          and ($ev["d.commit_count_total"].value < $ev["d.commits_window"].value) then
        {type: "count_mismatch", keys: ["d.commit_count_total", "d.commits_window"],
         detail: "d.commit_count_total (\($ev["d.commit_count_total"].value)) < d.commits_window (\($ev["d.commits_window"].value))"}
      else empty end),
      (if ($ev["k.coauthored_count"].value | type) == "number" and ($ev["d.commit_count_total"].value | type) == "number"
          and ($ev["k.coauthored_count"].value > $ev["d.commit_count_total"].value) then
        {type: "count_mismatch", keys: ["k.coauthored_count", "d.commit_count_total"],
         detail: "k.coauthored_count (\($ev["k.coauthored_count"].value)) > d.commit_count_total (\($ev["d.commit_count_total"].value))"}
      else empty end),
      (if ($ev["l.pr_review_stats_window"].value | type) == "object" and ($ev["l.ai_pr_stats_window"].value | type) == "object"
          and ($ev["l.pr_review_stats_window"].value.count != $ev["l.ai_pr_stats_window"].value.count) then
        {type: "count_mismatch", keys: ["l.pr_review_stats_window", "l.ai_pr_stats_window"],
         detail: "PR count differs between l.pr_review_stats_window (\($ev["l.pr_review_stats_window"].value.count)) and l.ai_pr_stats_window (\($ev["l.ai_pr_stats_window"].value.count))"}
      else empty end),
      (if ($ev["l.ai_pr_stats_window"].value | type) == "object"
          and (($ev["l.ai_pr_stats_window"].value.human_approved_after_ai_review // 0) > ($ev["l.ai_pr_stats_window"].value.ai_reviewed // 0)) then
        {type: "count_mismatch", keys: ["l.ai_pr_stats_window"],
         detail: "human_approved_after_ai_review (\($ev["l.ai_pr_stats_window"].value.human_approved_after_ai_review)) > ai_reviewed (\($ev["l.ai_pr_stats_window"].value.ai_reviewed))"}
      else empty end)
    ]) as $anomalies |

    {
      uncollected_keys: $uncollected,
      limit_reached: $limit_reached,
      anomalies: $anomalies
    }
  ' "$EVIDENCE_FILE")"
fi

jq -n --argjson scores "$SCORES_RESULT" --argjson evidence "$EVIDENCE_CHECKS" \
  '{scores: $scores, evidence_checks: $evidence}'
