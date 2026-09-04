import QtQml 6.0

QtObject {
    property string path: ""
    property bool connected: false
    property QtObject parser: null

    signal connectionStateChanged
    signal error
}
