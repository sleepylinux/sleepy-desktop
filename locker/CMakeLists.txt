cmake_minimum_required(VERSION 3.24)
project(sleepy-locker VERSION 0.2.0 LANGUAGES CXX)

include(CTest)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick Network Test)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PAM REQUIRED IMPORTED_TARGET pam)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

add_library(sleepy-locker-secure STATIC secureprompt.cpp secureprompt.hpp)
target_include_directories(sleepy-locker-secure PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(sleepy-locker-secure
    PUBLIC Qt6::Core Qt6::Gui Qt6::Quick
    PRIVATE PkgConfig::PAM)
target_compile_options(sleepy-locker-secure PRIVATE
    -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Werror)

qt_add_executable(sleepy-locker main.cpp)
qt_add_qml_module(sleepy-locker
    URI Sleepy.Locker
    VERSION 1.0
    QML_FILES qml/LockRoot.qml
    NO_LINT)
target_link_libraries(sleepy-locker PRIVATE
    sleepy-locker-secure Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network)

if(BUILD_TESTING)
    qt_add_executable(sleepy-locker-tests
        ../tests/locker_native.cpp
        secureprompt.cpp
        secureprompt.hpp)
    target_include_directories(sleepy-locker-tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
    target_compile_definitions(sleepy-locker-tests PRIVATE SLEEPY_LOCKER_TESTING)
    target_link_libraries(sleepy-locker-tests PRIVATE
        Qt6::Core Qt6::Gui Qt6::Quick Qt6::Test PkgConfig::PAM)
    add_test(NAME sleepy-locker-native COMMAND sleepy-locker-tests)
    set_tests_properties(sleepy-locker-native PROPERTIES
        TIMEOUT 20
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_QPA_PLATFORMTHEME=;KDE_FULL_SESSION=;XDG_CURRENT_DESKTOP=;KDE_DEBUG=1;QT_STYLE_OVERRIDE=Fusion")
endif()

install(TARGETS sleepy-locker RUNTIME DESTINATION bin)
