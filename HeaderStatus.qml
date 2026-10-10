import QtQuick
import qs.Commons
import qs.Ui
import "Cells.js" as Cells
import "Tones.js" as Tones
// The animal, live status, the look, and the help mark. Surfaces own the
// actions; this only draws and signals. The animal is the day's bull or
// bear in both looks, retro's in cells and smooth's drawn, in one slot the
// status words start after, drawn or not, so neither the look nor a flat
// day moves them. The height is the slot's in both looks, and the look is
// one small icon in both, so toggling moves nothing.
Item {
  id: root

  property string statusText: ""
  property bool retro: false
  // The animal, as the body decides it: `kind` "bull", "bear", or "" (a
  // flat day, or no direction yet), and `chart`, what it reads. A turn of
  // the same chart crossfades in smooth; any other change is at once.
  property var animal: ({ kind: "", chart: "" })
  property bool scrubbing: false
  property bool live: false
  // The surface is closing: the look icon's step and the animal's turn stop
  // where they are.
  property bool still: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property color upColor: Color.foreground
  property color downColor: Color.urgent
  property color ground: Color.background
  property string fontFamily: Style.font.family

  readonly property string kind: animal ? animal.kind : ""
  // The chart the animal last showed, by which a change is a turn.
  property string shownChart: ""

  signal styleRequested(string style)
  signal helpRequested()
  signal replayRequested()

  // At rest as a surface opens: the icon on the look, the animal on what
  // it reads.
  function settle() {
    lookIcon.settle()
    show(false)
  }

  // Smooth's layers to the animal: crossfading when it turns on the chart
  // it showed, from wherever a turn under way has them; else at once.
  function show(fade) {
    var k = animal ? animal.kind : ""
    shownChart = animal ? animal.chart : ""
    turn.stop()
    turnBull.to = k === "bull" ? 1 : 0
    turnBear.to = k === "bear" ? 1 : 0
    if (fade) turn.start()
    else {
      bull.opacity = turnBull.to
      bear.opacity = turnBear.to
    }
  }

  Component.onCompleted: settle()
  // While still, nothing moves: a change waits for the open's `settle`.
  onAnimalChanged: if (!still) show(animal.chart === shownChart)
  onStillChanged: if (still && turn.running) turn.pause()

  implicitHeight: Style.space(28)
  implicitWidth: parent ? parent.width : 0
  height: implicitHeight
  width: parent ? parent.width : implicitWidth

  Item {
    id: slot
    objectName: "animal"
    width: Style.space(40)
    height: Style.space(28)
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter

    PixelSprite {
      objectName: "sprite"
      anchors.fill: parent
      visible: root.retro && root.kind !== ""
      pixels: Cells.spriteFor(root.kind === "bull")
      color: root.kind === "bull" ? root.upColor : root.downColor
    }

    // Smooth's pair, one layer each, so a turn crossfades between them.
    DrawnAnimal {
      id: bull
      objectName: "drawnBull"
      anchors.fill: parent
      visible: !root.retro && opacity > 0
      bull: true
      color: root.upColor
      wash: Tones.washAlpha(root.upColor, root.upColor, root.ground, 0.16, 1)
    }
    DrawnAnimal {
      id: bear
      objectName: "drawnBear"
      anchors.fill: parent
      visible: !root.retro && opacity > 0
      bull: false
      color: root.downColor
      wash: Tones.washAlpha(root.downColor, root.upColor, root.ground, 0.16, 1)
    }

    ParallelAnimation {
      id: turn
      NumberAnimation { id: turnBull; target: bull; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
      NumberAnimation { id: turnBear; target: bear; property: "opacity"; duration: 160; easing.type: Easing.OutCubic }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.kind !== ""
      cursorShape: Qt.PointingHandCursor
      onClicked: root.replayRequested()
    }
  }

  // Live is said by the chart's breathing dot and by these words in the
  // foreground; a mark in front of them would push them over each time it
  // came and went, with every range change and every scrub.
  Text {
    objectName: "statusText"
    anchors.left: slot.right
    anchors.leftMargin: Style.space(10)
    anchors.right: lookIcon.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: root.statusText.toUpperCase()
    color: root.scrubbing || root.live ? root.foreground : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
    elide: Text.ElideRight
  }

  // The look a click switches to, as s does, about a word tall: the chart
  // already shows the current one. The target is the header's full height,
  // so a click above or below the icon still lands.
  LookIcon {
    id: lookIcon
    objectName: "lookIcon"
    anchors.right: helpMark.left
    anchors.rightMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    retro: root.retro
    still: root.still
    color: lookMouse.containsMouse ? root.foreground : root.dim

    MouseArea {
      id: lookMouse
      objectName: "lookToggle"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width + Style.space(12)
      height: root.height
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.styleRequested(root.retro ? "smooth" : "retro")

      // Under the header, its right edge on the header's: inside the card,
      // which the shell's place above the icon crossed.
      PanelToolTip {
        objectName: "lookTip"
        visible: lookMouse.containsMouse
        x: root.width - lookIcon.x - lookMouse.x - width
        y: lookMouse.height + Style.space(4)
        text: root.retro ? "Switch to smooth (s)" : "Switch to retro (s)"
        fontFamily: root.fontFamily
      }
    }
  }

  Text {
    id: helpMark
    objectName: "helpMark"
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: "?"
    color: helpMouse.containsMouse ? root.foreground : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
    MouseArea {
      id: helpMouse
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(Style.space(24), parent.width + Style.space(12))
      height: root.height
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.helpRequested()
    }
  }
}
