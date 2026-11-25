# React

The React branch of [`frontend-mvvm`](../SKILL.md). Read it with `SKILL.md` before writing a ViewModel, a View or a route in a React project.

## The ViewModel is a hook

React ties logic to component lifecycle, so a pure ViewModel class is optional. The physical split is not:

```tsx
export function Checkout(props: CheckoutProps) {
  const vm = useCheckout(props)
  useEffect(() => {
    void vm.functions.load()
  }, [vm.functions.load])
  return <CheckoutView {...vm} />
}
```

`Checkout` is the module root: it calls the hook, starts the first load in a `useEffect` calling the `load` command (or leaves it to a query library that loads on mount) and renders the passive `CheckoutView`, which takes `CheckoutViewModel` as props. Commands the root depends on are stable (`useCallback`).

## Groups in React

Every group is a plain object; React re-renders on state change, so nothing needs unwrapping.

| Group | Holds |
| --- | --- |
| `state` | values |
| `form` | field values; their setters (`changeEmail`, `changePromoCode`) go to `functions` |
| `features` | the nested controllers' objects as their hooks return them |
| `functions` | commands and form setters |
| `refs` | `useRef` objects, bound as `ref={refs.emailInput}` |

`useSyncExternalStore` selectors and other infrastructure hooks are `lib` files in `common/lib/` (`use-debounce.lib.ts`).

## Routes

`pages/checkout/checkout.view.tsx` mounts the module root and passes its dependencies; `app/app.route.ts` joins the route with the page View; `app/main.tsx` calls it once with the dependencies it constructs:

```tsx
// pages/checkout/checkout.view.tsx
import type { CartSource } from '@/modules/cart'
import { Checkout } from '@/modules/checkout'

export type CheckoutPageProps = { cartSource: CartSource }

export function CheckoutPage({ cartSource }: CheckoutPageProps) {
  return <Checkout cartSource={cartSource} />
}
```

```ts
// pages/checkout/checkout.route.ts
export const checkoutRoute = { path: '/checkout' }

// app/app.route.ts
import { createElement } from 'react'
import { checkoutRoute } from '@/pages/checkout/checkout.route'
import { CheckoutPage, type CheckoutPageProps } from '@/pages/checkout/checkout.view'

export function createRoutes(deps: CheckoutPageProps) {
  return [{ ...checkoutRoute, element: createElement(CheckoutPage, deps) }]
}

// app/main.tsx
import { createCartSource } from '@/modules/cart'

const router = createBrowserRouter(createRoutes({ cartSource: createCartSource() }))
```

## Tests

Vitest with jsdom and `@testing-library/react`. The ViewModel test renders the hook with `renderHook` and calls `load` explicitly; stories are `.stories.tsx`.
