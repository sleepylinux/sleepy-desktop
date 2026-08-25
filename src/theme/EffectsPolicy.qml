import QtQuick 6.0

QtObject {
    id: root

    property string effectsProfile: "full"
    property bool reducedMotion: false
    property bool portalReducedMotion: false
    property bool opaqueFallback: false

    readonly property string profile:
        effectsProfile === "full" || effectsProfile === "reduced"
        || effectsProfile === "none" ? effectsProfile : "none"
    readonly property real surfaceOpacity:
        opaqueFallback ? 1.0 : profile === "full" ? 0.82 : profile === "reduced" ? 0.94 : 1.0
    readonly property real raisedSurfaceOpacity:
        opaqueFallback ? 1.0 : profile === "full" ? 0.88 : profile === "reduced" ? 0.97 : 1.0
    readonly property real contrastLayerOpacity:
        profile === "full" ? 0.12 : profile === "reduced" ? 0.08 : 0.0
    readonly property bool highlightEnabled: profile !== "none" && !opaqueFallback
    readonly property bool shadowEnabled: profile !== "none" && !opaqueFallback
    readonly property bool glowEnabled: profile === "full" && !opaqueFallback
    readonly property bool decorativeMotionEnabled:
        profile !== "none" && !reducedMotion && !portalReducedMotion
    readonly property int motionDuration:
        !decorativeMotionEnabled ? 0 : profile === "reduced" ? 90 : 180
    readonly property int slowMotionDuration:
        !decorativeMotionEnabled ? 0 : profile === "reduced" ? 140 : 260
    readonly property real shadowOpacity:
        profile === "full" ? 0.30 : profile === "reduced" ? 0.20 : 0.0
    readonly property real glowOpacity: glowEnabled ? 0.18 : 0.0
    readonly property real sheenOpacity:
        profile === "full" ? 0.14 : profile === "reduced" ? 0.07 : 0.0
}
