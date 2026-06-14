import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

ApplicationWindow {
    id: root
    width: mainWidth
    height: mainHeight
    minimumWidth: mainWidth
    minimumHeight: mainHeight
    maximumWidth: mainWidth
    maximumHeight: mainHeight
    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window | Qt.WindowStaysOnTopHint
    title: "Floating Countdown"

    property int minutesValue: 1
    property int secondsValue: 0
    property int remainingSeconds: 60
    property bool running: false
    property bool paused: false
    property bool pinned: settings.pinned
    property string statusText: remainingSeconds === 0 ? "时间到" : (running ? "计时中" : (paused ? "已暂停" : "准备好"))

    readonly property int mainWidth: 380
    readonly property int mainHeight: 420
    readonly property int miniWidth: 292
    readonly property int miniHeight: 132

    readonly property color ink: "#F7F4EA"
    readonly property color muted: "#A7AFBF"
    readonly property color panel: "#D91E2530"
    readonly property color line: "#22FFFFFF"
    readonly property color fieldBg: "#18FFFFFF"
    readonly property color accent: "#63D8B6"
    readonly property color warm: "#F1B869"

    Settings {
        id: settings
        category: "window"
        property int mainX: 120
        property int mainY: 120
        property int miniX: 160
        property int miniY: 160
        property bool pinned: false
    }

    Component.onCompleted: {
        applyWindowSize()
        x = pinned ? settings.miniX : settings.mainX
        y = pinned ? settings.miniY : settings.mainY
        syncDuration()
    }

    onXChanged: saveWindowPosition()
    onYChanged: saveWindowPosition()
    onClosing: saveWindowPosition()

    Timer {
        id: ticker
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (remainingSeconds > 0) {
                remainingSeconds -= 1
            }
            if (remainingSeconds <= 0) {
                remainingSeconds = 0
                root.running = false
                root.paused = false
            }
        }
    }

    function pad(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function displayTime() {
        const mins = Math.floor(remainingSeconds / 60)
        const secs = remainingSeconds % 60
        return pad(mins) + ":" + pad(secs)
    }

    function clampInputs() {
        minutesValue = Math.max(0, Math.min(9999, Number(minutesInput.text || 0)))
        secondsValue = Math.max(0, Math.min(59, Number(secondsInput.text || 0)))
        minutesInput.text = String(minutesValue)
        secondsInput.text = String(secondsValue)
    }

    function syncDuration() {
        const active = root.running || root.paused
        if (!active) {
            remainingSeconds = Math.max(0, minutesValue * 60 + secondsValue)
        }
    }

    function toggleStartPause() {
        clampInputs()
        if (running) {
            running = false
            paused = true
            return
        }
        if (remainingSeconds <= 0 || !paused) {
            remainingSeconds = Math.max(0, minutesValue * 60 + secondsValue)
        }
        if (remainingSeconds > 0) {
            running = true
            paused = false
        }
    }

    function resetTimer() {
        clampInputs()
        running = false
        paused = false
        remainingSeconds = Math.max(0, minutesValue * 60 + secondsValue)
    }

    function togglePin() {
        const currentX = root.x
        const currentY = root.y

        settings.mainX = currentX
        settings.mainY = currentY
        settings.miniX = currentX
        settings.miniY = currentY

        pinned = !pinned
        settings.pinned = pinned
        applyWindowSize()
        x = currentX
        y = currentY
    }

    function applyWindowSize() {
        const nextWidth = pinned ? miniWidth : mainWidth
        const nextHeight = pinned ? miniHeight : mainHeight

        maximumWidth = 10000
        maximumHeight = 10000
        minimumWidth = 1
        minimumHeight = 1
        width = nextWidth
        height = nextHeight
        minimumWidth = nextWidth
        maximumWidth = nextWidth
        minimumHeight = nextHeight
        maximumHeight = nextHeight
    }

    function saveWindowPosition() {
        if (pinned) {
            settings.miniX = root.x
            settings.miniY = root.y
        } else {
            settings.mainX = root.x
            settings.mainY = root.y
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: pinned ? 28 : 34
        color: panel
        border.color: line
        border.width: 1

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemMove()
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "#10141D"
            opacity: 0.92
        }

        Canvas {
            anchors.fill: parent
            opacity: pinned ? 0.42 : 0.55
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const gradient = ctx.createLinearGradient(0, 0, width, height)
                gradient.addColorStop(0, "rgba(99,216,182,0.26)")
                gradient.addColorStop(0.58, "rgba(241,184,105,0.07)")
                gradient.addColorStop(1, "rgba(125,145,255,0.12)")
                ctx.fillStyle = gradient
                ctx.fillRect(0, 0, width, height)

                ctx.strokeStyle = "rgba(255,255,255,0.13)"
                ctx.lineWidth = 1
                for (let i = -60; i < width; i += 28) {
                    ctx.beginPath()
                    ctx.moveTo(i, height)
                    ctx.lineTo(i + height * 0.65, 0)
                    ctx.stroke()
                }
            }
        }
    }

    Item {
        id: mainView
        anchors.fill: parent
        visible: !pinned

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "Floating Countdown"
                        color: ink
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: statusText
                        color: muted
                        font.family: "Microsoft YaHei UI"
                        font.pixelSize: 12
                    }
                }

                ChipButton {
                    text: "Pin"
                    width: 58
                    accentColor: root.accent
                    onClicked: root.togglePin()
                }
                ChipButton {
                    text: "X"
                    width: 40
                    accentColor: "#FF7F73"
                    onClicked: Qt.quit()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 132

                Text {
                    anchors.centerIn: parent
                    text: root.displayTime()
                    color: ink
                    font.family: "Segoe UI Variable Display"
                    font.pixelSize: 74
                    font.weight: Font.Light
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 108
                    height: 4
                    radius: 2
                    color: remainingSeconds === 0 ? "#FF7F73" : accent
                    opacity: 0.86
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                TimeField {
                    id: minutesInput
                    label: "分钟"
                    valueText: "1"
                    validator: IntValidator { bottom: 0; top: 9999 }
                    onEditingFinished: {
                        root.minutesValue = Math.max(0, Math.min(9999, Number(text || 0)))
                        root.syncDuration()
                    }
                }

                TimeField {
                    id: secondsInput
                    label: "秒"
                    valueText: "0"
                    validator: IntValidator { bottom: 0; top: 59 }
                    onEditingFinished: {
                        root.secondsValue = Math.max(0, Math.min(59, Number(text || 0)))
                        root.syncDuration()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ActionButton {
                    Layout.fillWidth: true
                    text: root.running ? "暂停" : (root.paused ? "继续" : "开始")
                    accentColor: root.accent
                    onClicked: root.toggleStartPause()
                }
                ActionButton {
                    Layout.fillWidth: true
                    text: "重置"
                    accentColor: root.warm
                    quiet: true
                    onClicked: root.resetTimer()
                }
            }
        }
    }

    Item {
        id: miniView
        anchors.fill: parent
        visible: pinned

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: root.displayTime()
                    color: ink
                    font.family: "Segoe UI Variable Display"
                    font.pixelSize: 42
                    font.weight: Font.Light
                }
                Text {
                    text: statusText
                    color: muted
                    font.family: "Microsoft YaHei UI"
                    font.pixelSize: 12
                }
            }

            ChipButton {
                text: "Unpin"
                width: 74
                accentColor: root.accent
                onClicked: root.togglePin()
            }
        }
    }

    component ChipButton: Rectangle {
        id: chip
        property alias text: label.text
        property color accentColor: "#63D8B6"
        signal clicked()
        height: 36
        radius: 18
        color: mouse.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22) : "#16FFFFFF"
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.56)
        border.width: 1

        Text {
            id: label
            anchors.centerIn: parent
            color: ink
            font.family: "Microsoft YaHei UI"
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: button
        property alias text: label.text
        property color accentColor: "#63D8B6"
        property bool quiet: false
        signal clicked()
        Layout.preferredHeight: 52
        radius: 18
        color: quiet ? (mouse.containsMouse ? "#24FFFFFF" : "#14FFFFFF") : (mouse.containsMouse ? Qt.lighter(accentColor, 1.08) : accentColor)
        border.color: quiet ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.5) : "transparent"
        border.width: quiet ? 1 : 0

        Text {
            id: label
            anchors.centerIn: parent
            color: quiet ? ink : "#10141D"
            font.family: "Microsoft YaHei UI"
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }

    component TimeField: Rectangle {
        id: field
        property alias text: editor.text
        property alias validator: editor.validator
        property string label: ""
        property string valueText: "0"
        signal editingFinished()
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        radius: 20
        color: fieldBg
        border.color: editor.activeFocus ? accent : line
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Text {
                text: field.label
                color: muted
                font.family: "Microsoft YaHei UI"
                font.pixelSize: 12
            }

            TextInput {
                id: editor
                Layout.fillWidth: true
                text: field.valueText
                color: ink
                selectionColor: accent
                selectedTextColor: "#10141D"
                font.family: "Segoe UI Variable Text"
                font.pixelSize: 24
                font.weight: Font.Medium
                inputMethodHints: Qt.ImhDigitsOnly
                clip: true
                onEditingFinished: field.editingFinished()
            }
        }
    }
}
