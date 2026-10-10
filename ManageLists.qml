pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Tones.js" as Tones

// Manage lists, in the rows' place: rename, reorder, and delete the named
// lists. All is listed first and cannot be changed. Value-in, signals out;
// the body persists. Like the list menu it owns its keys while open: the
// arrows or j k move the cursor, Enter renames, J K move the list, x asks to
// delete and Enter confirms, Escape backs out one step. One cursor, as on the
// rows: moving the pointer puts it, with the rows' mark, on the row under it,
// which shows that row's controls; a click on one takes it.
FocusScope {
  id: root

  property var choices: []
  property bool retro: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property string fontFamily: Style.font.family
  // Why the typed name was refused, said under the field.
  property string problem: ""

  property int cursor: 1
  property bool renaming: false
  property bool confirming: false

  readonly property int itemHeight: Style.space(30)
  readonly property int rowsHeight: choices.length * itemHeight + (problem !== "" ? itemHeight : 0)
  readonly property int contentHeight: itemHeight + rowsHeight + keyLine.height
  readonly property var cursorChoice: choices[cursor] || null

  signal renameRequested(string name, string newName)
  signal moveRequested(string name, int delta)
  signal deleteRequested(string name)
  signal dismissed()

  // True while the view is open on an open surface. Turned on, it starts on
  // the first named list, or All when there is none, before its first frame
  // and takes the keys a turn later if it is still on; turned off, however
  // it closes, the surface's closing included, it gives the keys up, its
  // rename field's too, and keeps what it shows for the close fade.
  property bool active: false
  // Off, it still shows, through the close fade, but takes no pointer or
  // key: nothing acts or takes focus from a view that is closing.
  enabled: active
  onActiveChanged: {
    if (active) {
      reset()
      pointer.rest()
      Qt.callLater(function() { if (root.active && !root.renaming) root.forceActiveFocus() })
    } else {
      nameField.focus = false
      root.focus = false
      scroll.cancelFlick()
    }
  }

  function reset() {
    renaming = false
    confirming = false
    problem = ""
    nameField.focus = false
    cursor = choices.length > 1 ? 1 : 0
    scroll.contentY = 0
  }

  function moveCursor(delta) {
    confirming = false
    cursor = Math.max(0, Math.min(choices.length - 1, cursor + delta))
    showCursor()
  }

  // The cursor to the row the pointer moved onto, at (x, y) in the scene;
  // the title and the key line are no row. A row renaming or asking keeps
  // it, so the question stays on its own list.
  function pointAt(x, y) {
    if (renaming || confirming) return
    var at = scroll.mapFromItem(null, x, y)
    if (at.x < 0 || at.x >= scroll.width || at.y < 0 || at.y >= scroll.height) return
    var index = Math.floor((at.y + scroll.contentY) / itemHeight)
    if (index < choices.length) cursor = index
  }

  // A key takes the list over from the wheel: its motion stops, so it
  // cannot carry the cursor on from where the key put it.
  function showCursor() {
    scroll.cancelFlick()
    var top = cursor * itemHeight
    if (top < scroll.contentY) scroll.contentY = top
    else if (top + itemHeight > scroll.contentY + scroll.height)
      scroll.contentY = top + itemHeight - scroll.height
  }

  function startRenaming(index) {
    if (!choices[index] || choices[index].name === "") return
    cursor = index
    confirming = false
    problem = ""
    nameField.text = choices[index].name
    renaming = true
    Qt.callLater(function() {
      if (!root.active || !root.renaming) return
      nameField.forceActiveFocus()
      nameField.selectAll()
    })
  }

  // The field gives up its focus, or the scope hands the keys straight back.
  function stopEditing() {
    renaming = false
    confirming = false
    problem = ""
    nameField.focus = false
    if (root.active) root.forceActiveFocus()
  }

  function move(index, delta) {
    var choice = choices[index]
    var to = index + delta
    if (!choice || choice.name === "" || to < 1 || to >= choices.length) return
    confirming = false
    cursor = to
    moveRequested(choice.name, delta)
    showCursor()
  }

  function askDelete(index) {
    if (!choices[index] || choices[index].name === "") return
    cursor = index
    confirming = true
  }

  function confirmDelete() {
    if (!confirming || !cursorChoice) return
    var name = cursorChoice.name
    confirming = false
    deleteRequested(name)
    cursor = Math.min(cursor, choices.length - 1)
  }

  Keys.onPressed: function(event) {
    // While renaming, the field has the keys; what it lets past goes nowhere.
    event.accepted = true
    if (root.renaming) return
    if (event.key === Qt.Key_Escape) { if (root.confirming) root.confirming = false; else root.dismissed() }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.confirming) root.confirmDelete()
      else root.startRenaming(root.cursor)
    }
    else if (event.key === Qt.Key_Down || event.text === "j") root.moveCursor(1)
    else if (event.key === Qt.Key_Up || event.text === "k") root.moveCursor(-1)
    else if (event.text === "J") root.move(root.cursor, 1)
    else if (event.text === "K") root.move(root.cursor, -1)
    else if (event.text === "x" || event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) root.askDelete(root.cursor)
    else if (event.text === "W") root.dismissed()
  }

  RowPointer {
    id: pointer
    // A view showing through its surface's close moves no cursor.
    onMoved: function(x, y) { if (root.active) root.pointAt(x, y) }
  }

  Item {
    id: title
    width: parent.width
    height: root.itemHeight

    Text {
      x: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "MANAGE LISTS"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    ListAction {
      view: root
      objectName: "manageDone"
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
    // The wheel scrolling the rows under a still pointer moves the cursor
    // to the row now under it; a key's scroll (showCursor) is no movement.
    onContentYChanged: if (root.active && moving && pointer.hovered) root.pointAt(pointer.scenePosition.x, pointer.scenePosition.y)

    Column {
      id: column
      width: scroll.width

      Repeater {
        model: root.choices

        Item {
          id: entry
          objectName: "manageRow"
          required property var modelData
          required property int index
          readonly property bool named: modelData.name !== ""
          readonly property bool isCursor: index === root.cursor
          readonly property bool editing: isCursor && root.renaming
          readonly property bool asking: isCursor && root.confirming
          readonly property bool showsActions: named && !editing && !asking && isCursor
          width: column.width
          height: root.itemHeight * (editing && root.problem !== "" ? 2 : 1)

          Rectangle {
            width: parent.width
            height: root.itemHeight
            radius: root.retro ? 0 : Style.cornerRadius
            color: entry.isCursor ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
            Behavior on color { ColorAnimation { duration: 60 } }
          }

          CursorBar {
            visible: entry.isCursor
            rowHeight: root.itemHeight
            retro: root.retro
            foreground: root.foreground
          }

          Text {
            visible: !entry.editing && !entry.asking
            x: Style.space(12)
            width: (entry.showsActions ? actions.x : count.x) - x - Style.space(12)
            height: root.itemHeight
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: entry.modelData.label
            color: entry.named ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Text {
            visible: !entry.named && entry.isCursor
            anchors.right: count.left
            anchors.rightMargin: Style.space(16)
            height: root.itemHeight
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: "THE LIBRARY"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          Row {
            id: actions
            visible: entry.showsActions
            anchors.right: count.left
            anchors.rightMargin: Style.space(16)
            height: root.itemHeight
            spacing: Style.space(14)

            ListAction {
              view: root
              objectName: "moveUp"
              anchors.verticalCenter: parent.verticalCenter
              text: "↑"
              opacity: entry.index > 1 ? 1 : 0.4
              onActivated: root.move(entry.index, -1)
            }
            ListAction {
              view: root
              objectName: "moveDown"
              anchors.verticalCenter: parent.verticalCenter
              text: "↓"
              opacity: entry.index < root.choices.length - 1 ? 1 : 0.4
              onActivated: root.move(entry.index, 1)
            }
            ListAction {
              view: root
              objectName: "renameAction"
              anchors.verticalCenter: parent.verticalCenter
              text: "RENAME"
              onActivated: root.startRenaming(entry.index)
            }
            ListAction {
              view: root
              objectName: "deleteAction"
              anchors.verticalCenter: parent.verticalCenter
              text: "DELETE"
              onActivated: root.askDelete(entry.index)
            }
          }

          Text {
            id: count
            visible: !entry.editing && !entry.asking
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            height: root.itemHeight
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: String(entry.modelData.count)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          // Delete asks here, in the row: the viewer has no dialogs.
          Text {
            visible: entry.asking
            x: Style.space(12)
            width: confirm.x - x - Style.space(12)
            height: root.itemHeight
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: "Delete " + entry.modelData.label + "? "
              + (entry.modelData.count === 0 ? "It is empty."
                : entry.modelData.count === 1 ? "Its symbol stays in All."
                : "Its " + entry.modelData.count + " symbols stay in All.")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          Row {
            id: confirm
            visible: entry.asking
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            height: root.itemHeight
            spacing: Style.space(14)

            ListAction {
              view: root
              objectName: "confirmDelete"
              anchors.verticalCenter: parent.verticalCenter
              text: "⏎ DELETE"
              strong: true
              onActivated: root.confirmDelete()
            }
            ListAction {
              view: root
              objectName: "keepList"
              anchors.verticalCenter: parent.verticalCenter
              text: "ESC KEEP"
              onActivated: root.confirming = false
            }
          }

          Text {
            visible: entry.editing && root.problem !== ""
            y: root.itemHeight
            x: Style.space(12)
            width: parent.width - x
            height: root.itemHeight
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            text: root.problem
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
      }
    }

    // One field, laid over whichever row is being renamed.
    TextField {
      id: nameField
      objectName: "renameField"
      visible: root.renaming
      x: Style.space(6)
      y: root.cursor * root.itemHeight
      width: parent.width - x
      height: root.itemHeight
      verticalPadding: 0
      foreground: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      onTextChanged: root.problem = ""
      // Enter is taken here, not on accepted: the press would go on to the
      // view, which by then has the keys back and would rename again.
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) { root.stopEditing(); event.accepted = true }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          event.accepted = true
          root.renameRequested(root.cursorChoice ? root.cursorChoice.name : "", text)
        }
      }
    }
  }

  // The key line follows the rows, and holds the bottom once they scroll.
  Item {
    id: keyLine
    y: Math.min(title.height + root.rowsHeight, root.height - height)
    width: parent.width
    height: root.itemHeight + Style.space(6)

    PanelSeparator {
      anchors.top: parent.top
      foreground: root.foreground
      strength: 0.08
    }

    // While a row asks to delete, the row says its keys, on the choices
    // themselves, as the shell's panels put a row's actions on the row; the
    // line says nothing, and keeps its place.
    Text {
      objectName: "keyHints"
      visible: !root.confirming
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Style.space(3)
      width: Math.min(implicitWidth, parent.width - Style.space(20))
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: root.renaming ? "⏎ save  ·  esc cancel"
        : "⏎ rename  ·  J K move  ·  x delete  ·  esc done"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
