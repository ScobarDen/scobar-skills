---
name: qt-modular-mvvm
description: How to lay out and grow a Qt Quick (QML + C++) desktop application as levels (global → common → modules → pages → app, the FEOD idea) with an MVVM pyramid inside every module (domain / data / model / viewmodel / ui), a facade per module, constructor injection instead of a DI container, and a thin app-level mediator wiring modules together. Load this whenever structuring or reviewing a Qt Quick app — a new screen or module, "where does this code go", a ViewModel or QAbstractListModel, a Module facade, qmldir/internal, the composition root in main.cpp, cross-module wiring — even if the user never says FEOD or MVVM. Also load for architecture review of an existing Qt module. Build-system enforcement (CMake OBJECT layers, PUBLIC/PRIVATE, LINK_ONLY, moc/rcc traps) lives in the sibling skill qt-cmake-boundaries; load both when creating a module.
---

# Qt modular MVVM

Two cuts through one codebase, and they answer different questions:

- **Levels** answer *where does it live and who may see it*. `global → common → modules → pages → app`; a level imports only levels below it.
- **Layers inside a module** answer *who is responsible for what* within one scenario. `domain → data → model → viewmodel → ui`; that is MVVM with the Model split into three folders.

A module directory is one level in the first cut and the whole MVVM pyramid in the second. Understand one module and you understand them all.

## Provenance and precedence

- Harvested 2026-09-03 from a teaching expense tracker (Qt 5.15, QML, PostgreSQL) that was built, tested and reviewed end to end; every rule below was either enforced by its compiler or bitten someone in its history.
- **Project conventions win.** If the repository already has a layout, a naming scheme or its own module recipe, follow it and mention the divergence in one line. This skill is a default, not a mandate to refactor an existing project into its shape.
- Qt 5.14+ is the baseline. Qt 6 changes the QML packaging story; see *Qt 6 deltas* at the end.
- The sibling skill **qt-cmake-boundaries** holds the build-system half: how the layer matrix becomes compiler errors, and copyable CMake templates. Recipes here say "see qt-cmake-boundaries" at exactly the steps that need it.

## 1. Levels

| Level | Holds | May import | Frontend analogue |
| --- | --- | --- | --- |
| `global/` | settings applied before the app object exists (HiDPI, style, defaults) | nothing | `polyfills.ts` loaded only by `main.ts` |
| `common/` | technical entities with no product meaning: money formatting, DB connection, date ranges, UI primitives, sugar over Qt | `global` | `shared/` |
| `modules/` | product scenarios; 90% of the work | `common`, other modules' **public API only** | `features/*` |
| `pages/` | thin screens: mount a module's view, hand it its ViewModel | `modules`, `common` | `pages/*` in Next.js |
| `app/` | composition root, the mediator between modules, root QML, resources | everything | `main.tsx` + DI root + router |

Two consequences people miss:

- `common` never knows a module exists. The moment a `common` entity mentions a product term, it is a module.
- A module never knows `app` or `pages` exist. It does not read the global `App` singleton from QML; the page reads `App` and passes the ViewModel down as a property.

### The fork "module or common"

Something is needed by two modules. Ask one question:

> Can you explain what it is **without naming the product domain**?
> Yes → `common`. No → a module (possibly a *cross-cutting module* like a shared `category` lookup).

"Used twice" is never by itself a reason. Money formatting, a database connection, a date range with its "start not after end" invariant, an empty-state placeholder, a coloured dot with a label: `common`. The *same* dot named `CategoryDot` because "this is how a category looks here": a thin wrapper in the `category` module over the neutral `common` primitive. Naming by a product entity is product meaning.

### The fork "lookup table or enum"

> Can the user invent a new value at runtime?
> Yes → a table in the database and a repository. No → `enum class` in the module's `domain`.

## 2. Layers inside a module

