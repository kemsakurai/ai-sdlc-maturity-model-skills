# ai-sdlc-maturity-model-skills

English | [日本語](README.ja.md)

An agent skill that assesses how maturely a team uses AI across its software development lifecycle (AI-SDLC), based on the git history, files, Issues, PRs and GitHub Actions runs of a GitHub repository.

| Skill | Invocation | What it does |
| --- | --- | --- |
| [`assessing-ai-sdlc-maturity`](skills/assessing-ai-sdlc-maturity/SKILL.md) | `/assessing-ai-sdlc-maturity` | Scores a repository against a fixed criteria sheet (16 items × 7 levels) and records the baseline and re-assessments in a parent GitHub Issue |

> **Language.** The skill (`SKILL.md`), its criteria sheet and the generated reports are written in **Japanese**. This README is a translation of [`README.ja.md`](README.ja.md). The skill works on repositories in any language, but the report you get back is in Japanese.

## What it can and cannot do

**What it can do**

- Reads primary evidence from the repository (commits, PR review status, workflow run results, ADRs, tests, labels and so on) read-only, and packs it into a keyed JSON.
- Scores 16 items from −1 to 5 based on that JSON, and reports per-axis scores, the overall median and minimum, the gap to the next level, and recommended actions.
- Turns each recommended action into an Issue with acceptance criteria written in evidence keys (for example `c.adr_duplicates == []`). In quarterly re-assessments it explains what changed by diffing against the previous JSON.

**What it cannot do (please read)**

- Evidence is **only what lives on GitHub**. Procedures agreed verbally, retrospectives run in other tools such as Slack or Notion, and internal monitoring dashboards — any process not managed on GitHub — are invisible to it. Teams that run many such processes will be scored **lower** than reality, so treat the result as **reference information**.
- The output is not a final verdict; it is a **draft for discussion**. We recommend going through it with your team: "this one we actually run like this", "yes, this one really is weak". Record what you learn about processes outside GitHub as a comment on the parent Issue; it helps the next re-assessment.
- After scoring, for the items among monitoring, data management, synthetic user research, continuous improvement, value measurement and vision (G, H, M, N, O, P) where no evidence was found on GitHub, the skill **asks you once, all at once**, whether the process is run outside GitHub. Answers are only recorded in the "external operation" column; **scores do not change**. In environments where it cannot ask (cloud sessions, CI and so on) it does not ask, and notes this under "limits of the assessment".

