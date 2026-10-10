import QtQuick
// The pointer over a list of rows, said only when it really moves within
// them. The first place the pointer is seen at, as it comes in or as the
// view opens or shows again under a resting pointer, is where it starts,
// no move: Qt's first hover there says nothing about a hand, so the cursor
// stays where the view put it. And Qt sends the hover again as rows scroll
// under a still pointer; that is no move either, so a key gliding a list
// never hands its cursor back to the pointer.
HoverHandler {
  id: root

  // The pointer's last place in the scene, wherever it was.
  property point scenePosition: Qt.point(-1, -1)
  // Whether the pointer was already here at its last place.
  property bool within: false
  // Set as the view opens or shows again (rest). When the pointer is first
  // seen near where this handler last saw it, it never moved: it rests
  // there until it leaves that place by the drag distance, Qt's own measure
  // of a hand that means to move. Qt and the compositor can report a
  // resting pointer again as the view comes back, a pixel or so off. A
  // pointer first seen anywhere else has moved, and starts there as usual.
  property bool resting: false
  property point restPlace: Qt.point(-1, -1)

  // The pointer moved to (x, y) in the scene: a list maps it to its own
  // rows, since a handler's own point may be read in a list's moving content.
  signal moved(real x, real y)

  function rest() {
    resting = true
    within = false
  }

  function nearTo(a, b) {
    var near = Application.styleHints.startDragDistance
    return Math.abs(a.x - b.x) <= near && Math.abs(a.y - b.y) <= near
  }

  onPointChanged: {
    var next = point.scenePosition
    if (resting && hovered) {
      if (!within) {
        if (nearTo(next, scenePosition)) restPlace = next
        else resting = false
      }
      if (resting && nearTo(next, restPlace)) {
        scenePosition = next
        within = true
        return
      }
      resting = false
    }
    var changed = within && (next.x !== scenePosition.x || next.y !== scenePosition.y)
    scenePosition = next
    within = hovered
    if (hovered && changed) moved(next.x, next.y)
  }
  onHoveredChanged: if (!hovered) within = false
}
