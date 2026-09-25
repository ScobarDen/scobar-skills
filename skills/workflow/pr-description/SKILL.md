---
name: pr-description
description: Write or update the title and description of a pull request / merge request from the branch diff — why first, then what, 1–3 bullets per section, grouped by business domain; English title, body in the user's language. Forge-agnostic (GitHub, GitLab, Gitea, Bitbucket), autodetects the base branch, fills the repo's own PR/MR template, and takes the motive from the open PR, the task tracker and the commits. Load whenever the user asks for an MR/PR description or title, asks to update or refresh an existing one, says "what do I write in the merge request", or is about to open one. Read-only by default — writes to the forge only on an explicit request, and then only inside its own marked block.
---

# PR / MR description

Turn a branch diff into a title and a body a reviewer can start from without opening the diff. A reviewer's hardest question is not "is there a bug" but **why does this change exist** — so the body answers **why** first, then **what**, and stays short enough to read in one pass.

GitHub calls it a pull request, GitLab a merge request. The analysis is identical; only the vocabulary of the output changes. "PR" below means whichever one this repo has.

**Read-only by default.** Reads git, the forge and the tracker; the output is text in the chat. Writing to the forge is a separate, explicit step — §11.

Forge and tracker commands for every step live in [`references/forge-cli.md`](references/forge-cli.md).

## 1. Resolve the forge

`git remote get-url origin`: `github` → PR, `gh`; `gitlab` → MR, `glab`; `gitea` / `forgejo` / `codeberg` → PR, `tea`; `bitbucket` or unknown → PR, no CLI.

Self-hosted domains rarely carry the product name — look for `.gitlab-ci.yml`, `.github/`, `.gitea/`, `bitbucket-pipelines.yml` before guessing. Still ambiguous → say "PR/MR" once and move on.

Forge hosts sit behind auth: reach them through the CLI or plain git, never a plain HTTP fetch.

## 2. Resolve the base branch

First hit wins:

1. A base the user named.
2. The target branch of an **already open PR for this branch** — the most reliable signal.
3. `origin/dev` or `origin/develop`, if either exists: a long-lived dev branch is where features branch off, whatever `origin/HEAD` says.
4. `origin/HEAD` — `git symbolic-ref --short refs/remotes/origin/HEAD`.
5. First existing of `origin/main`, `origin/master`.
6. Nothing resolved → ask. This is the one hard stop.

Refresh it, best effort: `git fetch origin <base-short> --quiet`, failure ignored.

## 3. Read the diff

```sh
git diff <base>...HEAD --stat                    # three dots — merge-base diff, noise included
git log  <base>..HEAD --oneline                  # what the author already said
git diff <base>...HEAD -- . ':(exclude)<noise>'  # the content, noise excluded
```

Three dots matter: with two, every commit that landed on the base after branching reads as "your" change.

**Noise** is read through `--stat` only and never by content: lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock*`, `Cargo.lock`, `poetry.lock`, `uv.lock`, `composer.lock`, `Gemfile.lock`, `go.sum`), build output (`dist/`, `build/`, `*.min.*`), snapshots (`__snapshots__/`, `*.snap`), generated code (`*.generated.*`, `*.g.cs`, `*.Designer.cs`, ORM model snapshots) and anything `.gitattributes` marks `linguist-generated` or `-diff`. Noise earns at most one bullet from its stat — "dependencies updated", "API client regenerated". A hand-written migration is not noise: it goes to Breaking changes.

A diff too large for one read goes to a temp file and is read in chunks, all of it. **Every hunk you describe is a hunk you read** — a plausible summary of an unread diff is the one failure of this skill nobody catches in review. Empty diff → say so and stop.

## 4. Gather context

**Why** comes from these sources, first hit wins:

1. **The body of the open PR**, if a human wrote one — the author's own intent. Keep what they said; don't throw it away.
2. **The task in the tracker.** Take the id from the branch name, the PR title or a link in the PR body, and read the task with whatever tracker tool the session has — an MCP server or a CLI (e.g. `gh issue view`, `glab issue view`, `jira`), read-only. No tool, no access → move on silently.
3. **Commit messages.**
4. **The branch name.**
5. Still nothing → §6.

The tracker feeds **why** only. **What** always comes from the diff. Retell the task's motive in your own words, never quote it: tracker text can carry client names, incidents and internal links that don't belong in a PR. Link the task only when the repo's existing PRs or commits already do. Task and diff disagree → describe the diff and add a note (§10).

**Vocabulary** comes from the repo's own docs when they exist — `CONTEXT.md` / `CONTEXT-MAP.md`, `ARCHITECTURE.md`, a glossary, `docs/adr/`. Name domains in the project's words; don't retell the docs.

**Rules** come from the PR/MR sections of `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, and from habits visible in `git log --oneline -30` on the base.

Precedence, top wins: the user in chat → the repo's template (shape) → repo rules (wording, limits, language, task-id format) → repo habits → this skill's defaults. A rule that contradicts the template on shape loses to the template; mention the conflict in one line.

## 5. The repo's template

