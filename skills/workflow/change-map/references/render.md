# Rendering before and after

The recipe behind step 4 of [`SKILL.md`](../SKILL.md). `<map>` is the output folder from step 1 (an absolute path). `<base>` is a temp worktree at the base commit. `<head>` is the project root when the head is the current checkout; for a branch, a range or an MR it is a second temp worktree at the head commit, made and removed the same way. `<side>` is `base` or `head`, `<side root>` the matching tree, and `<checkout>` the user's project root, whose `node_modules` both temp trees borrow.

Both rungs that render follow one rule: **our own entry per piece and state, fed from the shared mocks, built by the project's own tooling.** The project's stories and pages are never what gets shot — they may have changed in the diff, and then base and head would show different data.

## Temp worktrees

```sh
git worktree add --detach "$(node -p "require('os').tmpdir()")/change-map-<side>-<short-sha>" <sha>
```

Link the checkout's dependencies into it instead of installing: `ln -s <checkout>/node_modules <tree>/node_modules`; on Windows a junction from PowerShell, `New-Item -ItemType Junction -Path <tree>\node_modules -Target <checkout>\node_modules` (`mklink` called from Git Bash mangles the path). When a side's lockfile differs from the checkout's, that side runs on borrowed dependencies — say so in the `note` of every piece built this way. For someone else's MR that adds or bumps a dependency, the head side may not build at all; that piece falls to a sketch with the dependency named.

These are detached, throwaway snapshots: no branch, no work, nothing to carry over. `worktree-flow` is for worktrees where work lives, so it stays out of these. Remove each as soon as its builds are done — shooting reads only from `<map>` — and also after a failure.

**Unlink `node_modules` first.** A recursive delete of the worktree can follow the link into the checkout's real `node_modules`. Remove the link itself, non-recursively — `rm <tree>/node_modules` (no `-r`), on Windows `[System.IO.Directory]::Delete('<tree>\node_modules')`, which removes a junction and refuses a real folder. Then:

```sh
git worktree remove --force <tree>
git worktree prune
```

## Mocks

One mock per piece and state in `<map>/mocks/`, read by **both** sides — a difference in data would show up as a difference in the UI.

- `mocks/<id>.<state>.json` — built from the component's props type on head: realistic values, the length real data has (a 40-character product name, not "Test").
- `mocks/<id>.<state>.base.json` — only when the props type differs between base and head: the same values with head-only props removed and base-only props added from base's type. The base entry imports this file when it exists; name the difference in the `note`.
- A state is a mock variant: `error` sets whatever the component reads as its error, `empty` an empty list.
- **Probe the branches that depend on shape.** Read how each side lays the data out — `fill` against fixed `width`/`height`, `object-cover` or none, line clamps, `min-width` — and give those branches data that tells them apart: a 2:1 image next to the square one, a name that wraps. A square image hides an image-fit change completely.
- Images live in `mocks/img/` and are referenced by absolute URL (`/mocks/img/1.png`): the shoot server serves `<map>` as its root. Prefer PNG; an SVG standing in for a photo needs `preserveAspectRatio="none"`, or it letterboxes where a raster would stretch.

## Entries

Per side, a harness folder: on head `<map>/harness/` when head is the checkout, otherwise `<head>/.change-map-harness/`; on base `<base>/.change-map-harness/`. Each sits inside its tree, so bare imports resolve through the `node_modules` above it. Every piece and state gets an entry that imports the component through the module's public API, the way its consumers do, and the mock by absolute path.

A piece that lives inside a page — an image slot, a card in a grid — is mounted inside the page's layout components and the wrapper classes that side's view gives it, copied from that side's view file, with the rest of the page left as an empty placeholder. The `note` says which wrapper was copied from where.

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

The project has Vite — as the app's builder, or only as the test runner. A Next app with a Vitest config qualifies: its config already resolves the aliases, and `next/image` is swapped for a plain `<img>`.

Check what `vite` actually is first: `node -p "require('vite/package.json').name"` from `<checkout>`. It may be a wrapper (`@voidzero-dev/vite-plus-core` answers to `vite` in vite-plus projects), and the project's `vite.config.*` may be a test and lint config whose plugins have nothing to do with a build. So the harness builds through Vite's JS API with an inline config, and takes from the project's config only what resolution needs: aliases, the CSS pipeline, a framework plugin the code cannot compile without (`@vitejs/plugin-vue` for `.vue` files).

Per piece and state, `<harness>/<id>.<state>.html` (a `#root` div and a module script pointing at the entry) and the entry:

