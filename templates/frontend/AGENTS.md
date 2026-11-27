## Frontend

The architecture above, on the web: `frontend-mvvm`. Its §1 table sends you to the framework's file. Levels and roles are enforced by lint from `frontend-boundaries`.

### Toolchain: Vite+

`vp` runs the project: `vp install`, `vp dev`, `vp check` (Oxfmt, Oxlint, type-check of `.ts`), `vp test` (Vitest), `vp build`. The toolchain's configuration lives in `vite.config.ts` (`defineConfig` from `vite-plus`): `lint`, `fmt`, `test`, and a `staged` block (`'*': 'vp check --fix'`). `.vite-hooks/pre-commit` runs `vp staged`, then `vp run typecheck` when the framework needs a type-check `vp check` cannot do. `vp config` keeps its own block in this file and leaves the rest as it is.

Oxfmt follows antfu's style, and both tools skip installed agent assets:

```ts
fmt: {
  singleQuote: true,
  semi: false,
  ignorePatterns: ['.agents/**', '.claude/**', '.codex/**', '.cursor/**', 'skills-lock.json'],
},
```

Formatting is Oxfmt and linting is Oxlint. From the `antfu` skill, its ESLint config, `antislop` setup and `ci` script do not apply here; its other conventions do: explicit imports, explicit return types, pnpm with named catalogs, a test file beside its source with `describe` / `it`.

### Lint

Start the `lint` block from `frontend-boundaries`' oxlint `boundaries` object (FEOD levels, role matrix, `export *` in `index.ts`), typed as `OxlintConfig` from `vite-plus/lint`, then add antfu's import rules and his antislop rules through Oxlint JS plugins:

```ts
lint: {
  ...boundaries,
  plugins: ['typescript', 'unicorn', 'oxc', 'import', 'vitest'],
  jsPlugins: [...(boundaries.jsPlugins ?? []), 'eslint-plugin-antfu', 'eslint-plugin-slop'],
  ignorePatterns: ['.agents/**', '.claude/**', '.codex/**', '.cursor/**'],
  options: { typeAware: true, typeCheck: true },
  rules: {
    ...boundaries.rules,
    'import/no-duplicates': 'error',
    'antfu/import-dedupe': 'error',
    'antfu/no-import-dist': 'error',
    'antfu/no-import-node-modules-by-path': 'error',
    'slop/no-em-dash': 'error',
    'slop/max-comment-length': 'error',
    'slop/no-chained-type-assertions': 'error',
    'slop/no-jargon': 'error',
    'slop/no-trivial-functions': 'error',
    'slop/no-trivial-type-aliases': 'error',
  },
},
```

`eslint-plugin-sonarjs`, the other half of antfu's antislop, fails to load in Oxlint (vite-plus 1.8.0, 2026-11-25); Oxlint's native `eslint/no-dupe-else-if` and its correctness rules cover part of it.

### Tests

`vp test` with jsdom and the framework's Testing Library. Storybook only in a UI library, with `@storybook/addon-vitest` so stories run in `vp test`.

Four test skills, each answering one question:

- `test-craft`: what a test asserts and what it leaves alone.
- `testing` (siberiacancode): conventions of a unit test, and Playwright integration tests derived from test cases. Before writing tests, its `rules/unit-test-analyze.md` and `rules/integration-test-analyze.md` plan the coverage. In a project with no tests yet, its defaults set the shape: `Should <observable behavior>` names, repeated cases through `forEach`. Its React rules apply only to React subjects.
- `vitest`: the runner's API.
- The framework file: how its subjects are mounted and tested.

Flows that need real navigation are Playwright browser tests; everything below that runs in `vp test`.

### Skills

| Area | Skill |
| --- | --- |
| Architecture on the web; lint for levels and roles | `frontend-mvvm`, `frontend-boundaries` |
| Tooling conventions; Vite; Vitest; pnpm | `antfu`, `vite`, `vitest`, `pnpm` (from `antfu/skills`) |
| Test conventions, Playwright integration, coverage planning | `testing` (from `siberiacancode/agent-skills`) |
| Improving an interface, or a new one | `design-flow` with `jakubkrehel/skills` and `Leonxlnx/taste-skill` |

```bash
npx skills add ScobarDen/scobar-skills --skill frontend-mvvm frontend-boundaries design-flow
npx skills add antfu/skills --skill antfu vite vitest pnpm
npx skills add siberiacancode/agent-skills --skill testing
npx skills add jakubkrehel/skills
npx skills add Leonxlnx/taste-skill
```

Vite+ ships no user skill: its docs come from Context7 (`/voidzero-dev/vite-plus`).
