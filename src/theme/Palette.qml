import QtQuick 6.0

QtObject {
    id: root

    property string appearanceMode: "dark"

    readonly property bool light: appearanceMode === "light"
    readonly property color shellBackground: light ? "#f1eef8" : "#17131f"
    readonly property color surface: light ? "#fbf9ff" : "#211c2b"
    readonly property color surfaceRaised: light ? "#ffffff" : "#2b2438"
    readonly property color surfaceQuiet: light ? "#e9e4f3" : "#1c1825"
    readonly property color border: light ? "#d8d0e6" : "#3b3249"
    readonly property color accent: light ? "#6a50aa" : "#b9a7ff"
    readonly property color accentSoft: light ? "#e4dcfb" : "#3a3152"
    readonly property color textPrimary: light ? "#251f2e" : "#f7f3ff"
    readonly property color textSecondary: light ? "#584f65" : "#d0c7dc"
    readonly property color success: light ? "#2b6e58" : "#76c7aa"
    readonly property color warning: light ? "#8c5720" : "#ddb87d"
    readonly property color error: light ? "#a33d56" : "#ef9aaf"
    readonly property color contrastLayer: light ? "#ffffff" : "#100c18"
    readonly property color highlight: light ? "#ffffff" : "#d9cdff"
    readonly property color shadow: light ? "#463b5c" : "#050309"
    readonly property color glow: light ? "#9c82ed" : "#a98fff"
}
