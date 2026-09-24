#!/usr/bin/env bash
# リポジトリ内のファイル間の整合性を検査する。
# - 版番号: plugin.json / テンプレート / criteria.md / evidence-keys.md / CHANGELOG.md の先頭の版がそろっている
# - 証拠キー: テンプレートが emit するキー、evidence-keys.md の表、criteria.md の「参照する証拠キー」が一致する
# - プラグイン定義: JSON として正しく、参照するスキルのディレクトリに SKILL.md がある
#
# 使い方: bash tests/consistency_test.sh
# 必要なコマンド: bash, jq, grep, sed
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/skills/assessing-ai-sdlc-maturity"
TPL="$SKILL_DIR/templates/collect-evidence.template.sh"

FAILED=0
pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILED=1; }

# --- プラグイン定義 -----------------------------------------------------------
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if jq -e . "$ROOT/$f" >/dev/null 2>&1; then pass "$f は正しい JSON"; else fail "$f は正しい JSON"; fi
done
while IFS= read -r p; do
  if [ -f "$ROOT/$p/SKILL.md" ]; then pass "plugin.json の skills: $p に SKILL.md がある"; else fail "plugin.json の skills: $p に SKILL.md がある"; fi
done < <(jq -r '.skills[]' "$ROOT/.claude-plugin/plugin.json")

# --- 版番号 -------------------------------------------------------------------
V_PLUGIN="$(jq -r .version "$ROOT/.claude-plugin/plugin.json")"
V_SKILL="$(sed -nE 's/^SKILL_VERSION="([^"]+)"/\1/p' "$TPL")"
V_CRIT_TPL="$(sed -nE 's/^CRITERIA_VERSION="([^"]+)"/\1/p' "$TPL")"
V_TPL_HEADER="$(sed -nE 's/.*criteria\.md ([0-9]+\.[0-9]+\.[0-9]+) 準拠.*/\1/p' "$TPL")"
V_CRITERIA="$(sed -nE '1s/^# 判定基準シート ([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' "$SKILL_DIR/criteria.md")"
V_KEYS_DOC="$(sed -nE 's/.*"skill_version": "([^"]+)".*/\1/p' "$SKILL_DIR/references/evidence-keys.md")"
V_CHANGELOG="$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' "$ROOT/CHANGELOG.md" | head -1)"

echo "     plugin.json=$V_PLUGIN SKILL_VERSION=$V_SKILL CRITERIA_VERSION=$V_CRIT_TPL template-header=$V_TPL_HEADER criteria.md=$V_CRITERIA evidence-keys.md=$V_KEYS_DOC CHANGELOG=$V_CHANGELOG"
ALL_SAME=1
for v in "$V_SKILL" "$V_CRIT_TPL" "$V_TPL_HEADER" "$V_CRITERIA" "$V_KEYS_DOC" "$V_CHANGELOG"; do
  [ "$v" = "$V_PLUGIN" ] || ALL_SAME=0
done
if [ -n "$V_PLUGIN" ] && [ "$ALL_SAME" = "1" ]; then pass "版番号がすべてのファイルでそろっている"; else fail "版番号がすべてのファイルでそろっている"; fi

# --- 証拠キー -----------------------------------------------------------------
KEYS_TPL="$(grep -oE 'emit "[a-p]\.[a-z0-9_]+"' "$TPL" | sed -E 's/emit "(.*)"/\1/' | sort -u)"
KEYS_DOC="$(grep -oE '^\| `[a-p]\.[a-z0-9_]+`' "$SKILL_DIR/references/evidence-keys.md" | sed -E 's/^\| `(.*)`/\1/' | sort -u)"
KEYS_CRIT="$(grep -E '^参照する証拠キー' "$SKILL_DIR/criteria.md" | grep -oE '`[a-p]\.[a-z0-9_]+`' | tr -d '`' | sort -u)"

N_TPL="$(printf '%s\n' "$KEYS_TPL" | grep -c .)"
echo "     template=$N_TPL evidence-keys.md=$(printf '%s\n' "$KEYS_DOC" | grep -c .) criteria.md=$(printf '%s\n' "$KEYS_CRIT" | grep -c .)"
if [ "$KEYS_TPL" = "$KEYS_DOC" ]; then pass "テンプレートと evidence-keys.md のキーが一致"; else fail "テンプレートと evidence-keys.md のキーが一致"; diff <(printf '%s\n' "$KEYS_TPL") <(printf '%s\n' "$KEYS_DOC") | sed 's/^/     /'; fi
if [ "$KEYS_TPL" = "$KEYS_CRIT" ]; then pass "テンプレートと criteria.md のキーが一致"; else fail "テンプレートと criteria.md のキーが一致"; diff <(printf '%s\n' "$KEYS_TPL") <(printf '%s\n' "$KEYS_CRIT") | sed 's/^/     /'; fi

if [ "$FAILED" -ne 0 ]; then echo "テストに失敗しました"; exit 1; fi
echo "すべてのテストに合格しました"
