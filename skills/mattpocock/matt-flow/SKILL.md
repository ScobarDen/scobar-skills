---
name: matt-flow
description: Walks one task through Matt Pocock's skills, naming the command to type at each step and remembering where you stopped.
disable-model-invocation: true
argument-hint: "the task to route, or nothing to resume"
---

# Matt flow

A **router** over [Matt Pocock's skills](https://github.com/mattpocock/skills): read one task, pick its **route**, name the next command.

Matt's orchestrators — `/grill-with-docs`, `/to-spec`, `/to-tickets`, `/implement`, `/wayfinder`, `/triage` — carry `disable-model-invocation: true`. Each is a **checkpoint**: the human types it, this skill hints. His primitives — `grilling`, `domain-modeling`, `tdd`, `code-review`, `research`, `prototype`, `diagnosing-bugs` — are model-invoked, so the agent loads those itself.

`/ask-matt` is the map of every route. This is the one route this task takes, plus the place you stopped.

Name a skill and hand over: its own `SKILL.md` is the source of truth for what it does.

## Preflight

Confirm the pack is reachable: `/ask-matt` exists, or Matt's skills sit under `~/.claude/skills`, `~/.agents/skills`, or `~/.claude/plugins`. When it is absent, give the install line and stop — the route is empty without the pack.

```bash
npx skills add mattpocock/skills
```

For real issues instead of local files, `/setup-matt-pocock-skills` configures a tracker. Local `.scratch/` files are the default and need no setup.

**Done when:** the pack is confirmed, or the user holds the install line.

## Route the task

Read the task, then take the first row that fits.

| The task | Route |
|---|---|
| one edit: a rename, a typo, a config line | none — do the work |
| something is broken, flaky, or slow | `diagnosing-bugs`, then rejoin at Build |
| fits one session, questions settle in conversation | Sharpen → Build |
| outlives one context window, or many moving parts | Sharpen → Spec → Tickets → Build per ticket |
| a design question that needs runnable code to answer | detour through `prototype`, then rejoin |
| fog: greenfield, or too big to hold in one session | hand off to `/wayfinder`, past this skill's scope |
| incoming issues or external PRs written by others | hand off to `/triage`, past this skill's scope |

Size is the fork that decides the route and the one that gets misread: "outlives one context window" is about context, not about how big the work feels.

**Done when:** one row is chosen and the user has seen which.

## Show the route

Print every step of the route as a checklist, the current one marked `→` and each finished one `✓`. The whole route stays on screen at every step, so what remains is as legible as what is at hand.

| Step | Command | Load first |
|---|---|---|
| Sharpen | `/grill-with-docs` | — |
| Spec | `/to-spec` | — |
| Tickets | `/to-tickets` | — |
| Build | `/implement` | the stack's own skills, plus `code-craft` |
| PR | — | `pr-description` |

Before Build, detect the stack from the repo — lockfiles, manifests, file extensions, config — and load its skills; a Qt module wants `qt-modular-mvvm` and `qt-cmake-boundaries`, a screen with client logic wants `frontend-mvvm`. Tests ride on `test-craft` alongside `tdd`. `/implement` closes with `code-review` on its own.

Between tickets: `/clear`, then `/matt-flow` to resume.

**Done when:** the route is on screen with the current step marked.

## Resume

`/matt-flow` with no argument resumes. State comes from the repo; the ledger holds only what the repo cannot show.

| Read | Tells you |
|---|---|
| `CONTEXT.md`, `docs/adr/` | Sharpen ran |
| the spec, on the tracker or in `.scratch/<feature>/` | Spec closed |
| `.scratch/<feature>/issues/` | which tickets exist, and which are closed |
| `git log` on the branch | what Build has landed |
| `.scratch/<feature>/flow.md` | the route, why it was chosen, what was ruled out |

`flow.md` runs ten lines: the route, the reason for it, and decisions no artifact records. It carries no counts or progress totals, so a second session working a parallel ticket cannot make it lie.

An artifact that disagrees with the ledger wins — the repo is what actually happened. One feature per run, tickets in blocker order.

**Done when:** the current step is derived from the repo and named to the user.
