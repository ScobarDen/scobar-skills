---
name: frontend-testing-approach
description: A practice-tested approach to frontend testing — deciding whether a test is worth writing at all, what each layer actually proves, the four unit-test rules, an L0–L4 ladder of test helpers that kills repeated boilerplate (render factories, a shared conformance suite, a suite registry with only/skip, a custom render with setProps, family suites), test-id contracts instead of text queries, a11y as infrastructure, and how to review AI-written tests. Load when writing or reviewing frontend/React tests, setting up a component test suite, extracting test helpers to stop repeating the same checks, deciding what deserves coverage, or judging tests an agent produced.
---

# Frontend Testing Approach

A working doctrine for testing UI code: what to test, what each layer proves, and how to keep per-component tests small.

## Provenance and precedence

- Derived from the practice of `debabin` / `siberiacancode` — his live reasoning while preparing a talk on autotests (`t.me/artalog`-adjacent stream `youtube.com/watch?v=Kc0AvJFP3vY`, cited below as `[mm:ss]`) plus the code that actually ships in his repos (`juniors-bootcamp-uikit`, `siberiacancode/core/packages/testids`, `mock-config`, `reactuse`), harvested 2026-08-27.
- **Project conventions win.** If the repo already has a testing style, ESLint rules, or a runner setup, follow it and mention the divergence in one line — do not refactor a suite to match this file.
- His talk had not been delivered when this was harvested: the component-level patterns below are shipped code; the Next/SSR and e2e parts were stated plans. Marked where it matters.
- For Reatom-specific test mechanics (context isolation, `mock`, async timing), load `reatom-testing` instead — that is a different axis.

## 1. Gate: does this deserve a test?

Never answer "should we test this" in the abstract. Answer it per unit of code, on three axes:

- **Project criticality.** Vehicle firmware, banking, medical: read everything, test everything. Marketing landing: the result is what matters, not how it was written `[1:36:22]`.
- **Section criticality.** Inside one project there is the core (business logic, money, access) and there is typical work — one more endpoint in an API module, another CRUD admin page. For the typical kind, a smoke test is a sufficient gate `[1:37:25]`.
- **Cost of a silent break.** If a failure surfaces immediately on first run, a test buys little. If it can rot unnoticed (money math, permissions, data loss), it buys a lot.

Two consequences worth stating out loud:

- "Most projects live without tests" is an observation, not a sin `[2:22:33]`. Do not moralize about missing coverage; price it.
- **A test only proves something if its author understands both the product and testing.** "Writing adequate autotests without immersing yourself in testing and in the product is impossible — you will miss something, 100%" `[1:13:00]`. This is why tests cannot be delegated to someone without context — human or model.

When a codebase has no tests at all: start from the critical path and priority-zero flows, not from a coverage target.

## 2. Layers, and what each one actually proves

| Layer | Proves | Notes |
| --- | --- | --- |
| Unit | A function/class/component honors its contract | "Checking pure functionality" — this is the only layer where **code coverage is a valid proxy for test coverage** `[1:51:31]` |
| Component | The component behaves under real interaction, in a real DOM | Where the conformance suite pays off (§4) |
| Integration | Feature-level flows against mocked transport | Playwright + mocks (MSW, native Playwright mocks, or a mock-config style lib) `[2:26:00]` |
| E2E | A thin top slice | Deliberately minimal `[1:51:55]` |

**SSR changes the test case, not just the setup.** When a tester writes a case while watching the request in the network tab, that is one test; with SSR/streaming and no visible request, it is a different test with different assertions. Budget for that explicitly instead of porting client-side cases `[2:19:34]`. (Stated plan, not yet shipped code.)

## 3. The four unit-test rules

1. **Cover every parameter** — each prop/argument gets an assertion.
2. **Combinations only when parameters interact.** Usually they are independent; a combinatorial matrix is waste.
3. **Cover implementation specifics, not just the contract.** The reason this rule exists: a listener-removal bug (a new function reference passed to `removeEventListener`) leaked memory while the public contract looked fine `[2:22:33]`. Ask "what did I get subtly wrong in *this* implementation" and test that.
4. **Compound components: one `describe` per part, plus one combined render.** Every block of a compound system must be verified on its own; a single blob test over the whole tree hides which part broke `[2:47:10]`.

## 4. Killing boilerplate: the helper ladder

Most component tests repeat the same checks. The cure is a layer of test helpers so each component's own file contains **only what is unique about that component**. Escalate one rung at a time — a five-component project should stop at L1.

The reference implementation is Base UI's `packages/react/test/` module (`describeConformance.tsx`, `createRenderer.ts`, `conformanceTests/*`, `popupConformanceTests.tsx`, interaction/time helpers, all re-exported from one `index.ts`). It is worth reading before designing your own. Note that it stands on `@mui/internal-test-utils` — published, but internal to MUI: **borrow the idea, not the dependency**.

### L0 — Local render factory + test-id map

Zero infrastructure, immediate payoff. In the test file itself:

