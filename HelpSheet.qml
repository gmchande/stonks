pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons
import qs.Ui
import "Tones.js" as Tones

// Shortcut sheet, in two columns on both surfaces: one column left half the
// window empty and pushed the last group below the fold. The two
// columns stack independently, groups in order, the first taking groups
// until it holds about half the lines, so a short group never sits beside a
// long one with a hole under it.
Flickable {
  id: root

  property var groups: []
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property string fontFamily: Style.font.family

  // How many groups the first column takes.
  readonly property int split: {
    var lines = function(group) { return group.rows.length + 1 }
    var total = 0
    for (var i = 0; i < groups.length; i++) total += lines(groups[i])
    var taken = 0
    for (var j = 0; j < groups.length; j++) {
      if (taken + lines(groups[j]) / 2 > total / 2) return Math.max(1, j)
      taken += lines(groups[j])
    }
    return groups.length
  }
  readonly property int columnWidth: (width - sheet.spacing) / 2

  contentWidth: width
  contentHeight: sheet.y + sheet.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  interactive: contentHeight > height

  Component {
    id: groupDelegate

    Column {
      id: group
      required property var modelData
      width: root.columnWidth
      spacing: Style.space(4)

      PanelSectionHeader {
        text: group.modelData.title
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: group.modelData.rows

        Row {
          id: helpRow
          required property var modelData
          width: group.width
          spacing: Style.space(10)

          Text {
            objectName: "helpKey"
            width: Style.space(48)
            textFormat: Text.PlainText
            text: helpRow.modelData.key
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
          Text {
            width: parent.width - Style.space(48) - parent.spacing
            textFormat: Text.PlainText
            text: helpRow.modelData.does
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  Row {
    id: sheet
    y: Style.space(4)
    spacing: Style.space(24)

    Repeater {
      model: [root.groups.slice(0, root.split), root.groups.slice(root.split)]

      Column {
        required property var modelData
        width: root.columnWidth
        spacing: Style.space(16)

        Repeater {
          model: parent.modelData
          delegate: groupDelegate
        }
      }
    }
  }
}
