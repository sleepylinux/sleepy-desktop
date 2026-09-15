#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Exercise Nmcli's actual Process component in the supplied Quickshell engine."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def block(source, prefix):
    start = source.index(prefix)
    opening = source.index("{", start)
    depth = 1
    for end in range(opening + 1, len(source)):
        depth += (source[end] == "{") - (source[end] == "}")
        if depth == 0:
            return source[start:end + 1]
    raise ValueError(f"unterminated {prefix}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("quickshell")
    parser.add_argument("shell")
    args = parser.parse_args()
    source = (Path(__file__).resolve().parents[1] / "src/services/Nmcli.qml").read_text()
    component = block(source, "component CommandProcess: Process {")
    # Count real QObject destruction, including the Process-owned collectors.
    component = component.replace("id: proc", "id: proc\nComponent.onCompleted: root.alive++\nComponent.onDestruction: root.alive--", 1)
    for name in ("stdoutCollector", "stderrCollector"):
        component = component.replace(f"id: {name}", f"id: {name}\nComponent.onCompleted: root.collectors++\nComponent.onDestruction: root.collectors--", 1)
    functions = "\n".join(block(source, f"function {name}(") for name in ("executeCommand", "retireCommandProcess"))
    qml = r'''
import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id: root
    property var activeProcesses: []
    property int alive: 0
    property int collectors: 0
    property int callbacks: 0
    property int finishes: 0
    property int exits: 0
    property int starts: 0
    property string lastError: ""
    property var pendingConnection: null
    property int refreshes: 0
    property var cases: [
        {argv: ["/sleepy-regression-no-such-program"], success: false, code: -1, starts: 0, exits: 0},
        {argv: [SHELL, "-c", "printf stdout-value; printf stderr-value >&2; exit 0"], success: true, code: 0, starts: 1, exits: 1},
        {argv: [SHELL, "-c", "exit 7"], success: false, code: 7, starts: 1, exits: 1},
        {argv: [SHELL, "-c", "kill -TERM $$"], success: false, starts: 1, exits: 1}
    ]
    property int current: -1
    property int attempts: 0
    property bool finished: false
    function check(condition, message) {
        if (!condition) {
            console.error("NMCLI_PROCESS_FAIL: " + message);
            Qt.quit();
            throw new Error(message);
        }
    }
    function isConnectionCommand(args) { return false; }
    function isMutationCommand(args) { return false; }
    function handlePasswordRequired(proc, error, output, code) { return false; }
    function detectPasswordRequired(error) { return false; }
    function refresh() { refreshes++; }
    function runNext() {
        current++;
        if (current >= cases.length) {
            check(refreshes === 0, "queries/failures must not refresh");
            finished = true;
            console.log("NMCLI_PROCESS_PASS: missing executable, normal exit, failure exit, signal exit; callbacks once; Process and collectors destroyed");
            Qt.quit();
            return;
        }
        const item = cases[current];
        callbacks = 0; finishes = 0; starts = 0; exits = 0;
        executeCommand([], result => {
            callbacks++;
            check(result.success === item.success, "success result " + current);
            if (item.code !== undefined)
                check(result.exitCode === item.code, "exit code " + current);
            if (current === 0)
                check(result.error.length > 0 && result.needsPassword === false, "missing executable diagnostic");
            if (current === 1)
                check(result.output === "stdout-value" && result.error === "stderr-value", "collectors retained until callback");
        }, "");
        const proc = activeProcesses[activeProcesses.length - 1];
        // executeCommand intentionally defers exec; change only the program under
        // test so these cases cannot invoke the user's real NetworkManager.
        proc.cmdArgs = item.argv;
        proc.processFinished.connect(() => finishes++);
        proc.started.connect(() => starts++);
        proc.exited.connect(() => exits++);
        attempts = 0;
        completionPoll.start();
    }
    Timer {
        id: completionPoll
        interval: 10
        repeat: true
        onTriggered: {
            attempts++;
            if (root.callbacks === 1 && root.finishes === 1 && root.alive === 0 && root.collectors === 0 && root.activeProcesses.length === 0) {
                stop();
                root.check(root.starts === root.cases[root.current].starts && root.exits === root.cases[root.current].exits, "real process signal sequence " + root.current);
                Qt.callLater(root.runNext);
            } else if (attempts >= 200) {
                root.check(false, "completion/ownership timeout: callbacks=" + root.callbacks + " finishes=" + root.finishes + " alive=" + root.alive + " collectors=" + root.collectors + " active=" + root.activeProcesses.length);
            }
        }
    }
    Component { id: commandProc; CommandProcess {} }
    FUNCTIONS
    COMPONENT
    Component.onCompleted: Qt.callLater(runNext)
}
'''
    qml = qml.replace("SHELL", json.dumps(args.shell)).replace("FUNCTIONS", functions).replace("COMPONENT", component)
    with tempfile.TemporaryDirectory(prefix="sleepy-nmcli-process-") as directory:
        config = Path(directory) / "shell.qml"
        config.write_text(qml)
        runtime = Path(directory) / "runtime"
        runtime.mkdir(mode=0o700)
        environment = os.environ.copy()
        environment.update(XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        for name in ("WAYLAND_DISPLAY", "WAYLAND_SOCKET", "QT_QPA_PLATFORMTHEME"):
            environment.pop(name, None)
        try:
            result = subprocess.run([args.quickshell, "--no-color", "--path", str(config)], timeout=15, capture_output=True, text=True, env=environment)
        except subprocess.TimeoutExpired as error:
            print((error.stdout or b"").decode(errors="replace"))
            print((error.stderr or b"").decode(errors="replace"))
            raise SystemExit("actual Process fixture exceeded its deadline")
        output = result.stdout + result.stderr
        print(output, end="")
        if result.returncode != 0 or "NMCLI_PROCESS_PASS:" not in output:
            raise SystemExit("actual Nmcli Process lifecycle regression failed")


if __name__ == "__main__":
    main()
