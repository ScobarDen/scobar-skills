---
name: design-flow
description: Turns "how do I improve this interface" or "I want a new one" into a short route through the UI skills, with the command and a ready prompt for each step.
disable-model-invocation: true
argument-hint: "what you want to improve or invent, in your own words"
---

# Design flow

A **router** over two UI packs: [`jakubkrehel/skills`](https://github.com/jakubkrehel/skills) (the `better-*` family and its harness skills) and [`Leonxlnx/taste-skill`](https://github.com/Leonxlnx/taste-skill) (`design-taste-frontend`). Read one wish, pick its **route**, print each step as a command plus a prompt the user copies.

This skill prints and stops. It loads none of the skills it names and builds nothing: the user types every step. Each skill's own `SKILL.md` is the source of truth for what it does; this file only holds what their descriptions leave out — which to reach for, in what order, and what each one needs as input.

## Preflight

Check which skills are installed: `~/.claude/skills`, `~/.agents/skills`, `~/.claude/plugins`. A route step whose skill is missing gets its install line printed right before it, and the route goes on.

```bash
npx skills add jakubkrehel/skills
npx skills add Leonxlnx/taste-skill
```

**Done when:** every skill the route will name is either found or has its install line queued.

## Read the forks

Settle each fork from the wish and the repo — open files, the diff, routes, the stack, any Figma link or image in the message. Ask only about a fork neither can settle, in one short block; state every guess in one line above the route.

- **New or existing**: inventing an interface, or improving one that runs.
- **Page or app screen**: a page is read and scrolled (landing, marketing, portfolio); an app screen is worked in (dashboard, settings, inbox, editor). `design-taste-frontend` runs a different program for each, so the prompt says which.
- **Scope**: one piece (a card, a form, a table), a whole screen or flow, or a change (uncommitted work, a branch, a PR).
- **Source**: a Figma link or a design image, or nothing.
- **Discipline**: the wish names one — color, type, copy, layout, accessibility, motion — or none.

**Done when:** every fork has a value, guessed or answered.

## Route the wish

Take the first row that fits.

| The wish | Route |
|---|---|
| build from a Figma link or a design image | `build-design` → `/state-machine` → `better-interface` |
| a new page | `design-taste-frontend` (page run) → `better-interface` |
| a new app screen | `design-taste-frontend` (app-screen run) → `/state-machine` on its central piece → `better-interface` |
| redesign or restyle a running page or screen | `design-taste-frontend` (redesign: record the before first) → `better-interface` |
| "looks generic / AI-made", unsure what to change | `design-taste-frontend` as a review, which stops at the critique → re-route on its three changes |
| one piece, the direction is open | `/variant` → `/state-machine` → `/break` |
| one piece, its states or edge cases | `/state-machine`, then `/break` |
| one discipline is the problem | the matching `better-*` alone |
| audit a whole screen or flow | `better-interface` |
| check what my change broke | `/interface-review` |
| how was this effect or site built | `/explain-interface` with the URL or screenshot |
| a UX question that needs throwaway runnable code | `prototype`, then rejoin above |

A route runs one to four steps. Two rows fit → take the earlier one and name the other as the next run.

**Done when:** one row is chosen and the user has seen why in one line.

## The catalog

**Closed** skills carry `disable-model-invocation: true`: only a typed `/command` starts them. **Open** ones the agent also loads on a plain request, so the command is optional.

| Skill | | Takes | Gives |
|---|---|---|---|
| `design-taste-frontend` | open | a page or an app screen, new or running | an art direction dealt from a library, the build, screenshots at three widths, a fix loop |
| `build-design` | open | a Figma link or an image | UI on the project's own tokens and components, deviations listed |
| `better-interface` | open | a screen, a flow or the repo | one ranked review across all six `better-*` disciplines |
| `better-colors` / `better-typography` / `better-layout` / `better-writing` / `better-accessibility` / `better-ui` | open | the surface and the discipline | rules and exact values for that one discipline; `better-ui` owns radius, shadows, icons, motion |
| `/variant` | closed | **one** piece | three variants behind a picker in the real page, tradeoffs, then one promoted |
| `/state-machine` | closed | **one** component | a throwaway page rendering every state on mock data, with a switcher |
| `/break` | closed | **one** component | a stress harness and a report of what broke, nothing fixed |
| `/interface-review` | closed | a change: working tree, branch, PR | what the change made worse; no change → it asks |
| `/explain-interface` | closed | a URL or a screenshot | how the effect is built and what transfers |

The harness skills take one piece per run. "The dashboard" is a screen; "the revenue card" is a piece. The prompt names the piece by its component and file, and a screen-sized wish gets split into one step per piece.

Neighbours enter a route only when the wish points at them: `modern-web-guidance` when the build leans on a recent CSS or HTML API, `antfu-design` on a UnoCSS project, `frontend-design:frontend-design` when `design-taste-frontend` is absent, `figma:figma-generate-design` when the result goes back into Figma.

## Print the route

The assumptions line, then each step:

````
**1. `/variant`** · закрытый
Зачем: направление карточки не выбрано, сравнить три ответа на живой странице.

```
Сделай варианты RevenueCard из src/modules/dashboard/revenue-card.view.tsx. Ось — плотность: от компактной строки до крупной карточки с графиком. Смотрю на 375 и 1440.
```
````

Prompts are in Russian and concrete: the piece or screen by name and path, the page-or-app-screen kind for `design-taste-frontend`, the widths that matter, what must survive (brand colors, routes, existing components). Each prompt stands alone, since it starts a fresh run.

**Done when:** every step has a command, an open or closed mark, a one-line why, and a prompt the user can paste unchanged.
