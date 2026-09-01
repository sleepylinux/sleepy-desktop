// SPDX-License-Identifier: GPL-3.0-only

import QtQuick 6.0
import QtTest 1.0
import Sleepy
import Sleepy.Models
import Sleepy.Services

TestCase {
    id: testCase
    name: "NativeFullPlugin"

    Component {
        id: appDbFactory
        AppDb {
            path: ""
            entries: []
            favouriteApps: []
        }
    }

    Component {
        id: fileSystemFactory
        FileSystemModel {
            path: ""
            watchChanges: false
        }
    }

    function test_models_are_creatable() {
        verify(createTemporaryObject(appDbFactory, testCase) !== null);
        verify(createTemporaryObject(fileSystemFactory, testCase) !== null);
    }

    function test_core_and_resource_singletons_are_ready() {
        verify(Qalculator !== null);
        compare(Qalculator.eval("1 + 1", false), "2");
        verify(Cpu !== null);
        verify(Memory !== null);
        verify(UsageFmt !== null);
    }
}
