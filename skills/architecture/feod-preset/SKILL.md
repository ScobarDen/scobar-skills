---
name: feod-preset
description: FEOD preset — stricter module rules on top of the official `feod` skill. Use together with `feod` when starting a project, creating or placing a module, a submodule or a common entity, or reviewing a module's exports.
---

# FEOD preset

Load the official `feod` skill first (`npx skills add Sdju/feod`); it owns the levels, the import matrix, the project profile and the lint setup. Where this file and `feod`'s defaults differ, templates included, this file wins. An existing project's `feod.profile.md` and layout win over both: follow them and mention the divergence in one line. Inside a module, file names are `role-files` and responsibilities are `mvvm`.

Every rule below holds for the code you add or move. Name any rule you could not satisfy and why.

## New project

Right after `feod` init:

1. Under `## Project notes` in `feod.profile.md`, add one line: module rules follow the `feod-preset` skill, kebab-case module names, role files inside modules.
2. Put the two config options named below (`submodules.visibility`, `modules.forbiddenNames`) into the FEOD config.

Done when the profile names the preset and the config holds both options.

## Module or common

> Can you state what it is **without naming the product domain**?
> Yes → `common`. No → a module, possibly a cross-cutting one (`auth`, `notifications`, `feature-flags`).

Decide by this test alone, whatever the reuse count. Money formatting, an HTTP client, a coloured dot with a label: `common`. The same dot named `CategoryDot` is a thin wrapper in the `category` module over the neutral one.

## Module public API

- `index.ts` names every export one by one; `export *` publishes whatever lands in the folder next.
- A new export has a consumer or a stated reason.
- Exported names are domain names (`Checkout`, `getOrderTotal`); `CheckoutApi` and `UserModel` echo an internal folder.
- The owner exports its types, and consumers import them from it.
- An external package wrapped by a common entity or a module is used only through that wrapper.

## Names

- Modules are domain nouns in kebab-case: `checkout`, `feature-flags`. If no short product name fits, the boundary is not clear yet.
- A folder is named after a responsibility or a role from `role-files`, on every level and inside modules. `utils`, `helpers`, `shared`, `misc`, `services`, `components`, `composables`, `hooks` name neither; list them in `modules.forbiddenNames` so lint rejects them as module names.

## Submodules

- Cut one when a part of the module gets its own reason to change: `modules/checkout/modules/delivery/`. Two files are too early, and a folder grouping files by technical kind is a role folder.
- A part with its own consumers and its own product responsibility is a separate module.
- Code outside the parent reaches a submodule through the parent's `index.ts`. Lint allows the submodule's own `index.ts` until the config sets `submodules.visibility: "parent-only"`.

## Module README

Every module with a ViewModel has a `README.md` of five to ten lines with exactly these parts:

```md
# checkout

Turns a cart into a placed order: address, delivery slot, payment.

- Injected: `cartSource`, `paymentClient` (from `app/`).
- Out of scope: cart editing (`cart`), order history (`orders`).
```

## Exceptions

A rule gives way only to an exception written next to the code and checked by a tool (the FEOD config's `ignore`, a lint override with a comment); a temporary one carries an end date. The excepted import is the whole exception: the file it reaches stays internal.