```tsx
const ROOT_TEST_ID = 'theme-switcher';
const ITEM_TEST_ID = (theme: Theme) => `theme-switcher-item-${theme}`;

const renderSwitcher = (props: Partial<ComponentProps<typeof ThemeSwitcher>> = {}) =>
  render(
    <ThemeSwitcher data-testid={ROOT_TEST_ID} {...props}>
      {THEMES.map(theme => (
        <ThemeSwitcherItem key={theme} data-testid={ITEM_TEST_ID(theme)} value={theme} />
      ))}
    </ThemeSwitcher>,
  );
```

Every case becomes one line of setup plus its assertions, and the ids are computed, not copy-pasted.

### L1 — One shared conformance suite

The repeated checks extracted into a single helper, called at the top of each component's test file. What belongs in it:

- renders, with the expected `tagName`, root class, and `data-slot`;
- a custom `className` **merges** instead of replacing the base class;
- native attributes (`id`, `aria-label`) and `style` are forwarded;
- **no a11y violations** (axe);
- `asChild` (or equivalent polymorphism) renders the other tag while keeping slot and classes;
- **SSR smoke: `renderToString` does not throw.**

```tsx
interface ConformanceOptions {
  tag: string;
  slot: string;
  rootClass: string;
  asChild?: boolean;
  asChildTag?: keyof JSX.IntrinsicElements;
  wrapper?: (node: ReactNode) => ReactElement;
}

export const testConformance = (element: ReactElement, options: ConformanceOptions) => {
  const renderElement = (props: Record<string, unknown>) => {
    const node = cloneElement(element, props);
    return render(options.wrapper ? options.wrapper(node) : node);
  };

  it('Should render', () => {
    renderElement({ 'data-testid': 'conformance-root' });
    const root = screen.getByTestId('conformance-root');
    expect(root.tagName).toBe(options.tag);
    expect(root.classList.contains(options.rootClass)).toBeTruthy();
    expect(root.getAttribute('data-slot')).toBe(options.slot);
  });

  // …className merge, attribute/style forwarding, axe, asChild…

  it('Should render on the server', () => {
    const node = cloneElement(element, { 'data-testid': 'conformance-root' });
    expect(() => renderToString(node)).not.toThrow();
  });
};
```

The `wrapper` option is what makes it usable for a compound's inner part, which cannot render without its parent's context:

```tsx
describe('ThemeSwitcherItem', () => {
  testConformance(<ThemeSwitcherItem value='light' />, {
    tag: 'BUTTON',
    slot: 'theme-switcher-item',
    rootClass: styles.theme_switcher_button,
    wrapper: node => <ThemeSwitcher aria-label='Theme'>{node}</ThemeSwitcher>,
  });
  // only the unique behavior below
});
```

### L2 — Suite registry with `only` / `skip`, one file per check

Needed once components are numerous enough that exceptions appear. A flat helper forces a component that legitimately fails one check to either fork the helper or copy the rest; a registry lets it opt out by name:

```ts
const fullSuite = {
  propsSpread: testPropForwarding,
  refForwarding: testRefForwarding,
  renderProp: testRenderProp,
  className: testClassName,
};

const filteredTests = Object.keys(fullSuite).filter(
  key => only.includes(key) && !skip.includes(key),
);

filteredTests.forEach(key => fullSuite[key](minimalElement, getOptions));
```

Call site: `describeConformance(<Component />, () => ({ render, skip: ['refForwarding'] }))`.

Two details from the reference worth copying:

- **One check per file** (`className.tsx`, `propForwarding.tsx`, `refForwarding.tsx`, …). Each is a small `describe` factory taking `(element, getOptions)`, so the set grows by files instead of turning into one unreadable blob. A single check file can hold several `it`s — `propForwarding` covers six variants of prop and `style` forwarding.
- **Fail loudly on a missing option.** Their check files call `throwMissingPropError('render')` when the caller forgot to pass the renderer, instead of failing with a confusing assertion.

### L3 — Your own `render`

Wrap the testing-library `render` once, and every test in the project gets the same free upgrades:

- required providers mounted (theme, i18n, store, router);
- the render already wrapped in `act`;
- an async `rerender`;
- **`setProps(newProps)`** — the biggest single boilerplate killer, since testing a reaction to a changed prop otherwise means cloning the element by hand in every test:

```ts
async function setProps(newProps: object) {
  await rerender(cloneElement(element, newProps));
}
```

### L4 — Thematic suites and interaction/time helpers

The second axis of reuse: not "every component", but "every component of this family".

- **Family suites.** Base UI ships `popupConformanceTests` — one shared body of checks for every popup/overlay. Good candidates in a product codebase: modals/portals, form fields, paginated tables — anywhere a whole class of components shares invariants that are easy to break one at a time.
- **Interaction helpers** (`useTestInteractions`, `firePointer`, `moveMouse`, `enterWithMouse`) instead of assembling raw `fireEvent` sequences per test.
- **Time helpers** (`wait`, `waitForPositioned`, `advanceReactClock`) so waiting is a named call rather than an ad-hoc timeout.
- **Matcher registration in one function** (`addVitestMatchers`) pulled into the shared setup.

