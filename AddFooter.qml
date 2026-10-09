import QtQuick
import qs.Commons
import qs.Ui
import "Tones.js" as Tones

// Pinned "+ Add a symbol" bar. Surfaces own the add flow. For a moment it can
// carry a note instead, in the foreground, when a key was refused; until
// what it says is fixed, a notice, in the foreground too, under any note,
// whose click is the surface's (`acts`); or, quiet as the label, a hint for
// the visit. It is painted in its surface's ground, so riding a growing edge
// it covers the rows it passes.
Item {
  id: root

  property bool retro: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property string fontFamily: Style.font.family
  property int rowHeight: Style.space(30)
  property string note: ""
  property string notice: ""
  property string hint: ""
  // A click does something: the add, an undo, or the notice's own action.
  property bool acts: true
  property string label: "+  Add a symbol"
  property color ground: "transparent"

  signal clicked()

  implicitHeight: rowHeight + Style.space(6)
  height: implicitHeight

  Rectangle {
    anchors.fill: parent
    color: root.ground
  }

  PanelSeparator {
    anchors.top: parent.top
    foreground: root.foreground
    strength: 0.08
  }

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.space(6)
    radius: root.retro ? 0 : Style.cornerRadius
    color: root.acts && addMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"

    Text {
      objectName: "footerText"
      anchors.centerIn: parent
      width: Math.min(implicitWidth, parent.width - Style.space(20))
      elide: Text.ElideRight
      // The hint is longer than the popup is wide: it says its last part on
      // a second line, in the footer's height.
      horizontalAlignment: Text.AlignHCenter
      lineHeight: text.indexOf("\n") >= 0 ? 0.9 : 1
      textFormat: Text.PlainText
      text: root.note !== "" ? root.note : root.notice !== "" ? root.notice : root.hint !== "" ? root.hint : root.label
      color: root.note !== "" || root.notice !== "" ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: addMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: root.acts ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.clicked()
      // A double-click is one click: an undo, then not a search.
      onDoubleClicked: {}
    }
  }
}
