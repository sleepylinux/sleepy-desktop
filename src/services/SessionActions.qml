// SPDX-License-Identifier: GPL-3.0-only
// Typed Sleepy owner for every privileged session mutation.

pragma Singleton

import QtQuick
import "DesktopCommands.js" as DesktopCommands

QtObject {
    id: root

    function resolveAction(command) {
        if (typeof command === "string")
            command = [command];
        if (!command || command.length === 0)
            return "";

        let candidate = String(command[0]);
        if ((candidate === "systemctl" || candidate === "loginctl")
                && command.length === 2) {
            candidate = String(command[1]);
        } else if (candidate === "loginctl" && command.length === 3
                && String(command[1]) === "terminate-user") {
            candidate = "logout";
        } else if (command.length !== 1) {
            return "";
        }

        candidate = candidate.replace(/[-_]/g, "").toLowerCase();
        const actions = ({
            "lock": "lock",
            "locksession": "lock",
            "suspend": "suspend",
            "hibernate": "hibernate",
            "suspendthenhibernate": "suspendThenHibernate",
            "logout": "logout",
            "poweroff": "powerOff",
            "shutdown": "powerOff",
            "reboot": "reboot"
        });
        return actions[candidate] || "";
    }

    function perform(action) {
        const command = DesktopCommands.session(String(action));
        return command ? CommandClient.session(command) : false;
    }

    function exec(command) {
        const resolved = root.resolveAction(command);
        return resolved.length > 0 ? root.perform(resolved) : false;
    }
}
