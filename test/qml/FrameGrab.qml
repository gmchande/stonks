import QtQuick
import Quickshell
import Quickshell.Io

// Grabs `source`'s rendered frames, one on every frame while running, into
// $STONKS_FRAMES as PPM, and has frames.js judge them. A grab alone keeps
// the source's transparency, and not always in the same format, so while
// grabbing the source has its window's colour laid under it: what is on
// screen stays the same, and every frame is the picture as it shows. Each
// frame is asked for, and timed, as its window's animations have just
// advanced (afterAnimating), so its picture is that moment's: a grab asked
// for from a FrameAnimation shows the next tick, a frame interval later
// than its time, and load stretches that interval. Times are ms since
// `start`, which a harness sets as its motion starts (`markStart`). A
// harness copies this beside its shell.qml (`frame_tools`, lib.sh).
Item {
  id: grabber

  property Item source: null
  property string name: ""
  property real start: 0
  property var frames: []
  property int waiting: 0
  property var verdict: null
  property Item ground: null

  // Starts a run of frames named `runName`, timed from now until marked.
  function begin(runName) {
    if (ground) ground.destroy()
    ground = Qt.createQmlObject('import QtQuick; Rectangle { anchors.fill: parent; z: -1000 }', source)
    ground.color = source.Window.window.color
    name = runName
    frames = []
    verdict = null
    start = Date.now()
    ticker.running = true
  }

  function markStart() { start = Date.now() }

  function end() { ticker.running = false }
  function resume() { ticker.running = true }

  // One frame: this moment's picture, as the window's animations have just
  // set it.
  function shot() {
    var path = Quickshell.env("STONKS_FRAMES") + "/" + name + "-" + String(frames.length).padStart(3, "0") + ".ppm"
    var frame = { path: path, at: Date.now() }
    frames.push(frame)
    waiting++
    source.grabToImage(function(result) {
      result.saveToFile(path)
      grabber.waiting--
    })
  }

  // The frames rendered before the start was marked.
  function framesBefore() {
    return frames.filter(function(frame) { return frame.at < grabber.start })
  }

  // Asks frames.js for its verdict on `judged` (every frame by default), in
  // `mode` (drawin, same, edge, or edgeheld) with the mode's own `args`
  // (edge's band). The run is over: the ground goes. A verdict always comes
  // within 9 s, a failing one if frames.js gave none, so a harness waiting
  // 10 s for it never reads null.
  function judge(mode, judged, args) {
    verdict = null
    if (ground) ground.destroy()
    ground = null
    judgeProc.command = ["bun", Quickshell.env("STONKS_FRAME_CHECK"), mode].concat(args || []).concat((judged || frames).map(function(frame) {
      return frame.path + "@" + Math.round(frame.at - grabber.start)
    }))
    judgeProc.running = true
    noVerdict.restart()
  }

  Timer {
    id: noVerdict
    interval: 9000
    onTriggered: if (grabber.verdict === null) grabber.verdict = { ok: false, detail: "no verdict from frames.js in 9 s" }
  }

  // Asks the window for a frame on every tick while grabbing, still
  // pictures too, so every tick has its afterAnimating.
  FrameAnimation {
    id: ticker
    running: false
    onTriggered: grabber.source.Window.window.update()
  }

  Connections {
    target: ticker.running ? grabber.source.Window.window : null
    function onAfterAnimating() { grabber.shot() }
  }

  Process {
    id: judgeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { grabber.verdict = JSON.parse(String(text || "").trim()) }
        catch (e) { grabber.verdict = { ok: false, detail: "no verdict: " + text } }
      }
    }
  }
}
