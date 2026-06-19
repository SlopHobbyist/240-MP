import QtQuick
import Components

FocusScope {
    id: ethRoot

    property var navParams: ({})

    signal goBack()

    property var ethStatus: ({})
    property bool isDhcp: true
    property string statusMessage: ""
    property bool showStatus: false

    property var menuItems: []
    property int editingField: -1
    property string editBuffer: ""

    property string staticIp: ""
    property string staticGateway: ""
    property string staticDns: ""

    function refreshStatus() {
        ethStatus = networkBackend.getEthernetStatus()
        isDhcp = ethStatus.method !== "manual"

        var currentIp = ethStatus.ip || ""
        if (currentIp.contains && currentIp.contains('/'))
            currentIp = currentIp.split('/')[0]

        if (!isDhcp) {
            staticIp = currentIp
            staticGateway = ethStatus.gateway || ""
            staticDns = ethStatus.dns || ""
        }

        buildModel()
    }

    function buildModel() {
        var items = []

        items.push({ type: "section", label: "Status:" })

        if (ethStatus.available === false) {
            items.push({ type: "info", label: "No Ethernet Adapter", detail: "" })
        } else {
            var state = ethStatus.state || "unknown"
            var ip = ethStatus.ip || ""
            if (ip.indexOf && ip.indexOf('/') >= 0) ip = ip.split('/')[0]
            items.push({ type: "info", label: state === "connected" ? "Connected" : "Disconnected", detail: ip })
        }

        items.push({ type: "section", label: "Configuration:" })
        items.push({ type: "toggle", label: "Mode", value: isDhcp ? "DHCP" : "Static", key: "mode" })

        if (!isDhcp) {
            items.push({ type: "editable", label: "IP Address", value: staticIp, key: "ip" })
            items.push({ type: "editable", label: "Gateway", value: staticGateway, key: "gateway" })
            items.push({ type: "editable", label: "DNS", value: staticDns, key: "dns" })
        }

        items.push({ type: "section", label: "" })
        items.push({ type: "action", label: "Apply", key: "apply" })

        menuItems = items
    }

    function firstSelectableAfter(idx) {
        for (var i = idx + 1; i < menuItems.length; i++) {
            var t = menuItems[i].type
            if (t === "toggle" || t === "editable" || t === "action") return i
        }
        return ethList.currentIndex
    }

    function firstSelectableBefore(idx) {
        for (var i = idx - 1; i >= 0; i--) {
            var t = menuItems[i].type
            if (t === "toggle" || t === "editable" || t === "action") return i
        }
        return ethList.currentIndex
    }

    function isSelectable(idx) {
        if (idx < 0 || idx >= menuItems.length) return false
        var t = menuItems[idx].type
        return t === "toggle" || t === "editable" || t === "action"
    }

    Component.onCompleted: refreshStatus()

    Connections {
        target: networkBackend
        function onEthernetConfigResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()
            if (success) refreshStatus()
        }
    }

    Timer {
        id: statusTimer
        interval: 3000
        onTriggered: showStatus = false
    }

    AppBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: "Ethernet"
    }

    ListView {
        id: ethList
        model: menuItems
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.525
        clip: true
        focus: editingField < 0

        Component.onCompleted: {
            for (var i = 0; i < menuItems.length; i++) {
                if (isSelectable(i)) { currentIndex = i; break }
            }
        }

        Keys.onUpPressed: {
            var prev = ethRoot.firstSelectableBefore(currentIndex)
            if (prev !== currentIndex) currentIndex = prev
        }
        Keys.onDownPressed: {
            var next = ethRoot.firstSelectableAfter(currentIndex)
            if (next !== currentIndex) currentIndex = next
        }

        Keys.onLeftPressed: {
            var row = menuItems[currentIndex]
            if (row && row.type === "toggle") {
                isDhcp = !isDhcp
                buildModel()
                var savedIdx = currentIndex
                ethList.currentIndex = savedIdx
            }
        }
        Keys.onRightPressed: {
            var row = menuItems[currentIndex]
            if (row && row.type === "toggle") {
                isDhcp = !isDhcp
                buildModel()
                var savedIdx = currentIndex
                ethList.currentIndex = savedIdx
            }
        }

        Keys.onReturnPressed: {
            var row = menuItems[currentIndex]
            if (!row) return

            if (row.type === "editable") {
                editingField = currentIndex
                editBuffer = row.value || ""
            } else if (row.type === "action" && row.key === "apply") {
                if (isDhcp) {
                    statusMessage = "Applying DHCP..."
                    showStatus = true
                    networkBackend.setEthernetDhcp()
                } else {
                    if (staticIp === "" || staticGateway === "") {
                        statusMessage = "IP and Gateway required"
                        showStatus = true
                        statusTimer.restart()
                        return
                    }
                    statusMessage = "Applying static config..."
                    showStatus = true
                    networkBackend.setEthernetStatic(staticIp, staticGateway, staticDns)
                }
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                goBack()
                event.accepted = true
            }
        }

        delegate: Item {
            width: ethList.width
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
                    leftPadding: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
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
                visible: modelData.type === "toggle"
                anchors.fill: parent
                color: ethList.currentIndex === index ? root.accentColor : "transparent"

                Text {
                    text: modelData.label || ""
                    color: ethList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    spacing: root.sw * 0.00625

                    Text {
                        text: "◄"
                        color: ethList.currentIndex === index ? root.surfaceColor : root.tertiaryColor
                        font.family: root.globalFont
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: root.sh * 0.0375
                    }
                    Text {
                        text: modelData.value || ""
                        color: ethList.currentIndex === index ? root.surfaceColor : root.primaryColor
                        font.family: root.globalFont
                        font.capitalization: Font.AllUppercase
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: root.sw * 0.009375
                        rightPadding: root.sw * 0.009375
                        topPadding: root.sh * 0.0041667
                        bottomPadding: root.sh * 0.00625
                        font.pixelSize: root.sh * 0.05
                    }
                    Text {
                        text: "►"
                        color: ethList.currentIndex === index ? root.surfaceColor : root.tertiaryColor
                        font.family: root.globalFont
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: root.sh * 0.0375
                    }
                }
            }

            Rectangle {
                visible: modelData.type === "editable"
                anchors.fill: parent
                color: ethList.currentIndex === index ? root.accentColor : "transparent"

                Text {
                    text: modelData.label || ""
                    color: ethList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                Rectangle {
                    visible: editingField === index
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    width: root.sw * 0.35
                    height: root.sh * 0.045
                    color: "transparent"
                    border.color: root.accentColor
                    border.width: root.sw * 0.0015625

                    Text {
                        text: editBuffer
                        color: root.primaryColor
                        font.family: root.globalFont
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        leftPadding: root.sw * 0.005
                        font.pixelSize: root.sh * 0.035
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: editFieldText.implicitWidth + root.sw * 0.005
                        width: root.sw * 0.005
                        height: root.sh * 0.035
                        color: root.accentColor

                        Text {
                            id: editFieldText
                            visible: false
                            text: editBuffer
                            font.family: root.globalFont
                            font.pixelSize: root.sh * 0.035
                        }

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 500 }
                            NumberAnimation { to: 1; duration: 500 }
                        }
                    }
                }

                Text {
                    visible: editingField !== index
                    text: modelData.value || "(not set)"
                    color: ethList.currentIndex === index ? root.surfaceColor : root.secondaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.0375
                }
            }

            Rectangle {
                visible: modelData.type === "action"
                anchors.fill: parent
                color: ethList.currentIndex === index ? root.accentColor : "transparent"

                Text {
                    text: modelData.label || ""
                    color: ethList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    rightPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }
            }
        }
    }

    FocusScope {
        id: editFocus
        focus: editingField >= 0
        visible: false

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                var row = menuItems[editingField]
                if (row) {
                    if (row.key === "ip") staticIp = editBuffer
                    else if (row.key === "gateway") staticGateway = editBuffer
                    else if (row.key === "dns") staticDns = editBuffer
                }
                editingField = -1
                buildModel()
                ethList.forceActiveFocus()
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                editingField = -1
                ethList.forceActiveFocus()
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (editBuffer.length > 0)
                    editBuffer = editBuffer.substring(0, editBuffer.length - 1)
                event.accepted = true
            } else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
                editBuffer += event.text
                event.accepted = true
            }
        }
    }

    Rectangle {
        visible: showStatus
        anchors.bottom: footerText.top
        anchors.bottomMargin: root.sh * 0.02
        anchors.horizontalCenter: parent.horizontalCenter
        color: root.surfaceColor
        border.color: root.tertiaryColor
        border.width: root.sw * 0.0015625
        width: ethStatusText.implicitWidth + root.sw * 0.03125
        height: ethStatusText.implicitHeight + root.sh * 0.02

        Text {
            id: ethStatusText
            text: statusMessage
            color: root.primaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            anchors.centerIn: parent
            font.pixelSize: root.sh * 0.0333333
        }
    }

    Text {
        id: footerText
        text: editingField >= 0
            ? root.hints.back + ":CANCEL " + root.hints.select + ":CONFIRM"
            : root.hints.back + ":BACK " + root.hints.navigate + ":NAVIGATE " + root.hints.change + ":CHANGE " + root.hints.select + ":EDIT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
