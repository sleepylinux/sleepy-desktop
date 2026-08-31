qml_module(sleepy-components
    URI Sleepy.Components
    SOURCES
        lazylistview.cpp
        wavyline.cpp
        buttonrow.cpp
        circularindicatormanager.cpp
        linearindicatormanager.cpp
        sparklineitem.cpp
        visualiserbars.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        sleepy-core
    DEPENDENCIES
        Sleepy
)
