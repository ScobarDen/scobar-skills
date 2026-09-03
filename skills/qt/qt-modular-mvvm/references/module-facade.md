# Module facade, composition root and mediator — skeletons

Copy, rename `budget`/`Budget`, delete what the module does not need. Comments explain the traps the shape guards against; drop them in a project that keeps code comment-free.

## 1. Public facade — `include/budget/module.h`

```cpp
#pragma once

#include <memory>

namespace category { class CategoryRepository; }   // a cross-module dependency, by forward declaration

namespace budget {

class BudgetViewModel;

class Module
{
public:
    // Dependencies on other modules arrive as arguments. The module knows the
    // other module's public API (allowed) but not where the instance comes from.
    explicit Module(category::CategoryRepository *categories);

    // Declared here, DEFINED in module.cpp: unique_ptr<Impl> needs the complete
    // Impl type to destroy it, and Impl is only complete in the .cpp.
    ~Module();

    Module(const Module &)            = delete;
    Module &operator=(const Module &) = delete;

    // Ownership is not transferred: the pointer lives as long as Module does.
    BudgetViewModel *viewModel() const;

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace budget
```

## 2. Module body — `module.cpp`

```cpp
#include "budget/module.h"

#include "budget/budgetviewmodel.h"
#include "data/budgetrepository.h"   // private layer path: only this file and the layers may see it

namespace budget {

struct Module::Impl
{
    explicit Impl(category::CategoryRepository *categories)
        : viewModel(&repository, categories)
    {
    }

    // DECLARATION ORDER IS THE CONSTRUCTION ORDER. repository must be declared
    // before viewModel, which takes its address. Swap the two lines and viewModel
    // receives a pointer to a not-yet-constructed object — and the compiler stays
    // silent: -Wreorder only compares an initializer list against declarations,
    // and repository is not in the list.
    BudgetRepository repository;
    BudgetViewModel  viewModel;
};

Module::Module(category::CategoryRepository *categories)
    : m_impl(std::make_unique<Impl>(categories))
{
}

Module::~Module() = default;   // Impl is complete here

BudgetViewModel *Module::viewModel() const
{
    return &m_impl->viewModel;
}

} // namespace budget
```

## 3. Public ViewModel header — `include/budget/budgetviewmodel.h`

```cpp
#pragma once

#include <QDate>
#include <QObject>
#include <functional>

class QAbstractItemModel;

namespace budget {

class BudgetRepository;   // forward-declared: header is private, so callers see the
class BudgetListModel;    // signature but cannot construct the argument

class BudgetViewModel : public QObject
{
    Q_OBJECT
    // Abstract base type on purpose: the concrete model stays private.
    // CONSTANT: the pointer never changes; the model signals its own content changes.
    Q_PROPERTY(QAbstractItemModel *model READ model CONSTANT)
    Q_PROPERTY(QString errorText READ errorText NOTIFY errorTextChanged)

public:
    using Today = std::function<QDate()>;

    // Clock injected with an empty default; the constructor substitutes
    // QDate::currentDate. "Last 30 days" is untestable otherwise.
    explicit BudgetViewModel(BudgetRepository *repository, Today today = {}, QObject *parent = nullptr);

    QAbstractItemModel *model() const;
    QString errorText() const { return m_errorText; }

    Q_INVOKABLE void refresh();

signals:
    void errorTextChanged();
    void dataChanged();   // for the mediator; this module does not know who listens

private:
    void setErrorText(const QString &text);

    BudgetRepository *m_repository;
    BudgetListModel  *m_model;   // created with `this` as parent: QObject tree owns it
    Today             m_today;
    QString           m_errorText;
};

} // namespace budget
```

Rules encoded in this header:

- Nothing from QtQuick is included; the build must not hand `Qt5::Quick` to this target.
- The constructor does **not** load data. The mediator subscribes to `errorTextChanged` after construction; a load in the constructor emits the first error into the void.
- `refresh()` keeps the previous rows on error and sets `errorText`. An empty vector means both "nothing there" and "the DB failed"; wiping the table would read as data loss.

