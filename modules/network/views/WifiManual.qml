import QtQuick
import Components

FocusScope {
    id: manualRoot

    property var navParams: ({})

    signal goBack()

    property int activeField: 0   // 0 = ssid, 1 = security, 2 = password
    property string ssid: ""
    property string password: ""
    property var securityOptions: ["WPA2", "WPA3 (SAE)", "Open"]
    property int securityIndex: 0
    property string security: securityOptions[securityIndex]
    property bool needsPassword: securityIndex < 2
    property int fieldCount: needsPassword ? 3 : 2
    property bool connecting: false
    property string statusMessage: ""
    property bool showPassword: false

    Connections {
        target: networkBackend

        function onWifiConnectResult(success, message) {
            connecting = false
            if (success) {
                goBack()
            } else {
                statusMessage = message
            }
        }
    }

    function submit() {
        if (ssid.length === 0) {
            statusMessage = "Enter a network name"
            return
        }
        if (needsPassword && password.length === 0) {
            statusMessage = "Enter a password"
            return
        }
        connecting = true
        statusMessage = "Connecting..."
        if (needsPassword)
            networkBackend.connectWifi(ssid, password, security)
        else
            networkBackend.connectOpenWifi(ssid)
    }

    focus: true

    Keys.onPressed: function(event) {
        if (connecting) {
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Escape) {
            goBack()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Up) {
            if (activeField > 0) activeField--
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Down) {
            if (activeField < fieldCount - 1) activeField++
            event.accepted = true
            return
        }

        if (activeField === 1) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                var dir = event.key === Qt.Key_Right ? 1 : -1
                securityIndex = (securityIndex + dir + securityOptions.length) % securityOptions.length
                if (!needsPassword) {
                    password = ""
                    if (activeField >= fieldCount) activeField = fieldCount - 1
                }
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (needsPassword)
                    activeField = 2
                else
                    submit()
                event.accepted = true
                return
            }
        }

        if (activeField === 0 || activeField === 2) {
            if (event.key === Qt.Key_Backspace) {
                if (activeField === 0 && ssid.length > 0)
                    ssid = ssid.substring(0, ssid.length - 1)
                else if (activeField === 2 && password.length > 0)
                    password = password.substring(0, password.length - 1)
                statusMessage = ""
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (activeField === 0 && ssid.length > 0) {
                    activeField = 1
                } else {
                    submit()
                }
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Tab) {
                showPassword = !showPassword
                event.accepted = true
                return
            }
            if (event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
                if (activeField === 0)
                    ssid += event.text
                else
                    password += event.text
                statusMessage = ""
                event.accepted = true
                return
            }
        }
    }

    AppBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: "Manual WiFi"
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.3
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        spacing: root.sh * 0.025

        // ── SSID field ──
        Text {
            text: "Network Name (SSID)"
            color: activeField === 0 ? root.primaryColor : root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0291667
        }

        Rectangle {
            width: parent.width
            height: root.sh * 0.075
            color: "transparent"
            border.color: activeField === 0 ? root.accentColor : root.tertiaryColor
            border.width: root.sw * 0.0015625

            Text {
                id: ssidDisplay
                text: ssid
                color: root.primaryColor
                font.family: root.globalFont
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: ssidCursor.left
                leftPadding: root.sw * 0.009375
                font.pixelSize: root.sh * 0.05
                elide: Text.ElideLeft
            }

            Rectangle {
                id: ssidCursor
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(ssidDisplay.implicitWidth + root.sw * 0.009375, parent.width - root.sw * 0.03)
                width: root.sw * 0.0078125
                height: root.sh * 0.05
                color: root.accentColor
                visible: activeField === 0 && !connecting

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
        }

        // ── Security selector ──
        Text {
            text: "Security"
            color: activeField === 1 ? root.primaryColor : root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0291667
        }

        Rectangle {
            width: parent.width
            height: root.sh * 0.075
            color: activeField === 1 ? root.accentColor : "transparent"
            border.color: activeField === 1 ? root.accentColor : root.tertiaryColor
            border.width: root.sw * 0.0015625

            Text {
                text: "◄  " + security + "  ►"
                color: activeField === 1 ? root.surfaceColor : root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: root.sh * 0.0041667
                bottomPadding: root.sh * 0.00625
                font.pixelSize: root.sh * 0.05
            }
        }

        // ── Password field ──
        Text {
            visible: needsPassword
            text: "Password"
            color: activeField === 2 ? root.primaryColor : root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0291667
        }

        Rectangle {
            visible: needsPassword
            width: parent.width
            height: root.sh * 0.075
            color: "transparent"
            border.color: activeField === 2 ? root.accentColor : root.tertiaryColor
            border.width: root.sw * 0.0015625

            Text {
                id: passDisplay
                text: showPassword ? password : password.replace(/./g, "*")
                color: root.primaryColor
                font.family: root.globalFont
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: passCursor.left
                leftPadding: root.sw * 0.009375
                font.pixelSize: root.sh * 0.05
                elide: Text.ElideLeft
            }

            Rectangle {
                id: passCursor
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(passDisplay.implicitWidth + root.sw * 0.009375, parent.width - root.sw * 0.03)
                width: root.sw * 0.0078125
                height: root.sh * 0.05
                color: root.accentColor
                visible: activeField === 2 && !connecting

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
        }

        // ── Status message ──
        Text {
            visible: statusMessage !== ""
            text: statusMessage
            color: connecting ? root.secondaryColor : root.accentColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0333333
        }
    }

    Text {
        text: root.hints.back + ":BACK " + root.hints.navigate + ":FIELD " + root.hints.select + ":CONNECT [TAB]:SHOW/HIDE"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
