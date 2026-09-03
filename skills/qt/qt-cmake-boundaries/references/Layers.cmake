# add_layer — one OBJECT library per MVVM layer with an explicit visibility list.
#
#   add_layer(<module> <layer>
#       SOURCES <files, relative to the module directory>
#       [SEES   <sibling layers this layer may include>]
#       [LINKS  <external targets: Qt5::Sql, ${PROJECT_NAME}_common_money, ...>]
#       [API]   # also grant the module's public include/ (the viewmodel layer
#               # implements the public header, so it needs it)
#   )
#
# Creates target ${PROJECT_NAME}_<module>_<layer>. Include it from the root
# CMakeLists.txt (include(Layers)) so every module file can call it.
#
# Why OBJECT: the layer is a set of compiled objects with its own include
# paths and nothing else. The module target picks the objects up with
# $<TARGET_OBJECTS:...>; consumers never see the layers.
#
# What does NOT propagate: an OBJECT library links nothing, so any library
# its objects need (Qt5::Sql for the data layer) must be supplied by the
# module target — preferably as $<LINK_ONLY:...> so the module's own
# sources do not gain the right to include that library's headers.
#
# A layer without any .cpp (a domain of one struct) needs no call: SEES only
# adds a path and never references a layer target.

function(add_layer module layer)
    cmake_parse_arguments(ARG "API" "" "SOURCES;SEES;LINKS" ${ARGN})

    if(NOT ARG_SOURCES)
        message(FATAL_ERROR
            "add_layer(${module} ${layer}): SOURCES is empty. "
            "A header-only layer needs no target; do not call add_layer for it.")
    endif()

    set(target ${PROJECT_NAME}_${module}_${layer})

    add_library(${target} OBJECT ${ARG_SOURCES})

    # Paths are relative to the CALLING CMakeLists.txt: a function does not
    # change directory scope, unlike add_subdirectory.
    target_include_directories(${target} PRIVATE ${layer}/include)

    foreach(seen IN LISTS ARG_SEES)
        # Fail at configure time with a readable message instead of
        # "No such file or directory" in the middle of somebody's .cpp.
        if(NOT IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${seen}/include)
            message(FATAL_ERROR
                "add_layer(${module} ${layer}): SEES lists layer '${seen}', "
                "but ${seen}/include does not exist")
        endif()
        target_include_directories(${target} PRIVATE ${seen}/include)
    endforeach()

    if(ARG_API)
        target_include_directories(${target} PRIVATE include)
    endif()

    # PRIVATE: the layer exposes nothing; its objects are consumed by the
    # module target, and these requirements matter only while compiling them.
    target_link_libraries(${target} PRIVATE ${PROJECT_NAME}_warnings Qt5::Core ${ARG_LINKS})
endfunction()
