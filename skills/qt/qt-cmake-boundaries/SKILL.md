---
name: qt-cmake-boundaries
description: Make CMake enforce architecture boundaries in a Qt / C++ project so that a forbidden dependency is a compile error, not a code-review comment — one OBJECT library per MVVM layer with an explicit "sees" list of sibling layers, a STATIC module target assembled from the layers' objects with a public facade include dir and a pointed PRIVATE list, PUBLIC vs PRIVATE vs INTERFACE linking, $<LINK_ONLY:> to link a library without granting its headers, per-module unit-test registration with layer access, plus the Qt-specific traps (AUTOMOC needs macro headers on the include path or properties vanish silently, rcc rejects "--" in .qrc comments, RUNTIME_OUTPUT_DIRECTORY when targets move into subdirectories). Load whenever writing or reviewing CMakeLists.txt in a Qt project, adding a module or a layer, wiring a new library, deciding PUBLIC/PRIVATE, fixing "No such file or directory" for a file that exists, "undefined reference" after adding a layer, or a Q_PROPERTY that QML cannot see. Copyable templates in references/. The architecture itself (levels, layers, facade, mediator) is the sibling skill qt-modular-mvvm.
---

# Qt CMake boundaries

A layer diagram enforced by discipline is broken the first time someone is in a hurry. This skill turns the diagram into include paths and link lines, so a model that reaches for the database does not compile.

## Provenance and precedence

