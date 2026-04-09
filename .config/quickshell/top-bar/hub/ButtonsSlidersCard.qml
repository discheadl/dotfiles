import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "../lib" as Lib

Lib.Card {
  id: root
  signal closeRequested()
  signal batteryToggleRequested()
  property bool active: true

  // --- WIFI VIEW STATE ---
  property bool wifiViewVisible: false
  property int wifiViewIndex: 0  // 0=list, 1=password
  property string wifiTargetSsid: ""
  property bool wifiTargetEnterprise: false
  property string wifiEnteredPass: ""
  property bool wifiShowPass: false
  property bool wifiBusy: false
  property bool wifiScanning: false
  property string wifiStatus: ""
  property color wifiStatusColor: root.theme ? root.theme.textSecondary : "#9da9a0"
  property string wifiPendingUuid: ""

  // --- BT VIEW STATE ---
  property bool btViewVisible: false
  property bool btScanning: false
  property bool btBusy: false
  property string btStatus: ""
  property color btStatusColor: root.theme ? root.theme.textSecondary : "#9da9a0"
  property string btConnectedMac: ""
  property string btConnectedName: ""

  onActiveChanged: { if (!active) { closeWifiView(); closeBtView() } }

  property bool autoMode: true
  Component.onCompleted: {
        if (root.autoMode) {
            det("sudo auto-cpufreq --force=reset")
        }
    }

  function sh(cmd) { return ["bash","-lc", cmd] }
  function det(cmd) { Quickshell.execDetached(sh(cmd)) }

  // --- WIFI ---
  Lib.CommandPoll {
    id: wifiOn
    running: root.active && root.visible
    interval: 2500
    command: sh("nmcli -t -f WIFI g 2>/dev/null | head -n1 || true")
    parse: function(o) { return String(o).trim() === "enabled" }
  }

  Lib.CommandPoll {
    id: wifiSSID
    running: root.active && root.visible
    interval: 5000
    command: sh("nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}' || true")
    parse: function(o) {
      var s = String(o).trim() || "WiFi"
      return s.length > 9 ? s.slice(0, 9) : s
    }
  }

  function toggleWifi() {
    var next = !Boolean(wifiOn.value)
    det("nmcli radio wifi " + (next ? "on" : "off"))
  }

  // --- BLUETOOTH ---
  property bool _optBt: false
  property bool _toggling: false
  Timer { id: optTimer; interval: 3500; onTriggered: root._toggling = false }

  Lib.CommandPoll {
    id: btOn;
    running: root.active && root.visible; interval: 3000
    command: sh("rfkill list bluetooth")
    parse: function(o) { return String(o).includes("Soft blocked: no") }
    onUpdated: if (!root._toggling) root._optBt = value
  }

  Lib.CommandPoll {
    id: btDev;
    running: root.active && root.visible; interval: 3500
    command: sh("pactl list cards 2>/dev/null | grep -A 20 'bluez_card' | grep 'device.description' | head -n1 | cut -d'=' -f2 | tr -d '\"'")
    parse: function(o) {
      var d = String(o).trim();
      if (d.length > 0) return d.length > 9 ? d.slice(0, 9) : d
      return btOn.value ? "On" : "Off"
    }
  }

  function toggleBt() {
      root._toggling = true;
      root._optBt = !btOn.value;
      optTimer.restart();
      det("rfkill " + (root._optBt ? "unblock" : "block") + " bluetooth")
  }

  // --- VOLUME / BRIGHTNESS ---
  Lib.CommandPoll {
    id: volPoll
    running: root.active && root.visible
    interval: 1200
    command: sh("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '\\d+(?=%)' | head -n1")
    parse: function(o) {
      var n = parseInt(String(o).trim())
      return isFinite(n) ? n : 0
    }
    onUpdated: if (!volS.pressed && !root._volScrolling) volS.value = value
  }

  Lib.CommandPoll {
    id: briPoll
    running: root.active && root.visible
    interval: 1500
    command: sh("brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '% ' || true")
    parse: function(o) {
      var n = Number(String(o).trim())
      return isFinite(n) ? n : 50
    }
    onUpdated: if (!briS.pressed && !root._briScrolling) briS.value = value
  }

  // --- SCROLL STATE ---
  property bool _briScrolling: false
  property bool _volScrolling: false

  Timer {
    id: briScrollTimer
    interval: 100
    onTriggered: {
      det("brightnessctl set " + Math.round(briS.value) + "%")
      root._briScrolling = false
    }
  }

  Timer {
    id: volScrollTimer
    interval: 100
    onTriggered: {
      det("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(volS.value) + "%")
      root._volScrolling = false
    }
  }

  function scrollBri(angleDelta) {
    var step = 5
    var newVal = Math.max(0, Math.min(100, briS.value + (angleDelta > 0 ? step : -step)))
    briS.value = newVal
    root._briScrolling = true
    briScrollTimer.restart()
  }

  function scrollVol(angleDelta) {
    var step = 5
    var newVal = Math.max(0, Math.min(100, volS.value + (angleDelta > 0 ? step : -step)))
    volS.value = newVal
    root._volScrolling = true
    volScrollTimer.restart()
  }

// --- CPU GOVERNOR (AUTO-CPUFREQ) ---
    property string gpuMode: "Integrated"
    property bool _isChanging: false

    Lib.CommandPoll {
        id: gpuPoll
        running: root.active && root.visible && !root._isChanging
        interval: 10000
        command: sh("supergfxctl -g 2>/dev/null || echo 'Integrated'")
        parse: function(o) { return String(o).trim() }
        onUpdated: root.gpuMode = value
    }

    Timer {
        id: pollLockout
        interval: 5000
        onTriggered: root._isChanging = false
    }

    function toggleGpu() {
        root._isChanging = true
        pollLockout.restart()

        if (root.gpuMode.toLowerCase() === "integrated") {
            root.gpuMode = "Hybrid"
            det("supergfxctl -m Hybrid ; sleep 0.2 ; pkill -x dunst; pkill -x quickshell; hyprctl dispatch exit")
        } else {
            root.gpuMode = "Integrated"
            det("supergfxctl -m Integrated ; sleep 0.2 ; pkill -x dunst; pkill -x quickshell; hyprctl dispatch exit")
        }
    }

    function getGpuIcon() {
        return (root.gpuMode.toLowerCase() === "hybrid") ? "cpu_max.svg" : "cpu_powersave.svg"
    }

    function getGpuLabel() {
        return (root.gpuMode.toLowerCase() === "hybrid") ? "Hybrid" : "Integrated"
    }

    function getGpuColor() {
        if (root.gpuMode.toLowerCase() === "hybrid") {
            return (root.theme && root.theme.isDarkMode !== undefined && !root.theme.isDarkMode)
                ? '#283314'
                : (root.theme ? root.theme.accent : "#a7c080")
        }
        return root.theme ? root.theme.textPrimary : "#d3c6aa"
    }

// --- MIXER ---
  property bool mixerVisible: false
  ListModel { id: mixerModel }

  function getMixerIcon(name) {
    var n = (name || "").toLowerCase()
    if (n.includes("firefox") || n.includes("zen") || n.includes("librewolf")) return "󰈹"
    if (n.includes("chrome") || n.includes("thorium")) return ""
    if (n.includes("brave")) return ""
    if (n.includes("spotify")) return "󰓇"
    if (n.includes("discord") || n.includes("vesktop") || n.includes("webrtc")) return ""
    if (n.includes("vlc")) return "󰕼"
    if (n.includes("mpv") || n.includes("haruna") || n.includes("celluloid") || n.includes("totem")) return ""
    if (n.includes("obs")) return ""
    if (n.includes("steam")) return ""
    if (n.includes("telegram")) return ""
    if (n.includes("amberol") || n.includes("lollypop") || n.includes("rhythmbox") || n.includes("strawberry")) return "󰎆"
    if (n.includes("pipewire") || n.includes("alsa")) return "󰓃"
    return "󰕾"
  }

  function updateMixer(apps) {
    var seen = {}
    for (var j = 0; j < apps.length; j++) {
      var app = apps[j]
      seen[app.idx] = true
      var found = -1
      for (var m = 0; m < mixerModel.count; m++) {
        if (mixerModel.get(m).idx === app.idx) { found = m; break }
      }
      if (found >= 0) {
        mixerModel.setProperty(found, "vol", app.vol)
        mixerModel.setProperty(found, "muted", app.muted)
      } else {
        mixerModel.append(app)
      }
    }
    for (var k = mixerModel.count - 1; k >= 0; k--) {
      if (!seen[mixerModel.get(k).idx]) mixerModel.remove(k)
    }
  }

  Lib.CommandPoll {
    id: mixerPoll
    running: root.active && root.visible && root.mixerVisible
    interval: 1500
    command: sh("pactl -f json list sink-inputs 2>/dev/null || echo '[]'")
    parse: function(o) {
      try {
        var raw = JSON.parse(String(o).trim())
        var apps = []
        for (var i = 0; i < raw.length; i++) {
          var si = raw[i]
          var props = si.properties || {}
          var name = props["application.name"] || props["media.name"] || "Audio"
          var muted = si.mute || false
          var vol = 0
          if (si.volume) {
            var ch = Object.keys(si.volume)
            if (ch.length > 0) {
              var pct = String(si.volume[ch[0]].value_percent || "0")
              vol = parseInt(pct.replace("%","").trim())
            }
          }
          if (!isFinite(vol)) vol = 0
          apps.push({ idx: si.index, name: name, vol: vol, muted: muted })
        }
        return apps
      } catch(e) { return [] }
    }
    onUpdated: root.updateMixer(value)
  }

// --- DND ---
  property bool dnd: false

  Lib.CommandPoll {
    id: dndPoll
    running: root.active && root.visible
    interval: 4000
    command: sh("dunstctl is-paused 2>/dev/null || echo false")
    parse: function(o) { return String(o).trim() === "true" }
    onUpdated: root.dnd = value
  }

  function toggleDnd() {
    var next = !root.dnd
    root.dnd = next
    det("dunstctl set-paused " + (next ? "true" : "false"))
  }

  // --- WIFI INLINE PANEL ---
  ListModel { id: wifiNetworkModel }
  property var wifiSsidMap: ({})

  // Current connection info
  property string wifiCurrentSsid: ""
  property string wifiCurrentIp: ""
  property int wifiCurrentSignal: 0

  Process {
    id: wifiStatusProc
    command: ["bash", "-c", [
      "SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}')",
      "[ -z \"$SSID\" ] && exit 0",
      "echo \"SSID:$SSID\"",
      "SIG=$(nmcli -g IN-USE,SIGNAL dev wifi list 2>/dev/null | awk -F: '$1==\"*\"{print $2; exit}')",
      "echo \"SIG:$SIG\"",
      "IP=$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\"){print $(i+1); exit}}')",
      "echo \"IP:$IP\""
    ].join("\n")]
    stdout: StdioCollector {
      onStreamFinished: {
        var ssid = "", ip = "", sig = 0
        var lines = String(text || "").split(/\r?\n/)
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].split(":")
          if (p.length < 2) continue
          if (p[0] === "SSID") ssid = p.slice(1).join(":")
          else if (p[0] === "IP") ip = p[1]
          else if (p[0] === "SIG") sig = parseInt(p[1], 10) || 0
        }
        root.wifiCurrentSsid = ssid
        root.wifiCurrentIp = ip
        root.wifiCurrentSignal = sig
      }
    }
  }

  Timer {
    id: wifiStatusTimer
    interval: 3200
    onTriggered: root.wifiStatus = ""
  }

  function setWifiStatus(msg, bad) {
    root.wifiStatus = msg
    root.wifiStatusColor = bad
        ? (root.theme ? root.theme.accent : "#e67e80")
        : (root.theme ? root.theme.textSecondary : "#9da9a0")
    wifiStatusTimer.restart()
  }

  function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  function getSignalIcon(strength) {
    if (strength > 80) return "󰤨"
    if (strength > 60) return "󰤥"
    if (strength > 40) return "󰤢"
    if (strength > 20) return "󰤟"
    return "󰤯"
  }

  function openWifiView() {
    root.wifiViewVisible = true
    root.wifiViewIndex = 0
    root.wifiTargetSsid = ""
    root.wifiEnteredPass = ""
    root.wifiShowPass = false
    root.wifiBusy = false
    wifiNetworkModel.clear()
    root.wifiSsidMap = ({})
    wifiStatusProc.running = true
    wifiScanProc.running = true
  }

  function closeWifiView() {
    root.wifiViewVisible = false
    root.wifiViewIndex = 0
    root.wifiTargetSsid = ""
    root.wifiEnteredPass = ""
    root.wifiShowPass = false
    root.wifiBusy = false
    root.wifiScanning = false
  }

  function parseWifiScan(raw) {
    var lines = String(raw || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue
      var safeLine = line.replace(/\\:/g, "___COLON___")
      var parts = safeLine.split(":")
      if (parts.length < 4) continue
      var ssid = parts[1].replace(/___COLON___/g, ":")
      var sec = parts[2].replace(/___COLON___/g, ":")
      var sig = parseInt(parts[3], 10)
      if (!isFinite(sig)) sig = 0
      if (!ssid || ssid.length === 0) continue
      if (ssid === root.wifiCurrentSsid) continue

      if (root.wifiSsidMap[ssid] !== undefined) {
        var idx = root.wifiSsidMap[ssid]
        if (idx < wifiNetworkModel.count && sig > wifiNetworkModel.get(idx).strength) {
          wifiNetworkModel.setProperty(idx, "security", sec || "")
          wifiNetworkModel.setProperty(idx, "strength", sig)
        }
      } else {
        var isOpen = (sec.trim() === "" || sec.trim() === "--")
        wifiNetworkModel.append({ ssid: ssid, security: sec || "", strength: sig, isOpen: isOpen })
        root.wifiSsidMap[ssid] = wifiNetworkModel.count - 1
      }
    }
  }

  Process {
    id: wifiScanProc
    command: ["bash", "-c", "nmcli -g BSSID,SSID,SECURITY,SIGNAL dev wifi list --rescan yes 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.wifiScanning = false
        root.parseWifiScan(text || "")
        if (wifiNetworkModel.count === 0)
          root.setWifiStatus("No networks found", true)
      }
    }
    onRunningChanged: if (running) root.wifiScanning = true
  }

  Process {
    id: wifiConnectProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.wifiBusy = false
        var out = String(text || "")
        if (out.includes("__EXIT:0")) {
          root.setWifiStatus("Connected!", false)
          root.wifiViewIndex = 0
          // refresh after short delay
          wifiReconnDelay.restart()
        } else if (out.includes("Secrets were required") || out.includes("No suitable secrets")) {
          root.setWifiStatus("Wrong password", true)
        } else {
          root.setWifiStatus("Connection failed", true)
        }
      }
    }
  }

  Timer {
    id: wifiReconnDelay
    interval: 1500
    onTriggered: {
      wifiStatusProc.running = true
      wifiOn.command = wifiOn.command
      wifiSSID.command = wifiSSID.command
    }
  }

  function wifiConnect(ssid, password) {
    if (root.wifiBusy) return
    root.wifiBusy = true
    root.setWifiStatus("Connecting…", false)
    var cmd = "nmcli -w 20 dev wifi connect " + shellQuote(ssid)
    if (password && password.trim().length > 0)
      cmd += " password " + shellQuote(password)
    wifiConnectProc.command = ["bash", "-c", cmd + " 2>&1; rc=$?; echo __EXIT:$rc"]
    wifiConnectProc.running = true
  }

  function wifiRescan() {
    if (root.wifiScanning || root.wifiBusy) return
    wifiNetworkModel.clear()
    root.wifiSsidMap = ({})
    wifiScanProc.running = true
  }

  function wifiStopScan() {
    root.wifiScanning = false
  }

  // --- BLUETOOTH INLINE PANEL ---
  ListModel { id: btPairedModel }
  ListModel { id: btDiscoveredModel }
  property var btDiscoveredMap: ({})

  Timer {
    id: btStatusTimer
    interval: 3200
    onTriggered: root.btStatus = ""
  }

  function setBtStatus(msg, bad) {
    root.btStatus = msg
    root.btStatusColor = bad
        ? "#e67e80"
        : (root.theme ? root.theme.textSecondary : "#9da9a0")
    btStatusTimer.restart()
  }

  function getBtIcon(name) {
    var n = (name || "").toLowerCase()
    if (n.includes("airpods") || n.includes("buds") || n.includes("earbuds") || n.includes("earbud")) return "󰥰"
    if (n.includes("headphone") || n.includes("headset") || n.includes("wh-") || n.includes("wf-")) return "󰋋"
    if (n.includes("speaker") || n.includes("jbl") || n.includes("ue boom") || n.includes("soundbar")) return "󰓃"
    if (n.includes("keyboard") || n.includes("keychron") || n.includes("kbd")) return "󰌌"
    if (n.includes("mouse") || n.includes("trackpad") || n.includes("mx master")) return "󰍽"
    if (n.includes("controller") || n.includes("gamepad") || n.includes("dualsense") || n.includes("xbox")) return "󰊗"
    if (n.includes("phone") || n.includes("iphone") || n.includes("pixel") || n.includes("galaxy") || n.includes("samsung")) return "󰏲"
    if (n.includes("watch")) return "󰔛"
    if (n.includes("tv") || n.includes("fire")) return "󰔂"
    return "󰂯"
  }

  function openBtView() {
    root.btViewVisible = true
    root.btBusy = false
    btPairedModel.clear()
    btDiscoveredModel.clear()
    root.btDiscoveredMap = ({})
    root.btConnectedMac = ""
    root.btConnectedName = ""
    btPairedProc.running = true
    // Delay scan start so paired list is populated first (avoids duplicates)
    btScanDelayTimer.restart()
  }

  Timer {
    id: btScanDelayTimer
    interval: 600
    repeat: false
    onTriggered: btStartScan()
  }

  function closeBtView() {
    root.btViewVisible = false
    root.btBusy = false
    root.btScanning = false
    btStopScan()
  }

  // Get paired devices
  Process {
    id: btPairedProc
    command: ["bash", "-c", [
      "bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do",
      "  info=$(bluetoothctl info \"$mac\" 2>/dev/null)",
      "  connected=$(echo \"$info\" | grep -c 'Connected: yes')",
      "  printf '%s\\t%s\\t%s\\n' \"$mac\" \"$name\" \"$connected\"",
      "done"
    ].join("\n")]
    stdout: StdioCollector {
      onStreamFinished: {
        btPairedModel.clear()
        root.btConnectedMac = ""
        root.btConnectedName = ""
        var lines = String(text || "").split(/\r?\n/)
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (parts.length < 3) continue
          var mac = parts[0].trim()
          var name = parts[1].trim()
          var conn = parts[2].trim() === "1"
          if (!mac) continue
          if (conn) {
            root.btConnectedMac = mac
            root.btConnectedName = name
          }
          btPairedModel.append({ mac: mac, name: name, connected: conn })
        }
      }
    }
  }

  // Scan for new devices
  Process {
    id: btScanOnProc
    command: ["bash", "-c", "bluetoothctl --timeout 15 scan on 2>/dev/null; echo __DONE"]
    stdout: StdioCollector {
      onStreamFinished: root.btScanning = false
    }
  }

  Process {
    id: btScanOffProc
    command: ["bash", "-c", "bluetoothctl scan off 2>/dev/null"]
  }

  // Poll discovered devices while scanning
  Timer {
    id: btDiscoverPoll
    interval: 3000
    repeat: true
    running: root.btScanning && root.btViewVisible
    onTriggered: btDiscoverProc.running = true
  }

  Process {
    id: btDiscoverProc
    command: ["bash", "-c", [
      "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do",
      "  printf '%s\\t%s\\n' \"$mac\" \"$name\"",
      "done"
    ].join("\n")]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(text || "").split(/\r?\n/)
        // Collect all paired MACs to exclude
        var pairedMacs = {}
        for (var p = 0; p < btPairedModel.count; p++)
          pairedMacs[btPairedModel.get(p).mac] = true

        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t")
          if (parts.length < 2) continue
          var mac = parts[0].trim()
          var name = parts[1].trim()
          if (!mac || !name || pairedMacs[mac]) continue
          // Skip unnamed devices
          if (name === mac || name.match(/^[0-9A-F]{2}[:-]/i)) continue
          if (root.btDiscoveredMap[mac] !== undefined) continue
          btDiscoveredModel.append({ mac: mac, name: name })
          root.btDiscoveredMap[mac] = true
        }
      }
    }
  }

  function btStartScan() {
    root.btScanning = true
    btDiscoveredModel.clear()
    root.btDiscoveredMap = ({})
    btScanOnProc.running = true
    // Also poll immediately
    btDiscoverProc.running = true
  }

  function btStopScan() {
    root.btScanning = false
    btScanOffProc.running = true
  }

  // Connect to a paired device
  Process {
    id: btConnectProc
    property string targetMac: ""
    property string targetName: ""
    stdout: StdioCollector {
      onStreamFinished: {
        root.btBusy = false
        var out = String(text || "")
        if (out.includes("__EXIT:0")) {
          root.setBtStatus("Connected to " + btConnectProc.targetName, false)
          btPairedProc.running = true
        } else {
          root.setBtStatus("Failed to connect", true)
        }
      }
    }
  }

  function btConnect(mac, name) {
    if (root.btBusy) return
    root.btBusy = true
    root.setBtStatus("Connecting…", false)
    btConnectProc.targetMac = mac
    btConnectProc.targetName = name
    btConnectProc.command = ["bash", "-c", "bluetoothctl connect " + shellQuote(mac) + " 2>&1; rc=$?; echo __EXIT:$rc"]
    btConnectProc.running = true
  }

  // Disconnect
  Process {
    id: btDisconnectProc
    property string targetName: ""
    stdout: StdioCollector {
      onStreamFinished: {
        root.btBusy = false
        var out = String(text || "")
        if (out.includes("__EXIT:0")) {
          root.setBtStatus("Disconnected", false)
          btPairedProc.running = true
        } else {
          root.setBtStatus("Failed to disconnect", true)
        }
      }
    }
  }

  function btDisconnect(mac, name) {
    if (root.btBusy) return
    root.btBusy = true
    root.setBtStatus("Disconnecting…", false)
    btDisconnectProc.targetName = name
    btDisconnectProc.command = ["bash", "-c", "bluetoothctl disconnect " + shellQuote(mac) + " 2>&1; rc=$?; echo __EXIT:$rc"]
    btDisconnectProc.running = true
  }

  // Pair + trust + connect new device
  Process {
    id: btPairProc
    property string targetName: ""
    stdout: StdioCollector {
      onStreamFinished: {
        root.btBusy = false
        var out = String(text || "")
        if (out.includes("__EXIT:0")) {
          root.setBtStatus("Paired with " + btPairProc.targetName, false)
          btPairedProc.running = true
          // Remove from discovered
          for (var k = btDiscoveredModel.count - 1; k >= 0; k--) {
            if (btDiscoveredModel.get(k).name === btPairProc.targetName) {
              var mac = btDiscoveredModel.get(k).mac
              btDiscoveredModel.remove(k)
              delete root.btDiscoveredMap[mac]
              break
            }
          }
        } else {
          root.setBtStatus("Pairing failed", true)
        }
      }
    }
  }

  function btPair(mac, name) {
    if (root.btBusy) return
    root.btBusy = true
    root.setBtStatus("Pairing…", false)
    btPairProc.targetName = name
    btPairProc.command = ["bash", "-c",
      "bluetoothctl pair " + shellQuote(mac) + " 2>&1 && " +
      "bluetoothctl trust " + shellQuote(mac) + " 2>&1 && " +
      "bluetoothctl connect " + shellQuote(mac) + " 2>&1; rc=$?; echo __EXIT:$rc"]
    btPairProc.running = true
  }

  // Remove paired device
  Process {
    id: btRemoveProc
    property string targetName: ""
    stdout: StdioCollector {
      onStreamFinished: {
        root.btBusy = false
        root.setBtStatus("Removed " + btRemoveProc.targetName, false)
        btPairedProc.running = true
      }
    }
  }

  function btRemove(mac, name) {
    if (root.btBusy) return
    root.btBusy = true
    root.setBtStatus("Removing…", false)
    btRemoveProc.targetName = name
    btRemoveProc.command = ["bash", "-c", "bluetoothctl remove " + shellQuote(mac) + " 2>&1; rc=$?; echo __EXIT:$rc"]
    btRemoveProc.running = true
  }

  // --- UI ---

  // === WIFI INLINE VIEW ===
  ColumnLayout {
    spacing: 10
    width: parent.width
    visible: root.wifiViewVisible

    // Header with back arrow
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Rectangle {
        width: 28; height: 28
        radius: 14
        color: wifiBackMouse.containsMouse
            ? Qt.rgba(1,1,1, root.isDark ? 0.08 : 0.12)
            : "transparent"

        Text {
          anchors.centerIn: parent
          text: "󰁍"
          font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
          font.pixelSize: 16
          color: root.theme ? root.theme.textPrimary : "#d3c6aa"
        }

        MouseArea {
          id: wifiBackMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.closeWifiView()
        }
      }

      Text {
        text: root.wifiViewIndex === 0 ? "WiFi Networks" : root.wifiTargetSsid
        font.family: root.theme ? root.theme.textFont : "Manrope"
        font.pixelSize: 13
        font.weight: Font.Bold
        color: root.theme ? root.theme.textPrimary : "#d3c6aa"
        Layout.fillWidth: true
        elide: Text.ElideRight
      }

      // Rescan button
      Rectangle {
        visible: root.wifiViewIndex === 0
        width: 28; height: 28
        radius: 14
        color: wifiRescanMouse.containsMouse
            ? Qt.rgba(1,1,1, root.isDark ? 0.08 : 0.12)
            : "transparent"
        Text {
          anchors.centerIn: parent
          text: root.wifiScanning ? "󰓛" : "󰑓"
          font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
          font.pixelSize: 16
          renderType: Text.CurveRendering
          color: root.theme ? root.theme.textPrimary : "#d3c6aa"
          antialiasing: true
        }

        MouseArea {
          id: wifiRescanMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.wifiScanning ? root.wifiStopScan() : root.wifiRescan()
        }
      }
    }

    // Status
    Text {
      visible: root.wifiStatus.length > 0
      text: root.wifiStatus
      font.family: root.theme ? root.theme.textFont : "Manrope"
      font.pixelSize: 10
      color: root.wifiStatusColor
    }

    // === VIEW 0: Network list ===
    ColumnLayout {
      visible: root.wifiViewIndex === 0
      Layout.fillWidth: true
      spacing: 6

      // --- Connected network ---
      Rectangle {
        visible: root.wifiCurrentSsid.length > 0
        Layout.fillWidth: true
        height: 44
        radius: 12
        color: Qt.rgba(
          (root.theme ? root.theme.accent : "#a7c080").r,
          (root.theme ? root.theme.accent : "#a7c080").g,
          (root.theme ? root.theme.accent : "#a7c080").b,
          root.isDark ? 0.12 : 0.18
        )
        border.width: 1
        border.color: Qt.rgba(
          (root.theme ? root.theme.accent : "#a7c080").r,
          (root.theme ? root.theme.accent : "#a7c080").g,
          (root.theme ? root.theme.accent : "#a7c080").b,
          0.25
        )

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 8

          Text {
            text: root.getSignalIcon(root.wifiCurrentSignal)
            font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: root.theme ? root.theme.accent : "#a7c080"
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              text: root.wifiCurrentSsid
              font.family: root.theme ? root.theme.textFont : "Manrope"
              font.pixelSize: 12
              font.weight: Font.Bold
              color: root.theme ? root.theme.textPrimary : "#d3c6aa"
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: root.wifiCurrentIp || "No IP"
              font.family: root.theme ? root.theme.textFont : "Manrope"
              font.pixelSize: 9
              color: root.theme ? root.theme.textSecondary : "#9da9a0"
            }
          }

          Text {
            text: "Connected"
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            color: root.theme ? root.theme.accent : "#a7c080"
          }
        }
      }

      // Separator
      Rectangle {
        visible: root.wifiCurrentSsid.length > 0 && wifiNetworkModel.count > 0
        Layout.fillWidth: true
        height: 1
        color: root.theme ? root.theme.textSecondary : "#9da9a0"
        opacity: 0.12
      }

      // Scanning indicator
      Text {
        visible: root.wifiScanning && wifiNetworkModel.count === 0
        text: "Scanning…"
        font.family: root.theme ? root.theme.textFont : "Manrope"
        font.pixelSize: 11
        color: root.theme ? root.theme.textSecondary : "#9da9a0"
        opacity: 0.7
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        Layout.bottomMargin: 8
      }

      ListView {
        id: wifiListView
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(5 * 40, Math.max(0, wifiNetworkModel.count * 40))
        clip: true
        model: wifiNetworkModel
        spacing: 4
        ScrollBar.vertical: ScrollBar {
          active: true
          width: 3
          policy: wifiNetworkModel.count > 5 ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
        }

        delegate: Rectangle {
          required property string ssid
          required property string security
          required property int strength
          required property bool isOpen
          required property int index

          width: wifiListView.width - 6
          height: 36
          radius: 12
          color: wifiItemMouse.containsMouse
              ? Qt.rgba(1,1,1, root.isDark ? 0.06 : 0.10)
              : "transparent"
          border.width: wifiItemMouse.containsMouse ? 1 : 0
          border.color: Qt.rgba(1,1,1, root.isDark ? 0.10 : 0.15)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: root.getSignalIcon(parent.parent.strength)
              font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
              font.pixelSize: 14
              color: root.theme ? root.theme.accent : "#a7c080"
            }

            Text {
              text: parent.parent.ssid
              font.family: root.theme ? root.theme.textFont : "Manrope"
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: root.theme ? root.theme.textPrimary : "#d3c6aa"
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            Text {
              text: parent.parent.isOpen ? "󰦝" : "󰌾"
              font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              color: root.theme ? root.theme.textSecondary : "#9da9a0"
            }
          }

          MouseArea {
            id: wifiItemMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              var item = parent
              if (item.isOpen) {
                root.wifiConnect(item.ssid, "")
              } else {
                root.wifiTargetSsid = item.ssid
                root.wifiEnteredPass = ""
                root.wifiShowPass = false
                root.wifiViewIndex = 1
                Qt.callLater(function() { wifiPassInput.forceActiveFocus() })
              }
            }
          }
        }
      }
    }

    // === VIEW 1: Password entry ===
    ColumnLayout {
      visible: root.wifiViewIndex === 1
      Layout.fillWidth: true
      spacing: 10

      // Password field
      Rectangle {
        Layout.fillWidth: true
        height: 36
        radius: 18
        color: root.theme ? root.theme.bgItem : "#2d353b"
        border.width: 1
        border.color: wifiPassInput.activeFocus
            ? Qt.rgba((root.theme ? root.theme.accent : "#a7c080").r,
                       (root.theme ? root.theme.accent : "#a7c080").g,
                       (root.theme ? root.theme.accent : "#a7c080").b, 0.7)
            : Qt.rgba(1,1,1, root.isDark ? 0.05 : 0.10)

        TextInput {
          id: wifiPassInput
          anchors.left: parent.left
          anchors.right: wifiEyeBtn.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.leftMargin: 14
          anchors.rightMargin: 4
          verticalAlignment: TextInput.AlignVCenter
          color: root.theme ? root.theme.textPrimary : "#d3c6aa"
          font.family: root.theme ? root.theme.textFont : "Manrope"
          font.pixelSize: 12
          echoMode: root.wifiShowPass ? TextInput.Normal : TextInput.Password
          selectByMouse: true
          clip: true
          onTextChanged: root.wifiEnteredPass = text
          Keys.onReturnPressed: root.wifiConnect(root.wifiTargetSsid, root.wifiEnteredPass)
        }

        // Placeholder
        Text {
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.verticalCenter: parent.verticalCenter
          text: "Password"
          color: root.theme ? root.theme.textSecondary : "#9da9a0"
          font.family: root.theme ? root.theme.textFont : "Manrope"
          font.pixelSize: 12
          visible: wifiPassInput.text.length === 0 && !wifiPassInput.activeFocus
        }

        // Show/hide password toggle
        Rectangle {
          id: wifiEyeBtn
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.rightMargin: 4
          width: 28; height: 28
          radius: 14
          color: wifiEyeMouse.containsMouse
              ? Qt.rgba(1,1,1, root.isDark ? 0.08 : 0.12)
              : "transparent"

          Text {
            anchors.centerIn: parent
            text: root.wifiShowPass ? "󰈈" : "󰈉"
            font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: root.theme ? root.theme.textSecondary : "#9da9a0"
          }

          MouseArea {
            id: wifiEyeMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.wifiShowPass = !root.wifiShowPass
          }
        }
      }

      // Connect / Back buttons
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Back button
        Rectangle {
          Layout.fillWidth: true
          height: 32
          radius: 16
          color: wifiPassBackMouse.containsMouse
              ? Qt.rgba(1,1,1, root.isDark ? 0.06 : 0.10)
              : (root.theme ? root.theme.bgItem : "#2d353b")

          Text {
            anchors.centerIn: parent
            text: "Back"
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: root.theme ? root.theme.textPrimary : "#d3c6aa"
          }

          MouseArea {
            id: wifiPassBackMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { root.wifiViewIndex = 0 }
          }
        }

        // Connect button
        Rectangle {
          Layout.fillWidth: true
          height: 32
          radius: 16
          color: {
            var c = root.theme ? root.theme.accent : "#a7c080"
            return wifiConnectMouse.containsMouse ? Qt.darker(c, 1.1) : c
          }
          opacity: root.wifiBusy ? 0.5 : 1.0

          Text {
            anchors.centerIn: parent
            text: root.wifiBusy ? "Connecting…" : "Connect"
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: root.theme ? root.theme.textOnAccent : "#232a2e"
          }

          MouseArea {
            id: wifiConnectMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !root.wifiBusy
            onClicked: root.wifiConnect(root.wifiTargetSsid, root.wifiEnteredPass)
          }
        }
      }
    }
  }

  // === BLUETOOTH INLINE VIEW ===
  ColumnLayout {
    spacing: 10
    width: parent.width
    visible: root.btViewVisible

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Rectangle {
        width: 28; height: 28; radius: 14
        color: btBackMouse.containsMouse
            ? Qt.rgba(1,1,1, root.isDark ? 0.08 : 0.12) : "transparent"
        Text {
          anchors.centerIn: parent; text: "󰁍"
          font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
          font.pixelSize: 16
          color: root.theme ? root.theme.textPrimary : "#d3c6aa"
        }
        MouseArea { id: btBackMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeBtView() }
      }

      Text {
        text: "Bluetooth"
        font.family: root.theme ? root.theme.textFont : "Manrope"
        font.pixelSize: 13; font.weight: Font.Bold
        color: root.theme ? root.theme.textPrimary : "#d3c6aa"
        Layout.fillWidth: true
      }

      // Scan button
      Rectangle {
        width: 28; height: 28; radius: 14
        color: btRescanMouse.containsMouse
            ? Qt.rgba(1,1,1, root.isDark ? 0.08 : 0.12) : "transparent"
        Text {
          anchors.centerIn: parent
          text: root.btScanning ? "󰓛" : "󰑓"
          font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
          font.pixelSize: 16; renderType: Text.CurveRendering; antialiasing: true
          color: root.theme ? root.theme.textPrimary : "#d3c6aa"
        }
        MouseArea { id: btRescanMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.btScanning ? root.btStopScan() : root.btStartScan() }
      }
    }

    // Status
    Text {
      visible: root.btStatus.length > 0
      text: root.btStatus
      font.family: root.theme ? root.theme.textFont : "Manrope"
      font.pixelSize: 10
      color: root.btStatusColor
    }

    // --- Connected device ---
    Rectangle {
      visible: root.btConnectedMac.length > 0
      Layout.fillWidth: true
      height: 44; radius: 12
      color: Qt.rgba(
        (root.theme ? root.theme.accent : "#a7c080").r,
        (root.theme ? root.theme.accent : "#a7c080").g,
        (root.theme ? root.theme.accent : "#a7c080").b,
        root.isDark ? 0.12 : 0.18
      )
      border.width: 1
      border.color: Qt.rgba(
        (root.theme ? root.theme.accent : "#a7c080").r,
        (root.theme ? root.theme.accent : "#a7c080").g,
        (root.theme ? root.theme.accent : "#a7c080").b, 0.25
      )

      RowLayout {
        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
        Text {
          text: root.getBtIcon(root.btConnectedName)
          font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
          font.pixelSize: 16; renderType: Text.CurveRendering
          color: root.theme ? root.theme.accent : "#a7c080"
        }
        Text {
          text: root.btConnectedName
          font.family: root.theme ? root.theme.textFont : "Manrope"
          font.pixelSize: 12; font.weight: Font.Bold
          color: root.theme ? root.theme.textPrimary : "#d3c6aa"
          Layout.fillWidth: true; elide: Text.ElideRight
        }
        // Disconnect button
        Rectangle {
          width: 24; height: 24; radius: 12
          color: btDiscMouse.containsMouse ? Qt.rgba(1,0.3,0.3,0.15) : "transparent"
          Text {
            anchors.centerIn: parent; text: "󰅙"
            font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
            font.pixelSize: 13; color: "#e67e80"
          }
          MouseArea {
            id: btDiscMouse; anchors.fill: parent; hoverEnabled: true
            enabled: !root.btBusy
            onClicked: root.btDisconnect(root.btConnectedMac, root.btConnectedName)
          }
        }
      }
    }

    // --- Paired devices ---
    Text {
      visible: btPairedModel.count > 0
      text: "Paired"
      font.family: root.theme ? root.theme.textFont : "Manrope"
      font.pixelSize: 10; font.weight: Font.DemiBold
      color: root.theme ? root.theme.textSecondary : "#9da9a0"
      opacity: 0.7
    }

    ListView {
      id: btPairedList
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(4 * 40, Math.max(0, btPairedFilterModel.count * 40))
      clip: true; spacing: 4
      model: ListModel { id: btPairedFilterModel }
      ScrollBar.vertical: ScrollBar { active: true; width: 3 }

      // Rebuild filter model when paired model or connected mac changes
      function rebuild() {
        btPairedFilterModel.clear()
        for (var i = 0; i < btPairedModel.count; i++) {
          var item = btPairedModel.get(i)
          if (item.mac !== root.btConnectedMac)
            btPairedFilterModel.append(item)
        }
      }

      Connections { target: btPairedModel; function onCountChanged() { btPairedList.rebuild() } }
      Connections {
        target: root
        function onBtConnectedMacChanged() { btPairedList.rebuild() }
      }
      Component.onCompleted: rebuild()

      delegate: Rectangle {
        required property string mac
        required property string name
        required property bool connected
        required property int index

        width: btPairedList.width - 6; height: 36; radius: 12
        color: btPairedMouse.containsMouse
            ? Qt.rgba(1,1,1, root.isDark ? 0.06 : 0.10) : "transparent"
        border.width: btPairedMouse.containsMouse ? 1 : 0
        border.color: Qt.rgba(1,1,1, root.isDark ? 0.10 : 0.15)

        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
          Text {
            text: root.getBtIcon(parent.parent.name)
            font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
            font.pixelSize: 14; renderType: Text.CurveRendering
            color: root.theme ? root.theme.textSecondary : "#9da9a0"
          }
          Text {
            text: parent.parent.name
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 12; font.weight: Font.DemiBold
            color: root.theme ? root.theme.textPrimary : "#d3c6aa"
            Layout.fillWidth: true; elide: Text.ElideRight
          }
          // Remove button
          Rectangle {
            width: 20; height: 20; radius: 10
            color: btRemMouse.containsMouse ? Qt.rgba(1,0.3,0.3,0.12) : "transparent"
            Text {
              anchors.centerIn: parent; text: "󰆴"
              font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
              font.pixelSize: 11; color: root.theme ? root.theme.textSecondary : "#9da9a0"
            }
            MouseArea {
              id: btRemMouse; anchors.fill: parent; hoverEnabled: true
              enabled: !root.btBusy
              onClicked: root.btRemove(parent.parent.parent.mac, parent.parent.parent.name)
            }
          }
        }

        MouseArea {
          id: btPairedMouse; anchors.fill: parent; hoverEnabled: true; z: -1
          enabled: !root.btBusy
          onClicked: root.btConnect(parent.mac, parent.name)
        }
      }
    }

    // Separator
    Rectangle {
      visible: btDiscoveredModel.count > 0
      Layout.fillWidth: true; height: 1
      color: root.theme ? root.theme.textSecondary : "#9da9a0"
      opacity: 0.12
    }

    // --- Discovered devices ---
    Text {
      visible: btDiscoveredModel.count > 0 || root.btScanning
      text: root.btScanning ? "Scanning…" : "Available"
      font.family: root.theme ? root.theme.textFont : "Manrope"
      font.pixelSize: 10; font.weight: Font.DemiBold
      color: root.theme ? root.theme.textSecondary : "#9da9a0"
      opacity: 0.7
    }

    ListView {
      id: btDiscList
      visible: btDiscoveredModel.count > 0
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(5 * 40, Math.max(0, btDiscoveredModel.count * 40))
      clip: true; spacing: 4
      model: btDiscoveredModel
      ScrollBar.vertical: ScrollBar {
        active: true; width: 3
        policy: btDiscoveredModel.count > 5 ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
      }

      delegate: Rectangle {
        required property string mac
        required property string name
        required property int index

        width: btDiscList.width - 6; height: 36; radius: 12
        color: btDiscItemMouse.containsMouse
            ? Qt.rgba(1,1,1, root.isDark ? 0.06 : 0.10) : "transparent"
        border.width: btDiscItemMouse.containsMouse ? 1 : 0
        border.color: Qt.rgba(1,1,1, root.isDark ? 0.10 : 0.15)

        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
          Text {
            text: root.getBtIcon(parent.parent.name)
            font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
            font.pixelSize: 14; renderType: Text.CurveRendering
            color: root.theme ? root.theme.textSecondary : "#9da9a0"
          }
          Text {
            text: parent.parent.name
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 12; font.weight: Font.DemiBold
            color: root.theme ? root.theme.textPrimary : "#d3c6aa"
            Layout.fillWidth: true; elide: Text.ElideRight
          }
          Text {
            text: "Pair"
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 9; font.weight: Font.DemiBold
            color: root.theme ? root.theme.accent : "#a7c080"
          }
        }

        MouseArea {
          id: btDiscItemMouse; anchors.fill: parent; hoverEnabled: true
          enabled: !root.btBusy
          onClicked: root.btPair(parent.mac, parent.name)
        }
      }
    }
  }

  // === NORMAL VIEW (buttons + sliders) ===
  ColumnLayout {
    spacing: 12
    width: parent.width
    visible: !root.wifiViewVisible && !root.btViewVisible

    RowLayout {
      spacing: 12
      Layout.fillWidth: true

      Lib.ExpressiveButton {
        theme: root.theme
        icon: wifiOn.value ? "wifi_connected.svg" : "wifi_off.svg"
        label: String(wifiSSID.value || "WiFi")
        active: Boolean(wifiOn.value)
        onClicked: toggleWifi()
        onRightClicked: root.openWifiView()
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: !btOn.value ? "bt_off.svg" : (String(btDev.value) !== "On" ? "bt_connected.svg" : "bt_on.svg")
        label: String(btDev.value || "Off")
        active: Boolean(btOn.value)
        onClicked: toggleBt()
        onRightClicked: root.openBtView()
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: root.getGpuIcon()
        label: root.getGpuLabel()
        active: (root.gpuMode.toLowerCase() === "hybrid")
        customIconColor: root.getGpuColor()
        hasCustomColor: true
        onClicked: root.toggleGpu()
        onRightClicked: root.batteryToggleRequested()
      }

      Lib.ExpressiveButton {
        theme: root.theme
        icon: root.dnd ? "silent.svg" : "notify.svg"
        label: root.dnd ? "Silent" : "Notify"
        active: root.dnd
        onClicked: toggleDnd()
      }
    }

    ColumnLayout {
      spacing: 8
      Layout.fillWidth: true

      Lib.ExpressiveSlider {
        theme: root.theme
        id: briS
        icon: {
             if (value < 40) return "bness_less40.svg"
             if (value < 75) return "bness_40to75.svg"
             return "bnessmax.svg"
        }
        from: 0; to: 100
        value: 50
        Layout.fillWidth: true
        accentColor: root.theme ? root.theme.accentSlider : "#83C092"
        onUserChanged: det("brightnessctl set " + Math.round(value) + "%")

        WheelHandler {
          target: null
          onWheel: function(event) {
            root.scrollBri(event.angleDelta.y)
            event.accepted = true
          }
        }
      }

      Lib.ExpressiveSlider {
        theme: root.theme
        id: volS
        icon: {
            if (value === 0) return "mute.svg"
            if (volPoll.value.isHeadphones) return "vol_headphones.svg"
            return (value > 50) ? "vol_50p.svg" : "vol_50m.svg"
        }
        from: 0; to: 100
        value: 0
        Layout.fillWidth: true
        accentColor: root.theme ? root.theme.accentSlider : "#83C092"
        onUserChanged: det("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(value) + "%")

        WheelHandler {
          target: null
          onWheel: function(event) {
            root.scrollVol(event.angleDelta.y)
            event.accepted = true
          }
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          onClicked: root.mixerVisible = !root.mixerVisible
        }
      }

      // --- MIXER PANEL ---
      Item {
        Layout.fillWidth: true
        clip: true
        visible: root.mixerVisible
        implicitHeight: root.mixerVisible ? mixerContent.implicitHeight : 0
        Behavior on implicitHeight {
          NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
          id: mixerContent
          width: parent.width
          spacing: 6

          Rectangle {
            Layout.fillWidth: true
            height: 1
            opacity: 0.15
            color: root.theme ? root.theme.textSecondary : "#9da9a0"
          }

          Text {
            visible: mixerModel.count === 0
            text: "No apps"
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 10
            font.weight: 600
            color: root.theme ? root.theme.textSecondary : "#9da9a0"
            opacity: 0.7
          }

          Repeater {
            model: mixerModel

            Item {
              Layout.fillWidth: true
              implicitHeight: 30

              property bool _adjusting: false
              property int _vol: model.vol
              on_VolChanged: if (!_adjusting) mixSl.value = _vol

              Rectangle {
                anchors.fill: parent
                radius: 15
                color: root.theme ? root.theme.bgItem : "#2d353b"

                Rectangle {
                  width: mixSl.visualPosition * parent.width
                  height: parent.height
                  radius: 15
                  color: root.theme ? root.theme.accentSlider : "#83C092"
                  opacity: 0.25 + (mixSl.visualPosition * 0.55)
                  Behavior on width { NumberAnimation { duration: 60 } }
                }

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: 12
                  text: root.getMixerIcon(model.name)
                  font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
                  font.pixelSize: 18
                  renderType: Text.CurveRendering
                  color: mixSl.visualPosition > 0.12
                      ? (root.theme ? root.theme.textOnAccent : "#232a2e")
                      : (root.theme ? root.theme.textSecondary : "#9da9a0")
                  Behavior on color { ColorAnimation { duration: 200 } }
                  transformOrigin: Item.Center
                  scale: mixSl.hovered || mixSl.pressed ? 1.0 : 0.78
                  Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                }
              }

              Slider {
                id: mixSl
                anchors.fill: parent
                from: 0; to: 100
                value: model.vol
                background: Item {}
                handle: Item { width: 0; height: 0 }

                property int _idx: model.idx

                onMoved: {
                  parent._adjusting = true
                  _mixSend.restart()
                }
                onPressedChanged: if (!pressed) _mixSend.restart()

                Timer {
                  id: _mixSend
                  interval: 70
                  onTriggered: {
                    root.det("pactl set-sink-input-volume " + mixSl._idx + " " + Math.round(mixSl.value) + "%")
                    parent._adjusting = false
                  }
                }
              }
            }
          }
        }
      }
    }

  }
}
