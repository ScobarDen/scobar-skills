---
name: mobx-mvvm
description: MobX MVVM recipe — ViewModelBase + withViewModel, payload/DI into the VM not the View, mobx-tanstack-query createQuery outside React, compose feature stores through constructor args. Load only when the project already uses MobX / mobx-view-model / mobx-tanstack-query, or when implementing or reviewing that stack. Do not recommend MobX on greenfield (load frontend-state-stack). Doctrine lives in frontend-mvvm.
---

# MobX MVVM recipe

How to implement **`frontend-mvvm`** when the repo is already on MobX. Not a MobX tutorial and not a greenfield recommendation.

## Provenance and precedence

- Recipe from [MVVM for React](https://www.youtube.com/watch?v=H0pKvQ8P3UI), packages from [js2me/mobx-view-model](https://js2me.github.io/mobx-view-model/) and [js2me/mobx-tanstack-query](https://js2me.github.io/mobx-tanstack-query/).
- **Installed typings and the project's existing VM files win.** Re-check signatures before copying snippets; the React bindings moved to `mobx-view-model-react` (root re-export is deprecated).
- Layers, DTO rule, mediator rule: **`frontend-mvvm`**. Do not restate them. This file is the wiring.
- Greenfield / "should we take MobX": **`frontend-state-stack`**. The answer is no unless the repo already did.

## Stack

| Job | Package |
| --- | --- |
| VM class, payload, lifecycle | `mobx-view-model` (`ViewModelBase`) |
| Bind VM to React | `mobx-view-model-react` (`withViewModel`, `ViewModelProps`) |
| Queries/mutations outside React | `mobx-tanstack-query/preset` (`createQuery`) |
| Reactivity | `mobx` + `mobx-react-lite` (`observer` if a child is not wrapped by `withViewModel`) |

MobX has no async/cache of its own. Do not call `@tanstack/react-query` hooks inside a VM class — that puts the query back on the component. `createQuery` wraps query-core so the query lives next to the store.

Docs for APIs this file does not copy: [withViewModel](https://js2me.github.io/mobx-view-model/react/api/with-view-model.md), [createQuery](https://js2me.github.io/mobx-tanstack-query/preset/createQuery.md).

## Bind: props go to the VM

```tsx
import { ViewModelBase } from 'mobx-view-model'
import { withViewModel } from 'mobx-view-model-react'

class WorkflowMonitoringVM extends ViewModelBase<{ taskService: TaskService }> {}

export const WorkflowMonitoring = withViewModel(
  WorkflowMonitoringVM,
  ({ model }) => (
    <>
      <StatsCards cards={model.statsCards} />
      <Filters store={model.filterStore} />
      <TaskTable store={model.tableStore} />
    </>
  ),
)

<WorkflowMonitoring payload={{ taskService }} />
```

The View receives `model`. It does not receive `taskService` or a DTO.

`withViewModel` wraps the view in `observer` by default. Child widgets that read an observable store passed as a prop need their own `observer` (or they will miss updates).

Do not use `withViewModel` together with React `lazy()` / `<Suspense>` — the HOC is documented as incompatible. Split that another way (`react-simple-loadable` in the upstream docs, or don't lazy the VM root).

## Compose stores through arguments

Split the screen VM into stores along UI domains (filters, stats, table, pagination). The VM constructs them and passes **functions**, not sibling store types.

```ts
class TableStore {
  readonly tasksQuery = createQuery(
    async () => this.getTasks(this.params()),
    { queryKey: ['tasks'] },
  )

  constructor(
    private getTasks: (params: TaskQuery) => Promise<TaskRow[]>,
    private params: () => TaskQuery,
  ) {}

  get rows() {
    return this.tasksQuery.data ?? []
  }
}

class WorkflowMonitoringVM extends ViewModelBase<{ taskService: TaskService }> {
  readonly filterStore = new FilterStore()
  readonly paginationStore = new PaginationStore()

  readonly tableStore = new TableStore(
    (params) => this.payload.taskService.getTasks(params),
    () => ({ ...this.filterStore.query, ...this.paginationStore.params }),
  )
}
```

`queryFn` / `params` close over `this.payload` and run later, after mount. If `params()` must retrigger the fetch, use the documented `createQuery(queryClient, () => options)` overload — a static `queryKey: ['tasks']` will not.

`taskService.getTasks` already returns **UI/domain types**. If it still returns a DTO, map in the service (Model), not in the table widget.

## Queries live in the store, flags stay there

```ts
readonly statsQuery = createQuery(
  () => this.payload.taskService.getStats(),
  { queryKey: ['workflow-stats'] },
)

get statsCards(): Array<{ label: string; value: string }> {
  return this.statsQuery.data ?? []
}
```

The View binds `model.statsCards` and, if needed, `model.statsQuery.isPending`. It does not call `useQuery`.

## Action configs are data

Pagination controls, row actions, header buttons: the VM exposes an array `{ view, action, text, icon, loading, ...style }` and a dumb `ActionButtons` maps `view` to the UI-kit. Building that array in JSX is a VM leak.

## Review smells (MobX-specific)

- `useQuery` / `useMutation` from `@tanstack/react-query` inside a component that already has a VM.
- `taskService` or a DTO type on the View's props.
- `FilterStore` imported by `TableStore`.
- `withViewModel` + `React.lazy` / `Suspense` on the same boundary.
- Greenfield prompt answered with this stack. Send that to `frontend-state-stack`.
