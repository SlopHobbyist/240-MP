import QtQuick
import Components

FocusScope {
    id: itemsRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    property var menuItems: []
    property bool powered: false

    function refreshStatus() {
        var status = bluetoothBackend.getAdapterStatus()
        powered = status.powered || false

        var items = []
        items.push({ type: "section", label: "Status:" })

        if (!status.available) {
            items.push({ type: "info", label: "No Bluetooth Adapter", detail: "" })
        } else if (!powered) {
            items.push({ type: "info", label: "Powered Off", detail: "" })
        } else if ((status.connectedCount || 0) > 0) {
            items.push({ type: "info", label: "Connected: " + status.connectedName, detail: "" })
        } else {
            items.push({ type: "info", label: "No Devices Connected", detail: "" })
        }

        items.push({ type: "section", label: "Configure:" })
        items.push({ type: "toggle", label: "Bluetooth", value: powered ? "On" : "Off", action: "togglePower" })
        if (powered) {
            items.push({ type: "nav", label: "Paired Devices", target: "PairedDevices.qml" })
            items.push({ type: "nav", label: "Scan for Devices", target: "ScanDevices.qml" })
        }

        menuItems = items
    }

    function isSelectable(item) {
        return item.type === "nav" || item.type === "toggle"
    }

    function firstSelectableAfter(idx) {
        for (var i = idx + 1; i < menuItems.length; i++)
            if (isSelectable(menuItems[i])) return i
        return itemList.currentIndex
    }

    function firstSelectableBefore(idx) {
        for (var i = idx - 1; i >= 0; i--)
            if (isSelectable(menuItems[i])) return i
        return itemList.currentIndex
    }

    Connections {
        target: bluetoothBackend
        function onPowerChanged() { refreshStatus() }
    }

    Component.onCompleted: {
        refreshStatus()
        var restore = navListState.currentIndex !== undefined ? navListState.currentIndex : -1
        if (restore >= 0 && restore < menuItems.length) {
            itemList.currentIndex = restore
        } else {
            for (var i = 0; i < menuItems.length; i++) {
                if (isSelectable(menuItems[i])) { itemList.currentIndex = i; break }
            }
        }
        itemList.positionViewAtIndex(itemList.currentIndex, ListView.Contain)
    }

    AppBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
    }

    ListView {
        id: itemList
        model: menuItems
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.525
        clip: true
        focus: true

        Keys.onUpPressed: {
            var prev = itemsRoot.firstSelectableBefore(currentIndex)
            if (prev !== currentIndex) currentIndex = prev
        }
        Keys.onDownPressed: {
            var next = itemsRoot.firstSelectableAfter(currentIndex)
            if (next !== currentIndex) currentIndex = next
        }

        Keys.onReturnPressed: {
            var row = menuItems[currentIndex]
            if (!row) return

            if (row.type === "toggle" && row.action === "togglePower") {
                bluetoothBackend.setPower(!powered)
            } else if (row.type === "nav" && row.target) {
                navigateTo(row.target, {}, { currentIndex: currentIndex })
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                goBack()
                event.accepted = true
            }
        }

        delegate: Item {
            width: itemList.width
            height: root.sh * 0.0583333

            Text {
                visible: modelData.type === "section"
                text: modelData.label || ""
                color: root.secondaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.verticalCenter: parent.verticalCenter
                topPadding: root.sh * 0.0020833
                leftPadding: root.sw * 0.009375
                rightPadding: root.sw * 0.009375
                font.pixelSize: root.sh * 0.0291667
            }

            Rectangle {
                visible: modelData.type === "info"
                anchors.fill: parent
                color: "transparent"

                Text {
                    text: modelData.label || ""
                    color: root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    rightPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }
            }

            Rectangle {
                visible: modelData.type === "toggle"
                anchors.fill: parent
                color: itemList.currentIndex === index ? root.accentColor : "transparent"

                Text {
                    text: modelData.label || ""
                    color: itemList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                Text {
                    text: modelData.value || ""
                    color: itemList.currentIndex === index ? root.surfaceColor : root.secondaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.0375
                }
            }

            Rectangle {
                visible: modelData.type === "nav"
                anchors.fill: parent
                color: itemList.currentIndex === index ? root.accentColor : "transparent"

                Text {
                    text: modelData.label || ""
                    color: itemList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    rightPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                Text {
                    text: "►"
                    color: itemList.currentIndex === index ? root.surfaceColor : root.tertiaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.0375
                }
            }
        }
    }

    Text {
        text: root.hints.back + ":BACK " + root.hints.navigate + ":NAVIGATE " + root.hints.select + ":SELECT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
