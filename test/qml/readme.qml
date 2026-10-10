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

  function check(label, ok, detail) {
    console.log((ok ? "PASS " : "FAIL ") + label + (!ok && detail !== undefined ? " — " + detail : ""))
    if (!ok) failures++
  }

  function finish() {
    console.log("README DONE")
    done.exitCode = failures ? 1 : 0
    done.start()
  }

  Stonks.Service { id: service }
  Stonks.Updates { id: updates }
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
  Stonks.App { id: app; service: service; updates: updates }

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
    }

    // `item` as drawn now, into STONKS_README_RAW/<name>.png, once the chart
    // has finished drawing in.
    function grab(name, item) {
      wait(900)
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
      grab("popup", panel.testCard.card)
      grab("strip", heroStrip)
      grab("forms", forms)

      // Scrubbed back into the afternoon, as a hover over the chart does.
      body.nudgeScrub(-84)
      grab("scrub", panel.testCard.card)
      body.endScrub()

      body.openListMenu()
      tryVerify(function() { return body.listMenuOpen }, 3000)
      grab("lists", panel.testCard.card)
      body.closeListMenu()

      service.persist({ style: "retro" })
      wait(100)
      grab("retro", panel.testCard.card)
      service.persist({ style: "smooth" })
      panel.close()
      wait(300)

      app.open("{}")
      tryVerify(function() { return app.testBody.surfaceOpen }, 3000)
      grab("window", app.testKeyCatcher)
      app.close()
      harness.finish()
    }
  }

  Timer {
    interval: 60000
    running: true
    onTriggered: {
      console.log("FAIL Readme harness timed out")
      done.exitCode = 1
      done.start()
    }
  }

  Timer {
    id: done
    property int exitCode: 0
    interval: 100
    onTriggered: Qt.exit(exitCode)
  }
}
