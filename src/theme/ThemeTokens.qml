import QtQuick 6.0

QtObject {
    id: root

    property bool reducedMotion: false

    readonly property int gridUnit: 12
    readonly property int shellRadius: 22
    readonly property int innerRadius: 16

    readonly property int outerInset: gridUnit
    readonly property int railWidth: gridUnit * 6
    readonly property int drawerGap: gridUnit
    readonly property int drawerWidth: gridUnit * 30
    readonly property int touchTarget: gridUnit * 4
    readonly property int contentPadding: gridUnit * 2

    readonly property int motionDuration: reducedMotion ? 0 : 180
    readonly property int slowMotionDuration: reducedMotion ? 0 : 260
}
