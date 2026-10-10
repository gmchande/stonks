pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Fetch.js" as Fetch
import "Search.js" as Search
import "Tones.js" as Tones
// Search field, results, and the Yahoo lookup. The body turns it on and off
// (`active`) and handles picked / chose / cancelled, and gives it the room
// of desiredHeight as it opens. The field sits at the top and the results
// fill down under it, whole rows only, so nothing above them moves as
// answers come and go. The last answer stays on screen while a new query is
// out, dimmed and not takeable, so nothing can add a symbol found for an
// earlier query; only an empty field clears it. An empty answer says there
// are no matches, and a lookup that failed says so. The keyboard owns the
// choice: it starts on the top result, the arrows move it and keep it in
// view, Enter takes it, and every change of it is told (`chose`), so the
// hero can show it before it is added. The pointer tints the row under it;
// a click chooses that row, and the chosen row's Add (Show, for a symbol
// already in the list) takes it, so a pointer
// left resting over the list can never change what Enter adds. A
// FocusScope so that hiding it takes the keyboard away from the field;
// otherwise the hidden field keeps every later key the surface's own key
// handler should see.
FocusScope {
  id: root

  property bool retro: false
  property color foreground: Color.foreground
  property color dim: Tones.dim(foreground, Color.background)
  property color dimmer: Tones.dimmer(foreground, Color.background)
  property string fontFamily: Style.font.family
  property int rowHeight: Style.space(30)
  // What the search endpoint returns at most, so the room is the shape of a
  // full answer.
  readonly property int maxResults: 8
  readonly property int rowGap: Style.space(2)
  readonly property int rowPitch: rowHeight + rowGap
  // From the field's rule to the first result.
  readonly property int resultsGap: Style.space(6)
  readonly property int desiredHeight: fieldBar.height + resultsGap + rowPitch * maxResults - rowGap
  // The results' room under the field, in whole rows: a row is never cut.
  readonly property int resultsHeight: {
    var rows = Math.floor((Math.max(0, height - fieldBar.height - resultsGap) + rowGap) / rowPitch)
    return rows > 0 ? rows * rowPitch - rowGap : 0
  }

  property var results: []
  // The query the answer on screen is for, and what it was: "results",
  // "none", or "failed"; "" before any answer.
  property string resultsQuery: ""
  property string answer: ""
  // The answer on screen is for an earlier query than the field's.
  readonly property bool stale: answer !== "" && resultsQuery !== searchText.trim()
  property int resultIndex: 0
  property string activeQuery: ""
  property string requestedQuery: ""
  property string searchText: ""
  property string placeholder: ""
  // The list on screen's members, arriving ones too: a result already in
  // it is shown, not added, and its button and the field's hint say so.
  property var members: []
  function actionFor(symbol) { return members.indexOf(symbol) >= 0 ? "Show" : "Add" }
  readonly property string chosenAction: results[resultIndex] ? actionFor(results[resultIndex].symbol) : "Add"
  // Add and Show share one slot on every row, the wider word's, so the
  // exchange codes keep their column whichever shows.
  readonly property int buttonWidth: Math.ceil(Math.max(addMetrics.advanceWidth, showMetrics.advanceWidth)) + Style.space(20)
  TextMetrics { id: addMetrics; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; text: "Add" }
  TextMetrics { id: showMetrics; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; text: "Show" }
  // A row's columns: the symbol, the name, the exchange, and the button.
  readonly property int rowPadding: Style.space(10)
  readonly property int columnGap: Style.space(10)
  readonly property int exchangeWidth: Style.space(110)
  // The symbol is what you match on, so the name gives way to it: one
  // column for every row, as wide as the answer's widest symbol, until the
  // name is down to half the room the two share; past that a symbol ends
  // in an ellipsis. The exchange and the button keep theirs.
  readonly property int sharedWidth: width - rowPadding * 2 - columnGap * 3 - exchangeWidth - buttonWidth
  readonly property int symbolWidth: {
    var font = symbolMetrics.font // read, so a look's new font measures again
    var widest = Style.space(80)
    for (var i = 0; i < results.length; i++)
      widest = Math.max(widest, Math.ceil(symbolMetrics.advanceWidth(results[i].symbol)))
    return Math.min(widest, Math.floor(sharedWidth / 2))
  }
  FontMetrics { id: symbolMetrics; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }

  signal picked(string symbol)
  // The choice is now this result, or none ("").
  signal chose(string symbol)
  signal cancelled()

  // True while search is open on an open surface. Turned on, it starts
  // fresh before its first frame and takes the keys a turn later if it is
  // still on; turned off, by any way it closes or by the surface closing, it
  // gives the keys up and drops a search still out, and keeps what it shows
  // for the close fade.
  property bool active: false
  // Off, it still shows, through the close fade, but takes no pointer or
  // key: nothing acts or takes focus from a view that is closing.
  enabled: active
  onActiveChanged: {
    if (active) {
      reset()
      Qt.callLater(function() { if (root.active) searchField.forceActiveFocus() })
    } else {
      suspend()
      searchField.focus = false
      root.focus = false
    }
  }
  Keys.onPressed: function(event) { root.handleKey(event) }

  // A new search's start, so its first frame is empty rather than the last
  // search's field and results.
  function reset() {
    results = []
    answer = ""
    resultsQuery = ""
    resultsScroll.contentY = 0
    activeQuery = ""
    requestedQuery = ""
    searchText = ""
    searchDebounce.stop()
    searchField.text = ""
    choose(0)
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Escape) {
      searchDebounce.stop()
      requestedQuery = ""
      root.cancelled()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.accept(root.resultIndex)
      event.accepted = true
    } else if (event.key === Qt.Key_Down) {
      root.showResult(Math.min(root.results.length - 1, root.resultIndex + 1))
      event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      root.showResult(Math.max(0, root.resultIndex - 1))
      event.accepted = true
    }
  }

  // Every way of taking a result comes through here, and only a result for
  // the query in the field is taken.
  function accept(index) {
    if (!stale && index >= 0 && index < results.length) picked(results[index].symbol)
  }

  function setQuery(text) {
    var changed = text.trim() !== searchText.trim()
    searchText = text
    if (!changed) return
    if (text.trim() === "") {
      // No query is asked any more: a search still out is dropped.
      suspend()
      results = []
      answer = ""
      resultsQuery = ""
      resultsScroll.contentY = 0
      choose(0)
      return
    }
    searchDebounce.restart()
  }

  // The choice, told: a result, or none when there are no results.
  function choose(index) {
    resultIndex = index
    chose(index >= 0 && index < results.length ? results[index].symbol : "")
  }

  // Choose a result and bring it into view.
  function showResult(index) {
    if (index < 0 || index >= results.length) return
    root.choose(index)
    var top = index * rowPitch
    var limit = Math.max(0, resultsColumn.implicitHeight - resultsScroll.height)
    if (top < resultsScroll.contentY) resultsScroll.contentY = Math.min(limit, top)
    else if (top + rowHeight > resultsScroll.contentY + resultsScroll.height)
      resultsScroll.contentY = Math.max(0, Math.min(limit, top + rowHeight - resultsScroll.height))
  }

  // Yahoo's gate (`Gate.qml`), which the service holds: while it pauses the
  // host, a lookup fails at once rather than waiting. A body with no
  // service has none.
  property var gate: null
  // The gate's ticket the request out was let through on (`Gate.report`).
  property int ticket: 0

  function runSearch() {
    var q = searchText.trim()
    if (q.length < 1) return
    if (searchProc.running) { requestedQuery = q; return }
    activeQuery = q
    if (gate && gate.take(1) === 0) {
      land("")
      return
    }
    if (gate) root.ticket = gate.ticket
    searchProc.command = Fetch.curlCommand([Search.searchUrl(q)], Fetch.SEARCH_CAP)
    searchProc.running = true
  }

  // An answer counts only for the query still being asked: a search dropped
  // by a close or a new open has no query, and an empty field takes no
  // results. "" is no answer.
  function land(body) {
    if (root.active && root.activeQuery !== "" && root.activeQuery === root.searchText.trim()) {
      try {
        root.results = Search.parseSearch(JSON.parse(body))
        root.answer = root.results.length > 0 ? "results" : "none"
      } catch (e) {
        root.results = []
        root.answer = "failed"
      }
      root.resultsQuery = root.activeQuery
      resultsScroll.contentY = 0
      root.choose(0)
      searchField.forceActiveFocus()
    }
    if (root.requestedQuery !== "") {
      root.requestedQuery = ""
      root.runSearch()
    }
  }

  // Drops a search not yet made and ignores an answer still out; what shows
  // stays.
  function suspend() {
    searchDebounce.stop()
    requestedQuery = ""
    activeQuery = ""
    // Its stream ends at once, empty, and is ignored: no query is asked.
    if (searchProc.running) searchProc.running = false
  }

  Timer {
    id: searchDebounce
    interval: 250
    onTriggered: root.runSearch()
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var got = Fetch.answers(String(text || ""))
        if (root.gate) root.gate.report(got.map(function(a) { return a.kind }), got.length ? got[0].retryAfter : 0, root.ticket)
        root.land(got.length && got[0].kind === "ok" ? got[0].body : "")
      }
    }
  }

  Flickable {
    id: resultsScroll
    objectName: "searchResults"
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: fieldBar.bottom
    anchors.topMargin: root.resultsGap
    height: root.resultsHeight
    visible: root.results.length > 0
    opacity: root.stale ? 0.4 : 1
    contentWidth: width
    contentHeight: resultsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: resultsColumn
      width: resultsScroll.width
      spacing: root.rowGap

      Repeater {
        model: root.results
        Rectangle {
          id: resultRow
          objectName: "searchResult"
          required property var modelData
          required property int index
          readonly property bool chosen: index === root.resultIndex
          width: parent.width
          height: root.rowHeight
          radius: root.retro ? 0 : Style.cornerRadius
          color: chosen ? Style.hoverFillFor(root.foreground, Color.accent)
            : rowMouse.containsMouse ? Style.normalFillFor(root.foreground, Color.accent) : "transparent"

          // Under the row's Add, which takes the result; a click anywhere
          // else on the row chooses it.
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: !root.stale
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showResult(resultRow.index)
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: root.rowPadding
            anchors.rightMargin: root.rowPadding
            spacing: root.columnGap
            Text {
              width: root.symbolWidth
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: resultRow.modelData.symbol
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
            }
            // Every row keeps the Add's slot, so the exchange codes stay in
            // one column as the choice moves.
            Text {
              width: root.sharedWidth - root.symbolWidth
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: resultRow.modelData.name
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
            Text {
              objectName: "searchExchange"
              width: root.exchangeWidth
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignRight
              textFormat: Text.PlainText
              text: resultRow.modelData.exchange || ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
            // The pointer's way to take a result: on the chosen result only,
            // the one the hero shows. Unchosen rows keep its slot, unseen
            // and taking no click, which chooses the row instead.
            Rectangle {
              id: addButton
              objectName: "searchAdd"
              opacity: resultRow.chosen ? 1 : 0
              anchors.verticalCenter: parent.verticalCenter
              width: root.buttonWidth
              height: Style.space(20)
              radius: root.retro ? 0 : Style.cornerRadius
              color: addMouse.containsMouse ? Style.pressedFillFor(root.foreground, Color.accent)
                : Style.selectedFillFor(root.foreground, Color.accent)
              Text {
                id: addLabel
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: root.actionFor(resultRow.modelData.symbol)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
              MouseArea {
                id: addMouse
                anchors.fill: parent
                enabled: !root.stale && resultRow.chosen
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.accept(resultRow.index)
              }
            }
          }
        }
      }
    }
  }

  // No matches, or no answer at all, said where the results would be.
  Text {
    objectName: "searchMessage"
    visible: root.answer === "none" || root.answer === "failed"
    opacity: root.stale ? 0.4 : 1
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: fieldBar.bottom
    anchors.topMargin: root.resultsGap
    height: root.rowHeight
    leftPadding: root.rowPadding
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    text: root.answer === "none" ? "No matches for “" + root.resultsQuery + "”" : "Search didn’t answer · try again"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  // The field, at the top, where the list's rows were. Its own border is
  // its edge: a rule under it would draw a second one.
  Item {
    id: fieldBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: root.rowHeight + Style.space(6)

    TextField {
      id: searchField
      objectName: "searchField"
      anchors.left: parent.left
      anchors.right: searchHint.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      foreground: root.foreground
      placeholderText: root.placeholder
      onTextChanged: root.setQuery(text)
      onAccepted: root.accept(root.resultIndex)
      Keys.onPressed: function(event) { root.handleKey(event) }
    }

    // The hint names what Enter does, in the wider hint's room, so the field
    // never moves as the choice goes from a new symbol to a member; with no
    // results there is nothing for Enter to take, and it names Escape alone.
    Text {
      id: searchHint
      objectName: "keyHints"
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Math.ceil(Math.max(addHint.advanceWidth, showHint.advanceWidth))
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: (root.results.length > 0 ? "⏎  " + root.chosenAction.toLowerCase() + "  ·  " : "") + "esc  cancel"
      color: root.dimmer
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      TextMetrics { id: addHint; font: searchHint.font; text: "⏎  add  ·  esc  cancel" }
      TextMetrics { id: showHint; font: searchHint.font; text: "⏎  show  ·  esc  cancel" }
    }
  }
}
