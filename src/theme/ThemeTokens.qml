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

    // Optical measurements shared by the rail and drawer surfaces.
    readonly property int railBrandTopInset: 15
    readonly property int railWorkspaceTop: 80
    readonly property int railWorkspaceSpacing: 7
    readonly property int railBottomInset: 15
    readonly property int railBottomSpacing: 9
    readonly property int drawerHeaderHeight: 54
    readonly property int drawerCloseSize: 38
    readonly property int drawerSectionSpacer: 8
    readonly property int drawerDiagnosticHeight: 58
    readonly property int sliderRowHeight: 64
    readonly property int sliderTrackHeight: 4

    readonly property int motionDuration: reducedMotion ? 0 : 180
    readonly property int slowMotionDuration: reducedMotion ? 0 : 260
}
