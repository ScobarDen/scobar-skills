---
name: qt-mvvm
description: MVVM, FEOD and role files applied to a Qt Quick (QML + C++) application — role folders `domain / data / model / viewmodel / ui` inside every module, `include/<name>/` plus `qmldir` as a module's public API, a pimpl `Module` class that assembles the module, constructor injection instead of a DI container, `main.cpp` as the composition root, an `AppViewModel` mediator, QML binding rules. Load when structuring or reviewing a Qt Quick app — a new screen or module, "where does this code go", a ViewModel or a QAbstractListModel, the `Module` class, qmldir and `internal`, `main.cpp` order, cross-module wiring — even if the user never says FEOD or MVVM. Doctrine is in feod, mvvm and role-files; CMake enforcement is qt-cmake-boundaries, load both when creating a module.
---

# Qt MVVM

How `feod`, `mvvm` and `role-files` look in a Qt Quick application. Load those three for the rules; this file adds what C++, QML and moc change.

A module directory is one FEOD module and the whole MVVM stack at once. Understand one module and you understand them all.

## Provenance and precedence

- Harvested 2026-09-03 from a teaching expense tracker (Qt 5.15, QML, PostgreSQL) that was built, tested and reviewed end to end; every rule below was either enforced by its compiler or bit someone in its history.
- FEOD itself is written for frontend projects. Applying it to C++ and QML is this skill family's extension, mapped in §1.
- **Project conventions win.** If the repository already has a layout, a naming scheme or its own module recipe, follow it and mention the divergence in one line.
- Qt 5.14+ is the baseline. Qt 6 changes the QML packaging; see *Qt 6 deltas* at the end.
- `qt-cmake-boundaries` holds the build half: how the role matrix becomes compiler errors, with copyable CMake. Recipes here say **[cmake]** at exactly the steps that need it.

## 1. FEOD on Qt

| Level | Holds on Qt |
| --- | --- |
| `global` | settings applied before the `QGuiApplication` exists (HiDPI attributes, style, defaults). `main()` calls it first, which is FEOD's entry exception; nothing else includes it |
| `common` | money formatting, the DB connection, date ranges, UI primitives, sugar over Qt; each entity is its own target with `include/<entity>/` |
| `modules` | product scenarios; most of the work |
| `pages` | thin QML screens that mount a module's View and hand it its ViewModel |
| `app` | `main.cpp` as the composition root, `AppViewModel` as the mediator, root QML, resources |

**A module's public API** has two halves:

- C++: `include/<name>/` with two or three headers, the ViewModel and `module.h`. Everything else is a private include path the build does not hand out.
- QML: `ui/qmldir` lists one public View; dialogs and badges are `internal`. This half is weaker than the C++ one (the engine still loads a `.qml` by relative path), so it stays on the review checklist.

A module never knows `app` or `pages` exist. It does not read the `App` singleton from QML; the page reads `App` and passes the ViewModel down.

## 2. Role folders

In Qt the role marker is **always a folder**: the build gives every role folder its own target, and that target is the boundary (`qt-cmake-boundaries`). File names follow Qt's idiom (`budgetrepository.h`), not dot-suffixes.

```
modules/<name>/
  include/<name>/         public API: <Name>ViewModel.h, module.h   (2–3 files, not more)
  module.cpp              the module's own composition root (pimpl body)
  domain/include/domain/  types and rules
  data/include/data/      repositories
  model/include/model/    QAbstractListModel subclasses
  viewmodel/              implementation of the public ViewModel
  ui/                     QML: one public View, the rest `internal` in qmldir
  tests/                  unit tests of this module
```

| Folder | `role-files` marker | `mvvm` role |
| --- | --- | --- |
| `domain/` | `model` | Model |
| `data/` | `api` | Model |
| `model/` | `vm` (a list adapter) | **ViewModel** |
| `viewmodel/` + the public ViewModel header | `vm` | ViewModel |
| `ui/` | `view` | View |

**Qt's `model/` is not the MVVM Model.** It turns domain structs into rows and roles for a `ListView`: UI-shaped output, so it belongs to the ViewModel role (`mvvm` §3). The folder keeps its Qt name because every Qt document calls it that. Domain code goes to `domain/`, never to `model/`.

What each folder adds on Qt:

