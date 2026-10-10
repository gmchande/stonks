import QtQuick
import qs.Commons
// The bull or the bear in smooth's own hand, drawn the way the hero chart
// draws: one 1.5 px round line in the day's colour and the wash inside it.
// The same subjects as retro's cells (`Cells.js`): the bull's face with its
// horns, the bear walking toward now. Drawn on a 40 by 28 grid, the retro
// sprite's box, and scaled to the item.
Item {
  id: root

  property bool bull: true
  property color color: Color.foreground
  // The wash's alpha, as the hero's (`Tones.washAlpha`), so the bear's red
  // weighs the same as the bull's green.
  property real wash: 0.16

  implicitWidth: 40
  implicitHeight: 28

  onBullChanged: canvas.requestPaint()
  onColorChanged: canvas.requestPaint()
  onWashChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var s = Math.min(width / 40, height / 28)
      if (s <= 0) return
      ctx.save()
      ctx.translate((width - 40 * s) / 2, (height - 28 * s) / 2)
      ctx.scale(s, s)
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.lineWidth = 1.5 / s
      ctx.strokeStyle = root.color
      ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, root.wash)
      if (root.bull) bull(ctx)
      else bear(ctx)
      ctx.restore()
    }

    function dot(ctx, x, y, r) {
      ctx.beginPath()
      ctx.arc(x, y, r, 0, Math.PI * 2)
      ctx.fill()
    }

    // The bull's face, front on: a broad brow, horns sweeping out and up,
    // a long face narrowing to a soft muzzle and its two nostrils.
    function bull(ctx) {
      ctx.beginPath()
      ctx.moveTo(13.5, 8.5)
      ctx.quadraticCurveTo(20, 6.2, 26.5, 8.5)
      ctx.quadraticCurveTo(27.6, 13, 25.2, 17.2)
      ctx.quadraticCurveTo(27.2, 19.4, 26.2, 23)
      ctx.quadraticCurveTo(20, 27.4, 13.8, 23)
      ctx.quadraticCurveTo(12.8, 19.4, 14.8, 17.2)
      ctx.quadraticCurveTo(12.4, 13, 13.5, 8.5)
      ctx.closePath()
      ctx.fill()
      ctx.stroke()
      // The horns, from the brow's corners out and up.
      ctx.beginPath()
      ctx.moveTo(13.8, 10)
      ctx.quadraticCurveTo(5, 11.5, 3.5, 3)
      ctx.moveTo(26.2, 10)
      ctx.quadraticCurveTo(35, 11.5, 36.5, 3)
      ctx.stroke()
      // The ears, under the horns.
      ctx.beginPath()
      ctx.moveTo(13.6, 12.4)
      ctx.quadraticCurveTo(9.4, 13.8, 8.6, 12.6)
      ctx.moveTo(26.4, 12.4)
      ctx.quadraticCurveTo(30.6, 13.8, 31.4, 12.6)
      ctx.stroke()
      ctx.fillStyle = root.color
      dot(ctx, 17, 13.2, 1.15)
      dot(ctx, 23, 13.2, 1.15)
      dot(ctx, 17.6, 21.6, 0.95)
      dot(ctx, 22.4, 21.6, 0.95)
    }

    // The bear, walking as retro's does, toward the left: a shoulder hump,
    // a round ear, the head low, a short snout, four short legs. Drawn
    // facing right and turned.
    function bear(ctx) {
      ctx.translate(40, 0)
      ctx.scale(-1, 1)
      ctx.beginPath()
      ctx.moveTo(4, 15.4)
      // The back, rising to the hump over the shoulders.
      ctx.quadraticCurveTo(4.4, 9, 11, 8.6)
      ctx.quadraticCurveTo(18.4, 4.2, 23.8, 8.2)
      // The neck, the ear, the brow, and the snout.
      ctx.quadraticCurveTo(25, 9.2, 26.2, 8.6)
      ctx.quadraticCurveTo(25.8, 5.6, 28.2, 5.4)
      ctx.quadraticCurveTo(30.6, 5.4, 30.2, 7.8)
      ctx.quadraticCurveTo(32.6, 8.2, 33.8, 10.2)
      ctx.quadraticCurveTo(37.8, 10.8, 37.8, 12.8)
      ctx.quadraticCurveTo(37.4, 14.6, 33.6, 14.6)
      ctx.quadraticCurveTo(31.8, 16.6, 30.2, 17.4)
      // The front legs and the belly.
      ctx.lineTo(30.2, 24)
      ctx.lineTo(25.4, 24)
      ctx.lineTo(25.2, 19.8)
      ctx.quadraticCurveTo(18, 20.8, 13, 19.8)
      // The hind legs, and up the haunch.
      ctx.lineTo(12.6, 24)
      ctx.lineTo(7.6, 24)
      ctx.quadraticCurveTo(7.2, 20.8, 5.8, 19.8)
      ctx.quadraticCurveTo(3.6, 18, 4, 15.4)
      ctx.closePath()
      ctx.fill()
      ctx.stroke()
      ctx.fillStyle = root.color
      dot(ctx, 31.2, 10.6, 1.15)
      dot(ctx, 37.1, 12.2, 0.9)
    }
  }
}
