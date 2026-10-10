import QtQuick
import QtQuick.Controls
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons
import "plugin/Chart.js" as Chart
import "plugin/Fundamentals.js" as Fundamentals
import "plugin/History.js" as History
import "plugin/Overnight.js" as Overnight
import "plugin/Quote.js" as Quote
import "plugin/Settings.js" as Settings
import "plugin"

// Nothing jumps. The 22-symbol list with a cap symbol, an ETF, non-US
// listings in Toronto, Tokyo, and London, a four-digit price, and a price
// wide enough to force a shrink, on the day and on a range, at both surface
// sizes and in both looks: the
// listing line, the price's measured top line, baseline and left edge, the
// change's baseline and right edge, the range row, the info block, the
// header's look control and the end of its words, the list's TODAY and its
// rule, and the first row must not move with the look, and the first row
// must not move with the symbol or the range. The header's words keep room
// for its longest states at the popup's width. The footer sits at the
// bottom, one gap under All's rows and where it is whichever list shows, the
// rows stop short of the scrollbar's gutter, an open list menu makes room
// for itself, and the window's smallest permitted height still holds a whole
// row. The price and change text are measured as displayed, at whatever size
// they were fitted to. Every key-hint row is one line of six keys at most.
// Nothing is mapped into the running shell.
ShellRoot {
  id: root

  property int failures: 0
  readonly property string fixtures: Quickshell.env("STONKS_FIXTURES")

  FileView { id: watchlistFile; path: root.fixtures + "/watchlist-22.json"; blockLoading: true }
  FileView { id: aaplFile; path: root.fixtures + "/aapl.json"; blockLoading: true }
  FileView { id: spyFile; path: root.fixtures + "/spy-2026-09-11-day-prepost.json"; blockLoading: true }
  FileView { id: shopFile; path: root.fixtures + "/shop-to.json"; blockLoading: true }
  FileView { id: aaplWeeklyFile; path: root.fixtures + "/history/aapl-5y.json"; blockLoading: true }
  FileView { id: shopYearFile; path: root.fixtures + "/history/shop-to-1y.json"; blockLoading: true }
  FileView { id: tokyoFile; path: root.fixtures + "/7203-t-day.json"; blockLoading: true }
  FileView { id: londonFile; path: root.fixtures + "/shel-l-day.json"; blockLoading: true }
  // A coin under a cent and a six-figure price, each in its own decimals.
  FileView { id: shibFile; path: root.fixtures + "/overnight/sweep-2026-10-08-1054/shib-usd.json"; blockLoading: true }
  FileView { id: berkshireFile; path: root.fixtures + "/overnight/sweep-2026-10-08-1054/brk-a.json"; blockLoading: true }
  // NBIS on the first live night, Monday 5 October 00:36: its day, its 1M
  // history, and Robinhood's prints, so its hero carries the overnight line.
  FileView { id: liveFile; path: root.fixtures + "/overnight/live-2026-10-05/nbis.json"; blockLoading: true }
  FileView { id: liveMonthFile; path: root.fixtures + "/overnight/live-2026-10-05/nbis-1m.json"; blockLoading: true }
  FileView { id: liveNightFile; path: root.fixtures + "/overnight/live-2026-10-05/robinhood-day.json"; blockLoading: true }
  FileView { id: calendarFile; path: Quickshell.env("STONKS_CALENDARS"); blockLoading: true }

  // The hero chart's rendered frames, for frames.js.
  FrameGrab { id: grab }

  // Saved fundamentals with their closes, as the feed keeps them.
  function figures(name) {
    var read = function(path) {
      var view = Qt.createQmlObject('import Quickshell.Io; FileView { blockLoading: true }', root)
      view.path = root.fixtures + "/fundamentals/" + path + ".json"
      var json = JSON.parse(view.text())
      view.destroy()
      return json
    }
    return Fundamentals.withSnapshotCloses(Fundamentals.parseFundamentals(read(name)), read(name + "-closes"))
  }

  function check(label, ok, detail) {
    console.log((ok ? "PASS " : "FAIL ") + label + (detail !== undefined && !ok ? " — " + detail : ""))
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

  function yIn(item, y) { return Math.round(item.mapToItem(body, 0, y).y) }
  function xIn(item, x) { return Math.round(item.mapToItem(body, x, 0).x) }

  // The ink of a Text as it is drawn now, at the size it was fitted to.
  TextMetrics { id: shownInk }

  function inkOf(item) {
    shownInk.font = item.font
    shownInk.text = item.text
    return shownInk.tightBoundingRect
  }

  // The bottom of the last row the list draws: the empty list's one row, or
  // the lowest row whose top is inside the list's box. Measured from the
  // rows, not the box, so room left in the box under them, or a row the box
  // cuts, moves the footer off its gap.
  function lastRowBottom() {
    var list = body.watchlist
    var empty = find(body, "emptyList")
    if (empty.visible) return yIn(empty, empty.height)
    var end = yIn(list, list.height)
    var bottom = yIn(list, 0)
    list.displayedSymbols.forEach(function(symbol) {
      var row = list.rowItem(symbol)
      if (row && yIn(row, 0) < end) bottom = Math.max(bottom, yIn(row, row.height))
    })
    return bottom
  }

  // Where everything sits right now, in body coordinates.
  function measure() {
    var smooth = find(body, "smoothPrice")
    var block = find(body, "blockPrice")
    var change = find(body, "changeText")
    var caption = find(body, "changeCaption")
    var info = find(body, "infoBlock")
    var firstRow = body.watchlist.rowItem(body.watchlist.displayedSymbols[0])
    var footer = find(body, "footer")
    var status = find(body, "statusText")
    var today = find(body, "todayLabel")
    var priceInk = inkOf(smooth)
    return {
      listing: yIn(find(body, "listingLine"), 0),
      baseline: stub.retro ? yIn(block, block.baselineOffset) : yIn(smooth, smooth.baselineOffset),
      top: stub.retro ? yIn(block, 0) : yIn(smooth, smooth.baselineOffset + priceInk.y),
      left: stub.retro ? xIn(block, 0) : xIn(smooth, priceInk.x),
      change: yIn(change, change.baselineOffset),
      changeRight: xIn(change, change.width),
      captionRight: xIn(caption, caption.width),
      // The line under the price, by its words' baseline, shown or not.
      strip: yIn(find(body, "extendedLine").children[0], find(body, "extendedLine").children[0].baselineOffset),
      range: yIn(find(body, "rangeRow"), 0),
      info: yIn(info, 0),
      infoHeight: Math.round(info.height),
      list: yIn(body.watchlist, 0),
      // mapToItem already carries the list's scroll, so this is where the row
      // is drawn: at the list's top only when the list is at rest there.
      row: firstRow ? yIn(firstRow, 0) : -1,
      footer: yIn(footer, footer.height),
      footerGap: yIn(footer, 0) - lastRowBottom(),
      looks: xIn(find(body, "lookIcon"), 0),
      statusRight: xIn(status, status.width),
      today: xIn(today, 0),
      todayRight: xIn(today, today.width),
      rule: xIn(find(body, "breadthRule"), 0),
      listRight: xIn(find(body, "listLabel"), find(body, "listLabel").width)
    }
  }

  function describe(m) { return JSON.stringify(m) }

  // A price and a change wide enough that the room the change leaves cannot
  // hold the digits: both renderers have to shrink.
  function wideQuote(quote) {
    return Object.assign({}, quote, {
      symbol: "WIDE", name: "Wide Price Inc.", price: 9999999.99, prevClose: 12345,
      points: quote.points.map(function(point) { return { t: point.t, p: 9999999.99 } })
    })
  }

  function load() {
    var fixture = JSON.parse(watchlistFile.text())
    var names = []
    var quotes = {}
    var entries = {}
    for (var i = 0; i < fixture.quotes.length; i++) {
      var item = fixture.quotes[i]
      var parsed = item.response ? Quote.parseChart(item.response) : null
      var name = parsed ? parsed.symbol : item.symbol
      names.push(name)
      if (parsed) quotes[name] = parsed
      entries[name] = { status: item.status, receivedAt: item.status === "ok" ? fixture.now : 0 }
    }
    quotes.AAPL = Quote.parseChart(JSON.parse(aaplFile.text()))
    quotes.SPY = Quote.parseChart(JSON.parse(spyFile.text()))
    quotes["SHOP.TO"] = Quote.parseChart(JSON.parse(shopFile.text()))
    quotes["7203.T"] = Quote.parseChart(JSON.parse(tokyoFile.text()))
    quotes["SHEL.L"] = Quote.parseChart(JSON.parse(londonFile.text()))
    quotes.NBIS = Quote.parseChart(JSON.parse(liveFile.text()))
    stub.nights = { NBIS: { status: "ok", bars: Overnight.parseOvernight(JSON.parse(liveNightFile.text()), ["NBIS"]).NBIS } }
    stub.nightCalendars = JSON.parse(calendarFile.text())
    entries["7203.T"] = entries["SHEL.L"] = { status: "ok", receivedAt: quotes.AAPL.marketTime + 120 }
    // BRK-A's real answer in place of the list's stand-in.
    quotes["SHIB-USD"] = Quote.parseChart(JSON.parse(shibFile.text()))
    quotes["BRK-A"] = Quote.parseChart(JSON.parse(berkshireFile.text()))
    names.push("SHIB-USD")
    entries["SHIB-USD"] = entries["BRK-A"] = { status: "ok", receivedAt: quotes.AAPL.marketTime + 120 }
    quotes.WIDE = wideQuote(quotes.MU)
    stub.now = quotes.AAPL.marketTime + 120
    names.push("WIDE")
    entries.WIDE = { status: "ok", receivedAt: stub.now }
    stub.symbols = names
    stub.quotes = quotes
    stub.entries = entries
  }

  // Before the surface takes its size, so its first height already holds rows.
  Component.onCompleted: load()

  QtObject {
    id: stub
    property var symbols: []
    property var library: symbols
    property string listName: ""
    property var lists: [{ name: "", label: "All", count: symbols.length, symbols: symbols }]
    property var quotes: ({})
    property var entries: ({})
    property var calendars: null
    property string featuredSymbol: "AAPL"
    property string order: "manual"
    property bool reversed: false
    property string changeMode: "pct"
    property int now: 0
    property var asked: ({})
    property string range: "1D"
    property var historyEntry: null
    property var figures: null
    readonly property var histories: historyEntry ? ({ [featuredSymbol + "|" + range]: historyEntry }) : ({})
    readonly property var fundamentals: figures ? ({ [featuredSymbol]: { status: "ok", figures: figures } }) : ({})
    property var arriving: []
    property var lastRemoval: null
    readonly property var view: ({ featured: featuredSymbol, range: range, list: listName, listKey: "=" + listName,
      order: order, reversed: reversed, rows: symbols, shown: Settings.sortedSymbols(symbols, quotes, order, reversed),
      library: library, chart: Chart.viewChart(featuredSymbol, range, quotes, entries, histories, nights,
        { NBIS: { status: "ok", allDay: true, at: 0 } }, featuredSymbol === "NBIS" ? nightCalendars : null) })
    // NBIS's prints, and the calendars its chart's day reads; only NBIS has
    // them, Robinhood trading it all day, so no other symbol waits on
    // Robinhood, and the body's own calendars stay null.
    property var nights: ({})
    property var nightCalendars: null
    property bool retro: false
    property color foreground: "#cacccc"
    property color upColor: "#7aa2f7"
    property color downColor: "#a55555"
    property string fontFamily: Style.font.family
    function persist(values) {}
    function setRange(value) {}
    function surfaceShown(surface, open) {}
    // A search's choice shown on the hero; this stub's hero never changes.
    readonly property var previewView: view
    readonly property var previewEntries: ({})
    property var previewSurface: null
    function preview(surface, symbol) {}
    function feature(symbol) { featuredSymbol = symbol }
    function removeSymbol(symbol) {}
    function setManualOrder(next) {}
    function addSymbol(symbol) {}
    function setOrder(value) { order = value; reversed = false }
    function reverseOrder() { reversed = !reversed }
    function switchList(name) {}
    function stepList(delta) {}
    function createList(name) { return "" }
  }

  FloatingWindow {
    id: window
    visible: true
    color: "#101315"
    implicitWidth: 760
    implicitHeight: 900

    // The surface under test: the popup's content box, or the window's.
    Item {
      id: surface
      property bool wide: false
      property int fixedHeight: 0
      x: 0
      y: 0
      width: wide ? 720 : 448
      height: fixedHeight > 0 ? fixedHeight : body.fittedHeight(730)

      StonksBody {
        id: body
        anchors.fill: parent
        service: stub
        foreground: stub.foreground
        upColor: stub.upColor
        downColor: stub.downColor
        fontFamily: stub.fontFamily
        surfaceOpen: true
        margins: surface.wide ? Style.space(16) : 0
        chartHeight: surface.wide ? Style.space(220) : Style.space(190)
        surfaceKind: surface.wide ? "window" : "popup"
      }
    }

    TestCase {
      name: "NothingJumps"
      when: window.visible

      function test_nothing_jumps() {
        // The rows animate into their slots on the first layout; measure once
        // everything has settled.
        wait(400)
        var weekly = History.parseHistory(JSON.parse(aaplWeeklyFile.text()), "5Y")
        var year = History.parseHistory(JSON.parse(shopYearFile.text()), "1Y")
        var month = History.parseHistory(JSON.parse(liveMonthFile.text()), "1M")
        var aapl = root.figures("aapl")
        var cases = [
          { symbol: "AAPL", range: "1D", history: null, figures: aapl },
          { symbol: "AAPL", range: "5Y", history: weekly, figures: aapl },
          { symbol: "SPY", range: "1D", history: null, figures: null },
          { symbol: "SHOP.TO", range: "1D", history: null, figures: root.figures("shop-to") },
          { symbol: "SHOP.TO", range: "1Y", history: year, figures: root.figures("shop-to") },
          { symbol: "MU", range: "1D", history: null, figures: null },
          { symbol: "MU", range: "5Y", history: null, figures: null },
          { symbol: "WIDE", range: "1D", history: null, figures: null },
          // The longest real key stats line: Tokyo's, with a four-digit
          // 52-week range in yen; London's names its pounds.
          { symbol: "7203.T", range: "1D", history: null, figures: root.figures("7203-t") },
          { symbol: "SHEL.L", range: "1D", history: null, figures: root.figures("shel-l") },
          { symbol: "SHIB-USD", range: "1D", history: null, figures: null },
          { symbol: "BRK-A", range: "1D", history: null, figures: null },
          // 1M with an overnight print under the price.
          { symbol: "NBIS", range: "1M", history: month, figures: null, line: "OVERNIGHT" }
        ]
        // Both info lines whole: never elided, in either look at either width.
        var cut = []
        var longest = ""
        // The line under the price, too: whole, short of the caption, and
        // there when the case expects it.
        var whole = function(label, expected) {
          ["periodLine", "keyStatsLine"].forEach(function(name) {
            var line = find(body, name)
            if (line.truncated || line.lineCount !== 1 || line.implicitWidth > line.width + 0.5)
              cut.push(label + " " + name + " \"" + line.text + "\" " + Math.ceil(line.implicitWidth) + " px in " + line.width)
          })
          if (body.keyStatsText.length > longest.length) longest = body.keyStatsText
          var strip = find(body, "extendedLine")
          var caption = find(body, "changeCaption")
          if (strip.visible && root.xIn(strip, strip.width) >= root.xIn(caption, 0))
            cut.push(label + " extendedLine ends at " + root.xIn(strip, strip.width) + ", the caption starts at " + root.xIn(caption, 0))
          var shown = strip.visible ? strip.children[0].text : ""
          if (expected && shown !== expected) cut.push(label + " shows \"" + shown + "\" under the price, not " + expected)
        }
        // A price shrinks only when it cannot fit beside the change: WIDE and
        // SHIB's nine decimals in the popup, and nothing else, nowhere else.
        var hero = find(body, "hero")
        var misfits = []
        for (var surfaceIndex = 0; surfaceIndex < 2; surfaceIndex++) {
          surface.wide = surfaceIndex === 1
          wait(50)
          var place = surface.wide ? "window" : "popup"
          var first = null
          for (var i = 0; i < cases.length; i++) {
            var c = cases[i]
            stub.featuredSymbol = c.symbol
            stub.range = c.range
            stub.historyEntry = c.history ? { status: "ok", history: c.history, receivedAt: stub.now } : null
            stub.figures = c.figures
            stub.retro = false
            wait(50)
            var smooth = root.measure()
            whole(place + " smooth " + c.symbol + " " + c.range, c.line)
            stub.retro = true
            wait(50)
            var retro = root.measure()
            whole(place + " retro " + c.symbol + " " + c.range, c.line)
            var label = place + " " + c.symbol + " " + c.range
            var fixed = ["listing", "baseline", "change", "changeRight", "captionRight", "strip",
              "range", "info", "infoHeight", "list", "row", "footer", "looks", "statusRight", "today", "rule"]
            var moved = fixed.filter(function(key) { return smooth[key] !== retro[key] })
            root.check(label + ": the look moves nothing outside the digits", moved.length === 0,
              moved.join(", ") + " smooth " + root.describe(smooth) + " retro " + root.describe(retro))
            root.check(label + ": both looks' digits share a top line and a left edge",
              Math.abs(smooth.top - retro.top) <= 2 && Math.abs(smooth.left - retro.left) <= 2,
              "smooth " + root.describe(smooth) + " retro " + root.describe(retro))
            root.check(label + ": the change and its caption end at the hero's right edge",
              smooth.changeRight === smooth.captionRight
                && smooth.changeRight === Math.round(body.width - body.margins),
              root.describe(smooth) + " body " + body.width + " margins " + body.margins)
            root.check(label + ": the change sits on the price baseline",
              smooth.change === smooth.baseline && retro.change === retro.baseline,
              "smooth " + root.describe(smooth) + " retro " + root.describe(retro))
            root.check(label + ": the footer follows the rows at one gap",
              smooth.footerGap === body.bandGap && retro.footerGap === body.bandGap,
              smooth.footerGap + " / " + retro.footerGap)
            root.check(label + ": the first row sits at the top of the list",
              smooth.row === smooth.list && retro.row === retro.list,
              "smooth " + root.describe(smooth) + " retro " + root.describe(retro))
            root.check(label + ": TODAY is after the list's name, dim, and the rule starts after it",
              find(body, "todayLabel").visible && find(body, "todayLabel").text === "TODAY"
                && String(find(body, "todayLabel").color) === String(body.dim)
                && smooth.today > smooth.listRight && retro.today > retro.listRight
                && smooth.rule > smooth.todayRight && retro.rule > retro.todayRight,
              find(body, "todayLabel").color + " vs " + body.dim + " " + root.describe(smooth))
            if (!first) first = smooth
            root.check(label + ": the first row, the info block, TODAY, and the line under the price stay put across symbols and ranges",
              smooth.row === first.row && smooth.info === first.info && smooth.infoHeight === first.infoHeight
                && smooth.today === first.today && smooth.rule === first.rule && smooth.strip === first.strip,
              "first " + root.describe(first) + " now " + root.describe(smooth))
            if ((hero.fittedCell < hero.naturalCell) !== ((c.symbol === "WIDE" || c.symbol === "SHIB-USD") && !surface.wide))
              misfits.push(label + " " + hero.fittedCell + " of " + hero.naturalCell)
          }
        }
        root.check("a price too wide for the popup (WIDE, SHIB-USD) shrinks there and not in the window, and no other price shrinks",
          misfits.length === 0, misfits.join(", "))
        root.check("both info lines are whole for every symbol, the longest key stats line included (" + longest + "), and the line under the price is whole where it shows",
          cut.length === 0, cut.join(" | "))

        // Every price a listing shows is in its own decimals: a coin under a
        // cent to four significant digits, a six-figure price to none, in
        // the hero in both looks, in its row, and in a scrub of its day.
        // SHIB read 0.00 everywhere.
        var decimals = []
        ;[["SHIB-USD", /^0\.00000\d{4}$/], ["BRK-A", /^7\d\d,\d{3}$/]].forEach(function(want) {
          stub.featuredSymbol = want[0]
          stub.range = "1D"
          stub.historyEntry = null
          stub.figures = null
          stub.retro = false
          wait(50)
          var row = body.watchlist.rowItem(want[0])
          var shown = { hero: find(body, "smoothPrice").text, row: row && row.view ? row.view.priceText : "" }
          stub.retro = true
          wait(50)
          shown.retro = find(body, "blockPrice").text
          stub.retro = false
          var day = body.featuredDay.points
          body.motion.scrubT = day[Math.floor(day.length / 2)].t
          wait(50)
          shown.scrub = find(body, "smoothPrice").text
          body.motion.scrubT = 0
          wait(50)
          for (var where in shown) if (!want[1].test(shown[where])) decimals.push(want[0] + " " + JSON.stringify(shown))
        })
        root.check("a coin under a cent and a six-figure price each show their own decimals in the hero, both looks, the row, and a scrub",
          decimals.length === 0, decimals.join(" | "))

        // The header's words keep room for its longest real states, the
        // longest holidays in calendars.json included, in both looks at both
        // widths, beside the look icon and the help mark. One is cut, by the
        // owner's call: Tokyo's longest closure in the popup, 12 px short in
        // retro before a New York reader's JST was added to it, and in smooth
        // too since its words start after the animal as retro's do.
        var header = find(body, "statusText").parent
        var roomless = []
        var longest = ["CLOSED · OPENS MON 09:30", "POWER HOUR · CLOSES IN 40M", "LUNCH BREAK · REOPENS 12:30 JST · IN 59M",
          "OPENING BELL · CLOSES IN 6H 20M", "INDEPENDENCE DAY OBSERVED · OPENS MON 09:30",
          "MARTIN LUTHER KING, JR. DAY · OPENS TUE 09:30", "CONSTITUTION MEMORIAL DAY OBSERVED · OPENS THU 09:00 JST"]
        for (var hw = 0; hw < 2; hw++) {
          surface.wide = hw === 1
          for (var hlook = 0; hlook < 2; hlook++) {
            stub.retro = hlook === 1
            for (var s = 0; s < longest.length; s++) {
              header.statusText = longest[s]
              wait(20)
              var words = find(body, "statusText")
              if (words.truncated || words.implicitWidth > words.width)
                roomless.push((surface.wide ? "window " : "popup ") + (stub.retro ? "retro " : "smooth ") + longest[s])
            }
          }
        }
        header.statusText = Qt.binding(function() { return body.headerText })
        surface.wide = false
        stub.retro = false
        wait(20)
        root.check("the header's longest real states fit, holidays included, in both looks at both widths, but Tokyo's longest closure in the popup",
          roomless.join(" | ") === "popup smooth CONSTITUTION MEMORIAL DAY OBSERVED · OPENS THU 09:00 JST | popup retro CONSTITUTION MEMORIAL DAY OBSERVED · OPENS THU 09:00 JST", roomless.join(" | "))

        // The list's header lines up with its rows and groups with them: its
        // name starts at the rows' text and its order word ends at the
        // figures it ranks, and it sits 16 px under the info lines and 6 px
        // over its rows, the range row 8 px over the info lines. Found in
        // design pass 3: the name started 4 px left of the symbols, the
        // order word ended 12 px right of the figures, and every band was
        // 10 px from the next.
        var headerFaults = []
        for (var hw = 0; hw < 2; hw++) {
          surface.wide = hw === 1
          for (var hl = 0; hl < 2; hl++) {
            stub.retro = hl === 1
            wait(50)
            var row0 = body.watchlist.rowItem(body.watchlist.displayedSymbols[0])
            var nameText = find(body, "listLabel")
            var orderWord = find(body, "orderLabel")
            var headerLine = nameText.parent
            var rangeRow = find(body, "rangeRow")
            var infoLines = find(body, "infoBlock")
            var placed = {
              name: xIn(nameText, 0) - (xIn(row0, 0) + row0.gap),
              order: xIn(orderWord, orderWord.width) - (xIn(row0, row0.width) - row0.gap),
              rangeToInfo: yIn(infoLines, 0) - yIn(rangeRow, rangeRow.height),
              infoToHeader: yIn(headerLine, 0) - yIn(infoLines, infoLines.height),
              headerToRows: yIn(body.watchlist, 0) - yIn(headerLine, headerLine.height)
            }
            if (placed.name !== 0 || placed.order !== 0 || placed.rangeToInfo !== 8
                || placed.infoToHeader !== 16 || placed.headerToRows !== 6)
              headerFaults.push((surface.wide ? "window " : "popup ") + (stub.retro ? "retro " : "smooth ") + JSON.stringify(placed))
          }
        }
        surface.wide = false
        stub.retro = false
        wait(50)
        root.check("the list's header starts at its rows' text, ends at their figures, 16 px under the info lines and 6 px over its rows",
          headerFaults.length === 0, headerFaults.join(" | "))

        // The rows stop short of the scrollbar's gutter, so the thumb never
        // sits on a row.
        stub.retro = false
        for (var g = 0; g < 2; g++) {
          surface.wide = g === 1
          wait(50)
          // The thumb as drawn: the bar's box carries padding that draws nothing.
          var thumb = body.watchlist.ScrollBar.vertical.contentItem
          var topRow = body.watchlist.rowItem(body.watchlist.displayedSymbols[0])
          var rowRight = xIn(topRow, topRow.width)
          var thumbLeft = xIn(thumb, 0)
          root.check((surface.wide ? "window" : "popup") + ": the rows stop short of the scrollbar's gutter",
            body.watchlist.interactive && thumb.visible && thumb.width > 0 && rowRight <= thumbLeft,
            "row ends " + rowRight + ", thumb starts " + thumbLeft + " and is " + thumb.width + " wide")
        }

        // The window's smallest permitted height still holds a whole row.
        surface.fixedHeight = body.chromeHeight + body.listRowHeight
        stub.featuredSymbol = "MU"
        stub.range = "1D"
        stub.historyEntry = null
        wait(50)
        var minimum = root.measure()
        root.check("the window's minimum height holds one whole row",
          body.watchlist.height === body.rowPitch - body.rowGap
            && minimum.footerGap === body.bandGap && minimum.footer <= surface.height,
          "list " + body.watchlist.height + " of " + surface.height)

        // Search takes its height as it opens, before any typing: the field
        // and a full set of results, or the rows' height when that is taller,
        // and keeps it as the answer comes: with All full, and nearly empty.
        // Found in the transition audit (search 1, lists 14): the card grew
        // only at the first answer, and the field jumped with it.
        surface.fixedHeight = 0
        var opens = function() {
          var rowsHeight = body.fittedHeight(730)
          body.adding = true
          wait(50)
          var opened = body.fittedHeight(730)
          body.search.results = [{ symbol: "ONE", name: "One", exchange: "NYSE" }]
          body.search.answer = "results"
          wait(50)
          var answered = body.fittedHeight(730)
          body.search.results = []
          body.search.answer = ""
          body.adding = false
          wait(50)
          return [opened === Math.min(730, Math.max(rowsHeight, body.searchHeight)), answered === opened].join(",")
            + " " + rowsHeight + "->" + opened + "->" + answered
        }
        var fullAll = opens()
        stub.symbols = ["MU", "AAPL"]
        wait(50)
        var shortAll = opens()
        root.check("search takes its height as it opens and keeps it as the answer comes, All full and nearly empty",
          /^true,true /.test(fullAll) && /^true,true /.test(shortAll), fullAll + " | " + shortAll)
        // Any budget takes every whole row it can hold and no more; at the
        // popup's cap, its fixed content and six whole rows, that is six. The
        // search check above left a short list behind.
        root.load()
        wait(50)
        var cap = body.chromeHeight + 6 * body.rowPitch - body.rowGap
        var budgets = [cap, cap - 1, cap - 30, 700]
        var loose = budgets.filter(function(budget) {
          var fitted = body.fittedHeight(budget)
          return fitted > budget || fitted + body.rowPitch <= budget
            || (fitted - body.chromeHeight + body.rowGap) % body.rowPitch !== 0
        })
        root.check("the popup takes every whole row its budget allows", loose.length === 0,
          budgets.map(function(b) { return b + "->" + body.fittedHeight(b) }).join(" "))

        // Another list, a long name, or an empty list moves nothing above the
        // rows, in either look; an empty list keeps one row, which says so.
        // The footer follows the list's rows (design pass 3).
        for (var look = 0; look < 2; look++) {
          stub.retro = look === 1
          stub.listName = ""
          root.load()
          // All stays the library whichever list shows, as the service's does.
          stub.library = stub.symbols.slice()
          stub.featuredSymbol = "MU"
          wait(50)
          var onAll = root.measure()
          stub.listName = "Semiconductors & AI infrastructure"
          stub.symbols = ["AAPL", "MU"]
          wait(250)
          var onList = root.measure()
          var lookName = stub.retro ? "retro" : "smooth"
          var keys = ["listing", "baseline", "change", "changeRight", "range", "info", "list", "row"]
          var shifted = keys.filter(function(key) { return onAll[key] !== onList[key] })
          root.check(lookName + ": a list switch with a long name moves nothing", shifted.length === 0,
            shifted.join(", ") + " all " + root.describe(onAll) + " list " + root.describe(onList))
          root.check(lookName + ": a long list name keeps TODAY after it and before the rule",
            onList.today > onList.listRight && onList.rule > onList.todayRight, root.describe(onList))
          stub.listName = "Energy"
          stub.symbols = []
          wait(50)
          var onEmpty = root.measure()
          var footerTop = function() { return yIn(find(body, "footer"), 0) }
          root.check(lookName + ": an empty list keeps one row, the footer one gap under it, and moves nothing above it",
            body.watchlist.height === body.rowPitch - body.rowGap && onEmpty.list === onAll.list
              && onEmpty.range === onAll.range && footerTop() === onEmpty.list + body.watchlist.height + body.bandGap
              && find(body, "emptyList").visible,
            root.describe(onEmpty) + " footer at " + footerTop())
          // An open list menu taller than the one row makes room for itself
          // and for the footer one gap under it: the surface grows until the
          // whole menu and the footer show inside it, but never past a budget
          // too short for them. Found in design pass 3: fitting a short list,
          // the menu covered the footer's words.
          stub.lists = [
            { name: "", label: "All", count: 23, symbols: [] },
            { name: "Energy", label: "Energy", count: 0, symbols: [] },
            { name: "My Portfolio", label: "My Portfolio", count: 2, symbols: [] },
            { name: "Semiconductors", label: "Semiconductors", count: 3, symbols: [] }
          ]
          // With All one symbol long, the menu is taller than the rows.
          stub.library = ["AAPL"]
          wait(50)
          var shut = surface.height
          body.openListMenu()
          wait(50)
          var menu = find(body, "listMenu")
          var menuBottom = yIn(menu, menu.height)
          var footerAt = find(body, "footer")
          root.check(lookName + ": an open list menu makes room for itself and the footer under it",
            menu.visible && menu.height === menu.contentHeight && surface.height > shut
              && menuBottom + body.bandGap <= yIn(footerAt, 0) && yIn(footerAt, footerAt.height) <= surface.height
              && body.fittedHeight(surface.height - 1) === surface.height - 1,
            "menu " + menu.height + " of " + menu.contentHeight + " ends at " + menuBottom + ", footer at " + yIn(footerAt, 0)
              + " in " + surface.height + ", shut " + shut + ", in one less " + body.fittedHeight(surface.height - 1))
          body.closeListMenu()
          stub.lists = Qt.binding(function() {
            return [{ name: "", label: "All", count: stub.symbols.length, symbols: stub.symbols }]
          })
          wait(50)
          // Manage lists and a symbol's lists take the rows' place and move
          // nothing above it.
          stub.listName = ""
          root.load()
          wait(50)
          var above = ["listing", "baseline", "change", "changeRight", "range", "info"]
          // Over search's results and the list views the header names the
          // list only, on a line of the same height. Found in design pass 3:
          // TODAY, the breadth, and "% CHANGE" stood over results and views
          // they did not describe.
          var header = find(body, "listLabel").parent
          var headerHeight = header.height
          var rowsOnly = ["todayLabel", "breadthRule", "orderLabel", "orderControl"]
          var namesOnly = function() {
            var shown = rowsOnly.filter(function(name) { return find(body, name).visible })
            return find(body, "listLabel").visible && shown.length === 0 && header.height === headerHeight
              ? "" : "shown " + shown.join(",") + " height " + header.height + " of " + headerHeight
          }
          var views = [
            { name: "manageLists", open: function() { body.openManageLists() }, close: function() { body.closeListViews() } },
            { name: "symbolLists", open: function() { body.openSymbolLists("MU") }, close: function() { body.closeListViews() } },
            { name: "searchResults", open: function() {
              body.startAdding()
              body.search.results = [{ symbol: "ONE", name: "One", exchange: "NYSE" }]
              body.search.answer = "results"
            }, close: function() { body.search.results = []; body.search.answer = ""; body.cancelAdding() } }
          ]
          for (var v = 0; v < views.length; v++) {
            views[v].open()
            wait(50)
            var withView = root.measure()
            var viewMoved = above.filter(function(key) { return onAll[key] !== withView[key] })
            var view = find(body, views[v].name)
            root.check(lookName + ": " + views[v].name + " takes the rows' place and moves nothing above them",
              viewMoved.length === 0 && view.visible && yIn(view, 0) === onAll.list,
              viewMoved.join(", ") + " view at " + yIn(view, 0) + " rows at " + onAll.list)
            var named = namesOnly()
            root.check(lookName + ": over " + views[v].name + " the list header names the list only", named === "", named)
            views[v].close()
            wait(50)
          }
          root.check(lookName + ": with the rows back the header says TODAY, the breadth, and the order again",
            rowsOnly.every(function(name) { return find(body, name).visible }))
        }
        // A shorter list's rows are its own, and the footer sits one gap under
        // them. Found in design pass 3: the footer stayed where All's is,
        // with an empty row's room above it.
        stub.retro = false
        stub.listName = ""
        root.load()
        stub.library = stub.symbols.slice()
        wait(250)
        var shortOk = true
        var lists = [{ name: "Energy", symbols: ["AAPL", "MU"] }, { name: "Losses", symbols: [] }]
        for (var s = 0; s < lists.length; s++) {
          stub.listName = lists[s].name
          stub.symbols = lists[s].symbols
          wait(250)
          var rows = Math.max(1, lists[s].symbols.length)
          var shortList = root.measure()
          shortOk = shortOk && body.watchlist.height === rows * body.rowPitch - body.rowGap
            && yIn(find(body, "footer"), 0) === shortList.list + body.watchlist.height + body.bandGap
        }
        root.check("a shorter list's footer sits one gap under its rows", shortOk)

        // Search's field opens at the bottom, where the footer is, the footer's
        // height, and stays there while you type, on any list, at either
        // surface size.
        var fieldPlaces = []
        var footerAt = find(body, "footer")
        var fieldBar = find(body.search, "searchField").parent
        for (var w = 0; w < 2; w++) {
          surface.wide = w === 1
          var cases = [{ name: "", symbols: stub.library }].concat(lists)
          for (var c2 = 0; c2 < cases.length; c2++) {
            stub.listName = cases[c2].name
            stub.symbols = cases[c2].symbols
            wait(50)
            var footerBottom = yIn(footerAt, footerAt.height) - surface.height
            body.startAdding()
            wait(50)
            var fieldY = yIn(fieldBar, 0)
            var fieldBottom = yIn(fieldBar, fieldBar.height) - surface.height
            body.search.results = [{ symbol: "ONE", name: "One", exchange: "NYSE" }]
            body.search.answer = "results"
            wait(50)
            var typedY = yIn(fieldBar, 0)
            body.search.results = []
            body.search.answer = ""
            body.cancelAdding()
            wait(50)
            if (footerBottom !== fieldBottom || fieldBar.height !== footerAt.height || typedY !== fieldY)
              fieldPlaces.push((surface.wide ? "window " : "popup ") + (cases[c2].name || "All") + " "
                + footerBottom + " vs " + fieldBottom + ", " + fieldY + " -> " + typedY)
          }
        }
        surface.wide = false
        root.check("search's field opens at the bottom where the footer is and stays while you type, on any list and either surface", fieldPlaces.length === 0,
          fieldPlaces.join(", "))

        // A live day and a range say the same words in the same place: nothing
        // is put in front of them while the market trades, so a range change
        // or a scrub moves nothing in the header. The chart's breathing dot
        // says live.
        stub.listName = ""
        stub.retro = false
        root.load()
        var shop = stub.quotes["SHOP.TO"]
        var liveNow = shop.marketTime + 30
        stub.now = liveNow
        stub.entries = Object.assign({}, stub.entries, { "SHOP.TO": { status: "ok", receivedAt: liveNow } })
        stub.featuredSymbol = "SHOP.TO"
        stub.range = "1D"
        stub.historyEntry = null
        wait(50)
        var status = find(body, "statusText")
        var onDay = { text: status.text, x: xIn(status, 0), live: body.heroLive }
        stub.range = "1Y"
        stub.historyEntry = { status: "ok", history: year, receivedAt: liveNow }
        wait(50)
        var onRange = { text: status.text, x: xIn(status, 0) }
        root.check("the header's words hold still from a live day to a range",
          onDay.live && onDay.text === onRange.text && onDay.x === onRange.x,
          JSON.stringify(onDay) + " " + JSON.stringify(onRange))
        stub.range = "1D"
        stub.historyEntry = null

        // A closing surface keeps its live marks as they are: the header's
        // words keep their colour, and the dot's ripple (retro's blinking cap)
        // stops where it is, then goes on as the surface opens. Found in the
        // transition audit (lifecycle 8): on the first frame of the close
        // fade the words dimmed and the ripple jumped back to rest.
        // While the chart asked for is on its way, the live day held on show
        // holds still with it: its halo and cap are the same picture on
        // every frame. Found in the design review of the motion rebuild: the
        // held day's ripple and cap went on moving under "Loading".
        var liveMarks = function(retro) {
          stub.retro = retro
          wait(50)
          var mark = find(body, retro ? "liveCap" : "liveHalo")
          var moving = function() { return retro ? mark.opacity < 1 : mark.scale > 1.2 }
          var reached = false
          for (var t = 0; t < 3000 && !reached; t += 10) { wait(10); reached = moving() }
          var colour = String(status.color)
          var at = retro ? mark.opacity : mark.scale
          body.surfaceOpen = false
          wait(200)
          var held = [body.heroLive, String(status.color) === colour, (retro ? mark.opacity : mark.scale) === at].join(",")
          body.surfaceOpen = true
          var before = retro ? mark.opacity : mark.scale
          var goesOn = false
          for (var u = 0; u < 2000 && !goesOn; u += 10) { wait(10); goesOn = (retro ? mark.opacity : mark.scale) !== before }
          stub.range = "1Y"
          stub.historyEntry = null
          grab.source = body.chartItem
          grab.begin("loading-live-" + (retro ? "retro" : "smooth"))
          var heldLive = body.chartLoading && body.heroLive
          tryVerify(function() { return grab.frames.length >= 90 }, 5000)
          grab.end()
          tryVerify(function() { return grab.waiting === 0 }, 3000)
          grab.judge("same")
          tryVerify(function() { return grab.verdict !== null }, 10000)
          stub.range = "1D"
          wait(50)
          return reached + "," + held + "," + goesOn + "," + (heldLive && grab.verdict.ok) + " " + grab.verdict.detail
        }
        var smoothLive = liveMarks(false)
        var retroLive = liveMarks(true)
        stub.retro = false
        // An aged quote is said plainly in the hero's listing line, as its row
        // says it; only overdue or failed takes the warning mark. Smooth and
        // retro. Found in the transition audit (data 8): '! AS OF 18:32' in
        // the hero over a plain 'As of 18:32' in the row.
        var listing = find(body, "listingLine")
        var lead = function(retro, age, unanswered) {
          stub.retro = retro
          stub.now = shop.marketTime + age
          stub.entries = Object.assign({}, stub.entries, { "SHOP.TO": { status: "ok", receivedAt: stub.now } })
          stub.asked = unanswered ? { "SHOP.TO": stub.now - unanswered } : {}
          wait(50)
          return listing.text.slice(0, 2)
        }
        var aged = [lead(false, 200, 0), lead(true, 200, 0)]
        var overdue = [lead(false, 200, 91), lead(true, 200, 91)]
        stub.retro = false
        stub.now = liveNow
        stub.entries = Object.assign({}, stub.entries, { "SHOP.TO": { status: "ok", receivedAt: liveNow } })
        stub.asked = {}
        wait(50)
        root.check("the hero says an aged quote plainly and marks only a warning, smooth and retro",
          aged.every(function(t) { return t === "AS" }) && overdue.every(function(t) { return t === "! " }),
          aged.join(",") + " | " + overdue.join(","))
        root.check("a closing surface, and a live day held while the next chart loads, hold the live marks: the words' colour and the ripple, smooth and retro — "
          + smoothLive + " | " + retroLive,
          /^true,true,true,true,true,true /.test(smoothLive) && /^true,true,true,true,true,true /.test(retroLive))

        // The header's words keep the animal's place in both looks, drawn or
        // not. Found offscreen: featuring a symbol whose first quote was
        // still out (every add) moved retro's 48 px left, then back; and a
        // look switch moved them 50 px, since only retro had an animal.
        var places = []
        ;[false, true].forEach(function(retro) {
          stub.retro = retro
          stub.featuredSymbol = "LOAD"
          wait(50)
          places.push(xIn(status, 0))
          stub.featuredSymbol = "SHOP.TO"
          wait(50)
          places.push(xIn(status, 0))
        })
        root.check("the header's words hold still across looks and while a symbol's first quote is out",
          places.every(function(x) { return x === places[0] }) && places[0] > 0, places.join(", "))
        stub.retro = false
        wait(50)

        // The look icon's tooltip shows inside the card, in both looks.
        // Found in the first run: it drew across the card's top edge.
        var toggle = find(body, "lookToggle")
        // A popup is no child item: it is among the toggle's data.
        var tip = null
        for (var d = 0; d < toggle.data.length; d++) if (toggle.data[d].objectName === "lookTip") tip = toggle.data[d]
        var inside = []
        ;[false, true].forEach(function(retro) {
          stub.retro = retro
          mouseMove(toggle, toggle.width / 2, toggle.height / 2)
          for (var t = 0; t < 2000 && !tip.opened; t += 20) wait(20)
          var a = tip.background.mapToItem(body, 0, 0)
          var b = tip.background.mapToItem(body, tip.background.width, tip.background.height)
          inside.push(tip.opened && a.x >= 0 && a.y >= 0 && b.x <= body.width && b.y <= body.height)
          inside.push([Math.round(a.x), Math.round(a.y), Math.round(b.x), Math.round(b.y)].join(" "))
          mouseMove(body, body.width / 2, 20)
          for (t = 0; t < 2000 && tip.visible; t += 20) wait(20)
        })
        root.check("the look icon's tooltip shows inside the card, smooth and retro",
          inside[0] === true && inside[2] === true, inside.join(" | ") + " in " + body.width + "x" + body.height)
        stub.retro = false
        wait(50)

        // A new order is a new arrangement: every row takes its place at once.
        // Found live: o slid every row through the others for 110 ms.
        var placed = function() {
          return stub.view.shown.every(function(s, i) { return body.watchlist.rowItem(s).y === i * body.rowPitch })
        }
        var where = function() {
          return stub.view.shown.map(function(s, i) { return s + "@" + body.watchlist.rowItem(s).y + "/" + i * body.rowPitch })
            .filter(function(text, i) { return body.watchlist.rowItem(stub.view.shown[i]).y !== i * body.rowPitch }).slice(0, 4).join(" ")
        }
        stub.order = "pct"
        wait(20)
        root.check("a new order places every row at once", placed(), where())
        // So does the same order the other way: a flip read as a resort would
        // slide every row through the others.
        var unreversed = stub.view.shown[0]
        stub.reversed = true
        wait(20)
        root.check("a reversed order places every row at once", placed() && stub.view.shown[0] !== unreversed, where())
        stub.reversed = false
        stub.order = "manual"
        wait(200)

        // The order word shows its direction with an arrow, on one line, and
        // no order moves anything: a flip moves nothing beside it, the word's
        // ends and the rule's, and every order, manual included, holds the
        // word's top, bottom, and right end, and the first row's top. Manual's
        // arrow came from a fallback font 1 px taller, and dropped the rows.
        // In both looks, both widths.
        var word = find(body, "orderLabel")
        var rule = find(body, "breadthRule")
        var wordFaults = []
        var wants = { manual: ["↕  MANUAL"], symbol: ["↑  SYMBOL", "↓  SYMBOL"], name: ["↑  NAME", "↓  NAME"],
          pct: ["↓  % CHANGE", "↑  % CHANGE"], abs: ["↓  $ CHANGE", "↑  $ CHANGE"] }
        for (var ow = 0; ow < 2; ow++) {
          surface.wide = ow === 1
          for (var olook = 0; olook < 2; olook++) {
            stub.retro = olook === 1
            var held = []
            Object.keys(wants).forEach(function(order) {
              stub.order = order
              var at = []
              var spot = (surface.wide ? "window " : "popup ") + (stub.retro ? "retro " : "smooth ") + order
              for (var dir = 0; dir < wants[order].length; dir++) {
                stub.reversed = dir === 1
                wait(20)
                if (word.text !== wants[order][dir] || word.lineCount !== 1 || word.truncated
                    || xIn(word, 0) <= xIn(rule, rule.width) || xIn(word, word.width) > body.width)
                  wordFaults.push(spot + (dir ? " reversed" : "") + ": \"" + word.text + "\" " + word.lineCount + " lines")
                at.push([xIn(word, 0), xIn(word, word.width), yIn(word, 0), yIn(word, word.height), xIn(rule, rule.width)].join(","))
                var firstRow = body.watchlist.rowItem(body.watchlist.displayedSymbols[0])
                held.push({ order: order + (dir ? " reversed" : ""), at: [yIn(firstRow, 0), yIn(word, 0), yIn(word, word.height), xIn(word, word.width)].join(",") })
              }
              if (at.length > 1 && at[0] !== at[1]) wordFaults.push(spot + " moved: " + at.join(" -> "))
            })
            if (!held.every(function(h) { return h.at === held[0].at }))
              wordFaults.push((surface.wide ? "window " : "popup ") + (stub.retro ? "retro" : "smooth")
                + " across orders (first row's top, word's top, bottom, right): "
                + held.map(function(h) { return h.order + " " + h.at }).join(" / "))
          }
        }
        stub.reversed = false
        stub.order = "manual"
        stub.retro = false
        surface.wide = false
        wait(200)
        root.check("the order word names its direction on one line, and no order or flip moves it or the rows, in both looks at both widths",
          wordFaults.length === 0, wordFaults.join(" | "))

        // Every key-hint row is one line, never elided or wrapped, inside the
        // surface, and names six keys at most: in both looks at both widths.
        var manage = find(body, "manageLists")
        var hintRows = [
          { name: "search", view: body.search, open: function() { body.startAdding() }, close: function() { body.cancelAdding() } },
          { name: "a symbol's lists", view: find(body, "symbolLists"), open: function() { body.openSymbolLists("MU") }, close: function() { body.closeListViews() } },
          { name: "manage lists", view: manage, open: function() { body.openManageLists() }, close: function() { body.closeListViews() } },
          { name: "renaming a list", view: manage, open: function() { body.openManageLists(); manage.renaming = true }, close: function() { body.closeListViews() } },
          { name: "deleting a list", view: manage, open: function() { body.openManageLists(); manage.confirming = true }, close: function() { body.closeListViews() } }
        ]
        var badHints = []
        for (var hw = 0; hw < 2; hw++) {
          surface.wide = hw === 1
          for (var hl = 0; hl < 2; hl++) {
            stub.retro = hl === 1
            hintRows.forEach(function(r) {
              r.open()
              wait(50)
              var hint = find(r.view, "keyHints")
              var keys = hint ? hint.text.split("·").length : 0
              var place = (surface.wide ? "window " : "popup ") + (stub.retro ? "retro " : "smooth ") + r.name
              // The whole text, not only its box: a hint that cannot fit fails
              // whether it is elided, wrapped, or left to spill.
              if (!hint || !hint.visible || hint.lineCount !== 1 || hint.truncated || keys > 6
                  || hint.implicitWidth > hint.width + 0.5 || xIn(hint, 0) < 0 || xIn(hint, hint.width) > body.width)
                badHints.push(place + ": " + (hint ? "\"" + hint.text + "\" " + hint.lineCount + " lines, "
                  + (hint.truncated ? "elided, " : "") + keys + " keys, " + Math.ceil(hint.implicitWidth) + " px of text in "
                  + xIn(hint, 0) + "–" + xIn(hint, hint.width) + " of " + body.width : "no hint row"))
              r.close()
              wait(20)
            })
          }
        }
        surface.wide = false
        stub.retro = false
        root.check("every key-hint row is one line, never elided or wrapped, with six keys at most, in both looks at both widths",
          badHints.length === 0, badHints.join(" | "))
        console.log("LAYOUT DONE")
        done.exitCode = root.failures ? 1 : 0
        done.start()
      }
    }
  }

  Timer {
    id: done
    property int exitCode: 0
    interval: 1
    onTriggered: Qt.exit(exitCode)
  }

  Timer {
    interval: 30000
    running: true
    onTriggered: {
      console.log("FAIL layout harness timed out")
      done.exitCode = 1
      done.start()
    }
  }
}
