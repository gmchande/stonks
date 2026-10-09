import QtQuick
import qs.Commons
import qs.Ui
import "Cells.js" as Cells
import "Tones.js" as Tones
// Sprite, live status, the look, and the help mark. Surfaces own the
// actions; this only draws and signals. The sprite is the retro look's; in
// smooth the status starts flush with the listing line. The height is the
// sprite's in both looks, and the look is one small icon in both, so
// toggling moves nothing.
Item {
  id: root

  property string statusText: ""
  property bool retro: false
  property bool bullish: true
  property bool spriteVisible: true
  property bool scrubbing: false
  property bool live: false
  // The surface is closing: the look icon's step stops where it is.
  property bool still: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property color upColor: Color.foreground
  property color downColor: Color.urgent
  property string fontFamily: Style.font.family
  property var sprite: Cells.spriteFor(bullish)

  signal styleRequested(string style)
  signal helpRequested()
  signal replayRequested()
  signal spriteCycled()

  // At rest as a surface opens: the icon on the look.
  function settle() { lookIcon.settle() }

  implicitHeight: Style.space(28)
  implicitWidth: parent ? parent.width : 0
  height: implicitHeight
  width: parent ? parent.width : implicitWidth

  PixelSprite {
    id: sprite
    objectName: "sprite"
    visible: root.spriteVisible
    width: Style.space(40)
    height: Style.space(28)
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    pixels: root.sprite
    color: root.bullish ? root.upColor : root.downColor
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.modifiers & Qt.ShiftModifier) root.spriteCycled()
        else root.replayRequested()
      }
    }
  }

  // Live is said by the chart's breathing dot and by these words in the
  // foreground; a mark in front of them would push them over each time it
  // came and went, with every range change and every scrub. In retro they
  // keep the sprite's place whether it is drawn or not, while a symbol's
  // first quote is out.
  Text {
    objectName: "statusText"
    anchors.left: root.retro ? sprite.right : parent.left
    anchors.leftMargin: root.retro ? Style.space(10) : 0
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

      PanelToolTip {
        objectName: "lookTip"
        visible: lookMouse.containsMouse
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
