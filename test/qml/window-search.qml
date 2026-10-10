import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "plugin" as Stonks

// Search in the window, through the real App and Service with real Qt keys
// and pointer: results that belong to their query, a search out at a close,
// looking a result up on the hero before adding it, and one preview across
// two surfaces. HOME and curl are scratch fixtures.
ShellRoot {
  id: harness

  property int failures: 0

  function check(label, ok, detail) {
    console.log((ok ? "PASS " : "FAIL ") + label + (!ok && detail !== undefined ? " — " + detail : ""))
    if (!ok) failures++
  }

  function same(got, want) {
    return !!got && got.join("|") === want.join("|")
  }

  function find(item, name) {
    if (!item) return null
    if (item.objectName === name) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = find(item.children[i], name)
      if (found) return found
    }
    return item.contentItem ? find(item.contentItem, name) : null
  }

  // The fake curl counts its calls per name in STONKS_FAKE_STATE. A fresh
  // view per read: a FileView that has loaded once returns its old text
  // straight after reload().
  function calls(name) {
    var view = Qt.createQmlObject('import Quickshell.Io; FileView { blockLoading: true; printErrors: false }', harness)
    view.path = Quickshell.env("STONKS_FAKE_STATE") + "/" + name + ".calls"
    var n = Number(String(view.text()).trim() || "0")
    view.destroy()
    return n
  }

  function finish() {
    console.log("WINDOW SEARCH DONE")
    done.exitCode = failures ? 1 : 0
    done.start()
  }

  Stonks.Service { id: service }
  Stonks.App { id: app; service: service }
  // A second surface on the same service, as a popup beside the window.
  Component { id: otherSurface; Stonks.StonksBody {} }

  TestCase {
    name: "WindowSearch"
    when: service.pluginsReady

    // Waits up to ms for fn to hold and returns whether it does, so the
    // check that reads it is the one that fails.
    function within(ms, fn) {
      for (var t = 0; t < ms && !fn(); t += 20) wait(20)
      return fn()
    }

    function findAll(item, name, into) {
      var out = into || []
      if (!item) return out
      if (item.objectName === name) out.push(item)
      for (var i = 0; i < item.children.length; i++) findAll(item.children[i], name, out)
      if (item.contentItem) findAll(item.contentItem, name, out)
      return out
    }

    // Search open with its answer (the saved SHOP results) in the rows' place.
    function searchShop(body, keys) {
      keys.forceActiveFocus()
      keyClick(Qt.Key_A)
      wait(50)
      keyClick(Qt.Key_S)
      keyClick(Qt.Key_H)
      tryVerify(function() { return body.adding && body.search.results.length > 1 }, 3000)
      wait(50)
    }

    // The six symbols these flows start from, in manual order, `featured`
    // on `range`, the window tall enough for every row.
    function sixRows(body, featured, range) {
      var six = ["AAPL", "MSFT", "NVDA", "FLAT", "DOWN", "STRAY"]
      six.forEach(function(s) { service.addSymbol(s) })
      tryVerify(function() { return service.arriving.length === 0 && service.testFeed.firstRun.length + service.testFeed.refreshRun.length === 0 }, 8000)
      service.setManualOrder(six.concat(service.library.filter(function(s) { return six.indexOf(s) < 0 })))
      service.persist({ order: "manual", featured: featured })
      service.setRange(range)
      mouseMove(body, 1, 1)
      app.close()
      app.testWindow.implicitHeight = body.chromeHeight + 7 * body.rowPitch
      app.open("{}")
      wait(200)
    }

    // Search shows its choice on the hero, unadded, before Enter adds it:
    // the arrows move the choice and the hero follows; a result's quote is
    // asked for only once the choice rests on it, never again by the quote
    // timer; while it is out the chart on show holds under "Loading"; Enter
    // adds the result the hero shows with the quote it has, and the chart
    // stays; Escape puts the featured symbol back; a failed lookup can still
    // be added; a click chooses and the chosen row's Add adds. The fake curl
    // answers SHOP.TO from its saved day and fails SHOP and SHHI.NE.
    function looksUpBeforeAdding(body, watchlist, keys) {
      service.switchList("")
      service.setRange("1D")
      wait(400)
      var hero = service.featuredSymbol
      var library = service.library.slice()
      var field = harness.find(body.search, "searchField")
      // Draw-ins, and changes of the symbol whose chart is on show.
      var draws = 0
      var changes = 0
      var onReveal = function() { if (body.motion.reveal === 0) draws++ }
      var lastShown = body.chartSymbol
      var onChart = function() { if (body.chartSymbol !== lastShown) { lastShown = body.chartSymbol; changes++ } }
      body.motion.revealChanged.connect(onReveal)
      body.motion.chartChanged.connect(onChart)
      // Fetches from here on: earlier flows fetched these too.
      var calls = function(symbol, from) { return harness.calls(symbol) - (from || 0) }
      var before = { to: harness.calls("SHOP.TO"), shop: harness.calls("SHOP"), shhi: harness.calls("SHHI.NE") }

      searchShop(body, keys)
      var fieldAt = field.mapToItem(body, 0, 0).y
      var topHeld = [body.headerText, body.chartSymbol, body.motion.drawn].join(",")
      harness.check("the top result shows on the hero as it loads: named, the chart on show held whole",
        topHeld === "Loading SHOP," + hero + ",1", topHeld)

      // Past SHOP and SHHI.NE before the choice rests: neither is fetched.
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Up)
      draws = 0
      changes = 0
      var previewed = within(3000, function() { return body.chartSymbol === "SHOP.TO" && !body.chartLoading })
      wait(100)
      var shown = [previewed, body.featured.priceText, body.search.resultIndex, service.featuredSymbol === hero,
        service.library.indexOf("SHOP.TO") < 0, changes, draws].join(",")
      harness.check("↓ shows the chosen result on the hero, unadded, once and whole at once, the featured symbol kept",
        shown === "true,194.60,1,true,true,1,0", shown)
      var fetched = [calls("SHOP.TO", before.to), calls("SHOP", before.shop), calls("SHHI.NE", before.shhi)].join(",")
      harness.check("only the result the choice rests on is fetched", fetched === "1,0,0", fetched)
      var stats = within(3000, function() { return !!body.yearLine && body.yearLine.facts.length > 0 && body.yearLine.facts[0].value !== "" })
      harness.check("the preview's info lines are its own: its day and its cap",
        stats && !!body.periodLine && body.periodLine.title === "WED 2 SEP", JSON.stringify(body.periodLine) + " / " + JSON.stringify(body.yearLine))
      // An hour on the schedule's clock, and a user's refresh.
      service.now += 3600
      service.askDue()
      service.refresh()
      wait(600)
      harness.check("neither the schedule nor r refreshes a preview", calls("SHOP.TO", before.to) === 1, calls("SHOP.TO", before.to))
      harness.check("the field stays put as the hero follows the choice",
        field.mapToItem(body, 0, 0).y === fieldAt, fieldAt + " -> " + field.mapToItem(body, 0, 0).y)
      // From a choice that has rested, arrowing on past results asks for
      // none of them either: each new choice waits its own rest. Found in
      // lookup-review's review: the next result was fetched at once.
      var further = { shhi: harness.calls("SHHI.NE"), f: harness.calls("307.F") }
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Up)
      keyClick(Qt.Key_Up)
      wait(400)
      var passed = [calls("SHHI.NE", further.shhi), calls("307.F", further.f), body.chartSymbol].join(",")
      harness.check("from a rested choice, results arrowed past are not fetched", passed === "0,0,SHOP.TO", passed)

      // Enter adds what the hero shows: its row joins faded in, it is the
      // featured symbol, and the chart on show neither changes nor redraws.
      var faded = false
      draws = 0
      changes = 0
      // The result returned to above is asked for again once it rests.
      tryVerify(function() { return calls("SHOP.TO", before.to) === 2 && !!service.previewView.chart }, 3000)
      var beforeEnter = harness.calls("SHOP.TO")
      keyClick(Qt.Key_Return)
      // The row is made as it joins, and fades in on the frames after.
      var row = watchlist.rowItem("SHOP.TO")
      var onFade = function() { if (row.visible && row.opacity < 1) faded = true }
      if (row) {
        onFade()
        row.opacityChanged.connect(onFade)
      }
      tryVerify(function() { return !!row && watchlist.displayedSymbols.indexOf("SHOP.TO") >= 0 && row.resting }, 2000)
      wait(100)
      var added = [service.featuredSymbol, body.adding, body.chartSymbol, changes, draws, calls("SHOP.TO", beforeEnter)].join(",")
      harness.check("Enter adds the result on the hero with its quote: featured, the chart kept, nothing fetched again",
        added === "SHOP.TO,false,SHOP.TO,0,0,0", added)
      harness.check("its row fades in at its place", faded, faded)
      row.opacityChanged.disconnect(onFade)
      service.removeSymbol("SHOP.TO")
      service.feature(hero)
      wait(400)

      // Escape puts the featured symbol back, whole at once, and adds nothing.
      searchShop(body, keys)
      keyClick(Qt.Key_Down)
      tryVerify(function() { return body.chartSymbol === "SHOP.TO" && !body.chartLoading && body.motion.reveal === 1 }, 3000)
      draws = 0
      changes = 0
      keyClick(Qt.Key_Escape)
      wait(100)
      var back = [body.adding, body.chartSymbol, changes, draws, service.library.indexOf("SHOP.TO") < 0].join(",")
      harness.check("Escape puts the featured symbol back on the hero, whole at once, and adds nothing",
        back === "false," + hero + ",1,0,true", back)

      // A lookup that fails says so on the hero; Enter adds it anyway, and
      // the hero goes back to what it showed. Its failed fetch was the add's
      // first: the add is done there, its row joining at once saying so,
      // with nothing fetched again. Found in the Grok review of #36: it
      // went arriving and was fetched again, and an answer then would have
      // taken the hero.
      searchShop(body, keys)
      var failed = within(9000, function() {
        return body.chartSymbol === "SHOP" && body.featuredFreshness.state === "failed"
      })
      harness.check("a failed lookup shows on the hero as failed", failed,
        body.chartSymbol + "|" + body.featuredFreshness.state + "|" + body.headerText)
      var shopCalls = harness.calls("SHOP")
      keyClick(Qt.Key_Return)
      wait(600)
      var failedAdd = [service.library.indexOf("SHOP") >= 0, service.featuredSymbol === hero, body.chartSymbol].join(",")
      harness.check("Enter adds a failed lookup anyway, and the hero shows the featured symbol",
        failedAdd === "true,true," + hero, failedAdd)
      var failedRow = [service.arriving.indexOf("SHOP") < 0, watchlist.displayedSymbols.indexOf("SHOP") >= 0,
        service.entries.SHOP ? service.entries.SHOP.status : "none", calls("SHOP", shopCalls)].join(",")
      harness.check("an add of a failed lookup is done there: its row joins saying so, nothing fetched again",
        failedRow === "true,true,failed,0", failedRow)
      service.removeSymbol("SHOP")
      wait(100)

      // The pointer: a click on a result chooses it and adds nothing; the
      // chosen row's Add adds it.
      searchShop(body, keys)
      var second = findAll(body.search, "searchResult")[1]
      mouseClick(second, second.width / 4, second.height / 2)
      var clicked = within(3000, function() { return body.chartSymbol === "SHOP.TO" && !body.chartLoading })
      var choseOnly = [clicked, body.search.resultIndex, body.adding, service.library.indexOf("SHOP.TO") < 0].join(",")
      harness.check("a click on a result chooses it for the hero and adds nothing", choseOnly === "true,1,true,true", choseOnly)
      // Two clicks closer together than this are one double-click.
      wait(Qt.styleHints.mouseDoubleClickInterval + 50)
      var add = harness.find(second, "searchAdd")
      mouseClick(add, add.width / 2, add.height / 2)
      wait(100)
      var byPointer = [service.library.indexOf("SHOP.TO") >= 0, service.featuredSymbol, body.adding].join(",")
      harness.check("the chosen result's Add adds it", byPointer === "true,SHOP.TO,false", byPointer)
      service.removeSymbol("SHOP.TO")
      service.feature(hero)
      body.motion.revealChanged.disconnect(onReveal)
      body.motion.chartChanged.disconnect(onChart)
      tryVerify(function() { return service.testFeed.firstRun.length + service.testFeed.refreshRun.length === 0 }, 5000)
      wait(400)
      harness.check("the lookup flow leaves All as it found it", harness.same(service.library, library),
        service.library + " vs " + library)
    }

    // A second surface beside the window, on the same service, as the
    // popup is: its search taking the preview closes the window's search,
    // so neither hero shows one result while Enter would add another; the
    // window's hero, back on the featured symbol, gets its range's history
    // while the other previews; and a surface that goes while previewing
    // takes its preview with it. Found in lookup-review's review.
    function twoSurfacesPreview(body, keys) {
      service.feature("MSFT")
      service.setRange("1Y")
      wait(400)
      var other = otherSurface.createObject(null, { service: service, width: 480, height: 760 })
      // The other surface previews, and history for MSFT's year is gone.
      other.surfaceOpen = true
      other.startAdding()
      wait(50)
      harness.find(other.search, "searchField").text = "SH"
      tryVerify(function() { return other.search.results.length > 1 }, 3000)
      other.search.showResult(1)
      tryVerify(function() { return other.chartSymbol === "SHOP.TO" && !other.chartLoading }, 5000)
      // r on the window, while the other previews, fetches every chart the
      // heroes show fresh: the window's own, here failed (the fake curl
      // answers no year for FLAT) and saying "unavailable · R to retry",
      // and the preview's. Found in the Grok review of #36: only the
      // preview's was fetched again.
      service.addSymbol("FLAT")
      tryVerify(function() { return !!service.quotes.FLAT }, 5000)
      service.feature("FLAT")
      tryVerify(function() {
        return body.headerText.indexOf("unavailable") >= 0 && !!service.testHistoryFeed.entries["SHOP.TO|1Y"]
      }, 12000)
      var histories = { flat: harness.calls("FLAT.history"), to: harness.calls("SHOP.TO.history") }
      keys.forceActiveFocus()
      keyClick(Qt.Key_R)
      var refreshed = within(12000, function() {
        return harness.calls("FLAT.history") > histories.flat && harness.calls("SHOP.TO.history") > histories.to
      })
      harness.check("r fetches every chart the heroes show fresh, the window's failed year and the preview's",
        refreshed, (harness.calls("FLAT.history") - histories.flat) + "," + (harness.calls("SHOP.TO.history") - histories.to))
      service.feature("MSFT")
      wait(100)
      service.testHistoryFeed.entries = ({})
      // The window opens search and takes the preview.
      searchShop(body, keys)
      keyClick(Qt.Key_Down)
      tryVerify(function() { return body.chartSymbol === "SHOP.TO" && !body.chartLoading }, 5000)
      var taken = [other.adding, other.previewSymbol, service.previewSurface === app.testBody].join(",")
      harness.check("a search that takes the preview closes the other surface's search", taken === "false,,true", taken)
      var otherChart = within(4000, function() { return other.chartSymbol === "MSFT" && !other.chartLoading && other.historyShown })
      harness.check("the other surface's hero, back on the featured symbol, gets its range's history meanwhile",
        otherChart, other.chartSymbol + "|" + other.headerText)
      // The window goes while it previews: its preview goes with it.
      app.close()
      wait(50)
      var closed = service.previewSymbol + "," + service.previewSurface
      other.startAdding()
      wait(50)
      harness.find(other.search, "searchField").text = "SH"
      tryVerify(function() { return other.search.results.length > 1 }, 3000)
      other.search.showResult(1)
      tryVerify(function() { return other.chartSymbol === "SHOP.TO" }, 3000)
      other.destroy()
      wait(50)
      var gone = service.previewSymbol + "," + service.previewSurface
      harness.check("a surface closing or going while it previews ends its preview", closed === ",null" && gone === ",null",
        closed + " / " + gone)
      app.open("{}")
      service.setRange("1D")
      wait(400)
    }

    // The result rows of the answer on screen, each once: findAll reaches
    // a Flickable's rows through its children and its contentItem both.
    function resultRows(body) {
      return findAll(body.search, "searchResult").filter(function(row, i, all) { return all.indexOf(row) === i })
    }

    // Types `query` over what the field holds and waits for its answer.
    function answer(body, query) {
      keyClick(Qt.Key_A, Qt.ControlModifier)
      for (var c = 0; c < query.length; c++) keyClick(query[c])
      tryVerify(function() { return body.search.resultsQuery === query }, 3000)
      wait(50)
    }

    // Search's field opens where the list's first row was, under its
    // header, and stays there from its open through one answer, five, none,
    // and a lookup with no answer; each answer starts the same gap under
    // it, and the hint offers Enter only while there is a result to take.
    // Found in the first-run review: the field opened at the bottom, and
    // "No matches" sat about 260 px above it, the hint still offering add.
    function fieldInRowsPlace(body, watchlist, keys) {
      var bar = harness.find(body.search, "searchField").parent
      var hint = harness.find(body.search, "keyHints")
      var message = harness.find(body.search, "searchMessage")
      var rowsAt = Math.round(watchlist.mapToItem(body, 0, 0).y)
      var seen = []
      // Where the field's bar stands, how far under it the answer starts,
      // and whether the hint offers Enter.
      var look = function(label) {
        var first = body.search.results.length ? resultRows(body)[0] : message.visible ? message : null
        var under = first ? Math.round(first.mapToItem(body, 0, 0).y - bar.mapToItem(body, 0, bar.height).y) : "-"
        seen.push([label, Math.round(bar.mapToItem(body, 0, 0).y), under, hint.text.indexOf("⏎") >= 0].join(" "))
      }
      keys.forceActiveFocus()
      keyClick(Qt.Key_A)
      wait(50)
      look("open")
      ;["ONE", "SH", "ZZZ", "OOPS"].forEach(function(query) {
        answer(body, query)
        look(query + "/" + body.search.results.length)
      })
      keyClick(Qt.Key_Escape)
      wait(50)
      var gap = body.search.resultsGap
      var want = ["open " + rowsAt + " - false", "ONE/1 " + rowsAt + " " + gap + " true", "SH/5 " + rowsAt + " " + gap + " true",
        "ZZZ/0 " + rowsAt + " " + gap + " false", "OOPS/0 " + rowsAt + " " + gap + " false"]
      harness.check("search's field opens where the first row was and stays there, each answer starting under it, Enter offered only with results",
        harness.same(seen, want), seen.join(" | ") + " — want " + want.join(" | "))
    }

    // A long symbol shows whole, the name giving way to it, and the
    // exchange codes keep one column. Found in the first-run review:
    // "XBTC39577-…" was cut while its name kept its room.
    function longSymbols(body, keys) {
      keys.forceActiveFocus()
      keyClick(Qt.Key_A)
      wait(50)
      answer(body, "BTC")
      var rows = resultRows(body)
      // The row's symbol: the Text that says it.
      var symbolText = function(item, symbol) {
        if (item.text === symbol && item.implicitWidth !== undefined) return item
        for (var i = 0; i < item.children.length; i++) {
          var found = symbolText(item.children[i], symbol)
          if (found) return found
        }
        return null
      }
      var symbols = rows.map(function(row) { return symbolText(row, row.modelData.symbol) }).filter(function(s) { return !!s })
      var cut = symbols.filter(function(s) { return s.implicitWidth > s.width }).map(function(s) { return s.text })
      var edges = rows.map(function(row) {
        var code = harness.find(row, "searchExchange")
        return Math.round(code.mapToItem(body, code.width, 0).x)
      })
      keyClick(Qt.Key_Escape)
      wait(50)
      harness.check("long symbols show whole in search, the exchange codes in one column",
        symbols.length === 5 && cut.length === 0 && edges.length === 5 && edges.every(function(x) { return x === edges[0] }),
        symbols.length + " symbols, cut: " + cut.join(",") + " | codes " + edges.join(","))
    }

    // The window at its smallest shows search's field and only whole
    // results, one at least. Found in the first-run review: the field cut
    // the second result in half.
    function smallestWindow(body, keys) {
      var height = app.testWindow.implicitHeight
      app.close()
      app.testWindow.implicitHeight = app.testWindow.minimumSize.height
      app.open("{}")
      wait(200)
      keys.forceActiveFocus()
      keyClick(Qt.Key_A)
      wait(50)
      answer(body, "SH")
      var view = harness.find(body.search, "searchResults")
      var tops = resultRows(body).map(function(row) { return Math.round(row.y - view.contentY) })
      var rowHeight = body.search.rowHeight
      var whole = tops.filter(function(top) { return top >= 0 && top + rowHeight <= view.height }).length
      var cut = tops.filter(function(top) { return top + rowHeight > 0 && top < view.height && (top < 0 || top + rowHeight > view.height) }).length
      var atMinimum = Math.round(body.height) === app.testWindow.minimumSize.height
      var at = [Math.round(body.height), Math.round(view.height), whole, cut].join(",")
      keyClick(Qt.Key_Escape)
      app.close()
      app.testWindow.implicitHeight = height
      app.open("{}")
      wait(200)
      harness.check("the smallest window shows search's results whole, one at least, none cut",
        atMinimum && whole >= 1 && cut === 0,
        "body, results' room, whole, cut: " + at + " (minimum " + app.testWindow.minimumSize.height + ")")
    }

    function test_flows() {
      tryVerify(function() {
        return service.quotes.AAPL && service.quotes.MSFT && service.quotes.NVDA
          && service.testFeed.firstRun.length + service.testFeed.refreshRun.length === 0
      }, 10000)

      app.open("{}")
      wait(200)
      var body = app.testBody
      var watchlist = body.watchlist
      var keys = app.testKeyCatcher

      // These flows start from three rows in this order, AAPL featured on its
      // year.
      service.setManualOrder(["NVDA", "AAPL", "MSFT"])
      service.feature("AAPL")
      service.setRange("1Y")
      wait(300)

      // Results belong to their query. Search SH and let its answer land,
      // replace the field with NVDA, and act before NVDA's answer (the fake
      // curl answers 0.4 s after the 250 ms debounce): neither Enter nor a
      // click where SHOP was adds anything. Once NVDA's answer is in, Enter
      // adds its top result. Found in the garden review: both added SHOP.
      var beforeSearch = service.dataSettings
      var beforeFeatured = service.featuredSymbol
      var searchFor = function(first, then) {
        keys.forceActiveFocus()
        keyClick(Qt.Key_A)
        wait(50)
        for (var c = 0; c < first.length; c++) keyClick(first[c])
        tryVerify(function() { return body.search.resultsQuery === first && body.search.results.length > 0 }, 3000)
        var top = harness.find(body.search, "searchResult")
        var at = top.mapToItem(body, top.width / 2, top.height / 2)
        keyClick(Qt.Key_A, Qt.ControlModifier)
        for (c = 0; c < then.length; c++) keyClick(then[c])
        return at
      }
      searchFor("SH", "NVDA")
      keyClick(Qt.Key_Return)
      wait(50)
      harness.check("Enter before the new query's results adds nothing",
        harness.same(service.library, beforeSearch.symbols) && service.featuredSymbol === beforeFeatured
          && body.adding && body.search.searchText === "NVDA",
        service.library + "|" + service.featuredSymbol + "|" + body.adding + "|" + body.search.searchText)
      tryVerify(function() { return body.search.resultsQuery === "NVDA" && body.search.results.length > 0 }, 3000)
      keyClick(Qt.Key_Return)
      wait(50)
      harness.check("Enter once the new query's results are in adds its top result",
        service.library.indexOf("SHOP") >= 0 && !body.adding,
        service.library + "|" + service.featuredSymbol + "|" + body.adding)
      service.persist(beforeSearch)
      wait(50)
      var oldTop = searchFor("SH", "NVDA")
      mouseClick(body, oldTop.x, oldTop.y)
      wait(50)
      harness.check("a click where an old result was, before the new results, adds nothing",
        harness.same(service.library, beforeSearch.symbols) && service.featuredSymbol !== "SHOP",
        service.library + "|" + service.featuredSymbol)
      service.persist(beforeSearch)
      body.resetInteraction()

      // While a new query is out, the last results stay on screen, dimmed
      // and not takeable; an empty answer says so in place, a failed lookup
      // says so differently, and only an empty field clears them, the rows
      // staying away while search is open. Found in the code-quality
      // review: every edit brought the watchlist back for up to a second.
      searchFor("SH", "SHO")
      var resultsView = harness.find(body.search, "searchResults")
      var whileOut = [body.search.results.length > 0, body.search.stale, resultsView.opacity < 1,
        !watchlist.visible].join(",")
      tryVerify(function() { return body.search.resultsQuery === "SHO" }, 3000)
      var freshAgain = !body.search.stale && resultsView.opacity === 1
      keyClick(Qt.Key_A, Qt.ControlModifier)
      ;["Z", "Z", "Z"].forEach(function(k) { keyClick(k) })
      tryVerify(function() { return body.search.resultsQuery === "ZZZ" }, 3000)
      var message = harness.find(body.search, "searchMessage")
      var noMatches = [body.search.results.length === 0, message.visible, message.text].join(",")
      keyClick(Qt.Key_A, Qt.ControlModifier)
      ;["O", "O", "P", "S"].forEach(function(k) { keyClick(k) })
      tryVerify(function() { return body.search.resultsQuery === "OOPS" }, 3000)
      var failed = [message.visible, message.text].join(",")
      keyClick(Qt.Key_A, Qt.ControlModifier)
      keyClick(Qt.Key_Backspace)
      var cleared = [body.search.results.length === 0, body.adding, watchlist.visible].join(",")
      harness.check("a query out keeps the last results dimmed and the rows away",
        whileOut === "true,true,true,true" && freshAgain, whileOut + "|" + freshAgain)
      harness.check("an empty answer and a failed lookup each say so in place, differently",
        noMatches === "true,true,No matches for “ZZZ”"
          && failed === "true,Search didn’t answer · try again",
        noMatches + " / " + failed)
      harness.check("an empty field clears the results, the rows still away while search is open",
        cleared === "true,true,false", cleared)
      // Emptied while a query is out, the field drops it: no answer comes
      // for it. Found in cubic's review of #25.
      ;["S", "H"].forEach(function(k) { keyClick(k) })
      tryVerify(function() { return body.search.activeQuery === "SH" }, 2000)
      var answeredBeforeClear = harness.calls("SEARCH.answered")
      keyClick(Qt.Key_Backspace)
      keyClick(Qt.Key_Backspace)
      wait(600)
      harness.check("emptying the field drops the query still out",
        harness.calls("SEARCH.answered") === answeredBeforeClear && body.search.activeQuery === "",
        (harness.calls("SEARCH.answered") - answeredBeforeClear) + "|" + body.search.activeQuery)
      body.resetInteraction()

      fieldInRowsPlace(body, watchlist, keys)
      longSymbols(body, keys)
      smallestWindow(body, keys)

      // A search still out when the window closes brings nothing back, and is
      // stopped, not waited out: type SH, let it go out (the fake curl
      // answers in 0.4 s), close, open, and start a new search. Found in
      // cubic's review of #25: the old curl ran on and could hold a new
      // search back for its whole timeout.
      app.close()
      app.open("{}")
      wait(200)
      keys.forceActiveFocus()
      keyClick(Qt.Key_A)
      wait(50)
      harness.find(body.search, "searchField").text = "SH"
      var searched = within(2000, function() { return body.search.activeQuery === "SH" })
      var answeredBefore = harness.calls("SEARCH.answered")
      app.close()
      app.open("{}")
      wait(100)
      keys.forceActiveFocus()
      keyClick(Qt.Key_A)
      wait(600)
      harness.check("a search out at a close is stopped, and a new open shows nothing of it",
        searched && body.adding && body.search.searchText === "" && body.search.results.length === 0
          && harness.calls("SEARCH.answered") === answeredBefore,
        searched + "|" + body.adding + "|" + body.search.searchText + "|" + body.search.results.length
          + "|" + (harness.calls("SEARCH.answered") - answeredBefore))

      keyClick(Qt.Key_Escape)

      sixRows(body, "STRAY", "1Y")

      looksUpBeforeAdding(body, watchlist, keys)
      twoSurfacesPreview(body, keys)
      app.close()
      harness.finish()
    }
  }

  HarnessExit { id: done }
}
