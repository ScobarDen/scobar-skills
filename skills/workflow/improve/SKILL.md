---
name: improve
description: Prioritized, read-only improvement advice for a feature, module, path or the current branch's diff — quick wins versus deeper refactors, each with a why, a before→after snippet and effort/impact/risk. Treats simplification as a first-class lens: hunts places where a verbose block collapses to a fraction of its size. Builds the project's effective rulebook by priority and speaks in the architecture the project actually uses. Load when the user asks to improve, simplify, clean up, refactor, tidy, "make this nicer", "what's wrong with this code", "как это упростить". Not a bug hunt and not an automatic rewrite — advice first, edits only when asked. Stack-agnostic.
---

# Improve

Given a feature, a module, a path, or just "what I've been writing" — produce a prioritized set of concrete improvements. Each one gets a reason, a `before → after` snippet and an honest cost.

**Advisory by default.** Read, judge, report. Applying the suggestions is a separate decision the user makes after seeing them — and when they do say "apply", apply only what they picked, not the whole list.

**This is not a review.** Reviews hunt defects; this hunts better shapes for code that already works. A real bug you trip over gets one line ("also: `foo.ts:42` drops the error"), not a findings section.

## 1. Resolve the scope

- An explicit path, module, feature or symbol → that.
- Nothing explicit → the current branch's own diff:
  ```sh
  git diff --name-only <base>...HEAD
  ```
  with `<base>`: what the user named → `origin/dev` / `origin/develop` if either exists → `origin/HEAD` → `origin/main` / `origin/master`. That reading of an empty request is "improve what I just wrote", which is almost always what it means.
- Diff empty too, and no scope given → say there's nothing to look at and stop. Don't go browsing the repo for something to criticise.

Don't ask clarifying questions. Decide from what's there; if the scope genuinely can't be located, say which name you looked for and stop.

## 2. Build the rulebook — strict priority order

Advice measured against the wrong rules is noise. Discover the project's *effective* rules before judging anything, and **the higher source wins on conflict**. Where a suggestion enforces a rule, name the rule.

1. **The project's own rules.** `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` at the root *and* nested ones deeper in the tree, `.cursorrules`, `.cursor/rules/**`, `.windsurfrules`, `.github/copilot-instructions.md`, `CONTRIBUTING.md`, the dev section of `README`, `.editorconfig`, and the linter/formatter/compiler configs the project actually runs (ESLint, Prettier, Biome, Ruff, Black, clang-format, clang-tidy, golangci-lint, RuboCop, ktlint, `tsconfig.json`, `.clang-tidy`, `pyproject.toml`, `Cargo.toml` lints, `.editorconfig`).
2. **The project's own skills and agents** — `./.claude/skills/*/SKILL.md`, `./.claude/agents/*`, or the equivalent for whatever harness is in use. These are the conventions the team wrote down for itself.
3. **Installed skills matching the detected stack.** Detect the stack from the repo — manifests, lockfiles, file extensions, imports, config files — and load the skills that match it *before* judging code written in it. A Vue project's advice comes from the Vue skill, not from general instincts about components; a Qt project's from the Qt skill; a test file's from the test-runner skill. Read the ones the stack actually uses and no others.
4. **The base floor, always in effect.** SOLID, KISS, YAGNI, DRY, separation of concerns, Law of Demeter, composition over inheritance, fail fast, principle of least astonishment, high cohesion / low coupling, the Boy Scout rule — plus declarative call sites (§4).

A conflict between levels is worth one line in the report. The project's convention beating a general principle is the correct outcome, not a finding.

## 3. Detect the architecture — never impose one

Read the real structure and name units the way the project names them:

| Signals | Architecture → unit vocabulary |
| --- | --- |
| `src/{app,pages,widgets,features,entities,shared}` | Feature-Sliced Design → layer + slice |
| `src/modules/*`, `*.module.ts`, per-feature folders with a public entry point | Modular / feature-based → module |
| `domain/application/infrastructure`, `controllers/services/repositories`, ports & adapters | Layered / Clean / Hexagonal → layer |
| `packages/*`, `apps/*`, `libs/*` + a workspace config | Monorepo → package / app |
| `models/views/controllers`, flat role folders | MVC / classic → folder role |
| a CMake/Bazel/Gradle tree of libraries with explicit deps | Component graph → target |
| none of the above | Infer from reality; use the project's own words |

**An architecture the project doesn't use is not a finding.** "This should be FSD" is not advice, it's a rewrite proposal wearing advice's clothes.

## 4. Declarative call sites

A reader should get what a call does from its name and arguments alone, without opening the callee. This bites only where the parameter name is **invisible at the call site** — positional arguments. Named forms (keyword arguments, object fields, template props, builders) are already declarative; never report those.