- **domain**: plain structs, `enum class`, pure validation functions. No Qt beyond `QString` / `QDate`, no SQL, no `QObject`. It tests without a database, a window or a `QCoreApplication`.
- **data**: repositories, SQL in, domain structs out; rows never leave. A repository spans as many tables as one scenario needs. Methods are `virtual`: that virtuality is the test seam, not polymorphism for its own sake. A report repository joining a table another module owns is a documented exception (`feod` §7).
- **model**: receives rows through `setRows(...)`; it never fetches. Roles start at `Qt::UserRole + 1`; `roleNames()` is the contract with QML and gets a test that pins the names.
- **viewmodel**: screen state as `Q_PROPERTY` with `NOTIFY`, commands as `Q_INVOKABLE`, calls into the repository it received through its constructor. It includes repository headers to use that instance and never constructs one: the C++ form of `role-files` §7 "`api` types pass, values do not". The header compiles without any QtQuick include and the build does not give it `Qt5::Quick`. It exposes the list as `QAbstractItemModel *` so the concrete model stays private. On error it keeps the rows and sets `errorText` (`mvvm` §8).
- **ui**: declarative bindings to the ViewModel and handlers that call its commands (§5).

## 3. The module's public API and composition roots

`Module` exists so the repository and the list model **never have to be public types**: the module assembles itself.