```
modules/<name>/
  include/<name>/         PUBLIC facade: <Name>ViewModel.h, module.h   (2–3 files, not more)
  module.cpp              the module's own composition root (pimpl body)
  domain/include/domain/  types and rules; sees nothing, not even siblings
  data/include/data/      repositories: SQL in, structs out; sees domain
  model/include/model/    QAbstractListModel subclasses; sees domain, NOT data
  viewmodel/              implementation of the public ViewModel; sees domain, data, model
  ui/                     QML: one public View, everything else `internal` in qmldir
  tests/                  unit tests of this module, next to what they test
```

Who is who:

- **domain** — plain structs, `enum class`, pure validation functions. No Qt beyond `QString`/`QDate`, no SQL, no QObject. This is why it tests without a database, a window, or even a `QCoreApplication`.
- **data** — repositories. A repository spans as many tables as one scenario needs; a report repository may `LEFT JOIN` a table another module owns, and that is a documented trade-off, not a violation, when the aggregation cannot be expressed through the other module's API. Methods are `virtual`: that virtuality is the test seam, not polymorphism for its own sake.
- **model** — turns a vector of domain structs into rows and roles for `ListView`. It receives rows through `setRows(...)`; it never fetches. A model that fetches cannot be unit-tested without a database, which turns a unit test into an integration test. Roles start at `Qt::UserRole + 1`; `roleNames()` is the contract with QML and deserves a test that pins the names.
- **viewmodel** — the screen's state (`Q_PROPERTY` with `NOTIFY`), its commands (`Q_INVOKABLE`), and the calls into repositories. It does not know how the screen looks: the header must compile without any QtQuick include, and the build must not give it `Qt5::Quick`. It exposes the model as `QAbstractItemModel *` so the concrete model type stays private. On an error it keeps the previous rows on screen and sets an `errorText`; an empty result and a failed query are indistinguishable by return value, so wiping the table on error would look like data loss.
- **ui** — declarative bindings to the ViewModel, handlers that call its commands. No domain conditions in QML: if a `.qml` file compares a payment method key or checks an amount, that logic escaped from `domain` or `viewmodel`.

Dependencies flow one way. The concrete matrix, and how to make the compiler enforce it, is in **qt-cmake-boundaries**.

## 3. The facade and the composition roots

Each module exposes two or three headers: the ViewModel and a `Module` class. `Module` exists so the repository and the model **never have to be public types**: the module assembles itself.

```cpp
// include/<name>/module.h — the only other public header
class Module {
public:
    explicit Module(ptr::not_null<other::SomeRepository *> dep);   // cross-module deps arrive as arguments
    ~Module();                                                    // defined in module.cpp (pimpl needs the full Impl)
    Module(const Module &) = delete;
    Module &operator=(const Module &) = delete;
    NameViewModel *viewModel() const;                             // ownership stays inside
private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};
```

`module.cpp` holds `struct Module::Impl { Repository repository; NameViewModel viewModel; }` with members **declared in dependency order**: members construct in declaration order, and `viewModel(&repository)` needs a live repository. The compiler will not warn if the order is wrong; `-Wreorder` only compares the initializer list against declarations. The full skeleton with the ownership and lifetime notes is in `references/module-facade.md`.

The public ViewModel header forward-declares the repository and the model. Its constructor signature is visible from outside, but nothing outside can construct the arguments: that is the public API boundary expressed in C++ rather than in a linter.

**Constructor injection, no container.** The `app` level's `main()` is the composition root: it creates the cross-cutting repositories on the stack, creates each `Module`, passes dependencies as constructor arguments, builds the mediator, registers types with QML, triggers the first data load, then loads QML. Order is a correctness condition, not style: the first load must happen *after* the mediator subscribed to error signals, or the very first failure is emitted into the void and the user sees an empty screen with an empty status bar. Objects on the stack in `main()` are destroyed in reverse order, so anything registered into the QML engine must be declared before the engine.

