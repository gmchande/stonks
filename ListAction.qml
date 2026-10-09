import QtQuick
import qs.Commons

// A caption-sized word that acts, in the list views: DONE, RENAME, DELETE,
// the moves. It hovers the way the order control does. `view` is the list
// view it sits in, for the look and the colours.
Text {
  id: root

  property var view: null
  // The word the view's next Enter or Escape takes, drawn in the foreground.
  property bool strong: false

  signal activated()

  textFormat: Text.PlainText
  color: mouse.containsMouse || strong ? view.foreground : view.dim
  font.family: view.fontFamily
  font.pixelSize: Style.font.caption
  font.bold: true
  font.letterSpacing: 1

  Rectangle {
    z: -1
    anchors.centerIn: parent
    width: parent.implicitWidth + Style.space(12)
    height: parent.implicitHeight + Style.space(4)
    radius: root.view.retro ? 0 : Style.cornerRadius
    color: mouse.containsMouse ? Style.hoverFillFor(root.view.foreground, Color.accent) : "transparent"
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    anchors.margins: -Style.space(6)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
