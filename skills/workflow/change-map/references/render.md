# Rendering before and after

The recipe behind step 4 of [`SKILL.md`](../SKILL.md). `<map>` is the output folder from step 1 (an absolute path). `<base>` is a temp worktree at the base commit. `<head>` is the project root when the head is the current checkout; for a branch, a range or an MR it is a second temp worktree at the head commit, made and removed the same way. `<side>` is `base` or `head`, `<side root>` the matching tree, and `<checkout>` the user's project root, whose `node_modules` both temp trees borrow.

Both rungs that render follow one rule: **our own entry per piece and state, fed from the shared mocks, built by the project's own tooling.** The project's stories and pages are never what gets shot — they may have changed in the diff, and then base and head would show different data.

## Temp worktrees

```sh
git worktree add --detach "$(node -p "require('os').tmpdir()")/change-map-<side>-<short-sha>" <sha>
```

Link the checkout's dependencies into it instead of installing: `ln -s <checkout>/node_modules <tree>/node_modules`, on Windows `mklink /J <tree>\node_modules <checkout>\node_modules`. When a side's lockfile differs from the checkout's, that side runs on borrowed dependencies — say so in the `note` of every piece built this way. For someone else's MR that adds or bumps a dependency, the head side may not build at all; that piece falls to a sketch with the dependency named.

These are detached, throwaway snapshots: no branch, no work, nothing to carry over. `worktree-flow` is for worktrees where work lives, so it stays out of these. Remove each as soon as its builds are done — shooting reads only from `<map>` — and also after a failure:

```sh
git worktree remove --force <tree>
git worktree prune
```

## Mocks

One mock per piece and state in `<map>/mocks/`, read by **both** sides — a difference in data would show up as a difference in the UI.

- `mocks/<id>.<state>.json` — built from the component's props type on head: realistic values, the length real data has (a 40-character product name, not "Test").
- `mocks/<id>.<state>.base.json` — only when the props type differs between base and head: the same values with head-only props removed and base-only props added from base's type. The base entry imports this file when it exists; name the difference in the `note`.
- A state is a mock variant: `error` sets whatever the component reads as its error, `empty` an empty list.

## Entries

Per side, a harness folder: on head `<map>/harness/`, on base `<base>/.change-map-harness/`. Both sit inside their tree, so bare imports resolve through the `node_modules` above them. Every piece and state gets an entry that imports the component through the module's public API, the way its consumers do, and the mock by absolute path.

**Providers** come from the app root (`main`, `App`, `app/providers`) or the project's Storybook decorators: theme, i18n, a router in memory mode. A provider that needs a backend, a live store or a session is left out; a piece that cannot render without it falls to a sketch, and the `note` names what it needed.

## Rung 1: Storybook

The project has Storybook → use its setup (framework, builder, aliases, decorators) with our own stories, so the project's existing stories never matter.

Story per piece and state, `<harness>/<id>.<state>.stories.tsx`:

```tsx
import { CartItem } from '@/modules/cart';
import props from '<map>/mocks/cart-item.default.json';

export default { title: 'change-map/cart-item.default', component: CartItem };
export const Shot = { args: props };
```

A config folder `<harness>/.storybook/` that borrows the project's and swaps the stories:

```js
// <harness>/.storybook/main.js
import project from '<side root>/.storybook/main';

export default { ...project, stories: ['../*.stories.@(tsx|ts|jsx|js)'] };
```

```js
// <harness>/.storybook/preview.js
export * from '<side root>/.storybook/preview';
export { default } from '<side root>/.storybook/preview';
```

Point the import at whatever file the project has (`main.ts`, `main.js`, `preview.tsx`). Relative paths inside the project's `main` — `staticDirs: ['../public']`, a `viteFinal` alias built from `'../src'` — resolve against the new config folder, so rewrite them against `<side root>/.storybook` in the spread.

```sh
npx storybook build --config-dir <harness>/.storybook --output-dir <map>/render/<side>/sb
```

Run it from `<side root>`. The story ids are in `<map>/render/<side>/sb/index.json`; shoot entries point at `render/<side>/sb/iframe.html?id=<story-id>&viewMode=story`.

