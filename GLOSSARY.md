# scobar-skills architecture vocabulary

The terms the architecture skills (`feod-preset`, `mvvm`, `role-files` and their stack skills) share. A skill uses a term from here in exactly this meaning, or does not use it.

## Skill family

**Core skill**:
A stack-neutral skill that states one idea: `feod-preset`, `mvvm` or `role-files`. The official `feod` skill (Sdju/feod) sits under `feod-preset` and is installed separately.
_Avoid_: base skill, generic skill

**Stack skill**:
A skill that applies the core skills to one stack and adds only what is specific to it (`frontend-mvvm`, `qt-mvvm`).
_Avoid_: adapter skill, flavour

**Boundaries skill**:
A stack skill whose only job is to make a tool reject what the core forbids: a linter on the frontend, the compiler via CMake on Qt.
_Avoid_: lint skill, enforcement layer

## FEOD

**Level**:
One of the five top-level folders `app`, `pages`, `modules`, `common`, `global`.
_Avoid_: layer, tier, slice

**Module**:
A folder on the `modules` level holding one product responsibility, used from outside only through its public API.
_Avoid_: feature, slice, package

**Submodule**:
A module nested in `modules/<name>/modules/<sub>/` for a stable part of its parent's responsibility, invisible outside unless the parent exports it. It may reach its parent's internals; the parent reaches it only through its `index.ts`.
_Avoid_: child module, sub-feature

**Transit module**:
A `modules/<group>/<child>/` container whose children share a private core in `<group>/_/index.ts` (FEOD "сквозной модуль").
_Avoid_: group module, folder module

**Private page module**:
A `pages/_<name>/` folder usable only by the page that owns it.
_Avoid_: page helper, page component

**Common entity**:
A file on the `common` level, at most one folder deep, whose purpose can be stated without naming the product domain. It has no `index.ts`; consumers import the file.
_Avoid_: shared, util, helper

**Public API**:
A module's `index.ts`: the contract it exposes to the rest of the code; everything else in it is internal.
_Avoid_: facade, barrel, entry point

**Deep import**:
An import from outside a module that bypasses its `index.ts` and reaches an internal file or folder.
_Avoid_: private import, internal import

**Zigzag import**:
An import from one module, or any of its submodules, into a submodule of another module.
_Avoid_: cross import

**Import matrix**:
The table of which level may import which.
_Avoid_: dependency rules, layer rules

## MVVM

**Role**:
What a file is responsible for inside a module. Model, ViewModel and View are the MVVM roles; `route`, `config`, `types`, `lib` are supporting roles.
_Avoid_: layer, tier

**Model**:
The role that owns domain types, domain rules, domain state and turning backend data into them.
_Avoid_: store, service, data layer

**ViewModel**:
The role that owns screen state, user intent and data shaped for one UI.
_Avoid_: controller, presenter, store

**View**:
The role that binds ViewModel output to UI and sends user actions back; it decides nothing.
_Avoid_: component, template, UI layer

**God component**:
A component that fetches, maps and decides on its own instead of binding ViewModel output; the failure MVVM exists to prevent.
_Avoid_: using it for a preset

**Compound component**:
A component split into a root and flat named parts the caller assembles; the root owns UI state, parts read it through context.
_Avoid_: composite, slot component

**Structural prop**:
A prop that shows, hides, replaces or rearranges a part of a component; the trigger to split it into a compound.
_Avoid_: config prop, option

**Preset**:
A fixed assembly of a compound component, inserted as one tag, taking only data and callbacks.
_Avoid_: god component, wrapper, default component

**Facade**:
The ViewModel's promise that the View receives only UI-shaped data and never a backend shape.
_Avoid_: using it for a module's public API

**Mediator**:
Whoever wires two parts that must not know each other by passing functions and values as arguments; the ViewModel inside a module, a page or `app` between modules.
_Avoid_: event bus, orchestrator, god object

**Composition root**:
The one place where the object graph of a module or of the app is constructed and dependencies are injected.
_Avoid_: DI container, bootstrap

## Role files

**Role marker**:
What tells a file's role: a dot-suffix in its name (`checkout.vm.ts`) or the role folder it sits in.
_Avoid_: file type, tag

**Subject**:
The part of a file name before the role marker, naming the concept the file is about.
_Avoid_: prefix, base name

**Headless module**:
A module that deliberately has no View of its own and says so in its README.
_Avoid_: logic-only module
