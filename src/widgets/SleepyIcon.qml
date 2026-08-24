import QtQuick 6.0
import QtQuick.Effects 6.5

Item {
    id: root

    required property var iconRegistry
    required property string name
    property color iconColor: "white"
    property int iconSize: 20
    property string accessibleName: ""

    readonly property url resolvedSource: iconRegistry
        ? iconRegistry.sourceFor(name) : ""
    readonly property bool available: resolvedSource.toString().length > 0
    readonly property bool ready:
        available && sourceImage.status === Image.Ready
        && maskImage.status === Image.Ready
    readonly property bool fallbackVisible: !available || sourceImage.status === Image.Error

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        id: sourceImage
        objectName: "iconSource"
        anchors.centerIn: parent
        width: Math.min(root.width, root.iconSize)
        height: Math.min(root.height, root.iconSize)
        source: root.resolvedSource
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        smooth: true
        mipmap: true
        visible: false
        layer.enabled: true
    }

    Image {
        id: maskImage
        anchors.fill: sourceImage
        source: root.resolvedSource
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        smooth: true
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        objectName: "iconEffect"
        z: 1
        anchors.fill: sourceImage
        autoPaddingEnabled: false
        source: sourceImage
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.iconColor
        maskEnabled: true
        maskSource: maskImage
        visible: root.ready
    }

    Item {
        objectName: "iconFallback"
        anchors.centerIn: parent
        width: Math.min(root.width, root.iconSize) * 0.72
        height: width
        visible: root.fallbackVisible

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Math.max(2, parent.height * 0.12)
            radius: height / 2
            rotation: 45
            color: root.iconColor
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Math.max(2, parent.height * 0.12)
            radius: height / 2
            rotation: -45
            color: root.iconColor
        }
    }

    Accessible.name: accessibleName
    Accessible.role: Accessible.Graphic
}
