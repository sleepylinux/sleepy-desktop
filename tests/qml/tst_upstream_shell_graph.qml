// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    name: "UpstreamShellGraph"

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function escaped(value) {
        return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function componentBlock(text, typeName, objectName) {
        const pattern = new RegExp("\\b" + escaped(typeName)
            + "\\s*\\{[^}]*\\bobjectName\\s*:\\s*\\\""
            + escaped(objectName) + "\\\"");
        return pattern.test(text);
    }

    function test_production_root_declares_complete_modular_graph() {
        const shell = source("../../src/shell.qml");

        verify(shell.includes('import "modules"'));
        verify(shell.includes('import "modules/drawers"'));
        verify(shell.includes('import "modules/background"'));
        verify(shell.includes('import "modules/areapicker"'));

        const required = [
            ["Background", "background"],
            ["Drawers", "drawers"],
            ["AreaPicker", "areaPicker"],
            ["Shortcuts", "shortcuts"],
            ["BatteryMonitor", "batteryMonitor"],
            ["IdleMonitors", "idleMonitors"]
        ];
        for (const entry of required)
            verify(componentBlock(shell, entry[0], entry[1]), entry[0]);

        verify(/\bGSFLoader\s*\{/.test(shell));
        verify(/\bServiceLoader\s*\{/.test(shell));
        verify(/target\s*:\s*ShellState/.test(shell));
        verify(/property\s*:\s*"shellRoot"/.test(shell));
    }

    function test_reduced_core_and_decorative_lock_are_not_active() {
        const shell = source("../../src/shell.qml");

        verify(!/\bCoreDesktopWindows\s*\{/.test(shell));
        verify(!/objectName\s*:\s*"sleepyCoreDesktop"/.test(shell));
        verify(!/^\s*import\s+"modules\/lock"/m.test(shell));
        verify(!/\bLock\s*\{/.test(shell));
    }
}
