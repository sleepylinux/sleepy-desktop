import QtQuick 6.0

QtObject {
    property int viewportHeight: 0
    property int inset: 12
    property int railWidth: 72
    property int gap: 12
    property int drawerWidth: 360

    readonly property int railX: inset
    readonly property int railY: inset
    readonly property int railHeight: Math.max(0, viewportHeight - inset * 2)
    readonly property int drawerX: railX + railWidth + gap
    readonly property int drawerY: railY
    readonly property int drawerHeight: railHeight
    readonly property int drawerRight: drawerX + drawerWidth
}
