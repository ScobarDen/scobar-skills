---
name: change-map
description: Turn a diff too big to read line by line into a local interactive page that steers the reviewer's eyes — modules ranked into must-look / skim / noise by contract changes and blast radius, and changed UI components rendered before and after on mock data with a flip, side-by-side and curtain viewer. Default scope is the current branch, commits and working tree together; also takes a branch, a range, or someone else's MR/PR by number or URL. Load when the user asks to show what changed, map or visualise a diff or an MR, see the UI before and after, or says a change is too big to review — «покажи, что поменялось», «карта изменений», «визуальный дифф». Read-only towards the project. Explaining why belongs to change-debrief, hunting bugs to review-flow. Stack-agnostic; real renders on Storybook or Vite, sketches elsewhere.
---

# Change map

A **map**, not a story and not a verdict. The reader owns or reviews a change they cannot read line by line, and the map tells them where to put their eyes: which modules carry weight, who depends on them, and what the UI looks like now against before.

Its value is that it is **true**. Every module's rank names the signal behind it, and every UI picture is either a **render** — the real component, built from real code — or a **sketch** the agent drew, labelled as one in the page. A map that flatters the change is worse than no map, because the person reading it came here to catch what the author — often an agent — got wrong.

**Read-only towards the project.** Everything is written under the repository's git directory, so nothing can be committed, plus throwaway worktrees in the system temp directory, removed before the run ends.

Neighbours: why the work was done → `change-debrief`. Defects → `review-flow`. Surface a broken thing in one line, name the skill, carry on mapping.

## 1. Resolve the scope

First match wins:

1. **Nothing named** → the current branch against its base, commits **and** the working tree. Base as `change-debrief` §1 resolves it; diff with three dots.
2. **A branch or a range** → that diff, no working tree.
3. **An MR/PR** (number or URL) → someone else's change. Read its source and target branches from the forge CLI the session has (`glab mr view`, `gh pr view`), fetch the head without checking it out (`git fetch origin merge-requests/<iid>/head` on GitLab, `pull/<n>/head` on GitHub), and diff `origin/<target>...FETCH_HEAD`. The user's checkout stays untouched: both sides that need building come from temp worktrees (`references/render.md`).

Nothing changed → say so and stop.

The output folder `<map>` is `$(git rev-parse --absolute-git-dir)/change-map/<slug>/` — the git directory, never a literal `.git`, which is a file inside a linked worktree. `<slug>` is the branch name with `/` turned into `-`, `mr-<iid>` for an MR, the short head sha for a range or a detached head. Copy [`assets/viewer.html`](assets/viewer.html) to `<map>/index.html`; the page reads `data.js` next to it.

**Done when:** the base commit, the head (with or without the working tree), and `<map>` are fixed.

## 2. Rank the modules

A **module** here is the unit a reviewer thinks in: the project's own module folder when it has one (FEOD `modules/*`, a package in a monorepo, a Qt library), otherwise the changed file.

For each changed module, collect the **signals**:

- **Contract** — what its users see changed: exports and public API, function and component signatures, props, DTOs and types crossing the boundary, DB schema and migrations, routes, events, config keys. Capture it as **before → after**, the declaration only, a few lines each.
- **Blast radius** — who imports it. Take the graph from the tool the project already has: `.dependency-cruiser.*` → `depcruise`, `madge` in `package.json` → `madge`, a `code-review-graph` MCP server → its impact query. None of them → grep for imports of the module's public path. Record the consumer list and its count.
- **Risk zone** — auth, sessions, permissions, money, migrations, crypto, input crossing a trust boundary.
- **Noise** — lockfiles, build output, snapshots, generated code (`.gitattributes` `linguist-generated`), pure renames and formatting, changes that touch only tests. Read noise through `--stat` only.

The signals propose a tier; your judgement settles it. A module you move off its proposed tier — a one-line contract change nobody can misuse, a risky refactor with no signal — says why in its `why`.

- **must** — a contract changed with consumers outside the module, or a risk zone was touched. At most **ten**. More than ten → the ten with the widest blast radius stay, the rest drop to skim, and `split` says how many dropped and that this change is too wide to review as one piece.
- **skim** — changed behaviour inside a module whose contract held.
- **noise** — the list above.

