# add_unit_test — register one test executable declared next to its module.
#
#   add_unit_test(<name> <unit|integration> <targets to link...>
#       [SEES <module layers whose private include/ the test may use>]
#   )
#
# <name>.cpp is expected next to the calling CMakeLists.txt. SEES resolves to
# ../<layer>/include because tests live in <module>/tests/.
#
# The label is a mandatory positional argument on purpose: labelling in a
# second step (set_tests_properties over a hand-kept list) lets a forgotten
# test silently drop out of `ctest -L unit`.
#
# Tests may see private layers: a test is part of the module, not a consumer,
# and it subclasses the real repository to fake it. Granting per layer keeps
# the statement readable — "this test looks into data and domain, nowhere
# else" — and a domain test that suddenly needs data shows up in this file's
# diff as database access leaking into the domain.

function(add_unit_test name label)
    cmake_parse_arguments(ARG "" "" "SEES" ${ARGN})

    add_executable(${name} ${name}.cpp)

    # Everything not consumed by SEES is a link target.
    target_link_libraries(${name} PRIVATE
        ${ARG_UNPARSED_ARGUMENTS}
        ${PROJECT_NAME}_warnings
        Qt5::Test
    )

    foreach(seen IN LISTS ARG_SEES)
        set(layer_include ${CMAKE_CURRENT_SOURCE_DIR}/../${seen}/include)
        if(NOT IS_DIRECTORY ${layer_include})
            message(FATAL_ERROR
                "add_unit_test(${name}): SEES lists layer '${seen}', "
                "but ../${seen}/include does not exist")
        endif()
        target_include_directories(${name} PRIVATE ${layer_include})
    endforeach()

    # One directory for every test binary regardless of which module declared
    # it. CI that runs binaries directly (QTest emits JUnit itself; ctest can
    # only do that from CMake 3.21) needs a stable path. Multi-config
    # generators add a configuration subdirectory (tests/Debug).
    set_target_properties(${name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/tests
    )

    add_test(NAME ${name} COMMAND ${name})

    # offscreen lets Qt run without a display even for guiless tests.
    set_tests_properties(${name} PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
        TIMEOUT 60
        LABELS ${label}
    )
endfunction()

# Root CMakeLists.txt wiring:
#
#   option(BUILD_TESTS "Build tests" ON)
#   if(BUILD_TESTS)
#       enable_testing()                                    # must be in the root
#       find_package(Qt5 5.14 REQUIRED COMPONENTS Test)    # only when tests are built
#       add_subdirectory(src/common/testing)                # test-only helpers linking Qt5::Test
#   endif()
#   ...
#   if(BUILD_TESTS)
#       add_subdirectory(tests/integration)                 # tests spanning modules
#   endif()
