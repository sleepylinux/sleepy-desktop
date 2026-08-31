//@ pragma ShellId sleepy
//@ pragma Env QS_CRASHREPORT_URL=https://github.com/sleepy-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "theme" as Theme
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: root

    readonly property bool portalDark: Application.styleHints.colorScheme !== Qt.Light

    settings.watchFiles: true

    Theme.EffectsPolicy {
        id: effects
        reducedMotion: false
    }

    Theme.ThemeTokens {
        id: tokens
        effectsPolicy: effects
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    GSFLoader {}
    ServiceLoader {}

    Background {}
    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
}
