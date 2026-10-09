import QtQuick
import Quickshell.Io
import "Fetch.js" as Fetch
import "History.js" as History
import "Quote.js" as Quote
// The history for the one chart on show. One curl at a time, one retry of
// a bad answer, fifteen minutes of cache, last-good kept on failure. The
// service says which chart it wants; a newer want, or none, stops the curl
// and the retry of the old one at once, so nothing nobody is looking at
// delays the chart that is. While Yahoo's gate pauses the host, a request
// fails at once, so its view says unavailable rather than "Loading".
// `entries` holds answers only, "ok" or "failed": what is on its way is
// `wanted`, so asking for a chart changes nothing a reader of the answers
// sees until one lands.
Item {
  id: root

  property var entries: ({})
  property var gate: null
  // The gate's ticket the request out was let through on (`Gate.report`).
  property int ticket: 0
  // The chart wanted, { key, symbol, range }, until its answer is in; null
  // when none is.
  property var wanted: null
  // The request under way, launched and not yet answered: its curl or its
  // retry pause.
  property var job: null
  property int attempts: 0
  // The job's curl was stopped; its answer, whatever it says, is dropped.
  property bool stopped: false

  readonly property bool busy: job !== null || wanted !== null

  function keyFor(symbol, range) {
    return String(symbol || "").toUpperCase() + "|" + String(range || "")
  }

  function setEntry(key, values) {
    var next = Object.assign({}, entries)
    next[key] = Object.assign({ history: null, receivedAt: 0 }, entries[key], values)
    root.entries = next
  }

  // The chart on show. A cached answer under fifteen minutes old is enough
  // unless `force`, a user's refresh, asks for a new one.
  function request(symbol, range, force) {
    var normalizedSymbol = String(symbol || "").toUpperCase()
    if (!History.historyUrl(normalizedSymbol, range)) {
      root.clear()
      return
    }
    var key = keyFor(normalizedSymbol, range)
    if (wanted && wanted.key === key) return
    var cached = entries[key]
    var now = Math.floor(Date.now() / 1000)
    if (!force && cached && cached.status === "ok" && cached.receivedAt && now - cached.receivedAt < 15 * 60) {
      root.want(null)
      return
    }
    root.want({ key: key, symbol: normalizedSymbol, range: range })
  }

  // No chart on show needs history: the day.
  function clear() {
    root.want(null)
  }

  function want(next) {
    root.wanted = next
    if (job && (!next || next.key !== job.key)) {
      if (retryTimer.running || heldTimer.running) {
        retryTimer.stop()
        heldTimer.stop()
        root.endJob()
      } else if (!stopped) {
        // Its stream ends at once, empty, and receive drops it.
        root.stopped = true
        fetchProc.running = false
      }
      return
    }
    root.launch()
  }

  function launch() {
    if (job || !wanted) return
    root.job = wanted
    root.attempts = 0
    root.run()
  }

  // While the gate holds the host, the request fails a turn later: the
  // change that asked for it is still being told.
  function run() {
    if (gate && gate.take(1) === 0) {
      heldTimer.restart()
      return
    }
    if (gate) root.ticket = gate.ticket
    root.attempts = attempts + 1
    fetchProc.command = Fetch.curlCommand([History.historyUrl(job.symbol, job.range)], Fetch.HISTORY_CAP)
    fetchProc.running = true
  }

  // The job is over; then the chart wanted now, if any, goes.
  function endJob() {
    root.job = null
    root.attempts = 0
    root.stopped = false
    root.launch()
  }

  function receive(text) {
    var request = job
    var got = Fetch.answers(text)
    if (gate) gate.report(got.map(function(a) { return a.kind }), got.length ? got[0].retryAfter : 0, root.ticket)
    if (stopped || !wanted || wanted.key !== request.key) {
      root.endJob()
      return
    }

    var answer = got.length ? got[0] : null
    var history = null
    if (answer && answer.kind === "ok") {
      try { history = History.parseHistory(JSON.parse(answer.body), request.range) } catch (e) { history = null }
    }
    if (!history && attempts < 2 && answer && (answer.kind === "bad" || answer.kind === "ok")) {
      retryTimer.restart()
      return
    }
    root.settle(history)
  }

  // The job's answer: a history, or null for a failure.
  function settle(history) {
    var request = job
    // Answered, before the answer is told: a reader of `entries` may want
    // the next chart at once, and that want must outlast this one.
    root.wanted = null
    if (history) {
      var dropped = Quote.bucketTimes(history.droppedTimes)
      var previous = entries[request.key]
      var previousDropped = Quote.bucketTimes(previous && previous.history
        ? previous.history.droppedTimes : null)
      if (dropped && dropped !== previousDropped)
        console.warn("stonks: " + request.symbol + " " + request.range
          + " dropped stray buckets " + dropped)
      root.setEntry(request.key, {
        status: "ok",
        history: history,
        receivedAt: Math.floor(Date.now() / 1000)
      })
    } else {
      root.setEntry(request.key, { status: "failed" })
    }
    root.endJob()
  }

  Timer {
    id: retryTimer
    interval: 2500
    onTriggered: root.run()
  }

  Timer {
    id: heldTimer
    interval: 0
    onTriggered: root.settle(null)
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.receive(String(text || ""))
    }
  }
}
