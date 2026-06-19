import QtQuick
import QtQuick.Effects
import Components

FocusScope {
    id: wifiRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    property var networks: []
    property bool scanning: true
    property string statusMessage: ""
    property bool showStatus: false

    Component.onCompleted: {
        networkBackend.scanWifi()
    }

    Connections {
        target: networkBackend

        function onWifiScanComplete(nets) {
            networks = nets
            scanning = false

            var restore = navListState.currentIndex !== undefined ? navListState.currentIndex : 0
            wifiList.currentIndex = Math.min(restore, Math.max(0, nets.length - 1))
            if (nets.length > 0)
                wifiList.positionViewAtIndex(wifiList.currentIndex, ListView.Contain)
        }

        function onWifiConnectResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()

            if (success) {
                scanning = true
                networkBackend.scanWifi()
            }
        }

        function onWifiForgetResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()
            scanning = true
            networkBackend.scanWifi()
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
        subtitle: "WiFi"
    }

    Text {
        visible: scanning
        text: "Scanning..."
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    Text {
        visible: !scanning && networks.length === 0
        text: "No networks found"
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    ListView {
        id: wifiList
        model: networks
        visible: !scanning && networks.length > 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.525
        clip: true
        focus: true

        Keys.onReturnPressed: {
            var net = networks[currentIndex]
            if (!net) return

            if (net.active) {
                networkBackend.disconnectWifi()
                statusMessage = "Disconnected"
                showStatus = true
                statusTimer.restart()
                scanning = true
                networkBackend.scanWifi()
            } else if (net.security === "" || net.security === "--") {
                statusMessage = "Connecting..."
                showStatus = true
                networkBackend.connectOpenWifi(net.ssid)
            } else {
                navigateTo("WifiPassword.qml", { ssid: net.ssid, security: net.security }, { currentIndex: currentIndex })
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                goBack()
                event.accepted = true
            } else if (event.key === Qt.Key_R || event.key === Qt.Key_F5) {
                scanning = true
                networkBackend.scanWifi()
                event.accepted = true
            } else if (event.key === Qt.Key_D || event.key === Qt.Key_Delete) {
                var net = networks[currentIndex]
                if (net) {
                    statusMessage = "Forgetting " + net.ssid + "..."
                    showStatus = true
                    networkBackend.forgetWifi(net.ssid)
                }
                event.accepted = true
            }
        }

        delegate: Item {
            width: wifiList.width
            height: root.sh * 0.0583333

            Rectangle {
                anchors.fill: parent
                color: wifiList.currentIndex === index ? root.accentColor : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.sw * 0.009375
                    anchors.rightMargin: root.sw * 0.009375
                    spacing: root.sw * 0.015625

                    Text {
                        text: modelData.ssid
                        color: wifiList.currentIndex === index ? root.surfaceColor : root.primaryColor
                        font.family: root.globalFont
                        font.capitalization: Font.AllUppercase
                        anchors.verticalCenter: parent.verticalCenter
                        topPadding: root.sh * 0.0041667
                        bottomPadding: root.sh * 0.00625
                        font.pixelSize: root.sh * 0.05
                    }

                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    spacing: root.sw * 0.015625

                    Text {
                        visible: modelData.active
                        text: "●"
                        color: wifiList.currentIndex === index ? root.surfaceColor : root.accentColor
                        font.family: root.globalFont
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: root.sh * 0.0333333
                    }

                    Text {
                        text: {
                            var s = modelData.signal
                            if (s >= 75) return "▂▄▆█"
                            if (s >= 50) return "▂▄▆"
                            if (s >= 25) return "▂▄"
                            return "▂"
                        }
                        color: wifiList.currentIndex === index ? root.surfaceColor : root.secondaryColor
                        font.family: root.globalFont
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: root.sh * 0.0291667
                    }

                    Item {
                        visible: modelData.security !== "" && modelData.security !== "--"
                        width: lockImg.width
                        height: lockImg.height
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: lockImg
                            visible: false
                            height: root.sh * 0.025
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            source: "../assets/images/lock.svg"
                        }
                        MultiEffect {
                            anchors.fill: lockImg
                            source: lockImg
                            colorization: 1.0
                            colorizationColor: wifiList.currentIndex === index ? root.surfaceColor : root.secondaryColor
                        }
                    }
                }
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
        width: statusText.implicitWidth + root.sw * 0.03125
        height: statusText.implicitHeight + root.sh * 0.02

        Text {
            id: statusText
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
        text: root.hints.back + ":BACK " + root.hints.navigate + ":NAVIGATE " + root.hints.select + ":CONNECT " + root.hints.option1 + ":RESCAN " + root.hints.option2 + ":FORGET"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
