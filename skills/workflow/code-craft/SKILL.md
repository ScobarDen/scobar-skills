---
name: code-craft
description: Naming, signatures, state shape, function shape and file placement, decided while writing code. Load when naming something, designing or extending a signature, a second boolean argument or a third flag for one state appears, a function outgrows a screen, choosing where new code goes, or asked "what should I call this" / "is this signature ok". Not for judging code that already exists — that is refactor-advice.
---

# Code craft

The handful of decisions that decide whether this code is readable in six months. All of them are made **while writing**, and none of them get cheaper afterwards.

**Done when:** every new name, signature, state shape, function and file placement in your change has been checked against the sections below.

## When it doesn't

- Judging code that already exists → **`refactor-advice`**.

## The project wins

Read how the neighbours in this repo already do it and follow that. A convention you'd have chosen differently, applied consistently, beats a better idea applied in one file. Everything below is the default for where the project has no opinion. Where the project's stated convention disagrees with this file, follow the project and say so in one line.

## Pairs with ponytail

When [`ponytail`](https://github.com/DietrichGebert/ponytail) is installed (`npx skills add DietrichGebert/ponytail`), load it too: it decides **how much** code to write — the smallest complete change, at its default `full` level — and this file decides **the shape** of what remains. Its `shortcut: <limit>, <when to upgrade>` marker is a legitimate why-comment.

## Names state the result, not the machinery

A reader should get what something does from its name, without opening it.

| Instead of | Write |
| --- | --- |
| `handleData()`, `processItem()`, `doStuff()` | what it achieves — `normalizeInvoice()`, `applyDiscount()` |
| `DataManager`, `Helper`, `Utils` | the thing it owns — `InvoiceRepository`, `PriceFormatter` |
| `retryWithBackoffLoop()` | `fetchWithRetry()` — *what* it achieves; *how* stays inside |
| `flag`, `tmp`, `data2`, `x` | the thing it holds — `isExpired`, `draftInvoice` |
| `check(user)` returning a boolean | `isActive(user)`, `hasUnpaidInvoices(user)`, `canEditOrder(user)` |

- Booleans read as a question: `is` / `has` / `can` / `should`.
- Length is not the goal; a name that needs a comment to be understood is the one to change.
- One concept, one word, across the whole codebase. `fetch`, `load`, `get` and `retrieve` meaning the same thing in four files is four times the reading cost. Different meanings keep different words; where the project and its stack skill have none yet: `get` reads what is already in memory, `fetch` crosses an I/O boundary and returns the result, `load` fetches into state the caller then reads.
- A helper generic over the operation is named for what it adds: `retry(operation, policy)`. `fetchWithRetry` is the name only when it fetches.
- Spell words out; abbreviate only what the domain already abbreviates. `usr`, `cnt`, `mgr` save four characters and cost a lookup.

## Signatures make the argument's meaning visible

The rule bites where the parameter's name is **invisible at the call site** — positional arguments. Named forms are already fine: keyword arguments, object fields, template props, builders. Nothing to fix there. The examples below are TypeScript; "options object" means whatever named form the language has: an object literal, keyword arguments, a struct or record literal, a builder.

| Call site | The problem | Write instead |
| --- | --- | --- |
| `setContent(node, true, false)` | two flags, zero names, and you can't tell which is which | `setContent(node, { override: true, silent: false })` |
| `setContent(node, true)` | one flag that switches behaviour | a `'replace' \| 'append'` mode, or two functions — `replaceContent` / `appendContent` |
| `retry(3, 500, true)` | magic literals with no names in sight | `retry({ attempts: 3, delayMs: 500, jitter: true })` |
| `createUser(name, email, true, null, 2)` | five positionals is a struct wearing a trench coat | one options object, or a builder |

- **Mode value or two functions.** Two functions when each call site always takes the same branch; a mode value when the choice is data that travels — from config, user input or a stored record.
- **A boolean that *is* the data is fine.** `setVisible(true)`, `checked: true`, `setEnabled(false)` — nothing to fix. Only an argument that **selects a branch of behaviour** (`force`, `silent`, `recursive`, `override`, `replace`) qualifies.
- Two positionals of the same type in a row is a bug waiting to happen — `transfer(accountA, accountB)` reads fine until someone swaps them. Name them, or take a single object.
- Magic literals at a call site get a named constant, even when the signature is fine.
- **Three or more parameters is a signal**, not a violation. Ask whether they are really one concept.
- A **structural prop** — a prop that shows, hides, replaces or rearranges a part of a UI component (`showFooter`, `renderHeader`) — is the same flag at the component level: split the component into a compound (a root plus flat named parts the caller assembles), as `frontend-mvvm` §7 shows on the web (`npx skills add ScobarDen/scobar-skills --skill frontend-mvvm`). A slot that takes the caller's content (`children`, a named slot) is that composition already, not a structural prop.

## One union beats a constellation of booleans

`isLoading` + `isError` + `isEmpty` sitting side by side on your own type, state or props means impossible states are representable — loading *and* error at once, and now every reader has to work out which combinations are real.

```
status: 'idle' | 'loading' | 'ready' | 'empty' | 'error'
```

The impossible states stop existing, and the exhaustiveness check does the reminding for you.

Spell it as the language's closed set of variants, data on each: a literal or discriminated union in TypeScript, a sealed class in Kotlin and Java, an enum with payloads in Rust and Swift, a union of dataclasses tagged by a `Literal` field in Python. Where the compiler has no exhaustiveness check (Go: a typed constant set or an interface with one type per variant), every `switch` over it gets a `default` that fails loudly.

- Applies to the project's **own** domain types, state and props. Never to the shape a third-party library hands back — wrapping a library's return just to comply is worse than the flags.
- Carry the data on the variant that has it (`{ status: 'error', error }`) rather than in a parallel field that is meaningless in four states out of five.
- **Don't store what you can derive.** A field that is always `items.length === 0` is a second source of truth for the same fact. The `empty` variant above is such a case: store the loaded items, and derive `empty` where you build the state its reader gets.

## Shape of a function

- **Guard clauses first.** Handle the impossible cases up front and return; the happy path stays at one indent level instead of being buried three deep.
- **One level of abstraction per function.** Orchestrating steps and doing byte-level work in the same body is what makes a function hard to skim.
- **One job.** If describing what it does needs an "and", that's two functions.
- Prefer a short function whose name you can say out loud over a long one with section-banner comments inside it. Those banners are the extraction points.
- Fail fast and loudly. A swallowed error is a bug that surfaces somewhere else, at a worse time, without a stack trace.

## Where the code goes

- **Mirror the neighbours.** Find the closest existing thing of the same kind and match its directory, file naming, internal structure and registration. Consistency here is worth more than any layout you'd argue for in the abstract.
- **A new kind of folder is the user's call.** A `services/` folder in a codebase with no services is a new convention: raise it, and put the code where the existing kinds of folder say until the user answers.
- **Dependencies point one way.** Whatever the project's direction is, don't be the first import that goes back up.
- New file or existing one — a file that has grown past what you can hold in your head is doing too many jobs. That's the signal to split, not the line count.
- A project with no layout of its own yet: **levels** (the five top-level folders `app`, `pages`, `modules`, `common`, `global`) and **modules** (a folder on the `modules` level holding one product responsibility, used from outside only through its public API) are **`feod`** with **`feod-preset`**, what each file inside a module owns is **`mvvm`** (a project with no UI gets a delivery — HTTP endpoints, a command, a queue consumer — where a screen would be), file names are **`role-files`**. A stack skill spells all of it for its stack (**`frontend-mvvm`** on the web); with none, `feod-preset`'s Stack spelling says how to spell it in the language's own idiom. Prerequisites: `npx skills add Sdju/feod`, and `npx skills add ScobarDen/scobar-skills --skill <name>` for `feod-preset`, `mvvm`, `role-files` and, on the web, `frontend-mvvm`. When any of them is missing from your skill list, stop before laying out files: give the user the install lines for the missing ones and wait for their answer.

## Two principles that get misapplied

- **DRY is about knowledge, not characters.** Two blocks that look alike but change for different reasons are not duplication. Don't abstract on the first repeat — wait for the third, when the shape of the abstraction is actually visible.
- **YAGNI beats an extension point you're imagining.** An interface with one implementation and no second caller in sight is ceremony, not flexibility.

## Scope

- Rename only symbols inside the scope you were given — other callers depend on the rest.
- Neighbouring code that breaks these rules gets one line in your final message, at most.
