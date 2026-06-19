import QtQuick
import Components

FocusScope {
    id: pairedRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    property var devices: []
    property bool loading: true
    property string statusMessage: ""
    property bool showStatus: false

    function refreshDevices() {
        loading = true
        devices = bluetoothBackend.getPairedDevices()
        loading = false

        if (devices.length > 0 && deviceList.currentIndex < 0)
            deviceList.currentIndex = 0
        if (deviceList.currentIndex >= devices.length)
            deviceList.currentIndex = Math.max(0, devices.length - 1)
    }

    Component.onCompleted: {
        refreshDevices()
        var restore = navListState.currentIndex !== undefined ? navListState.currentIndex : 0
        deviceList.currentIndex = Math.min(restore, Math.max(0, devices.length - 1))
        if (devices.length > 0)
            deviceList.positionViewAtIndex(deviceList.currentIndex, ListView.Contain)
    }

    Connections {
        target: bluetoothBackend

        function onConnectResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()
            refreshDevices()
        }

        function onDisconnectResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()
            refreshDevices()
        }

        function onRemoveResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()
            refreshDevices()
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
        subtitle: "Paired Devices"
    }

    Text {
        visible: !loading && devices.length === 0
        text: "No paired devices"
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    ListView {
        id: deviceList
        model: devices
        visible: !loading && devices.length > 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.525
        clip: true
        focus: true

        Keys.onReturnPressed: {
            var dev = devices[currentIndex]
            if (!dev) return

            if (dev.connected) {
                statusMessage = "Disconnecting..."
                showStatus = true
                bluetoothBackend.disconnectDevice(dev.address)
            } else {
                statusMessage = "Connecting..."
                showStatus = true
                bluetoothBackend.connectDevice(dev.address)
            }
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                goBack()
                event.accepted = true
            } else if (event.key === Qt.Key_D || event.key === Qt.Key_Delete) {
                var dev = devices[currentIndex]
                if (dev) {
                    statusMessage = "Removing " + dev.name + "..."
                    showStatus = true
                    bluetoothBackend.removeDevice(dev.address)
                }
                event.accepted = true
            } else if (event.key === Qt.Key_R || event.key === Qt.Key_F5) {
                refreshDevices()
                event.accepted = true
            }
        }

        delegate: Item {
            width: deviceList.width
            height: root.sh * 0.0583333

            Rectangle {
                anchors.fill: parent
                color: deviceList.currentIndex === index ? root.accentColor : "transparent"

                Text {
                    text: modelData.name
                    color: deviceList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                Text {
                    visible: modelData.connected
                    text: "●"
                    color: deviceList.currentIndex === index ? root.surfaceColor : root.accentColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    font.pixelSize: root.sh * 0.0333333
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
        text: root.hints.back + ":BACK " + root.hints.navigate + ":NAVIGATE " + root.hints.select + ":CONNECT/DISCONNECT " + root.hints.option1 + ":REFRESH " + root.hints.option2 + ":REMOVE"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