Inject the clock as well: a `std::function<QDate()>` parameter with an empty default that the constructor replaces with `QDate::currentDate`. "Last 30 days" is otherwise untestable.

## 4. Modules talk through arguments or through the mediator

Two legal shapes, pick by direction of knowledge:

| Shape | When | Example |
| --- | --- | --- |
| **Argument** | module A genuinely needs module B's data | `expenses::Module(category::CategoryRepository *)` — the lookup is passed in, declared in the constructor and in the build file |
| **Mediator in `app`** | "something happened in A, B should react" and neither should know the other | `AppViewModel` connects `expenses.dataChanged → report.refresh` in one visible line |

Never create another module inside your module, and never import a module's private paths. The mediator is not a god object: it owns no data, only pointers to the modules' ViewModels, a status line, and connection info. It collects errors from every module into one status text and must be updated when a module is added, or that module's errors silently never reach the UI. Report success *after* collecting errors, never before, or the success message overwrites the error.

## 5. QML side

- **One public View per module**, listed in `ui/qmldir`; dialogs and badges are `internal`. This is the QML `index.ts`. It is weaker than the C++ boundary — the engine still loads a `.qml` by relative path — so it stays on the review checklist.
- **The View receives its ViewModel as a property**, typed: `property ExpensesViewModel vm`. The type exists in QML because `main.cpp` registered it with `qmlRegisterUncreatableType` — QML must *know* the type for tooling and typed properties even though it never instantiates it. The mediator itself is registered with `qmlRegisterSingletonInstance`, which gives it a type; `setContextProperty` would give it `var` and hide typos until runtime.
- **Pages are thin**: `Item { SomeView { anchors.fill: parent; vm: App.some } }`. Logic in a page has escaped from a module; move it back.
- **Bindings down, handlers up.** There is no two-way binding: `text: vm.searchText` plus `onTextEdited: vm.searchText = text`. Use the user-action signal (`onActivated`, `onTextEdited`), not the change signal (`onCurrentIndexChanged`), or the binding feeds itself into a loop.
- **Dialogs close only on success.** A command returns `bool`; with `standardButtons` the dialog closes before you can read it. Give the dialog its own footer buttons and call `accept()` only when the command returned `true`.
- **Reactivity is per property, not per component.** Every `Q_PROPERTY` bound in QML needs a `NOTIFY` that actually fires; forgetting the `emit` is the one rule the build cannot check — the screen just stops updating. Write the compare-assign-emit ritual once per class (a helper for single fields, one private `applyX()` for multi-field state), never per method.
- Resources: in Qt 5 every `.qml` and `qmldir` is listed in a `.qrc` with `alias` so the physical FEOD layout and the QML import tree can differ. Forget one file and the app builds fine and fails at runtime with `module "x" is not installed`.

## 6. Tests prove the seams exist

MVVM that cannot be tested without a database and without a window exists only on paper. Every module keeps unit tests next to its code, and most of them run with no PostgreSQL and no display: the repository is replaced by a subclass overriding its virtual methods, the clock by a fixed lambda. A test that links more than one module's target is an integration test and lives at the project level, not inside a module. That is the whole testing doctrine this skill carries; specific fixture and fake patterns are project detail.

## 7. Optional sugar seen in the source project

The source project shortened `Q_PROPERTY` boilerplate with macros (`PROP_READONLY / WRITABLE / COMPUTED` generating property, getter, field), wrapped "compare, assign, emit" into one template helper so single-field setters cannot forget the signal, and used a tiny `not_null<T *>` for pointers that must be valid (a deleted `nullptr_t` constructor turns the mistake into a compile error). These are stylistic contracts. Adopt them only if the project wants them; if it does, the macro header must be on moc's include path for every target whose header uses it, or the properties silently vanish from the meta-object while the code still compiles. Guard that with a test that walks `staticMetaObject` and asserts each expected property exists with the right writability.

## 8. Recipes

