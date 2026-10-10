import QtQuick
import qs.Commons
import "Figures.js" as Figures
import "Format.js" as Format
import "Fundamentals.js" as Fundamentals
import "History.js" as History
import "KeySheet.js" as KeySheet
import "Market.js" as Market
import "Quote.js" as Quote
import "Settings.js" as Settings
import "Tones.js" as Tones
// Shared body for the window and the popup: header, hero band, list,
// search, footer, help, and the chart's motion (ChartMotion). It reads the
// service and acts through it; the surface around it keeps its lifecycle,
// keys, and look.
// The footer sits at the bottom; a surface that sizes itself asks
// fittedHeight for a height of whole rows for the list shown, so nothing is
// left over between the rows and the footer.
Item {
  id: root

  // The data owner, or null while it is not ready.
  property var service: null
  // The plugin's version on disk against the one running (`Updates`).
  property var updates: null
  property bool surfaceOpen: false
  property string headerWhenMissing: "No quote"
  property bool failClosedHeader: false
  property int margins: 0
  // Where the surface's visible bottom is, in the body: the popup's card
  // eases its edge to a new height while the body lays out at it at once.
  // What sits at the bottom, the footer or the search field, rides it, and a
  // row below it is out of sight. The window's is its height.
  property real edge: height
  property int bandGap: Style.space(10)
  // From the list's header to its rows, closer than the bands above it, so
  // the header groups with the rows it titles: the shell's own spacing step.
  readonly property int listGap: Style.spacing.md
  property int chartHeight: Style.space(190)
  // The host's look.
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property color upColor: Color.foreground
  property color downColor: Color.urgent
  // The added symbol the chart will change to once its answer is in, its row
  // in view, and the list at rest; "" when none is. The latest add is the
  // one, and a hero chosen meanwhile drops it.
  property string landing: ""
  // The landing row has joined and been eased into view; what is left is to
  // feature it once it and the list are at rest.
  property bool landingJoined: false
  // The landing is a Show of a member still arriving, not an add: it is
  // featured once its first answer is in, a failed one too.
  property bool landingShows: false
  // The surface's own colour, which a moving row carries.
  property color ground: Color.background
  property var rangeOptions: History.historyRanges()

  // A view that had the keys has let them go: the surface takes them back.
  signal keysReleased()

  // The moment the chart shows, the motion's: a scrub or a replay.
  readonly property int scrubT: motion.scrubT
  property bool adding: false
  // The search result the hero shows unadded while search is open: the
  // keyboard's choice (`previewTo`); "" when none is.
  property string previewSymbol: ""
  property bool showingHelp: false
  property bool listMenuOpen: false
  property bool managingLists: false
  // The symbol whose lists the checklist shows; "" while it is closed.
  property string listsSymbol: ""
  property int spriteOverride: 0
  // A short word in the footer's place, for a moment, held while the pointer
  // is on it: why a key did nothing, or what a removal took, which a click
  // on it puts back (`offered`).
  property string note: ""
  // A quiet line in the footer's place for this visit, under any note: the
  // popup's first-run hint (`showFirstRunHint`). The next open clears it.
  property string hint: ""
  function showFirstRunHint() {
    hint = "Drag the pill anywhere · middle-click to change it\nright-click opens the window"
  }
  // A standing word in the footer's place, under a note, until what it says
  // is fixed: the data file can't be read, or an update waits on a shell
  // restart, which a click on it does.
  readonly property string notice: settingsUnreadable ? "grvc.stonks.json can't be read, so changes aren't being saved"
    : updatedTo !== "" ? "Updated to " + updatedTo + " · restart the shell" : ""
  // The removal the footer's note offers back, the service's one removal on
  // offer as the note was said: when another surface makes a newer removal,
  // the lists change, or it is undone, the offer goes, and the note with it.
  property var offered: null
  onRemovalChanged: if (offered !== null && removal !== offered) clearNote()

  // What this surface shows of the service, held in one place: the surface
  // reads the service only while it is open. From a close until the next
  // open each of these keeps what it last read, so nothing on a closing
  // surface changes during the popup's close fade, whatever the service does
  // meanwhile: a chart that lands, a hero chosen on another surface, a
  // removal from All. The next open takes the latest at once.
  readonly property var emptyView: ({ featured: "", range: "1D", list: "", listKey: "=", order: "manual", reversed: false,
    rows: [], shown: [], library: [], chart: null })
  // What the rows show, the hero and the range asked for, and the chart
  // ready for them, as one value: each change of it is whole. While search
  // previews a result, the hero is that result.
  property var view: emptyView
  property var quotes: ({})
  property var entries: ({})
  // The preview's receipt, which says whether its quote failed.
  property var previewEntries: ({})
  // Every symbol's cap and P/E, as the service keeps them.
  property var fundamentalEntries: ({})
  property var lists: []
  // The current list's members, those still arriving included.
  property var members: []
  property var arriving: []
  property var removal: null
  property string changeMode: "pct"
  property bool retro: false
  // Each symbol asked for and not yet answered: freshness's overdue.
  property var asked: ({})
  property bool settingsUnreadable: false
  property string updatedTo: ""
  // The clock: a closed surface's holds still too, so nothing it would show
  // is derived again every second.
  property int now: 0
  readonly property bool reading: surfaceOpen && !!service
  // This surface's preview, while the service's preview is its own.
  readonly property bool previewing: previewSymbol !== "" && !!service && service.previewSurface === root
  Binding on view {
    when: root.reading
    value: root.previewing ? root.service?.previewView : root.service?.view
    restoreMode: Binding.RestoreNone
  }
  Binding on quotes { when: root.reading; value: root.service?.quotes; restoreMode: Binding.RestoreNone }
  Binding on entries { when: root.reading; value: root.service?.entries; restoreMode: Binding.RestoreNone }
  Binding on previewEntries { when: root.reading; value: root.service?.previewEntries; restoreMode: Binding.RestoreNone }
  Binding on fundamentalEntries { when: root.reading; value: root.service?.fundamentals; restoreMode: Binding.RestoreNone }
  Binding on lists { when: root.reading; value: root.service?.lists; restoreMode: Binding.RestoreNone }
  Binding on members { when: root.reading; value: root.service?.symbols; restoreMode: Binding.RestoreNone }
  Binding on arriving { when: root.reading; value: root.service?.arriving; restoreMode: Binding.RestoreNone }
  Binding on removal { when: root.reading; value: root.service?.lastRemoval; restoreMode: Binding.RestoreNone }
  Binding on changeMode { when: root.reading; value: root.service?.changeMode; restoreMode: Binding.RestoreNone }
  Binding on retro { when: root.reading; value: root.service?.retro; restoreMode: Binding.RestoreNone }
  Binding on asked { when: root.reading; value: root.service?.asked; restoreMode: Binding.RestoreNone }
  Binding on settingsUnreadable { when: root.reading; value: root.service?.settingsUnreadable; restoreMode: Binding.RestoreNone }
  Binding on updatedTo { when: root.reading; value: root.updates ? root.updates.newVersion : ""; restoreMode: Binding.RestoreNone }
  Binding on now { when: root.reading; value: root.service?.now; restoreMode: Binding.RestoreNone }

  readonly property var symbols: view.rows
  // The current list, "" for All.
  readonly property string listName: view.list
  readonly property string listLabel: listName !== "" ? listName : "All"
  readonly property var shown: view.shown
  readonly property var calendars: service ? service.calendars : null
  readonly property string featuredSymbol: view.featured
  readonly property string range: view.range
  readonly property string order: view.order
  readonly property bool reversed: view.reversed
  // The chart on screen, the motion's: the view's once it can be drawn, and
  // until then the one already on screen, as it was, so the hero keeps what
  // it showed, chart, figures, and info lines alike, until the new one is in
  // and draws in. Null only before any chart has been in. There is never a
  // third state.
  readonly property var chart: motion.chart
  // The chart asked for is still on its way: what is on screen is another.
  readonly property bool chartLoading: motion.loading
  readonly property string chartSymbol: chart ? chart.symbol : ""
  readonly property string chartRange: chart ? chart.range : "1D"
  readonly property var fundamentals: chartSymbol ? fundamentalEntries[chartSymbol] || null : null
  readonly property color dim: Tones.dim(foreground, ground)
  readonly property color dimmer: Tones.dimmer(foreground, ground)
  readonly property color ghost: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  readonly property int rowHeight: Style.space(30)
  readonly property int listRowHeight: Style.space(40)
  readonly property int rowGap: Style.space(2)
  readonly property int rowPitch: listRowHeight + rowGap

  // The chart on screen as the motion measures it, and the moment it shows.
  readonly property bool historyActive: motion.historyActive
  readonly property var history: motion.history
  // A range whose first fetch failed: the day stands in, figures and all.
  readonly property bool historyFailed: !!chart && chart.failed
  // From this body's own `history`, not the motion's `historyShown`: what
  // reads both here then sees them change together, never a shown history
  // that is not there yet.
  readonly property bool historyShown: historyActive && !!history
  readonly property var historyStats: historyShown ? History.periodStats(history) : null
  readonly property var historyBar: historyShown && scrubT
    ? History.historyBarAt(history, History.historyFraction(history, scrubT)) : null
  readonly property int scrubShown: motion.scrubShown
  // The rows show the day: they follow a scrub of it, and stay on now while
  // one reads a range, or the 1D chart's hours outside Yahoo's day, before
  // it or the night after it.
  readonly property int watchlistScrubShown: historyActive || !featuredQuote || scrubShown < Quote.dayStart(featuredQuote)
    || (!!featuredDay.axis && scrubShown >= Quote.dayEnd(featuredQuote)) ? 0 : scrubShown
  // Yahoo's quote: the headline and the day's figures, at rest.
  readonly property var featuredQuote: motion.quote
  // The day the 1D chart draws, which a scrub of it reads: its prints, and
  // its baseline as `prevClose` (`Chart.viewChart`).
  readonly property var featuredDay: motion.day
  readonly property var featuredFreshness: Figures.freshness(entryOf(chartSymbol || featuredSymbol), featuredQuote, now,
    asked[chartSymbol || featuredSymbol] || 0)
  readonly property var featuredGeometry: motion.geometry
  readonly property real scrubX: motion.scrubX
  readonly property bool dayScrubbed: !historyActive && scrubShown !== 0
  readonly property var dailyFeatured: featuredQuote
    ? Figures.rowModel(dayScrubbed ? featuredDay : featuredQuote, dayScrubbed ? scrubShown : 0, changeMode) : null
  readonly property var featured: historyShown ? History.historyRowModel(history, featuredQuote, scrubShown) : dailyFeatured
  // A live marker is honest only when the headline and chart endpoint are the same day quote.
  readonly property bool heroLive: (!historyActive || historyFailed)
    && !scrubT && featuredFreshness.live
  // The header's animal, in both looks: the direction of the moment shown
  // against the baseline, a bull up and a bear down, and none on a flat day
  // (`dayTone`) or before a direction is known; Shift-click's choice first.
  readonly property string animalKind: spriteOverride === 1 ? "bull" : spriteOverride === 2 ? "bear"
    : !featured || featured.dayTone === "flat" ? "" : featured.dayTone === "up" ? "bull" : "bear"
  // What it reads, the chart as the motion tells charts apart (a failed
  // range's stand-in day is another chart than its history), the list, and
  // the look: a change of it is no turn, so the animal changes at once.
  readonly property string animalChart: [motion.chartKeyOf(chart), view.listKey, retro].join(" ")
  readonly property var animal: ({ kind: animalKind, chart: animalChart })
  // The info block describes what the chart shows: the range's statistics,
  // or the day's when the chart is the day. Before any chart, nothing.
  readonly property string periodText: !chart ? "" : historyShown ? History.historyStatsText(history, historyStats, featuredQuote ? featuredQuote.priceDigits : undefined)
    : Figures.dayStatsText(featuredQuote)
  readonly property string keyStatsText: chart ? Fundamentals.keyStatsText(featuredQuote, fundamentals ? fundamentals.figures : null) : ""
  // What the dashed line is, said while a scrub reads against it.
  readonly property string baselineText: historyShown ? chartRange.toUpperCase() + " START " + Format.money(history.baseline, featuredQuote ? featuredQuote.priceDigits : undefined)
    : (!historyActive && featuredDay ? "PREV CLOSE " + Format.money(featuredDay.prevClose, featuredDay.priceDigits) : "")
  readonly property string headerText: {
    if (!service) return headerWhenMissing
    // The chart asked for is on its way, named: what was on show stays.
    if (chartLoading) return "Loading " + featuredSymbol + (range !== "1D" ? " " + range : "")
    if (failClosedHeader && !featuredQuote && featuredFreshness && featuredFreshness.state === "failed")
      return "No quote"
    if (historyActive && historyFailed) return chartRange.toUpperCase() + " unavailable · R to retry"
    // A refetch, out or failed, with the range in hand says nothing: it
    // keeps the chart and the market.
    if (historyShown && historyBar) return History.historyScrubText(history, historyBar, featuredQuote ? featuredQuote.priceDigits : undefined,
      featuredQuote ? Market.calendarFor(calendars, featuredQuote) : null)
    if (featuredQuote) return Market.marketStatus(dayScrubbed ? featuredDay : featuredQuote, now, scrubShown, calendars)
    return headerWhenMissing
  }
  // Everything but the rows: margins, header, band, and footer, one gap
  // apart, and the list's own gap from its header.
  readonly property int chromeHeight: margins * 2 + header.height + heroBand.implicitHeight + footer.height + bandGap * 2 + listGap
  readonly property int helpHeight: margins * 2 + header.height + bandGap + helpSheet.contentHeight
  // Search needs room for the field and a full set of results, never less
  // because the list it replaces is short. Until its first answer arrives
  // the rows stay where they are, above the field; from then until the field
  // is empty, search's answer shows in their place.
  readonly property bool searching: adding && search.answer !== ""
  readonly property int searchHeight: margins * 2 + header.height + heroBand.implicitHeight
    + bandGap + listGap + search.desiredHeight
  readonly property int wholeListHeight: wholeRowsHeight(height - chromeHeight)
  readonly property int listMenuTop: margins + header.height + bandGap + heroBand.implicitHeight + Style.space(4)
  // The menu ends one gap above the footer, which stays in sight under it.
  readonly property int listMenuBottom: listMenuTop + listMenu.contentHeight + bandGap + footer.height + margins
  // Manage lists and a symbol's lists take the rows' and the footer's place,
  // at their own height.
  readonly property bool listViewOpen: managingLists || listsSymbol !== ""
  readonly property int listViewHeight: margins * 2 + header.height + heroBand.implicitHeight + bandGap + listGap
    + (managingLists ? manageLists.contentHeight : symbolLists.contentHeight)
  // The rows are what the body shows under the band, not the key sheet,
  // search's results, or a list view.
  readonly property bool rowsShown: !showingHelp && !searching && !listViewOpen
  // While any of these is open it has the keys, not the surface.
  readonly property bool ownsKeys: adding || listMenuOpen || listViewOpen
  readonly property var keySheet: KeySheet.sheet(order)
  // The rows' mood, for the rule under the list name; it follows the scrub
  // as the rows do, and names its list, so the rule tells a switch from a
  // change. Read from the view, list and rows at once: `symbols` may not
  // have caught up with a switch when this is evaluated.
  readonly property var breadth: Object.assign({ list: view.list },
    Figures.listBreadth(view.rows, quotes, watchlistScrubShown, changeMode))
  readonly property alias watchlist: watchlist
  readonly property alias search: search
  readonly property alias chartItem: heroBand.chartItem
  readonly property alias motion: motion

  function entryOf(symbol) {
    if (entries && entries[symbol]) return entries[symbol]
    return previewEntries && previewEntries[symbol] ? previewEntries[symbol] : null
  }

  // The height of `count` rows, as many whole ones as fit in `space`.
  function rowsHeight(count, space) {
    var rows = Math.min(count, Math.floor((Math.max(0, space) + rowGap) / rowPitch))
    return rows > 0 ? rows * rowPitch - rowGap : 0
  }

  // The list's height in whole rows. An empty named list keeps one row,
  // which says so; All is never empty.
  function wholeRowsHeight(space) {
    return rowsHeight(listName !== "" ? Math.max(1, symbols.length) : symbols.length, space)
  }

  // The body's height within `maxHeight`: the key sheet's own height while it
  // shows, a list view's own, otherwise whole rows for the list shown, the
  // footer one gap under them. Search takes its height as it opens, before
  // any typing: the field and a full set of results, or the rows' height
  // when that is taller, the spare room above the field, so the field never
  // moves while you type. An open list menu taller than the rows makes room
  // for itself and for the footer under it.
  function fittedHeight(maxHeight) {
    if (showingHelp) return Math.min(maxHeight, helpHeight)
    if (listViewOpen) return Math.min(maxHeight, listViewHeight)
    var rows = chromeHeight + wholeRowsHeight(maxHeight - chromeHeight)
    if (adding) return Math.min(maxHeight, Math.max(rows, searchHeight))
    return listMenuOpen ? Math.max(rows, Math.min(maxHeight, listMenuBottom)) : rows
  }

  // A hero chosen while an add is still coming wins over the add.
  onFeaturedSymbolChanged: if (featuredSymbol !== landing) landing = ""

  // The service wants the chart's history only while a surface shows it,
  // and a preview only while its search is open on an open surface.
  onSurfaceOpenChanged: {
    if (service) service.surfaceShown(root, surfaceOpen)
    if (!surfaceOpen) previewTo("")
  }
  onServiceChanged: if (service && surfaceOpen) service.surfaceShown(root, true)
  Component.onDestruction: if (service) {
    service.surfaceShown(root, false)
    service.preview(root, "")
  }
  // One search previews at a time: another surface's search that starts
  // choosing takes the preview, and this search closes, so its hero never
  // shows one result while Enter would add another.
  Connections {
    target: root.service
    ignoreUnknownSignals: true
    function onPreviewTaken(surface) { if (surface === root) root.cancelAdding() }
  }

  // Every action on the rows and the chart shows what it acts on: the key
  // sheet closes first, from either surface.
  // The order and the change mode are separate settings; each key moves one.
  function cycleChangeMode() {
    showingHelp = false
    if (service) service.persist({ changeMode: Settings.nextChangeMode(changeMode) })
  }
  function setStyle(style) {
    showingHelp = false
    if (service) service.persist({ style: style })
  }
  function toggleStyle() { setStyle(retro ? "smooth" : "retro") }
  function cycleOrder() {
    showingHelp = false
    if (service) service.setOrder(Settings.nextOrder(order))
  }
  // Manual has no direction: there it does nothing at all.
  function reverseOrder() {
    if (order === "manual") return
    showingHelp = false
    if (service) service.reverseOrder()
  }
  function cycleSprite() { spriteOverride = (spriteOverride + 1) % 3 }

  // A row by its place in the list as it is on screen, as 1 to 9 feature
  // them: while the pointer holds the rows, that is not the service's order.
  function featureAt(index) {
    showingHelp = false
    var rows = watchlist.displayedSymbols
    if (service && index >= 0 && index < rows.length) service.feature(rows[index])
  }

  // Acting on the rows closes what covers them first, the key sheet or
  // search, so what the act does shows.
  function featureSymbol(symbol) {
    showingHelp = false
    cancelAdding()
    if (service && symbol) service.feature(symbol)
  }

  function moveCursor(delta) {
    showingHelp = false
    watchlist.moveCursor(delta)
  }

  function moveSelected(delta) {
    showingHelp = false
    watchlist.moveSelected(delta)
  }

  function stepList(delta) {
    showingHelp = false
    if (service) service.stepList(delta)
  }

  // Every removal comes through here, from a key or a right-click, so All's
  // last row's refusal is said once, in the footer. A named list may empty.
  // Removing the row the keyboard cursor is on hands the cursor to the row
  // that takes its place, as Mail and Finder do: the next row, or the one
  // before when it was the last.
  function removeRow(symbol) {
    showingHelp = false
    cancelAdding()
    if (!service || !symbol) return
    if (listName === "" && !Settings.canRemove(symbols)) {
      say("Keep at least one symbol")
      return
    }
    var rows = watchlist.displayedSymbols
    var at = rows.indexOf(symbol)
    var successor = symbol === watchlist.cursorRow && at >= 0 ? (rows[at + 1] || rows[at - 1] || "") : ""
    service.removeSymbol(symbol, rows)
    if (successor !== "") watchlist.select(successor)
    offerUndo(symbol, listName)
  }

  function say(text) {
    offered = null
    note = text
    holdNote()
  }

  // A removal is instant and needs no confirm, and the row may be off screen,
  // so the footer names what went and offers it back. `u` takes it back
  // until the next change to the lists, long after the note has gone.
  function offerUndo(symbol, from) {
    offered = removal
    note = "Removed " + symbol + (from !== "" ? " from " + from : "")
    holdNote()
  }

  // Puts the service's last removal back, whichever surface made it, or
  // says there is none: the next change to the lists ended the offer. The
  // row returns at its place, and the list eases it into view.
  function undoRemoval() {
    if (!service) return
    showingHelp = false
    if (!removal) {
      say("Nothing to undo")
      return
    }
    var symbol = removal.symbol
    clearNote()
    service.undoRemoval(symbol)
    watchlist.select(symbol)
  }

  // The note's moment starts again, and waits while the pointer is on it,
  // so it never turns into the add under a click on its way.
  function holdNote() {
    if (note !== "" && surfaceOpen && !footer.hovered) noteTimer.restart()
    else noteTimer.stop()
  }

  function clearNote() {
    noteTimer.stop()
    note = ""
    offered = null
  }

  function selectRange(value) {
    showingHelp = false
    motion.clearScrub()
    if (service) service.setRange(value)
  }

  function stepRange(delta) {
    var index = rangeOptions.indexOf(range)
    var target = Math.max(0, Math.min(rangeOptions.length - 1, index + delta))
    if (target !== index) selectRange(rangeOptions[target])
  }

  function nudgeScrub(steps) {
    showingHelp = false
    motion.nudgeScrub(steps)
  }

  // A replay plays the shown chart; the motion runs it.
  function replay(slow) {
    showingHelp = false
    motion.replay(slow)
  }

  // Back from a scrub or a replay to now; false when there was none.
  function endScrub() {
    if (!motion.replayRunning && !motion.scrubT) return false
    motion.clearScrub()
    return true
  }

  // Every view that takes the keys, closed. Each gives up its own keys; the
  // surface takes them back once none has them (keysReleased).
  function closeViews() {
    cancelAdding()
    listMenuOpen = false
    managingLists = false
    listsSymbol = ""
  }

  function toggleHelp() {
    closeViews()
    showingHelp = !showingHelp
    if (showingHelp) helpSheet.contentY = 0
  }

  // Opening a view closes whatever else was open, the key sheet included.
  function startAdding() {
    closeViews()
    showingHelp = false
    adding = true
  }

  // A symbol you add has nothing to show until its first answer, so the
  // service keeps it out of the rows until then and the view stays on what
  // you were looking at. Then its row joins at its place, the list eases it
  // into view once, and when the list and the row are at rest it is featured
  // the way a click on that row features it, unless you chose another hero
  // meanwhile or switched to a list without it. The latest add is the one;
  // closing drops it (freeze). A result the hero already shows as a preview
  // has its answer: it joins at once and stays the hero.
  // Search closes first, the preview staying on the hero: the rows show
  // again as they were, and the add then joins them the way any new row
  // does, faded in at its place with the rows below it sliding. The preview
  // ends once the add has made it the featured symbol, so the chart on
  // show never changes for it.
  // A result already in the list on screen is shown, not added
  // (`showSymbol`); one still arriving lands as an add does, and, shown,
  // is featured even when its first fetch fails.
  function acceptSymbol(symbol) {
    if (!service) return
    var s = String(symbol || "").trim().toUpperCase()
    if (view.rows.indexOf(s) >= 0) {
      showSymbol(s)
      return
    }
    var member = members.indexOf(s) >= 0
    adding = false
    if (!member) service.addSymbol(s)
    previewTo("")
    // After the preview has gone, whose hero was a choice, not a landing.
    landing = s
    landingShows = member
    landingJoined = false
    land()
  }

  // Show features the member's row the way a click on it does, a first
  // fetch that failed too, and carries the row into view. The hero already
  // shows it as the preview: it is featured before the preview ends, so the
  // chart on show never changes for it. Show is a choice of hero, so it
  // ends an add still landing, which the featured symbol may not change to
  // tell (`onFeaturedSymbolChanged`) when the hero was already the result.
  function showSymbol(symbol) {
    landing = ""
    service.feature(symbol)
    cancelAdding()
    watchlist.select(symbol)
  }

  // Called once the rows show the service's latest view.
  function land() {
    if (landing === "" || !service || service.arriving.indexOf(landing) >= 0) return
    // A first fetch that failed has nothing to show: the view stays, the add
    // is done, and its row says it failed; a Show features that row all the
    // same. One the list on show lacks is done too. One already in All
    // whose first quote is still out waits for it.
    var failed = !quotes[landing] && !!entries[landing] && entries[landing].status === "failed"
    if (view.rows.indexOf(landing) < 0 || (failed && !landingShows)) {
      landing = ""
      return
    }
    if (!quotes[landing] && !failed) return
    if (!landingJoined) {
      landingJoined = true
      watchlist.select(landing)
    }
    featureLanding()
  }

  // The chart changes to the landing row once it has joined and the list is
  // at rest: where the selection's glide took it, or wherever a wheel or a
  // key left it instead.
  function featureLanding() {
    if (landing === "" || !landingJoined || watchlist.settling || !watchlist.rowResting(landing)) return
    var symbol = landing
    landing = ""
    if (service) service.feature(symbol)
  }

  function cancelAdding() {
    adding = false
    previewTo("")
  }

  // The hero shows search's choice, unadded, while search is open on an
  // open surface; "" puts the featured symbol back.
  function previewTo(symbol) {
    var s = adding && surfaceOpen ? String(symbol || "") : ""
    if (s === previewSymbol) return
    // The service's first: until it is, this preview would read as taken.
    if (service) service.preview(root, s)
    previewSymbol = s
  }

  function openListMenu() {
    closeViews()
    showingHelp = false
    listMenuOpen = true
  }

  function closeListMenu() {
    listMenuOpen = false
  }

  function chooseList(name) {
    closeListMenu()
    if (service && name !== listName) service.switchList(name)
  }

  // A new list is empty, so search opens straight away to fill it.
  function createList(name) {
    if (!service) return
    var problem = service.createList(name)
    if (problem !== "") { listMenu.problem = problem; return }
    startAdding()
  }

  function openManageLists() {
    closeViews()
    showingHelp = false
    managingLists = true
  }

  function openSymbolLists(symbol) {
    if (!symbol) return
    closeViews()
    showingHelp = false
    listsSymbol = symbol
  }

  function closeListViews() {
    managingLists = false
    listsSymbol = ""
  }

  // The keys go back to the surface once no view has them; a turn later,
  // so one view closing as another opens hands the keys straight across.
  onOwnsKeysChanged: if (!ownsKeys) Qt.callLater(function() { if (!root.ownsKeys) root.keysReleased() })

  function renameList(name, newName) {
    if (!service) return
    var problem = service.renameList(name, newName)
    if (problem !== "") manageLists.problem = problem
    else manageLists.stopEditing()
  }

  // Unticking All is a removal from All: its last symbol stays, and the
  // symbol it takes away has no lists left to show.
  function setMembership(name, member) {
    if (!service) return
    if (name === "" && !member && !Settings.canRemove(lists[0].symbols)) {
      say("Keep at least one symbol")
      return
    }
    var symbol = listsSymbol
    service.setMembership(symbol, name, member, watchlist.displayedSymbols)
    if (name === "" && !member) {
      closeListViews()
      offerUndo(symbol, "")
    }
  }

  // Closing stops what moves and keeps what is shown, so the surface fades
  // out as it was; resetInteraction puts it at rest when it next opens. A
  // pending search and a pending add are dropped, the wheel stops where it
  // is, a drag ends with every row where it is on screen, and the footer's
  // note stays, so nothing lands, glides, drops, or goes during the fade or
  // after it. What the header and band move stops with `still`.
  function freeze() {
    landing = ""
    noteTimer.stop()
    watchlist.takeOver()
    motion.freeze()
    watchlist.pauseRows()
    watchlist.releaseDragInPlace()
  }

  // At rest before the first frame: the rows in their places and the list on
  // a row, wherever a close stopped the wheel, and the look icon and the
  // breadth rule on what the surface now reads.
  function resetInteraction() {
    closeViews()
    showingHelp = false
    freeze()
    motion.reset()
    // The rows in the service's order, at rest, whatever a close held.
    watchlist.reopen()
    watchlist.snapToRow()
    header.settle()
    heroBand.settle()
    clearNote()
    hint = ""
  }

  // A refusal stays a moment; an offer to undo long enough to act on it.
  Timer {
    id: noteTimer
    interval: root.offered !== null ? 5000 : 2500
    onTriggered: root.clearNote()
  }

  HeaderStatus {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.margins
    statusText: root.headerText
    retro: root.retro
    animal: root.animal
    ground: root.ground
    scrubbing: root.scrubT !== 0
    live: root.heroLive
    still: !root.surfaceOpen
    foreground: root.foreground
    dim: root.dim
    upColor: root.upColor
    downColor: root.downColor
    fontFamily: root.fontFamily
    onStyleRequested: function(v) { root.setStyle(v) }
    onHelpRequested: root.toggleHelp()
    onReplayRequested: root.replay(false)
    onSpriteCycled: root.cycleSprite()
  }

  HeroBand {
    id: heroBand
    calendars: root.calendars
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.leftMargin: root.margins
    anchors.rightMargin: root.margins
    anchors.topMargin: root.bandGap
    visible: !root.showingHelp
    freshness: root.featuredFreshness
    retro: root.retro
    scrubbing: root.scrubT !== 0
    live: root.heroLive
    still: !root.surfaceOpen
    held: root.chartLoading
    foreground: root.foreground
    dim: root.dim
    dimmer: root.dimmer
    upColor: root.upColor
    downColor: root.downColor
    ghost: root.ghost
    ground: root.ground
    fontFamily: root.fontFamily
    symbol: root.chartSymbol
    view: root.featured
    quote: root.featuredQuote
    day: root.featuredDay
    latest: motion.latest
    geometry: root.featuredGeometry
    scrubX: root.scrubX
    reveal: motion.reveal
    replayX: motion.replayX
    chartHeight: root.chartHeight
    order: root.order
    reversed: root.reversed
    listLabel: root.listLabel
    breadth: root.breadth
    listMenuOpen: root.listMenuOpen
    rowsCovered: root.searching || root.listViewOpen
    replayRunning: motion.replayRunning
    rangeOptions: root.rangeOptions
    range: root.range
    periodText: root.periodText
    baselineText: root.baselineText
    keyStatsText: root.keyStatsText
    now: root.now
    changeCycles: !root.historyShown
    onChangeClicked: root.cycleChangeMode()
    onOrderClicked: root.cycleOrder()
    onOrderReverseClicked: root.reverseOrder()
    onListClicked: root.listMenuOpen ? root.closeListMenu() : root.openListMenu()
    onScrubRequested: function(fraction) { motion.scrubTo(fraction) }
    onScrubCleared: if (root.surfaceOpen) motion.clearScrub()
    onSlowReplayRequested: root.replay(true)
    onSnapToNow: motion.clearScrub()
    onRangeRequested: function(value) { root.selectRange(value) }
  }

  Watchlist {
    id: watchlist
    calendars: root.calendars
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: heroBand.bottom
    anchors.leftMargin: root.margins
    anchors.rightMargin: root.margins
    anchors.topMargin: root.listGap
    height: root.wholeListHeight
    visible: root.rowsShown
    view: root.view
    quotes: root.quotes
    entries: root.entries
    featuredSymbol: root.featuredSymbol
    scrubShown: root.watchlistScrubShown
    changeMode: root.changeMode
    now: root.now
    asked: root.asked
    retro: root.retro
    upColor: root.upColor
    downColor: root.downColor
    foreground: root.foreground
    dim: root.dim
    dimmer: root.dimmer
    fontFamily: root.fontFamily
    rowHeight: root.listRowHeight
    rowGap: root.rowGap
    surfaceOpen: root.surfaceOpen
    // A turn later: the change that arranged the rows is still being told.
    onArranged: Qt.callLater(root.land)
    onSettlingChanged: Qt.callLater(root.featureLanding)
    onRowRested: Qt.callLater(root.featureLanding)
    ground: root.ground
    onFeatureRequested: function(symbol) { root.featureSymbol(symbol) }
    onRemoveRequested: function(symbol) { root.removeRow(symbol) }
    onManualOrderRequested: function(symbols) {
      root.cancelAdding()
      if (root.service) root.service.setManualOrder(symbols)
    }
    onListsRequested: function(symbol) { root.openSymbolLists(symbol) }
  }

  // Its field sits on the edge, where the footer is, and rides it.
  SymbolSearch {
    id: search
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: heroBand.bottom
    anchors.leftMargin: root.margins
    anchors.rightMargin: root.margins
    anchors.topMargin: root.listGap
    height: Math.max(0, root.edge - root.margins - y)
    visible: root.adding
    gate: root.service ? root.service.yahooGate : null
    active: root.adding && root.surfaceOpen
    retro: root.retro
    foreground: root.foreground
    dim: root.dim
    dimmer: root.dimmer
    fontFamily: root.fontFamily
    placeholder: root.listName !== "" ? "Add symbols to " + root.listName + "…" : "Search symbols…"
    members: root.members
    onPicked: function(symbol) { root.acceptSymbol(symbol) }
    onChose: function(symbol) { root.previewTo(symbol) }
    onCancelled: root.cancelAdding()
  }

  ManageLists {
    id: manageLists
    objectName: "manageLists"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: heroBand.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.margins
    anchors.rightMargin: root.margins
    anchors.topMargin: root.listGap
    anchors.bottomMargin: root.margins
    visible: root.managingLists
    active: root.managingLists && root.surfaceOpen
    choices: root.lists
    retro: root.retro
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
    onRenameRequested: function(name, newName) { root.renameList(name, newName) }
    onMoveRequested: function(name, delta) { if (root.service) root.service.moveList(name, delta) }
    onDeleteRequested: function(name) { if (root.service) root.service.deleteList(name) }
    onDismissed: root.closeListViews()
  }

  SymbolLists {
    id: symbolLists
    objectName: "symbolLists"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: heroBand.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.margins
    anchors.rightMargin: root.margins
    anchors.topMargin: root.listGap
    anchors.bottomMargin: root.margins
    visible: root.listsSymbol !== ""
    active: root.listsSymbol !== "" && root.surfaceOpen
    choices: root.lists
    symbol: root.listsSymbol
    symbolName: root.quotes[root.listsSymbol] ? root.quotes[root.listsSymbol].name : ""
    note: root.note
    retro: root.retro
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
    onToggled: function(name, member) { root.setMembership(name, member) }
    onDismissed: root.closeListViews()
  }

  // Only a list with no members at all says so: one whose add is still
  // arriving is not empty, its row is coming. It says so over the rows on
  // show, so a closing surface, which keeps its rows, says nothing.
  Text {
    objectName: "emptyList"
    visible: root.members.length === 0 && watchlist.displayedSymbols.length === 0
      && !root.showingHelp && !root.searching && !root.listViewOpen
    x: root.margins
    y: watchlist.y
    width: root.width - root.margins * 2
    height: root.listRowHeight
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: "No symbols in " + root.listLabel + " yet"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  // At the body's visible bottom, the edge, where the search field opens,
  // one gap under the list's rows; it rides the popup's easing edge. It
  // carries the surface's ground and stacks over the rows and the empty
  // list's line, so a growing edge carries it across them without drawing
  // its words through a row.
  AddFooter {
    id: footer
    objectName: "footer"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.margins
    anchors.rightMargin: root.margins
    y: root.edge - root.margins - height
    visible: !root.showingHelp && !root.adding && !root.listViewOpen
    retro: root.retro
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
    rowHeight: root.rowHeight
    note: root.note
    noteAction: root.offered !== null ? " · click or u to undo" : ""
    notice: root.notice
    hint: root.hint
    ground: root.ground
    label: root.listName !== "" ? "+  Add a symbol to " + root.listName : "+  Add a symbol"
    acts: root.offered !== null || !root.settingsUnreadable
    onHoveredChanged: root.holdNote()
    // The click acts on what the footer shows: an undo offer undoes, the
    // update's notice restarts the shell, and the file's does nothing,
    // nor does a refusal over it; a refusal otherwise, or the label, adds.
    onClicked: {
      if (root.offered !== null) root.undoRemoval()
      else if (root.settingsUnreadable) return
      else if (root.note === "" && root.updatedTo !== "") root.updates.restart()
      else root.startAdding()
    }
  }

  HelpSheet {
    id: helpSheet
    objectName: "helpSheet"
    visible: root.showingHelp
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.margins
    anchors.rightMargin: root.margins
    anchors.topMargin: root.bandGap
    anchors.bottomMargin: root.margins
    sheet: root.keySheet
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
  }

  // A closing surface takes no press, click, or wheel: the popup's card
  // still shows while it fades, and nothing on it acts. Hover passes, so
  // nothing under the pointer changes as the card goes.
  MouseArea {
    objectName: "closedShield"
    anchors.fill: parent
    z: 20
    visible: !root.surfaceOpen
    acceptedButtons: Qt.AllButtons
    onWheel: function(wheel) { wheel.accepted = true }
  }

  // A click anywhere off the open menu closes it, and nothing under it acts,
  // not even to a resting pointer: the chart would scrub.
  MouseArea {
    anchors.fill: parent
    visible: root.listMenuOpen
    hoverEnabled: true
    z: 9
    onClicked: root.closeListMenu()
    onWheel: function(wheel) { wheel.accepted = true }
  }

  ListMenu {
    id: listMenu
    objectName: "listMenu"
    visible: root.listMenuOpen
    active: root.listMenuOpen && root.surfaceOpen
    z: 10
    x: root.margins
    y: root.listMenuTop
    maxHeight: root.height - root.listMenuTop - root.bandGap - footer.height - root.margins
    choices: root.lists
    current: root.listName
    retro: root.retro
    foreground: root.foreground
    dim: root.dim
    fontFamily: root.fontFamily
    onChosen: function(name) { root.chooseList(name) }
    onCreateRequested: function(name) { root.createList(name) }
    onManageRequested: root.openManageLists()
    onDismissed: root.closeListMenu()
  }

  ChartMotion {
    id: motion
    view: root.view
    surfaceOpen: root.surfaceOpen
    retro: root.retro
    calendars: root.calendars
  }
}
