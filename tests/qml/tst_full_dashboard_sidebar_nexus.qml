// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0

TestCase {
    name: "FullDashboardSidebarNexus"

    function source(relativePath) {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl(relativePath), false);
        request.send();
        return request.responseText;
    }

    function containsAll(text, fragments) {
        for (const fragment of fragments)
            verify(text.indexOf(fragment) >= 0, "missing production contract: " + fragment);
    }

    function test_dashboard_keeps_all_tabs_players_lyrics_weather_and_resources() {
        const content = source("../../src/modules/dashboard/Content.qml");
        const media = source("../../src/modules/dashboard/Media.qml");
        const lyrics = source("../../src/modules/dashboard/media/LyricsAndSelector.qml");
        const weather = source("../../src/modules/dashboard/WeatherTab.qml");
        const resources = source("../../src/modules/dashboard/dash/Resources.qml");

        containsAll(content, ["dashComponent", "mediaComponent", "performanceComponent", "weatherComponent"]);
        containsAll(media, ["Players.active", "state: Players.active ? \"\" : \"noMedia\""]);
        containsAll(lyrics, ["Players.list", "LyricList", "LyricsInfo"]);
        containsAll(weather, ["Weather.forecast", "Weather.reload()", "Weather.humidity", "Weather.windSpeed"]);
        containsAll(resources, ["service: Cpu", "service: Memory", "service: Storage", "Cpu.percentage", "Memory.percentage", "Storage.percentage"]);
    }

    function test_sidebar_and_overlay_keep_grouping_actions_dnd_and_animation() {
        const dock = source("../../src/modules/sidebar/NotifDock.qml");
        const groups = source("../../src/modules/sidebar/NotifGroupList.qml");
        const overlay = source("../../src/modules/notifications/Notification.qml");
        containsAll(dock, ["Notifs.list", "Notifs.notClosed", "NotifDockList", "Anim.StandardExtraLarge"]);
        containsAll(groups, ["modelData", "Anim.DefaultEffects", "LazyListView"]);
        containsAll(overlay, ["root.modelData.actions", "root.modelData.close()", "modelData.invoke()", "GlobalConfig.notifs"]);
    }

    function test_nexus_keeps_network_audio_bluetooth_apps_panels_and_style_pages() {
        const registry = source("../../src/modules/nexus/PageCompRegistry.qml");
        const network = source("../../src/modules/nexus/pages/NetworkPage.qml");
        const audio = source("../../src/modules/nexus/pages/AudioPage.qml");
        const bluetooth = source("../../src/modules/nexus/pages/BluetoothPage.qml");
        const style = source("../../src/modules/nexus/pages/WallpaperAndStyle.qml");
        containsAll(registry, ["NetworkPage", "BluetoothPage", "BluetoothPairing", "AudioPage", "AppVolumes", "AppsPage", "WallpaperAndStyle", "PanelsPage"]);
        containsAll(network, ["Nmcli", "VPN", "NetworkList", "EthernetSection"]);
        containsAll(audio, ["Audio.sinks", "Audio.sources", "Audio.streams", "Audio.setAudioSink", "Audio.setAudioSource"]);
        containsAll(bluetooth, ["Bluetooth.devices", "Bluetooth.defaultAdapter", "device.modelData.connected = !device.connected"]);
        containsAll(style, ["Wallpapers.current", "root.nState.openSubPage(1)", "root.nState.openSubPage(3)", "Colours.setMode"]);
    }

    function test_weather_and_vpn_are_complete_direct_providers() {
        const weather = source("../../src/services/Weather.qml");
        const vpn = source("../../src/services/VPN.qml");
        containsAll(weather, ["Requests.get", "api.open-meteo.com", "hourlyForecast", "forecast", "sleepy-shell/"]);
        containsAll(vpn, ["wireguardAdapter", "warpAdapter", "tailscaleAdapter", "netbirdAdapter", "nmcli", "Process {"]);
        verify(weather.indexOf("DesktopModel") < 0);
        verify(vpn.indexOf("DesktopModel") < 0);
    }

    function test_wifi_secrets_never_enter_process_argv_or_logs() {
        const nmcli = source("../../src/services/Nmcli.qml");
        containsAll(nmcli, ["executeSecretCommand", "stdinPayload", "write(stdinPayload + \"\\n\")", "[\"--ask\", ...args]"]);
        verify(nmcli.indexOf("root.connectionParamPassword, password") < 0);
        verify(nmcli.indexOf("root.securityPsk, password") < 0);
        verify(nmcli.indexOf("command.join(\" \")") < 0);
    }
}
