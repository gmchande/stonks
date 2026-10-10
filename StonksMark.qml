pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import "Cells.js" as Cells
// Stonks' mark in cells (`Cells.markLevels`), the pill's icon form: each
// column one bar at full ink from its cap down to the floor, so it reads
// beside the bar's glyphs where faint cells would scatter into dots. It
// climbs, or falls on a down day, so the shape says the direction without
// its colour.
Item {
  id: root
  property bool falling: false
  property color color: Color.foreground
  property int pixel: 2
  property int gap: 1
  readonly property int rows: 4
  readonly property var levels: Cells.markLevels(rows, falling)

  implicitWidth: levels.length * (pixel + gap) - gap
  implicitHeight: rows * (pixel + gap) - gap

  Repeater {
    model: root.levels.length

    Rectangle {
      objectName: "markCell"
      required property int index
      x: index * (root.pixel + root.gap)
      y: root.levels[index] * (root.pixel + root.gap)
      width: root.pixel
      height: root.height - y
      color: root.color
    }
  }
}
