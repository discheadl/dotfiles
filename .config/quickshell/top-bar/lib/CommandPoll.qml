import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property int interval: 1000
  property var command: []
  property var parse: function(out) { return String(out ?? "").trim() }
  property bool running: true
  property var value: null
  property string text: ""
  property bool busy: false

  signal updated()

  function reload() {
    root.busy = false
    poll()
  }

  function poll() {
    if (!root.running) return
    if (root.busy) return
    if (!command || command.length === 0) return
    root.busy = true
    proc.exec(command)
  }

  function valuesEqual(a, b) {
    if (a === b) return true
    if (a === null || b === null || a === undefined || b === undefined) return false
    if (typeof a !== "object" || typeof b !== "object") return false
    var ka = Object.keys(a), kb = Object.keys(b)
    if (ka.length !== kb.length) return false
    for (var i = 0; i < ka.length; i++) {
      if (a[ka[i]] !== b[ka[i]]) return false
    }
    return true
  }

  property Process proc: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        root.text = this.text ?? ""
        var parsed = root.parse(root.text)

        if (!root.valuesEqual(parsed, root.value)) {
          root.value = parsed
          root.updated()
        }
        root.busy = false
      }
    }

    onExited: function(code, status) {
      // Safety: clear busy only if stream already finished (no output case)
      Qt.callLater(function() {
        if (root.busy) root.busy = false
      })
    }
  }

  property Timer timer: Timer {
    interval: Math.max(50, root.interval)
    repeat: true
    running: root.running
    triggeredOnStart: true
    onTriggered: root.poll()
  }
}
