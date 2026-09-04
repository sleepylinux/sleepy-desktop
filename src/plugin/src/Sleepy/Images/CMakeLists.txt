qml_module(sleepy-images
    URI Sleepy.Images
    SOURCES
        cachingimageprovider.cpp
        imagecacher.cpp
        imageanalyser.cpp
        iutils.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
)
