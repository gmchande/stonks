import QtQuick
import QtTest
import Quickshell
import qs.Commons
import qs.Ui
import "plugin" as Stonks

// The README's pictures, through the real Service, popup (Panel.qml, its
// card in CardWindow.qml), window (App.qml), and pill (BarWidget.qml), on the
// demo watchlist at the saved moment readme.sh names. Each picture is
// grabbed into STONKS_README_RAW; readme.sh puts them together.
ShellRoot {
  id: harness

  property int failures: 0
  readonly property string rawDir: Quickshell.env("STONKS_README_RAW")
  readonly property var demo: ["AAPL", "PSIX", "SPY", "^GSPC", "BTC-USD", "SHEL.L", "7203.T"]
  readonly property var us: ["AAPL", "PSIX", "SPY"]

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
    console.log("README DONE")
    done.exitCode = failures ? 1 : 0
    done.start()
  }

  Stonks.Service { id: service }
  Stonks.Updates { id: updates }
  Stonks.TrendColors { id: colors }
  QtObject {
    id: shellApi
    function serviceFor(id) { return { service: service, trendColors: colors } }
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
  Stonks.App { id: app; service: service; updates: updates; trendColors: colors }

  // The pill on strips of bar: one in the bar's centre, as wide as the
  // popup's card, for the top picture; and each of its four forms.
  FloatingWindow {
    visible: true
    color: "transparent"
    implicitWidth: 560
    implicitHeight: 400

    Column {
      spacing: 24

      Rectangle {
        id: heroStrip
        width: panel.testCard.card.width
        height: Style.bar.sizeHorizontal
        color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 1)

        Stonks.BarWidget {
          anchors.centerIn: parent
          width: implicitWidth
          height: parent.height
          bar: barApi
          settings: ({ id: "grvc.stonks", barStyle: "sparkline" })
        }
      }

      Column {
        id: forms
        spacing: 8

        Repeater {
          model: ["sparkline", "arrow", "text", "icon"]

          Rectangle {
            required property string modelData
            width: 200
            height: Style.bar.sizeHorizontal
            color: heroStrip.color

            Stonks.BarWidget {
              anchors.centerIn: parent
              width: implicitWidth
              height: parent.height
              bar: barApi
              settings: ({ id: "grvc.stonks", barStyle: parent.modelData })
            }
          }
        }
      }
    }
  }
  PluginBarApi {
    id: barApi
    pluginId: "grvc.stonks"
    moduleName: "grvc.stonks"
    shell: shellApi
    foreground: Color.bar.text
    barForeground: Color.bar.text
    fontFamily: Style.font.family
    barSize: Style.bar.sizeHorizontal
  }

  TestCase {
    name: "Readme"
    when: service.pluginsReady

    function quiet() {
      tryVerify(function() {
        return harness.demo.every(function(s) { return !!service.quotes[s] })
          && service.arriving.length === 0 && service.testFeed.firstRun.length + service.testFeed.refreshRun.length === 0
      }, 15000, "every demo listing answered")
      harness.check("the theme's green is read", colors.green !== "", colors.green)
    }

    // Robinhood's word on the US listings, asked for once a surface opens:
    // whether each trades all day, and the prints of those that do.
    function robinhoodIn() {
      return harness.us.every(function(s) {
        var allDay = service.testAllDay.entries[s]
        var night = service.testOvernight.entries[s]
        return !!allDay && allDay.status === "ok" && (!allDay.allDay || (!!night && night.status === "ok"))
      })
    }

    // `body` at rest: its chart landed and drawn in whole, and the rule
    // beside the list's name on its shares, which ease when a scrub moves
    // the rows and freeze where they are while a list view covers them.
    function atRest(body) {
      var rule = harness.find(body, "breadthRule")
      var share = function(n) { return rule.total ? n / rule.total : 0 }
      return !body.chartLoading && body.motion.reveal === 1
        && Math.abs(rule.upShare - share(rule.breadth.up)) < 1e-6
        && Math.abs(rule.downShare - share(rule.breadth.down)) < 1e-6
    }

    // `item` as drawn now, into STONKS_README_RAW/<name>.png, once `body` is
    // at rest and `ready` holds.
    function grab(name, item, body, ready) {
      tryVerify(function() { return (!body || atRest(body)) && (!ready || ready()) }, 5000, name + " ready to grab")
      waitForRendering(item)
      var saved = false
      item.grabToImage(function(result) { saved = result.saveToFile(harness.rawDir + "/" + name + ".png") })
      tryVerify(function() { return saved }, 3000, "grab " + name)
      harness.check("grabbed " + name, saved)
    }

    function test_pictures() {
      quiet()
      harness.check("the demo watchlist, AAPL featured, on All and the day",
        service.symbols.join(",") === harness.demo.join(",") && service.featuredSymbol === "AAPL"
          && service.listName === "" && service.range === "1D", service.symbols.join(","))

      panel.open()
      var body = panel.testBody
      tryVerify(function() { return body.surfaceOpen }, 3000)
      grab("popup", panel.testCard.card, body, robinhoodIn)
      grab("strip", heroStrip)
      grab("forms", forms)

      // Scrubbed back into the afternoon, as a hover over the chart does.
      body.nudgeScrub(-84)
      grab("scrub", panel.testCard.card, body, function() { return body.motion.scrubT !== 0 })
      body.endScrub()
      tryVerify(function() { return atRest(body) }, 3000, "the rows back on now")

      body.openListMenu()
      grab("lists", panel.testCard.card, body, function() { return body.listMenuOpen })
      body.closeListMenu()
      panel.close()
      tryVerify(function() { return !body.surfaceOpen }, 3000)

      // Retro from a fresh open, so the header's colour and the look
      // button's cells, which ease on a switch, ease while it is closed,
      // before the open's draw-in starts.
      service.persist({ style: "retro" })
      panel.open()
      grab("retro", panel.testCard.card, body, function() { return service.retro && body.surfaceOpen })
      panel.close()
      service.persist({ style: "smooth" })
      tryVerify(function() { return !body.surfaceOpen && !service.retro }, 3000)

      app.open("{}")
      grab("window", app.testKeyCatcher, app.testBody, function() { return app.testBody.surfaceOpen })
      app.close()
      harness.finish()
    }
  }

  HarnessExit { id: done; interval: 100 }
}