### Where to stop

Rungs cost maintenance. L0 and L1 pay for themselves almost immediately; L2 pays off at roughly a dozen components or the first legitimate exception; L3 the moment more than a couple of providers are involved; L4 only when real component families exist. Note what a practitioner adapting this actually did: kept L1, deliberately skipped the registry ("they did it in a fairly complicated way — I did not bother"), and added a11y plus the SSR smoke to his own suite instead `[2:17:14, 2:37:15]`.

## 5. Query contract: test ids, not text

- **Query by `data-testid`, not by visible text.** Text-based queries break on copy edits and are unusable in a multi-locale app; "`data-testid` is not used at all here, that is hideous — searching by text" is his verdict on suites that skip it `[2:43:59]`.
- Assert state through **semantic attributes** — `aria-pressed`, `role`, `data-variant`, `data-slot` — not through whatever class happened to be in the markup.
- Worth industrializing when a project is big enough: generate ids from a schema into typed constants, lint for unused ones, and **strip `data-testid` from the production build** with a bundler plugin (that is what `@siberiacancode/testids` does).

## 6. The evil-cases checklist

Per interactive component, these four earn their place — they are the breaks that ship silently:

1. A caller's handler **composes** with the internal one instead of replacing it (`onClick` + internal `onValueChange`).
2. `preventDefault` in the caller's handler **suppresses** the internal effect.
3. Using a part **outside its provider throws** a clear, asserted message.
4. **Controlled mode** driven by a real `useState` wrapper, verifying state moves as the external value changes — not a mocked setter.

## 7. a11y and coverage as infrastructure

- Register axe matchers in the shared test setup, not per file, and put one a11y assertion inside the conformance suite so every component gets it for free.
- **Coverage on by default in the config**, not a CI-only ritual. Its purpose is to be read: the useful output is "these three hooks have no tests at all", not the percentage `[1:51:31]`.
- Keep the runner config in one shared preset across repos so every project's test environment is identical.
- Do not chase 100%. Coverage is a proxy only for the unit layer; a green number over integration code proves nothing.

## 8. Reviewing AI-written tests

Tests produced by an agent need one specific kind of skepticism:

- **Circular validation proves nothing.** Same author writes the code, writes the tests, and runs them — "wrote the code, wrote the tests, checked its own code with its own tests, all green" `[1:26:50]`. If an agent authored both sides, a human must read the assertions.
- **Look for expectations fitted to the output.** The failure mode seen in the wild: a model turns a red test green by writing the observed value into the assertion — `expect(true).toBe(true)` instead of asserting the function `[1:13:00]`. Grep for assertions that cannot fail.
- **Ask who built the fence.** If requirements, test cases, and architecture rules were also generated, the "constraints" are not independent evidence `[1:18:29]`.
- **Where AI tests are a good trade:** pure, trivial functions (formatters, converters) — cheap to generate, easy to eyeball, and they do pin real behavior `[2:22:33]`.
- **Tests as a migration checklist.** Rewriting or porting a module: the existing suite is the cheapest signal that features survived — not proof, but the best available `[1:26:50]`.
- Keep in mind the classic limit the approach accepts: tests show the presence of bugs, never their absence; 100% coverage with green acceptance tests can still be a bad system, because tests only check what someone thought to check `[1:18:58]`.

## 9. Deliberately not part of this approach

Snapshot tests, visual-regression layers, mutation testing, and TDD-as-ritual are absent from it — screenshot tests exist only as a maintenance artifact in the team's Definition of Done. Adopt any of them if there is a stated reason; do not add them because they are on a generic best-practice list.

## 10. Process framing

Tests sit in the team's **Definition of Done** alongside test cases, screenshot tests, and documentation — a quality gate on the code, explicitly *not* the feature's acceptance criteria, which belong to the requester `[4:20:37, 4:26:44]`. Practical consequence for review: ask whether a change updated its test cases and docs, not just whether tests pass.

## 11. Adapting the tooling

The approach is runner-agnostic; only the imports change.

| Concern | Vitest project | Jest project |
| --- | --- | --- |
| a11y matchers | `vitest-axe` | `jest-axe` |
| DOM matchers | `@testing-library/jest-dom/vitest` | `@testing-library/jest-dom` |
| Setup file | `test.setupFiles` | `setupFilesAfterEach` |
| Coverage | `test.coverage` (v8) | `collectCoverage` (v8/babel) |
| Component tests in a real browser | `@vitest/browser-playwright` | Playwright separately |

## Review smells

- Repeated boilerplate assertions in every component test instead of one conformance call.
- Queries by visible text in a localized app.
- A compound component covered by a single blob test.
- Coverage quoted as a percentage with nobody reading the uncovered list.
- a11y checks added ad hoc in a few files instead of the shared setup.
- Agent-authored tests merged without a human reading the assertions for fitted expectations.
- Assertions on internal class names rather than semantic state attributes.
