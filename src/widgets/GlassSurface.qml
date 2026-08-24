import QtQuick 6.0

Item {
    id: root

    required property var colors
    required property var effects
    property bool raised: false
    property real radius: 22

    readonly property real effectiveSurfaceOpacity:
        raised ? effects.raisedSurfaceOpacity : effects.surfaceOpacity
    readonly property bool shadowVisible: effects.shadowEnabled
    readonly property bool glowVisible: effects.glowEnabled

    Rectangle {
        objectName: "materialShadow"
        anchors {
            fill: parent
            margins: -6
        }
        radius: root.radius + 6
        color: root.colors.shadow
        opacity: root.effects.shadowOpacity
        visible: root.shadowVisible
    }

    Rectangle {
        objectName: "materialGlow"
        anchors {
            fill: parent
            margins: -2
        }
        radius: root.radius + 2
        color: "transparent"
        border.width: 2
        border.color: root.colors.glow
        opacity: root.effects.glowOpacity
        visible: root.glowVisible
    }

    Rectangle {
        objectName: "materialBase"
        anchors.fill: parent
        radius: root.radius
        color: root.raised ? root.colors.surfaceRaised : root.colors.surface
        opacity: root.effectiveSurfaceOpacity
    }

    Rectangle {
        objectName: "materialContrastLayer"
        anchors.fill: parent
        radius: root.radius
        color: root.colors.contrastLayer
        opacity: root.effects.contrastLayerOpacity
    }

    Rectangle {
        objectName: "materialSheen"
        anchors.fill: parent
        radius: root.radius
        opacity: root.effects.sheenOpacity
        visible: root.effects.highlightEnabled
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.colors.highlight }
            GradientStop { position: 0.46; color: "transparent" }
            GradientStop { position: 1.0; color: root.colors.glow }
        }
    }

    Rectangle {
        objectName: "materialHighlight"
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.colors.highlight
        visible: root.effects.highlightEnabled
    }
}
