import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Desktop Quote — a Variety-style quote placard pinned to the desktop.
// Reads a plain-text quotes file, re-rolls on a timer and whenever the
// wallpaper changes. Config: ~/.config/omarchy/desktop-quote.json
Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

  // ---- config (all overridable in ~/.config/omarchy/desktop-quote.json) -------
  property string quotesPath: home + "/.config/omarchy/quotes.txt"
  property int rotateMinutes: 20
  property bool syncWithWallpaper: true
  property string corner: "bottom-left"   // bottom-left | bottom-right | top-left | top-right
  property int marginX: 96
  property int marginY: 84
  property int maxWidth: 720
  property real fontScale: 1.0
  property string layerName: "bottom"     // bottom (desktop) | top (over windows)
  property real dim: 0.92                  // 0..1 overall opacity
  property bool shown: true

  // ---- state ----------------------------------------------------------------
  property var quotes: []
  property string quoteText: ""
  property string quoteAttr: ""
  property string lastWallpaper: ""

  function applyConfig(raw) {
    try {
      var c = JSON.parse(raw && raw.length ? raw : "{}")
      if (c.quotesPath) quotesPath = String(c.quotesPath).replace(/^~/, home)
      if (c.rotateMinutes !== undefined) rotateMinutes = c.rotateMinutes
      if (c.syncWithWallpaper !== undefined) syncWithWallpaper = c.syncWithWallpaper
      if (c.corner) corner = c.corner
      if (c.marginX !== undefined) marginX = c.marginX
      if (c.marginY !== undefined) marginY = c.marginY
      if (c.maxWidth !== undefined) maxWidth = c.maxWidth
      if (c.fontScale !== undefined) fontScale = c.fontScale
      if (c.layer) layerName = c.layer
      if (c.dim !== undefined) dim = c.dim
    } catch (e) {}
  }

  function parseQuotes(raw) {
    var out = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line[0] === "#") continue
      var parts = line.split("|")
      out.push({ text: parts[0].trim(), attr: parts.length > 1 ? parts.slice(1).join("|").trim() : "" })
    }
    return out
  }

  function refreshQuotes() {
    var list = parseQuotes(userQuotes.text())
    if (!list.length) list = parseQuotes(bundledQuotes.text())
    quotes = list
    var texts = quotes.map(function (q) { return q.text })
    if (quotes.length && (!quoteText || texts.indexOf(quoteText) === -1)) roll()
  }

  function roll() {
    if (!quotes.length) return
    var idx = Math.floor(Math.random() * quotes.length)
    if (quotes.length > 1 && quotes[idx].text === quoteText)
      idx = (idx + 1) % quotes.length
    quoteText = quotes[idx].text
    quoteAttr = quotes[idx].attr
  }

  FileView {
    id: userQuotes
    path: root.quotesPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.refreshQuotes()
    onLoadFailed: root.refreshQuotes()
  }

  FileView {
    id: bundledQuotes
    path: root.pluginDir + "quotes.txt"
    printErrors: false
    onLoaded: root.refreshQuotes()
  }

  FileView {
    id: configFile
    path: root.home + "/.config/omarchy/desktop-quote.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyConfig(text())
  }

  Timer {
    interval: Math.max(1, root.rotateMinutes) * 60000
    running: true; repeat: true
    onTriggered: root.roll()
  }

  // Poll the current-wallpaper symlink; re-roll when it points somewhere new.
  Process {
    id: wpProbe
    command: ["readlink", "-f", root.home + "/.local/state/omarchy/current/background"]
    stdout: StdioCollector {
      onStreamFinished: {
        var wp = String(text || "").trim()
        if (!wp) return
        if (root.lastWallpaper === "") { root.lastWallpaper = wp; return }
        if (wp !== root.lastWallpaper) {
          root.lastWallpaper = wp
          if (root.syncWithWallpaper) root.roll()
        }
      }
    }
  }
  Timer {
    interval: 2500
    running: root.syncWithWallpaper
    repeat: true; triggeredOnStart: true
    onTriggered: wpProbe.running = true
  }

  // IPC:  omarchy-shell -q desktopQuote next | toggle | show | hide
  IpcHandler {
    target: "desktopQuote"
    function next(): void { root.roll() }
    function toggle(): void { root.shown = !root.shown }
    function show(): void { root.shown = true }
    function hide(): void { root.shown = false }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      readonly property bool bottomEdge: root.corner.indexOf("bottom") === 0
      readonly property bool leftEdge: root.corner.indexOf("left") !== -1

      anchors {
        top: !bottomEdge
        bottom: bottomEdge
        left: leftEdge
        right: !leftEdge
      }
      margins {
        top: bottomEdge ? 0 : root.marginY
        bottom: bottomEdge ? root.marginY : 0
        left: leftEdge ? root.marginX : 0
        right: leftEdge ? 0 : root.marginX
      }

      implicitWidth: root.maxWidth + 40
      implicitHeight: Math.max(1, placard.implicitHeight)

      WlrLayershell.namespace: "desktop-quote"
      WlrLayershell.layer: root.layerName === "top" ? WlrLayer.Top : WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Row {
        id: placard
        spacing: 15
        layoutDirection: win.leftEdge ? Qt.LeftToRight : Qt.RightToLeft
        anchors.left: win.leftEdge ? parent.left : undefined
        anchors.right: win.leftEdge ? undefined : parent.right
        anchors.verticalCenter: parent.verticalCenter

        opacity: (root.shown && root.quoteText ? 1 : 0) * root.dim
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

        Rectangle {
          width: 3
          height: col.implicitHeight
          anchors.verticalCenter: parent.verticalCenter
          color: Color.accent
          opacity: 0.85
        }

        Column {
          id: col
          spacing: 6

          Text {
            width: root.maxWidth
            horizontalAlignment: win.leftEdge ? Text.AlignLeft : Text.AlignRight
            text: root.quoteText
            wrapMode: Text.WordWrap
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Math.round(18 * root.fontScale)
            font.weight: Font.Light
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
          }

          Text {
            visible: root.quoteAttr.length > 0
            width: root.maxWidth
            horizontalAlignment: win.leftEdge ? Text.AlignLeft : Text.AlignRight
            text: "— " + root.quoteAttr.toUpperCase()
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Math.round(10 * root.fontScale)
            font.letterSpacing: 2
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.45)
          }
        }
      }
    }
  }
}
