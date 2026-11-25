## Vue

Vue 3 with `<script setup lang="ts">`, Vue Router, Pinia, Pinia Colada, VueUse, UnoCSS. ViewModels, Views and routes follow `frontend-mvvm` and its `references/vue.md`.

- **Where state lives**: server data in Pinia Colada queries and mutations; screen state in the ViewModel composable, shared down the screen's tree with provide/inject; filters, search, sort and paging in the URL (`useRouteQuery` from `@vueuse/router`); only app-wide state (the user, settings, a cart) in Pinia setup stores.
- **Reactivity**: `shallowRef` by default, `ref` for objects changed in place, `reactive` only for the ViewModel's return groups. Props are read as `props.x`, never destructured.
- **Imports**: explicit `import` from `vue`, `vue-router` and every component; no auto-import plugins.
- **Styling**: UnoCSS with `presetWind4` in `uno.config.ts`. Class names are written in full, never concatenated.
- **Type check**: `vp check` does not type-check `.vue` files. `vue-tsc --noEmit` does, as the `typecheck` script that `.vite-hooks/pre-commit` and CI run. vue-tsc needs TypeScript 6 (`typescript@~6.0`); TypeScript 7 breaks it (vue-tsc 3.3.14, 2026-11-25). For `vp check` to resolve `.vue` imports in `.ts` files, `src/global/vue-shim.d.ts` declares `module '*.vue'`; that shim hides an SFC's own exports, so types live in `.ts` files and nothing imports a type from a `.vue` file.
- **Lint**: add `'vue'` to `lint.plugins`.
- **Tests**: `@testing-library/vue`; a ViewModel test calls the composable directly, inside `app.runWithContext` and an `effectScope` when it injects the router, Pinia or Pinia Colada. Component integration tests from `testing` run in `vp test` with `@testing-library/vue`, since Playwright's component testing for Vue is still `@playwright/experimental-ct-vue`; Playwright stays for browser flows.

### Skills

| Area | Skill |
| --- | --- |
| Vue style, Pinia, UnoCSS | `vue`, `pinia`, `unocss` (from `antfu/skills`) |
| Vue pitfalls; router | `vue-debug-guides`, `vue-router-best-practices` (from `vuejs-ai/skills`) |
| VueUse composables | `vueuse-functions` (from `vueuse/vueuse`) |

```bash
npx skills add antfu/skills --skill vue pinia unocss
npx skills add vuejs-ai/skills --skill vue-debug-guides vue-router-best-practices
npx skills add vueuse/vueuse --skill vueuse-functions
```
