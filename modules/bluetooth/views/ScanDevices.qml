import QtQuick
import Components

FocusScope {
    id: scanRoot

    property var navParams: ({})

    signal goBack()

    property var devices: []
    property bool scanning: true
    property string statusMessage: ""
    property bool showStatus: false

    Component.onCompleted: {
        bluetoothBackend.startScan()
    }

    Component.onDestruction: {
        bluetoothBackend.stopScan()
    }

    Connections {
        target: bluetoothBackend

        function onScanResult(devs) {
            devices = devs
            scanning = false
        }

        function onPairResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()
        }

        function onConnectResult(success, message) {
            statusMessage = message
            showStatus = true
            statusTimer.restart()

            if (success) {
                bluetoothBackend.stopScan()
                scanning = false
            }
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
        subtitle: "Scan"
    }

    Text {
        visible: scanning && devices.length === 0
        text: "Scanning..."
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    Text {
        visible: scanning && devices.length > 0
        text: "Scanning..."
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.sh * 0.14
        anchors.rightMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0291667

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 800 }
            NumberAnimation { to: 1.0; duration: 800 }
        }
    }

    ListView {
        id: scanList
        model: devices
        visible: devices.length > 0
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

            statusMessage = "Pairing..."
            showStatus = true
            bluetoothBackend.pairAndConnect(dev.address)
        }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                goBack()
                event.accepted = true
            } else if (event.key === Qt.Key_R || event.key === Qt.Key_F5) {
                scanning = true
                devices = []
                bluetoothBackend.stopScan()
                bluetoothBackend.startScan()
                event.accepted = true
            }
        }

        delegate: Item {
            width: scanList.width
            height: root.sh * 0.0583333

            Rectangle {
                anchors.fill: parent
                color: scanList.currentIndex === index ? root.accentColor : "transparent"

                Text {
                    text: modelData.name
                    color: scanList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                Text {
                    text: modelData.address
                    color: scanList.currentIndex === index ? root.surfaceColor : root.secondaryColor
                    font.family: root.globalFont
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.sw * 0.009375
                    topPadding: root.sh * 0.0041667
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.0291667
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
        text: root.hints.back + ":BACK " + root.hints.navigate + ":NAVIGATE " + root.hints.select + ":PAIR " + root.hints.option1 + ":RESCAN"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