Step-by-step procedures live in `references/recipes.md`. Read the one you need:

1. **New module** — directories, facade, layer declaration, QML, page, composition root, mediator, tab, tests. Ten steps, two of which point into qt-cmake-boundaries.
2. **New field through every layer** — schema → domain struct → SQL and index → role → `roleNames()` → width token → QML → role test. Eight places; know the price before promising the feature.
3. **New `common` entity** — when to extract, how to shape it (STATIC vs header-only), and why its test needs no private paths.
4. **Linking two modules** — argument versus mediator, and the visible places each must appear.

## 9. Review checklist (architecture half)

Use on a new module or on any change touching module structure. The build-system half of the checklist is in qt-cmake-boundaries.

- [ ] Module knows nothing about `app` or `pages`: no `App` in module QML, no app headers in module C++
- [ ] Other modules are used only through `include/<name>/`, never through their layer paths
- [ ] `common` mentions no module and no product term
- [ ] `model` does not fetch: rows arrive via `setRows`, and its build declaration does not see `data`
- [ ] Repository methods are `virtual` and the ViewModel takes the repository as a constructor argument (the test seam exists)
- [ ] ViewModel header has no QtQuick include; the model is exposed as `QAbstractItemModel *`
- [ ] Public headers are two or three, not everything
- [ ] Every property bound in QML has a `NOTIFY` that fires; multi-field state changes through one private apply method
- [ ] On error the ViewModel keeps previous rows and sets `errorText`; success is reported only if no error followed
- [ ] `qmldir` lists one public View, the rest `internal`; every `.qml` is in the resource file
- [ ] Page only mounts the View and passes `vm`
- [ ] ViewModel type registered in `main.cpp`; module added to the mediator's error collection
- [ ] Tab order matches `StackLayout` order (they are linked by index)
- [ ] Unit tests live in the module and run without a database; multi-module tests live at project level
- [ ] No domain conditions in QML; no duplicated formatting or validation outside `common` / `domain`

## 10. Symptoms and causes (architecture half)

| You see | Cause |
| --- | --- |
| Interface "sometimes does not update" | A setter changed a field without `emit`; or a multi-field change emitted before fixing its invariant |
| Screen shows a value but a status message overwrote the error | Success reported before errors were collected |
| Empty list plus an error line after a DB hiccup | ViewModel wiped rows on error instead of keeping them |
| A module's errors never reach the status bar | Module not added to the mediator's error collection |
| Clicking the same preset twice re-queries the DB | Setter lacks the "unchanged → return" check |
| Dialog closes and the input is lost although the DB rejected it | `standardButtons` close before the command result is read |
| `module "x" is not installed` at runtime, build was clean | `.qml` or `qmldir` missing from the resource file, or the type missing from `qmldir` |
| `App.x` is an object without properties in QML | ViewModel type not registered with `qmlRegisterUncreatableType` |
| A combo box shows a placeholder entry in an input form | The form reused the filter list that carries the pseudo-item "all"; expose a separate list for input |
| A test of the domain layer suddenly needs the repository header | Database access leaked into `domain`; the layer matrix caught it |

## 11. Qt 6 deltas

- `qt_add_qml_module(target URI ... QML_FILES ...)` replaces the hand-written `.qrc` + `qmldir`: the module's public/internal split moves to the CMake call, and `internal` types become non-exported QML files. The level and layer rules are unchanged; only the packaging step in recipe 1 differs (see qt-cmake-boundaries).
- `required property SomeViewModel vm` replaces the plain `property` plus a null-check habit; a page that forgets to pass `vm` fails at load instead of throwing `TypeError`s per binding.
- `qmlRegisterSingletonInstance` and `qmlRegisterUncreatableType` still work; `QML_ELEMENT` / `QML_SINGLETON` macros in the C++ headers are the declarative alternative.
- `QRegularExpression` only; `QRegExp` is gone. `QVariant::type()` becomes `typeId()`.
