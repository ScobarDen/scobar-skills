---
name: change-debrief
description: Explain work that already exists so the user understands the whole task end to end — what changed, which decisions carried weight, why each one, what is left and where it is thin. Default scope is the current branch, commits and working tree together; also takes a branch, a range, a path, or a feature named in prose, and then it explains how existing code is built instead of what changed. Plain language and named sources — every claim comes from files that were actually read, and every principle it cites says where that principle is written. Load when the user asks to explain what was done, walk me through this branch, I don't understand what happens here, onboard me onto this module, «объясни, что сделал», «разбери эту ветку», «введи в курс». Read-only and explanatory: bugs belong to code-review, improvements to refactor-advice, MR text to pr-description. A single question about a single function is an ordinary answer, not a debrief. Stack-agnostic.
---

# Change debrief

A debrief after the flight: the work is done, and now the person who owns it has to understand it well enough to defend it, extend it, and know what they are still carrying.

The reader is a developer who has not seen this code. Stack vocabulary is fine — `ViewModel`, facade, memoization. Anything specific to *this* project gets explained.

**Read-only.** Reads git and files, writes the debrief into the chat. Runs no tests, no build, no linter. A file only when the user asks for one, at the path they name.

**Explains, does not grade.** Bugs → `code-review`. Improvements → `refactor-advice`. MR text → `pr-description`. When something genuinely broken surfaces mid-debrief, name it in one line, say which skill picks it up, and carry on explaining.

## 1. Resolve the scope

First match wins:

1. **Nothing named** → the current branch in full: commits ahead of base **and** the working tree. This is the common case — a task just finished, half of it committed, half still sitting uncommitted.
2. **A branch or a range** (`feature/x`, `main..feature/x`) → that diff.
3. **An existing path** → the code mode of §5. Nothing changed there; explain how it is built.
4. **Prose naming a feature** → find it first: grep the name, read the directory layout, follow routes and entry points. One obvious home → work with it and **say out loud what you settled on** ("reading this as `src/modules/auth/*` — redirect me if that's wrong"). Several candidates or none → show what you looked for and ask.

Resolve the base the way `pr-description` does: what the user named → `origin/dev` / `origin/develop` if either exists → `origin/HEAD` → `origin/main` / `origin/master`. Diff with **three dots** (`git diff <base>...HEAD`) — with two, commits that landed on the base after branching become "your" work and the debrief turns into fiction.

Nothing committed, nothing modified, no scope given → say so and stop.

## 2. Facts from the files, reasons from the session

The one failure mode nobody catches in review: a fluent retelling of what the agent *intended*, drifting further from the files with every compaction of the context.

- **Every factual claim traces to something read in this run.** Session memory supplies the *why* — what was tried, what was rejected, what the user asked for mid-flight. It never supplies the *what*.
- **Describe only hunks you have read.** A large diff goes to a temp file and gets read in chunks.
- Prefer whole files over hunks wherever the decision under discussion reaches past the changed lines.
- In branch mode, read all of it: `git status`, `git diff`, `git diff --staged`, `git diff <base>...HEAD`, `git log <base>..HEAD --oneline`. Untracked files are read too — new files are usually the heart of the work.
- Changes in the tree that this session did not make belong to the user. Cover them as part of the picture, attributed honestly, or name them as out of scope.

## 3. Every principle names its source

"This follows SOLID and clean architecture" attached to arbitrary code is a horoscope: impressive, unfalsifiable, worthless. A principle enters the debrief only with a source, and the class of source is stated:

| Class | What it is | How it is cited |
| --- | --- | --- |
| **Project rule** | Written down in this repo: `AGENTS.md` / `CLAUDE.md`, an ADR, `CONTEXT.md`, `CONTRIBUTING.md`, linter and compiler config, a skill under `./.claude/skills` | Name the file |
| **Local convention** | A pattern already living in neighbouring code | Point at one example, `path:line` |
| **General practice** | Widely held craft, written nowhere here | Labelled as general practice |

No source, no mention. Naming an acronym obliges you to show the concrete thing that would break under the alternative — otherwise the acronym is decoration and the sentence reads better without it.

Skills loaded during the session that shaped the work count as a project rule: cite them by name.

## 4. Rank decisions by consequence

Two to four decisions carry the debrief. A change qualifies when at least one holds:

- the direction of a dependency or the boundary of a module moved
- a new abstraction, layer or pattern appeared that this repo did not have
- several options genuinely worked and one was chosen — the rejected ones are half the explanation
- an external dependency arrived
- a public contract changed: API, props, signature, schema, event, migration

Rank by **consequence**, measured as what breaks or gets harder under the alternative. Diff size measures typing, not weight — a three-line change that inverts a dependency outranks a four-hundred-line rename, and the rename belongs in the routine line of §7.

## 5. The skeleton

Sections in order; a section with nothing real in it collapses to one line rather than getting filled. Sections 1–2 stay short, section 3 carries the weight. Target a read of three to five minutes.

**Diff mode** — work that changed something:

1. **Суть** — what it was, what it is now, what for. Three sentences.
2. **Карта изменений** — three to six bullets grouped by meaning, not by file. A reader should be able to name the moving parts from this alone.
3. **Главные решения** — one block per decision from §4: what was chosen → why → what was turned down → what it commits you to next.
4. **Что осталось и где тонко** — cut corners, `TODO`s, uncovered cases, deferred calls, deliberate compromises. Written even when nobody asked, including the ones you made yourself.
5. **Чего я не проверял** — tests not run, runtime not exercised, integrations not touched. Plus one command the user can run to close the biggest gap.
6. **Что я сжал** — two or three places where the explanation simplified, each an offer to expand. This is where the reader sees the edge of their own understanding.

**Code mode** — a path or a feature that already existed:

1. **Зачем эта штука** — the job it does.
2. **Из чего состоит** — the parts, and who talks to whom.
3. **Главные решения** — same criteria as §4, reconstructed from the code. Mark reconstruction as reconstruction: "выглядит так, будто" is honest where an ADR or `git blame` is silent, and both are cheap to check first.
4. **Где тонко** — debts, oddities, `TODO`s, the places that break under an innocent edit. Work that is "left" appears here only where the code itself declares it.
5. **Чего я не проверял** and 6. **Что я сжал** — unchanged.

## 6. How it reads

- **Past tense, factual verbs.** "Вынес маппинг в фасад" — the reader decides whether that was good.
- **Every "why" answers "and what if the opposite".** A reason that survives no alternative is the code restated; drop it.
- **Analogies explain mechanism, and land where the mechanism is genuinely non-obvious** — a trade-off, an inversion, a lifecycle. Two or three in a whole debrief is plenty. An analogy that only decorates ("код как сад") costs the reader more than it gives.
- **Snippets are copied, never paraphrased**: `было → стало`, three to five lines, real identifiers, inside decision blocks only. Point at everything else with `path:line`.
- **Headings and bullets**, emoji in section headings at most.
- **Language follows the user.** Prose in whatever language the conversation runs in; identifiers, paths, commands and quoted output stay as the repo has them.

Self-assessment stays out: *элегантно*, *чисто*, *значительно*, *robust*, *правильная архитектура* describe the author's feelings rather than the code. So do connectives that announce importance while carrying none — *стоит отметить, что*.

## 7. Scale and honesty

- A hundred-plus files is not an invitation to describe a hundred files. Explain what §4 selects, then one line for the rest: "плюс N файлов рутины — переименования, импорты, форматирование".
- A debrief that cannot fit the target read offers a split by theme and lets the user pick, rather than shipping a wall.
- State the reading cap when one was hit. An unstated cap reads as full coverage.
- A `TODO` or `FIXME` sitting in code the debrief covers is worth one line in "Что осталось" — what it is about, not a plan to fix it.

[`references/example-debrief.md`](references/example-debrief.md) is one full debrief of a fictional refactor. Read it for **form and density** — the weight of each section, sentence length, how a decision block lands. Its wording and its Russian are not a template; the language of the output follows the user.

## What NOT to do

- ❌ Don't describe a file you didn't open.
- ❌ Don't cite a principle without its source class.
- ❌ Don't invent remaining work in code mode — only what the code itself declares.
- ❌ Don't fix, refactor or review inside a debrief. Name it, hand it to the right skill, keep explaining.
- ❌ Don't run tests, builds or linters. Name the gap instead.
- ❌ Don't quiz the reader. The offer to expand in "Что я сжал" does that job without the exam.