Each must and skim module gets a `why` — one line naming its signal: "CartItem props gained discount; 14 consumers", not "important change".

**Done when:** every changed file belongs to exactly one module, every module has a tier, and every must and skim module has a `why` naming a signal.

## 3. Pick the UI pieces

Skip this step when no UI file changed: components, templates, styles, QML.

A **UI piece** is a changed component that renders on its own. List each with the screens it shows up on — walk the import graph up to route or page files (FEOD `pages`, a file-based router's path) — and the **states** the diff touched: a changed `isError`, `isEmpty`, `loading` branch earns its state; the default state is always in.

Show the list to the user before rendering anything: pieces, states, screens, and which rung each will take (step 4). Rendering is the expensive part, and the user prunes it here.

**Done when:** the user approved the list of pieces and states.

## 4. Render before and after

Take each piece down this ladder; the first rung that works wins:

1. **Storybook** — the project has Storybook → our own story per piece and state on the shared mocks, built with the project's Storybook setup on both sides.
2. **Vite harness** — the project builds with Vite → our own entry per piece and state, mounting the real component alone on the shared mocks inside the app's providers, built by the project's Vite config on both sides.
3. **Sketch** — everything else (webpack without Storybook, Next, Qt, a component that needs a live store, a build that failed twice) → plain HTML and CSS drawn from the old and new code and the project's tokens.

Rungs 1 and 2 produce a **render**; rung 3 produces a **sketch**. The words are exact: a sketch is never called a render, and its `note` says why the piece fell to it ("needs useCartStore with live queries", "webpack build").

[`references/render.md`](references/render.md) is the recipe: the temp worktrees, mocks, providers, both harnesses, shooting with [`scripts/shoot.mjs`](scripts/shoot.mjs), and cleanup.

**Done when:** every approved piece has a picture for each side that existed (a new piece has no before, a removed one no after) and a kind, and every temp worktree is gone.

## 5. Write the data and open the page

Write `<map>/data.js`:

```js
window.CHANGE_MAP = {
  title: 'feature/cart-discounts',
  base: 'origin/dev @ 3f2a91c',
  head: 'feature/cart-discounts @ 8b0d4e2 + working tree',
  summary: 'One line on what this change touches, by meaning.',
  split: null, // or the warning from step 2 when must overflowed
  modules: [{
    id: 'cart-item', name: 'CartItem', path: 'src/modules/cart/item',
    tier: 'must', // 'must' | 'skim' | 'noise'
    why: 'CartItemProps gained discount; 14 consumers', // plain text, the page renders no markdown
    contract: { before: 'type CartItemProps = { item: Item }', after: 'type CartItemProps = { item: Item; discount?: Money }' },
    consumers: ['src/pages/cart', 'src/modules/checkout/summary'], consumersTotal: 14,
    diff: '@@ -1,4 +1,6 @@\n…', // the unified diff of this module, read in this run
  }],
  screens: [{
    id: 'cart-item', name: 'CartItem', usedOn: ['/cart', '/checkout'],
    kind: 'render', // 'render' | 'sketch'
    note: 'Mocks: mocks/cart-item.default.json',
    states: [{ name: 'default', before: 'shots/cart-item.default.before.png', after: 'shots/cart-item.default.after.png' }],
    diff: '…', // markup and style hunks of this piece
  }],
};
```

`consumers` lists up to ten; `consumersTotal` keeps the real count. Noise modules carry `id`, `path` and `tier` only. Text the human reads — `summary`, `why`, `note`, `split` — is in the language the user speaks to you; code, paths and identifiers stay as they are.

Open `<map>/index.html` in the user's browser (`start` on Windows, `open` on macOS, `xdg-open` on Linux), then answer in chat with three lines: the path, the counts per tier, and how many pieces are renders against sketches. When the session can publish a page with its files — a Claude Artifact, say — offer that as a second home; the local page stays the default.

**Done when:** the page opens and every module and piece from steps 2–4 is in it.

## Boundaries

- Every `why`, contract and consumer comes from files and commands run in this session.
- A sketch is labelled as a sketch, in the data and in the page.
- The project's working tree and checked-out branch end exactly as they started; the only writes are under `<map>` and the temp worktrees.
- Two live dev servers, logins, pixel-diff overlays and dependency-graph pictures stay out: the ladder in step 4 is the whole UI story.
