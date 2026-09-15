#!/usr/bin/env bash
# Actual Quickshell Process lifecycle; only the external capture CLI is a fixture.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
qs=${SLEEPY_QS:-$(command -v qs)}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/services" "$tmp/bin" "$tmp/runtime"
chmod 700 "$tmp/runtime"
cp "$repo/src/services/CaptureJobs.qml" "$repo/src/services/CaptureJobsProtocol.qml" "$tmp/services/"
cat > "$tmp/services/qmldir" <<'EOF'
singleton CaptureJobs CaptureJobs.qml
CaptureJobsProtocol CaptureJobsProtocol.qml
EOF
cat > "$tmp/bin/sleepyctl" <<'PY'
#!/usr/bin/env python3
import json,sys
assert sys.argv[1:3] == ['capture','request']
command=json.loads(sys.argv[3])['command']
assert command['type'] in ('begin','cancel')
print(json.dumps({'schemaVersion':1,'payload':{'type':'job','job':{
    'jobId':command['jobId'],'outputId':'output:DP-1',
    'state':'awaitingConsent' if command['type']=='begin' else 'cancelled'}}}))
PY
chmod +x "$tmp/bin/sleepyctl"
cat > "$tmp/shell.qml" <<'QML'
import QtQuick
import Quickshell
import "services" as Services
ShellRoot {
    property bool sawConsent: false
    Component.onCompleted: {
        if (!Services.CaptureJobs.begin("output:DP-1", "22222222-2222-4222-8222-222222222222")) Qt.exit(2);
    }
    Connections {
        target: Services.CaptureJobs
        function onJobChanged() {
            const job = Services.CaptureJobs.job;
            if (job.state === "awaitingConsent") {
                if (job.result || !Services.CaptureJobs.active) Qt.exit(3);
                sawConsent = true;
                Qt.callLater(() => Services.CaptureJobs.cancel());
            } else if (job.state === "cancelled" && sawConsent) {
                console.log("CAPTURE_CLIENT_REAL_PROCESS_CONSENT_CANCEL_OK"); Qt.quit();
            } else Qt.exit(4);
        }
    }
    Timer { interval: 5000; running: true; onTriggered: Qt.exit(5) }
}
QML
timeout 10 env -u WAYLAND_DISPLAY -u DISPLAY QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$tmp/runtime" \
    PATH="$tmp/bin:$PATH" "$qs" -p "$tmp/shell.qml" > "$tmp/output.log" 2>&1
cat "$tmp/output.log"
grep -F 'CAPTURE_CLIENT_REAL_PROCESS_CONSENT_CANCEL_OK' "$tmp/output.log" >/dev/null
printf 'PASS: capture client preserves consent and cancellation across real processes\n'
