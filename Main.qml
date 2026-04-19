import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import SddmComponents 2.0

Item {
    id: root
    width: Screen.width
    height: Screen.height
    focus: true

    function cfgStr(k, def) {
        if (typeof config === "undefined")
            return def
        var candidates = ["Theme/" + k, "General/" + k, k]
        for (var i = 0; i < candidates.length; i++) {
            var ck = candidates[i]
            if (config[ck] !== undefined) {
                var sv = String(config[ck])
                if (sv.length)
                    return sv
            }
        }
        return def
    }

    function cfgReal(k, def) {
        var s = cfgStr(k, "")
        if (!s.length)
            return def
        var v = parseFloat(s)
        return isNaN(v) ? def : v
    }

    function cfgInt(k, def) {
        var s = cfgStr(k, "")
        if (!s.length)
            return def
        var v = parseInt(s, 10)
        return isNaN(v) ? def : v
    }

    readonly property string ownerName: "jrtilak"
    readonly property string ownerRole: "Developer"
    readonly property string ownerGithub: "github.com/jrtilak"
    readonly property string ownerWebsite: "jrtilak.dev"

    readonly property string accentColor: cfgStr("accent", "#5c7099")
    readonly property string solidBackground: cfgStr("solidBackground", "#0b0e14")
    readonly property string fontFamilyUi: cfgStr("fontFamily", "Iosevka Nerd Font")
    readonly property int fontSizeLogo: cfgInt("fontSizeLogo", 14)
    readonly property int fontSizeText: cfgInt("fontSizeText", 13)
    readonly property real logoLineHeight: cfgReal("logoLineHeight", 1.05)
    readonly property int layoutMargin: cfgInt("layoutMargin", 40)
    readonly property int layoutSpacing: cfgInt("layoutSpacing", 12)
    readonly property int terminalLineSpacing: cfgInt("terminalLineSpacing", 2)
    readonly property int promptLineSpacing: cfgInt("promptLineSpacing", 4)
    readonly property int passwordRowSpacing: cfgInt("passwordRowSpacing", 6)
    readonly property real noiseOpacityCfg: cfgReal("noiseOpacity", 0.04)
    readonly property int cursorBlockWidth: cfgInt("cursorBlockWidth", 9)
    readonly property int cursorBlinkInterval: cfgInt("cursorBlinkInterval", 530)
    readonly property real blurStrength: cfgReal("blurStrength", 1.0)
    readonly property int blurMax: cfgInt("blurMax", 32)
    readonly property real blurMultiplier: cfgReal("blurMultiplier", 1.5)
    readonly property int sessionIndex: cfgInt("sessionIndex", 0)
    readonly property int maxHistory: cfgInt("commandHistoryMax", 50)

    // Qt.ImhNoOnScreenKeyboard — always set on text fields; numeric form for SDDM QML
    readonly property int imhNoOnScreenKeyboard: 0x200000

    property bool passwordMode: false
    property string pendingLoginUser: ""
    property var commandHistory: []
    property int historyBrowseIndex: -1
    property string historyDraft: ""

    property bool cursorBlink: true
    property string firstUserName: ""
    property string cfgType: cfgStr("type", "")

    property string wallpaperPath: {
        var t = cfgType.toLowerCase()
        if (t === "color")
            return ""
        var bg = cfgStr("background", "")
        if (!bg.length)
            return ""
        if (bg.charAt(0) === "#")
            return ""
        if (bg.toLowerCase().indexOf("rgb") === 0)
            return ""
        if (t === "image")
            return bg
        return bg
    }

    property bool showWallpaper: wallpaperPath.length > 0

    property color overlayTint: {
        if (typeof config !== "undefined" && config.defaultBackground !== undefined)
            return String(config.defaultBackground)
        return solidBackground
    }

    property real overlayOpacity: cfgReal("backgroundOpacity", 0.6)

    property color textColor: cfgStr("foreground", "#8b9bb4")

    function resolvedUserName() {
        if (typeof userModel === "undefined" || !userModel.count)
            return "user"
        var lu = userModel.lastUser
        if (lu !== undefined && lu !== null && String(lu).length > 0)
            return String(lu)
        if (firstUserName.length > 0)
            return firstUserName
        return "user"
    }

    function defaultLoginUserName() {
        if (firstUserName.length > 0)
            return firstUserName
        return resolvedUserName()
    }

    function appendLine(line, isRich) {
        terminalModel.append({
            line: line,
            rich: !!isRich
        })
        termView.positionViewAtEnd()
    }

    function appendPromptBlock(cmd) {
        var u = resolvedUserName()
        appendLine("(" + u + "@void) -[~]", false)
        appendLine("$ " + cmd, false)
    }

    function scrollBottom() {
        termView.positionViewAtEnd()
    }

    function safeSddmCall(method, arg1, arg2, arg3) {
        if (typeof sddm === "undefined")
            return false
        try {
            if (method === "login" && sddm.login) {
                sddm.login(arg1, arg2, arg3)
                return true
            }
            if (method === "powerOff" && sddm.powerOff) {
                sddm.powerOff()
                return true
            }
            if (method === "reboot" && sddm.reboot) {
                sddm.reboot()
                return true
            }
        } catch (e) {
        }
        return false
    }

    function pushHistoryEntry(cmd) {
        var c = String(cmd)
        if (!c.length)
            return
        var h = commandHistory.slice()
        if (h.length && h[h.length - 1] === c)
            return
        h.push(c)
        if (h.length > maxHistory)
            h = h.slice(h.length - maxHistory)
        commandHistory = h
    }

    function runCommand(raw) {
        var line = String(raw).trim()
        historyBrowseIndex = -1
        historyDraft = ""

        appendPromptBlock(line)
        pushHistoryEntry(line)

        if (!line.length) {
            scrollBottom()
            scheduleRefocus()
            return
        }

        var parts = line.split(/\s+/).filter(function (x) {
            return x.length > 0
        })
        var cmd = parts[0]
        var rest = parts.slice(1)

        if (cmd === "help") {
            appendLine("Available commands:", false)
            appendLine("<span style=\"color:" + accentColor + "\">  help</span><span style=\"color:" + textColor + "\">               Show this help message</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  clear</span><span style=\"color:" + textColor + "\">              Clear the terminal</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  whoishe</span><span style=\"color:" + textColor + "\">            About the user</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  login [username]</span><span style=\"color:" + textColor + "\">   Login (prompts for password)</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  logout</span><span style=\"color:" + textColor + "\">             Cancel current login attempt</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  shutdown</span><span style=\"color:" + textColor + "\">           Shutdown the system</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  reboot</span><span style=\"color:" + textColor + "\">             Reboot the system</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  date</span><span style=\"color:" + textColor + "\">               Show current date and time</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  whoami</span><span style=\"color:" + textColor + "\">             Show current user</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  echo &lt;text&gt;</span><span style=\"color:" + textColor + "\">        Print text</span>", true)
            appendLine("<span style=\"color:" + accentColor + "\">  uname</span><span style=\"color:" + textColor + "\">              Print system info</span>", true)
        } else if (cmd === "clear") {
            terminalModel.clear()
        } else if (cmd === "whoishe") {
            appendLine("Name:    " + ownerName, false)
            appendLine("Role:    " + ownerRole, false)
            appendLine("GitHub:  " + ownerGithub, false)
            appendLine("Web:     " + ownerWebsite, false)
        } else if (cmd === "login") {
            var u = rest.length ? rest.join(" ") : defaultLoginUserName()
            pendingLoginUser = u
            passwordMode = true
            passwordField.text = ""
            scheduleRefocusPassword()
            scrollBottom()
            return
        } else if (cmd === "logout") {
            appendLine("No active login attempt to cancel.", false)
        } else if (cmd === "shutdown") {
            safeSddmCall("powerOff")
        } else if (cmd === "reboot") {
            safeSddmCall("reboot")
        } else if (cmd === "date") {
            appendLine(new Date().toString(), false)
        } else if (cmd === "whoami") {
            appendLine(resolvedUserName(), false)
        } else if (cmd === "echo") {
            appendLine(rest.join(" "), false)
        } else if (cmd === "uname") {
            appendLine("Linux void 6.12.74 #1 SMP x86_64 GNU/Linux", false)
        } else {
            appendLine("bash: " + cmd + ": command not found", false)
        }

        scrollBottom()
        scheduleRefocus()
    }

    function cancelPasswordMode() {
        passwordMode = false
        pendingLoginUser = ""
        passwordField.text = ""
        appendLine("Login cancelled.", false)
        scrollBottom()
        scheduleRefocus()
    }

    function tryLogin() {
        var pw = passwordField.text
        var u = pendingLoginUser
        passwordField.text = ""
        passwordMode = false
        pendingLoginUser = ""
        scrollBottom()
        scheduleRefocus()
        safeSddmCall("login", u, pw, sessionIndex)
    }

    function scheduleRefocus() {
        refocusTimer.restart()
    }

    function scheduleRefocusPassword() {
        refocusPwdTimer.restart()
    }

    Timer {
        id: refocusTimer
        interval: 0
        repeat: false
        onTriggered: cmdInput.forceActiveFocus()
    }

    Timer {
        id: refocusPwdTimer
        interval: 0
        repeat: false
        onTriggered: passwordField.forceActiveFocus()
    }

    Timer {
        id: inputPanelSuppressTimer
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            if (typeof Qt.inputMethod !== "undefined" && Qt.inputMethod.visible)
                Qt.inputMethod.hide()
        }
    }

    Timer {
        interval: root.cursorBlinkInterval
        repeat: true
        running: true
        onTriggered: root.cursorBlink = !root.cursorBlink
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null

        function onLoginFailed() {
            appendLine("Login failed. Incorrect password.", false)
            scrollBottom()
            scheduleRefocus()
        }
    }

    Connections {
        target: typeof Qt.inputMethod !== "undefined" ? Qt.inputMethod : null

        function onVisibleChanged() {
            if (Qt.inputMethod.visible)
                Qt.inputMethod.hide()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: solidBackground
    }

    Image {
        id: bgImage
        anchors.fill: parent
        visible: root.showWallpaper
        source: root.showWallpaper ? (String(wallpaperPath).indexOf("/") === 0 ? "file://" + wallpaperPath : Qt.resolvedUrl(wallpaperPath)) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }

    MultiEffect {
        source: bgImage
        anchors.fill: bgImage
        visible: root.showWallpaper
        blurEnabled: true
        blur: root.blurStrength
        blurMax: root.blurMax
        blurMultiplier: root.blurMultiplier
    }

    Rectangle {
        anchors.fill: parent
        color: root.overlayTint
        opacity: root.overlayOpacity
    }

    Canvas {
        id: noiseCanvas
        anchors.fill: parent
        opacity: root.noiseOpacityCfg
        visible: width > 0 && height > 0

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            if (width < 1 || height < 1)
                return
            var imageData = ctx.createImageData(width, height)
            var d = imageData.data
            for (var i = 0; i < d.length; i += 4) {
                var val = Math.random() * 255
                d[i] = val
                d[i + 1] = val
                d[i + 2] = val
                d[i + 3] = 255
            }
            ctx.putImageData(imageData, 0, 0)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        propagateComposedEvents: true
        onClicked: {
            if (passwordMode)
                passwordField.forceActiveFocus()
            else
                cmdInput.forceActiveFocus()
            mouse.accepted = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.layoutMargin
        spacing: root.layoutSpacing

        Text {
            id: asciiLogo
            text: "██╗   ██╗  ██████╗  ██╗██████╗ \n" + "██║   ██║ ██╔═══██╗ ██║██╔══██╗\n" + "██║   ██║ ██║   ██║ ██║██║  ██║\n" + "╚██╗ ██╔╝ ██║   ██║ ██║██║  ██║\n" + " ╚████╔╝  ╚██████╔╝ ██║██████╔╝\n" + "  ╚═══╝    ╚═════╝  ╚═╝╚═════╝ "
            color: root.textColor
            font.family: root.fontFamilyUi
            font.pixelSize: root.fontSizeLogo
            lineHeight: root.logoLineHeight
            Layout.alignment: Qt.AlignLeft
        }

        ColumnLayout {
            id: staticHelp
            spacing: 8
            Layout.fillWidth: true

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Text {
                    text: "1."
                    width: 28
                    horizontalAlignment: Text.AlignRight
                    color: root.textColor
                    opacity: 0.45
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                }
                Text {
                    text: "login"
                    color: root.accentColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                    font.weight: Font.Medium
                }
                Text {
                    text: "—"
                    color: root.textColor
                    opacity: 0.35
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                }
                Text {
                    text: "log in"
                    color: root.textColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Text {
                    text: "2."
                    width: 28
                    horizontalAlignment: Text.AlignRight
                    color: root.textColor
                    opacity: 0.45
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                }
                Text {
                    text: "help"
                    color: root.accentColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                    font.weight: Font.Medium
                }
                Text {
                    text: "—"
                    color: root.textColor
                    opacity: 0.35
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                }
                Text {
                    text: "show all commands"
                    color: root.textColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                Text {
                    text: "3."
                    width: 28
                    horizontalAlignment: Text.AlignRight
                    color: root.textColor
                    opacity: 0.45
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                }
                Text {
                    text: "whoishe"
                    color: root.accentColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                    font.weight: Font.Medium
                }
                Text {
                    text: "—"
                    color: root.textColor
                    opacity: 0.35
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                }
                Text {
                    text: "know about me (creator)"
                    color: root.textColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        ListView {
            id: termView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: root.terminalLineSpacing
            model: terminalModel
            onCountChanged: scrollBottom()

            delegate: Text {
                width: termView.width
                wrapMode: Text.Wrap
                text: model.line
                textFormat: model.rich ? Text.RichText : Text.PlainText
                color: root.textColor
                font.family: root.fontFamilyUi
                font.pixelSize: root.fontSizeText
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.promptLineSpacing
            visible: !passwordMode

            Text {
                text: "(" + resolvedUserName() + "@void) -[~]"
                color: root.textColor
                font.family: root.fontFamilyUi
                font.pixelSize: root.fontSizeText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "$ "
                    color: root.textColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                }

                TextInput {
                    id: cmdInput
                    Layout.fillWidth: true
                    color: root.textColor
                    font.family: root.fontFamilyUi
                    font.pixelSize: root.fontSizeText
                    inputMethodHints: root.imhNoOnScreenKeyboard
                    focus: !passwordMode
                    cursorVisible: true
                    selectByMouse: true
                    wrapMode: TextInput.NoWrap

                    cursorDelegate: Rectangle {
                        implicitWidth: root.cursorBlockWidth
                        implicitHeight: cmdInput.cursorRectangle.height
                        color: root.cursorBlink ? root.textColor : "transparent"
                    }

                    Keys.onPressed: function (event) {
                        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C) {
                            cmdInput.text = ""
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Up) {
                            event.accepted = true
                            if (!commandHistory.length)
                                return
                            if (historyBrowseIndex === -1)
                                historyDraft = cmdInput.text
                            if (historyBrowseIndex < commandHistory.length - 1)
                                historyBrowseIndex++
                            cmdInput.text = commandHistory[commandHistory.length - 1 - historyBrowseIndex]
                            return
                        }
                        if (event.key === Qt.Key_Down) {
                            event.accepted = true
                            if (historyBrowseIndex < 0)
                                return
                            historyBrowseIndex--
                            if (historyBrowseIndex < 0) {
                                cmdInput.text = historyDraft
                                return
                            }
                            cmdInput.text = commandHistory[commandHistory.length - 1 - historyBrowseIndex]
                            return
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true
                            var t = cmdInput.text
                            cmdInput.text = ""
                            runCommand(t)
                            return
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.passwordRowSpacing
            visible: passwordMode

            Text {
                text: "Password for " + pendingLoginUser + ": "
                color: root.textColor
                font.family: root.fontFamilyUi
                font.pixelSize: root.fontSizeText
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                color: root.textColor
                font.family: root.fontFamilyUi
                font.pixelSize: root.fontSizeText
                inputMethodHints: root.imhNoOnScreenKeyboard
                focus: passwordMode
                echoMode: TextInput.Password
                passwordCharacter: "*"
                background: Item {}
                selectByMouse: true

                cursorDelegate: Rectangle {
                    implicitWidth: root.cursorBlockWidth
                    implicitHeight: passwordField.cursorRectangle.height
                    color: root.cursorBlink ? root.textColor : "transparent"
                }

                Keys.onPressed: function (event) {
                    if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_C) {
                        event.accepted = true
                        cancelPasswordMode()
                        return
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        event.accepted = true
                        tryLogin()
                        return
                    }
                }
            }
        }
    }

    ListModel {
        id: terminalModel
    }

    Repeater {
        model: userModel
        delegate: Item {
            width: 0
            height: 0
            Component.onCompleted: {
                if (index === 0 && model.name !== undefined)
                    root.firstUserName = String(model.name)
            }
        }
    }

    Component.onCompleted: {
        Qt.inputMethod.hide()
        cmdInput.forceActiveFocus()
    }

    onPasswordModeChanged: {
        if (passwordMode)
            scheduleRefocusPassword()
        else
            scheduleRefocus()
    }
}
