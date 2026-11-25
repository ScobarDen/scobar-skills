# Reatom

The Reatom branch of [`frontend-mvvm`](../SKILL.md). Reatom replaces the ViewModel's mechanism, not the View's framework: read this file together with [`react.md`](react.md) or [`vue.md`](vue.md) for the framework the Views render on. The Reatom API itself comes from the official `reatom` and `reatom-async` skills (`npx skills add https://github.com/reatom/reatom/tree/v1001/skills`).

## The ViewModel is a model factory

`checkout.vm.ts` exports `reatomCheckout(deps, name)`, a factory that builds the screen's atoms, computeds and actions and returns them in the groups of `SKILL.md` §1:

| Group | Holds |
| --- | --- |
| `state` | atoms and computeds the View reads (`total()`) |
| `form` | the field atoms, or the `reatomForm` instance |
| `features` | nested models built by their own `reatom*` factories |
| `functions` | actions |
| `refs` | stays in the framework (`useRef`, a template ref) |

Domain state that outlives the screen, a cart that is its own source of truth, is a `model` file (`cart.model.ts`); the ViewModel reads it, it does not own it. Read data is an async computed with `withAsyncData`: subscribing the View starts the load, so the module root has no `load` call, the same as with a query library.

The roles and their boundaries stay exactly as `mvvm` states them; atoms are only the mechanism. `CheckoutViewModel` declares what the factory returns and is exported by name.

## Binding the View

The module root creates the model once per mount and passes it to the passive Views.

- **React**: every View that reads atoms is a `reatomComponent` from `@reatom/react`; reading an atom in render subscribes to it.
- **Vue**: `reatomRef(atom)` from `@reatom/vue` turns an atom into a ref, and `useAction(action)` binds an action; the refs are grouped as `vue.md` states. `@reatom/vue` is an alpha (`1000.0.0-alpha.31`), and `reatomRef` subscribes in the default context, not in the frame given to `createReatomVue`: SSR isolation needs a bridge that subscribes inside that frame.
