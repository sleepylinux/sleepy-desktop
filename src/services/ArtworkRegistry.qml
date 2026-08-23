import QtQuick 6.0

QtObject {
    required property url primaryMarkSource

    function sourceFor(logicalName) {
        if (logicalName === "branding.primaryMark")
            return primaryMarkSource;
        return "";
    }
}
