---
name: design-flow
description: Turns "how do I improve this interface" or "I want a new one" into a short route through the UI skills, with the command and a ready prompt for each step.
disable-model-invocation: true
argument-hint: "what you want to improve or invent, in your own words"
---

# Design flow

A **router** over the UI packs installed below, chiefly [`jakubkrehel/skills`](https://github.com/jakubkrehel/skills) (the `better-*` family and its harness skills) and [`Leonxlnx/taste-skill`](https://github.com/Leonxlnx/taste-skill) (`design-taste-frontend`). Read one wish, pick its **route**, print each step as a command plus a prompt the user copies.

This skill prints and stops. It loads none of the skills it names and builds nothing: the user types every step. For every installed skill on the route, read its `description` before printing its step; where it contradicts the catalog below, the skill wins and the contradiction gets one line above the route.

## Read the forks

Settle each fork from the wish and the repo — open files, the diff, routes, the stack, any Figma link or image in the message. Ask only about a fork neither can settle, in one short block; state every guess in one line above the route.

- **New or existing**: inventing an interface, or improving one that runs.
- **Page or app screen**: a page is read and scrolled (landing, marketing, portfolio); an app screen is worked in (dashboard, settings, inbox, editor).
- **Scope**: one piece (a card, a form, a table), a whole screen or flow, or a change (uncommitted work, a branch, a PR).
- **Source**: a Figma link or a design image, or nothing.
- **Discipline**: the wish names one — color, type, copy, layout, accessibility, motion — or none.

**Done when:** every fork has a value, guessed or answered.

## Route the wish

Take the first row that fits.

| The wish | Route |
|---|---|
| build from a Figma link or a design image | `build-design` → `/state-machine` on its central piece → `better-interface` |
| "looks generic / AI-made", unsure what to change, no wish to rebuild | `better-interface` as a review → re-route on its top three findings |
| a page, new or running | `design-taste-frontend` → `better-interface` |
| an app screen, new or running | `frontend-design:frontend-design` → `/state-machine` on its central piece → `better-interface` |
| one piece, the direction is open | `/variant` → `/state-machine` → `/break` |
| one piece, its states or edge cases | `/state-machine`, then `/break` |
| one discipline is the problem | the matching `better-*` alone |
| audit a whole screen or flow | `better-interface` |
| check what my change broke | `/interface-review` |
| how was this effect or site built | `/explain-interface` with the URL or screenshot |
| a UX question that needs throwaway runnable code | `prototype`, then re-route with its answer |

The central piece is the one with the most states. A route runs one to four steps; pieces past the fourth step go to the next run. When a later row also fits, name it as the next run.

**Done when:** one row is chosen and the user has seen why in one line.

## Check the route's skills

Look up every skill the chosen route names, neighbours included: the skills the harness lists as available, else the skills folders of the agent in use. When one is missing, the route is gated: print the chosen row with its one-line why and its chain of skills, then the missing skills, each with its install line below; ask the user to install them and say when it is done, and stop before printing any step's prompt. On the user's word, check again; once all are found, print the route.

```bash
npx skills add jakubkrehel/skills
npx skills add Leonxlnx/taste-skill
npx skills add mattpocock/skills --skill prototype
npx skills add GoogleChrome/modern-web-guidance
npx skills add antfu/skills --skill unocss
/plugin install frontend-design@claude-plugins-official
/plugin install figma@claude-plugins-official
```

**Done when:** every skill the route names is found, or the user has the install lines for the missing ones and no step is printed.

## The catalog

**Closed** skills carry `disable-model-invocation: true`: only a typed `/command` starts them. **Open** ones the agent also loads on a plain request, so the command is optional.

| Skill | | Takes | Gives |
|---|---|---|---|
| `design-taste-frontend` | open | a company site or landing page, new or running | a page on a dealt palette and hero, held by a finish gate at 1440, 390 and 320 (checked on tasteskill 2.5.1) |
| `frontend-design:frontend-design` | open | an app screen, new or running | a committed visual direction and guidance for building or reshaping the screen in it |
| `build-design` | open | a Figma link or an image | UI on the project's own tokens and components, deviations listed |
| `better-interface` | open | a screen, a flow or the repo | one ranked review across all seven `better-*` disciplines |
| `better-colors` / `better-typography` / `better-layout` / `better-writing` / `better-accessibility` / `better-ui` / `better-motion` | open | the surface and the discipline | rules and exact values for that one discipline; `better-ui` owns radius, optical alignment, shadows and icons |
| `prototype` | open | one UX or state-model question | throwaway runnable code that answers it |
| `/variant` | closed | **one** piece | three variants behind a picker in the real page, tradeoffs, then one promoted |
| `/state-machine` | closed | **one** component | a throwaway page rendering every state on mock data, with a switcher |
| `/break` | closed | **one** component | a stress harness and a report of what broke, nothing fixed |
| `/interface-review` | closed | a change: working tree, branch, PR | what the change made worse; no change → it asks |
| `/explain-interface` | closed | a URL or a screenshot | how the effect is built and what transfers |

The harness skills take one piece per run. "The dashboard" is a screen; "the revenue card" is a piece. The prompt names the piece by its component and file, and a screen-sized wish gets one harness step per piece. The other skills take the whole screen in one step.

Neighbours enter a route only when the wish points at them: `modern-web-guidance` when the build leans on a recent CSS or HTML API, `unocss` on a UnoCSS project, `figma:figma-generate-design` when the result goes back into Figma.

## Print the route

The assumptions line, then each step. Every step's command is `/<skill name>`, open ones included; the open or closed mark says whether the user may ask in plain words instead.

````
**1. `/variant`** · closed
Why: the card's direction is open; compare three answers on the live page.

```
Make variants of RevenueCard from src/modules/dashboard/revenue-card.view.tsx. Axis: density, from a compact row to a large card with a chart. I check at 375 and 1440.
```
````

Everything printed is in the user's language, the labels and marks of the example included. Prompts are concrete: the piece or screen by name and path, the widths that matter (the project's breakpoints, else 1440 and 390), what must survive (brand colors, routes, existing components). Each prompt stands alone, since it starts a fresh run.

**Done when:** every step has a command, an open or closed mark, a one-line why, and a prompt the user can paste unchanged.
