# src/modules/budget/CMakeLists.txt — complete module build file. Copy, rename
# `budget`, delete layers the module does not have.
#
# Read SEES as the architecture of the module:
#   domain    sees nothing — pure types and rules, testable without Qt app
#   data      sees domain, and is the ONLY layer that gets the SQL library
#   model     sees domain, NOT data — a model receives rows, it never fetches
#   viewmodel sees all three plus the public header it implements

add_layer(budget domain
    SOURCES
        domain/include/domain/budget.h
        domain/include/domain/budgetrules.h
        domain/budgetrules.cpp
)

add_layer(budget data
    SOURCES
        data/include/data/budgetrepository.h
        data/budgetrepository.cpp
    SEES  domain
    LINKS Qt5::Sql ${PROJECT_NAME}_common_db
)

add_layer(budget model
    SOURCES
        model/include/model/budgetlistmodel.h
        model/budgetlistmodel.cpp
    SEES  domain
    LINKS ${PROJECT_NAME}_common_money
)

# The public header lives HERE, not in the module target: it carries Q_OBJECT
# and AUTOMOC pairs a header with its same-name .cpp inside one target.
add_layer(budget viewmodel
    SOURCES
        include/budget/budgetviewmodel.h
        viewmodel/budgetviewmodel.cpp
    SEES  domain data model
    LINKS ${PROJECT_NAME}_common_money
    API
)

# One STATIC library goes out; consumers never learn about the layers.
add_library(${PROJECT_NAME}_module_budget STATIC
    include/budget/module.h
    module.cpp
    $<TARGET_OBJECTS:${PROJECT_NAME}_budget_domain>
    $<TARGET_OBJECTS:${PROJECT_NAME}_budget_data>
    $<TARGET_OBJECTS:${PROJECT_NAME}_budget_model>
    $<TARGET_OBJECTS:${PROJECT_NAME}_budget_viewmodel>
)

target_include_directories(${PROJECT_NAME}_module_budget
    # Consumers write #include "budget/module.h": the module-name prefix is
    # what keeps two modules' module.h apart.
    PUBLIC  include
    # Pointed, never `.`: module.cpp constructs the repository (data), and the
    # repository header includes a domain type (domain). Layer paths are not
    # inherited from the OBJECT libraries; grant them here explicitly.
    PRIVATE data/include domain/include
)

target_link_libraries(${PROJECT_NAME}_module_budget
    # A type from the dependency appears in a public header → PUBLIC.
    # Header-only helpers whose macros expand in public headers → PUBLIC too,
    # or consumers (and moc) cannot see the macros.
    PUBLIC  Qt5::Core ${PROJECT_NAME}_common_money
    # $<TARGET_OBJECTS:> brings objects, not link requirements: the data
    # layer's objects reference QtSql, so the module must link it. LINK_ONLY
    # links without granting QtSql's include paths to module.cpp, keeping
    # "only data touches SQL" intact.
    PRIVATE ${PROJECT_NAME}_warnings $<LINK_ONLY:Qt5::Sql>
)

if(BUILD_TESTS)
    add_subdirectory(tests)
endif()

# Then, elsewhere:
#   root CMakeLists.txt:      add_subdirectory(src/modules/budget)
#   src/app/CMakeLists.txt:   target_link_libraries(<app> PRIVATE ... ${PROJECT_NAME}_module_budget)
#   src/app/ui/app.qrc (Qt5): <file alias="modules/budget/qmldir">../../modules/budget/ui/qmldir</file>
#                             <file alias="modules/budget/BudgetView.qml">../../modules/budget/ui/BudgetView.qml</file>
#   Qt 6 instead of .qrc:     qt_add_qml_module(${PROJECT_NAME}_budget_qml URI Modules.Budget VERSION 1.0
#                                 QML_FILES ui/BudgetView.qml)
