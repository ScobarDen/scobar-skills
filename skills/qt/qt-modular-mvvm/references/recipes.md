# Recipes

Four procedures. Each lists every place that must change, because the price of the layered layout is exactly that: more places per change, each of them small and each of them checkable. Steps marked **[cmake]** are detailed in the sibling skill qt-cmake-boundaries.

## Recipe 1 — New module `budget`

Copy the smallest existing module (a read-only one, without dialogs) rather than starting blank.

1. **Directories and files**
   ```
   modules/budget/
     include/budget/budgetviewmodel.h, module.h     public
     module.cpp
     domain/include/domain/budget.h  domain/budget.cpp
     data/include/data/budgetrepository.h  data/budgetrepository.cpp
     model/include/model/budgetlistmodel.h  model/budgetlistmodel.cpp
     viewmodel/budgetviewmodel.cpp
     ui/qmldir  ui/BudgetView.qml
     tests/CMakeLists.txt  tests/tst_budgetviewmodel.cpp
   ```
   A header-only layer (a domain of one struct) needs no `.cpp`; the layer then has no build target, only a path.

2. **Facade.** `module.h` + `module.cpp` from `module-facade.md` §1–2. Cross-module dependencies as constructor arguments; never construct another module inside.

3. **Public ViewModel header** from `module-facade.md` §3: forward-declared internals, `QAbstractItemModel *` for the model, injected clock, no data load in the constructor.

4. **[cmake] Layer declaration and module target.** One `CMakeLists.txt` inside the module: four layer calls with the visibility matrix (`domain` sees nothing, `data` sees `domain` and gets the SQL library, `model` sees `domain` only, `viewmodel` sees all three plus the public header), then one STATIC module target assembled from the layers' objects with `PUBLIC include` and a *pointed* `PRIVATE` on just the layer paths `module.cpp` needs. Add `add_subdirectory(modules/budget)` to the root and the module target to the executable's link list.

5. **QML.** `ui/qmldir` exports `BudgetView` and marks everything else `internal`. `BudgetView.qml` declares `property BudgetViewModel vm` and never touches `App`.

6. **Resources (Qt 5).** Add `qmldir` and every `.qml` to the app's `.qrc` with an `alias` under `modules/budget/`. Missing file → clean build, runtime `module "budget" is not installed`. (Qt 6: `qt_add_qml_module` instead; see qt-cmake-boundaries.)

7. **Page.** `pages/BudgetPage.qml`: `Item { BudgetView { anchors.fill: parent; vm: App.budget } }`. Add it to `pages/qmldir` and to the `.qrc`. If the page grows logic, that logic belongs in the module.

8. **Composition root** (`main.cpp`): include the two public headers, create `budget::Module budgetModule(...)`, `qmlRegisterUncreatableType<budget::BudgetViewModel>(...)`, pass `budgetModule.viewModel()` to the mediator. Registration is mandatory even though QML never instantiates the type: without it `App.budget` is a property-less object and `property BudgetViewModel vm` does not compile.

9. **Mediator.** `Q_PROPERTY` + getter + field; subscribe `errorTextChanged → collectError`; add `m_budget->errorText()` to the error candidates array; wire cross-module reactions (`dataChanged → refresh`) if any. The candidates array is the step everyone forgets and the only one that fails silently.

10. **Tab.** A `TabButton` in the root QML and a `BudgetPage {}` in the `StackLayout`, in the same position: they are linked by index.

11. **Tests.** `tests/CMakeLists.txt` registers a unit test that may see the module's `data` and `domain` layers (test-time access to internals is allowed; the test is part of the module). The ViewModel test uses a fake repository subclass and a fixed clock and needs no database. **[cmake]** for the test registration helper.

## Recipe 2 — New field `shop` through every layer

Eight places. Know them before promising the feature.

1. **Schema** — the column in the DDL (and the seed). If the DB is seeded from a mounted script directory, the volume must be recreated for the change to apply.
2. **Domain struct** — `QString shop;` in `domain/include/domain/expense.h`.
3. **SQL** — append `e.shop` to the end of the `SELECT` list and read it by the next index; add it to the `INSERT`. Indices follow `SELECT` order and nothing checks them: **append, never insert in the middle.**
4. **Role** — `ShopRole` in the model's `enum Role`.
5. **Role delivery** — the `case ShopRole:` in `data()` and `{ ShopRole, "shop" }` in `roleNames()`.
6. **Width token** — a column width constant in the shared theme so header and rows cannot drift apart.
7. **QML** — a header column and a row cell reading `model.shop`.
8. **Role test** — the `roleNames()` test pins the new name; renaming the role breaks QML silently otherwise.

## Recipe 3 — New `common` entity `period`

1. **Qualify it.** Explain it without a product term ("a date range whose start is not after its end"). If you cannot, it is a module.
2. **Shape.** A value type or free functions, no QObject, no inheritance: `struct Range { QDate from, to; }` plus pure functions (`withFrom`, `lastDays`, `currentMonth`, `text`). ViewModels keep their own `Q_PROPERTY`s and only *apply* the rules; `common` never emits signals for them.
3. **Target.** `common/period/` with `include/period/period.h`, a `.cpp`, its own `CMakeLists.txt` (STATIC, or INTERFACE if header-only), added to the root. **[cmake]**
4. **Consumers.** Each layer that uses it lists it in its own dependencies; the module target lists it `PUBLIC` if the type appears in a public header (an alias like `using Today = period::Today` counts).
5. **Test.** `common/period/tests/tst_period.cpp`, `QTEST_APPLESS_MAIN`: no private paths needed because the entity is public in full. Move the invariant tests here out of the ViewModel tests; they now test only that the ViewModel emits and re-queries.

## Recipe 4 — Linking two modules

Decide by who needs to know whom:

| Situation | Shape | Where it becomes visible |
| --- | --- | --- |
| `expenses` needs the category lookup to filter | **Argument**: `expenses::Module(category::CategoryRepository *)` | the constructor signature; the module target links the other module `PUBLIC`; `main.cpp` passes the instance |
| adding an expense should refresh the report | **Mediator**: `connect(expenses.dataChanged, report.refresh)` in `AppViewModel` | one line in the mediator; the two module targets do **not** link each other |
| the report aggregates over a table the category module owns | **Documented exception**: the report repository joins the table in SQL | a comment in the repository and in the module's build file explaining why the aggregation cannot go through the other module's API |

Test for hidden links: a QML file importing another module's directory (`import "../category"`) is a link too, and an undeclared one if the build file does not show it. Either declare it (link the module, mention it in the docs' list of links) or extract a neutral primitive into `common/ui` and let the product-named wrapper stay in the owning module.
