---
name: frontend-mvvm
description: MVVM as separation of responsibilities for UI features — Model prepares domain data, View is a passive function of ViewModel, ViewModel is a facade (UI never sees DTOs) plus a mediator (modules wired through arguments, not each other). Load when writing or reviewing a screen with client logic, fetch+map+handlers, a god component, DTO props leaking down the tree, or when deciding where mapping, handlers, and DI live. Triggers on MVVM, ViewModel, passive view, DTO in UI, logic in the component. Not for picking a state library (frontend-state-stack) and not for MobX APIs (mobx-mvvm).
---

# Frontend MVVM

Write the feature as three layers. The ViewModel is a **role**, not a library.

## Provenance and precedence

- Harvested from [MVVM for React](https://www.youtube.com/watch?v=H0pKvQ8P3UI) (SoC, not reactivity history).
- **Project conventions win.** If the repo already places mapping in API clients or forbids a VM layer, follow the repo and mention the divergence in one line.
- Picking Zustand vs Reatom vs MobX vs hooks is **`frontend-state-stack`**. This file assumes the stack is already chosen.
- MobX wiring (`ViewModelBase`, `withViewModel`, `createQuery`) is **`mobx-mvvm`**.
- Hook *return shape* (`form` / `state` / `functions` / `refs` / `features`) is **`react-hooks-best-practices`** rule `dx-extract-complex-hook`. This file owns the fact that the hook **is** the ViewModel.

## When this applies

A feature that fetches, maps, and handles user intent — a table with filters, a dashboard, a form that orchestrates more than one source. A static presentational piece (icon, layout chrome, a UI-kit button) is not a VM.

## The three layers

| Layer | Owns | Does not own |
| --- | --- | --- |
| **Model** | API calls, domain types, pure transforms, DTO→domain adapters, storage | JSX, UI-kit props, click handlers |
| **ViewModel** | Orchestration: handlers, wiring modules, data *shaped for this screen's UI* | Raw DTO fields, markup |
| **View** | Bind VM output to UI-kit. `View = f(ViewModel)` | Fetch, map, assemble use-case flow |

Start analysis from **state**, then bind the View. Do not start from the JSX tree and sprinkle fetch/map into whoever needed a field.

## Facade: the View never sees a DTO

The VM (or the Model it calls) maps backend shapes into what the UI-kit already consumes — `{ label, value }[]` for a select, column defs for a table, card configs for stats. The View binds those objects. It does not map.

**Wrong:** DTO enters a parent, is passed as props, mapped in one child, mapped again in a grandchild. An analyst asking "which fields of this endpoint do we use?" has to walk the tree.

**Right:** one mapping site in Model/VM. The View's props are UI types.

Pass DTO through a component only as an opaque id if a child VM needs to load its own Model. Do not pass the DTO *to render it*.

Where mapping lives is a size call, not a religion: a tiny app may map in the VM; a real domain maps in the Model (adapter next to the API function) and the VM only composes. Never in the View.

## Mediator: modules do not know each other

The VM is the one place that constructs (or receives) collaborators and passes **functions/values as arguments**. A service does not import a storage. Two services that share an id do not import each other — the VM passes the id through.

This is inversion of control so the graph can be substituted in tests. It is the *intention* of a mediator, not the GoF class.

```ts
class TableStore {
  constructor(
    private getTasks: (params: TaskQuery) => Promise<Task[]>,
    private params: () => TaskQuery,
  ) {}
}

this.tableStore = new TableStore(taskService.getTasks, () => ({
  ...this.filterStore.query,
  ...this.paginationStore.params,
}))
```

The same shape on hooks: `useTable({ getTasks, params })` receives getters, it does not call `useFilters()` inside.

Inject the service into the VM from the outside (`payload`, constructor, hook argument). The VM does not `new AxiosClient()` in a leaf.

## Compose the screen by domain, not by file length

Split the VM into collaborating stores/hooks along **UI domains of this feature** — filters, stats, table, pagination — then bind each to a passive widget.

A nested feature that is its own business value gets **its own VM**. The parent passes in what that VM needs (ids, callbacks, a pre-built widget). It does not absorb the child's use-case.

## Handlers and action configs live in the VM

Click/submit/search handlers are VM methods. When a row of buttons is data (style, label, icon, handler, loading), the VM exposes an array of configs and the View is one generic `ActionButtons` that reads `view` and renders. Assembling that array in JSX is the logic leak this layer exists to kill.

## Hooks adapter

React ties logic to component lifecycle, so a *pure* VM class is optional. The physical split is not:

```tsx
export function WorkflowPage(props: { taskService: TaskService }) {
  const vm = useWorkflowPage(props)
  return <WorkflowView {...vm} />
}
```

`useWorkflowPage` is the ViewModel: mapping, handlers, queries, wiring. `WorkflowView` and its children bind. They do not call the API.

- Return grouping: follow `dx-extract-complex-hook`. Do not invent a second return vocabulary here.
- React infrastructure (debounce, click-outside, `createStore` / `useSyncExternalStore` selectors, disclosure) comes from **`reactuse`**. Business use-case does not.
- Granular renders, if a measured problem: subscribe the widget to *its* store/hook, not the whole page VM. That is a binding choice, not a reason to fetch from the widget.

On Vue the VM is a composable (`useXxx`), the View is the SFC template. Same DTO/DI rules. SFC mechanics stay in the Vue skills.

On Reatom the VM is a model (atoms/actions). Load **`reatom`**. Do not re-implement this file's rules as atoms.

## Renders

Do not smear fetches and maps across the tree to "localize state" or dodge rerenders. Boundaries first.

`vercel-react-best-practices` applies **after a measured problem** (profiler, a real jank). It does not override this file. Memo sprinkled on a god component is not architecture.

## Review smells

- `useQuery` / `fetch` / DTO field access inside a presentational component.
- The same DTO type in a widget's props.
- `selectOptions` assembled in JSX from a raw enum/DTO.
- Service module imports storage *and* HTTP client.
- Feature stores/hooks importing each other instead of taking arguments.
- Parent View re-implements a child feature instead of mounting the child's VM.
- "We put the query in the row component so the table doesn't rerender."

## Related skills

| Need | Load |
| --- | --- |
| Which STM to take | `frontend-state-stack` |
| Project is already MobX | `mobx-mvvm` |
| Hook return contract | `react-hooks-best-practices` (`dx-extract-complex-hook`) |
| Which ReactUse hook | `reactuse` |
| Reatom API | `reatom` / `reatom-async` |
| Render optimization after a measurement | `vercel-react-best-practices` |
