pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Tones.js" as Tones

// The list menu: All and each named list with its count, a check on the
// current one, then "New list…", which turns into a name field in place, and
// "Manage lists…".
// Value-in, signals out; the body switches and creates. Like search, the
// keyboard owns the choice: it opens on the current list, the arrows or
// j k move it, Enter or 1–9 take one, and Escape backs out. The pointer only
// marks the row under it, a tint and the shell's outline, since a tint alone
// can vanish against the menu's opaque ground; a click takes that row.
FocusScope {
  id: root

  property var choices: []
  property string current: ""
  property bool retro: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property string fontFamily: Style.font.family
  property int maxHeight: 0
  // Opaque whatever the theme's popup alpha, so the rows never show through.
  property color background: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
  // Why the typed name was refused, said under the field.
  property string problem: ""

  property int cursor: 0
  property bool naming: false

  readonly property int itemHeight: Style.space(26)
  readonly property int separatorHeight: Style.space(9)
  readonly property int newIndex: choices.length
  readonly property int manageIndex: choices.length + 1
  readonly property int contentHeight: choices.length * itemHeight + separatorHeight + itemHeight * 2
    + (problem !== "" ? itemHeight : 0) + Style.space(8)

  signal chosen(string name)
  signal createRequested(string name)
  signal manageRequested()
  signal dismissed()

  width: Style.space(236)
  height: maxHeight > 0 ? Math.min(contentHeight, maxHeight) : contentHeight

  // True while the menu is open on an open surface. Turned on, it starts on
  // the current list before its first frame and takes the keys a turn later
  // if it is still on; turned off, however it closes, the surface's closing
  // included, it gives the keys up, its name field's too, and keeps what it
  // shows for the close fade.
  property bool active: false
  // Off, it still shows, through the close fade, but takes no pointer or
  // key: nothing acts or takes focus from a view that is closing.
  enabled: active
  onActiveChanged: {
    if (active) {
      reset()
      Qt.callLater(function() { if (root.active && !root.naming) root.forceActiveFocus() })
    } else {
      nameField.focus = false
      root.focus = false
    }
  }

  // The menu's start: the cursor on the current list.
  function reset() {
    naming = false
    problem = ""
    nameField.text = ""
    nameField.focus = false
    cursor = 0
    for (var i = 0; i < choices.length; i++) if (choices[i].name === current) cursor = i
    scroll.contentY = 0
    showCursor()
  }

  function moveCursor(delta) {
    cursor = Math.max(0, Math.min(manageIndex, cursor + delta))
    showCursor()
  }

  function showCursor() {
    var top = cursor * itemHeight + (cursor < newIndex ? 0 : separatorHeight)
    if (top < scroll.contentY) scroll.contentY = top
    else if (top + itemHeight > scroll.contentY + scroll.height)
      scroll.contentY = top + itemHeight - scroll.height
  }

  function take(index) {
    if (index === newIndex) startNaming()
    else if (index === manageIndex) manageRequested()
    else if (index >= 0 && index < choices.length) chosen(choices[index].name)
  }

  function startNaming() {
    cursor = newIndex
    naming = true
    problem = ""
    Qt.callLater(function() { if (root.active && root.naming) nameField.forceActiveFocus() })
  }

  function stopNaming() {
    naming = false
    problem = ""
    nameField.text = ""
    // The field gives up its focus, or the scope hands the keys straight
    // back to it.
    nameField.focus = false
    if (root.active) root.forceActiveFocus()
  }

  Keys.onPressed: function(event) {
    // While naming, the field has the keys; what it lets past goes nowhere.
    if (root.naming) { event.accepted = true; return }
    if (event.key === Qt.Key_Escape) { root.dismissed(); event.accepted = true }
    else if (event.key === Qt.Key_Down || event.text === "j") { root.moveCursor(1); event.accepted = true }
    else if (event.key === Qt.Key_Up || event.text === "k") { root.moveCursor(-1); event.accepted = true }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.take(root.cursor); event.accepted = true }
    else if (event.text >= "1" && event.text <= "9") { root.take(Number(event.text) - 1); event.accepted = true }
    else if (event.text === "w") { root.dismissed(); event.accepted = true }
    // Every other key stays with the menu, so nothing behind it acts.
    else event.accepted = true
  }

  Rectangle {
    anchors.fill: parent
    radius: root.retro ? 0 : Style.cornerRadius
    color: root.background
    border.width: 1
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
  }

  Flickable {
    id: scroll
    objectName: "menuScroll"
    anchors.fill: parent
    anchors.margins: Style.space(4)
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
          objectName: "listChoice"
          required property var modelData
          required property int index
          width: column.width
          height: root.itemHeight

          Rectangle {
            readonly property bool pointed: entryMouse.containsMouse && !(entry.index === root.cursor && !root.naming)
            anchors.fill: parent
            radius: root.retro ? 0 : Style.cornerRadius
            color: entry.index === root.cursor && !root.naming ? Style.hoverFillFor(root.foreground, Color.accent)
              : pointed ? Style.normalFillFor(root.foreground, Color.accent) : "transparent"
            border.width: pointed ? 1 : 0
            border.color: Style.normalBorderFor(root.foreground, Color.accent)
          }

          Text {
            id: mark
            x: Style.space(8)
            width: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            text: entry.modelData.name === root.current ? "✓" : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            anchors.left: mark.right
            anchors.right: count.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: entry.modelData.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
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
            id: entryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.take(entry.index)
          }
        }
      }

      Item {
        width: column.width
        height: root.separatorHeight

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          x: Style.space(8)
          width: parent.width - Style.space(16)
          height: 1
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        }
      }

      Item {
        id: newRow
        objectName: "newListRow"
        width: column.width
        height: root.itemHeight

        Rectangle {
          anchors.fill: parent
          visible: !root.naming
          radius: root.retro ? 0 : Style.cornerRadius
          color: root.cursor === root.newIndex ? Style.hoverFillFor(root.foreground, Color.accent)
            : newMouse.containsMouse ? Style.normalFillFor(root.foreground, Color.accent) : "transparent"
          border.width: newMouse.containsMouse && root.cursor !== root.newIndex ? 1 : 0
          border.color: Style.normalBorderFor(root.foreground, Color.accent)
        }

        Text {
          visible: !root.naming
          x: Style.space(24)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "New list…"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
          id: newMouse
          anchors.fill: parent
          visible: !root.naming
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.startNaming()
        }

        TextField {
          id: nameField
          objectName: "listNameField"
          anchors.fill: parent
          visible: root.naming
          verticalPadding: 0
          foreground: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          placeholderText: "List name, ↵ to make it"
          onTextChanged: root.problem = ""
          onAccepted: root.createRequested(text)
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.stopNaming(); event.accepted = true }
          }
        }
      }

      Text {
        visible: root.problem !== ""
        width: column.width
        height: root.itemHeight
        leftPadding: Style.space(24)
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        text: root.problem
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }

      Item {
        objectName: "manageListsRow"
        width: column.width
        height: root.itemHeight

        Rectangle {
          anchors.fill: parent
          radius: root.retro ? 0 : Style.cornerRadius
          color: root.cursor === root.manageIndex && !root.naming ? Style.hoverFillFor(root.foreground, Color.accent)
            : manageMouse.containsMouse ? Style.normalFillFor(root.foreground, Color.accent) : "transparent"
          border.width: manageMouse.containsMouse && !(root.cursor === root.manageIndex && !root.naming) ? 1 : 0
          border.color: Style.normalBorderFor(root.foreground, Color.accent)
        }

        Text {
          x: Style.space(24)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Manage lists…"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
          id: manageMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.manageRequested()
        }
      }
    }
  }
}
