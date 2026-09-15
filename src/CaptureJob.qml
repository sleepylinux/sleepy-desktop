//@ pragma ShellId sleepy-capture-job
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Sleepy
import qs.services
import qs.components.containers
import "modules/areapicker"

ShellRoot {
    id: root
    settings.watchFiles: false
    readonly property string jobId: Quickshell.env("SLEEPY_CAPTURE_JOB_ID") || ""
    readonly property string outputId: Quickshell.env("SLEEPY_CAPTURE_OUTPUT_ID") || ""
    readonly property string outputPath: Quickshell.env("SLEEPY_CAPTURE_OUTPUT_PATH") || ""
    readonly property var targetScreen: Quickshell.screens.find(screen => "output:" + screen.name === root.outputId) || null
    property bool initialized: false
    CaptureJobsProtocol { id: validator }
    CaptureJobState {
        id: job
        onReported: (state, code, message) => CUtils.captureJobStatus(state, code, message)
        onExitRequested: code => Qt.callLater(() => Qt.exit(code))
    }
    Component.onCompleted: {
        root.initialized = true;
        const requestShape = {jobId: root.jobId, outputId: root.outputId, state: "completed",
            result: {path: root.outputPath, mimeType: "image/png", width: 1, height: 1}};
        if (!validator.validJob(requestShape)) {
            job.fail("captureFailed", "Capture helper request is invalid");
        } else if (!root.targetScreen) {
            job.fail("outputUnavailable", "The requested screen is unavailable");
        } else {
            job.begin();
        }
    }
    onTargetScreenChanged: {
        if (initialized && !targetScreen)
            job.fail("outputUnavailable", "The requested screen was disconnected");
    }
    LazyLoader {
        id: pickerLoader
        property bool freeze: false
        property bool closing: false
        property bool clipboardOnly: false
        active: root.initialized && !!root.targetScreen && !job.terminal
        StyledWindow {
            id: window
            name: "capture-job"
            screen: root.targetScreen
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            Picker {
                loader: pickerLoader
                screen: window.screen
                captureJob: true
                capturePath: root.outputPath
                onCaptureStarted: job.consent()
                onCaptureFinished: (ok, width, height) => job.completed(ok, width, height)
                onCaptureDismissed: job.cancel()
            }
        }
    }
}