## Rung 2: Vite harness

No Storybook, the project builds with Vite → mount the component alone, built by the project's Vite config.

Per piece and state, `<harness>/<id>.<state>.html` (a `#root` div and a module script pointing at the entry) and the entry:

```tsx
// <harness>/cart-item.default.tsx — React
import { createRoot } from 'react-dom/client';
import { CartItem } from '@/modules/cart';
import { AppProviders } from '@/app/providers';
import props from '<map>/mocks/cart-item.default.json';
import '@/app/styles/global.css';

createRoot(document.getElementById('root')!).render(<AppProviders><CartItem {...props} /></AppProviders>);
```

```ts
// <harness>/cart-item.default.ts — Vue
import { createApp, h } from 'vue';
import CartItem from '@/modules/cart/CartItem.vue';
import AppProviders from '@/app/AppProviders.vue';
import props from '<map>/mocks/cart-item.default.json';
import '@/app/styles/global.css';

createApp({ render: () => h(AppProviders, null, () => h(CartItem, props)) }).mount('#root');
```

Global CSS and fonts are imported the way the app entry imports them. A Vue app that wires plugins (`app.use(i18n)`, `app.use(router)`) instead of provider components gets the same `use` calls before `mount`.

The build config reuses the project's so aliases, plugins and CSS handling match:

```js
// <harness>/vite.config.mjs
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { mergeConfig } from 'vite';
import project from '<side root>/vite.config.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const projectConfig = typeof project === 'function' ? await project({ command: 'build', mode: 'production' }) : project;

export default mergeConfig(projectConfig, {
  root: here,
  envDir: '<side root>',
  publicDir: '<side root>/public',
  base: './',
  build: {
    outDir: '<map>/render/<side>/vite',
    emptyOutDir: true,
    rollupOptions: { input: { 'cart-item.default': resolve(here, 'cart-item.default.html') } },
  },
});
```

```sh
npx vite build --config <harness>/vite.config.mjs
```

Run it from `<side root>`.

- Entry paths are absolute: Rollup resolves a bare `input` against the working directory, not against `root`.
- Moving `root` moves everything Vite and its plugins find relative to it. `envDir` and `publicDir` are pinned back above (keep the project's own `publicDir` if its config sets one), and a plugin that searches from the root — `vite-tsconfig-paths` is the common one — gets the side root passed explicitly (`tsconfigPaths({ root: '<side root>' })`), or `@/` imports stop resolving and every piece falls to a sketch for the wrong reason.
- The Vite output goes to `render/<side>/vite`, apart from Storybook's `render/<side>/sb`, so `emptyOutDir` never wipes the other rung's build.

A build that fails, fixed once and failing again, sends the pieces it carried to a sketch.

## Rung 3: Sketch

`sketch/<id>.<state>.before.html` and `.after.html`: static HTML with inline CSS, drawn from the old and the new markup and styles, using the project's real token values (colours, spacing, radii, font stack) read from its theme files. Same mock data as a render would use. `kind: 'sketch'`, and the `note` says why the piece is here.

## Shooting

Write `<map>/shots.json`, one entry per picture, with paths relative to `<map>`:

```json
[
  { "page": "render/base/vite/cart-item.default.html", "out": "shots/cart-item.default.before.png", "viewport": "480,320" },
  { "page": "render/head/vite/cart-item.default.html", "out": "shots/cart-item.default.after.png", "viewport": "480,320" }
]
```

One `viewport` per piece, the same on both sides, fitting the piece with a little air; a shot grows past it only when the piece itself is taller. `waitMs` (default 300) is there for pieces that animate in.

```sh
node <skill-dir>/scripts/shoot.mjs <map>
```

It serves `<map>` over local HTTP and shoots through a pinned Playwright. The first run on a machine may need `npx playwright@1.62.0 install chromium`. A non-zero exit lists the pages that are missing, failed, or point outside `<map>`; those pieces get no picture on that side, and the `note` says so.

## Cleanup

Every temp worktree is gone (see above). The harness, mocks, renders and shots stay under `<map>` — they are what the page shows and how the user checks what it was built from.
