---
name: change-debrief
description: Explain work that already exists so the user understands the whole task end to end — why it was done, the one change that matters most shown in real code, which decisions carried weight, what is left and where it is thin. Short by default, deeper on request. Default scope is the current branch, commits and working tree together; also takes a branch, a range, a path, or a feature named in prose, and then it explains how existing code is built instead of what changed. Plain language and named sources — every claim comes from files that were actually read, and every principle it cites says where that principle is written. Load when the user asks to explain what was done, walk me through this branch, I don't understand what happens here, onboard me onto this module, «объясни, что сделал», «разбери эту ветку», «введи в курс». Read-only and explanatory — bugs belong to code-review, improvements to refactor-advice, MR text to pr-description. A single question about a single function is an ordinary answer, not a debrief. Stack-agnostic.
---

# Change debrief

A debrief after the flight: the work is done, and now the person who owns it has to understand it well enough to defend it, extend it, and know what they are still carrying.

The reader is a developer who has not seen this code — except where they have. Stack vocabulary is fine — `ViewModel`, facade, memoization. Anything specific to *this* project gets explained.

**Short by default, deeper on request.** The debrief is a one-to-two-minute read. Everything that doesn't fit goes into the closing offer to expand (§5), and the reader pulls what they want.

**Calibrate on what the reader already watched.** Decisions the user made, approved or argued through in this session are established; re-deriving them spends the reader's attention on what they already hold. One line of reference each, and the budget goes to what happened out of their sight.

**Read-only.** Reads git, files, the forge and the tracker, and writes the debrief into the chat. Runs no tests, no build, no linter. A file only when the user asks for one, at the path they name.

**Explains, does not grade.** Bugs → `code-review`. Improvements → `refactor-advice`. MR text → `pr-description`. When something genuinely broken surfaces mid-debrief, name it in one line, say which skill picks it up, and carry on explaining.

## 1. Resolve the scope

First match wins:

1. **Nothing named** → the current branch in full: commits ahead of base **and** the working tree. This is the common case — a task just finished, half of it committed, half still sitting uncommitted.
2. **A branch or a range** (`feature/x`, `main..feature/x`) → that diff.
3. **An existing path** → code mode (§5). Nothing changed there; explain how it is built.
4. **Prose naming a feature** → find it first: grep the name, read the directory layout, follow routes and entry points. One obvious home → work with it and **say out loud what you settled on** ("reading this as `src/modules/auth/*` — redirect me if that's wrong"). Several candidates or none → show what you looked for and ask.

Base branch: what the user named → `origin/dev` / `origin/develop` if either exists → `origin/HEAD` → `origin/main` / `origin/master`. Diff with **three dots** (`git diff <base>...HEAD`) — with two, commits that landed on the base after branching become "your" work and the debrief turns into fiction.

Nothing committed, nothing modified, no scope given → say so and stop.

## 2. Facts from the files, reasons from the session

The one failure mode nobody catches in review: a fluent retelling of what the agent *intended*, drifting further from the files with every compaction of the context.

- **Every factual claim traces to something read in this run.** The *what* comes from files only.
- **Describe only hunks you have read.** A large diff goes to a temp file and gets read in chunks.
- Prefer whole files over hunks wherever the decision under discussion reaches past the changed lines.
- In branch mode, read all of it: `git status`, `git diff`, `git diff --staged`, `git diff <base>...HEAD`, `git log <base>..HEAD --oneline`. Untracked files are read too — new files are usually the heart of the work.
- **Noise** is read through `--stat` only: lockfiles, build output (`dist/`, `build/`, `*.min.*`), snapshots, generated code, anything `.gitattributes` marks `linguist-generated` or `-diff`. It earns one line at most.
- Changes in the tree that this session did not make belong to the user. Cover them as part of the picture, attributed honestly, or name them as out of scope.

The *why* comes from the session — what was asked, tried, rejected. When the session doesn't hold it (a fresh session, someone else's branch), fall back, best effort and read-only: the body of the open PR → the task in the tracker, by the id in the branch name, through whatever MCP server or CLI the session has → commit messages. Still nothing → say the motive is unknown rather than inventing one.

## 3. Every principle names its source

"This follows SOLID and clean architecture" attached to arbitrary code is a horoscope: impressive, unfalsifiable, worthless. A principle enters the debrief only with a source, and the class of source is stated:

| Class | What it is | Tag in the text |
| --- | --- | --- |
| **Project rule** | Written down in this repo: `AGENTS.md` / `CLAUDE.md`, an ADR, `CONTEXT.md`, `CONTRIBUTING.md`, linter and compiler config, a skill under `./.claude/skills` | `(правило: CLAUDE.md)` |
| **Local convention** | A pattern already living in neighbouring code | `(как в billing/mappers.ts:14)` |
| **General practice** | Widely held craft, written nowhere here | `(общая практика)` |

The tag is a parenthesis at the end of the sentence it backs, not a sentence of its own. No source, no mention. Naming an acronym obliges you to show the concrete thing that would break under the alternative — otherwise the acronym is decoration and the sentence reads better without it.

Skills loaded during the session that shaped the work count as a project rule: cite them by name.

## 4. Rank decisions by consequence

One to three decisions carry the debrief. A change qualifies when at least one holds:

