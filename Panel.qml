import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "esh.omicon"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property var apps: []
  property var changedApps: []
  property string appId: ""
  property string imagePath: ""
  property string status: ""
  property string pendingRevertId: ""
  property bool revertConfirmationReady: false
  property bool applyOnAppSelection: false
  property bool busy: false
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/esh.omicon/apply-icon"
  readonly property string chooser: Quickshell.env("HOME") + "/.config/omarchy/plugins/esh.omicon/choose-image"

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function loadApps() {
    var entries = DesktopEntries.applications.values || []
    var options = []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry || entry.noDisplay || !entry.id) continue
      options.push({
        value: String(entry.id),
        label: String(entry.name || entry.id),
        description: String(entry.genericName || entry.comment || "")
      })
    }
    options.sort(function(a, b) { return a.label.localeCompare(b.label) })
    apps = options
  }

  function appName(id) {
    for (var i = 0; i < apps.length; i++)
      if (apps[i].value === id) return apps[i].label
    return id
  }

  function expandedImagePath() {
    return imagePath.indexOf("~/") === 0
      ? Quickshell.env("HOME") + imagePath.slice(1)
      : imagePath
  }

  function loadChanges() {
    if (!listProc.running) listProc.running = true
  }

  function applyIcon() {
    if (!appId || !imagePath || busy) return
    applyOnAppSelection = false
    busy = true
    status = "Updating icon…"
    applyProc.action = "apply"
    applyProc.command = [helper, "apply", appId, imagePath]
    applyProc.running = true
  }

  function selectDroppedImage(urls, text) {
    var value = urls && urls.length > 0 ? String(urls[0]) : String(text || "")
    if (value.indexOf("file://") !== 0) {
      root.open()
      status = "Drop an image file"
      return false
    }
    var path = decodeURIComponent(value.slice("file://".length))
    if (!/\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(path)) {
      root.open()
      status = "Drop an image file"
      return false
    }
    root.open()
    imagePath = path
    appId = ""
    applyOnAppSelection = true
    status = "Select an application"
    return true
  }

  function revertIcon(id) {
    if (!id || busy) return
    pendingRevertId = ""
    revertConfirmationReady = false
    revertArmTimer.stop()
    busy = true
    status = "Restoring icon…"
    applyProc.action = "revert"
    applyProc.command = [helper, "revert", id]
    applyProc.running = true
  }

  onOpenedChanged: {
    pendingRevertId = ""
    revertConfirmationReady = false
    revertArmTimer.stop()
    if (opened) { loadApps(); loadChanges(); status = "" }
  }
  Component.onCompleted: { loadApps(); loadChanges() }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.loadApps() }
  }

  Timer {
    id: revertArmTimer
    interval: 300
    onTriggered: root.revertConfirmationReady = root.pendingRevertId !== ""
  }

  Process {
    id: browseProc
    property string output: ""
    command: [root.chooser]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { browseProc.output += chunk }
    }
    onRunningChanged: if (running) output = ""
    onExited: function(exitCode) {
      if (exitCode !== 0) root.status = "Could not open file browser"
      else if (output !== "") {
        root.imagePath = output
        root.applyOnAppSelection = false
        root.status = ""
      }
      Qt.callLater(function() { root.open() })
    }
  }

  Process {
    id: applyProc
    property string action: ""
    property string output: ""
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { applyProc.output += chunk }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { applyProc.output += chunk }
    }
    onRunningChanged: if (running) output = ""
    onExited: function(exitCode) {
      root.busy = false
      root.status = exitCode === 0
        ? (action === "revert" ? "Icon restored" : "Icon updated")
        : (output.trim() || "Could not update icon")
      if (exitCode === 0) root.loadChanges()
      if (action === "revert") Qt.callLater(function() { root.open() })
    }
  }

  Process {
    id: listProc
    property var rows: []
    command: [root.helper, "list"]
    stdout: SplitParser {
      onRead: function(line) {
        var fields = line.split("\t")
        if (fields.length >= 2) listProc.rows.push({ id: fields[0], icon: fields[1] })
      }
    }
    onRunningChanged: if (running) rows = []
    onExited: root.changedApps = rows.slice()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(form.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: appPicker.popupOpen || pathField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: form
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Text {
          text: "Choose an app icon"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        SearchableDropdown {
          id: appPicker
          width: parent.width
          label: "Application"
          placeholderText: "Search applications…"
          emptyText: "No applications found"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          options: root.apps
          value: root.appId
          onChanged: function(value) {
            root.appId = value
            root.status = ""
            if (root.applyOnAppSelection) Qt.callLater(root.applyIcon)
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          Text {
            text: "Icon image"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Row {
            width: parent.width
            spacing: Style.spacing.sm

            TextField {
              id: pathField
              width: parent.width - browseButton.width - parent.spacing
              text: root.imagePath
              placeholderText: "~/Downloads/icon.png"
              foreground: root.bar.foreground
              onTextEdited: {
                root.imagePath = text
                root.applyOnAppSelection = false
                root.status = ""
              }
              onAccepted: root.applyIcon()
            }

            Button {
              id: browseButton
              text: "Browse"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              focusable: true
              active: !browseProc.running
              onClicked: if (!browseProc.running) browseProc.running = true
            }
          }
        }

        Image {
          visible: root.imagePath !== ""
          width: Style.space(72)
          height: width
          anchors.horizontalCenter: parent.horizontalCenter
          source: root.imagePath ? "file://" + root.expandedImagePath() : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        Text {
          visible: root.status !== ""
          width: parent.width
          text: root.status
          color: root.status === "Icon updated" ? Color.accent : root.bar.foreground
          horizontalAlignment: Text.AlignHCenter
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Button {
          width: parent.width
          text: root.busy ? "Updating…" : "Use this icon"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          active: root.appId !== "" && root.imagePath !== "" && !root.busy
          focusable: active
          onClicked: root.applyIcon()
        }

        PanelSeparator {
          visible: root.changedApps.length > 0
          foreground: root.bar.foreground
        }

        PanelSectionHeader {
          visible: root.changedApps.length > 0
          text: "CHANGED ICONS"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        ListView {
          width: parent.width
          height: root.changedApps.length > 0 ? Math.min(contentHeight, Style.space(44 * 8 + 6 * 7)) : 0
          visible: root.changedApps.length > 0
          model: root.changedApps
          spacing: Style.space(6)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          delegate: CursorSurface {
            required property var modelData
            width: ListView.view.width
            height: Style.space(44)
            foreground: root.bar.foreground

            Image {
              id: changedIcon
              width: Style.space(28)
              height: width
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              source: "file://" + modelData.icon
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }

            Text {
              anchors.left: changedIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.right: restoreButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.appName(modelData.id)
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Button {
              id: restoreButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰑐"
              foreground: root.pendingRevertId === modelData.id ? Color.urgent : root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              onClicked: {
                if (root.pendingRevertId === modelData.id && root.revertConfirmationReady) {
                  root.revertIcon(modelData.id)
                } else if (root.pendingRevertId !== modelData.id) {
                  root.pendingRevertId = modelData.id
                  root.revertConfirmationReady = false
                  revertArmTimer.restart()
                }
              }

              PanelToolTip {
                visible: restoreButton.hot
                text: root.pendingRevertId === modelData.id
                  ? "Click again to restore"
                  : "Restore original icon"
                fontFamily: root.bar.fontFamily
              }
            }
          }
        }
      }
    }
  }
}
