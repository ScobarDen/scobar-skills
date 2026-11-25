# Project

## Architecture

- Levels (`app`, `pages`, `modules`, `common`, `global`) and modules with a public API: FEOD, as `feod` and `feod-preset` state it.
- What each file inside a module owns (Model, ViewModel, View and the supporting roles): `mvvm`.
- File names and role folders: `role-files`.
- A stack section below spells these for its stack.

## Skills

Load a skill when its area comes up, before the first line of code in it. When the skill for that area is missing from your skill list, stop, give me its install line from the block below and wait for my answer.

| Area | Skill |
| --- | --- |
| Levels, modules, public API | `feod`, `feod-preset` |
| Roles and file names | `mvvm`, `role-files` |
| Naming, signatures, the shape of code, where it goes | `code-craft` |
| Tests | `test-craft` |
| Improving or simplifying code | `refactor-advice` |
| Review | `review-flow` |
| The smallest change that solves the task | `ponytail` |
| Explaining a finished change; PR or MR text | `change-debrief`, `pr-description` |
| Grilling a plan, specs, tickets, TDD | `mattpocock/skills` |

```bash
npx skills add Sdju/feod
npx skills add ScobarDen/scobar-skills --skill feod-preset mvvm role-files code-craft test-craft refactor-advice review-flow change-debrief pr-description
npx skills add mattpocock/skills
```

`ponytail` is a Claude Code plugin: `/plugin marketplace add DietrichGebert/ponytail`, then `/plugin install ponytail@ponytail`.

## Commands

<!-- install, dev, check, test, build: one line each -->

## Project notes

<!-- one line per decision that diverges from a skill, and why -->