```tsx
// <harness>/cart-item.default.tsx — React
import '@/app/globals.css';
import { createRoot } from 'react-dom/client';
import { CartItem } from '@/modules/cart';
import { AppProviders } from '@/app/providers';
import props from '<map>/mocks/cart-item.default.json';

createRoot(document.getElementById('root')!).render(<AppProviders><CartItem {...props} /></AppProviders>);
```

```ts
// <harness>/cart-item.default.ts — Vue
import '@/app/styles/global.css';
import { createApp, h } from 'vue';
import CartItem from '@/modules/cart/CartItem.vue';
import AppProviders from '@/app/AppProviders.vue';
import props from '<map>/mocks/cart-item.default.json';

createApp({ render: () => h(AppProviders, null, () => h(CartItem, props)) }).mount('#root');
```

Global CSS and fonts are imported the way the app entry imports them. A Vue app that wires plugins (`app.use(i18n)`, `app.use(router)`) instead of provider components gets the same `use` calls before `mount`.

```js
// <harness>/build.mjs
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { build } from 'vite';

const here = fileURLToPath(new URL('.', import.meta.url));
const sideRoot = '<side root>';

await build({
  configFile: false,
  root: here,
  base: './',
  envDir: sideRoot,
  publicDir: resolve(sideRoot, 'public'),
  resolve: {
    alias: [
      { find: /^@\//, replacement: resolve(sideRoot, 'src') + '/' },
      { find: /^next\/image$/, replacement: resolve(here, 'next-image.shim.tsx') },
    ],
  },
  css: { postcss: sideRoot },
  define: { 'process.env.NODE_ENV': '"production"' },
  build: {
    outDir: '<map>/render/<side>/vite',
    emptyOutDir: true,
    rollupOptions: { input: { 'cart-item.default': resolve(here, 'cart-item.default.html') } },
  },
});
```

```sh
node <harness>/build.mjs
```

Run it from `<side root>`, so Tailwind and other tools that scan from the working directory find the project's sources.

- Aliases are regular expressions anchored on the separator: a bare `'@'` key also catches `@scope/package` imports.
- `css.postcss` points at the side root, where the project's PostCSS config lives; with `root` moved to the harness, Vite would not find it.
- Entry paths are absolute: Rollup resolves a bare `input` against the working directory, not against `root`.
- Vite 8 compiles TSX with the automatic JSX runtime as is; an older Vite needs `esbuild: { jsx: 'automatic' }` or the project's React plugin.
- `next/image` shim: a component that renders `<img src alt width height className>`, and with `fill` adds `position: absolute; inset: 0; width: 100%; height: 100%`. It skips Next's optimisation and `sizes`, which is fine for a before/after of the same shim — say so in the `note`.
- Warnings about `"use client"` directives are harmless here.
- The Vite output goes to `render/<side>/vite`, apart from Storybook's `render/<side>/sb`, so `emptyOutDir` never wipes the other rung's build.

A build that fails, fixed once and failing again, sends the pieces it carried to a sketch.

## Rung 3: Sketch

`sketch/<id>.<state>.before.html` and `.after.html`: static HTML with inline CSS, drawn from the old and the new markup and styles, using the project's real token values (colours, spacing, radii, font stack) read from its theme files. Same mock data as a render would use. `kind: 'sketch'`, and the `note` says why the piece is here.

## Shooting

Take viewports from the project's own breakpoints — Tailwind `--breakpoint-*` tokens or `theme.screens`, the media queries in its layout code — not from Tailwind's defaults: a project's `lg` may be 1200px. One page shot at several viewports is several states.

Write `<map>/shots.json`, one entry per picture, with paths relative to `<map>`:

```json
[
  { "page": "render/base/vite/cart-item.default.html", "out": "shots/cart-item.default.before.png", "viewport": "1280,800", "selector": "#root > div > :first-child" },
  { "page": "render/head/vite/cart-item.default.html", "out": "shots/cart-item.default.after.png", "viewport": "1280,800", "selector": "#root > div > :first-child" }
]
```

- `viewport` is the same on both sides of a state.
- `selector` crops the shot to the piece; without it the shot is the full page. A desktop shot of a whole 1280px page does not fit next to its pair in the viewer, so crop pieces that sit in a wider layout.
- `waitMs` (default 300) is there for pieces that animate in.

```sh
node <skill-dir>/scripts/shoot.mjs <map>
```

It serves `<map>` over local HTTP and shoots with a pinned Playwright, installed once into the system temp directory on first use. When the browser itself is missing, it says to run `npx playwright@1.62.0 install chromium`. A non-zero exit lists the pages that are missing, failed, or point outside `<map>`; those pieces get no picture on that side, and the `note` says so.

## Cleanup

Every temp worktree is gone, its `node_modules` link removed first (see above). The harness, mocks, renders and shots stay under `<map>` — they are what the page shows and how the user checks what it was built from.