For what a report looks like, see the [example report](docs/example-report.md), built on a fictional repository (in Japanese). For results of assessing five well-known public OSS repositories (Cline, GitHub CLI, pnpm and others), see the [external repository verification report](docs/external-verification.md).

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) (or any agent that can read `SKILL.md`-format skills)
- `git`, `jq`, `curl`
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated with `gh auth login` using an account that can read the target repository. In cloud environments without `gh` (such as Claude Code on the web), download a binary from the [official releases](https://github.com/cli/cli/releases) and authenticate with the `GH_TOKEN` environment variable. Evidence collection also works without the GraphQL API, using the REST API.
- The target repository must be on GitHub

## Installation

### As a user skill (recommended)

This makes `/assessing-ai-sdlc-maturity` available from every project.

```sh
git clone https://github.com/kemsakurai/ai-sdlc-maturity-model-skills.git ~/ai-sdlc-maturity-model-skills
mkdir -p ~/.claude/skills
ln -s ~/ai-sdlc-maturity-model-skills/skills/assessing-ai-sdlc-maturity ~/.claude/skills/assessing-ai-sdlc-maturity
```

To update, run `git pull` in the cloned directory. You may also copy the `skills/assessing-ai-sdlc-maturity` directory instead of using a symlink. The copyright and license notices are at the end of `SKILL.md` and in the "出典とライセンス" (sources and licenses) section of `criteria.md`; do not remove them when copying.

### As a Claude Code plugin

```text
/plugin marketplace add kemsakurai/ai-sdlc-maturity-model-skills
/plugin install ai-sdlc-maturity@ai-sdlc-maturity
```

When installed as a plugin, the invocation name is `/ai-sdlc-maturity:assessing-ai-sdlc-maturity`.

### Without installing

In cloud sessions where you cannot write to the home directory (`~/.claude/skills`), you can use the skill without installing it. Clone this repository into a working directory, ask the agent to read `skills/assessing-ai-sdlc-maturity/SKILL.md`, and have it assess following those steps. `criteria.md`, `references/` and `templates/` are referenced by relative path from `SKILL.md`, so keep the directory layout as is.

```sh
git clone https://github.com/kemsakurai/ai-sdlc-maturity-model-skills.git /tmp/ai-sdlc-maturity-model-skills
# Example request to the agent:
#   Read /tmp/ai-sdlc-maturity-model-skills/skills/assessing-ai-sdlc-maturity/SKILL.md
#   and assess path/to/repo by those steps, in no-write mode.
```

## Usage

Start Claude Code in the target repository's directory and invoke the skill as below. The model never starts it by itself; it runs only when you call it explicitly.

```text
/assessing-ai-sdlc-maturity                 # first assessment of the current repository
/assessing-ai-sdlc-maturity path/to/repo    # specify a path
/assessing-ai-sdlc-maturity reassess #123   # re-assess against the baseline in parent Issue #123
/assessing-ai-sdlc-maturity reassess ./assessment-2026-09-25.json  # compare with a baseline saved to a file
/assessing-ai-sdlc-maturity no-write        # assess without writing to the repository or to GitHub
```

The keywords have Japanese equivalents: `再評価` for `reassess` and `書き込みなし` for `no-write`. Both forms are accepted.

The first run goes as follows.

1. It inspects the repository's layout (languages, how tests are written, pre-commit, task runner and CI, ADR location, label scheme and so on), and from the bundled template generates an evidence-collection script specific to that repository (default `scripts/ai-sdlc/collect-evidence.sh`). The destination is confirmed at run time. The generated path is recorded in one line in the agent instructions file (`AGENTS.md`, `CLAUDE.md` and so on; the README if there is none).
2. It runs the script to get the evidence JSON. The script is read-only and never touches `.env`. The default window is 90 days.
3. It scores the repository against `criteria.md`.
4. For items among G, H, M, N, O and P where no evidence was found on GitHub, it asks whether the process is run outside GitHub. Answers are recorded in the "external operation" column of the scoring table (`申告あり` = declared, `申告なし` = not declared) and do not change the score. On a re-assessment it shows your previous answers and asks whether anything changed.
5. It outputs the result.
6. It records the result and the JSON in a parent GitHub Issue, and files each recommended action as an Issue. Before writing, it shows the destination and the content and asks for confirmation. If you do not want to record to Issues, it can save the JSON and the report to files (`assessment-<date>.json` / `.md`), and you pass that path in the next re-assessment.

Commit the generated script to the repository. Later runs reuse it, which keeps the yardstick the same across re-assessments. The script header carries an MIT copyright notice; keep it when you commit.

When you cannot, or do not want to, write to the repository, call it with `no-write`. The script is generated temporarily outside the repository, and nothing is appended to the instructions file and no Issue is created. The settings embedded in the script are kept in the evidence JSON under `header.config`, so the same script can be regenerated next time with the same yardstick. When assessing an external repository by cloning it into a temporary directory, a checkout can abort in some environments if the repository uses Git LFS, so we recommend fetching with `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 100 <URL> <temporary directory>`.

What gets assessed is the files git tracks in your local checkout. If your checkout is behind the latest default branch, recently added instructions files and the like will be missing. The skill checks for this drift before running and, if needed, checks out the latest default branch into a temporary worktree and assesses that (your working tree is left untouched).

### Writing to GitHub and personal names

- This skill **creates Issues and posts comments** in the target repository. You need to be logged in with `gh auth login` using an account that can create Issues. Every write is confirmed before it is performed.
- The evidence JSON includes commit author names (`header.authors_top5`) and PR author logins (`l.pr_authors_window`). For public repositories these are replaced with placeholder names such as `author-1` when collected (`--anonymize-authors` of the evidence-collection script). Counts and rankings are kept.
- When using it on a repository someone else maintains, get the maintainers' approval before creating Issues.

## How scoring works

- **Scale**: seven levels — −1 (resistant) / 0 (ad hoc) / 1 (exploring) / 2 (structured) / 3 (established) / 4 (integrated) / 5 (transformative). An item's score is the highest level reached by meeting the criteria consecutively from level 1.
- **Existence and operation are distinguished**: a rule or workflow that merely "exists" caps at level 2. Level 3 and above need evidence of execution (counts of successful runs, dates, logs).
- **The overall score** reports both the median across all items and the minimum (tiered compliance). The item that sets the minimum is the largest operational risk.
- The full criteria are in [`criteria.md`](skills/assessing-ai-sdlc-maturity/criteria.md) (Japanese), and the meaning of each evidence key is in [`references/evidence-keys.md`](skills/assessing-ai-sdlc-maturity/references/evidence-keys.md).

## Layout

```text
.
├── .claude-plugin/            # Claude Code plugin / marketplace definitions
├── .github/workflows/test.yml # CI (shellcheck and running tests/)
├── docs/
│   └── example-report.md      # example output (fictional repository)
├── tests/
│   ├── template_test.sh       # regression tests for the evidence-collection template
│   └── consistency_test.sh    # cross-file consistency checks for versions and evidence keys
├── skills/
│   └── assessing-ai-sdlc-maturity/
│       ├── SKILL.md           # the skill itself (steps)
│       ├── criteria.md        # criteria sheet
│       ├── references/
│       │   └── evidence-keys.md
│       └── templates/
│           ├── collect-evidence.template.sh
│           └── report.template.md   # report template
├── CHANGELOG.md
├── LICENSE                    # MIT License
├── README.md                  # English (this file)
├── README.ja.md               # Japanese
└── THIRD_PARTY_NOTICES.md     # third-party material referenced or adapted, and its licenses
```

## Versioning

This project follows [Semantic Versioning](https://semver.org/). The skill and the criteria sheet share a single version number, and `header.skill_version` and `header.criteria_version` in the evidence JSON always hold the same value.

- **patch** (e.g. 0.1.0 → 0.1.1): the wording of the criteria does not change. Fixes to how evidence is collected, or documentation touch-ups. Scores from versions that differ only in patch are comparable.
- **minor and above** (e.g. 0.1.x → 0.2.0): the wording or items of the criteria change. Scores cannot be compared with earlier ones as is.

See [`CHANGELOG.md`](CHANGELOG.md) (Japanese) for the change history.

## Sources and license

The code and documents in this repository are released under the [MIT License](LICENSE). The third-party materials below, however, remain under their respective owners and licenses. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for details.

- **DEFRA "AI-SDLC Maturity Assessment"** (<https://github.com/DEFRA/ai-sdlc-maturity-assessment>): the seven-level scale, dimension names and the tiered-compliance scoring method are referenced. The per-item criteria take their viewpoints from the "Sample assessment questions" on each dimension page, but the wording is original. DEFRA's text is not reproduced; see the linked source for the original.
- **Gigacore "AI-Maturity-Model"** (<https://github.com/Gigacore/AI-Maturity-Model>, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)): the six axes and level names are used with modifications — translated into Japanese and mapped onto the items.

This skill is unofficial and is not affiliated with DEFRA or Gigacore.
