---
name: frontend-state-stack
description: Choose a client-state stack before mixing libraries. Simple screens stay on a hooks ViewModel; heavy client logic (state + async + routing + forms as one contract) takes Reatom; MobX only if the project already uses it. Load on greenfield, "which state manager", Zustand vs Redux vs MobX vs Reatom vs React Query, or when a feature starts combining Zustand + TanStack Query + React Router as three sources of truth. Do not load when the stack is already chosen and the task is just implementing a feature. Points at reatom / frontend-mvvm / mobx-mvvm; does not re-teach them.
---

# Frontend state stack

Pick **one** reactive contract for the feature's logic. Then structure it with **`frontend-mvvm`**.

This skill is a gate, not a feature implementation guide. If `package.json` already shows the winner, stop and follow the repo.

## Provenance and precedence

- Same source as `frontend-mvvm`: [MVVM for React](https://www.youtube.com/watch?v=H0pKvQ8P3UI) (stack-choice section).
- **Project conventions win.** An existing Zustand+RQ app is not a rewrite target unless the user asked for a migration.
- Reatom API lives in **`reatom`** / **`reatom-async`** / **`reatom-field-notes`**. MobX recipe in **`mobx-mvvm`**. Hooks VM in **`frontend-mvvm`**. Do not copy those rules here.

## When to load

- Greenfield / "what STM should we use".
- A feature is about to add a *second* state library next to an existing one.
- The prompt is a comparison (Zustand vs Redux vs MobX vs Reatom vs React Query).

## When not to load

- The repo already has a chosen stack and the task is to implement a screen. Load `frontend-mvvm` plus the stack skill (`reatom`, `mobx-mvvm`, or hooks).
- The question is "how do I map this DTO" or "where does the click handler go". That is `frontend-mvvm`.

## Decision tree

Walk top to bottom. Stop at the first hit.

1. **Repo already chose.** Follow it. Do not introduce a sibling STM in this task.
2. **Frankenstack forming.** Client state in lib A, server cache in lib B, routing in lib C, forms in lib D — each with its own React-bound lifecycle, so a ViewModel cannot mediate them. Refuse the extra library. Collapse onto the covering stack the repo already has, or pick one below for greenfield.
3. **Simple screen.** CRUD form, list+filter, a settings page a top-level hook can hold. Hooks ViewModel (`frontend-mvvm` hooks adapter). React infra (debounce, query-shaped fetch, `createStore`) from **`reactuse`**, not a STM. Replacing `useState` with Zustand is not a stack.
4. **Heavy client logic.** Custom boards, dense orchestration, one contract needed for client state **and** async **and** routing **and** forms. **Reatom.** Load `reatom` + `reatom-async`. This is the covering-stack recommendation, not "always Reatom".
5. **Project is already MobX** (or the user explicitly stays on it). **`mobx-mvvm`**. Do not evangelize MobX into greenfield, and do not migrate MobX→Reatom inside an unrelated feature.

## What "covering stack" means

The VM has to sit *outside* the component and still run queries, cache, navigation, and form state. A library that only replaces `get`/`set` cannot. A library that only caches server state cannot. Glue between three of them is the cost this skill exists to avoid.

Zustand + TanStack Query + React Router is the usual glue pile: three sources of truth, three lifecycles, glue code in every screen.

## Output

When this skill fires, the answer is **one line** (stack + pointer), then implement under `frontend-mvvm`. Do not write a comparison essay unless the user asked for trade-offs.

| Verdict | Next |
| --- | --- |
| Hooks VM | `frontend-mvvm` + `reactuse` as needed |
| Reatom | `reatom` + `reatom-async` + `frontend-mvvm` |
| Stay on MobX | `mobx-mvvm` + `frontend-mvvm` |
| Repo already chose X | X's skill + `frontend-mvvm` |
