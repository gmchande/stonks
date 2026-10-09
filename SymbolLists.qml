pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Tones.js" as Tones

// A symbol's lists, in the rows' place: one tick box per list, All first.
// Value-in, signals out; the body applies the membership rules. It owns its
// keys while open: the arrows or j k move the cursor, Enter or Space ticks
// the cursor's list, 1–9 tick that list, Escape or m closes. The pointer
// tints the row under it, and a click ticks that row.
FocusScope {
  id: root

  property var choices: []
  property string symbol: ""
  property string symbolName: ""
  property bool retro: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property string fontFamily: Style.font.family
  // A short word in the key line's place, for a moment: why a tick did nothing.
  property string note: ""

  property int cursor: 0

  readonly property int itemHeight: Style.space(30)
  readonly property int contentHeight: itemHeight + choices.length * itemHeight + keyLine.height

  signal toggled(string name, bool member)
  signal dismissed()

  function member(index) {
    return !!choices[index] && choices[index].symbols.indexOf(symbol) >= 0
  }

  // True while the checklist is open on an open surface. Turned on, it
  // starts before its first frame and takes the keys a turn later if it is
  // still on; turned off, however it closes, the surface's closing included,
  // it gives the keys up and keeps what it shows for the close fade.
  property bool active: false
  // Off, it still shows, through the close fade, but takes no pointer or
  // key: nothing acts or takes focus from a view that is closing.
  enabled: active
  onActiveChanged: {
    if (active) {
      reset()
      Qt.callLater(function() { if (root.active) root.forceActiveFocus() })
    } else {
      root.focus = false
    }
  }

  // Opens on the first named list, and with none there is no cursor until an
  // arrow or a number picks a row: a stray Enter never unticks All.
  function reset() {
    cursor = choices.length > 1 ? 1 : -1
    scroll.contentY = 0
  }

  function toggle(index) {
    if (index < 0 || index >= choices.length) return
    cursor = index
    showCursor()
    toggled(choices[index].name, !member(index))
  }

  function moveCursor(delta) {
    cursor = Math.max(0, Math.min(choices.length - 1, cursor + delta))
    showCursor()
  }

  function showCursor() {
    var top = cursor * itemHeight
    if (top < scroll.contentY) scroll.contentY = top
    else if (top + itemHeight > scroll.contentY + scroll.height)
      scroll.contentY = top + itemHeight - scroll.height
  }

  Keys.onPressed: function(event) {
    event.accepted = true
    if (event.key === Qt.Key_Escape || event.text === "m") root.dismissed()
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.toggle(root.cursor)
    else if (event.key === Qt.Key_Down || event.text === "j") root.moveCursor(1)
    else if (event.key === Qt.Key_Up || event.text === "k") root.moveCursor(-1)
    else if (event.text >= "1" && event.text <= "9") root.toggle(Number(event.text) - 1)
  }

  Item {
    id: title
    width: parent.width
    height: root.itemHeight

    Text {
      id: lead
      x: Style.space(6)
      anchors.baseline: symbolText.baseline
      textFormat: Text.PlainText
      text: "LISTS WITH"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    Text {
      id: symbolText
      anchors.left: lead.right
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: root.symbol
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    Text {
      anchors.left: symbolText.right
      anchors.leftMargin: Style.space(8)
      anchors.right: done.left
      anchors.rightMargin: Style.space(16)
      anchors.baseline: symbolText.baseline
      textFormat: Text.PlainText
      text: root.symbolName.toUpperCase()
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 1
      elide: Text.ElideRight
    }

    ListAction {
      id: done
      objectName: "symbolListsDone"
      view: root
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      text: "DONE"
      strong: true
      onActivated: root.dismissed()
    }
  }

  Flickable {
    id: scroll
    anchors.top: title.bottom
    anchors.bottom: keyLine.top
    width: parent.width
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: column
      width: scroll.width

      Repeater {
        model: root.choices

        Item {
          id: entry
          objectName: "symbolListRow"
          required property var modelData
          required property int index
          readonly property bool ticked: modelData.symbols.indexOf(root.symbol) >= 0
          width: column.width
          height: root.itemHeight

          Rectangle {
            anchors.fill: parent
            radius: root.retro ? 0 : Style.cornerRadius
            color: rowMouse.containsMouse ? Style.normalFillFor(root.foreground, Color.accent) : "transparent"
          }

          Rectangle {
            objectName: "cursorBar"
            visible: entry.index === root.cursor
            y: Style.space(6)
            width: Style.space(2)
            height: parent.height - Style.space(12)
            radius: root.retro ? 0 : width / 2
            color: Style.selectedStateColor(root.foreground, Color.accent)
          }

          Rectangle {
            id: box
            objectName: "tickBox"
            x: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(12)
            height: width
            radius: root.retro ? 0 : Style.space(3)
            color: "transparent"
            border.width: 1
            border.color: entry.ticked ? root.foreground : root.dim

            Text {
              anchors.centerIn: parent
              visible: entry.ticked
              text: "✓"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            anchors.left: box.right
            anchors.leftMargin: Style.space(10)
            anchors.right: (entry.modelData.name === "" ? hint : count).left
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: entry.modelData.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            id: hint
            visible: entry.modelData.name === ""
            anchors.right: count.left
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "UNTICK TO REMOVE EVERYWHERE"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          Text {
            id: count
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: String(entry.modelData.count)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle(entry.index)
          }
        }
      }
    }
  }

  // The key line follows the rows, and holds the bottom once they scroll.
  Item {
    id: keyLine
    y: Math.min(title.height + root.choices.length * root.itemHeight, root.height - height)
    width: parent.width
    height: root.itemHeight + Style.space(6)

    PanelSeparator {
      anchors.top: parent.top
      foreground: root.foreground
      strength: 0.08
    }

    Text {
      objectName: "keyHints"
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Style.space(3)
      width: Math.min(implicitWidth, parent.width - Style.space(20))
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: root.note !== "" ? root.note : "↵ tick  ·  1–9 that list  ·  esc done"
      color: root.note !== "" ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
