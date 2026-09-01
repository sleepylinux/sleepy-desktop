qml_module(sleepy-core
    URI Sleepy
    SOURCES
        cutils.cpp
        toaster.cpp
        circularbuffer.cpp
        qalculator.cpp
        requests.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::Network
        PkgConfig::Qalculate
        sleepy-util
)

# Bake the shell version in so CUtils can expose it without spawning a process
target_compile_definitions(sleepy-core PRIVATE SLEEPY_VERSION="${VERSION}")

# Node macros expand to Q_OBJECT, automoc can't see it otherwise
list(APPEND CMAKE_AUTOMOC_MACRO_NAMES
    SETTINGS_NODE SETTINGS_NODE_NO_CTOR SETTINGS_LIST_TYPE
    CONFIG_NODE CONFIG_NODE_NO_CTOR CONFIG_LIST_TYPE
)

add_subdirectory(Settings)
add_subdirectory(Config)
add_subdirectory(Components)
add_subdirectory(Blobs)
add_subdirectory(Images)
add_subdirectory(Models)
add_subdirectory(Services)
