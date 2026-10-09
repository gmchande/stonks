import QtQuick
import Quickshell
import Quickshell.Io
import "Chart.js" as Chart
import "Fundamentals.js" as Fundamentals
import "History.js" as History
import "Market.js" as Market
import "Overnight.js" as Overnight
import "Settings.js" as Settings
// The one data owner. Data settings live in grvc.stonks.json and are
// written only here, including what you are looking at: the list, the
// featured symbol, and the chart range the popup and the window share.
// List membership follows Settings.js's rules; this file persists their result.
Item {
  id: root

  property var dataSettings: Settings.fileSettings(null)
  property bool pluginsReady: false
  // The data file is there but can't be read: empty, not JSON, or not an
  // object. The settings in memory stay, the defaults if it never could be
  // read, and changes still apply to them, but nothing is written until the
  // file reads again, so a typo in it never costs the user's lists.
  property bool settingsUnreadable: false
  property int now: Math.floor(Date.now() / 1000)
  // A symbol whose fundamentals were asked for before its first quote.
  property string pendingFundamentals: ""
  // What the last removal took and the settings from just before it.
  property var lastRemoval: null
  // Symbols just added whose first answer is not in: neither a quote nor a
  // first fetch that failed for good. They are members, saved and fetched,
  // but no list shows them until then.
  property var arriving: []
  // The surfaces open now: the popup on any bar, the window. The chart's
  // history is wanted only while one is (`surfaceShown`).
  property var openSurfaces: []
  // The search result a surface's hero shows unadded, the keyboard's choice
  // while its search is open (`preview`); "" when none is. Never saved.
  property string previewSymbol: ""
  // The surface whose search it is: one search previews at a time, and
  // another surface's search that starts choosing takes it.
  property var previewSurface: null
  // The choice has rested on it: only then are its quote, its range's
  // history, and its cap and P/E asked for.
  property bool previewRests: false
  // The symbols whose quotes are kept fresh now: the featured symbol, which
  // the pill shows; every stock, ETF, and index in All through its own
  // regular session, so an open finds the rows fresh (`Market.staysWarm`);
  // and all of All while a surface is open. Each is asked for on its own
  // market's clock (`askDue`).
  property var watched: []

  readonly property string dataPath: Quickshell.env("HOME") + "/.config/omarchy/grvc.stonks.json"
  // The last good quotes, shown at start until each one's first answer.
  readonly property string quotesPath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache")
    + "/grvc.stonks/quotes.json"

  // All, the library: every symbol, fetched once each whatever lists hold it.
  readonly property var library: dataSettings.symbols
  // The current list: "" for All. Its symbols in manual order are the rows.
  readonly property string listName: dataSettings.list
  readonly property var lists: Settings.listChoices(dataSettings)
  // Every member of the current list, in manual order, arriving ones too.
  readonly property var symbols: Settings.listSymbols(dataSettings)
  readonly property string order: Settings.listOrder(dataSettings)
  readonly property bool reversed: Settings.listReversed(dataSettings)
  readonly property string range: dataSettings.range
  // The popup's first-run hint has shown.
  readonly property bool hinted: dataSettings.hinted
  // What the surfaces show of the settings, as one value, so a change of it
  // is whole whatever changed: the hero, the range, the list and its key
  // (`listKey`), which tells a rename from a switch, its order and
  // direction, its rows (members that have answered), those rows as sorted,
  // All, and the chart asked for once it is ready.
  // Read straight from the settings and the feeds, not from the bindings
  // above, which may not have caught up when this one is evaluated.
  readonly property var view: {
    var all = dataSettings.symbols
    var order = Settings.listOrder(dataSettings)
    var reversed = Settings.listReversed(dataSettings)
    var rows = Settings.listSymbols(dataSettings).filter(function(s) { return arriving.indexOf(s) < 0 })
    var named = String(dataSettings.featured || "").toUpperCase()
    var featured = all.indexOf(named) >= 0 ? named : (all[0] || "")
    var range = dataSettings.range
    // Receipts and histories are read only when the chart needs them, so a
    // receipt for a quoted symbol on the day recomputes nothing here.
    var chart = Chart.viewChart(featured, range, feed.quotes,
      feed.quotes[featured] ? ({}) : feed.entries, range === "1D" ? ({}) : historyFeed.entries,
      overnightFeed.entries, allDayFeed.entries, calendars)
    root.keepDay(featured, chart, overnightFeed.entries, allDayFeed.entries)
    return {
      featured: featured,
      range: range,
      list: dataSettings.list,
      listKey: root.listKey(dataSettings.list),
      order: order,
      reversed: reversed,
      rows: rows,
      shown: Settings.sortedSymbols(rows, feed.quotes, order, reversed),
      library: all,
      // The chart asked for once it can be drawn (`Chart.viewChart`), null
      // while it is on its way: each surface keeps the one it has on screen.
      chart: chart
    }
  }
  // The view with the preview as its hero, unadded: the rows and the range
  // as they are, and its chart once it can be drawn. The view itself while
  // there is none. A symbol in All has its chart as it does featured; a US
  // listing outside it has Yahoo's own day: Robinhood is asked only for All.
  readonly property var previewView: {
    var symbol = root.previewSymbol
    if (!symbol) return view
    var own = !!previewFeed.quotes[symbol] || !!previewFeed.entries[symbol]
    var quotes = own ? previewFeed.quotes : feed.quotes
    var entries = own ? previewFeed.entries : feed.entries
    var range = view.range
    var nights = own ? ({}) : overnightFeed.entries
    var allDay = own ? null : allDayFeed.entries
    var chart = Chart.viewChart(symbol, range, quotes, quotes[symbol] ? ({}) : entries,
      range === "1D" ? ({}) : historyFeed.entries, nights, allDay, calendars)
    root.keepDay(symbol, chart, nights, allDay)
    return Object.assign({}, view, { featured: symbol, chart: chart })
  }
  readonly property var previewEntries: previewFeed.entries
  readonly property string featuredSymbol: view.featured
  readonly property string changeMode: dataSettings.changeMode === "abs" || dataSettings.changeMode === "open"
    ? dataSettings.changeMode : "pct"
  readonly property bool retro: dataSettings.style === "retro"
  readonly property int refreshIntervalSec: dataSettings.refreshIntervalSec
  readonly property var quotes: feed.quotes
  readonly property var entries: feed.entries
  // Each symbol asked for and not yet answered, with the second it was asked.
  readonly property var asked: feed.asked
  readonly property var histories: historyFeed.entries
  readonly property var fundamentals: fundamentalsFeed.entries
  readonly property var shown: view.shown
  // Every US stock and ETF, by its quote (`Overnight.hasOvernight`), never by
  // what Robinhood answers: Robinhood is asked whether it trades each all day.
  readonly property var overnightSymbols: library.filter(function(s) {
    return !!feed.quotes[s] && Overnight.hasOvernight(feed.quotes[s], calendars)
  })
  // Those Robinhood trades all day, the only ones asked for its prints.
  readonly property var allDaySymbols: overnightSymbols.filter(function(s) {
    return !!allDayFeed.entries[s] && allDayFeed.entries[s].allDay
  })
  // Robinhood is asked only while a surface is open, the one place its
  // answers show: whether it trades a listing all day, once a day each
  // (`Overnight.allDayDue`); and the prints of those it does, for each one
  // it has not answered for, and for all of them as a night goes
  // (`Overnight.overnightDue`). Looked at as the clock ticks, the listings
  // change, and a surface opens.
  function askOvernight() {
    if (!root.pluginsReady || root.openSurfaces.length === 0) return
    allDayFeed.fetch(root.overnightSymbols.filter(function(s) {
      return Overnight.allDayDue(allDayFeed.entries[s], root.now)
    }), root.now)
    if (root.allDaySymbols.length === 0) return
    var failed = root.allDaySymbols.some(function(s) {
      return !!overnightFeed.entries[s] && overnightFeed.entries[s].status === "failed"
    })
    if (Overnight.overnightDue(overnightFeed.askedAt, root.now, root.calendars, failed)) {
      overnightFeed.fetch(root.allDaySymbols, root.now)
      return
    }
    overnightFeed.fetch(root.allDaySymbols.filter(function(s) { return !overnightFeed.entries[s] }), root.now)
  }
  onNowChanged: {
    askOvernight()
    askDue()
    flushQuotes()
  }
  onOvernightSymbolsChanged: askOvernight()
  onAllDaySymbolsChanged: askOvernight()

  // What is watched (`watched`), and of it what is due: a symbol whose last
  // answer, ok or failed, is as old as its own market's cadence
  // (`Market.quoteCadence`), the hero of an open surface on the interval.
  // First answers are the feed's own. Looked at each second, as a surface
  // opens, and as the featured symbol changes.
  function askDue() {
    if (!root.pluginsReady) return
    var open = root.openSurfaces.length > 0
    var featured = root.view.featured
    var watched = root.library.filter(function(s) {
      return open || s === featured || Market.staysWarm(feed.quotes[s], root.now, root.calendars)
    })
    if (watched.join(",") !== root.watched.join(",")) root.watched = watched
    feed.ask(watched.filter(function(s) {
      var entry = feed.entries[s]
      if (!entry || entry.status === "saved") return false
      var hero = open && (s === featured || (root.previewRests && s === root.previewSymbol))
      return root.now - entry.answeredAt >= Market.quoteCadence(feed.quotes[s], root.now, root.refreshIntervalSec, hero, root.calendars)
    }), root.now)
  }
  // The day last built for each symbol's chart, kept while what built it is
  // the same: its quote, and for a listing Robinhood trades all day its
  // prints, read from the answers the chart was built from (`nights`,
  // `allDay`, as `Chart.viewChart` took them), so an own preview's Yahoo day
  // is never handed to the same symbol's calendar day once it is added. An
  // answer for another symbol hands the chart the objects it has and nothing
  // that draws it repaints. Written in place by the views alone; it notifies
  // nothing.
  readonly property var builtDays: ({})
  function keepDay(symbol, chart, nights, allDay) {
    if (!chart || !chart.quote || chart.day === chart.quote) return
    var tradability = allDay ? allDay[symbol] : null
    var night = tradability && tradability.allDay ? nights[symbol] : null
    var bars = night ? night.bars : null
    var built = builtDays[symbol]
    if (built && built.quote === chart.quote && built.bars === bars) {
      chart.day = built.day
      chart.latest = built.latest
    } else {
      builtDays[symbol] = { quote: chart.quote, bars: bars, day: chart.day, latest: chart.latest }
    }
  }

  FileView {
    id: calendarFile
    path: Qt.resolvedUrl("calendars.json")
    blockLoading: true
    printErrors: false
  }

  readonly property var calendars: {
    try { return JSON.parse(calendarFile.text()) } catch (e) { return null }
  }

  FileView {
    id: shellFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    blockLoading: true
    printErrors: false
  }

  FileView {
    id: dataFile
    path: root.dataPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: dataFile.reload()
    onLoaded: root.takeLoadedSettings()
    // Only a file that isn't there is missing: one there that can't be
    // read, for its permissions or as a folder, is never written over.
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) root.takeMissingFile()
      else root.takeUnreadableFile()
    }
    onSaveFailed: function(error) {
      console.warn("stonks: failed to write " + root.dataPath + ": " + error)
    }
  }

  Gate {
    id: yahooGate
    host: "Yahoo"
    clock: root
    onReopened: root.showHistory(false)
  }
  // Robinhood is asked for its prints and its instruments as a surface
  // opens, as US listings are added, every 5 minutes through a night, and on
  // r: a few a minute, more while adding, so the budget only stops a
  // runaway.
  Gate {
    id: robinhoodGate
    host: "Robinhood"
    clock: root
    capacity: 20
    perMinute: 10
  }
  readonly property alias yahooGate: yahooGate

  QuoteFeed {
    id: feed
    symbols: root.pluginsReady ? root.library : []
    watched: root.watched
    lead: root.view.featured
    now: root.now
    gate: yahooGate
  }

  // One chart's history at a time; an answer may leave another chart a
  // refresh still owes, or one with no answer yet, which is asked for next.
  HistoryFeed {
    id: historyFeed
    gate: yahooGate
    onEntriesChanged: {
      var owed = root.owedHistory()
      if (owed.length > 0) historyFeed.request(owed[0], root.view.range, true)
      else {
        var unanswered = root.unansweredHistory()
        if (unanswered.length > 0) historyFeed.request(unanswered[0], root.view.range, false)
      }
    }
  }
  // The preview's quote, fetched once when the choice rests on a symbol
  // outside All, and never refreshed: not on the timer, not by `r`.
  QuoteFeed {
    id: previewFeed
    symbols: root.previewRests && root.previewSymbol !== "" && root.library.indexOf(root.previewSymbol) < 0
      ? [root.previewSymbol] : []
    now: root.now
    gate: yahooGate
    bulk: false
    onQuotesChanged: if (root.pendingFundamentals) root.fetchFundamentals(root.pendingFundamentals)
  }

  FundamentalsFeed { id: fundamentalsFeed; gate: yahooGate }
  AllDayFeed { id: allDayFeed; now: root.now; gate: robinhoodGate }
  OvernightFeed { id: overnightFeed; now: root.now; gate: robinhoodGate }

  // A user's refresh, from a key, the pill, or IPC: every watched quote
  // whose last answer is more than 10 s old, and, with a surface open to
  // show them, the overnight prints unless asked for in the last 10 s, so a
  // second press adds nothing; and the chart's history fresh whatever the
  // cache holds.
  function refresh() {
    if (root.pluginsReady) {
      feed.ask(root.watched.filter(function(s) {
        var entry = feed.entries[s]
        return !!entry && entry.status !== "saved" && root.now - entry.answeredAt > 10
      }), root.now)
      root.showHistory(true)
      if (root.openSurfaces.length > 0 && root.now - overnightFeed.askedAt > 10)
        overnightFeed.fetch(root.allDaySymbols, root.now)
    }
  }

  // The history the open surfaces' heroes show on the shared range: the
  // featured symbol's, on every open surface but the one previewing, and
  // the preview's once the choice rests on it. The day needs none, and
  // neither does the pill, which always shows the day. One request at a
  // time: a chart a user's refresh (`force`) still owes first, fetched
  // fresh, then one with no answer yet, else the last, the preview.
  function showHistory(force) {
    if (!root.pluginsReady) return
    var charts = root.historyCharts()
    if (charts.length === 0) {
      root.historyOwed = ({})
      historyFeed.clear()
      return
    }
    var range = root.view.range
    if (force) {
      var owing = {}
      charts.forEach(function(s) {
        var key = historyFeed.keyFor(s, range)
        owing[key] = historyFeed.entries[key] || null
      })
      root.historyOwed = owing
    }
    var owed = root.owedHistory()
    if (owed.length > 0) {
      historyFeed.request(owed[0], range, true)
      return
    }
    var unanswered = root.unansweredHistory()
    historyFeed.request(unanswered.length > 0 ? unanswered[0] : charts[charts.length - 1], range, false)
  }

  // The charts a user's refresh asked for fresh, each with the answer it had
  // then: one is owed until a new answer, ok or failed, replaces that.
  property var historyOwed: ({})
  function owedHistory() {
    var range = root.view.range
    return root.historyCharts().filter(function(s) {
      var key = historyFeed.keyFor(s, range)
      return key in root.historyOwed && historyFeed.entries[key] === root.historyOwed[key]
    })
  }

  // The symbols whose history the open surfaces' heroes show.
  function historyCharts() {
    if (root.openSurfaces.length === 0 || root.view.range === "1D") return []
    var charts = []
    if (root.previewSymbol === "" || root.openSurfaces.some(function(s) { return s !== root.previewSurface }))
      charts.push(root.view.featured)
    if (root.previewSymbol !== "" && root.previewRests && charts.indexOf(root.previewSymbol) < 0)
      charts.push(root.previewSymbol)
    return charts.filter(function(s) { return s !== "" })
  }

  // Those of them with no answer yet, ok or failed.
  function unansweredHistory() {
    var range = root.view.range
    return root.historyCharts().filter(function(s) { return !historyFeed.entries[historyFeed.keyFor(s, range)] })
  }

  // A surface's search shows its choice on the hero (`previewView`), or
  // nothing with "", which only the search previewing can say. What it
  // needs is asked for only once the choice has rested there, so arrowing
  // past a result asks for nothing.
  function preview(surface, symbol) {
    var s = String(symbol || "").trim().toUpperCase()
    if (!s && surface !== root.previewSurface) return
    if (s === root.previewSymbol && surface === root.previewSurface) return
    var before = root.previewSurface
    // The rest first: a choice that moves on has not rested on the next one.
    root.previewRests = false
    root.previewSurface = s ? surface : null
    root.previewSymbol = s
    if (s) previewRest.restart()
    else previewRest.stop()
    root.showHistory(false)
    if (before && before !== root.previewSurface && s) root.previewTaken(before)
  }

  // Another surface's search took the preview `surface` had.
  signal previewTaken(var surface)

  Timer {
    id: previewRest
    interval: 250
    onTriggered: {
      root.previewRests = true
      root.showHistory(false)
      root.fetchFundamentals(root.previewSymbol)
    }
  }

  // A surface says when it opens and closes, and as it goes.
  function surfaceShown(surface, open) {
    var others = root.openSurfaces.filter(function(s) { return s !== surface })
    var next = open ? others.concat([surface]) : others
    if (next.length === root.openSurfaces.length) return
    root.openSurfaces = next
    root.showHistory(false)
    root.askOvernight()
    root.askDue()
  }

  // Asked for once per change of the chart asked for, read from the view, so
  // a change of symbol and range together is one request, never a mixed pair.
  property string chartOnShow: ""
  onViewChanged: {
    var chart = view.featured + "|" + view.range
    if (chart === chartOnShow) return
    chartOnShow = chart
    showHistory(false)
    askDue()
  }

  function setRange(value) {
    if (History.historyRanges().indexOf(value) >= 0) root.persist({ range: value })
  }

  // An open surface asks for the hero's cap and P/E: the featured symbol's,
  // or a preview's. One asked for before its quote goes when the quote
  // lands, and only an equity's.
  function fetchFundamentals(symbol) {
    var normalized = String(symbol || "").toUpperCase()
    var quote = root.quotes[normalized] || previewFeed.quotes[normalized]
    if (!quote) {
      root.pendingFundamentals = normalized
      return
    }
    root.pendingFundamentals = ""
    if (Fundamentals.hasFundamentals(quote)) fundamentalsFeed.fetch(normalized)
  }

  onQuotesChanged: {
    if (pendingFundamentals) fetchFundamentals(pendingFundamentals)
    settleArrivals()
  }
  // Every run's answers land in the entries, after their quotes, whether or
  // not a quote changed: the last good quotes are saved from there.
  onEntriesChanged: {
    settleArrivals()
    if (Object.keys(feed.entries).some(function(s) { return feed.entries[s].status === "ok" })) saveQuotes()
  }
  onLibraryChanged: settleArrivals()

  function answered(symbol) {
    return !!feed.quotes[symbol] || !!(feed.entries[symbol] && feed.entries[symbol].status === "failed")
  }

  // An add leaves arriving once it has answered, or has left All.
  function settleArrivals() {
    var still = root.arriving.filter(function(s) { return root.library.indexOf(s) >= 0 && !root.answered(s) })
    if (still.length !== root.arriving.length) root.arriving = still
  }

  function parseShell() {
    try { return JSON.parse(shellFile.text()) } catch (e) { return null }
  }

  function parseDataText(text) {
    try {
      var parsed = JSON.parse(String(text || "").trim())
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null
      return Settings.fileSettings(parsed)
    } catch (e) {
      return null
    }
  }

  function adopt(settings) {
    root.dataSettings = Settings.fileSettings(settings)
    if (!root.pluginsReady) {
      root.pluginsReady = true
      feed.seed(root.parseSavedQuotes())
      root.askDue()
    }
  }

  FileView {
    id: quotesFile
    path: root.quotesPath
    blockLoading: true
    atomicWrites: true
    printErrors: false
  }

  // The saved quotes, { symbol: { quote, receivedAt } }; none when the file
  // is missing or unreadable.
  function parseSavedQuotes() {
    try {
      var parsed = JSON.parse(quotesFile.text())
      return parsed && parsed.version === 1 && parsed.quotes ? parsed.quotes : {}
    } catch (e) {
      return {}
    }
  }

  // Written as answers come, at most every 10 minutes on the service's
  // clock: at once, then, if more came meanwhile, as the wait ends.
  property bool quotesUnsaved: false
  property int quotesSavedAt: 0
  function saveQuotes() {
    root.quotesUnsaved = true
    root.flushQuotes()
  }

  function flushQuotes() {
    if (!root.quotesUnsaved || (root.quotesSavedAt && root.now - root.quotesSavedAt < 10 * 60)) return
    root.quotesUnsaved = false
    root.quotesSavedAt = root.now
    var saved = {}
    root.library.forEach(function(s) {
      if (feed.quotes[s]) saved[s] = { quote: feed.quotes[s], receivedAt: (feed.entries[s] || {}).receivedAt || 0 }
    })
    if (typeof quotesFile.setText === "function") quotesFile.setText(JSON.stringify({ version: 1, quotes: saved }) + "\n")
  }

  function takeLoadedSettings() {
    var parsed = root.parseDataText(dataFile.text())
    if (!parsed) {
      root.takeUnreadableFile()
      return
    }
    root.settingsUnreadable = false
    if (root.pluginsReady && Settings.settingsEqual(parsed, root.dataSettings)) return
    root.adopt(parsed)
  }

  // The settings in memory stay, the defaults if none were read, and
  // nothing is written until the file reads again.
  function takeUnreadableFile() {
    if (!root.settingsUnreadable)
      console.warn("stonks: " + root.dataPath + " can't be read; saving nothing until it can")
    root.settingsUnreadable = true
    if (!root.pluginsReady) root.adopt(root.dataSettings)
  }

  function takeMissingFile() {
    root.settingsUnreadable = false
    if (!root.pluginsReady) {
      var fromBar = Settings.settingsFromBar(root.parseShell())
      if (fromBar) {
        root.adopt(fromBar)
        root.writeDataFile(fromBar)
        return
      }
    }
    console.warn("stonks: settings file missing; using defaults")
    root.adopt(Settings.fileSettings(null))
  }

  function writeDataFile(settings) {
    var body = JSON.stringify(Settings.fileSettings(settings), null, 2) + "\n"
    if (typeof dataFile.setText !== "function") {
      console.warn("stonks: cannot write " + root.dataPath)
      return
    }
    dataFile.setText(body)
  }

  function persist(values) {
    var next = Settings.fileSettings(root.dataSettings)
    for (var key in values) next[key] = values[key]
    next = Settings.fileSettings(next)
    root.dataSettings = next
    if (!root.pluginsReady || root.settingsUnreadable) return
    root.writeDataFile(next)
  }

  function feature(symbol) {
    var s = String(symbol || "").toUpperCase()
    if (root.library.indexOf(s) < 0) return
    root.persist({ featured: s })
  }

  // The pill's wheel and IPC's next and prev: the next row of the current
  // list, or from outside it its first or last.
  function featureStep(delta) {
    var shown = root.view.shown
    if (shown.length === 0) return
    var at = shown.indexOf(root.view.featured)
    root.feature(at < 0 ? shown[delta > 0 ? 0 : shown.length - 1]
      : shown[(at + delta + shown.length) % shown.length])
  }

  // A summon's symbol and range, in one change.
  function summon(symbol, range) {
    var values = {}
    var s = String(symbol || "").toUpperCase()
    if (s && root.library.indexOf(s) >= 0) values.featured = s
    if (History.historyRanges().indexOf(range) >= 0) values.range = range
    if (Object.keys(values).length) root.persist(values)
  }

  // Every membership change is a Settings.js rule: settings in, settings out.
  function save(next) {
    if (Settings.settingsEqual(next, root.dataSettings)) return
    root.persist(next)
  }

  // A symbol new to All arrives: fetched ahead of any refresh, and shown
  // once it has answered. One already in All is a row at once. The result
  // the hero shows as a preview joins with the answer it has: a quote, and
  // it stays the hero, so nothing is fetched again and the chart does not
  // change; or a first fetch that failed, and the add is done there, its
  // row saying so.
  function addSymbol(symbol) {
    var s = String(symbol || "").trim().toUpperCase()
    if (s && s === root.previewSymbol && previewFeed.entries[s])
      feed.restore(s, previewFeed.quotes[s] || null, previewFeed.entries[s])
    var shown = s !== "" && s === root.previewSymbol && !!feed.quotes[s]
    if (s && root.library.indexOf(s) < 0 && root.arriving.indexOf(s) < 0 && !root.answered(s))
      root.arriving = root.arriving.concat([s])
    var next = Settings.withSymbolAdded(root.dataSettings, s)
    if (shown) next.featured = s
    root.save(next)
  }

  // A featured symbol that leaves hands the hero to its neighbour in `shown`,
  // the rows as the surface shows them; the service's own order otherwise.
  function removeSymbol(symbol, shown) {
    root.remove(symbol, Settings.withMembership(root.dataSettings, symbol, root.listName, false, shown || root.shown))
  }

  // A tick or untick in a symbol's checklist; "" is All. Unticking All is a
  // removal, and can be taken back like one.
  function setMembership(symbol, name, member, shown) {
    var next = Settings.withMembership(root.dataSettings, symbol, name, member, shown || root.shown)
    if (name === "" && !member) root.remove(symbol, next)
    else root.save(next)
  }

  // A removal remembers the settings before it, the hero it left, and the
  // symbol's quote, so it can be taken back as it was without undoing
  // anything chosen since. It is the one
  // removal on offer, whichever surface made it.
  function remove(symbol, next) {
    var before = root.dataSettings
    var quote = feed.quotes[symbol] || null
    var entry = feed.entries[symbol] || null
    root.save(next)
    root.lastRemoval = { symbol: symbol, before: before, left: root.dataSettings.featured, quote: quote, entry: entry }
  }

  // The last removal, put back where it was. Only once.
  function undoRemoval(symbol) {
    if (!root.lastRemoval || root.lastRemoval.symbol !== symbol) return
    var removal = root.lastRemoval
    root.lastRemoval = null
    if (removal.quote) feed.restore(symbol, removal.quote, removal.entry)
    root.save(Settings.withRemovalUndone(root.dataSettings, removal.before, symbol, removal.left))
  }

  // A hand-arranged order of the rows. Members still arriving keep their
  // places, so the order saved holds every member.
  function setManualOrder(rows) {
    var members = root.symbols
    var next = rows.slice()
    for (var i = 0; i < members.length; i++)
      if (next.indexOf(members[i]) < 0) next.splice(Math.min(i, next.length), 0, members[i])
    root.save(Settings.withManualOrder(root.dataSettings, next))
  }

  function setOrder(order) {
    root.save(Settings.withListOrder(root.dataSettings, order))
  }

  // The current sorted order the other way; manual stays as it is.
  function reverseOrder() {
    root.save(Settings.withListReversed(root.dataSettings))
  }

  function switchList(name) {
    root.persist({ list: name })
  }

  function stepList(delta) {
    root.switchList(Settings.steppedList(root.dataSettings, delta))
  }

  // Makes and opens an empty list. Returns why not, or "" once it exists.
  function createList(name) {
    var problem = Settings.listNameProblem(name, root.dataSettings.lists)
    if (problem === "") root.save(Settings.withListCreated(root.dataSettings, name))
    return problem
  }

  // Returns why not, or "" once renamed. The new name takes the list's key
  // before the save, so no view shows the list under another key; the old
  // name, now free, takes a new one after.
  function renameList(name, newName) {
    var problem = Settings.renameProblem(root.dataSettings, name, newName)
    var i = Settings.listIndex(root.dataSettings.lists, name)
    if (problem !== "" || i < 0) return problem
    var old = root.dataSettings.lists[i].name
    var now = Settings.listName(newName)
    if (old !== now) root.keyList(now, root.listKey(old))
    root.save(Settings.withListRenamed(root.dataSettings, name, newName))
    if (old !== now) root.keyList(old, "#" + (++root.listKeyCount))
    return problem
  }

  function moveList(name, delta) {
    root.save(Settings.withListMoved(root.dataSettings, name, delta))
  }

  // A list made later under the deleted one's name is another list.
  function deleteList(name) {
    var i = Settings.listIndex(root.dataSettings.lists, name)
    if (i < 0) return
    var old = root.dataSettings.lists[i].name
    root.save(Settings.withListDeleted(root.dataSettings, name))
    root.keyList(old, "#" + (++root.listKeyCount))
  }

  // Each list's identity for the session, by name, for what is kept by list
  // and not saved (each surface's place in it): a rename keeps it, and a name
  // a rename or a delete freed names another list. A name with no entry is
  // its own key. A list renamed by editing the file is another list.
  property var listKeys: ({})
  property int listKeyCount: 0
  function listKey(name) { return root.listKeys[name] || "=" + name }
  function keyList(name, key) {
    var next = Object.assign({}, root.listKeys)
    next[name] = key
    root.listKeys = next
  }

  Timer {
    interval: 1000
    running: root.pluginsReady
    repeat: true
    onTriggered: root.now = Math.floor(Date.now() / 1000)
  }
}
