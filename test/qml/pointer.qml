import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons
import "plugin/Cells.js" as Cells
import "plugin/Chart.js" as Chart
import "plugin/Quote.js" as Quote
import "plugin/Settings.js" as Settings
import "plugin"

// StonksBody under a real offscreen pointer and wheel, on a stub surface:
// the cases real data cannot set up. Nothing is mapped into the running shell.
ShellRoot {
  id: root

  property int failures: 0

  FileView {
    id: watchlistFixture
    path: Quickshell.env("STONKS_WATCHLIST_FIXTURE")
    blockLoading: true
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

  function findAll(item, name, into) {
    var out = into || []
    if (!item) return out
    if (item.objectName === name) out.push(item)
    for (var i = 0; i < item.children.length; i++) findAll(item.children[i], name, out)
    return out
  }

  function check(label, ok, detail) {
    console.log((ok ? "PASS " : "FAIL ") + label + (!ok && detail !== undefined ? " — " + detail : ""))
    if (!ok) failures++
  }

  // What the header's animal slot draws, in the look shown: retro's cells,
  // or smooth's drawn layer alone at full ink; "" for nothing at all.
  function animalShows(kind) {
    var sprite = find(body, "sprite")
    var bull = find(body, "drawnBull")
    var bear = find(body, "drawnBear")
    if (stub.retro) return !bull.visible && !bear.visible && (kind === "" ? !sprite.visible
      : sprite.visible && JSON.stringify(sprite.pixels) === JSON.stringify(Cells.spriteFor(kind === "bull"))
        && Qt.colorEqual(sprite.color, kind === "bull" ? stub.upColor : stub.downColor))
    return !sprite.visible && (kind === "bull" ? bull.visible && bull.opacity === 1 && !bear.visible
      : kind === "bear" ? bear.visible && bear.opacity === 1 && !bull.visible
      : !bull.visible && !bear.visible)
  }

  function quote(symbol, price, previous) {
    return {
      symbol: symbol,
      name: "Sample " + symbol,
      currency: "USD",
      exchange: "NASDAQ",
      timezoneName: "America/New_York",
      gmtoffset: -14400,
      instrumentType: "EQUITY",
      crypto: false,
      price: price,
      prevClose: previous,
      marketTime: stub.now,
      dayHigh: Math.max(price, previous) + 1,
      dayLow: Math.min(price, previous) - 1,
      volume: 100,
      session: {
        pre: { start: stub.now - 25200, end: stub.now - 19800 },
        regular: { start: stub.now - 19800, end: stub.now + 3600 },
        post: { start: stub.now + 3600, end: stub.now + 18000 }
      },
      points: [
        { t: stub.now - 19800, p: previous },
        { t: stub.now - 300, p: price }
      ]
    }
  }

  function symbols(count) {
    var result = []
    for (var i = 0; i < count; i++) result.push("S" + String(i).padStart(2, "0"))
    return result
  }

  function setQuotes(symbols, values) {
    var nextQuotes = {}
    var nextEntries = {}
    for (var i = 0; i < symbols.length; i++) {
      nextQuotes[symbols[i]] = root.quote(symbols[i], values[i], 100)
      nextEntries[symbols[i]] = { status: "ok", receivedAt: stub.now }
    }
    stub.symbols = symbols.slice()
    stub.quotes = nextQuotes
    stub.entries = nextEntries
    stub.shown = Settings.sortedSymbols(stub.symbols, stub.quotes, stub.order)
    stub.featuredSymbol = symbols[0]
  }

  function setFixtureWatchlist() {
    var fixture = JSON.parse(watchlistFixture.text())
    var nextSymbols = []
    var nextQuotes = {}
    var nextEntries = {}
    for (var i = 0; i < fixture.quotes.length; i++) {
      var item = fixture.quotes[i]
      var parsed = item.response ? Quote.parseChart(item.response) : null
      var symbol = parsed ? parsed.symbol : item.symbol
      nextSymbols.push(symbol)
      if (parsed) nextQuotes[symbol] = parsed
      nextEntries[symbol] = { status: item.status, receivedAt: item.status === "ok" ? fixture.now : 0 }
    }
    stub.now = fixture.now
    stub.order = "manual"
    stub.symbols = nextSymbols
    stub.quotes = nextQuotes
    stub.entries = nextEntries
    stub.shown = nextSymbols.slice()
    stub.featuredSymbol = "MU"
  }

  QtObject {
    id: stub
    property var symbols: []
    property var shown: []
    property var library: symbols
    property string listName: ""
    property var lists: [{ name: "", label: "All", count: symbols.length, symbols: symbols }]
    property var quotes: ({})
    property var entries: ({})
    property var calendars: null
    property string featuredSymbol: ""
    property string order: "pct"
    property bool reversed: false
    property string changeMode: "pct"
    property int now: 1789669200
    property var asked: ({})
    property string range: "1D"
    property var histories: ({})
    property var fundamentals: ({})
    property var arriving: []
    property var lastRemoval: null
    readonly property var view: ({ featured: featuredSymbol, range: range, list: listName, listKey: "=" + listName,
      order: order, reversed: reversed, rows: symbols.filter(function(s) { return arriving.indexOf(s) < 0 }),
      shown: shown.filter(function(s) { return arriving.indexOf(s) < 0 }), library: library,
      chart: Chart.viewChart(featuredSymbol, range, quotes, entries, histories) })
    property bool retro: false
    property color foreground: "#cacccc"
    property color upColor: "#7aa2f7"
    property color downColor: "#a55555"
    property string fontFamily: "CaskaydiaMono Nerd Font"
    property var lastSettings: null
    function persist(values) { lastSettings = values }
    function setRange(value) { range = value }
    function surfaceShown(surface, open) {}
    // A search's choice shown on the hero; this stub's hero never changes.
    readonly property var previewView: view
    readonly property var previewEntries: ({})
    property var previewSurface: null
    function preview(surface, symbol) {}
    function feature(symbol) { featuredSymbol = symbol }
    function removeSymbol(symbol) {
      var next = symbols.filter(function(value) { return value !== symbol })
      symbols = next
      shown = Settings.sortedSymbols(next, quotes, order)
      if (featuredSymbol === symbol) featuredSymbol = next[0] || ""
      lastRemoval = { symbol: symbol }
    }
    property string undone: ""
    function undoRemoval(symbol) {
      undone = symbol
      lastRemoval = null
    }
    function setManualOrder(next) { symbols = next.slice(); shown = next.slice(); order = "manual" }
    function addSymbol(symbol) {
      var upper = String(symbol || "").toUpperCase()
      var next = symbols.slice()
      if (next.indexOf(upper) < 0) {
        next.push(upper)
        arriving = arriving.concat([upper])
      }
      symbols = next
      shown = Settings.sortedSymbols(next, quotes, order)
    }
    function setOrder(value) { order = value; lastSettings = { order: value } }
    property var memberships: []
    function setMembership(symbol, name, member) { memberships = memberships.concat([symbol + "|" + name + "|" + member]) }
    function switchList(name) {}
    function stepList(delta) {}
    function createList(name) { return "" }
  }

  DayChart { id: directionlessSmooth; visible: false; up: null; baselineColor: "#667788" }
  PixelChart { id: directionlessRetro; visible: false; up: null; baselineColor: "#667788" }
  // The body's rendered frames, for frames.js.
  FrameGrab { id: grab }

  FloatingWindow {
    id: window
    visible: true
    color: "#101315"
    implicitWidth: 480
    implicitHeight: 760

    StonksBody {
      id: body
      anchors.fill: parent
      anchors.margins: Style.space(16)
      service: stub
      foreground: stub.foreground
      upColor: stub.upColor
      downColor: stub.downColor
      fontFamily: stub.fontFamily
      surfaceOpen: true
      chartHeight: Style.space(190)
      rangeOptions: ["1D", "1Y"]
    }

    // A pill on this window, which maps offscreen, and the popup card's held
    // anchor on it: the one place the anchor finds a real bar window.
    Row {
      Item { width: 200; height: 1 }
      Item { id: pillStandIn; width: 150; height: 30 }
    }
    HeldAnchor {
      id: heldAnchor
      pill: pillStandIn
    }
    // The body's rendered frames, for frames.js.
    FrameGrab { id: grab }

    TestCase {
      name: "Pointer"
      when: window.visible

      // Waits up to ms for fn to hold and returns whether it does.
      function within(ms, fn) {
        for (var t = 0; t < ms && !fn(); t += 20) wait(20)
        return fn()
      }

      function test_owner_flows() {
        root.check("unknown chart direction is neutral in both looks",
          directionlessSmooth.aboveColor === directionlessSmooth.baselineColor
            && directionlessSmooth.belowColor === directionlessSmooth.baselineColor
            && directionlessRetro.aboveColor === directionlessRetro.baselineColor
            && directionlessRetro.belowColor === directionlessRetro.baselineColor)
        // The featured symbol is up while the list is net down.
        root.setQuotes(["UP", "DOWN", "DEEP"], [110, 95, 90])

        // The header's animal, in both looks: the featured day's, whatever
        // the click. A Shift-click replays the chart as a click does, and
        // never forces a bull or a bear over the day's direction.
        ;[true, false].forEach(function(retro) {
          stub.retro = retro
          var look = retro ? "retro" : "smooth"
          wait(50)
          root.check("featured direction beats a down watchlist in " + look + "'s animal",
            body.animal.kind === "bull" && within(500, function() { return root.animalShows("bull") }))
          var clicks = []
          for (var shiftClick = 0; shiftClick < 3; shiftClick++) {
            mouseClick(body, 20, 14, Qt.LeftButton, Qt.ShiftModifier)
            var replayed = body.motion.replayRunning
            // The replay reads the day from its start; at rest it is the day's.
            body.motion.stopReplay()
            body.motion.scrubT = 0
            wait(50)
            clicks.push(body.animal.kind + " " + replayed)
          }
          root.check(look + "'s animal: a Shift-click replays the chart and leaves the day's bull",
            clicks.join(",") === "bull true,bull true,bull true" && within(500, function() { return root.animalShows("bull") }),
            clicks.join(","))
        })

        var rangeRow = root.find(body, "rangeRow")
        var tokens = root.findAll(rangeRow, "rangeToken")
        var second = tokens[1].mapToItem(body, tokens[1].width / 2, tokens[1].height / 2)
        mouseMove(body, second.x, second.y)
        // Past the 160ms fill animation, so the colour is the settled one.
        wait(260)
        root.check("a range token under the pointer takes the hover fill",
          Qt.colorEqual(tokens[1].color, Style.hoverFillFor(stub.foreground, Color.accent))
            && Qt.colorEqual(tokens[0].color, Style.selectedFillFor(stub.foreground, Color.accent)))
        mouseMove(body, body.width / 2, body.height - 4)
        wait(260)
        root.check("the token lets go when the pointer leaves",
          Qt.colorEqual(tokens[1].color, "transparent"))

        // The wheel over a token walks the ranges, the way it does between
        // them: a notch down is the next, longer range. The pointer rests on
        // the token first, the way a hand reaches for it, so the token's
        // hover area is live when the wheel arrives.
        var first = tokens[0].mapToItem(body, tokens[0].width / 2, tokens[0].height / 2)
        mouseMove(body, first.x, first.y)
        wait(200)
        mouseWheel(body, first.x, first.y, 0, -120, Qt.NoModifier)
        wait(50)
        root.check("a wheel notch down over a hovered range token steps to the next range", body.range === "1Y")
        mouseWheel(body, first.x, first.y, 0, 120, Qt.NoModifier)
        wait(50)
        root.check("a wheel notch up over a hovered range token steps back", body.range === "1D")
        mouseMove(body, body.width / 2, body.height - 4)
        wait(50)

        // The header's marks are as easy to hit as the row they sit in.
        var helpMark = root.find(body, "helpMark")
        var beside = helpMark.mapToItem(body, helpMark.width + 8, helpMark.height / 2)
        mouseClick(body, beside.x, beside.y)
        wait(50)
        root.check("a click beside the help mark opens the sheet", body.showingHelp)
        mouseClick(body, beside.x, beside.y)
        wait(50)
        root.check("and closes it again", !body.showingHelp)
        // The look icon shows the look a click switches to, as a button shows
        // what pressing it does: cells (Stonks' mark) in smooth, the curve in
        // retro, stepping column by column as the look changes. A click on it,
        // or under it, as the header's full height is the target, switches
        // the look, and hovering says what a click does.
        var icon = root.find(body, "lookIcon")
        var toggle = root.find(body, "lookToggle")
        var tip = toggle.data.filter(function(o) { return o.objectName === "lookTip" })[0]
        var cellsShown = function() { return root.findAll(icon, "markCell").filter(function(c) { return c.parent.visible }).length }
        var onIcon = icon.mapToItem(body, icon.width / 2, icon.height / 2)
        var underIcon = toggle.mapToItem(body, toggle.width / 2, toggle.height - 2)
        mouseMove(body, onIcon.x, onIcon.y)
        wait(50)
        var smoothShown = cellsShown() + " " + (tip ? tip.text : "")
        stub.lastSettings = null
        mouseClick(body, underIcon.x, underIcon.y)
        wait(50)
        var picked = stub.lastSettings ? stub.lastSettings.style : ""
        var steps = []
        var watchSteps = function() { steps.push(icon.cellColumns) }
        icon.cellColumnsChanged.connect(watchSteps)
        stub.retro = true
        for (var stepWait = 0; stepWait < 2000 && icon.cellColumns !== 0; stepWait += 50) wait(50)
        icon.cellColumnsChanged.disconnect(watchSteps)
        var retroShown = cellsShown() + " " + (tip ? tip.text : "")
        stub.lastSettings = null
        mouseClick(body, onIcon.x, onIcon.y)
        wait(50)
        var back = stub.lastSettings ? stub.lastSettings.style : ""
        stub.retro = false
        for (stepWait = 0; stepWait < 2000 && icon.cellColumns !== 5; stepWait += 50) wait(50)
        root.check("the look icon shows the look a click switches to, steps between cells and curve, says so, and a click on or under it switches",
          smoothShown === "5 Switch to retro (s)" && picked === "retro" && steps.length >= 3
            && retroShown === "0 Switch to smooth (s)" && back === "smooth" && cellsShown() === 5,
          smoothShown + " | " + picked + " | " + steps.join(",") + " | " + retroShown + " | " + back + " | " + cellsShown())
        mouseMove(body, body.width / 2, body.height - 4)
        wait(50)

        // The axis runs to the bell, an hour off; the fixture's last print is
        // five minutes old.
        var lastPrint = stub.now - 300
        root.check("the day's axis runs past its last print", body.motion.dayGeometry.end > lastPrint)
        body.motion.scrubTo(1)
        root.check("hover scrubbing stops at the last print", body.scrubT === lastPrint)
        body.nudgeScrub(50)
        root.check("key scrubbing stops at the last print", body.scrubT === lastPrint)
        // Watch the whole sweep: its furthest moment is the last print, and
        // it reaches it rather than stopping short.
        body.motion.scrubT = 0
        body.replay(false)
        var furthest = 0
        var sampled = 0
        while (body.motion.replayRunning && sampled < 80) {
          furthest = Math.max(furthest, body.scrubT)
          wait(40)
          sampled++
        }
        root.check("replay sweeps as far as the last print and no further",
          sampled > 10 && !body.motion.replayRunning && furthest <= lastPrint && furthest > lastPrint - 600)
        body.motion.stopReplay()
        body.motion.scrubT = 0

        // The bull and bear agree with the moment shown: a day that traded
        // above its close in the morning and closed below it is a bull while
        // the scrub reads the morning, and a bear at rest.
        var restFeatured = stub.featuredSymbol
        var open = stub.now - 19800
        var swing = root.quote("SWING", 95, 100)
        swing.points = [{ t: open, p: 104 }, { t: open + 10800, p: 96 }, { t: stub.now - 300, p: 95 }]
        stub.quotes = Object.assign({}, stub.quotes, { SWING: swing })
        stub.entries = Object.assign({}, stub.entries, { SWING: { status: "ok", receivedAt: stub.now } })
        stub.featuredSymbol = "SWING"
        // Scrub the way the owner does, with the pointer over the chart.
        var span = Chart.chartGeometry(swing).end - Chart.chartGeometry(swing).start
        var legend = root.find(body, "baselineLegend")
        ;[true, false].forEach(function(retro) {
          stub.retro = retro
          var look = retro ? "retro" : "smooth"
          wait(50)
          var chart = body.chartItem
          var xAt = function(t) { return chart.width * (t - Chart.chartGeometry(swing).start) / span }
          root.check(look + ": at rest a day that closed down draws the bear",
            within(500, function() { return root.animalShows("bear") }))
          mouseMove(chart, xAt(open + 600), chart.height / 2)
          root.check(look + ": the pointer on a morning above the close draws the bull",
            within(500, function() { return root.animalShows("bull") }))
          // While a scrub reads the price against the dashed line, the strip
          // under the price names it.
          root.check(look + ": a scrub names the dashed line under the price",
            !!legend && legend.visible && legend.text === "┄ PREV CLOSE 100.00")
          mouseMove(chart, xAt(open + 10800 + 600), chart.height / 2)
          root.check(look + ": the pointer on an afternoon below the close draws the bear again",
            within(500, function() { return root.animalShows("bear") }))
          mouseMove(body, body.width / 2, 20)
          wait(50)
          root.check(look + ": the name leaves with the scrub", !!legend && !legend.visible && body.scrubT === 0)
        })

        // A flat day, a change that rounds to nothing, has no sign, neither
        // colour, and no animal, in either look. Found on BLDP at 0.00%:
        // retro drew a green bull.
        var flat = root.quote("FLAT", 100.001, 100)
        flat.points = [{ t: open, p: 100.4 }, { t: stub.now - 300, p: 100.001 }]
        stub.quotes = Object.assign({}, stub.quotes, { FLAT: flat })
        stub.entries = Object.assign({}, stub.entries, { FLAT: { status: "ok", receivedAt: stub.now } })
        stub.featuredSymbol = "FLAT"
        ;[true, false].forEach(function(retro) {
          stub.retro = retro
          wait(50)
          root.check((retro ? "retro" : "smooth") + ": a flat day draws no animal",
            body.featured.tone === "flat" && body.animal.kind === "" && root.animalShows(""), body.featured.changeText)
        })
        stub.retro = false

        // A range whose first fetch failed shows the day in its place; the
        // retry that lands is another chart, so the animal changes at once.
        // Found in review: the up day's bull crossfaded into the range's bear.
        stub.featuredSymbol = "UP"
        stub.range = "1Y"
        stub.histories = { "UP|1Y": { history: null } }
        root.check("a failed range's stand-in day draws its bull",
          body.chart.failed && within(500, function() { return root.animalShows("bull") }))
        stub.histories = { "UP|1Y": { history: { symbol: "UP", range: "1Y", baseline: 120, interval: "1d", gmtoffset: -14400, bars: [
          { t: stub.now - 86400, c: 120, h: 121, l: 119, o: 120, v: 100 },
          { t: stub.now, c: 110, h: 111, l: 109, o: 110, v: 100 }
        ] } } }
        root.check("a failed range's retry that lands down draws the bear at once, no crossfade",
          !body.chart.failed && root.animalShows("bear"), body.animal.kind + " " + root.find(body, "drawnBear").opacity)
        stub.range = "1D"
        stub.histories = {}
        stub.featuredSymbol = restFeatured
        wait(50)

        var held = body.watchlist.displayedSymbols.join(",")
        mouseMove(body.watchlist, 12, 12)
        wait(50)
        root.setQuotes(["UP", "DOWN", "DEEP"], [90, 95, 120])
        wait(50)
        root.check("quote arrival records the newest sort while rows stay put",
          stub.shown.join(",") === "DEEP,DOWN,UP"
            && body.watchlist.displayedSymbols.join(",") === held)
        mouseMove(body, body.width / 2, 20)
        wait(200)
        root.check("leaving applies the newest sort once",
          !body.watchlist.sortHeld && body.watchlist.displayedSymbols.join(",") === "DEEP,DOWN,UP")

        // A closing surface holds the order on screen too: the pointer leaving
        // as the card fades re-sorts nothing, and the next open lays the rows
        // out in the newest order at once, in smooth and in retro. Found in
        // the review of the transitions branch: the rows moved during the
        // close fade once the pointer left them.
        var closingHolds = function(values, retro) {
          stub.retro = retro
          mouseMove(body.watchlist, 12, 12)
          wait(50)
          var onScreen = body.watchlist.displayedSymbols.join(",")
          root.setQuotes(["UP", "DOWN", "DEEP"], values)
          wait(50)
          body.surfaceOpen = false
          mouseMove(body, body.width / 2, 20)
          wait(200)
          var kept = body.watchlist.displayedSymbols.join(",") === onScreen && onScreen !== stub.shown.join(",")
          body.resetInteraction()
          body.surfaceOpen = true
          var laidOut = body.watchlist.displayedSymbols.join(",") === stub.shown.join(",")
            && body.watchlist.displayedSymbols.every(function(s) { return body.watchlist.rowItem(s).resting })
          return kept + "," + laidOut + " " + onScreen + " -> " + body.watchlist.displayedSymbols.join(",")
        }
        var smoothClose = closingHolds([120, 95, 90], false)
        var retroClose = closingHolds([90, 95, 120], true)
        stub.retro = false
        wait(50)
        root.check("a closing surface holds the rows' order as the pointer leaves, and the next open lays them out at once",
          /^true,true /.test(smoothClose) && /^true,true /.test(retroClose), smoothClose + " | " + retroClose)
        // So does a list chosen on another surface as this one closes: the
        // rows stay as they were, and the next open shows the new list from
        // its top. Found in cubic's review of #26.
        var allRows = stub.symbols.slice()
        var shownRows = body.watchlist.displayedSymbols.join(",")
        body.surfaceOpen = false
        stub.listName = "Other"
        stub.symbols = ["DEEP"]
        stub.shown = ["DEEP"]
        wait(100)
        var keptRows = body.watchlist.displayedSymbols.join(",") === shownRows
        body.resetInteraction()
        body.surfaceOpen = true
        var otherList = body.watchlist.displayedSymbols.join(",") === "DEEP" && body.watchlist.contentY === 0
        // An empty list chosen so says nothing over the rows it keeps.
        var emptyList = root.find(body, "emptyList")
        body.surfaceOpen = false
        stub.listName = "Empty"
        stub.symbols = []
        stub.shown = []
        wait(100)
        var quiet = !emptyList.visible && body.watchlist.displayedSymbols.join(",") === "DEEP"
        body.resetInteraction()
        body.surfaceOpen = true
        var saysEmpty = emptyList.visible && body.watchlist.displayedSymbols.length === 0
        stub.listName = ""
        stub.symbols = allRows
        stub.shown = Settings.sortedSymbols(allRows, stub.quotes, stub.order)
        wait(100)
        root.check("a list chosen elsewhere as the surface closes changes no row until the next open, which starts it from the top; an empty one says so only then",
          keptRows && otherList && quiet && saysEmpty,
          [keptRows, otherList, quiet, saysEmpty].join("|") + " " + shownRows + " -> " + body.watchlist.displayedSymbols.join(","))

        var fifteen = root.symbols(15)
        var values = []
        for (var i = 0; i < fifteen.length; i++) values.push(100 + i)
        stub.order = "pct"
        root.setQuotes(fifteen, values)
        wait(100)

        // `x` with the pointer on a row removes that row: the pointer put the
        // cursor there. (A middle-click used to remove it; it removes nothing
        // now.)
        body.watchlist.contentY = 0
        mouseMove(body.watchlist, 12, body.watchlist.rowPitch + 12)
        wait(50)
        var removed = body.watchlist.displayedSymbols[1]
        mouseClick(body.watchlist, 12, body.watchlist.rowPitch + 12, Qt.MiddleButton)
        var middleKept = body.watchlist.displayedSymbols.indexOf(removed) === 1
        body.removeRow(body.watchlist.cursorRow)
        wait(200)
        var contiguous = true
        for (i = 0; i < body.watchlist.displayedSymbols.length; i++) {
          var row = body.watchlist.rowItem(body.watchlist.displayedSymbols[i])
          if (!row || Math.abs(row.y - i * body.watchlist.rowPitch) > 0.5) contiguous = false
        }
        root.check("a middle-click on a row removes nothing, and x on the pointer's row removes it without a hole",
          middleKept && body.watchlist.sortHeld && body.watchlist.displayedSymbols.indexOf(removed) < 0
            && body.watchlist.rowItem(removed) === null && contiguous
            && body.watchlist.displayedSymbols.length === 14)

        // Before its first answer the new symbol is not in the list at all:
        // not drawn, not counted in the scroll, and not a key's target.
        // Found in the code-quality review: it showed as "Loading…" at the
        // end, then vanished and faded in again at its sorted place.
        var newAt = []
        var watchNew = function() { newAt.push(body.watchlist.displayedSymbols.indexOf("NEW")) }
        body.watchlist.displayedSymbolsChanged.connect(watchNew)
        var extent = body.watchlist.contentHeight
        body.search.picked("NEW")
        wait(20)
        body.watchlist.displayedSymbolsChanged.disconnect(watchNew)
        root.check("a pointer-held add stays out of the list until its first answer",
          body.watchlist.sortHeld && body.watchlist.displayedSymbols.length === 14
            && body.watchlist.contentHeight === extent && body.shown.indexOf("NEW") < 0
            && newAt.every(function(at) { return at < 0 }),
          body.watchlist.displayedSymbols.length + "|" + newAt.join(","))
        // Its first answer lands, as the service's fetch would bring it, up
        // 100%, which sorts it first. With the pointer still over the rows it
        // joins there, is selected there, and stays when the pointer leaves.
        // Found in motion pass 3 review: it was selected at the bottom, then
        // slid up once the pointer left.
        tryVerify(function() { return body.watchlist.rowItem("NEW") !== null }, 1000)
        var addedRow = body.watchlist.rowItem("NEW")
        var addedSlid = 0
        var watchAdded = function() { addedSlid = Math.max(addedSlid, Math.abs(addedRow.shift)) }
        addedRow.shiftChanged.connect(watchAdded)
        var joins = 0
        var watchJoin = function() { if (addedRow.opacity === 0) joins++ }
        addedRow.opacityChanged.connect(watchJoin)
        stub.quotes = Object.assign({}, stub.quotes, { NEW: root.quote("NEW", 200, 100) })
        stub.entries = Object.assign({}, stub.entries, { NEW: { status: "ok", receivedAt: stub.now } })
        stub.shown = Settings.sortedSymbols(stub.symbols, stub.quotes, stub.order)
        stub.arriving = []
        wait(100)
        var landedAt = body.watchlist.displayedSymbols.indexOf("NEW")
        root.check("pointer-held sorted add joins at its sorted place, selected and in view",
          body.watchlist.sortHeld && landedAt === stub.shown.indexOf("NEW") && landedAt < 14
            && addedSlid === 0 && joins === 1 && body.watchlist.cursorSymbol === "NEW"
            && addedRow.y >= body.watchlist.contentY
            && addedRow.y + addedRow.height <= body.watchlist.contentY + body.watchlist.height)

        // Scrolled by hand with NEW still whole in sight, so it keeps the
        // cursor of its own.
        body.watchlist.contentY = addedRow.y
        var userScroll = body.watchlist.contentY
        stub.quotes = Object.assign({}, stub.quotes)
        stub.shown = Settings.sortedSymbols(stub.symbols, stub.quotes, stub.order)
        wait(100)
        root.check("a quote refresh does not repeat add selection or scrolling",
          body.watchlist.cursorSymbol === "NEW"
            && Math.abs(body.watchlist.contentY - userScroll) < 0.5)
        mouseMove(body.watchlist, 24, body.watchlist.rowPitch + 12)
        wait(50)
        var pointedRow = body.watchlist.displayedSymbols[Math.floor((body.watchlist.rowPitch + 12 + body.watchlist.contentY) / body.watchlist.rowPitch)]
        root.check("real pointer movement takes the cursor from the added row to the row under the pointer",
          pointedRow !== "NEW" && body.watchlist.cursorSymbol === pointedRow, pointedRow + "|" + body.watchlist.cursorSymbol)
        mouseMove(body, body.width / 2, 20)
        wait(200)
        addedRow.shiftChanged.disconnect(watchAdded)
        addedRow.opacityChanged.disconnect(watchJoin)
        root.check("and the added row stays there once the pointer leaves",
          !body.watchlist.sortHeld && body.watchlist.displayedSymbols.indexOf("NEW") === landedAt && addedSlid === 0)

        root.setFixtureWatchlist()
        wait(100)
        var fixtureOrder = body.watchlist.displayedSymbols.join(",")
        var scrollBar = body.watchlist.ScrollBar.vertical
        wait(2200)
        root.check("the overflow scrollbar stays visible at rest",
          scrollBar.visible && scrollBar.active && scrollBar.opacity > 0)
        body.watchlist.contentY = 0
        var wheelRow = body.watchlist.rowItem(body.watchlist.displayedSymbols[2])
        mouseWheel(wheelRow, wheelRow.width / 2, wheelRow.height / 2,
          0, -120, Qt.NoModifier)
        wait(500)
        var afterOne = body.watchlist.contentY
        mouseWheel(wheelRow, wheelRow.width / 2, wheelRow.height / 2,
          0, -120, Qt.NoModifier)
        wait(500)
        root.check("each wheel notch over a row moves one whole row",
          afterOne === body.watchlist.rowPitch && body.watchlist.contentY === body.watchlist.rowPitch * 2)

        // A high-resolution wheel sends many small ticks per notch. Each
        // moves its fraction of a row, and the list settles on a boundary
        // once they stop, not on every tick.
        var pitch = body.watchlist.rowPitch
        body.watchlist.contentY = 0
        wait(50)
        mouseWheel(wheelRow, wheelRow.width / 2, wheelRow.height / 2,
          0, -30, Qt.NoModifier)
        wait(200)
        root.check("a high-resolution tick moves its fraction of a row",
          Math.abs(body.watchlist.contentY - pitch / 4) < 1
            && body.watchlist.contentY % pitch !== 0)
        wait(400)
        root.check("the list settles on a row boundary once the wheel is quiet",
          body.watchlist.contentY % pitch === 0)
        body.watchlist.contentY = 0
        wait(50)
        for (var tick = 0; tick < 4; tick++) {
          mouseWheel(wheelRow, wheelRow.width / 2, wheelRow.height / 2,
            0, -30, Qt.NoModifier)
          wait(30)
        }
        wait(600)
        root.check("four high-resolution ticks add up to one row",
          body.watchlist.contentY === pitch)
        root.check("wheel scrolling does not reorder rows", body.watchlist.displayedSymbols.join(",") === fixtureOrder)

        // A row lifted mid-glide takes the list over: neither the glide nor
        // the wheel's pending settle moves the list under it.
        body.watchlist.wheelBy(0.3)
        wait(40)
        var lifted = body.watchlist.displayedSymbols[2]
        body.watchlist.beginDrag(lifted, 2 * pitch + 10)
        var heldAt = body.watchlist.contentY
        wait(500)
        root.check("lifting a row stops the wheel's glide and its settle",
          body.watchlist.dragSymbol === lifted && body.watchlist.contentY === heldAt)
        body.watchlist.cancelDrag()
        body.watchlist.snapToRow()

        // A held row keeps the cursor while the wheel scrolls the list under
        // it, and once it drops: it rides the pointer wherever its old place
        // went. From the rows review: the cursor left it as soon as its old
        // place scrolled out of sight, and the next key acted on another row.
        body.watchlist.contentY = 0
        wait(50)
        var held = body.watchlist.displayedSymbols[1]
        body.watchlist.beginDrag(held, pitch + 10)
        mouseWheel(body.watchlist, 12, pitch + 10, 0, -600, Qt.NoModifier)
        wait(700)
        var heldScrolled = [body.watchlist.cursorRow === held, body.watchlist.contentY >= 4 * pitch].join(",")
        body.watchlist.endDrag()
        wait(400)
        root.check("a held row keeps the cursor while the wheel scrolls the list under it, and once it drops",
          heldScrolled === "true,true" && body.watchlist.dragSymbol === "" && body.watchlist.cursorRow === held,
          heldScrolled + " | " + body.watchlist.cursorRow + " for " + held)
        root.setFixtureWatchlist()
        wait(100)

        // The keyboard cursor always has a row: with none of its own it sits
        // on the featured row, in sight at the top, and it is drawn as a bar,
        // not as a fill.
        body.watchlist.contentY = 0
        body.watchlist.cursorSymbol = ""
        mouseMove(body, body.width / 2, 20)
        wait(200)
        var featuredRow = body.watchlist.rowItem("MU")
        var cursorBar = root.find(featuredRow, "cursorBar")
        root.check("with no cursor of its own the list's cursor rests on the featured row",
          body.watchlist.cursorRow === "MU" && cursorBar && cursorBar.visible)
        var otherRow = body.watchlist.rowItem(body.watchlist.displayedSymbols[1])
        root.check("the cursor, the featured fill, and a plain row look different",
          !root.find(otherRow, "cursorBar").visible
            && !Qt.colorEqual(otherRow.color, featuredRow.color))
        body.watchlist.moveCursor(1)
        wait(50)
        root.check("the first Down moves the cursor off the featured row",
          body.watchlist.cursorRow === body.watchlist.displayedSymbols[1]
            && root.find(otherRow, "cursorBar").visible && !cursorBar.visible)

        // One cursor, as the shell's own panels have it: the pointer puts it
        // on the row under it; a wheel notch with the pointer still leaves
        // it, once the glide rests, on the row then under the pointer, never
        // the first row in sight; ↓ moves it on from there; the pointer
        // leaving the list leaves it. Only the cursor's row takes the hover
        // fill and the bar, and the featured row keeps its selected fill.
        // From the owner's trial: the pointer cleared the cursor, so the bar
        // went to the featured row, and after the wheel to the first row in
        // sight, wherever the pointer was; a hovered row only tinted, at 4%.
        var wl = body.watchlist
        var hoverFill = Style.hoverFillFor(stub.foreground, Color.accent)
        var selectedFill = Style.selectedFillFor(stub.foreground, Color.accent)
        // The rows whose fill or bar says something other than their state.
        var misdrawn = function() {
          var wrong = []
          wl.displayedSymbols.forEach(function(symbol) {
            var item = wl.rowItem(symbol)
            var want = symbol === stub.featuredSymbol ? selectedFill : symbol === wl.cursorRow ? hoverFill : "transparent"
            if (!Qt.colorEqual(item.color, want)) wrong.push(symbol + " fill " + item.color)
            if (root.find(item, "cursorBar").visible !== (symbol === wl.cursorRow)) wrong.push(symbol + " bar")
          })
          return wrong
        }
        wl.contentY = 0
        wait(50)
        var third = wl.rowItem(wl.displayedSymbols[2])
        mouseMove(third, third.width / 2, third.height / 2)
        wait(100)
        var onThird = [wl.cursorRow === wl.displayedSymbols[2]].concat(misdrawn())
        mouseWheel(third, third.width / 2, third.height / 2, 0, -120, Qt.NoModifier)
        // At once, before the glide: the row that will rest under the pointer.
        var atOnce = wl.cursorRow === wl.displayedSymbols[3] && wl.contentY < pitch
        wait(700)
        var afterWheel = [atOnce, wl.contentY === pitch, wl.cursorRow === wl.displayedSymbols[3], wl.cursorRow !== wl.displayedSymbols[1]].concat(misdrawn())
        body.moveCursor(1)
        wait(100)
        var afterDown = [wl.cursorRow === wl.displayedSymbols[4]].concat(misdrawn())
        mouseMove(body, body.width / 2, 20)
        wait(100)
        var afterLeaving = [wl.cursorRow === wl.displayedSymbols[4]].concat(misdrawn())
        var steps = [onThird, afterWheel, afterDown, afterLeaving]
        root.check("one cursor: the pointer puts it on row 3, the wheel on the row under the still pointer once it rests, ↓ one row on, and leaving keeps it; no other row is tinted",
          steps.every(function(step) { return step.every(function(part) { return part === true }) }),
          steps.map(function(step) { return step.join(",") }).join(" | "))

        // The cursor's fill keeps up with the pointer at the shell's own
        // 60 ms: on rendered frames, the rows change as the pointer moves a
        // row down and are still from 80 ms on. It eased in 160 ms.
        var listBand = function() {
          var corner = wl.mapToItem(body, 0, 0)
          return [Math.round(corner.x), Math.round(corner.y), Math.round(wl.width), Math.round(wl.height)].join(",")
        }
        var fillFrom = wl.rowItem(wl.displayedSymbols[2])
        mouseMove(fillFrom, fillFrom.width / 2, fillFrom.height / 2)
        wait(200)
        grab.source = body
        grab.begin("cursor-fill")
        wait(50)
        grab.markStart()
        mouseMove(fillFrom, fillFrom.width / 2, fillFrom.height / 2 + pitch)
        wait(250)
        grab.end()
        var fillRow = wl.cursorRow
        grab.judge("same:" + listBand(), grab.frames.filter(function(frame) { return frame.at >= grab.start }))
        tryVerify(function() { return grab.verdict !== null }, 10000)
        var fillMoved = grab.verdict
        grab.judge("same:" + listBand(), grab.frames.filter(function(frame) { return frame.at >= grab.start + 80 }))
        tryVerify(function() { return grab.verdict !== null }, 10000)
        var fillStill = grab.verdict
        root.check("the cursor's fill follows the pointer to the next row, and is still 80 ms on",
          fillRow === wl.displayedSymbols[3] && !fillMoved.ok && fillStill.ok,
          fillRow + " | " + fillMoved.detail + " | " + fillStill.detail)

        // The list menu's edge is drawn over its ground, so the rows' cursor
        // never shows through it. Found in the first-run design review: the
        // bar of the cursor's row under the open menu showed as a bright
        // stroke on its left edge. Judged on rendered frames, inside the
        // menu between its rounded corners: the cursor moving from a row
        // under the menu to one below it changes nothing there.
        mouseMove(body, body.width / 2, 20)
        wl.contentY = 0
        body.openListMenu()
        wait(100)
        var listMenu = root.find(body, "listMenu")
        var corner = Math.ceil(Style.cornerRadius)
        var menuTop = Math.round(listMenu.y) + corner
        var menuBottom = Math.round(listMenu.y + listMenu.height) - corner
        var underMenu = ""
        var belowMenu = ""
        wl.displayedSymbols.forEach(function(symbol, index) {
          var top = wl.rowItem(symbol).mapToItem(body, 0, 0).y
          if (underMenu === "" && top + Style.space(6) >= menuTop && top + wl.rowHeight - Style.space(6) <= menuBottom) underMenu = symbol
          if (belowMenu === "" && top >= listMenu.y + listMenu.height && wl.wholeInSight(index, wl.contentY)) belowMenu = symbol
        })
        wl.cursorSymbol = underMenu
        wait(100)
        grab.begin("menu-edge")
        wait(100)
        wl.cursorSymbol = belowMenu
        wait(150)
        grab.end()
        var movedBelow = wl.cursorRow === belowMenu
        grab.judge("same:" + [Math.round(listMenu.x), menuTop, Math.round(listMenu.width), menuBottom - menuTop].join(","))
        tryVerify(function() { return grab.verdict !== null }, 10000)
        root.check("the rows' cursor never shows through the list menu's edge",
          underMenu !== "" && belowMenu !== "" && movedBelow && grab.verdict.ok,
          underMenu + " -> " + belowMenu + " | " + movedBelow + " | " + grab.verdict.detail)
        body.closeListMenu()
        wait(100)

        // A touchpad's pixels move the list exactly and settle through the
        // same glide as the wheel.
        body.watchlist.contentY = 0
        wait(50)
        body.watchlist.followBy(15)
        root.check("a touchpad stroke moves the list by its pixels", body.watchlist.contentY === 15)
        wait(700)
        root.check("and the list settles on a row once the finger stops", body.watchlist.contentY === 0)

        // Search: it takes the rows' place as it opens, then the keyboard's
        // choice (the top result) is what Enter adds, wherever the pointer
        // rests.
        body.startAdding()
        wait(100)
        root.check("opening search takes the rows' place at once", body.adding && !body.watchlist.visible)
        body.search.results = [
          { symbol: "TOPR", name: "Top Result Inc.", exchange: "NASDAQ" },
          { symbol: "SECR", name: "Second Result Inc.", exchange: "NYSE" },
          { symbol: "THRD", name: "Third Result Inc.", exchange: "NYSE" }
        ]
        body.search.answer = "results"
        wait(50)
        var third = root.findAll(body.search, "searchResult")[2]
        var overThird = third.mapToItem(body, third.width / 2, third.height / 2)
        mouseMove(body, overThird.x, overThird.y)
        wait(200)
        root.check("the pointer only tints a result", body.search.resultIndex === 0)
        // The exchange codes stay in one column as the choice moves, and an
        // unchosen row's Add, unseen, takes no click: a click there chooses
        // the row. Found in design pass 3: the chosen row's code sat about
        // 50 px left of the others, so each arrow moved two codes.
        var codeEdges = function() {
          return root.findAll(body.search, "searchExchange").map(function(code) {
            return Math.round(code.mapToItem(body, code.width, 0).x)
          })
        }
        var columns = [codeEdges()]
        keyClick(Qt.Key_Down)
        wait(50)
        columns.push(codeEdges())
        var edges = [].concat.apply([], columns)
        root.check("search's exchange codes stay in one column as the choice moves",
          edges.length === 6 && edges.every(function(x) { return x === edges[0] }), columns.join(" | "))
        var hiddenAdd = root.find(third, "searchAdd")
        var overHiddenAdd = hiddenAdd.mapToItem(body, hiddenAdd.width / 2, hiddenAdd.height / 2)
        mouseClick(body, overHiddenAdd.x, overHiddenAdd.y)
        wait(100)
        root.check("an unchosen result's unseen Add takes no click: the click chooses its row",
          body.adding && body.search.resultIndex === 2 && stub.symbols.indexOf("THRD") < 0,
          body.adding + "|" + body.search.resultIndex + "|" + stub.symbols.join(","))
        keyClick(Qt.Key_Up)
        keyClick(Qt.Key_Up)
        wait(50)
        keyClick(Qt.Key_Return)
        wait(100)
        root.check("Enter adds the keyboard's choice, not the result under the pointer",
          stub.symbols.indexOf("TOPR") >= 0 && stub.symbols.indexOf("THRD") < 0 && !body.adding)
        mouseMove(body, body.width / 2, 20)
        wait(200)

        // More results than the viewport holds: Down past its bottom and back
        // Up keeps the choice in view, and the scroll never leaves its bounds.
        body.startAdding()
        wait(100)
        var many = []
        for (var r = 0; r < 14; r++) many.push({ symbol: "R" + r, name: "Result " + r, exchange: "NYSE" })
        body.search.results = many
        body.search.answer = "results"
        wait(50)
        var viewport = root.find(body.search, "searchResults")
        var limit = viewport.contentHeight - viewport.height
        var inView = function() {
          var chosen = root.findAll(body.search, "searchResult")[body.search.resultIndex]
          var top = chosen.y - viewport.contentY
          return top >= 0 && top + chosen.height <= viewport.height
        }
        var arrowsHold = limit > 0
        for (var down = 0; down < 16; down++) {
          keyClick(Qt.Key_Down)
          arrowsHold = arrowsHold && inView() && viewport.contentY >= 0 && viewport.contentY <= limit
        }
        root.check("Down past the viewport keeps the choice in view and stops at the last result",
          arrowsHold && body.search.resultIndex === 13 && viewport.contentY === limit)
        arrowsHold = true
        for (var up = 0; up < 16; up++) {
          keyClick(Qt.Key_Up)
          arrowsHold = arrowsHold && inView() && viewport.contentY >= 0 && viewport.contentY <= limit
        }
        root.check("Up back past the top keeps the choice in view and rests at the top",
          arrowsHold && body.search.resultIndex === 0 && viewport.contentY === 0)
        keyClick(Qt.Key_Escape)
        wait(50)

        // A view still showing as its surface closes takes nothing: a click
        // on a result or a checklist box acts on nothing and takes no focus.
        // Found in the review of the untangle: during the popup's close fade
        // a click on a result added it. The surface's closing is surfaceOpen
        // going false, as the popup's fade begins.
        body.startAdding()
        wait(100)
        body.search.results = [{ symbol: "LATE", name: "Late Inc.", exchange: "NYSE" }]
        body.search.answer = "results"
        wait(50)
        body.surfaceOpen = false
        var lateRow = root.findAll(body.search, "searchResult")[0]
        var overLate = lateRow.mapToItem(body, lateRow.width / 2, lateRow.height / 2)
        mouseClick(body, overLate.x, overLate.y)
        wait(50)
        var searchInert = stub.symbols.indexOf("LATE") < 0 && body.adding && !body.search.activeFocus
        body.surfaceOpen = true
        wait(50)
        body.cancelAdding()
        body.openSymbolLists(stub.symbols[0])
        wait(100)
        body.surfaceOpen = false
        var box = root.find(body, "symbolLists")
        var overBox = box.mapToItem(body, box.width / 2, Style.space(45))
        mouseClick(body, overBox.x, overBox.y)
        wait(50)
        var listsInert = stub.memberships.length === 0 && !box.activeFocus
        body.surfaceOpen = true
        body.closeListViews()
        wait(50)
        root.check("a view showing through its surface's close takes no click and no focus",
          searchInert && listsInert, searchInert + "|" + listsInert + "|" + stub.memberships)

        // Nothing else on a closing surface acts either: a click, a right-click,
        // or the wheel on a row, a click on the footer or the header's look,
        // and the pointer over the chart, in smooth and in retro. Found in
        // cubic's review of #25: the card took clicks through its close fade.
        var inert = function() {
          mouseMove(body, 1, 1)
          wait(50)
          var rows = body.watchlist.displayedSymbols.slice()
          var target = rows[1]
          var hero = stub.featuredSymbol
          var settings = stub.lastSettings
          var scrolled = body.watchlist.contentY
          var cursor = body.watchlist.cursorRow
          body.surfaceOpen = false
          var row = body.watchlist.rowItem(target)
          var overRow = row.mapToItem(body, row.width / 2, row.height / 2)
          mouseClick(body, overRow.x, overRow.y)
          mouseClick(body, overRow.x, overRow.y, Qt.RightButton)
          mouseWheel(body, overRow.x, overRow.y, 0, -120)
          var footer = root.find(body, "footer")
          var overFooter = footer.mapToItem(body, footer.width / 2, footer.height / 2)
          mouseClick(body, overFooter.x, overFooter.y)
          var look = root.find(body, "lookIcon")
          var overLook = look.mapToItem(body, look.width / 2, look.height / 2)
          mouseClick(body, overLook.x, overLook.y)
          var chart = body.chartItem
          var overChart = chart.mapToItem(body, chart.width / 3, chart.height / 2)
          mouseMove(body, overChart.x, overChart.y)
          mouseMove(body, overChart.x + 20, overChart.y)
          wait(300)
          var still = [stub.featuredSymbol === hero, body.watchlist.displayedSymbols.join() === rows.join(),
            body.watchlist.contentY === scrolled, !body.adding, stub.lastSettings === settings,
            body.scrubT === 0, body.watchlist.cursorRow === cursor, body.listsSymbol === ""].join(",")
          body.surfaceOpen = true
          mouseMove(body, 1, 1)
          wait(50)
          return still
        }
        var smoothInert = inert()
        stub.retro = true
        wait(50)
        var retroInert = inert()
        stub.retro = false
        wait(50)
        root.check("a closing surface takes no click, right-click, wheel, or scrub, smooth and retro",
          smoothInert === "true,true,true,true,true,true,true,true" && retroInert === smoothInert, smoothInert + " | " + retroInert)

        // The order control hovers like a range token.
        var orderRow = root.find(body, "orderControl")
        var overOrder = orderRow.mapToItem(body, orderRow.width / 2, orderRow.height / 2)
        mouseMove(body, overOrder.x, overOrder.y)
        wait(260)
        root.check("the order control takes the hover fill",
          Qt.colorEqual(orderRow.color, Style.hoverFillFor(stub.foreground, Color.accent)))
        mouseMove(body, body.width / 2, 20)
        wait(200)

        // Since the open, the hero's caption names it, in the slot AT CLOSE
        // would take, and the figure is bare; a row says "open" inline.
        stub.featuredSymbol = "MU"
        stub.changeMode = "open"
        wait(50)
        var heroCaption = root.find(body, "changeCaption")
        var heroChange = root.find(body, "changeText")
        var firstShown = body.watchlist.rowItem(body.watchlist.displayedSymbols[0])
        root.check("a change since the open is captioned SINCE OPEN, never AT CLOSE",
          heroCaption.text === "SINCE OPEN" && heroChange.text.indexOf("open") < 0
            && firstShown.view.changeLine.indexOf(" open") > 0)
        stub.changeMode = "pct"
        wait(50)

        root.setQuotes(["FIT1", "FIT2"], [101, 102])
        wait(200)
        root.check("the scrollbar is absent when every row fits",
          !body.watchlist.ScrollBar.vertical.visible)

        // On the body as the popup and the window both host it, a right-click
        // on a row shows its lists and removes nothing; nor does a
        // middle-click, nor a click at once after the right-click. (The
        // popup's own harness has no pointer: its window is never mapped.)
        var fitRow = body.watchlist.rowItem("FIT2")
        var fitAt = fitRow.mapToItem(body, fitRow.width / 2, fitRow.height / 2)
        var membershipsBefore = stub.memberships.length
        mouseClick(body, fitAt.x, fitAt.y, Qt.MiddleButton)
        mouseClick(body, fitAt.x, fitAt.y, Qt.RightButton)
        var listsShown = body.listsSymbol
        mouseClick(body, fitAt.x, fitAt.y)
        wait(50)
        root.check("a right-click on a row shows its lists, and it, a middle-click, and a click at once after it remove nothing",
          listsShown === "FIT2" && body.listsSymbol === "FIT2" && stub.symbols.join(",") === "FIT1,FIT2"
            && stub.memberships.length === membershipsBefore,
          listsShown + "|" + body.listsSymbol + "|" + stub.symbols + "|" + stub.memberships.slice(membershipsBefore))
        body.closeListViews()
        wait(50)

        // x removes a row; the last one stays, and the footer says why for a
        // moment.
        body.removeRow("FIT2")
        wait(200)
        body.removeRow("FIT1")
        wait(50)
        root.check("the last row stays and the footer says why",
          stub.symbols.join(",") === "FIT1" && body.note === "Keep at least one symbol")
        wait(2700)
        root.check("the note clears on its own", body.note === "")

        // A removal's note stays while the pointer rests on it, past its five
        // seconds, and a click then takes the removal back: it never turns
        // into the add under the pointer. Once the pointer leaves, it has its
        // moment again. Found in the first-run review: a slow click on the
        // note opened search.
        root.setQuotes(["FIT1", "FIT2"], [101, 102])
        wait(200)
        var footer = root.find(body, "footer")
        var onNote = footer.mapToItem(body, footer.width / 2, footer.height / 2 + Style.space(3))
        mouseMove(body, onNote.x, onNote.y)
        wait(50)
        body.removeRow("FIT2")
        wait(5600)
        var action = root.find(footer, "footerAction")
        var held = body.note + "|" + (action ? action.text : "no action") + "|" + footer.hovered
        mouseClick(body, onNote.x, onNote.y)
        wait(50)
        root.check("a removal's note stays under the pointer past its moment, and a click on it then undoes",
          held === "Removed FIT2| · click or u to undo|true" && stub.undone === "FIT2" && !body.adding,
          held + "|" + stub.undone + "|" + body.adding)
        root.setQuotes(["FIT1", "FIT2"], [101, 102])
        wait(200)
        body.removeRow("FIT2")
        wait(5600)
        var stillHeld = body.note
        mouseMove(body, body.width / 2, 20)
        wait(1000)
        var leftAMoment = body.note
        tryVerify(function() { return body.note === "" }, 6000)
        root.check("once the pointer leaves, the note has its moment again, then goes",
          stillHeld === "Removed FIT2" && leftAMoment === "Removed FIT2" && body.note === "",
          stillHeld + "|" + leftAMoment + "|" + body.note)

        // The popup card's held anchor finds the pill's bar window through
        // the pill and sits on its content, where the shell measures an
        // anchor, and stays where the pill was held as the pill widens. Found
        // in review: it found its window through the card, which finds its
        // window through it, so neither had one and the card opened in the
        // screen's corner.
        heldAnchor.hold()
        var heldAt = heldAnchor.x + "+" + heldAnchor.width
        pillStandIn.width = 200
        var widened = heldAnchor.x + "+" + heldAnchor.width
        heldAnchor.hold()
        var heldAgain = heldAnchor.x + "+" + heldAnchor.width
        pillStandIn.width = 150
        root.check("the popup's held anchor sits on the pill's bar window, where the pill was held, until held again",
          heldAnchor.QsWindow.window === window && heldAnchor.parent === window.contentItem
            && heldAt === "200+150" && widened === heldAt && heldAgain === "200+200",
          [heldAnchor.QsWindow.window === window, heldAnchor.parent === window.contentItem, heldAt, widened, heldAgain].join("|"))

        // Every Stonks control answers a press the moment the button goes
        // down, as the shell's buttons do: its box, judged on the rendered
        // frames, leaves what lay under it on the next frame and settles on
        // the shell's pressed fill over it while the button is held. Let go
        // off the control, so the press does nothing else. In both looks.
        body.closeListViews()
        body.showingHelp = false
        stub.range = "1D"
        stub.order = "pct"
        grab.source = body
        var status = root.find(body, "statusText")
        var away = status.mapToItem(body, status.width / 2, status.height / 2)
        var pressed = Style.pressedFillFor(stub.foreground, Color.accent)
        var fillArg = [pressed.r, pressed.g, pressed.b, pressed.a].join(",")
        var boxOf = function(item) {
          var at = item.mapToItem(body, 0, 0)
          return [Math.ceil(at.x) + 1, Math.ceil(at.y) + 1, Math.floor(item.width) - 3, Math.floor(item.height) - 3]
        }
        var settings = function() {
          return [stub.range, stub.order, body.showingHelp, body.listMenuOpen, JSON.stringify(stub.lastSettings), body.adding, body.managingLists].join(",")
        }
        var pressOn = function(name, fill, target) {
          // A control drawn with no fill at all is judged on its own box.
          var box = boxOf(fill || target)
          var at = target.mapToItem(body, target.width / 2, target.height / 2)
          mouseMove(body, away.x, away.y)
          wait(200)
          var before = settings()
          grab.begin("press-" + name)
          wait(60)
          grab.markStart()
          mousePress(body, at.x, at.y)
          wait(300)
          grab.end()
          mouseMove(body, away.x, away.y)
          mouseRelease(body, away.x, away.y)
          tryVerify(function() { return grab.waiting === 0 }, 3000)
          grab.judge("press", null, [fillArg, box.join(",")])
          tryVerify(function() { return grab.verdict !== null }, 10000)
          var after = settings()
          return grab.verdict.ok && after === before ? "" : name + ": " + grab.verdict.detail + (after !== before ? ", the press did " + before + " -> " + after : "")
        }
        var pressFaults = []
        ;[false, true].forEach(function(retro) {
          stub.retro = retro
          stub.lastSettings = null
          wait(300)
          var look = retro ? "retro " : "smooth "
          var token = root.findAll(root.find(body, "rangeRow"), "rangeToken")[1]
          var controls = [
            ["range token", token, token],
            ["list name", root.find(body, "listControl"), root.find(body, "listLabel")],
            ["order word", root.find(body, "orderControl"), root.find(body, "orderLabel")],
            ["look icon", root.find(body, "lookFill"), root.find(body, "lookIcon")],
            ["help mark", root.find(body, "helpFill"), root.find(body, "helpMark")],
            ["footer", root.find(body, "footerFill"), root.find(body, "footerText")]
          ]
          controls.forEach(function(c) {
            var fault = pressOn((look + c[0]).replace(/ /g, "-"), c[1], c[2])
            if (fault !== "") pressFaults.push(fault)
          })
          body.openManageLists()
          wait(100)
          var doneAction = root.find(body, "manageDone")
          var actionFault = pressOn((look + "list view action").replace(/ /g, "-"), root.find(doneAction, "actionFill"), doneAction)
          if (actionFault !== "") pressFaults.push(actionFault)
          body.closeListViews()
          wait(100)
        })
        stub.retro = false
        root.check("the range tokens, the list name, the order word, the look icon, the ?, the footer, and a list view's action take the pressed fill on mouse-down, in both looks",
          pressFaults.length === 0, pressFaults.join(" | "))

        // The list views follow the wheel as the rows do: scrolled under a
        // still pointer, the cursor goes to the row then under it, so Enter
        // never acts on a row scrolled out of sight. From the rows review:
        // the cursor stayed on the row the pointer had left.
        var many = [{ name: "", label: "All", count: 1, symbols: ["FIT1"] }]
        for (var n = 1; n < 15; n++) many.push({ name: "L" + n, label: "List " + n, count: 0, symbols: [] })
        stub.lists = many
        wait(50)
        var wheeled = function(open, close, viewName, rowName) {
          open()
          wait(100)
          var view = root.find(body, viewName)
          var rows = root.findAll(view, rowName)
          var at = rows[1].mapToItem(body, rows[1].width / 2, rows[1].height / 2)
          mouseMove(body, at.x, at.y)
          wait(50)
          var pointed = view.cursor
          mouseWheel(body, at.x, at.y, 0, -240, Qt.NoModifier)
          wait(400)
          var under = -1
          rows.forEach(function(row, i) { if (row.contains(row.mapFromItem(body, at.x, at.y))) under = i })
          var cursor = view.cursor
          close()
          wait(100)
          return [pointed === 1, under > 1, cursor === under].join(",") + " " + pointed + "/" + under + "/" + cursor
        }
        var wheels = [
          wheeled(function() { body.openListMenu() }, function() { body.closeListMenu() }, "listMenu", "listChoice"),
          wheeled(function() { body.openSymbolLists("FIT1") }, function() { body.closeListViews() }, "symbolLists", "symbolListRow"),
          wheeled(function() { body.openManageLists() }, function() { body.closeListViews() }, "manageLists", "manageRow")
        ]
        root.check("in the list menu, a symbol's lists, and Manage lists, the wheel under a still pointer moves the cursor to the row then under it",
          wheels.every(function(w) { return w.indexOf("true,true,true ") === 0 }), wheels.join(" | "))

        console.log("POINTER DONE")
        done.exitCode = root.failures ? 1 : 0
        done.start()
      }
    }
  }

  HarnessExit { id: done }
}
