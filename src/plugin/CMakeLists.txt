find_package(Qt6 REQUIRED COMPONENTS
    ShaderTools Core Qml Gui Quick QuickControls2 Concurrent DBus Network Sql
)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Qalculate REQUIRED IMPORTED_TARGET libqalculate)
pkg_check_modules(Pipewire REQUIRED IMPORTED_TARGET libpipewire-0.3)
pkg_check_modules(Aubio REQUIRED IMPORTED_TARGET aubio)
pkg_check_modules(Cava REQUIRED IMPORTED_TARGET libcava)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

include(cmake/pch.cmake)
include(cmake/qml-module.cmake)
include(cmake/sensorslib.cmake)

# Header only helpers
add_library(sleepy-util INTERFACE)
target_include_directories(sleepy-util INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

add_subdirectory(src/Sleepy)