- Harvested 2026-09-03 from a Qt 5.15 / CMake 3.16+ teaching project whose layer matrix was probed empirically: every forbidden include in the tables below produced the quoted compiler error.
- **Project conventions win.** Keep the project's target naming, its helper functions, its minimum CMake version. Templates here use `${PROJECT_NAME}_` as a target prefix and function names `add_layer` / `add_unit_test`; rename to taste, keep the mechanics.
- CMake ≥ 3.16 is assumed (Qt's own floor for `find_package(Qt5)` with AUTOMOC works fine there). Where a newer feature would simplify something, the note says which version.
- Architecture doctrine (what the layers *mean*) is the sibling skill **qt-modular-mvvm**. This skill assumes you already know which layer may see which.

## 1. The mechanism in one paragraph

An `#include "x/y.h"` compiles only if some `-I` directory contains `x/y.h`. CMake hands out `-I` per target through `target_include_directories`, and `PRIVATE` paths do not propagate to anything that links the target. So: give each layer its **own target** with its **own include paths**, and a layer can only include what you listed for it. A missing path fails as `fatal error: data/repo.h: No such file or directory` while the file sits on disk. That error is the boundary working.

Two consequences that make the pattern cheap:

- Layers are `OBJECT` libraries: a bag of `.o` files with their own compile rules, no archive, no extra artifact for consumers.
- The module is one `STATIC` library assembled from `$<TARGET_OBJECTS:...>` of its layers. Consumers see one target and never learn the layers exist.

## 2. Layer targets and the visibility matrix

```cmake
add_layer(expenses domain    SOURCES domain/include/domain/expense.h domain/expense.cpp)
add_layer(expenses data      SOURCES data/include/data/repo.h data/repo.cpp
                             SEES domain
                             LINKS Qt5::Sql ${PROJECT_NAME}_common_db)
add_layer(expenses model     SOURCES model/include/model/listmodel.h model/listmodel.cpp
                             SEES domain
                             LINKS ${PROJECT_NAME}_common_money)
add_layer(expenses viewmodel SOURCES include/expenses/viewmodel.h viewmodel/viewmodel.cpp
                             SEES domain data model
                             LINKS ${PROJECT_NAME}_common_money ${PROJECT_NAME}_common_sugar
                             API)
```

`add_layer` (full source in `references/Layers.cmake`) creates `${PROJECT_NAME}_expenses_<layer>` as an OBJECT library, adds `<layer>/include` privately, adds `<seen>/include` for every `SEES` entry after checking the directory exists (a typo fails at configure time with a readable message instead of mid-compilation in someone else's `.cpp`), adds the module's public `include/` when `API` is given, and links `LINKS` privately. Read `SEES` as the architecture declaration: in a frontend project this list lives in a boundaries linter and runs at best in CI; here the compiler runs it on every build.

Why each line is where it is:

- **`domain` sees nothing**, not even siblings. That is why it tests without a database, a window or a `QCoreApplication`.
- **`Qt5::Sql` goes only to `data`.** `#include <QSqlQuery>` in `model` or `domain` becomes `fatal error: QSqlQuery: No such file or directory`. The rule "only data touches the database" stops being a convention.
- **`model` does not see `data`.** `#include "data/repo.h"` in the model is the most common violation, and it now fails with "No such file".
- **The public header is compiled in the `viewmodel` layer (`API`).** It has `Q_OBJECT`; AUTOMOC pairs a header with its same-name `.cpp` *inside one target*, so the pair must live together. Keeping the public header in the module target and its `.cpp` in a layer target invites moc trouble.
- **Relative paths are from the module directory.** A `function` does not change directory scope (unlike `add_subdirectory`), so `domain/include` inside the helper means `<module>/domain/include`.
- A header-only layer (a domain that is one struct) needs no target: `SEES domain` only adds a path, it never references a target. List the header among the module target's sources so IDEs show it.

## 3. The module target

```cmake
add_library(${PROJECT_NAME}_module_expenses STATIC
    include/expenses/module.h
    module.cpp
    $<TARGET_OBJECTS:${PROJECT_NAME}_expenses_domain>
    $<TARGET_OBJECTS:${PROJECT_NAME}_expenses_data>
    $<TARGET_OBJECTS:${PROJECT_NAME}_expenses_model>
    $<TARGET_OBJECTS:${PROJECT_NAME}_expenses_viewmodel>
)

target_include_directories(${PROJECT_NAME}_module_expenses
    PUBLIC  include                        # the facade: #include "expenses/module.h"
    PRIVATE data/include domain/include    # POINTED, not the module root
)

target_link_libraries(${PROJECT_NAME}_module_expenses
    PUBLIC  Qt5::Core ${PROJECT_NAME}_common_money ${PROJECT_NAME}_common_sugar
    PRIVATE ${PROJECT_NAME}_warnings $<LINK_ONLY:Qt5::Sql>
)
```

Four things that are easy to get wrong here:

1. **`PUBLIC include`, not `include/expenses`.** Consumers write `#include "expenses/module.h"`; the module-name prefix is what keeps two modules' `module.h` from colliding. Publicness is the word `PUBLIC`, not the folder name `include`.
2. **`PRIVATE` is pointed.** `module.cpp` constructs the repository, so it needs `data/include`; the repository header includes a domain type, so it also needs `domain/include` — include paths are transitive through `#include`s but **not inherited from the layer targets** (they were `PRIVATE` there). `PRIVATE .` would reopen every boundary you just declared.
3. **`$<TARGET_OBJECTS:>` carries objects, not link requirements.** An OBJECT library compiles; it links nothing. If the `data` objects reference QtSql symbols, the module target must supply the library or you get `undefined reference to QSqlQuery::...` at link time.
4. **Use `$<LINK_ONLY:Qt5::Sql>` for that**, not plain `Qt5::Sql`: plain linking would also hand QtSql's include paths to `module.cpp`, and the "only data touches SQL" boundary would leak exactly here. `LINK_ONLY` links without granting the right to compile against it.

`PUBLIC` vs `PRIVATE` in `target_link_libraries`, the whole rule: **a type from the dependency appears in one of this target's headers → `PUBLIC`; only in `.cpp` files → `PRIVATE`.** A `using Alias = other::Type;` in a public header counts as appearing. Header-only helpers whose macros expand inside a public header (property macros, `not_null`) must be `PUBLIC` too, or consumers get "macro not declared".

## 4. Header-only entities

```cmake
add_library(${PROJECT_NAME}_common_sugar INTERFACE)
target_include_directories(${PROJECT_NAME}_common_sugar INTERFACE include)
target_link_libraries(${PROJECT_NAME}_common_sugar INTERFACE Qt5::Core)

# INTERFACE libraries accept sources only from CMake 3.19; on 3.16 list the
# headers through a custom target so IDEs show them.
add_custom_target(${PROJECT_NAME}_common_sugar_headers SOURCES include/sugar/property.h)
```

Link it even though there is nothing to link. AUTOMOC collects moc's `-I` flags from the *target's* include directories; a header that uses a property macro from an unlinked header-only library compiles fine (the getter is visible to the compiler) but moc cannot expand the macro, sees no `Q_PROPERTY`, and the property is absent from the meta-object. QML reports `unable to assign` or shows nothing, with a clean build. Guard it with a test that asserts each property exists in `staticMetaObject`.

A helper that is header-only but depends on a library the project deliberately restricts (e.g. `db/query.h` including `<QSqlQuery>` inside a STATIC `common_db` that links `Qt5::Sql` **PRIVATE**) stays usable only by targets that have that library themselves — which is exactly the layers you gave it to. Making the dependency `PUBLIC` would dissolve the restriction silently.

## 5. Tests inside modules

```cmake
# modules/expenses/tests/CMakeLists.txt
add_unit_test(tst_expenserules     unit ${PROJECT_NAME}_module_expenses SEES domain)
add_unit_test(tst_expenselistmodel unit ${PROJECT_NAME}_module_expenses SEES model domain)
add_unit_test(tst_expensesviewmodel unit ${PROJECT_NAME}_module_expenses ${PROJECT_NAME}_common_testing
              SEES data domain)
```

`add_unit_test` (full source in `references/Tests.cmake`) builds `<name>.cpp` next to the file, links the listed targets plus `Qt5::Test`, gives the test `../<layer>/include` for each `SEES` entry (validated like layers), sets `RUNTIME_OUTPUT_DIRECTORY` so all test binaries land in one `build/tests/` regardless of which subdirectory declared them, registers with `add_test`, and applies `QT_QPA_PLATFORM=offscreen`, a timeout and a label.

Why the pieces exist:

- **Tests see private layers on purpose.** A test is part of the module, not a consumer; it must subclass the real repository to fake it. Granting the paths per layer keeps the grant readable: "this test looks into `data` and `domain`, nowhere else". The day the domain test needs `data`, the diff of this file shows database access leaking into the domain.
- **The label is a mandatory positional parameter.** Labelling tests in a second step means a forgotten test silently drops out of `ctest -L unit`. CMake refuses to call the function without the argument.
- **One output directory.** CI that runs test binaries directly (for JUnit output on CMake < 3.21) needs a stable path; without the property the path depends on which module declared the test.
- Gate the whole tree on an `option(BUILD_TESTS ON)` and `find_package(Qt5 COMPONENTS Test)` **inside** that `if`, so a `-DBUILD_TESTS=OFF` build does not require QtTest. Put test-only helper targets (anything linking `Qt5::Test`) inside the same `if`.
- A test that links more than one module's target is an integration test: register it at project level, not inside a module.

## 6. Application target and resources

- **`RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}`** on the executable once `add_executable` moves from the root into `src/app/`: CMake mirrors the source tree, so the binary would otherwise land in `build/src/app/` and every script and README pointing at `build/<app>` breaks quietly.
- **The executable links modules only through their facades.** Its link list names module targets; it never adds a module's layer paths. Remove a module's public headers and the build fails *here*: that is the proof the facades are real.
- **Qt 5 resources.** All `.qml` and `qmldir` files of all levels go into one `.qrc` in `app/` (QML is embedded, and there is one executable), with `alias` so the resource tree can differ from the FEOD directory tree. Paths on the left of `alias` are relative to the `.qrc` file's directory.
- **rcc forbids `--` inside an XML comment.** A dashed separator line in a `.qrc` comment fails with `Expected '>', but got '-'`, which points nowhere near the cause. Use `=` for separators there.
- Set `CMAKE_AUTOMOC ON` and `CMAKE_AUTORCC ON` at the root; `CMAKE_EXPORT_COMPILE_COMMANDS ON` for clang-tidy and clangd.
- Warnings as a dependency: an `INTERFACE` target carrying `-Wall -Wextra -Wpedantic -Wshadow -Wnon-virtual-dtor -Woverloaded-virtual` (`/W4 /permissive- /utf-8` on MSVC — `/utf-8` is mandatory when sources contain non-ASCII string literals or they turn to garbage silently). Link it `PRIVATE` everywhere; add `-Werror` only in CI via `CMAKE_CXX_FLAGS`, so a local warning never blocks work.

## 7. Recipe: add a module's build files

1. `modules/<m>/CMakeLists.txt` from `references/module-CMakeLists.cmake`: layer calls with `SEES` (SQL only on `data`, `model` without `data`), then the STATIC target with `PUBLIC include` and pointed `PRIVATE`, `$<LINK_ONLY:>` for libraries the layers' objects need, `if(BUILD_TESTS) add_subdirectory(tests)`.
2. `add_subdirectory(modules/<m>)` in the root, in dependency order (the order documents the level hierarchy even though CMake would resolve forward references).
3. Add the module target to the executable's `target_link_libraries`.
4. `modules/<m>/tests/CMakeLists.txt` with `add_unit_test(... SEES ...)`.
5. Qt 5: add the module's `qmldir` and `.qml` files to the `.qrc` with aliases. Qt 6: see §9.
6. Build and **probe one boundary on purpose**: add `#include "data/repo.h"` to the model, confirm "No such file or directory", remove it. A boundary that was never seen failing has never been verified.

## 8. Review checklist (build half) and symptoms

- [ ] Every layer declared through the helper; `model`'s `SEES` does not contain `data`; SQL library only in `data`'s `LINKS`
- [ ] Every source file listed (a file on disk but not in `SOURCES` is `undefined reference` later)
- [ ] Module target: `PUBLIC include`, pointed `PRIVATE <layer>/include` list, no `PRIVATE .`
- [ ] Libraries the layers' objects need are supplied by the module target, via `$<LINK_ONLY:>` when their headers must stay out of reach
- [ ] `PUBLIC` for anything appearing in public headers (including macro headers and type aliases), `PRIVATE` otherwise
- [ ] Header-only helper targets are linked by every target whose *header* uses their macros (moc)
- [ ] Module target added to the executable's link list; `add_subdirectory` added to the root
- [ ] Tests registered with label and per-layer `SEES`; multi-module tests at project level
- [ ] `find_package(... Test)` and test-only targets inside `if(BUILD_TESTS)`
- [ ] Executable and tests have `RUNTIME_OUTPUT_DIRECTORY`; scripts and docs point at those paths
- [ ] Every new `.qml`/`qmldir` in the `.qrc` (Qt 5) or in `qt_add_qml_module` (Qt 6)

| You see | Cause |
| --- | --- |
| `fatal error: <file>: No such file or directory`, file exists, in another module | You used a private path; go through `include/<module>/` |
| Same, file in **your** module | Layer boundary: this layer's `SEES` does not grant that path; usually the model reaching into `data` |
| `fatal error: QSqlQuery: No such file or directory` | SQL is granted to `data` only; the query belongs in a repository |
| Configure error "layer 'X' listed in SEES but X/include does not exist" | Typo in `SEES`, caught at configure time as designed |
| `undefined reference to ...` right after adding a layer | Objects need a library the module target does not link; add it (usually as `$<LINK_ONLY:>`) |
| `undefined reference` to your own function | File not listed in `SOURCES`, or target not linked |
| `domain/x.h: No such file` while compiling `module.cpp`, which never includes it | Transitive include through the repository header; add `domain/include` to the module's pointed `PRIVATE` |
| `PROP_READONLY was not declared` in a consumer | Macro header's target linked `PRIVATE` where it had to be `PUBLIC` |
| QML `unable to assign` / property empty, build clean | moc did not expand a property macro: header-only target not linked by the target owning the header |
| `Expected '>', but got '-'` from rcc | `--` inside a `.qrc` XML comment |
| Binary not where scripts expect after moving `add_executable` | Missing `RUNTIME_OUTPUT_DIRECTORY` |
| `Target links to target Qt5::Test but the target was not found` | `find_package(Qt5 COMPONENTS Test)` was deleted with an old tests file; it belongs inside `if(BUILD_TESTS)` at the root |
| A macro with a template argument containing a comma fails | The comma splits macro arguments; introduce a `using` alias first |
| Removing one `#include <QSqlError>` breaks three unrelated files | They relied on a transitive `<QVariant>`; include what you use |

## 9. Qt 6 deltas

- `qt_add_qml_module(target URI Modules.Expenses VERSION 1.0 QML_FILES ExpensesView.qml AddDialog.qml ...)` replaces the `.qrc` + `qmldir` pair and generates both. Per-module QML targets become natural, and `internal` types are simply files not exported; the layer/facade mechanics for C++ are unchanged.
- `qt_standard_project_setup()` sets AUTOMOC/AUTORCC and modern policies in one call.
- `find_package(Qt6 COMPONENTS Core Quick Sql Test)` and `Qt6::` targets; the `$<LINK_ONLY:Qt6::Sql>` trick works identically.
- `qt_add_executable` instead of `add_executable`; `RUNTIME_OUTPUT_DIRECTORY` advice is unchanged.

## References

- `references/Layers.cmake` — `add_layer(module layer SOURCES ... [SEES ...] [LINKS ...] [API])`, with the configure-time `SEES` validation.
- `references/Tests.cmake` — `add_unit_test(name label libs... [SEES ...])`.
- `references/module-CMakeLists.cmake` — a complete module build file to copy and rename.
