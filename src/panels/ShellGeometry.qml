import QtQuick 6.0

QtObject {
    property int viewportHeight: 0
    property int inset: 12
    property int railWidth: 72
    property int gap: 12
    property int drawerWidth: 360

    readonly property int railMarginLeft: inset
    readonly property int railExclusiveZone: railWidth
    readonly property int railX: railMarginLeft
    readonly property int railY: inset
    readonly property int railHeight: Math.max(0, viewportHeight - inset * 2)
    readonly property int railEnvelopeRight: railMarginLeft + railExclusiveZone
    readonly property int drawerMarginLeft: railEnvelopeRight + gap
    readonly property int drawerExclusiveZone: 0
    readonly property int drawerX: drawerMarginLeft
    readonly property int drawerY: railY
    readonly property int drawerHeight: railHeight
    readonly property int drawerRight: drawerX + drawerWidth
}
