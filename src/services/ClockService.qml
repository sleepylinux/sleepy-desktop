import QtQuick 6.0

QtObject {
    id: root

    property date currentTime: new Date()
    readonly property string railTime: Qt.formatTime(currentTime, "HH\nmm")

    readonly property Timer updateTimer: Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }
}
