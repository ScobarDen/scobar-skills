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

Внутри только поведение, без каталога скиллов и без стека:

- русский в чате, английский в коде
- стиль общения
- zero comments
- планы
- TODO/FIXME
- как открывать ссылки (fetch → нативный браузер агента → Playwright)
- кто побеждает при конфликте: чат > проектные правила > скиллы / этот файл

```bash
curl -fsSL https://raw.githubusercontent.com/ScobarDen/scobar-skills/main/templates/AGENTS.md -o AGENTS.md
```

---

## Что внутри

### Frontend

| Скилл | Когда грузить |
| --- | --- |
| [`frontend-mvvm`](skills/frontend/frontend-mvvm/SKILL.md) | Экран с клиентской логикой: слои, пассивный View, VM как фасад и медиатор. Не про выбор STM. |
| [`frontend-state-stack`](skills/frontend/frontend-state-stack/SKILL.md) | Greenfield или «какой стейт-менеджер». Пока стек уже выбран — не нужен. |
| [`frontend-testing-approach`](skills/frontend/frontend-testing-approach/SKILL.md) | Писать / ревьюить фронтовые тесты: стоит ли вообще, слои, лестница хелперов L0–L4. |
| [`mobx-mvvm`](skills/frontend/mobx-mvvm/SKILL.md) | Рецепт, если проект уже на MobX. На greenfield не предлагать. |

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

---

## Ещё поставь вот это

Мои скиллы закрывают узкий кусок. Для повседневной работы я ещё смотрю сюда:

### Скиллы

```bash
npx skills add siberiacancode/agent-skills
npx skills add https://github.com/reatom/reatom/tree/v1001/skills
npx skills add antfu/skills
npx skills add DenisSergeevitch/agents-best-practices
npx skills add TheQtCompanyRnD/agent-skills
```

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
  frontend/   frontend-mvvm, frontend-state-stack, frontend-testing-approach, mobx-mvvm
  qt/         qt-modular-mvvm, qt-cmake-boundaries
  reatom/     reatom-field-notes, reatom-testing
```

Формат — [Agent Skills](https://agentskills.io): папка со `SKILL.md` и YAML-frontmatter (`name`, `description`). Группы на [skills.sh](https://skills.sh/ScobarDen/scobar-skills) задаёт `skills.sh.json`.
