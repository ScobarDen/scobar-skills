# scobar-skills

Мои скиллы для агентов. Ставятся через [`npx skills add`](https://skills.sh):

```bash
npx skills add ScobarDen/scobar-skills
```

Один скилл:

```bash
npx skills add ScobarDen/scobar-skills --skill frontend-mvvm
```

Это не маркетплейс и не «все скиллы, которые я использую». Здесь только то, что написал сам. Чужое — ниже, его лучше ставить из первоисточника.

---

## Шаблон инструкций агента

Не скилл и не ставится через `npx skills add`. Нейтральный [`templates/AGENTS.md`](templates/AGENTS.md) — копирую в корень репо как `AGENTS.md`. Если агент читает только другое имя (`CLAUDE.md`, `GEMINI.md`) — копия или симлинк туда же.

Внутри только поведение, без стека:

- русский в чате, английский в коде
- стиль общения
- zero comments
- планы
- TODO/FIXME
- документация: сначала MCP Context7 или `llms.txt` / `llms-full.txt` на сайте доки
- как открывать ссылки (fetch → нативный браузер агента → Playwright); если в браузере не прошла авторизация или упёрся во что-то ещё — остановиться и попросить меня, я сам введу и переподключу, без обходных манёвров
- ворктри — только через скилл, и не плодить ворктри внутри ворктри
- специфичная задача (тесты, фреймворк, язык, библиотека) — сначала проверь, есть ли скилл под неё; то же и для общих скиллов про ремесло
- кто побеждает при конфликте: чат > проектные правила > скиллы / этот файл

Каталога скиллов внутри нет. Единственное исключение — `worktree-flow` в пункте про ворктри, и то как `e.g.`: инструкция рабочая и без него.

```bash
curl -fsSL https://raw.githubusercontent.com/ScobarDen/scobar-skills/main/templates/AGENTS.md -o AGENTS.md
```

---

## Что внутри

### Workflow

Стек-нейтральные. Работают на фронте, на бэке, на Qt, на чём угодно с гитом.

| Скилл | Когда грузить |
| --- | --- |
| [`code-craft`](skills/workflow/code-craft/SKILL.md) | В момент решения, а не на ревью: как назвать, какая подпись, `setContent(node, true, false)` → union или options, guard clauses вместо вложенности, куда положить файл. |
| [`test-craft`](skills/workflow/test-craft/SKILL.md) | Пишу тест, тест покраснел от рефакторинга без смены поведения, ревью тестов в диффе. Контракт вместо потрохов, моки только на границе чужого кода, одно поведение на тест, галерея запахов. |
| [`refactor-advice`](skills/workflow/refactor-advice/SKILL.md) | «Улучши / упрости / отрефактори». Быстрые победы vs глубокие рефакторы, упрощение как отдельная линза. Плюс дисциплина применения: `git blame` перед правкой, поведение заморожено, по одному изменению. Не баг-хант. |
| [`change-debrief`](skills/workflow/change-debrief/SKILL.md) | «Объясни, что сделал» после задачи. Разбор полёта простым языком на минуту-две: сначала «зачем», потом главное изменение живым кодом было → стало с объяснением, что меняется в поведении, 3–5 буллетов изменений, 1–3 решения по четыре строки (выбрал / почему / вместо / цена), что осталось и чего не проверял. Глубже — по запросу через «Могу развернуть». По умолчанию — текущая ветка целиком, коммиты и рабочее дерево. Каждый принцип с источником, ноль самопохвалы. |
| [`pr-description`](skills/workflow/pr-description/SKILL.md) | Нужен тайтл и описание PR/MR или обновить уже открытое. Сначала «зачем» (из тела PR, задачи в трекере, коммитов — или один вопрос автору), потом «что», по 1–3 буллета, группировка по домену, а не по файлам. Тайтл на английском, тело на языке, на котором со мной говорят. Форж-агностик, шаблон репо главнее своего, шум вроде lockfile'ов и генерёнки — только по `--stat`. В форж пишет только по явной просьбе и только внутри своего блока `<!-- pr-description:start/end -->`. |
| [`worktree-flow`](skills/workflow/worktree-flow/SKILL.md) | Ворктри: папка-сиблинг `<repo>-<slug>`, перенос локальных untracked-файлов, снос по лестнице проверок (грязь, стэш, непушнутое, открытый MR, влито ли — включая squash). |

Пара: `code-craft` владеет доктриной (имена, подписи, форма состояния и функции, базовые принципы), `refactor-advice` её не переписывает, а ссылается и добавляет машинерию отчёта. Ставить лучше оба. `test-craft` — тот же жанр, но про тесты: что ассертить и что не ассертить, чтобы правка реализации не красила сюиту. Стек-специфичное (раннер, API ассертов) он не трогает — это дело скилла под стек.

Три скилла смотрят на один и тот же дифф, но отвечают на разные вопросы: `change-debrief` — «что тут вообще произошло и почему», `refactor-advice` — «как это улучшить», `pr-description` — «что написать в MR».

### Frontend

| Скилл | Когда грузить |
| --- | --- |
| [`frontend-mvvm`](skills/frontend/frontend-mvvm/SKILL.md) | Экран с клиентской логикой: слои, пассивный View, VM как фасад и медиатор. Не про выбор STM. |
| [`frontend-modular-mvvm`](skills/frontend/frontend-modular-mvvm/SKILL.md) | Куда класть и как называть: уровни FEOD, файлы `{subject}.{role}.ts` (`.model` / `.vm` / `.view` / `.api`…), папки ролей по мере роста, границы ролей линтом. |
| [`frontend-state-stack`](skills/frontend/frontend-state-stack/SKILL.md) | Greenfield или «какой стейт-менеджер». Пока стек уже выбран — не нужен. |
| [`mobx-mvvm`](skills/frontend/mobx-mvvm/SKILL.md) | Рецепт, если проект уже на MobX. На greenfield не предлагать. |

Пара: `frontend-mvvm` — роли, `frontend-modular-mvvm` — где они лежат и как называются.

### Qt

| Скилл | Когда грузить |
| --- | --- |
| [`qt-modular-mvvm`](skills/qt/qt-modular-mvvm/SKILL.md) | Куда класть код в Qt Quick: уровни, MVVM внутри модуля, фасад, медиатор. |
| [`qt-cmake-boundaries`](skills/qt/qt-cmake-boundaries/SKILL.md) | Те же границы, но чтобы их ловил компилятор, а не ревью. Шаблоны CMake в `references/`. |

Пара: новый модуль — оба.

### Reatom

Это **добавка** к официальным скиллам Reatom, не замена. Сначала `npx skills add` из репо Reatom (см. ниже).

| Скилл | Когда грузить |
| --- | --- |
| [`reatom-field-notes`](skills/reatom/reatom-field-notes/SKILL.md) | Вместе с `reatom`: странные аборты, рекурсия, полевые заметки из канала автора. |
| [`reatom-testing`](skills/reatom/reatom-testing/SKILL.md) | Тесты на Reatom: `context.start` / `context.reset`, моки, тайминг ассерта. |

### Поверх Мэтта

**Добавка** к [`mattpocock/skills`](https://github.com/mattpocock/skills), не замена. Сначала поставь его пак (см. ниже).

| Скилл | Когда грузить |
| --- | --- |
| [`matt-flow`](skills/mattpocock/matt-flow/SKILL.md) | «Вот задача, веди за руку». Разбирает задачу в маршрут по флоу Мэтта, на каждом шаге говорит, какую команду печатать, и помнит, где ты остановился, после `/clear`. |

Оркестраторы Мэтта (`/grill-with-docs`, `/to-spec`, `/to-tickets`, `/implement`) закрыты флагом `disable-model-invocation: true` — вызвать их может только человек, и `matt-flow` это не обходит: он навигатор, команды печатаешь ты. Заодно вставляет в маршрут мои скиллы — стек-специфичные и `code-craft` / `test-craft` перед сборкой.

---

## Ещё поставь вот это

Мои скиллы закрывают узкий кусок. Для повседневной работы я ещё смотрю сюда:

### Скиллы

```bash
npx skills add mattpocock/skills
npx skills add siberiacancode/agent-skills
npx skills add https://github.com/reatom/reatom/tree/v1001/skills
npx skills add antfu/skills
npx skills add DenisSergeevitch/agents-best-practices
npx skills add TheQtCompanyRnD/agent-skills
```

- [mattpocock/skills](https://github.com/mattpocock/skills) — процесс вместо вайбкодинга: грилл, спека, тикеты, TDD, ревью. Без него мой `matt-flow` пустой.
- [siberiacancode/agent-skills](https://github.com/siberiacancode/agent-skills) — фронт, тесты, практика.
- [reatom/reatom `v1001/skills`](https://github.com/reatom/reatom/tree/v1001/skills) — официальные `reatom` / `reatom-async` / `reatom-jsx` / `reatom-review`. Без них мои `reatom-*` слепые.
- [antfu/skills](https://github.com/antfu/skills) — тулинг, eslint, монорепы, как делает Anthony Fu.
- [DenisSergeevitch/agents-best-practices](https://github.com/DenisSergeevitch/agents-best-practices) — как собирать агентный харнесс.
- [DenisSergeevitch/chatgpt-custom-instructions](https://github.com/DenisSergeevitch/chatgpt-custom-instructions) — не скиллы, а кастомные инструкции; всё равно стоит глянуть.
- [TheQtCompanyRnD/agent-skills](https://github.com/TheQtCompanyRnD/agent-skills) — скиллы Qt Company.

### MCP

Скиллы — это инструкции. За живые инструменты отвечают MCP. Имеет смысл держать:

| MCP | Зачем |
| --- | --- |
| [Context7](https://github.com/upstash/context7) | Актуальная дока библиотек вместо того, что модель выдумала из весов. |
| [Playwright](https://github.com/microsoft/playwright-mcp) | Реальный браузер: клики, скрины, e2e. |
| [Figma](https://www.figma.com/mcp) | Читать и писать макеты, не скриншотить наугад. |

Как именно их подключить — зависит от агента (Claude Code / Cursor / Grok / Codex). Это не `npx skills add`.

---

## Как устроен репозиторий

```
templates/AGENTS.md   копируемый файл инструкций агента
skills/
  workflow/   code-craft, test-craft, refactor-advice, change-debrief, pr-description, worktree-flow
  frontend/   frontend-mvvm, frontend-modular-mvvm, frontend-state-stack, mobx-mvvm
  qt/         qt-modular-mvvm, qt-cmake-boundaries
  reatom/     reatom-field-notes, reatom-testing
  mattpocock/ matt-flow
```

Формат — [Agent Skills](https://agentskills.io): папка со `SKILL.md` и YAML-frontmatter (`name`, `description`). Группы на [skills.sh](https://skills.sh/ScobarDen/scobar-skills) задаёт `skills.sh.json`.
