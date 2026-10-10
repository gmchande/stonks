import QtQuick
import qs.Commons
import "Settings.js" as Settings
import "Tones.js" as Tones
// Hero, chart, range row, info block, and the list and order rule. Every piece keeps
// its height for every symbol, range, and look, so the list below never
// moves. Surfaces own scrub and persist.
Item {
  id: root

  property var freshness: null
  property bool retro: false
  property bool scrubbing: false
  property bool live: false
  // The surface is closing: what moves stops where it is.
  property bool still: false
  // The chart on show is held while the next one loads: its live mark holds
  // still with it.
  property bool held: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property color dimmer: Tones.dimmer(foreground, Color.background)
  property color upColor: Color.foreground
  property color downColor: Color.urgent
  property color ghost: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  // The surface under the chart, which the wash is seen against.
  property color ground: Color.background
  property string fontFamily: Style.font.family
  property string symbol: ""
  property var view: null
  property var quote: null
  property var calendars: null
  property var day: null
  property var latest: null
  property var geometry: null
  property real scrubX: -1
  // The draw-in's share of the ink, and a replay's place along the plot
  // (-1 without one), which each painter draws in behind.
  property real reveal: 1
  property real replayX: -1
  property int chartHeight: Style.space(190)
  property string order: "manual"
  property bool reversed: false
  property string listLabel: "All"
  property var breadth: ({ list: "", up: 0, flat: 0, down: 0, none: 0 })
  property bool listMenuOpen: false
  property bool replayRunning: false
  // Search or a list view covers the rows: the header names the
  // list they act on and says nothing about rows out of sight.
  property bool rowsCovered: false
  property var rangeOptions: []
  property string range: "1D"
  property string periodText: ""
  property string baselineText: ""
  property string keyStatsText: ""
  // The clock, by which the hero's overnight print is old.
  property int now: 0
  // Whether the hero's change is the day's, which a click cycles.
  property bool changeCycles: true
  readonly property alias chartItem: heroChart

  signal changeClicked()
  signal orderClicked()
  signal orderReverseClicked()
  signal listClicked()
  signal scrubRequested(real fraction)
  signal scrubCleared()
  signal slowReplayRequested()
  signal snapToNow()
  signal rangeRequested(string range)

  // At rest as a surface opens: the rule on the list's breadth.
  function settle() { breadthRule.settle() }

  implicitHeight: band.implicitHeight
  implicitWidth: parent ? parent.width : 0
  height: implicitHeight
  width: parent ? parent.width : implicitWidth

  Column {
    id: band
    width: parent.width
    spacing: Style.space(10)

    Hero {
      objectName: "hero"
      width: parent.width
      calendars: root.calendars
      symbol: root.symbol
      view: root.view
      quote: root.quote
      day: root.day
      latest: root.latest
      freshness: root.freshness
      retro: root.retro
      scrubbing: root.scrubbing
      now: root.now
      foreground: root.foreground
      dim: root.dim
      upColor: root.upColor
      downColor: root.downColor
      ghost: root.ghost
      fontFamily: root.fontFamily
      baselineText: root.baselineText
      changeCycles: root.changeCycles
      onChangeClicked: root.changeClicked()
    }

    Item {
      id: heroChart
      width: parent.width
      height: root.chartHeight

      DayChart {
        id: dayChart
        visible: !root.retro
        anchors.fill: parent
        // The hidden look rests: it draws nothing until it shows, so a new
        // chart paints once, in the look on screen.
        geometry: root.retro ? null : root.geometry
        up: root.view ? root.view.dayUp : true
        upColor: root.upColor
        downColor: root.downColor
        baselineColor: root.dimmer
        hairlineColor: root.foreground
        ground: root.ground
        // The hidden look rests: it neither draws in nor follows the scrub.
        scrubX: root.retro ? -1 : root.scrubX
        reveal: root.retro ? 1 : root.reveal
        replayX: root.retro ? -1 : root.replayX
        live: root.live && !root.retro
        still: root.still || root.held
      }

      PixelChart {
        visible: root.retro
        anchors.fill: parent
        geometry: root.retro ? root.geometry : null
        upColor: root.upColor
        downColor: root.downColor
        up: root.view ? root.view.dayUp : true
        baselineColor: root.dimmer
        glow: true
        live: root.live && root.retro
        still: root.still || root.held
        hairlineColor: root.foreground
        ghostColor: root.ghost
        ground: root.ground
        scrubX: root.retro ? root.scrubX : -1
        reveal: root.retro ? root.reveal : 1
        replayX: root.retro ? root.replayX : -1
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        // The pointer reads the chart where it is drawn, so its right edge
        // reaches the last print, alone after a quiet hour too.
        onPositionChanged: function(mouse) {
          if (!root.replayRunning) root.scrubRequested(root.retro ? mouse.x / width : dayChart.fractionAt(mouse.x))
        }
        onExited: if (!root.replayRunning) root.scrubCleared()
        onClicked: function(mouse) {
          if (mouse.modifiers & Qt.ShiftModifier) root.slowReplayRequested()
          else root.snapToNow()
        }
      }
    }

    // The range row and the info lines it chooses are one group, 8 px apart;
    // the list's header stands 16 px under them (the group's padding and the
    // band's spacing) and 6 px over its rows (the body's `listGap`), so it
    // groups with the rows it titles. The total is the 30 px it always was.
    Column {
      width: parent.width
      spacing: Style.space(8)
      bottomPadding: Style.space(6)

      RangeSelector {
        objectName: "rangeRow"
        width: parent.width
        options: root.rangeOptions
        value: root.range
        retro: root.retro
        foreground: root.foreground
        dim: root.dim
        fontFamily: root.fontFamily
        onSelected: function(value) { root.rangeRequested(value) }
      }

      // The period and the key stats: two lines that are always there, so
      // the list keeps its place for every symbol and range.
      Column {
        objectName: "infoBlock"
        width: parent.width
        spacing: Style.space(4)

        // A day that reaches its 52-week high or low says so in that
        // direction's colour; the rest of the line stays dim.
        Text {
          objectName: "periodLine"
          width: parent.width
          textFormat: Text.StyledText
          text: root.periodText.replace("52W HIGH", "<font color=\"" + root.upColor + "\">52W HIGH</font>")
            .replace("52W LOW", "<font color=\"" + root.downColor + "\">52W LOW</font>")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          elide: Text.ElideRight
          wrapMode: Text.NoWrap
        }

        Text {
          objectName: "keyStatsLine"
          width: parent.width
          textFormat: Text.PlainText
          text: root.keyStatsText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          elide: Text.ElideRight
          wrapMode: Text.NoWrap
        }
      }
    }

    // The list's name, a menu, at the left of the rule, as Apple puts it at
    // the top of the list; the order control at the right. The name starts
    // at the rows' text, and the order word ends at the figures it ranks,
    // the rows' inset plus the scrollbar's gutter. Its height is the caption
    // line's, never a word's: a glyph drawn from another font is taller, and
    // would move the rows. A line of text rounds its ascent and its descent
    // up to whole pixels each, and so does this.
    Item {
      width: parent.width
      height: Math.ceil(captionLine.ascent) + Math.ceil(captionLine.descent)

      FontMetrics {
        id: captionLine
        font: orderText.font
      }

      Rectangle {
        objectName: "listControl"
        anchors.left: listText.left
        anchors.leftMargin: -Style.space(6)
        anchors.right: listChevron.right
        anchors.rightMargin: -Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height + Style.space(4)
        radius: root.retro ? 0 : Style.cornerRadius
        color: root.listMenuOpen ? Style.selectedFillFor(root.foreground, Color.accent)
          : listMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }

      Text {
        id: listText
        objectName: "listLabel"
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width - orderText.implicitWidth - todayText.implicitWidth - Style.space(80))
        textFormat: Text.PlainText
        text: root.listLabel.toUpperCase()
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
        elide: Text.ElideRight
      }

      Text {
        id: listChevron
        anchors.left: listText.right
        anchors.leftMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅀"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      MouseArea {
        id: listMouse
        anchors.left: listText.left
        anchors.right: listChevron.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: -Style.space(6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.listClicked()
      }

      // The rows and the rule are the day's on every range, and say so while
      // the rows show.
      Text {
        id: todayText
        objectName: "todayLabel"
        visible: !root.rowsCovered
        anchors.left: listChevron.right
        anchors.leftMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "TODAY"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
      }

      // The rule between the name and the order is the list's breadth. It
      // rests while the rows are covered and settles as they show again.
      BreadthRule {
        id: breadthRule
        objectName: "breadthRule"
        visible: !root.rowsCovered
        anchors.left: todayText.right
        anchors.leftMargin: Style.space(10)
        anchors.right: orderText.left
        anchors.rightMargin: Style.space(10)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        breadth: root.breadth
        retro: root.retro
        still: root.still || root.rowsCovered
        foreground: root.foreground
        dim: root.dim
        upColor: root.upColor
        downColor: root.downColor
        fontFamily: root.fontFamily
      }

      // The order control hovers the way a range token does: the fill and
      // the brighter word, so it reads as a control and not a label.
      Rectangle {
        objectName: "orderControl"
        visible: !root.rowsCovered
        anchors.centerIn: orderText
        width: orderText.implicitWidth + Style.space(12)
        height: parent.height + Style.space(4)
        radius: root.retro ? 0 : Style.cornerRadius
        color: orderMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
        Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }

      Text {
        id: orderText
        objectName: "orderLabel"
        visible: !root.rowsCovered
        anchors.right: parent.right
        anchors.rightMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: Settings.orderLabel(root.order, root.reversed)
        // A sorted order is bright and manual dim, at once with the word; only
        // the hover's brightening eases.
        property real lift: orderMouse.containsMouse ? 1 : 0
        Behavior on lift { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        color: root.order !== "manual" ? root.foreground
          : Qt.tint(root.dim, Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, lift))
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1

        MouseArea {
          id: orderMouse
          anchors.fill: parent
          anchors.margins: -Style.space(6)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) {
            if (mouse.modifiers & Qt.ShiftModifier) root.orderReverseClicked()
            else root.orderClicked()
          }
        }
      }
    }
  }
}
