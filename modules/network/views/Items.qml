import QtQuick
import Components

FocusScope {
    id: itemsRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    property var menuItems: []
    property string activeType: ""
    property string activeName: ""
    property string activeIp: ""

    function refreshStatus() {
        var conn = networkBackend.getActiveConnection()
        activeType = conn.type || "none"
        activeName = conn.name || ""
        activeIp = conn.ip || ""

        var items = []
        items.push({ type: "section", label: "Current Connection:" })

        if (activeType === "wifi")
            items.push({ type: "info", label: "WiFi: " + activeName, detail: activeIp })
        else if (activeType === "ethernet")
            items.push({ type: "info", label: "Ethernet: " + activeName, detail: activeIp })
        else
            items.push({ type: "info", label: "Not Connected", detail: "" })

        items.push({ type: "section", label: "Configure:" })
        items.push({ type: "nav", label: "WiFi", target: "WifiList.qml" })
        items.push({ type: "nav", label: "Manual WiFi", target: "WifiManual.qml" })
        items.push({ type: "nav", label: "Ethernet", target: "EthernetConfig.qml" })

        menuItems = items
    }

    function firstSelectableAfter(idx) {
        for (var i = idx + 1; i < menuItems.length; i++)
            if (menuItems[i].type === "nav") return i
        return itemList.currentIndex
    }

    function firstSelectableBefore(idx) {
        for (var i = idx - 1; i >= 0; i--)
            if (menuItems[i].type === "nav") return i
        return itemList.currentIndex
    }

    Component.onCompleted: {
        refreshStatus()
        var restore = navListState.currentIndex !== undefined ? navListState.currentIndex : -1
        if (restore >= 0 && restore < menuItems.length) {
            itemList.currentIndex = restore
        } else {
            for (var i = 0; i < menuItems.length; i++) {
                if (menuItems[i].type === "nav") { itemList.currentIndex = i; break }
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
            if (row && row.type === "nav") {
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

                Text {
                    visible: (modelData.detail || "") !== ""
                    text: modelData.detail || ""
                    color: root.secondaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.0333333
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
