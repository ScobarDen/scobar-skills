---
name: frontend-modular-mvvm
description: Where frontend code lives and what its files are called — FEOD levels, a public `index.ts` per module, `{subject}.{role}.ts` names that grow into role folders. Load when placing or naming a frontend file, creating a module or screen, a file or module too big to navigate, splitting into submodules, writing `index.ts`, migrating from FSD, or setting up lint boundaries between roles. What each MVVM role owns is frontend-mvvm.
---

# Frontend modular MVVM

Two cuts through one codebase:

- **Levels** answer *where does it live and who may import it*. Taken from FEOD.
- **Roles** answer *who is responsible for what* inside one module. Taken from MVVM (`frontend-mvvm`).

The goal is a module you understand from its file list: open the folder, read the names, know what happens and where.

## Provenance and precedence

- Levels, public API and submodule rules: [FEOD](https://fractal-oriented.tech/llms-full.txt) (Fractal Entity Oriented Design). FEOD says nothing about MVVM; the roles, the file suffixes and the lint rules are this skill's own addition.
- Suffix choice weighed against the [Angular style guide](https://angular.dev/style-guide), which dropped `.component`/`.service` as decoration, and NestJS, which keeps them. Here the suffix stays because tooling keys off it: lint globs enforce role boundaries and `Ctrl+P checkout.vm` finds the file.
- **Project conventions win.** An existing layout, naming scheme or file-based router outranks everything below. Follow it and mention the divergence in one line.
- What each role owns (Model / ViewModel / View, facade, mediator, DI) is **`frontend-mvvm`**. Library wiring is `reatom` / `mobx-mvvm`. Qt Quick has its own sibling: `qt-modular-mvvm`.

## 1. Levels

| Level | Holds | May import |
| --- | --- | --- |
| `app/` | entry, bootstrap, providers, router, composition root | `pages`, `modules`, `common` |
| `pages/` | screens and routes: mount modules, pass their dependencies | `modules`, `common` |
| `modules/` | product scenarios and the domain; most of the code | `common`, other modules' public API, own submodules' public API |
| `common/` | neutral technical and UI entities with no product meaning | other `common` entities' public API, packages |
| `global/` | polyfills, shims, `vite-env.d.ts`, global styles; wired by entry or bundler, imported by nobody | nothing |

- Five levels; a sixth is an architecture decision, not a folder. A page never imports another page.
- **Module or common?** Can you describe it without naming the product domain? Yes → `common`. No → a module. "Used in two places" is never the reason by itself.
- Names are domain nouns in kebab-case: `checkout`, `user`, `feature-flags`. `common` names state a neutral contract: `button`, `format-date`, `http-client`. `utils`, `helpers`, `shared`, `services`, `components`, `hooks` name no responsibility.

### Coming from FSD

FEOD's own migration mapping:

| FSD | FEOD |
| --- | --- |
| `app`, `pages` | `app`, `pages` |
| `shared` | `common` for neutral code, `global` for declarations and polyfills; code with product meaning goes to a module |
| `entities`, `features` | `modules`, grouped by responsibility: `entities/user`, `features/change-email` and `widgets/profile-card` can become one `user` module |
| `widgets` | a module when reused as a product unit, otherwise `pages` |
| segments `ui` `api` `model` `lib` `config` | role suffixes (§3) and role folders (§4) |

`modules/` groups by responsibility. A `modules/entities/` or `modules/features/` folder is FSD renamed, not migrated.

## 2. Public API

- A module's root `index.ts` is its contract: explicit named exports only. `export *` publishes whatever lands in the folder next.
- Outside code imports the module root (`@/modules/checkout`), never a file or a segment inside it. Type-only imports obey the same rule.
- Relative imports stay inside the module that owns both files.
- Names exported from `index.ts` are clean domain names: `Checkout`, `useCheckout`, `CheckoutProps`, `getOrderTotal`. The role lives in the file name; `CheckoutVM` or `CheckoutApi` on the public surface restates the folder. Inside the module, names follow the library's convention (mobx-view-model's `CheckoutVM` class).
- The owner exports its types. A consumer writing `ReturnType<typeof getOrderStatus>` or `Parameters<typeof placeOrder>[0]` is reverse-engineering a type the owner forgot to export.
- What crosses `index.ts` toward a View is VM output shaped for the UI: the facade rule of `frontend-mvvm`.

## 3. File names: `{subject}.{role}.ts`

Every file with a role carries it as a dot-suffix, kebab-case throughout (`checkout-form.view.tsx`, not `CheckoutForm.tsx`).

| Suffix | Role |
| --- | --- |
| `.model.ts` | Model: domain types, pure transforms, domain state |
| `.vm.ts` | ViewModel: orchestration, handlers, data shaped for this UI |
| `.view.tsx` / `.view.ts` / `.view.vue` | View: passive render of VM output |
| `.api.ts` | transport plus the DTO → domain adapter; with `.model`, the Model layer of `frontend-mvvm` |
| `.dto.ts` | raw backend shapes |
| `.route.ts` | route declaration; lives in `pages/` |
| `.config.ts` | constants, feature flags |
| `.types.ts` | types with no single owner file |
| `.lib.ts` | pure helpers internal to the module |
| `.test.ts` / `.stories.tsx` | as the runner requires |

The list is closed. A file that fits no role is a signal the module holds two responsibilities; a genuinely new role extends this table or the project README first. Which role may import which is a single matrix in [`references/lint-boundaries.md`](references/lint-boundaries.md).

- **Subject.** The file named after the module is the entry of its role: `checkout.vm.ts`, `checkout.view.tsx`. Every other file is named after its concept: `delivery-address.model.ts`, `promo-code.api.ts`. The path supplies the module; fuzzy search on `checkout promo` matches it.
- **Hosts.** A module rendered by several hosts adds the host before the role: `checkout.web.view.tsx`, `checkout.native.view.tsx`. The `*.view.*` glob still matches both.
- **Tests** sit next to the file they test and repeat its name: `checkout.vm.test.ts`. Past ~500 lines a test splits by behaviour, keeping the prefix: `order-total.model.discounts.test.ts`, `order-total.model.taxes.test.ts`.
- **Routes and pages.** `pages/<page>/<page>.route.ts` declares the route; `pages/<page>/<page>.view.tsx` mounts module roots and passes their dependencies. A module never knows the URL it is mounted at. A file-based router (Next, TanStack Router, React Router fs-routes) dictates its own file names; they win and `.route.ts` is not used.

## 4. Inside a module: one file or one folder per suffix

Count the files of each suffix in the module, tests and stories included (`checkout.vm.test.ts` counts as `.vm`):

- **One file** → it sits at the module root.
- **Two or more** → all of them move into a folder named exactly like the suffix: `model/`, `vm/`, `view/`, `api/`, `dto/`, `lib/`, `config/`, `types/`. They keep their suffix inside, because the suffix is what the lint globs and the search see.

```
modules/checkout/
  index.ts
  README.md
  checkout.api.ts
  checkout.dto.ts
  checkout.config.ts
  checkout.view.tsx
  model/
    checkout.model.ts
    delivery-address.model.ts
    order-total.model.ts
    order-total.model.test.ts
  vm/
    checkout.vm.ts
    checkout.vm.test.ts
```

The root then shows at a glance which roles are a single file and which have grown. Each suffix in a module is laid out one way: one file at the root, or every file of it in its folder.

A **submodule** appears when a part of the module gets its own reason to change: `modules/checkout/delivery/` with its own `index.ts` and the same one-file-or-folder layout. It sits directly in the parent folder and is visible outside only through the parent's `index.ts`. Nesting stays within two or three levels; deeper needs a written reason. A part with its own consumers and its own product responsibility is a separate module, not a submodule. Two files are too early for either.

**The line count is a prompt, the cut is by responsibility.** Past ~200 lines (tests ~500), name the responsibilities inside: one name keeps the file, several split it along their reasons to change (`code-craft`). A pricing file mixing promo codes, loyalty points and shipping fees, each tuned on its own, is three files at any length.

## 5. The View lives in its module

The module owns its whole pyramid, View included; `pages/` only mounts it. A page holding a module's markup splits the pyramid across two levels, so understanding the module means reading both.

On hooks, the component that calls the VM hook and renders the passive View (`frontend-mvvm`'s hooks adapter) is the module's root View: it lives in `checkout.view.tsx` and is what `index.ts` exports as `Checkout`.

A module rendered by several hosts keeps every host's View inside the module with a host suffix (§3). A headless module (Model and VM only, Views elsewhere) is a legitimate exception when it is decided, and the module README says so.

## 6. Module README

Required for every module with a ViewModel. Five to ten lines, because a long README rots:

```md
# checkout

Turns a cart into a placed order: address, delivery slot, payment.

- Injected: `cartSource`, `paymentClient` (from `app/`).
- Out of scope: cart editing (`cart`), order history (`orders`).
```

The exports are already in `index.ts`. The README carries what the tree cannot tell: why the module exists, what it receives, and where the neighbouring work lives instead.

## 7. Lint boundaries

A boundary the linter does not check lasts until the first deadline. The role matrix and copyable ESLint flat / oxlint configs are in [`references/lint-boundaries.md`](references/lint-boundaries.md). Read it before an import crosses roles, when setting up a project's lint, or when a review finds a role importing across its boundary. Levels and deep imports can also be checked by [`@feod/analyzer`](https://fractal-oriented.tech/en/tools/) (`feod-analyzer analyze`); where it runs, the lint file adds only the role rules.

## 8. Worked example

[`references/worked-example.md`](references/worked-example.md) takes a typical shop frontend laid out by technical kind (`components/`, `hooks/`, `utils/`, `types/`) to this layout, row by row: every level, every role folder, submodules, and a page wiring two modules together. Read it when migrating a project or starting a new one.

## 9. Review checklist

- [ ] Every file with a role carries a suffix from §3
- [ ] Imports from another module or `common` end at its root; `index.ts` has named exports only
- [ ] Consumers import owner-exported types, no `ReturnType<typeof …>` reconstructions
- [ ] A suffix with one file sits at the root; a suffix with two or more files, tests included, is a folder named like the suffix
- [ ] The module's View is inside the module, or the README records it as headless
- [ ] Tests are named after the file they test and sit next to it
- [ ] Every file past ~200 lines (tests ~500) names one responsibility
- [ ] Modules with a VM have a README with purpose, injected dependencies and out of scope
- [ ] Routes and page views live in `pages/`; the module does not know its URL
- [ ] The role matrix from the reference is in the lint config; `export *` is checked by lint or here

## Related skills

| Need | Load |
| --- | --- |
| What each role owns, facade and mediator | `frontend-mvvm` |
| Which state library | `frontend-state-stack` |
| Reatom / MobX wiring of the VM | `reatom`, `mobx-mvvm` |
| Naming a single symbol, a signature | `code-craft` |
| The same idea for Qt Quick | `qt-modular-mvvm` |