```cpp
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

- `module.cpp` holds `struct Module::Impl { Repository repository; NameViewModel viewModel; }` with members **declared in dependency order**: members construct in declaration order, and `viewModel(&repository)` needs a live repository. The compiler does not warn; `-Wreorder` only compares the initializer list against declarations.
- The public ViewModel header forward-declares the repository and the model. Its constructor is visible from outside, but nothing outside can construct the arguments: the public API boundary expressed in C++ rather than in a linter.
- **Constructor injection, no container.** `main()` creates the cross-cutting repositories on the stack, each `Module`, the mediator, registers types with QML, triggers the first load, then loads QML (`mvvm` §4 for why the order matters). Stack objects die in reverse order, so anything registered into the QML engine is declared before the engine.
- The clock is a `std::function<QDate()>` parameter with an empty default the constructor replaces with `QDate::currentDate`.

Full skeletons with ownership and lifetime notes: [`references/module-api.md`](references/module-api.md).

## 4. Linking modules

| Shape | When | Example |
| --- | --- | --- |
| **Argument** | module A genuinely needs module B's data | `expenses::Module(category::CategoryRepository *)`: declared in the constructor and in the build file |
| **Mediator in `app`** | "something happened in A, B should react" and neither should know the other | `AppViewModel` connects `expenses.dataChanged → report.refresh` in one visible line |

`AppViewModel` owns no data: pointers to the modules' ViewModels, a status line, connection info. It collects every module's `errorText` into one status, so a new module is added to its error candidates or its errors never reach the UI.

## 5. QML side

- **The View receives its ViewModel as a typed property**: `property ExpensesViewModel vm`. The type exists in QML because `main.cpp` registered it with `qmlRegisterUncreatableType`; QML must know the type even though it never instantiates it. The mediator is registered with `qmlRegisterSingletonInstance`, which gives it a type; `setContextProperty` would give it `var` and hide typos until runtime.
- **Pages are thin**: `Item { SomeView { anchors.fill: parent; vm: App.some } }`. Logic in a page escaped from a module.
- **No two-way binding**: `text: vm.searchText` plus `onTextEdited: vm.searchText = text`. Use the user-action signal (`onActivated`, `onTextEdited`), not the change signal (`onCurrentIndexChanged`).
- **Dialogs close only on success.** A command returns `bool`; with `standardButtons` the dialog closes before you can read it. Give the dialog its own footer buttons and call `accept()` only when the command returned `true`.
- **Reactivity is per property.** Every `Q_PROPERTY` bound in QML needs a `NOTIFY` that actually fires; a forgotten `emit` is the one rule the build cannot check, and the screen just stops updating. Write the compare-assign-emit ritual once per class (a helper for single fields, one private `applyX()` for multi-field state).
- **Resources (Qt 5)**: every `.qml` and `qmldir` is listed in a `.qrc` with `alias`, so the FEOD layout on disk and the QML import tree can differ. A forgotten file builds fine and fails at runtime with `module "x" is not installed`.

## 6. Tests

Unit tests live in the module's `tests/` and run with no PostgreSQL and no display: the repository is replaced by a subclass overriding its virtual methods, the clock by a fixed lambda. A domain or `common` test needs no application object (`QTEST_APPLESS_MAIN`). A test linking two modules' targets is an integration test at project level. Registration with per-role include access is **[cmake]**.

## 7. Optional sugar seen in the source project

The source project shortened `Q_PROPERTY` boilerplate with macros (`PROP_READONLY / WRITABLE / COMPUTED` generating property, getter and field), wrapped "compare, assign, emit" into one template helper, and used a tiny `not_null<T *>` whose deleted `nullptr_t` constructor turns a null argument into a compile error. These are stylistic contracts; adopt them only if the project wants them. If it does, the macro header must be on moc's include path for every target whose header uses it, or the properties silently vanish from the meta-object while the code still compiles. Guard that with a test that walks `staticMetaObject` and asserts each expected property and its writability.

## 8. Recipes

Step-by-step procedures in [`references/recipes.md`](references/recipes.md):

1. **New module**: directories, `Module`, public ViewModel header, QML, page, composition root, mediator, tab, tests.
2. **New field through every role folder**: schema → domain struct → SQL → role → `roleNames()` → width token → QML → role test.
3. **New `common` entity**: when to extract, how to shape it, why its test needs no private paths.
4. **Linking two modules**: argument versus mediator versus documented exception.

## 9. Review checklist (Qt half)

Run `feod` §9 and the `mvvm` smells too; the build half is in `qt-cmake-boundaries`.

- [ ] Other modules are used only through `include/<name>/`, never through role-folder paths
- [ ] Module QML has no `App`; module C++ has no app headers
- [ ] Domain code is in `domain/`; `model/` holds only list adapters that receive rows via `setRows`
- [ ] Repository methods are `virtual`; the ViewModel takes the repository as a constructor argument
- [ ] ViewModel header has no QtQuick include; the list is exposed as `QAbstractItemModel *`
- [ ] Public headers are two or three, not everything
- [ ] Every property bound in QML has a `NOTIFY` that fires; multi-field state changes through one private apply method
- [ ] `qmldir` lists one public View, the rest `internal`; every `.qml` is in the resource file
- [ ] ViewModel type registered in `main.cpp`; module added to the mediator's error candidates
- [ ] Tab order matches `StackLayout` order (they are linked by index)
- [ ] No domain conditions in QML

## 10. Symptoms and causes

| You see | Cause |
| --- | --- |
| Interface "sometimes does not update" | A setter changed a field without `emit`; or a multi-field change emitted before fixing its invariant |
| Screen shows a value but a status message overwrote the error | Success reported before errors were collected |
| Empty list plus an error line after a DB hiccup | ViewModel wiped rows on error instead of keeping them |
| A module's errors never reach the status bar | Module not added to the mediator's error candidates |
| Clicking the same preset twice re-queries the DB | Setter lacks the "unchanged → return" check |
| Dialog closes and the input is lost although the DB rejected it | `standardButtons` close before the command result is read |
| `module "x" is not installed` at runtime, build was clean | `.qml` or `qmldir` missing from the resource file, or the type missing from `qmldir` |
| `App.x` is an object without properties in QML | ViewModel type not registered with `qmlRegisterUncreatableType` |
| A combo box shows a placeholder entry in an input form | The form reused the filter list that carries the pseudo-item "all"; expose a separate list for input |
| A test of the domain suddenly needs the repository header | Database access leaked into `domain`; the role matrix caught it |

## 11. Qt 6 deltas

- `qt_add_qml_module(target URI ... QML_FILES ...)` replaces the hand-written `.qrc` + `qmldir`: the QML half of the public API moves to the CMake call, and `internal` types become non-exported QML files. Level and role rules are unchanged; only the packaging step in recipe 1 differs (`qt-cmake-boundaries`).
- `required property SomeViewModel vm` replaces the plain `property`; a page that forgets to pass `vm` fails at load instead of throwing `TypeError`s per binding.
- `qmlRegisterSingletonInstance` and `qmlRegisterUncreatableType` still work; `QML_ELEMENT` / `QML_SINGLETON` in the C++ headers are the declarative alternative.
- `QRegularExpression` only; `QRegExp` is gone. `QVariant::type()` becomes `typeId()`.

## Related skills

| Need | Load |
| --- | --- |
| Levels, public API, exceptions | `feod` |
| What each role owns, mediator, errors, test seams | `mvvm` |
| The role list and role matrix | `role-files` |
| CMake targets that enforce all of the above | `qt-cmake-boundaries` |
