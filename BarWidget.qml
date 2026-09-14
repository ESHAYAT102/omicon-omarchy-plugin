import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "esh.omicon"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋩"
    active: root.opened || iconDrop.containsDrag
    tooltipText: "Change app icon · drop an image here"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggle()
    }

    DropArea {
      id: iconDrop
      anchors.fill: parent
      onContainsDragChanged: if (containsDrag && !root.opened) root.open()
      onDropped: function(drop) {
        if (panelLoader.item) panelLoader.item.selectDroppedImage(drop.urls, drop.text)
        drop.accept()
      }
    }
  }
}
