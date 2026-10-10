import QtQuick
import QtTest
import Quickshell
import qs.Commons
import qs.Ui
import "plugin" as Stonks

// The popup's card edge in motion, judged on rendered frames (frames.js):
// the real Panel and Service with real Qt keys, the card in a plain window
// (CardWindow.qml) since the shell's layer-shell one does not load
// offscreen. Each change of what the card fits eases its edge there in the
// house 160 ms, the footer riding it whole and covering the rows it passes;
// an open from closed shows the fitted height from its first frame. HOME and
// curl are scratch fixtures.
ShellRoot {
  id: harness

  property int failures: 0
  property bool marked: false

  function check(label, ok, detail) {
    console.log((ok ? "PASS " : "FAIL ") + label + (!ok && detail !== undefined ? " — " + detail : ""))
    if (!ok) failures++
  }

  function find(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = find(item.children[i], name)
      if (found) return found
    }
    return null
  }

  function finish() {
    console.log("POPUP MOTION DONE")
    done.exitCode = failures ? 1 : 0
    done.start()
  }

  Stonks.Service { id: service }
  QtObject {
    id: shellApi
    function serviceFor(id) { return { service: service } }
  }
  PluginBarApi {
    id: api
    pluginId: "grvc.stonks"
    moduleName: "grvc.stonks"
    shell: shellApi
    foreground: Color.foreground
    fontFamily: Style.font.family
  }
  Stonks.Panel { id: panel; bar: api; settings: ({}) }
  FrameGrab { id: grab }

  TestCase {
    name: "PopupMotion"
    when: service.pluginsReady

    function quiet() {
      tryVerify(function() { return service.arriving.length === 0 && service.testFeed.firstRun.length + service.testFeed.refreshRun.length === 0 }, 8000)
    }

    function markOnce() {
      if (harness.marked) return
      harness.marked = true
      grab.markStart()
    }

    // The card's frames from a moment before `act` until its edge has long
    // rested, timed from the change of the height it fits (the mark), and
    // frames.js's verdict on them in `mode`.
    function frames(name, act, mode, args) {
      grab.source = panel.testCard.surface
      grab.begin(name)
      wait(100)
      harness.marked = false
      panel.fittedCardHeightChanged.connect(markOnce)
      act()
      wait(500)
      panel.fittedCardHeightChanged.disconnect(markOnce)
      return verdict(mode, args)
    }

    function verdict(mode, args) {
      grab.end()
      tryVerify(function() { return grab.waiting === 0 }, 5000)
      grab.judge(mode, null, args || [])
      tryVerify(function() { return grab.verdict !== null }, 10000)
      return grab.verdict
    }

    // The footer and the card's bottom inset: what rides the edge.
    function band() {
      return [String(find(panel.testBody, "footer").height + panel.testCard.card.contentBottomInset)]
    }

    function key(text) {
      panel.testKeyCatcher.forceActiveFocus()
      keyClick(text)
    }

    // An ease of the edge, from the frames, after `act`. Its line, pass or
    // fail, says what frames.js read: its curve, and on a failure the edge
    // frame by frame.
    function eases(label, act) {
      var verdict = frames(label.replace(/[^a-z0-9]+/gi, "-"), act, "edge", band())
      harness.check(label + (verdict.ok ? " — " + verdict.detail.replace(/^edge [^|]*\| /, "") : ""), verdict.ok, verdict.detail)
      wait(200)
    }

    function test_edge() {
      // All of six, a list of two, and an empty one.
      ["FLAT", "DOWN", "STRAY"].forEach(function(s) { service.addSymbol(s) })
      quiet()
      service.createList("Short")
      service.setMembership("AAPL", "Short", true)
      service.setMembership("MSFT", "Short", true)
      service.createList("Empty")
      service.switchList("")
      service.persist({ featured: "MSFT" })
      wait(100)

      // The card's window exists once it shows: its frames are grabbed from
      // the same turn as the open, before its first frame.
      panel.open()
      grab.source = panel.testCard.surface
      grab.begin("open")
      wait(500)
      var opened = verdict("edgeheld")
      harness.check("an open from closed shows the fitted height from its first frame", opened.ok, opened.detail)
      wait(300)

      eases("a switch to a shorter list eases the edge up, the footer riding it", function() { key(".") })
      eases("a switch to a longer list eases the edge down, the footer covering the rows it passes", function() { key(",") })

      // Found in design pass 3: as the key sheet closed and the card grew,
      // the footer's line and words drew through the rows.
      key("?")
      wait(400)
      eases("the key sheet closing eases the edge down, the footer covering the rows it passes", function() { key("?") })

      key(".")
      wait(400)
      eases("a removal from a short list eases the edge up", function() { key("x") })
      eases("its undo eases the edge down", function() { key("u") })
      eases("an add that lands eases the edge down", function() { panel.testBody.acceptSymbol("SPY") })
      quiet()
      eases("a membership change from another surface eases the edge down", function() {
        service.setMembership("NVDA", "Short", true)
      })

      // The menu, a popover, passes over the footer as the card grows under
      // it: only the edge is judged.
      key(".")
      wait(400)
      var menu = frames("menu", function() { key("w") }, "edge", ["0"])
      var menuOk = menu.ok && service.listName === "Empty"
      harness.check("the list menu on an empty list eases the edge down to room for it and the footer"
        + (menuOk ? " — " + menu.detail.replace(/^edge [^|]*\| /, "") : ""), menuOk, menu.detail)
      panel.testBody.closeListMenu()
      wait(300)

      // Search on the empty list: opening eases the edge down to its room,
      // the field standing at the top with nothing riding the edge; closing
      // eases it back, the footer riding it.
      var opening = frames("search-open", function() { key("a") }, "edge", ["0"])
      var openOk = opening.ok && panel.testBody.adding
      harness.check("search opening eases the edge down to its room"
        + (openOk ? " — " + opening.detail.replace(/^edge [^|]*\| /, "") : ""), openOk, opening.detail)
      wait(200)
      eases("search closing eases the edge back up, the footer riding it", function() { panel.testBody.cancelAdding() })
      panel.close()
      harness.finish()
    }
  }

  HarnessExit { id: done; interval: 100 }
}
