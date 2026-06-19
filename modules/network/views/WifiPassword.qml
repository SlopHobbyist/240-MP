import QtQuick
import Components

FocusScope {
    id: passwordRoot

    property var navParams: ({})

    signal goBack()

    property string ssid: navParams.ssid || ""
    property string security: navParams.security || ""
    property string password: ""
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

    focus: true

    Keys.onPressed: function(event) {
        if (connecting) {
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            if (password.length > 0 && event.key === Qt.Key_Backspace) {
                password = password.substring(0, password.length - 1)
                statusMessage = ""
            } else if (event.key === Qt.Key_Escape) {
                goBack()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (password.length > 0) {
                connecting = true
                statusMessage = "Connecting..."
                networkBackend.connectWifi(ssid, password, security)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            showPassword = !showPassword
            event.accepted = true
        } else if (event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
            password += event.text
            statusMessage = ""
            event.accepted = true
        }
    }

    AppBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: ssid
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.3
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        spacing: root.sh * 0.04

        Text {
            text: "Enter Password for " + ssid
            color: root.secondaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.0291667
        }

        Text {
            text: security
            color: root.tertiaryColor
            font.family: root.globalFont
            font.capitalization: Font.AllUppercase
            font.pixelSize: root.sh * 0.025
        }

        Rectangle {
            width: parent.width
            height: root.sh * 0.075
            color: "transparent"
            border.color: root.accentColor
            border.width: root.sw * 0.0015625

            Text {
                id: passwordDisplay
                text: showPassword ? password : password.replace(/./g, "*")
                color: root.primaryColor
                font.family: root.globalFont
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: cursor.left
                leftPadding: root.sw * 0.009375
                font.pixelSize: root.sh * 0.05
                elide: Text.ElideLeft
            }

            Rectangle {
                id: cursor
                anchors.verticalCenter: parent.verticalCenter
                x: Math.min(passwordDisplay.implicitWidth + root.sw * 0.009375, parent.width - root.sw * 0.03)
                width: root.sw * 0.0078125
                height: root.sh * 0.05
                color: root.accentColor
                visible: !connecting

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
        }

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
        text: root.hints.back + ":BACK " + root.hints.select + ":CONNECT [TAB]:SHOW/HIDE"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
