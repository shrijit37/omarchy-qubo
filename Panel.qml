import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
  id: root
  moduleName: "qubo.purifier"
  ipcTarget: "qubo.purifier"

  // Telemetry data
  property bool authenticated: false
  property bool online: false
  property bool power: false
  property int pm25: 0
  property int fanSpeed: 1
  property string mode: "auto"
  property int filterLife: 100
  property string filterHours: ""
  property bool childLock: false
  property bool lightOn: true
  property string dimmer: "high"
  property string firmware: ""
  property string avgPm25: ""
  property string minPm25: ""
  property string maxPm25: ""
  property string totalUsageMins: ""
  property string ipAddress: "192.168.1.3"
  property string ssid: ""
  property string rssi: ""
  property string outdoorStation: ""
  property string deviceName: "Smart Air Purifier Q200"
  property string deviceModel: "HPH01A"
  property string macAddress: "58:2A:BD:2D:EF:B8"
  property bool busy: false
  property var historyPoints: []

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string aqiCategory: {
    if (pm25 <= 30) return "Good"
    if (pm25 <= 60) return "Moderate"
    if (pm25 <= 90) return "Poor"
    if (pm25 <= 120) return "Unhealthy"
    return "Severe"
  }

  readonly property color aqiColor: {
    if (!power) return Qt.darker(foreground, 1.8)
    if (pm25 <= 30) return "#10b981" // emerald
    if (pm25 <= 60) return "#38bdf8" // sky blue
    if (pm25 <= 90) return "#f59e0b" // amber
    if (pm25 <= 120) return "#f97316" // orange
    return "#ef4444" // red
  }

  readonly property bool airAlarm: pm25 > 90

  readonly property string barLabel: {
    if (!authenticated) return "󰌪 Login"
    if (!online) return "󰌪 Offline"
    if (!power) return "󰌪 Off"
    return "󰈐 AQI " + pm25
  }

  readonly property string statusTooltip: {
    if (!authenticated) return "Qubo Air Purifier: Not logged in\nClick to login."
    if (!online) return "Qubo Air Purifier: Offline"
    return deviceName + " (" + (power ? "ON" : "OFF") + ")\n" +
           "• PM2.5: " + pm25 + " µg/m³ (" + aqiCategory + ")\n" +
           "• Fan Speed: " + fanSpeed + "\n" +
           "• Mode: " + mode.toUpperCase() + "\n" +
           "• Filter: " + filterLife + "%\n\n" +
           "Left Click: Open control panel\n" +
           "Middle Click: Toggle power\n" +
           "Scroll Wheel: Adjust fan speed"
  }

  function refresh() {
    if (!statusProc.running) {
      root.busy = true
      statusProc.running = true
    }
  }

  function togglePower() {
    root.runCmd(["toggle"])
  }

  function setSpeed(s) {
    root.runCmd(["speed", String(s)])
  }

  function setMode(m) {
    root.runCmd(["mode", String(m)])
  }

  function runCmd(args) {
    if (actionProc.running) return
    root.busy = true
    actionProc.command = ["/home/shrijit/.local/bin/qubo-control"].concat(args)
    actionProc.running = true
  }

  function updateTelemetry(raw) {
    root.busy = false
    try {
      var d = JSON.parse(raw.trim())
      if (d.authenticated === false) {
        root.authenticated = false
        return
      }
      root.authenticated = true
      root.online = d.online === true
      root.power = d.power === true
      root.pm25 = Number(d.pm25 || 0)
      root.fanSpeed = Number(d.fan_speed || 1)
      root.mode = String(d.mode || "auto").toLowerCase()
      root.filterLife = Number(d.filter_life || 100)
      root.filterHours = String(d.filter_hours || "")
      root.childLock = d.child_lock === true
      root.lightOn = d.light_on === true
      root.dimmer = String(d.dimmer || "high")
      root.firmware = String(d.firmware || "")
      root.avgPm25 = String(d.avg_pm25 || "")
      root.minPm25 = String(d.min_pm25 || "")
      root.maxPm25 = String(d.max_pm25 || "")
      root.totalUsageMins = String(d.total_usage_mins || "")
      root.ipAddress = String(d.ip_address || "192.168.1.3")
      root.ssid = String(d.ssid || "")
      root.rssi = String(d.rssi || "")
      root.outdoorStation = String(d.outdoor_station || "")
      if (d.name) root.deviceName = String(d.name)
      if (d.model) root.deviceModel = String(d.model)
      if (d.mac) root.macAddress = String(d.mac)
      if (d.history && Array.isArray(d.history)) root.historyPoints = d.history
    } catch (e) {
      console.warn("Failed to parse qubo-control in panel:", e)
    }
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 20000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["/home/shrijit/.local/bin/qubo-control", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateTelemetry(text)
    }
    onExited: root.busy = false
  }

  Process {
    id: actionProc
    command: []
    onExited: root.refresh()
  }

  // --- Top Bar Button ---
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barLabel
    active: root.power || root.opened
    activeColor: root.airAlarm ? Commons.Color.urgent : root.aqiColor
    tooltipText: root.statusTooltip

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.togglePower()
      else root.toggle()
    }

    onWheelMoved: function(delta) {
      if (!root.power) return
      if (delta > 0) root.setSpeed(Math.min(3, root.fanSpeed + 1))
      else if (delta < 0) root.setSpeed(Math.max(1, root.fanSpeed - 1))
    }
  }

  // --- Dropdown KeyboardPanel ---
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(350))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.togglePower()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // 1. Hero Header
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              text: "󰈐"
              color: root.aqiColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              opacity: root.power ? 1.0 : 0.4
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              RotationAnimator on rotation {
                running: root.power
                from: 0; to: 360
                duration: root.fanSpeed === 3 ? 400 : (root.fanSpeed === 2 ? 800 : 1600)
                loops: Animation.Infinite
              }
              onRotationChanged: if (!root.power) rotation = 0
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(12)
              anchors.right: refreshAction.left
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.deviceName
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.ipAddress + (root.ssid !== "" ? " • " + root.ssid : "") + (root.rssi !== "" ? " (" + root.rssi + " dBm)" : "")
                color: root.foreground
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            PanelActionButton {
              id: refreshAction
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰑐"
              foreground: root.foreground
              tooltipText: "Refresh Telemetry"
              onClicked: root.refresh()
            }
          }

          // 2. Power Toggle (ButtonGroup style like Dyson)
          ButtonGroup {
            width: parent.width
            foreground: root.foreground
            background: root.bar ? root.bar.background : Commons.Color.background
            fontFamily: root.fontFamily
            options: [
              { value: "off", label: "Power Off", icon: "󰐥" },
              { value: "on", label: "Power On", icon: "󰐥" }
            ]
            value: root.power ? "on" : "off"
            onChanged: function(v) {
              if ((v === "on") !== root.power) root.togglePower()
            }
          }

          // 3. Air Quality Section Header & Card
          PanelSectionHeader {
            width: parent.width
            text: "Air Quality"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          BorderSurface {
            width: parent.width
            implicitHeight: Style.space(88)
            radius: Style.cornerRadius
            color: Qt.rgba(root.aqiColor.r, root.aqiColor.g, root.aqiColor.b, 0.12)
            borderSpec: Border.controlSpec("normal", root.aqiColor, root.aqiColor)

            Item {
              anchors.fill: parent
              anchors.margins: Style.space(12)

              Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Row {
                  spacing: Style.space(6)
                  Text {
                    text: root.power ? String(root.pm25) : "—"
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(34)
                    font.bold: true
                    color: root.aqiColor
                    anchors.baseline: pmUnit.baseline
                  }
                  Text {
                    id: pmUnit
                    text: "µg/m³ PM2.5"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                    opacity: 0.7
                  }
                }

                BorderSurface {
                  width: badgeText.implicitWidth + Style.space(12)
                  height: Style.space(20)
                  radius: Style.space(10)
                  color: root.aqiColor

                  Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.power ? (root.aqiCategory + " Air") : "Standby"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption * 0.85
                    font.bold: true
                    color: "#0f172a"
                  }
                }
              }

              Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)
                width: Style.space(140)

                Text {
                  text: "Today's Avg: " + (root.avgPm25 !== "" ? root.avgPm25 + " µg/m³" : "—")
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  text: "Range: " + (root.minPm25 !== "" ? root.minPm25 : "0") + " – " + (root.maxPm25 !== "" ? root.maxPm25 : "0")
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                  opacity: 0.65
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  text: "Runtime: " + (root.totalUsageMins !== "" ? root.totalUsageMins + "m" : "—")
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                  opacity: 0.65
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }
          }
          // AQI Spectrum Scale Bar
          Column {
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              height: Style.space(14)

              // Gradient track
              Row {
                anchors.fill: parent
                anchors.topMargin: Style.space(4)
                anchors.bottomMargin: Style.space(4)
                spacing: Style.space(2)

                Rectangle { width: (parent.width - Style.space(8)) * 0.20; height: parent.height; radius: Style.space(3); color: "#10b981" }
                Rectangle { width: (parent.width - Style.space(8)) * 0.20; height: parent.height; radius: Style.space(3); color: "#38bdf8" }
                Rectangle { width: (parent.width - Style.space(8)) * 0.20; height: parent.height; radius: Style.space(3); color: "#f59e0b" }
                Rectangle { width: (parent.width - Style.space(8)) * 0.20; height: parent.height; radius: Style.space(3); color: "#f97316" }
                Rectangle { width: (parent.width - Style.space(8)) * 0.20; height: parent.height; radius: Style.space(3); color: "#ef4444" }
              }

              // Cursor pointer at current PM2.5 level (clamped 0-150)
              Rectangle {
                width: Style.space(10)
                height: Style.space(10)
                radius: Style.space(5)
                color: "#ffffff"
                border.color: "#0f172a"
                border.width: 1.5
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * (Math.min(150, Math.max(0, root.pm25)) / 150.0)))
              }
            }

            Row {
              width: parent.width
              Text { text: "0 Good"; color: root.foreground; opacity: 0.5; font.family: root.fontFamily; font.pixelSize: Style.font.caption * 0.8 }
              Item { Layout.fillWidth: true; width: parent.width - implicitWidth }
              Text { text: "Moderate"; color: root.foreground; opacity: 0.5; font.family: root.fontFamily; font.pixelSize: Style.font.caption * 0.8 }
              Item { Layout.fillWidth: true; width: parent.width - implicitWidth }
              Text { text: "150+ Severe"; color: root.foreground; opacity: 0.5; font.family: root.fontFamily; font.pixelSize: Style.font.caption * 0.8 }
            }
          }

          // Dyson-style Historical PM2.5 Graph
          Item {
            width: parent.width
            implicitHeight: Style.space(86)

            Canvas {
              id: aqiGraph
              anchors.fill: parent
              anchors.bottomMargin: Style.space(16)

              readonly property var points: root.historyPoints
              readonly property color line: root.airAlarm ? Commons.Color.urgent : root.aqiColor
              onPointsChanged: requestPaint()
              onLineChanged: requestPaint()

              onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                if (!points || points.length < 2) return

                var w = width, h = height
                var tMin = points[0].t
                var tMax = points[points.length - 1].t
                var tSpan = Math.max(1, tMax - tMin)
                var minVal = 0
                var maxVal = Math.max(80, root.maxPm25 !== "" ? Number(root.maxPm25) : 80)
                for (var i = 0; i < points.length; i++) {
                  if (points[i].v > maxVal) maxVal = points[i].v
                }
                var vSpan = Math.max(1, maxVal - minVal)

                function px(p) { return (p.t - tMin) / tSpan * w }
                function py(p) { return h - (p.v - minVal) / vSpan * h }

                // Area fill under curve
                ctx.beginPath()
                ctx.moveTo(px(points[0]), h)
                for (var j = 0; j < points.length; j++) ctx.lineTo(px(points[j]), py(points[j]))
                ctx.lineTo(px(points[points.length - 1]), h)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(line.r, line.g, line.b, 0.16)
                ctx.fill()

                // Stroke curve
                ctx.beginPath()
                for (var k = 0; k < points.length; k++) {
                  var x = px(points[k]), y = py(points[k])
                  if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.strokeStyle = line
                ctx.lineWidth = Math.max(1.8, Style.space(2))
                ctx.lineJoin = "round"; ctx.lineCap = "round"
                ctx.stroke()

                // Latest point circle
                var last = points[points.length - 1]
                ctx.beginPath()
                ctx.arc(px(last), py(last), Style.space(3.5), 0, Math.PI * 2)
                ctx.fillStyle = line
                ctx.fill()
              }
            }

            Text {
              anchors.left: parent.left; anchors.bottom: parent.bottom
              text: "Peak: " + (root.maxPm25 !== "" ? root.maxPm25 : "85") + " µg/m³"
              color: root.foreground; opacity: 0.55
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }

            Text {
              anchors.right: parent.right; anchors.bottom: parent.bottom
              text: "Today's Trend"
              color: root.foreground; opacity: 0.55
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }
          }


          // 4. Fan Speed (ChipsRow)
          ChipsRow {
            width: parent.width
            bar: root.bar
            actionable: root.power
            label: "Speed"
            captionWidth: Style.space(54)
            options: [
              { value: "1", label: "1 (Low)" },
              { value: "2", label: "2 (Mid)" },
              { value: "3", label: "3 (Turbo)" }
            ]
            value: String(root.fanSpeed)
            onChanged: function(v) { root.setSpeed(Number(v)) }
          }

          // 5. Operating Mode (ChipsRow)
          ChipsRow {
            width: parent.width
            bar: root.bar
            actionable: root.power
            label: "Mode"
            captionWidth: Style.space(54)
            options: [
              { value: "auto", label: "Auto" },
              { value: "sleep", label: "Sleep" },
              { value: "manual", label: "Manual" }
            ]
            value: root.mode
            onChanged: function(v) { root.setMode(v) }
          }

          // 6. Quick Function Icons Toolbar (Flow like Dyson)
          PanelSectionHeader {
            width: parent.width
            text: "Controls"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Flow {
            width: parent.width
            spacing: Style.space(8)

            Button {
              iconText: root.childLock ? "󰌾" : "󰌿"
              text: root.childLock ? "Child Lock: ON" : "Child Lock: OFF"
              tooltipText: "Child Lock — physical button lockout on device"
              selected: root.childLock
              bordered: true
              foreground: root.foreground
              background: root.bar ? root.bar.background : Commons.Color.background
              fontFamily: root.fontFamily
              onClicked: root.runCmd(["childlock", root.childLock ? "disable" : "enable"])
            }

            Button {
              iconText: root.lightOn ? "󰛨" : "󰛩"
              text: root.lightOn ? "Display Light: ON" : "Display Light: OFF"
              tooltipText: "Device LED display illumination"
              selected: root.lightOn
              bordered: true
              foreground: root.foreground
              background: root.bar ? root.bar.background : Commons.Color.background
              fontFamily: root.fontFamily
              onClicked: root.runCmd(["light", root.lightOn ? "off" : "on"])
            }
          }

          // 7. Filter Health Row
          LabelledRow {
            width: parent.width
            bar: root.bar
            label: "Filter"
            captionWidth: Style.space(54)

            Column {
              width: parent.width
              spacing: Style.space(4)

              Row {
                width: parent.width
                Text {
                  text: root.filterLife + "% (" + (root.filterHours !== "" ? root.filterHours + "h remaining" : "Good") + ")"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.foreground
                }
              }

              Rectangle {
                width: parent.width
                height: Style.space(6)
                radius: Style.space(3)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

                Rectangle {
                  width: parent.width * (root.filterLife / 100.0)
                  height: parent.height
                  radius: Style.space(3)
                  color: root.filterLife > 20 ? "#10b981" : "#ef4444"
                }
              }
            }
          }

          // 8. Footer Metadata
          Row {
            width: parent.width
            Text {
              text: root.deviceModel + " • " + (root.firmware !== "" ? root.firmware : "FW") + " • " + root.macAddress
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption * 0.85
              color: root.foreground
              opacity: 0.4
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }
      }
    }
  }
}
