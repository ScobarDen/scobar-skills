# Rendering before and after

The recipe behind step 4 of [`SKILL.md`](../SKILL.md). `<map>` is `.git/change-map/<slug>/`; paths below are relative to it unless they start with `<head>` (the project root) or `<base>` (the temp worktree).

## The base side

```sh
git worktree add --detach "$TMPDIR/change-map-base-<short-sha>" <base-sha>
```

Link the project's dependencies into it instead of installing: `ln -s <head>/node_modules <base>/node_modules`, on Windows `mklink /J <base>\node_modules <head>\node_modules`. When the lockfile differs between base and head, the base side now runs on head's dependencies — say so in the `note` of every piece built this way.

This is a detached, throwaway snapshot: no branch, no work, nothing to carry over. `worktree-flow` is for worktrees where work lives, so it stays out of this one. Remove it as soon as the last base shot is taken, even after a failure:

```sh
git worktree remove --force <base>
```

## Mocks

One mock per piece and state, written once to `mocks/<id>.<state>.json` and fed to **both** sides — a difference in data would show up as a difference in the UI.

- Build it from the component's props type on head: realistic values, the length real data has (a 40-character product name, not "Test").
- A prop that exists only on head is dropped on the base side; a prop that exists only on base gets a value from base's type. Name either case in the `note`.
- A state is a mock variant: `error` sets whatever the component reads as its error, `empty` an empty list.

## Rung 1: Storybook

On each side, `npx storybook build --output-dir <map>/render/<side>/sb` from that side's root. When the piece has no story for a state, write a story file next to the harness rather than into the project's stories: on head under `<map>/harness/`, on base inside `<base>`.

Shoot entries point at `render/<side>/sb/iframe.html?id=<story-id>&viewMode=story`.

## Rung 2: Vite harness

Per side, a harness folder: on head `<map>/harness/`, on base `<base>/.change-map-harness/`. Both sit inside their tree, so bare imports resolve through the `node_modules` above them.

For each piece and state, the harness gets an HTML page and an entry that mounts the component alone:

```tsx
// harness/cart-item.default.tsx
import { createRoot } from 'react-dom/client';
import { CartItem } from '@/modules/cart';
import { AppProviders } from '@/app/providers';
import props from '<map>/mocks/cart-item.default.json';
import '@/app/styles/global.css';

createRoot(document.getElementById('root')!).render(
  <AppProviders><CartItem {...props} /></AppProviders>,
);
```

- Import the component through the module's public API, the way its consumers do. Mocks are imported by absolute path, so both sides read the same file.
- **Providers** come from the app root (`main`, `App`, `app/providers`): theme, i18n, a router in memory mode. A provider that needs a backend, a live store or a session is left out; a piece that cannot render without it falls to a sketch, and the `note` names what it needed.
- Global CSS and fonts are imported the way the app entry imports them.

The build reuses the project's Vite config so aliases, plugins and CSS handling match:

```js
// harness/vite.config.mjs
import { mergeConfig } from 'vite';
import project from '<side root>/vite.config.ts';

const base = typeof project === 'function' ? await project({ command: 'build', mode: 'production' }) : project;
export default mergeConfig(base, {
  root: import.meta.dirname,
  envDir: '<side root>',
  publicDir: '<side root>/public',
  base: './',
  build: {
    outDir: '<map>/render/<side>',
    emptyOutDir: true,
    rollupOptions: { input: { 'cart-item.default': 'cart-item.default.html' } },
  },
});
```

```sh
npx vite build --config <harness>/vite.config.mjs
```

Moving `root` also moves everything Vite and its plugins find relative to it: `envDir` and `publicDir` are pinned back above, and a plugin that searches from the root — `vite-tsconfig-paths` is the common one — gets the side root passed explicitly (`tsconfigPaths({ root: '<side root>' })`), or `@/` imports stop resolving and every piece falls to a sketch for the wrong reason. Keep the project's own `publicDir` if its config sets one.

Run it with the side's own root as the working directory. A build that fails, fixed once and failing again, sends that piece to a sketch.

## Rung 3: Sketch

`sketch/<id>.<state>.before.html` and `.after.html`: static HTML with inline CSS, drawn from the old and the new markup and styles, using the project's real token values (colours, spacing, radii, font stack) read from its theme files. Same mock data as a render would use. `kind: 'sketch'`, and the `note` says why the piece is here.

## Shooting

Write `shots.json` in `<map>`, one entry per picture:

```json
[
  { "page": "render/base/cart-item.default.html", "out": "shots/cart-item.default.before.png", "viewport": "480,320" },
  { "page": "render/head/cart-item.default.html", "out": "shots/cart-item.default.after.png", "viewport": "480,320" }
]
```

Pick a `viewport` that fits the piece with a little air; the same one on both sides. `waitMs` (default 300) is there for pieces that animate in.

```sh
node <skill-dir>/scripts/shoot.mjs <map>
```

It serves `<map>` over local HTTP and shoots through a pinned Playwright. The first run on a machine may need `npx playwright@1.62.0 install chromium`. A non-zero exit lists the pages that are missing or failed; those pieces get no picture on that side, and the `note` says so.

## Cleanup

Before the run ends: `git worktree remove --force <base>`, then `git worktree prune`. The harness, mocks, renders and shots stay under `<map>` — they are what the page shows and how the user checks what it was built from.