## 4. Composition root — `app/main.cpp` (order matters)

```cpp
int main(int argc, char *argv[])
{
    global::applySettings();                 // 0. before the app object: HiDPI attributes are read by the ctor
    QGuiApplication app(argc, argv);

    QString dbError;                         // 1. infrastructure; fail fast with a console message
    if (!db::connect(db::configFromEnvironment(), &dbError)) {
        qCritical() << dbError;
        return 1;
    }

    category::CategoryRepository categories; // 2. cross-cutting module, on the stack, outlives everyone
    budget::Module   budgetModule(&categories);   // 3. product modules assemble themselves
    report::Module   reportModule;

    app::AppViewModel appViewModel(budgetModule.viewModel(),   // 4. the mediator subscribes to signals
                                   reportModule.viewModel());

    const char *uri = "App";                 // 5. QML must KNOW the types even if it never creates them
    qRegisterMetaType<QAbstractItemModel *>();   // abstract Qt bases do not self-register; without this
                                                 // a `model` property reads as nothing and the list stays empty
    qmlRegisterUncreatableType<budget::BudgetViewModel>(uri, 1, 0, "BudgetViewModel", QStringLiteral("created by the module"));
    qmlRegisterUncreatableType<report::ReportViewModel>(uri, 1, 0, "ReportViewModel", QStringLiteral("created by the module"));
    qmlRegisterSingletonInstance(uri, 1, 0, "App", &appViewModel);   // typed, unlike setContextProperty

    appViewModel.refreshAll();               // 6. first load, strictly after step 4

    QQmlApplicationEngine engine;            // 7. declared after appViewModel: destroyed before it
    engine.load(QUrl(QStringLiteral("qrc:/ui/main.qml")));
    if (engine.rootObjects().isEmpty())      // QML errors are runtime-only; without this the app exits silently
        return 1;

    return app.exec();
}
```

## 5. Mediator — `app/appviewmodel.{h,cpp}`

```cpp
class AppViewModel : public QObject
{
    Q_OBJECT
    Q_PROPERTY(budget::BudgetViewModel *budget READ budget CONSTANT)
    Q_PROPERTY(report::ReportViewModel *report READ report CONSTANT)
    Q_PROPERTY(QString statusText    READ statusText    NOTIFY statusChanged)
    Q_PROPERTY(bool    statusIsError READ statusIsError NOTIFY statusChanged)
    // ...
};

AppViewModel::AppViewModel(budget::BudgetViewModel *budget, report::ReportViewModel *report, QObject *parent)
    : QObject(parent), m_budget(budget), m_report(report)
{
    // The one place two modules know about each other — one visible line per link.
    connect(m_budget, &budget::BudgetViewModel::dataChanged, m_report, &report::ReportViewModel::refresh);

    connect(m_budget, &budget::BudgetViewModel::errorTextChanged, this, &AppViewModel::collectError);
    connect(m_report, &report::ReportViewModel::errorTextChanged, this, &AppViewModel::collectError);
}

void AppViewModel::refreshAll()
{
    m_budget->refresh();
    m_report->refresh();
    collectError();                 // signals may not have fired: unchanged text emits nothing
    if (!m_statusIsError)           // success only when nothing is wrong — the other order hides errors
        setStatus(tr("Data refreshed"), false);
}

void AppViewModel::collectError()
{
    const QString candidates[] = { m_budget->errorText(), m_report->errorText() };   // ADD EVERY MODULE HERE
    for (const QString &error : candidates)
        if (!error.isEmpty()) { setStatus(error, true); return; }
    if (m_statusIsError)
        setStatus(QString(), false);
}

void AppViewModel::setStatus(const QString &text, bool isError)
{
    if (m_statusText == text && m_statusIsError == isError)
        return;
    m_statusText = text;            // two fields, ONE signal, emitted last
    m_statusIsError = isError;
    emit statusChanged();
}
```

Forgetting to add a new module to `candidates` is silent: the module works, its errors never reach the status bar. Put it on the checklist.
