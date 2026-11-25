# Vue

The Vue branch of [`frontend-mvvm`](../SKILL.md). Read it with `SKILL.md` before writing a ViewModel, a View or a route in a Vue project.

## The ViewModel is a composable

`useCheckout` in `checkout.vm.ts` is the ViewModel; the View is the SFC template. Its arguments type, `UseCheckoutArgs`, is also the module root's props type: `checkout.view.vue` declares `defineProps<UseCheckoutArgs>()`, and `index.ts` re-exports it as `CheckoutProps` next to `export { default as Checkout } from './view/checkout.view.vue'`.

The module root calls the composable in `<script setup>`, starts the first load with `onMounted(() => functions.load())`, and renders passive child SFCs.

## Groups in Vue

A template unwraps only top-level refs, so the composable keeps its state in `shallowRef` / `ref` and returns each group in the shape its binding needs:

| Group | Returned as | Why |
| --- | --- | --- |
| `state` | `readonly(reactive({ ... }))` | unwraps the refs; Views cannot write |
| `form` | `reactive({ ... })` | unwraps the refs; `v-model="form.email"` writes through to the ref |
| `features` | `readonly(reactive({ ... }))` | unwraps refs at any depth, whatever shape the nested controller has; a nested controller's template refs move up to `refs`, a third-party instance inside it is `markRaw` |
| `functions` | plain object | nothing to unwrap |
| `refs` | plain object, bound as `:ref="refs.emailInput"` | `reactive` would unwrap the ref and the element never reaches it |

```ts
return {
  state: readonly(reactive({ items, total, isSubmitting })),
  form: reactive({ email, password }),
  features: readonly(reactive({ promoModal })),
  functions: { removeItem, submit },
  refs: { emailInput },
}
```

A project's general ban on `reactive()` does not cover these return groups; name the exception in one line. `CheckoutViewModel` types the unwrapped values (`state: Readonly<CheckoutState>` with `total: number`; `refs` keeps its `Ref` types). Views pass a group, or a controller inside one, as the object (`:state="state"`, `:modal="features.promoModal"`); destructuring it snapshots its values.

Infrastructure composables are `lib` files in `common/lib/` (`use-disclosure.lib.ts`); `features` holds what they return.

## Routes

`vue-router`. The page View receives its dependencies through the route record's `props`:

```ts
// pages/checkout/checkout.route.ts
export const checkoutRoute = { path: '/checkout' }

// app/app.route.ts
import type { RouteRecordRaw } from 'vue-router'
import { checkoutRoute } from '@/pages/checkout/checkout.route'
import CheckoutPage, { type CheckoutPageProps } from '@/pages/checkout/checkout.view.vue'

export function createRoutes(deps: CheckoutPageProps): RouteRecordRaw[] {
  return [{ ...checkoutRoute, component: CheckoutPage, props: deps }]
}

// app/main.ts
import { createApp } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'
import { createCartSource } from '@/modules/cart'
import App from './app.view.vue'

const router = createRouter({ history: createWebHistory(), routes: createRoutes({ cartSource: createCartSource() }) })
createApp(App).use(router).mount('#app')
```

```vue
<!-- pages/checkout/checkout.view.vue -->
<script setup lang="ts">
import type { CartSource } from '@/modules/cart'
import { Checkout } from '@/modules/checkout'

export interface CheckoutPageProps { cartSource: CartSource }

const props = defineProps<CheckoutPageProps>()
</script>

<template>
  <Checkout :cart-source="props.cartSource" />
</template>
```

## Type checking and tests

`vue-tsc --noEmit` checks only what the `tsconfig.json` it reads includes: create-vite's root config (`"files": []` plus references) makes it check nothing. Use the single config from `SKILL.md` §4 with `src/**/*.vue` included, or run `vue-tsc -b`.

Vitest with jsdom and `@testing-library/vue`. The ViewModel test calls the composable directly, reads unwrapped values (`vm.state.total`) and assigns a test element to a `refs` entry; stories are `.stories.ts`.

## Review smells

- A ViewModel returning `state`, `form` or `features` as a plain object of refs (`state: { total }`): in `:disabled="state.isSubmitting"` the binding gets the ref, always truthy, while `{{ state.total }}` still renders and hides the bug.
- A ViewModel returning `refs` inside `reactive`: `:ref="refs.emailInput"` binds the unwrapped `null`, the element never reaches the ViewModel, and `emailInput.value?.focus()` does nothing.
