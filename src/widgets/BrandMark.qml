import QtQuick 6.0

Item {
    id: root

    required property var artworkRegistry
    property string logicalName: "branding.primaryMark"

    implicitWidth: 42
    implicitHeight: 42

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: "transparent"

        Image {
            anchors {
                fill: parent
                margins: 5
            }
            source: root.artworkRegistry.sourceFor(root.logicalName)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
        }
    }
}
