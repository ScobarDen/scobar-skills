---
name: pr-description
description: Write the title and description for a pull request / merge request from the branch diff. Forge-agnostic (GitHub, GitLab, Gitea, Bitbucket), autodetects the base branch, fills the repo's own PR/MR template when there is one, groups changes by business domain instead of by file, and lifts a task id out of the branch name. Load whenever the user asks for an MR/PR description or title, says "what do I write in the merge request", or is about to open one. Read-only — writes no files, pushes nothing, opens no PR unless that is asked for separately.
---

# PR / MR description

Turn a branch diff into a title and a body someone can review without opening the diff.

GitHub calls it a pull request, GitLab a merge request. The analysis is identical; only the vocabulary of the output changes. "PR" below means whichever one this repo has.

**Read-only.** This skill reads git and produces text in the chat (plus, best effort, the clipboard). It creates no files, pushes nothing, and does not open the PR. Opening it is a separate request — see the end.

## 1. Resolve the forge

`git remote get-url origin` decides the vocabulary and which CLI is worth trying:

| Host contains | Call it | CLI, if installed |
| --- | --- | --- |
| `github` | pull request, PR | `gh` |
| `gitlab` | merge request, MR | `glab` |
| `gitea` / `forgejo` / `codeberg` | pull request, PR | `tea` |
| `bitbucket` | pull request, PR | — |
| unknown host / no remote | pull request, PR | — |

Self-hosted instances usually don't carry the product name in the domain. Before guessing, look for `.gitlab-ci.yml`, `.github/`, `.gitea/`, `bitbucket-pipelines.yml`. If it stays ambiguous, say "PR/MR" once and move on — the description doesn't depend on it.

**Never fetch a forge URL over plain HTTP.** Those hosts sit behind auth and hand back a login page. Use the CLI, or plain git.

## 2. Resolve the base branch

First hit wins:

1. A base the user named in the request.
2. The target branch of an **already open PR for this branch** — the most reliable signal there is:
   `gh pr view --json baseRefName -q .baseRefName` / `glab mr list --source-branch "$branch" -F json`.
3. `origin/dev` or `origin/develop`, if either exists. A repo with a long-lived dev branch branches features off it even when `origin/HEAD` points at `main`.
4. `origin/HEAD` — `git symbolic-ref --short refs/remotes/origin/HEAD`.
5. First existing of `origin/main`, `origin/master`.
6. Nothing resolved → ask. Don't guess into a diff.

Then refresh it, best effort: `git fetch origin <base-short> --quiet` — ignore failure (offline, ref gone).

## 3. Read the diff

```sh
git diff <base>...HEAD --stat     # three dots — merge-base diff
git log  <base>..HEAD --oneline   # two dots — what the author already said about their own work
git diff <base>...HEAD            # the whole thing
```

Three dots matter: with two, every commit that landed on the base after you branched shows up as "your" change and the description turns into fiction.

If the full diff is too large to read in one go, redirect it to a temp file and read that in chunks. **Never describe a hunk you haven't read** — a plausible summary of an unread diff is the one failure mode of this skill that nobody catches in review.

Empty diff against base → say so and stop.

## 4. The repo's template wins

Before writing your own shape, look for the repo's:

```
.github/pull_request_template.md
.github/PULL_REQUEST_TEMPLATE.md
.github/PULL_REQUEST_TEMPLATE/*.md
.gitlab/merge_request_templates/*.md
.gitea/PULL_REQUEST_TEMPLATE.md
docs/pull_request_template.md
```

Found one → **fill that one.** Keep its headings, their order and its checkboxes verbatim. Fill each section from the diff, leave a section empty rather than padding it, and tick a checkbox only where the diff actually proves it (a "tests added" box needs test files in the diff). A directory of several templates → pick by name against the kind of change and say which you picked, in one line.

No template → the fallback in §6.

## 5. Title

- One line, no trailing period, ≤ 72 chars for the generated part.
- Conventional-commit prefix when the change is clearly one kind: `feat:` `fix:` `refactor:` `chore:` `perf:` `docs:` `test:` `build:` `ci:`. A mixed set with any new user-facing capability → `feat:`, otherwise the dominant kind.
- **Match the repo, not this list.** If `git log --oneline -30` on the base shows the project doesn't use conventional commits, don't introduce them in a PR title.
- Describe what changed **for whoever consumes the code**, not which files moved.
  - Bad: `feat: update CardStore and CardActionsDropdown`
  - Good: `feat: allow admins to delete a user's card`
- `feat(scope):` only when the scope is a real product area, never a folder name.

## 6. Body — fallback shape

Used only when the repo has no template of its own:

```markdown
## Summary

<2–3 sentences: what was done and why. The why comes from the commits, the task id, or the branch name — if none of them say, don't invent a motive.>

## Changes

- <one bullet per business domain: the behaviour before → after>

## Breaking changes

- <migrations, changed API or response shapes, new required params or env vars, removed public exports, widened or narrowed exported types, a new service the code now depends on>

## How to test

- <the shortest path a reviewer can follow to see it work: route, command, endpoint, fixture>
```

- Group by **business domain, not by file**. One bullet per domain, not one per changed path.
- Skip pure moves, formatting-only churn and internal renames — unless they change a public export, in which case they belong under breaking changes.
- No breaking changes → keep the heading with a single `- None`. Don't invent breakage to fill it, and don't delete the heading either: an explicit "None" is information.
- Drop **How to test** when the change genuinely isn't runnable (config, docs, types).
- No marketing voice. No "seamlessly", no "robust", no apologising.

## 7. Task id

Lift it from the branch name — `feat/TSK-12345-cards`, `ABC-42-fix-cart`, `bugfix/INC-9001`. A leading token shaped like `[A-Z]+-?\d+` is a task id.

- Found one → offer the title as `TSK-12345 feat: allow admins to delete a user's card` — task id, single space, no colon — and mention that the bare title is available if they don't want the prefix.
- **Match the repo's habit first**: if recent titles on the base use `[TSK-12345]` or a trailing `(TSK-12345)`, follow that instead.
- Not found → no prefix. Never invent a placeholder id.

## 8. Deliver

Print the title on its own line, then the body, then stop. No diff hunks, no file lists, no reasoning about how you grouped things.

Copying to the clipboard is a nice-to-have — try the platform's tool and never let it fail the task:

| Platform | Command |
| --- | --- |
| Windows (git-bash) | `clip` |
| Windows (PowerShell) | `Set-Clipboard` |
| macOS | `pbcopy` |
| Linux / Wayland | `wl-copy` |
| Linux / X11 | `xclip -selection clipboard` |

None available → say the output is in the chat only, in one line.

**Language of the description:** follow whatever the repo already uses in commits and existing PRs, defaulting to English. This is the repo's artefact, not chat output — a chat-language preference doesn't apply to it.

## Opening the PR is a separate step

This skill stops at the text. If the user then asks to actually open it, that's a distinct action with its own preconditions — clean tree, upstream set, nothing unpushed, not sitting on the base branch — and it needs their explicit go-ahead. Use the forge CLI (`gh pr create` / `glab mr create`), never a hand-built API call, and never force anything.

## What NOT to do

- ❌ Don't write files. Not `MR.md`, not `docs/pr.md`, nothing. The output lives in the chat.
- ❌ Don't push, pull, rebase, merge or switch branches.
- ❌ Don't run tests, lint or build — this skill reads git and nothing else.
- ❌ Don't review the code. A defect you trip over gets one line at the end, not a findings section.
- ❌ Don't ask clarifying questions about the diff — decide from it. The only hard stop is an unresolvable base branch.
- ❌ Don't describe unread hunks.
