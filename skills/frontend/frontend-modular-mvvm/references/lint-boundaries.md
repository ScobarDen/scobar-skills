# Lint boundaries for roles and levels

The role suffixes from `SKILL.md` §3 exist so these globs work. Every import boundary is `no-restricted-imports` with a `regex` pattern matched against the import specifier, and ESLint and oxlint read the same options; `max-lines` and the `export *` ban ride along. Both configs were run on fixtures for every row with oxlint 1.83 and ESLint 10.11 (2026-09-23; ESLint without a TS parser, so its `allowTypeImports` is taken from the rule's source).

## The matrix

This table is the single source of truth. Both configs below implement it, so a change here is a change in both.

| Files under `src/` | Must not import (specifier ends in) | Why |
| --- | --- | --- |
| every file | `@/modules/<x>/…`, `@/common/<x>/…` | deep import past a public `index.ts` |
| every file except `.api`, `.dto` and tests | `.dto` | raw backend shapes stop at `.api`, re-exports from `index.ts` included |
| `*.view.{ts,tsx,vue}` | `.api`, types included | the View binds VM output and never sees transport |
| `*.vm.ts` | `.view`; `.api` values (types pass) | the VM does not know how it is drawn, and it reaches transport through `.model` or an injected function (DI in `frontend-mvvm`) |
| `*.model.ts` | `.vm`, `.view` | the Model is below the VM |
| `*.api.ts` | `.vm`, `.view` | transport is below the VM |
| `index.ts` | `export *` | the contract is explicit named exports |
| every file | `max-lines` 200 as `warn`, tests 500 | a prompt to name the file's responsibilities |

Adjust `src/` and the `@/` alias to the project's. Where `@feod/analyzer` checks levels, drop the deep-import pattern.

## How overrides combine

Both linters apply overrides in order, and per rule the last matching one wins: its options replace the earlier ones for that file instead of merging. Two consequences:

- Each role override repeats the base patterns (deep import, `.dto`) and adds its own. The ESLint helper does it; the oxlint JSON spells it out.
- A rule the later override does not mention survives. `max-lines` from the base stays on a `.vm.ts` whose `no-restricted-imports` was replaced.

A project boundary whose glob overlaps a role glob obeys the same law. A host rule for `*.web.view.tsx` that lists only `react-native` silently drops the View's `.api` / `.dto` patterns for web views; write it with the View's patterns plus its own, after the View override:

```js
{ files: ['src/**/*.web.view.{ts,tsx}'], rules: restrict(role('api', 'dto'), { group: ['react-native', 'react-native/*'] }) },
```

A pure-domain rule (`*.model.ts` imports no packages) or "pages never import `x`" is the same shape with its own glob.

`max-lines` as `warn` fails a build that treats warnings as errors (vite-plus `denyWarnings`, `eslint --max-warnings 0`). There, keep it out of CI and run it in review.

## ESLint (flat config)

Merge into the project's flat config: `.ts` files need its TypeScript parser (typescript-eslint), `.vue` files `vue-eslint-parser`, and `allowTypeImports` reads the type-import marks the TS parser sets.

```js
const ext = String.raw`(\.([cm]?[jt]sx?|vue))?$`
const role = (...roles) => ({
  regex: String.raw`\.(${roles.join('|')})` + ext,
  message: 'Crosses a role boundary.',
})
const deepImport = {
  regex: '^@/(modules|common)/[^/]+/.+',
  message: 'Import the entity root, not its insides.',
}
const restrict = (...patterns) => ({
  'no-restricted-imports': ['error', { patterns: [deepImport, ...patterns] }],
})
const maxLines = (max) => ({
  'max-lines': ['warn', { max, skipBlankLines: true, skipComments: true }],
})

export default [
  { files: ['src/**/*.{ts,tsx,vue}'], rules: { ...restrict(role('dto')), ...maxLines(200) } },
  { files: ['src/**/*.test.{ts,tsx}'], rules: { ...restrict(), ...maxLines(500) } },
  {
    files: ['src/**/index.ts'],
    rules: {
      'no-restricted-syntax': ['error', { selector: 'ExportAllDeclaration', message: 'Name each export.' }],
    },
  },
  { files: ['src/**/*.dto.ts'], rules: restrict() },
  { files: ['src/**/*.api.ts'], rules: restrict(role('vm', 'view')) },
  { files: ['src/**/*.model.ts'], rules: restrict(role('vm', 'view', 'dto')) },
  { files: ['src/**/*.vm.ts'], rules: restrict(role('view', 'dto'), { ...role('api'), allowTypeImports: true }) },
  { files: ['src/**/*.view.{ts,tsx,vue}'], rules: restrict(role('api', 'dto')) },
]
```

## oxlint

`.oxlintrc.json`, or the `lint` block of `vite.config.ts` under vite-plus. oxlint parses TypeScript and the script of `.vue` files on its own. It has no selector-based `no-restricted-syntax`, so `export *` stays a review item there (`SKILL.md` §9).

```json
{
  "overrides": [
    {
      "files": ["src/**/*.{ts,tsx,vue}"],
      "rules": {
        "max-lines": ["warn", { "max": 200, "skipBlankLines": true, "skipComments": true }],
        "no-restricted-imports": ["error", { "patterns": [
          { "regex": "^@/(modules|common)/[^/]+/.+" },
          { "regex": "\\.dto(\\.([cm]?[jt]sx?|vue))?$" }
        ] }]
      }
    },
    {
      "files": ["src/**/*.test.{ts,tsx}"],
      "rules": {
        "max-lines": ["warn", { "max": 500, "skipBlankLines": true, "skipComments": true }],
        "no-restricted-imports": ["error", { "patterns": [
          { "regex": "^@/(modules|common)/[^/]+/.+" }
        ] }]
      }
    },
    {
      "files": ["src/**/*.dto.ts"],
      "rules": {
        "no-restricted-imports": ["error", { "patterns": [
          { "regex": "^@/(modules|common)/[^/]+/.+" }
        ] }]
      }
    },
    {
      "files": ["src/**/*.api.ts"],
      "rules": {
        "no-restricted-imports": ["error", { "patterns": [
          { "regex": "^@/(modules|common)/[^/]+/.+" },
          { "regex": "\\.(vm|view)(\\.([cm]?[jt]sx?|vue))?$" }
        ] }]
      }
    },
    {
      "files": ["src/**/*.model.ts"],
      "rules": {
        "no-restricted-imports": ["error", { "patterns": [
          { "regex": "^@/(modules|common)/[^/]+/.+" },
          { "regex": "\\.(vm|view|dto)(\\.([cm]?[jt]sx?|vue))?$" }
        ] }]
      }
    },
    {
      "files": ["src/**/*.vm.ts"],
      "rules": {
        "no-restricted-imports": ["error", { "patterns": [
          { "regex": "^@/(modules|common)/[^/]+/.+" },
          { "regex": "\\.(view|dto)(\\.([cm]?[jt]sx?|vue))?$" },
          { "regex": "\\.api(\\.([cm]?[jt]sx?|vue))?$", "allowTypeImports": true }
        ] }]
      }
    },
    {
      "files": ["src/**/*.view.{ts,tsx,vue}"],
      "rules": {
        "no-restricted-imports": ["error", { "patterns": [
          { "regex": "^@/(modules|common)/[^/]+/.+" },
          { "regex": "\\.(api|dto)(\\.([cm]?[jt]sx?|vue))?$" }
        ] }]
      }
    }
  ]
}
```