- the direction of a dependency or the boundary of a module moved
- a new abstraction, layer or pattern appeared that this repo did not have
- several options genuinely worked and one was chosen — the rejected ones are half the explanation
- an external dependency arrived
- a public contract changed: API, props, signature, schema, event, migration

Rank by **consequence**, measured as what breaks or gets harder under the alternative. Diff size measures typing, not weight — a three-line change that inverts a dependency outranks a four-hundred-line rename, and the rename belongs in the routine line.

**Decision №1 is the main change.** It is the one shown in code (§5), so the example and the ranking never disagree.

## 5. The skeleton

Sections in order. A section with nothing real in it is left out entirely, heading included.

**Diff mode** — work that changed something:

1. **Суть** — 2–3 sentences: **why** first (the problem), then what it is now. Where the delivered work diverged from what was asked — scope trimmed, approach swapped, a piece deferred — the divergence goes here, in the opening.
2. **Главное в коде** — decision №1, shown. One real snippet, then 2–3 sentences:
   - A local edit → one ```` ```diff ```` block. Code that moved between files → two blocks, `было` and `стало`. Each block is headed by its `path:line`, holds at most 8 lines, and is cut with `…` rather than paraphrased. Code is copied verbatim — no markers added inside it.
   - The sentences name the key line by its identifier and say what changes **in behaviour**: what happens at the next edit of this kind, and what used to happen instead. This is where the debrief goes one level below the label — a shape ("вынес маппинг в фасад") reads as understanding while leaving none behind; the chain is what stays with the reader.
   - No meaningful code in the diff (docs, config, types only) → the weightiest hunk, whatever its kind. Nothing but noise → the section is left out.
3. **Что поменялось** — 3–5 bullets grouped by meaning, not by file, plus one line for routine and noise. A reader should be able to name the moving parts from this alone.
4. **Главные решения** — one block per decision from §4, four short lines of one sentence each:
   - **Выбрал** — what.
   - **Почему** — the reason, answering "and what if the opposite".
   - **Вместо** — what was turned down.
   - **Цена** — what became harder, slower or newly obligatory. A decision that lists only upsides is advertising.

   Decision №1 refers to the snippet above instead of repeating it. The other decisions get `path:line`, never a snippet.
5. **Что осталось и чего не проверял** — up to 5 bullets: cut corners, `TODO`s, uncovered cases, deferred calls, deliberate compromises — including your own — and the tests, runtime and integrations not exercised. Then one command the user can run to close the biggest gap.

Close with one line: **«Могу развернуть: …»** — two or three places where the debrief simplified, each an offer to expand. This is where the reader sees the edge of their own understanding.

**Code mode** — a path or a feature that already existed:

1. **Зачем эта штука** — the job it does, 2–3 sentences.
2. **Сердце механизма** — up to 10 lines of the one place everything turns on (the entry point, the mapper, the state transition), headed by `path:line`, then 2–3 sentences on what happens there and why it is built that way.
3. **Из чего состоит** — 3–5 bullets: the parts, and who talks to whom.
4. **Главные решения** — same block and criteria as §4, reconstructed from the code. Mark reconstruction as reconstruction: "выглядит так, будто" is honest where an ADR or `git blame` is silent, and both are cheap to check first.
5. **Где тонко и чего не проверял** — debts, oddities, `TODO`s, the places that break under an innocent edit; remaining work only where the code itself declares it.

Close with the same «Могу развернуть» line.

## 6. How it reads

- **Past tense, factual verbs.** "Вынес маппинг в фасад" — the reader decides whether that was good.
- **Every "why" answers "and what if the opposite".** A reason that survives no alternative is the code restated; drop it.
- **One analogy at most**, and only where the mechanism is genuinely non-obvious — a trade-off, an inversion, a lifecycle. It explains mechanism rather than decorating, and one clause says where it stops holding: an analogy carried past its limit is how a confident wrong model gets built.
- **Headings and bullets**, emoji in section headings at most.
- **Language follows the user.** Prose in whatever language the conversation runs in; identifiers, paths, commands and quoted output stay as the repo has them.

Write the facts and the trade-offs plainly: "этот вариант дороже в поддержке, взял его ради X" explains. Words that grade the author's own work — *элегантно*, *чисто*, *значительно*, *robust*, *правильная архитектура* — and connectives that announce importance while carrying none — *стоит отметить, что* — stay out.

## 7. Scale and honesty

- A hundred-plus files is not an invitation to describe a hundred files. Explain what §4 selects, then one line for the rest: "плюс N файлов рутины — переименования, импорты, форматирование".
- A debrief that cannot fit the target read offers a split by theme and lets the user pick, rather than shipping a wall.
- State the reading cap when one was hit. An unstated cap reads as full coverage.
- A `TODO` or `FIXME` sitting in code the debrief covers is worth one line in «Что осталось» — what it is about, not a plan to fix it.

[`references/example-debrief.md`](references/example-debrief.md) is one full debrief of a fictional refactor. Read it for **form and density** — the length of each section, how the main change lands in code, how short a decision block is. Its wording and its Russian are not a template; the language of the output follows the user.

## Boundaries

- Every file described is a file opened in this run.
- Every principle carries its source tag.
- In code mode, remaining work comes only from what the code itself declares.
- Explaining is the whole job: fixes, refactors and reviews are named in one line and handed to their skill.
- Tests, builds and linters stay unrun; the gap is named instead.
- The reader is offered depth, never quizzed.
