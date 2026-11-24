---
name: review-flow
description: Reviews a change — the current branch, a PR, uncommitted work or named files — with `ponytail-review` as the baseline plus up to three lenses matched to the diff, merged into one deduplicated report. Read-only.
disable-model-invocation: true
argument-hint: "branch, PR number or URL, paths, or nothing for the current branch"
---

# Review flow

An **orchestrator** over review skills. [`ponytail`](https://github.com/DietrichGebert/ponytail)'s `ponytail-review` is the **baseline**: the general bug hunt over the whole diff. On top of it go up to three **lenses** — other review skills whose zone this diff actually touches. Each lens runs on its own, then one report comes out.

Every skill named here is the source of truth for what it checks. This file decides only which ones run, on what, and how their findings merge.

Read-only throughout: findings, no edits. Applying a fix is a separate request.

## Preflight

Confirm `ponytail-review` is installed: it is in the agent's skill list, or a `ponytail-review` skill sits in the harness's user or project skill directories. When it is absent, queue its install line for the report and carry on. The baseline seat then goes to another installed skill whose description is a bug hunt over a code change (a harness's built-in `code-review` qualifies); that skill takes no lens seat. With none installed, the lenses run alone.

```bash
npx skills add DietrichGebert/ponytail
```

**Done when:** the baseline is found, substituted, or reported missing with its install line queued.

## 1. Resolve the scope

- An explicit branch, range, path or file list → that.
- A PR or MR number or URL → its diff through the forge's CLI or MCP server when the session has one; otherwise fetch `refs/pull/<n>/head` (GitHub) or `refs/merge-requests/<n>/head` (GitLab) from `origin` and diff it against its target branch. Neither works → say so and stop.
- Nothing explicit → the current branch against its base, plus the working tree, untracked files included:
  ```sh
  git diff <base>...HEAD
  git diff HEAD
  git ls-files --others --exclude-standard
  ```
  Untracked files are read whole. `<base>`: what the user named → the target branch of the open PR/MR, when the session has the forge's CLI or MCP server → `origin/HEAD` → `origin/main` / `origin/master`. None of them exists → say so and stop.
- All empty → say there is nothing to review and stop.

Then look for the **spec** — what the change was supposed to do: the PR body, a linked issue, a ticket id in the branch name or commits that the tracker resolves, a spec file the user named. A ticket id the session cannot resolve counts as no spec, and the report names the id. Not found → the spec lens stays out, and the report says so in one line.

**Done when:** the scope is a concrete diff, and the spec is either in hand or known to be absent.

## 2. Pick the lenses

Gather candidates from two places:

- **Installed review skills.** Scan the agent's skill list and the skill directories from Preflight for skills that review a code change, other than this one and the baseline. Note each one's invocation: a skill with `disable-model-invocation: true` is **closed** — only a typed `/command` starts it.
- **The known lenses** below, each with its zone.

| Lens | Its zone in the diff |
| --- | --- |
| `mattpocock-skills:code-review` (or the pack's `code-review`) | a spec was found — run its **Spec** axis only |
| `code-craft` | new names, signatures, state shapes, new types and classes, inheritance, I/O inside business logic, new files |
| `test-craft` | tests added or changed |
| `reatom-review` | Reatom imports |
| `frontend-mvvm`, `feod-preset` | a module (a folder on the `modules` level) added or moved, a ViewModel (the role that owns screen state and user intent) added, an import between modules |
| `better-interface`, `better-accessibility` | UI files: components, templates, styles, QML |
| `/interface-review` | UI files — closed |
| `security-review` | auth, sessions, secrets, crypto, SQL, input crossing a trust boundary |

A discovered skill missing from the table gets its zone from its own description.

A lens runs only when its zone has a match in this diff. A found spec always takes one seat: with no spec skill installed, a plain subagent checks the change against the spec in that seat. Rank the other matches by the number of changed files in each zone, ties in table order, and open ones fill the remaining seats up to three. The rest:

- matched, closed → **run by hand**, with the command to type;
- matched, over the cap → **also worth running**;
- matched, not installed → **also worth running**, marked not installed;
- installed, no match → **not relevant here**, one line naming them.

**Done when:** every installed candidate and every matched known lens is in exactly one of: running, run by hand, also worth running, not relevant.

## 3. Run

One run per lens plus the baseline, each in its own subagent and in parallel when the harness has subagents, otherwise one after another. Each run gets:

- the absolute path of the repository, passed as the skill's target argument when the skill takes one, and an explicit `cd <repo>` in every command of the run — a forked skill starts in the session's working directory, and git context a skill injects from there is not this diff;
- the diff commands from step 1 and, for the spec lens, the spec;
- its skill, loaded;
- its brief: **defects and rule breaks in this change**, each as `file:line` (a bare `file` when the finding is about the file as a whole), severity (`blocker` / `major` / `minor`), and one line of why. Code-craft and test-craft judge only lines this diff adds. Improvement ideas for code that already worked belong to `refactor-advice` — leave them out.

**Done when:** every running lens has returned findings or an explicit "nothing found".

## 4. Merge the report

The report is for the human: write it in the language the user speaks to you; code, paths and identifiers stay as they are.

1. One line of **assumptions**: the scope, the base, spec found or not, which lenses ran.
2. **Defects** — every finding that is not a rule break, ranked by severity. Two findings on the same `file:line` with the same cause collapse into one, tagged with every lens that raised it; keep the sharper wording and the higher severity.
3. **By lens** — the rule breaks per lens: a broken rule of that lens, a naming or test-shape issue. A lens with nothing left gets no section.
4. **Run by hand**, **Also worth running**, **Not relevant here** — one line each, omitted when empty.
5. Install lines from Preflight, if any.

**Done when:** every finding from every run appears exactly once, under a lens tag, and every candidate from step 2 is accounted for.