```
.github/pull_request_template.md
.github/PULL_REQUEST_TEMPLATE.md
.github/PULL_REQUEST_TEMPLATE/*.md
.gitlab/merge_request_templates/*.md
.gitea/PULL_REQUEST_TEMPLATE.md
docs/pull_request_template.md
```

Found one → **fill that one.** Its headings, their order and its checkboxes stay verbatim. Each free-text section follows the 1–3 bullet limit of §8; a section the diff gives nothing for stays empty. Tick a checkbox only where the diff proves it (a "tests added" box needs test files in the diff). No section for the motive → **why** goes into the first section that fits, usually Summary or Description. Several templates → pick by name against the kind of change, and say which in one line.

No template → the shape in §8.

## 6. Ask why — once

When §4 found no motive, ask the author a single question before drafting: what problem does this change solve. An answer → it becomes **why**. "Don't know", "skip" or no answer → the body has no Why section, and no placeholder in its place. Everything else is decided from the diff, without questions.

## 7. Title

- One line, no trailing period, ≤ 72 chars for the generated part.
- Conventional-commit prefix when the change is clearly one kind: `feat:` `fix:` `refactor:` `chore:` `perf:` `docs:` `test:` `build:` `ci:`. Mixed with any new user-facing capability → `feat:`, otherwise the dominant kind. A repo whose `git log` doesn't use conventional commits gets none.
- Say what changed **for whoever consumes the code**, not which files moved.
  - Bad: `feat: update CardStore and CardActionsDropdown`
  - Good: `feat: allow admins to delete a user's card`
- `feat(scope):` only when the scope is a real product area, never a folder name.

**Task id prefix.** A leading token shaped like `[A-Z]+-?\d+` in the branch name (`feat/TSK-12345-cards`, `ABC-42-fix-cart`) is a task id → offer `TSK-12345 feat: allow admins to delete a user's card` — id, single space, no colon — and mention the bare title is available too. Recent titles on the base using `[TSK-12345]` or a trailing `(TSK-12345)` → follow that. No id → no prefix, and no placeholder.

## 8. Body — the default shape

Used when the repo has no template:

```markdown
## Why

- <1–3 bullets: the problem this solves, the motive from §4 or §6>

## What

- <1–3 bullets, one per business domain: behaviour before → after>

## Breaking changes

- <migrations, changed API or response shapes, new required params or env vars, removed public exports, widened or narrowed exported types, a new service the code now depends on>

## How to test

- <the shortest path a reviewer can follow to see it work: route, command, endpoint, fixture>
```

- **1–3 bullets per section.** Brevity is the point: a long description is one nobody reads.
- Group by **business domain**, one bullet per domain. More than three domains → keep the three that matter most for the reviewer and add a note (§10) that the PR looks worth splitting.
- **Breaking changes** and **How to test** appear only when there is something to put in them: real breakage, a runnable change. **Why** is absent only when §6 came back empty.
- Pure moves, formatting and internal renames stay out — unless they change a public export, which makes them breaking.
- Headings follow the description's language (§10).
- Plain voice: facts, no "seamlessly", no "robust", no apologising.

## 9. The marked block

The body — default shape or filled template — is wrapped in a pair of HTML comments:

```markdown
<!-- pr-description:start -->
...
<!-- pr-description:end -->
```

Every forge hides HTML comments when rendering, so the markers cost the reader nothing. They are the anchor for §11: a later update replaces only what lies between them and leaves the author's own text around them untouched. They are not an "AI-generated" label, and none is added.

## 10. Deliver

Print the title on its own line, then the marked body, then — outside the block, for the author, not the reviewer — the **notes**, one line each and only when they apply: the PR looks worth splitting, the task and the diff disagree, a defect you tripped over, a rule that conflicted with the template, which of several templates you picked. Then stop: no diff hunks, no file lists, no reasoning about the grouping.

Copy to the clipboard best effort (commands in the reference); it never fails the task. Nothing available → say the output is in the chat only, in one line.

**Language.** The title is English. The body is in the language the user writes to you in chat — headings included; a template's headings stay verbatim. Identifiers, paths, commands and the task id stay as they are in the code. An explicit language rule in the repo's rules (§4) outranks both; the language of past commits and PRs does not.

## 11. Writing to the forge

Only on an explicit request — "open the PR", "update the description" — and only through the forge CLI: no hand-built API calls, nothing forced. Show exactly what will be written and wait for a clear yes before running anything. No CLI, not authenticated, or no such command for this forge → say so in one line, and the text stays in the chat.

- **Update an open PR's body.** Markers present → replace what lies between them. No markers and an empty body → the marked block becomes the body. No markers and a non-empty body → append the marked block after it. The title changes only when that was asked for too.
- **Open a new PR.** Preconditions: clean tree, upstream set, nothing unpushed, not on the base branch. The marked block is the body.

## Boundaries

This skill reads git, the forge and the tracker, and writes nothing else: files stay as they are, branches stay where they are (no push, pull, rebase, merge or switch), tests, lint and builds stay unrun. It describes the change rather than reviewing it — a defect gets one note line, not a findings section.