| Smell | The shape to suggest |
| --- | --- |
| `setContent(node, true)` — a positional flag that switches behaviour | an options object, a `'replace' \| 'append'` mode, or two functions |
| `retry(3, 500, true)` — magic literals, no names in sight | named parameters / an options object |
| `handleData()`, `processItem()`, `DataManager` — names describing machinery, or nothing | names stating the observable result: `normalizeInvoice()`, `hasUnpaidInvoices`, `canEditOrder` |
| `retryWithBackoffLoop()` — the algorithm leaking into the name | `fetchWithRetry()`: *what* it achieves; *how* stays inside |
| `isLoading` + `isError` + `isEmpty` side by side on the project's own type or state | one `status` union — impossible states stop existing |
| nested conditionals on the way to the happy path | guard clauses, early return, one level of abstraction per function |

- A boolean that **is** the data is fine — `setVisible(true)`, `checked: true`. Only an argument that *selects a branch of behaviour* (`force`, `silent`, `recursive`, `override`) qualifies.
- The union rule covers the project's **own** domain types and state — never the return shape of a third-party library. Suggesting a wrapper just to comply is a false positive.
- Where the codebase passes flags positionally everywhere, note the pattern **once**. It's the lowest-priority source, so the project's consistency wins.
- Only inside your scope, and only where the fix is the scope's to make. A callee the scope doesn't own has other callers; reshaping it is out.

## 5. Read enough to be right

- Prefer **whole files** over hunks. A diff read without its surroundings is how you invent a problem the untouched half of the file already solves.
- **Cap around 12 files read in full.** Hit the cap → say so in the report. An unreported cap turns a partial read into a clean bill of health.
- Glance at the neighbours — an adjacent module or slice, the configs from §2 — so the advice matches how this project writes code, not how code could be written in general.
- Cross-reference imports and public entry points wherever the scope crosses a boundary. That's where the expensive suggestions live.

## 6. Dimensions

Judge holistically unless the user narrowed it ("performance only", "just the types"):

readability · structure and cohesion (SRP, coupling, layering violations) · **simplification** · types and type safety · error handling · performance · duplication · dead code · naming · testability · consistency with the project's conventions.

### Simplification is a first-class lens

Actively hunt places where a long block shrinks to a fraction **without losing behaviour or clarity**:

- hand-rolled loops that are one built-in (`map`/`filter`/`reduce`, comprehensions, `std::ranges`, LINQ)
- reinvented helpers that already exist in the project or in a dependency it already ships
- ceremony with one caller: wrappers around wrappers, a config object for a single call site, an interface with one implementation and no seam behind it
- deeply nested conditionals collapsing into early returns or a lookup table
- boilerplate a language or framework idiom removes outright
- state that is derivable and therefore shouldn't be stored

When you find one, quantify it: *"≈60 lines → ≈15"*. And keep the direction straight — shorter is a **means**. Never trade real readability, a needed extension seam, or an explicit error path for raw brevity, and say so when a tempting collapse would cost one of those.

### Unexplained warning suppression

An `eslint-disable`, `@ts-ignore`, `# noqa`, `#pragma warning disable`, `@SuppressWarnings`, `#[allow(...)]`, or a rule switched off in config, with no reason recorded on the line above, after the tool's own reason separator, or in the config entry — that's a tool catching something real and the code silencing it with no record of why. Mention it in one line; where the underlying warning looks fixable, say that fixing the cause beats explaining the mute.

## 7. Report

```markdown
# Improvements: <scope>

> Architecture: <detected> · location: <path> · files read: <N>[ · cap reached]

## Summary
Overall health in one to three sentences.

## Health snapshot
| Dimension | State | Note |
| --- | --- | --- |
| <only the dimensions you actually judged> | 🟢 / 🟡 / 🔴 | ... |

## ⚡ Quick wins

### <title> · impact: high/med · cost: low · risk: low/med
Why it helps, in one or two lines.
`before → after` snippet.

## 🏗️ Deeper refactors

### <title> · impact: high/med · cost: high/med · risk: low/med
Why, the trade-off, and a representative `before → after`.

## Order to tackle it
1. What first, and why — dependency, risk, or payoff order.

## Cover with tests first
- What could break, and what should be under test before anything is touched.
```

- Snippets stay code — real identifiers from the project, in its language and style. Comments in a snippet only where they mark what changed.
- Point with `path:line`. Don't paste whole files.
- **Clean code gets a short report.** "This is already in good shape, here are two nits" is a complete and useful answer. Padding a report to look thorough is the single worst failure mode of this skill.
- Language of the report follows the harness's own instructions (`AGENTS.md` / `CLAUDE.md` / chat). This skill doesn't override it.

## What NOT to do

- ❌ Don't edit code as part of the analysis. Advise first; apply only what the user picks.
- ❌ Don't run tests, lint, build, or anything that mutates the tree.
- ❌ Don't propose a wholesale rewrite. Incremental steps that each leave the code working.
- ❌ Don't invent problems to fill the report, and don't restate the scope for its own sake — mention only code you have something to say about.
- ❌ Don't impose an architecture, a state manager, or a library the project didn't choose.
- ❌ Don't file bugs here. One line, then keep advising.
- ❌ Don't judge code you didn't read.
