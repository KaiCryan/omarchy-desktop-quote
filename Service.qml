import QtQuick
import QtQuick.Effects
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
  // <vertical>-<horizontal>: vertical = top | middle | bottom,
  // horizontal = left | center | right  (e.g. "middle-right", "top-center")
  property string position: "bottom-left"
  property int marginX: 96
  property int marginY: 84
  property int maxWidth: 720
  property real fontScale: 1.0
  property string layerName: "bottom"     // bottom (desktop) | top (over windows)
  property real dim: 0.92                  // 0..1 overall opacity
  property bool shown: true

  readonly property var _pos: String(position || "bottom-left").toLowerCase().split("-")
  readonly property string vAlign: ["top", "middle", "bottom"].indexOf(_pos[0]) !== -1 ? _pos[0] : "bottom"
  readonly property string hAlign: ["left", "center", "right"].indexOf(_pos[1]) !== -1 ? _pos[1] : "left"

  // ---- state ----------------------------------------------------------------
  property var quotes: []
  property string quoteText: ""
  property string quoteAttr: ""
  property string lastWallpaper: ""
  property double lastRollAt: 0

  function applyConfig(raw) {
    try {
      var c = JSON.parse(raw && raw.length ? raw : "{}")
      if (c.quotesPath) quotesPath = String(c.quotesPath).replace(/^~/, home)
      if (c.rotateMinutes !== undefined) rotateMinutes = c.rotateMinutes
      if (c.syncWithWallpaper !== undefined) syncWithWallpaper = c.syncWithWallpaper
      if (c.position) position = c.position
      else if (c.corner) position = c.corner   // back-compat alias
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
    lastRollAt = Date.now()
    // Re-read the wallpaper now so the sync poll doesn't roll again right after
    // (e.g. a keybind that cycles the wallpaper and calls `next` together).
    wpProbe.running = true
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
          // Skip if the quote was just rolled explicitly (e.g. a keybind that
          // changes wallpaper and calls `next` together) — avoids a double flip.
          if (root.syncWithWallpaper && Date.now() - root.lastRollAt > 3000) root.roll()
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

      // Cover the whole output and place the placard inside; a full-screen
      // surface makes every vertical/horizontal alignment trivial.
      anchors { top: true; bottom: true; left: true; right: true }
      mask: Region {}   // never intercept pointer events

      WlrLayershell.namespace: "desktop-quote"
      WlrLayershell.layer: root.layerName === "top" ? WlrLayer.Top : WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Row {
        id: placard
        spacing: Math.round(18 * root.fontScale)
        layoutDirection: root.hAlign === "right" ? Qt.RightToLeft : Qt.LeftToRight

        anchors.left: root.hAlign === "left" ? parent.left : undefined
        anchors.leftMargin: root.marginX
        anchors.right: root.hAlign === "right" ? parent.right : undefined
        anchors.rightMargin: root.marginX
        anchors.horizontalCenter: root.hAlign === "center" ? parent.horizontalCenter : undefined

        anchors.top: root.vAlign === "top" ? parent.top : undefined
        anchors.topMargin: root.marginY
        anchors.bottom: root.vAlign === "bottom" ? parent.bottom : undefined
        anchors.bottomMargin: root.marginY
        anchors.verticalCenter: root.vAlign === "middle" ? parent.verticalCenter : undefined

        opacity: (root.shown && root.quoteText ? 1 : 0) * root.dim
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

        // Soft shadow so the text stays legible over any wallpaper.
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: "#000000"
          shadowBlur: 0.5
          shadowOpacity: 0.55
          shadowVerticalOffset: 1
          blurMax: 24
        }

        Rectangle {
          width: Math.max(2, Math.round(3 * root.fontScale))
          height: col.implicitHeight
          anchors.verticalCenter: parent.verticalCenter
          color: Color.accent
          opacity: 0.85
        }

        Column {
          id: col
          spacing: Math.round(8 * root.fontScale)

          Text {
            width: root.maxWidth
            horizontalAlignment: root.hAlign === "right" ? Text.AlignRight
              : root.hAlign === "center" ? Text.AlignHCenter : Text.AlignLeft
            text: root.quoteText
            wrapMode: Text.WordWrap
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Math.round(22 * root.fontScale)
            font.weight: Font.Light
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
          }

          Text {
            visible: root.quoteAttr.length > 0
            width: root.maxWidth
            horizontalAlignment: root.hAlign === "right" ? Text.AlignRight
              : root.hAlign === "center" ? Text.AlignHCenter : Text.AlignLeft
            text: "— " + root.quoteAttr.toUpperCase()
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Math.round(11 * root.fontScale)
            font.letterSpacing: 2
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.45)
          }
        }
      }
    }
  }
}
