import QtQuick
// The pointer over a list of rows, said only when it really moves. Qt sends
// the hover again as rows scroll under a still pointer; that is no move, so
// a key gliding a list never hands its cursor back to the pointer.
HoverHandler {
  id: root

  // The pointer's last place in the scene, wherever it was.
  property point scenePosition: Qt.point(-1, -1)

  // The pointer moved to (x, y) in the scene: a list maps it to its own
  // rows, since a handler's own point may be read in a list's moving content.
  signal moved(real x, real y)

  onPointChanged: {
    var next = point.scenePosition
    var changed = next.x !== scenePosition.x || next.y !== scenePosition.y
    scenePosition = next
    if (hovered && changed) moved(next.x, next.y)
  }
}
