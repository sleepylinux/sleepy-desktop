// SPDX-License-Identifier: GPL-3.0-only
import QtQuick
import QtTest
import "../../locker/qml" as Locker

TestCase {
    name: "NativeLockerView"
    visible: true
    width: 1280
    height: 800
    when: windowShown

    Component {
        id: viewComponent
        Locker.SleepyLockView { width: 1280; height: 800; inputLength: 0; authState: 0 }
    }

    function test_absent_information_is_hidden() {
        const view = createTemporaryObject(viewComponent, this);
        verify(view !== null);
        compare(view.hasDetails, false);
        compare(view.resourceRows.length, 0);
        compare(findChild(view, "detailsPanel").visible, false);
        compare(findChild(view, "resourcesPanel").visible, false);
        compare(view.surface, "#181620");
        compare(view.surfaceText, "#e8e2f0");
    }

    function test_supplied_information_is_retained_and_removed_when_cleared() {
        const view = createTemporaryObject(viewComponent, this, {
            weather: { temperature: 0, description: "Clear" },
            media: { title: "A song", artist: "An artist" },
            notificationSummary: { text: "One notification" },
            resources: { cpu: 0, memory: "2 GiB" }
        });
        verify(view !== null);
        compare(view.hasWeather, true);
        compare(view.hasMedia, true);
        compare(view.hasNotifications, true);
        compare(findChild(view, "detailsPanel").visible, true);
        compare(findChild(view, "resourcesPanel").visible, true);
        compare(view.resourceRows.length, 2);
        compare(view.resourceRows[0][1], 0);
        view.weather = {};
        view.media = {};
        view.notificationSummary = {};
        view.resources = {};
        compare(findChild(view, "detailsPanel").visible, false);
        compare(findChild(view, "resourcesPanel").visible, false);
    }
}
