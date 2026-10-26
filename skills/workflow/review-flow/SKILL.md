---
name: review-flow
description: Review a change — the current branch, a PR, uncommitted work, or named files — by running `ponytail-review` as the baseline plus up to three review lenses matched to the diff (the spec, the project's craft skills, the stack's own review skills, whatever review skills are installed), then merging them into one deduplicated report. Load on "review this", "отревьюй", "code review", "check my PR", "what did I break", and load it instead of calling `ponytail-review` directly — it calls that itself. Read-only. Not for improving working code (refactor-advice), explaining it (change-debrief) or mapping it visually (change-map). Stack-agnostic.
---

# Review flow

An **orchestrator** over review skills. [`ponytail`](https://github.com/DietrichGebert/ponytail)'s `ponytail-review` is the **baseline**: logic, safety, load, untested risk, speed, lines that need not exist. On top of it go up to three **lenses** — other review skills whose zone this diff actually touches. Each lens runs on its own, then one report comes out.

Every skill named here is the source of truth for what it checks. This file decides only which ones run, on what, and how their findings merge.

Read-only throughout: findings, no edits. Applying a fix is a separate request.

## Preflight

Confirm `ponytail-review` is installed: it is in the agent's skill list, or sits under `~/.claude/skills`, `~/.agents/skills`, `~/.claude/plugins`, or the project's `.claude/skills` / `.agents/skills`. When it is absent, put the install lines at the top of the report and carry on — a general bug-hunt review skill, if one is installed, takes the baseline seat; otherwise the lenses run alone.

```bash
npx skills add DietrichGebert/ponytail
```

In Claude Code the plugin is better — its hooks keep ponytail on in every session and in subagents:

```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```

**Done when:** the baseline is found, substituted, or reported missing with its install lines queued.

## 1. Resolve the scope

- An explicit PR, branch, range, path or file list → that.
- Nothing explicit → the current branch against its base, plus the working tree:
  ```sh
  git diff <base>...HEAD
  git diff HEAD
  ```
  with `<base>`: what the user named → `origin/dev` / `origin/develop` if either exists → `origin/HEAD` → `origin/main` / `origin/master`.
- Both empty → say there is nothing to review and stop.

Then look for the **spec** — what the change was supposed to do: the PR body, a linked issue, a ticket id in the branch name or commits that the tracker resolves, a spec file the user named. Not found → the spec lens stays out, and the report says so in one line.

**Done when:** the scope is a concrete diff, and the spec is either in hand or known to be absent.

## 2. Pick the lenses

Gather candidates from two places:

- **Installed review skills.** Scan the agent's skill list and the skill directories from Preflight for skills whose name or description says review, audit, or check. Note each one's invocation: a skill with `disable-model-invocation: true` is **closed** — only a typed `/command` starts it.
- **The known lenses** below, each with its zone.

| Lens | Its zone in the diff |
| --- | --- |
| `mattpocock-skills:code-review` (or the pack's `code-review`) | a spec was found — run its **Spec** axis only |
| `code-craft` | new names, signatures, state shapes, new files — judge **new code only** |
| `test-craft` | tests added or changed |
| `reatom-review` | Reatom imports |
| `frontend-mvvm`, `qt-mvvm`, `mobx-mvvm`, `feod` | a new or moved module, screen, ViewModel, or a cross-module import |
| `better-interface`, `better-accessibility` | UI files: components, templates, styles, QML |
| `/interface-review` | UI files — closed |
| `security-review` | auth, sessions, secrets, crypto, SQL, input crossing a trust boundary |
| `testing-best-practices` | browser or component integration tests |

A discovered skill missing from the table gets its zone from its own description.

A lens runs only when its zone has a match in this diff. A found spec always takes one seat; rank the other matches by how much of the diff each zone covers, and open ones fill the remaining seats up to three. The rest:

- matched, closed → **run by hand**, with the command to type;
- matched, over the cap → **also worth running**;
- installed, no match → **not relevant here**, one line naming them.

**Done when:** every candidate is in exactly one of: running, run by hand, also worth running, not relevant.

## 3. Run

One run per lens plus the baseline, each in its own subagent and in parallel when the harness has subagents, otherwise one after another. Each run gets:

- the scope from step 1 and, for the spec lens, the spec;
- its skill, loaded;
- its brief: **defects and rule breaks in this change**, each as `file:line`, severity (`blocker` / `major` / `minor`), and one line of why. Code-craft and test-craft judge only lines this diff adds. Improvement ideas for code that already worked belong to `refactor-advice` — leave them out.

**Done when:** every running lens has returned findings or an explicit "nothing found".

## 4. Merge the report

The report is for the human: write it in the language the user speaks to you; code, paths and identifiers stay as they are.

1. One line of **assumptions**: the scope, the base, spec found or not, which lenses ran.
2. **Defects** — every finding from every run, ranked by severity. Two findings on the same `file:line` with the same cause collapse into one, tagged with every lens that raised it; keep the sharper wording.
3. **By lens** — what is left per lens that is not a defect: a rule break, a naming or test-shape issue. A lens with nothing left gets no section.
4. **Run by hand**, **Also worth running**, **Not relevant here** — one line each, omitted when empty.
5. Install lines from Preflight, if any.

**Done when:** every finding from every run appears exactly once, under a lens tag, and every candidate from step 2 is accounted for.
